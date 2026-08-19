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
      -- Non-LSP mason packages. mason-lspconfig only knows servers and
      -- mason.nvim itself has no ensure_installed, so the `vale` CLI that
      -- vale-ls shells out to needs its own installer.
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      -- Required here (not at spec-collection time) so lsp_servers.lua's
      -- config.yml read for harper_ls happens on plugin load, not every startup.
      local servers = require("config.lsp_servers")
      local harper_utils = require("lib.harper_utils")

      require("mason").setup() -- must run before mason-lspconfig.setup(); prepends mason/bin to PATH

      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
      for name, config in pairs(servers) do
        vim.lsp.config(name, config)
      end

      -- Headless sessions (task install, CI, busted) must never trigger tool
      -- downloads — install only when a UI is attached. Shared by both
      -- installers below.
      local ui_attached = #vim.api.nvim_list_uis() > 0

      local server_names = vim.tbl_keys(servers)
      require("mason-lspconfig").setup({
        ensure_installed = ui_attached and server_names or {},
        -- automatic_enable runs vim.lsp.enable() for installed servers,
        -- including ones installed mid-session. Allowlisted to the servers
        -- table: the mason data dir may hold servers from earlier setups
        -- (vtsls, pyright, ...) that must not attach alongside these.
        automatic_enable = server_names,
      })

      -- The CLI half of Vale: vale-ls spawns `vale` from PATH, and mason's bin
      -- dir is on it once mason.setup() has run. scripts/install.sh reaches past
      -- the headless guard with an explicit `:MasonInstall vale`, so a fresh
      -- install can sync styles in the same headless session.
      --
      -- run_on_start is off and the check is driven directly: the plugin hangs
      -- its own trigger on a VimEnter autocmd registered from its plugin/ file,
      -- and this whole spec is BufReadPre-lazy. Opening a file at startup gets
      -- in ahead of VimEnter, but `:edit`ing one in an already-running session
      -- does not — there the autocmd is registered after VimEnter has fired and
      -- never runs, so `vale` would silently never install. Calling it here is
      -- the same work at a moment we control.
      local tool_installer = require("mason-tool-installer")
      tool_installer.setup({
        ensure_installed = ui_attached and { "vale" } or {},
        run_on_start = false,
      })
      if ui_attached then
        tool_installer.check_install(false) -- false = install missing, don't update existing
      end

      -- Global defaults for LSP diagnostics. Namespace-scoped config wins per
      -- key, so the markdownlint namespace setup in plugins/markdown.lua
      -- (no underline, linehl band, empty sign text) is untouched.
      vim.diagnostic.config({
        severity_sort = true,
        virtual_text = { source = "if_many" },
      })

      -- Prose diagnostics get their own underline colour instead of the theme's
      -- severity ones, so a wordiness nit never looks like a compile error and
      -- the two prose servers stay apart from each other. Harper's lints are all
      -- Hint severity, which the theme draws with the bluish
      -- DiagnosticUnderlineHint group — flat and link-like on terminals without
      -- undercurl. Vale's run error/warning/suggestion, which is worse: red and
      -- yellow squiggles on "utilize is too wordy".
      --
      -- Each handler draws its own extmarks in its own namespace, and is enabled
      -- per *diagnostic* namespace on attach below, so it applies to that server
      -- alone and every other server's diagnostics keep their default styling.
      -- One table drives everything: the handler name is derived from the client
      -- name rather than written out a second time, so a third prose server is
      -- one line here and cannot half-register. (Spelling the name twice would
      -- silently disable that server's diagnostics: LspAttach turns the built-in
      -- underline off and routes drawing to a handler key that does not exist.)
      local prose_underline = {} -- client name -> diagnostic handler name
      local function register_underline(client_name, hl_group)
        local name = client_name:gsub("_ls$", "") .. "/underline"
        -- Parenthesised: gsub also returns a count, and nvim_create_namespace
        -- takes exactly one argument.
        local ns = vim.api.nvim_create_namespace((name:gsub("/", "_")))
        prose_underline[client_name] = name
        vim.diagnostic.handlers[name] = {
          show = function(_, bufnr, diagnostics, _)
            for _, d in ipairs(diagnostics) do
              -- pcall: end_col can point past a shrinking line between publishes.
              pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, d.lnum, d.col, {
                end_row = d.end_lnum,
                end_col = d.end_col,
                hl_group = hl_group,
                priority = 200, -- above treesitter (100) so the undercurl shows
              })
            end
          end,
          hide = function(_, bufnr)
            vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
          end,
        }
      end

      -- Colours come from theme.yml.
      register_underline("harper_ls", "HarperDiagnosticUnderline") -- dark red
      register_underline("vale_ls", "ValeDiagnosticUnderline") -- violet

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

      -- <leader>ca quick-fix menu: plain code actions, plus the client-side half
      -- of Harper's dictionary support and Vale's fixes. Two things make it more
      -- than a bare vim.lsp.buf.code_action() call:
      --
      -- 1. No `context.only` filter, ever. Harper emits "Add "x" to the …
      --    dictionary." as kind-less lsp.Commands, and Neovim's own action_filter
      --    drops every kind-less action as soon as `only` is set — which is why
      --    the refactor menu above can never show them.
      -- 2. The request has to land in a lint span. Harper only answers one whose
      --    range sits inside a span; vale-ls answers from `context.diagnostics`
      --    alone, which Neovim fills from the cursor position unless an explicit
      --    range is passed. Both come out as "cursor on the flagged word only"
      --    without a snap; see lib/harper_utils.quick_fix_position.
      --
      -- Passing a range also widens the context Neovim builds: with opts.range
      -- set it stops filtering line diagnostics down to the ones containing the
      -- cursor, so every prose flag on the line reaches the server.
      --
      -- Everything after that is Neovim's: the workspace edit for a replacement,
      -- workspace/executeCommand for the dictionary and vocabulary commands (the
      -- servers do the file writes themselves), and aggregation across clients.
      local function quick_fix()
        local buf = vim.api.nvim_get_current_buf()
        local spans = {}
        -- Prose servers only, not every diagnostic in the buffer. Widening this
        -- to "any diagnostic contains the cursor → stay put" looks safer but
        -- breaks markdown: nvim-lint's markdownlint diagnostics can cover most of
        -- a line and carry no code actions at all, so they would veto the snap in
        -- exactly the buffers it is for.
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
          if prose_underline[client.name] then
            local ns = vim.lsp.diagnostic.get_namespace(client.id)
            vim.list_extend(spans, vim.diagnostic.get(buf, { namespace = ns }))
          end
        end

        local cursor = vim.api.nvim_win_get_cursor(0)
        local pos = harper_utils.quick_fix_position({ lnum = cursor[1] - 1, col = cursor[2] }, spans)
        if not pos then
          return vim.lsp.buf.code_action()
        end
        -- opts.range is mark-indexed (1-based row, 0-based byte col) and
        -- make_given_range_params converts to the client's utf-16 offsets, so the
        -- byte columns from vim.diagnostic.get() go in as they are. The cursor
        -- deliberately stays put: dismissing the menu must not move it.
        local range = { start = { pos.lnum + 1, pos.col }, ["end"] = { pos.lnum + 1, pos.col } }
        vim.lsp.buf.code_action({ range = range })
      end

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
        -- Normal mode only: in visual mode the selection is already an explicit
        -- range, and Neovim's built-in `gra` covers that case unsnapped.
        map("n", "<leader>ca", quick_fix, "Quick fix menu")
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_keymaps", { clear = true }),
        callback = function(ev)
          setup_lsp_keymaps(ev.buf)

          -- Non-markdown folding: drive <Tab>/indicator from the server's
          -- foldingRange support. Markdown keeps its own foldexpr (plugins/
          -- markdown.lua) even when a server does attach and advertise
          -- foldingRange — obsidian.nvim's obsidian-ls does — because
          -- folding.enable() refuses to downgrade a markdown-engine buffer.
          -- ev.data is absent when a spec fires LspAttach synthetically.
          local client = ev.data and vim.lsp.get_client_by_id(ev.data.client_id)
          if client and client.server_capabilities.foldingRangeProvider then
            require("config.folding").enable(ev.buf, {
              engine = "lsp",
              foldexpr = "v:lua.vim.lsp.foldexpr()",
              foldtext = "v:lua.vim.lsp.foldtext()",
            })
          end

          -- Swap a prose server's severity underline for its own scoped wavy one:
          -- disable the built-in underline on that server's namespace and route
          -- it through the handler registered above. `signs = false` applies to
          -- both prose namespaces — prose nits never open the signcolumn, the
          -- policy plugins/markdown.lua implements for markdownlint with empty
          -- sign text. It matters most for Vale, whose error/warning severities
          -- would otherwise put an E in the gutter next to "too wordy", but
          -- Harper's Hint signs go the same way.
          local handler = client and prose_underline[client.name]
          if handler then
            vim.diagnostic.config(
              { underline = false, signs = false, [handler] = true },
              vim.lsp.diagnostic.get_namespace(client.id)
            )
          end
        end,
      })
    end,
  },
}
