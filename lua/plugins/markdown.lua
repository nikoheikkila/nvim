local mu = require("lib.markdown_utils")

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

  local full_path = found_path:sub(1, 1) == "/"
    and found_path
    or vim.fn.fnamemodify(buf_dir .. "/" .. found_path, ":p")

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
    local new_full = found_path:sub(1, 1) == "/"
      and new_path
      or vim.fn.fnamemodify(buf_dir .. "/" .. new_path, ":p")

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
  local function italic_normal()
    local p = require("markdown-plus.format.patterns")
    local orig = p.patterns.italic.wrap
    p.patterns.italic.wrap = "_"
    require("markdown-plus.format.toggle").toggle_format_word("italic")
    p.patterns.italic.wrap = orig
  end
  vim.keymap.set("x", "<C-i>", italic_visual, { buffer = buf, desc = "Toggle italic (_)" })
  vim.keymap.set("n", "<C-i>", italic_normal, { buffer = buf, desc = "Toggle italic (_)" })

  -- Link
  vim.keymap.set("n", "<C-k>", "<Plug>(MarkdownPlusInsertLink)", { buffer = buf, desc = "Insert link" })
  vim.keymap.set("x", "<C-k>", "<Plug>(MarkdownPlusSelectionToLink)", { buffer = buf, desc = "Selection to link" })

  -- Checklist: pure regex toggle to avoid treesitter timing/compatibility issues
  local function checklist_toggle()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    local new_line = mu.toggle_checklist_line(line)
    if new_line == line then return end
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
  end
  vim.keymap.set({ "n", "i" }, "<C-l>", checklist_toggle, { buffer = buf, desc = "Toggle checklist item" })
  vim.keymap.set("x", "<C-l>", "<Plug>(MarkdownPlusToggleCheckbox)", { buffer = buf, desc = "Toggle checklist range" })

  -- Image
  vim.keymap.set("n", "<C-S-I>", "<Plug>(MarkdownPlusInsertImage)", { buffer = buf, desc = "Insert image" })
  vim.keymap.set("x", "<C-S-I>", "<Plug>(MarkdownPlusSelectionToImage)", { buffer = buf, desc = "Selection to image" })
  vim.keymap.set("n", "<F2>", rename_image_at_cursor, { buffer = buf, desc = "Rename image at cursor" })
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
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("MarkdownPlusKeymaps", { clear = true }),
        pattern = "markdown",
        callback = function(ev)
          setup_keymaps(ev.buf)
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
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      -- render-markdown sets its own opaque code block backgrounds that don't
      -- inherit theme transparency. Clear them so the terminal bg shows through.
      local function fix_code_hl()
        vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = "NONE" })
        vim.api.nvim_set_hl(0, "RenderMarkdownCodeBorder", { bg = "NONE" })
      end
      fix_code_hl()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = fix_code_hl })
    end,
  },

  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        markdown = { "prettier" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = false,
      },
    },
  },
}
