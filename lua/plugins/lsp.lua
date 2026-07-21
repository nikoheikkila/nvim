-- Language servers: completion (blink.cmp), live diagnostics, navigation, and
-- refactoring. See .claude/instructions/lsp.md for the full design notes.
--
-- Adding a language server = one entry in lua/config/lsp_servers.lua.
return {
  {
    "saghen/blink.cmp",
    version = "1.*", -- release tag → prebuilt fuzzy-matcher binary (no cargo); pinned via lazy-lock.json
    -- In practice blink loads with nvim-lspconfig (it's a dependency there,
    -- for capabilities); InsertEnter only matters in no-file sessions where
    -- BufReadPre/BufNewFile never fire.
    event = "InsertEnter",
    opts = {
      -- "enter" preset: <CR> accepts the selected item, <C-n>/<C-p>/arrows
      -- select, <C-space> opens manually. The default selection behavior
      -- (preselect = true) highlights the first suggestion when the menu
      -- opens, so a bare <CR> accepts it; close the menu with <C-e> to get a
      -- plain newline instead. Safe alongside markdown-plus's insert-mode
      -- <CR> (list continuation): that map is buffer-local to markdown, which
      -- shadows blink's global one — and blink is disabled in markdown anyway.
      keymap = { preset = "enter" },
      completion = { documentation = { auto_show = true } },
      -- Markdown buffers are prose in this config; keep the popup out of them.
      enabled = function()
        return vim.bo.filetype ~= "markdown"
      end,
    },
  },
  {
    "neovim/nvim-lspconfig", -- supplies the base server configs from its lsp/ runtime dir
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      -- Required here (not at spec-collection time) so lsp_servers.lua's
      -- config.yml read for harper_ls happens on plugin load, not every startup.
      local servers = require("config.lsp_servers")

      require("mason").setup() -- must run before mason-lspconfig.setup(); prepends mason/bin to PATH

      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
      for name, config in pairs(servers) do
        vim.lsp.config(name, config)
      end

      local server_names = vim.tbl_keys(servers)
      require("mason-lspconfig").setup({
        -- Headless sessions (task install, CI, busted) must never trigger
        -- server downloads — install only when a UI is attached.
        ensure_installed = #vim.api.nvim_list_uis() > 0 and server_names or {},
        -- automatic_enable runs vim.lsp.enable() for installed servers,
        -- including ones installed mid-session. Allowlisted to the servers
        -- table: the mason data dir may hold servers from earlier setups
        -- (vtsls, pyright, ...) that must not attach alongside these.
        automatic_enable = server_names,
      })

      -- Global defaults for LSP diagnostics. Namespace-scoped config wins per
      -- key, so the markdownlint namespace setup in plugins/markdown.lua
      -- (no underline, linehl band, empty sign text) is untouched.
      vim.diagnostic.config({
        severity_sort = true,
        virtual_text = { source = "if_many" },
      })

      -- Harper's grammar diagnostics are all Hint severity, so the theme renders
      -- them with the (bluish) DiagnosticUnderlineHint group — a flat, link-like
      -- underline on terminals without undercurl. A custom handler draws a
      -- dark-red wavy underline instead, in the HarperDiagnosticUnderline color
      -- from theme.yml. It's enabled per-namespace on attach below, so it runs
      -- for Harper alone and other servers' hints keep their default styling.
      local harper_underline_ns = vim.api.nvim_create_namespace("harper_underline")
      vim.diagnostic.handlers["harper/underline"] = {
        show = function(_, bufnr, diagnostics, _)
          for _, d in ipairs(diagnostics) do
            -- pcall: end_col can point past a shrinking line between publishes.
            pcall(vim.api.nvim_buf_set_extmark, bufnr, harper_underline_ns, d.lnum, d.col, {
              end_row = d.end_lnum,
              end_col = d.end_col,
              hl_group = "HarperDiagnosticUnderline",
              priority = 200, -- above treesitter (100) so the undercurl shows
            })
          end
        end,
        hide = function(_, bufnr)
          vim.api.nvim_buf_clear_namespace(bufnr, harper_underline_ns, 0, -1)
        end,
      }

      -- <leader>r menu: rename + kind-filtered code actions. `only` matching
      -- is hierarchical ("refactor.extract" catches .function, .constant, …)
      -- and apply = true auto-applies when exactly one action matches.
      -- Extract/inline availability is server-dependent (ts_ls: yes; most
      -- others rename-only) — an empty result reports "No code actions".
      local refactor_actions = {
        { label = "Rename symbol", run = vim.lsp.buf.rename },
        { label = "Extract function/method", only = { "refactor.extract.function", "refactor.extract.method" } },
        { label = "Extract constant/variable", only = { "refactor.extract.constant", "refactor.extract.variable" } },
        { label = "Inline", only = { "refactor.inline" } },
        { label = "All refactorings…", only = { "refactor" } },
      }

      local function refactor_menu()
        vim.ui.select(refactor_actions, {
          prompt = "Refactor",
          format_item = function(item)
            return item.label
          end,
        }, function(choice)
          if not choice then
            return
          end
          if choice.run then
            return choice.run()
          end
          vim.lsp.buf.code_action({ context = { only = choice.only }, apply = true })
        end)
      end

      -- Registered unconditionally on attach (not gated on client
      -- capabilities) so the integration spec can fire LspAttach on a scratch
      -- buffer without a live server.
      local function setup_lsp_keymaps(buf)
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
        end

        -- The function keys also work while typing: leave insert mode so the
        -- prompt/picker opens from normal mode, then restore insert when the
        -- action is done. Restoring cannot happen right after the call — the
        -- LSP round trip is async and snacks floats stopinsert as they close,
        -- which would undo an early startinsert. Two completion signals
        -- cover all flows: a WinEnter latch for when a float took focus
        -- (rename prompt, modal picker), and the picker's on_close callback
        -- for when no UI ever opened (single-result auto-jump, no results).
        local function stopinsert_with_restore()
          local win = vim.api.nvim_get_current_win()
          vim.cmd.stopinsert()
          -- One pending latch at a time: re-creating the group drops a stale
          -- one left by an action whose float never opened.
          local group = vim.api.nvim_create_augroup("lsp_restore_insert", { clear = true })
          vim.api.nvim_create_autocmd("WinEnter", {
            group = group,
            callback = function()
              if vim.api.nvim_get_current_win() ~= win then
                return false -- a float (picker/prompt) took focus; keep waiting
              end
              vim.cmd.startinsert()
              return true -- one-shot: remove once focus is back here
            end,
          })
          -- on_close for snacks pickers: when focus never left the window the
          -- latch above cannot fire — restore directly, scheduled so the
          -- picker finishes tearing down first.
          return function()
            if vim.api.nvim_get_current_win() == win then
              -- Cancel the pending latch (re-creating with clear is idempotent).
              vim.api.nvim_create_augroup("lsp_restore_insert", { clear = true })
              vim.schedule(function()
                vim.cmd.startinsert()
              end)
            end
          end
        end

        map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol") -- shadowed in markdown by the image-rename map
        map("i", "<F2>", function()
          stopinsert_with_restore() -- rename exposes no close hook; the WinEnter latch restores
          vim.lsp.buf.rename()
        end, "Rename symbol")
        map("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol")

        -- Both picker actions share one shape: F-keys in normal and insert
        -- mode plus a <leader> chord; the insert maps restore via the
        -- picker's on_close. <F24> exists because some terminals report
        -- Shift+F12 as F24.
        for _, action in ipairs({
          { picker = "lsp_definitions", fkeys = { "<F12>" }, leader = "<leader>gd", desc = "Go to definition" },
          {
            picker = "lsp_references",
            fkeys = { "<S-F12>", "<F24>" },
            leader = "<leader>gr",
            desc = "List references",
          },
        }) do
          local function run(opts)
            require("snacks").picker[action.picker](opts)
          end
          map("n", action.leader, run, action.desc)
          for _, fkey in ipairs(action.fkeys) do
            map("n", fkey, run, action.desc)
            map("i", fkey, function()
              run({ on_close = stopinsert_with_restore() })
            end, action.desc)
          end
        end

        map({ "n", "x" }, "<leader>r", refactor_menu, "Refactor menu")
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_keymaps", { clear = true }),
        callback = function(ev)
          setup_lsp_keymaps(ev.buf)

          -- Non-markdown folding: drive <Tab>/indicator from the server's
          -- foldingRange support. Markdown has its own foldexpr (plugins/
          -- markdown.lua) and no server here, so it never reaches this branch.
          -- ev.data is absent when a spec fires LspAttach synthetically.
          local client = ev.data and vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client.server_capabilities.foldingRangeProvider then
            require("config.folding").enable(ev.buf, {
              engine = "lsp",
              foldexpr = "v:lua.vim.lsp.foldexpr()",
              foldtext = "v:lua.vim.lsp.foldtext()",
            })
          end

          -- Swap Harper's flat hint underline for the scoped dark-red wavy one:
          -- disable the built-in underline on its namespace and route it through
          -- the harper/underline handler registered above.
          if client and client.name == "harper_ls" then
            vim.diagnostic.config(
              { underline = false, ["harper/underline"] = true },
              vim.lsp.diagnostic.get_namespace(client.id)
            )
          end
        end,
      })
    end,
  },
}
