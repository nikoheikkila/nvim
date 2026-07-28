-- Buffer-local markdown keymap wiring (plugins/markdown.lua), run inside headless
-- Neovim. Lazy-loaded plugins don't self-load in --headless, so force-load
-- markdown-plus before its FileType autocmd can wire the buffer-local maps.
describe("markdown keymaps", function()
  local buf

  setup(function()
    require("lazy").load({ plugins = { "markdown-plus.nvim" } })
    -- Fresh markdown buffer whose FileType event has run setup_keymaps on it.
    vim.cmd("enew")
    buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Title", "![alt](img/p.png)" })
    vim.bo.filetype = "markdown"
  end)

  teardown(function()
    vim.cmd("bwipeout! " .. buf)
  end)

  local function map(lhs, mode)
    return vim.fn.maparg(lhs, mode, false, true)
  end

  it("binds the formatting maps buffer-local", function()
    assert.equal("Toggle bold", map("<C-b>", "n").desc)
    assert.equal("Toggle bold", map("<C-b>", "x").desc)
    -- Visual only: normal-mode <C-i> is the same keycode as <Tab> (see folding_spec).
    assert.equal("Toggle italic (_)", map("<C-i>", "x").desc)
  end)

  it("binds the link and image maps buffer-local", function()
    assert.equal("Insert link", map("<C-k>", "n").desc)
    assert.equal("Selection to link", map("<C-k>", "x").desc)
    assert.equal("Insert image", map("<C-S-I>", "n").desc)
    assert.equal("Selection to image", map("<C-S-I>", "x").desc)
  end)

  it("binds the checklist maps buffer-local", function()
    assert.equal("Toggle checklist item", map("<C-l>", "n").desc)
    assert.equal("Toggle checklist item", map("<C-l>", "i").desc)
    assert.equal("Toggle checklist range", map("<C-l>", "x").desc)
  end)

  it("shadows the LSP <F2> rename with the image rename", function()
    local f2 = map("<F2>", "n")
    assert.equal("Rename image at cursor", f2.desc)
    assert.equal(1, f2.buffer)
  end)

  -- Retirement guard: <leader>gl (open_link_at_cursor) was removed when
  -- obsidian.nvim arrived. Vault notes follow links with <CR> and gf (the plugin
  -- sets 'includeexpr'); every other markdown file uses built-in gf and gx.
  it("no longer binds <leader>gl", function()
    assert.equal("", vim.fn.maparg(vim.g.mapleader .. "gl", "n"))
  end)
end)
