local mu = require("lib.markdown_utils")
local pu = require("lib.path_utils")
local folding = require("config.folding")

-- Markdown folds come from the pure lib.markdown_fold levels (headings, list
-- items with children, fenced code blocks). foldtext = "" lets Neovim render
-- the collapsed line with its real treesitter/render-markdown highlighting.
local function setup_folding(buf)
  folding.enable(buf, {
    engine = "markdown",
    foldexpr = "v:lua.require'config.folding'.markdown_foldexpr()",
    foldtext = "",
  })
end

-- Absolute targets (leading "/") pass through; relative targets resolve against
-- buf_dir and expand to a full path.
local function resolve_path(buf_dir, target)
  if target:sub(1, 1) == "/" then
    return target
  end
  return vim.fn.fnamemodify(buf_dir .. "/" .. target, ":p")
end

local function rename_image_at_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1 -- convert 0-based to 1-based
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]

  local found_path = mu.find_image_path_at(line, col)

  if not found_path or found_path == "" then
    vim.notify("No image reference under cursor", vim.log.levels.WARN)
    return
  end

  if mu.is_remote_url(found_path) then
    vim.notify("Cannot rename a remote URL", vim.log.levels.WARN)
    return
  end

  local buf_file = vim.api.nvim_buf_get_name(0)
  if buf_file == "" then
    vim.notify("Buffer has no file — save it first", vim.log.levels.ERROR)
    return
  end
  local buf_dir = vim.fn.fnamemodify(buf_file, ":h")

  local full_path = resolve_path(buf_dir, found_path)

  if vim.fn.filereadable(full_path) == 0 then
    vim.notify("File not found: " .. full_path, vim.log.levels.ERROR)
    return
  end

  local current_name = vim.fn.fnamemodify(found_path, ":t")

  vim.ui.input({ prompt = "Rename image to: ", default = current_name }, function(new_name)
    if not new_name or new_name == "" or new_name == current_name then
      return
    end

    local new_path = mu.replace_filename(found_path, new_name)
    local new_full = resolve_path(buf_dir, new_path)

    local ok, err = os.rename(full_path, new_full)
    if not ok then
      vim.notify("Rename failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
      return
    end

    -- Replace all occurrences of the old path in the buffer
    local bufnr = vim.api.nvim_get_current_buf()
    local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i, l in ipairs(all_lines) do
      all_lines[i] = l:gsub(vim.pesc(found_path), function()
        return new_path
      end)
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)

    vim.notify(("Renamed: %s → %s"):format(found_path, new_path), vim.log.levels.INFO)
  end)
end

local function open_link_at_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1 -- convert 0-based to 1-based
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]

  local target = mu.find_link_at(line, col)

  if not target or target == "" then
    vim.notify("No link under cursor", vim.log.levels.WARN)
    return
  end

  local kind = pu.classify_link(target)

  if kind == "external" then
    vim.ui.open(target)
    return
  end

  if kind == "ignored" then
    return
  end

  -- internal: open the file, dropping any #anchor, resolving relative to the buffer dir
  local path = pu.strip_anchor(target)
  local full_path

  if path:sub(1, 1) == "/" then
    full_path = path
  else
    local buf_file = vim.api.nvim_buf_get_name(0)
    if buf_file == "" then
      vim.notify("Buffer has no file — save it first", vim.log.levels.ERROR)
      return
    end
    full_path = resolve_path(vim.fn.fnamemodify(buf_file, ":h"), path)
  end

  vim.cmd.edit(vim.fn.fnameescape(full_path))
end

local function setup_keymaps(buf)
  -- Bold: plugin uses ** correctly
  vim.keymap.set({ "n", "x" }, "<C-b>", "<Plug>(MarkdownPlusBold)", { buffer = buf, desc = "Toggle bold" })

  -- Italic: plugin hardcodes *, temporarily patch to _ before calling its toggle
  local function italic_visual()
    local p = require("markdown-plus.format.patterns")
    local orig = p.patterns.italic.wrap
    p.patterns.italic.wrap = "_"
    require("markdown-plus.format.toggle").toggle_format("italic")
    p.patterns.italic.wrap = orig
  end
  -- Visual only: normal-mode <C-i> is the same terminal keycode as <Tab>, which
  -- folding.enable() binds to the fold toggle in markdown buffers.
  vim.keymap.set("x", "<C-i>", italic_visual, { buffer = buf, desc = "Toggle italic (_)" })

  -- Link
  vim.keymap.set("n", "<C-k>", "<Plug>(MarkdownPlusInsertLink)", { buffer = buf, desc = "Insert link" })
  vim.keymap.set("x", "<C-k>", "<Plug>(MarkdownPlusSelectionToLink)", { buffer = buf, desc = "Selection to link" })

  -- Checklist: pure regex toggle to avoid treesitter timing/compatibility issues
  local function checklist_toggle()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    local new_line = mu.toggle_checklist_line(line)
    if new_line == line then
      return
    end
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
  end
  vim.keymap.set({ "n", "i" }, "<C-l>", checklist_toggle, { buffer = buf, desc = "Toggle checklist item" })
  vim.keymap.set("x", "<C-l>", "<Plug>(MarkdownPlusToggleCheckbox)", { buffer = buf, desc = "Toggle checklist range" })

  -- Image
  vim.keymap.set("n", "<C-S-I>", "<Plug>(MarkdownPlusInsertImage)", { buffer = buf, desc = "Insert image" })
  vim.keymap.set("x", "<C-S-I>", "<Plug>(MarkdownPlusSelectionToImage)", { buffer = buf, desc = "Selection to image" })
  vim.keymap.set("n", "<F2>", rename_image_at_cursor, { buffer = buf, desc = "Rename image at cursor" })

  -- Follow the link under the cursor: browser for URLs, :e for files, ignore mailto/tel/anchors
  vim.keymap.set("n", "<leader>gl", open_link_at_cursor, { buffer = buf, desc = "Open link under cursor" })
end

return {
  {
    "yousefhadder/markdown-plus.nvim",
    ft = "markdown",
    -- keymaps.enabled = true restores the default <CR> list-continuation binding
    opts = {
      keymaps = { enabled = true },
    },
    config = function(_, opts)
      require("markdown-plus").setup(opts)

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "markdown" then
          setup_keymaps(buf)
          setup_folding(buf)
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("MarkdownPlusKeymaps", { clear = true }),
        pattern = "markdown",
        callback = function(ev)
          setup_keymaps(ev.buf)
          setup_folding(ev.buf)
        end,
      })
    end,
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    -- Render in all modes so the appearance never changes on mode switch
    opts = {
      render_modes = true,
      heading = {
        -- position = 'overlay' (default) lays each icon over the raw `#` markers,
        -- so every icon must be exactly as wide as the markers it covers
        icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " },
      },
      checkbox = {
        -- Diagnostic groups give theme-consistent red/green without custom highlights
        unchecked = { icon = "○ ", highlight = "DiagnosticError" },
        checked = { icon = "● ", highlight = "DiagnosticOk" },
      },
      bullet = {
        icons = { "•" },
        highlight = "Normal",
      },
      code = {
        -- sign + inline language label rendered the marker twice; keep only
        -- the inline icon+name label
        sign = false,
        -- one cell of RenderMarkdownCodeInline-highlighted padding on each
        -- side of inline code, so the background doesn't hug the text
        inline_pad = 1,
      },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      -- render-markdown sets its own opaque code block backgrounds that don't
      -- inherit theme transparency. Clear them so the terminal bg shows through.
      local function fix_highlights()
        vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = "NONE" })
        vim.api.nvim_set_hl(0, "RenderMarkdownCodeBorder", { bg = "NONE" })
        -- H1 in magenta: bright text on a dark magenta band — identical shades
        -- would make the overlaid `# ` marker invisible against the background.
        -- The plugin's fg group only covers the marker + sign; the heading text
        -- itself is highlighted by treesitter (@markup.heading.1.markdown).
        vim.api.nvim_set_hl(0, "RenderMarkdownH1", { fg = "#ff00ff", bold = true })
        vim.api.nvim_set_hl(0, "RenderMarkdownH1Bg", { bg = "#3a0d3a" })
        vim.api.nvim_set_hl(0, "@markup.heading.1.markdown", { fg = "#ff00ff", bold = true })
        -- github-theme styles @markup.raw italic and leaves @markup.raw.block
        -- undefined, so fence content falls back to italic — and injected language
        -- captures set fg but not italic, so italic bleeds through. Define the most
        -- specific group non-italic, keeping the theme's fg; inline code
        -- (@markup.raw.markdown_inline) is styled via theme.yml's groups section.
        local raw = vim.api.nvim_get_hl(0, { name = "@markup.raw", link = false })
        vim.api.nvim_set_hl(0, "@markup.raw.block.markdown", { fg = raw.fg })
      end
      fix_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = fix_highlights })
    end,
  },

  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        markdown = { "prettier" },
        lua = { "stylua" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = false,
      },
    },
  },

  {
    "mfussenegger/nvim-lint",
    ft = "markdown",
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = { markdown = { "markdownlint-cli2" } }
      -- Base config aligning MD013 with textwidth=120; per-project
      -- .markdownlint* files still override it (cli2 --config is a base, not
      -- a replacement). "-" (the stdin glob) must stay last.
      lint.linters["markdownlint-cli2"].args =
        { "--config", require("config.paths").config_file(".markdownlint.jsonc"), "-" }
      -- cli2 >= 0.18 prefixes findings with a severity word
      -- ("stdin:3:121 error MD013/... message"); nvim-lint's bundled
      -- errorformat predates that and would leak "error " into every
      -- message. Strip it, with fallbacks for the old format.
      lint.linters["markdownlint-cli2"].parser = require("lint.parser").from_errorformat(
        "stdin:%l:%c error %m,stdin:%l error %m,stdin:%l:%c warning %m,stdin:%l warning %m,stdin:%l:%c %m,stdin:%l %m",
        { source = "markdownlint", severity = vim.diagnostic.severity.WARN }
      )

      -- Dark-yellow band on offending lines; re-applied on ColorScheme like
      -- render-markdown's fix_highlights above.
      local function set_highlight()
        vim.api.nvim_set_hl(0, "MarkdownLintLine", { bg = "#3a2f1a" })
      end
      set_highlight()

      -- Empty sign text on purpose: the runtime signs handler defaults it to
      -- "W", which opens/shifts the auto signcolumn on every appearing
      -- warning; "" keeps the linehl band without touching the signcolumn.
      local warn = vim.diagnostic.severity.WARN
      vim.diagnostic.config({
        underline = false,
        virtual_text = true,
        signs = { text = { [warn] = "" }, linehl = { [warn] = "MarkdownLintLine" } },
      }, lint.get_namespace("markdownlint-cli2"))

      local warned = false
      local function lint_buf(buf)
        if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "markdown" then
          return
        end
        if vim.fn.executable("markdownlint-cli2") == 1 then
          vim.api.nvim_buf_call(buf, function()
            lint.try_lint("markdownlint-cli2")
          end)
        elseif not warned then
          warned = true
          vim.notify(
            "markdownlint-cli2 not found on PATH (brew install markdownlint-cli2) — live markdown linting disabled",
            vim.log.levels.WARN
          )
        end
        -- Deterministic sync point for tests: signals that a debounced run
        -- finished deciding (spawned or guarded). The integration spec latches
        -- on this instead of sleeping out the timer; with no listeners,
        -- exec_autocmds is a no-op.
        vim.api.nvim_exec_autocmds("User", { pattern = "MarkdownLintRun" })
      end

      -- nvim-lint has no debounce and each run spawns a node process;
      -- restarting an active uv timer coalesces event bursts
      -- (InsertLeave -> auto-save -> prettier -> BufWritePost) into one run.
      local timer = assert(vim.uv.new_timer())
      local group = vim.api.nvim_create_augroup("markdown_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave", "BufWritePost", "BufReadPost" }, {
        group = group,
        callback = function(ev)
          if vim.bo[ev.buf].filetype ~= "markdown" then
            return
          end
          timer:start(
            300,
            0,
            vim.schedule_wrap(function()
              lint_buf(ev.buf)
            end)
          )
        end,
      })
      vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_highlight })

      -- ft-lazy loading: this config() runs during the FIRST markdown
      -- buffer's FileType event, whose BufReadPost has already fired — catch
      -- up on every markdown buffer already open (markdown-plus pattern).
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "markdown" then
          lint_buf(buf)
        end
      end
    end,
  },
}
