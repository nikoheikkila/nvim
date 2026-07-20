-- nvim-surround wiring (plugins/surround.lua). VeryLazy plugins don't load on
-- their own in --headless, so force-load before asserting anything created at
-- setup() time (same pattern as multicursor_spec.lua).
describe("nvim-surround", function()
  setup(function()
    require("lazy").load({ plugins = { "nvim-surround" } })
  end)

  it("loads", function()
    assert.is_true((pcall(require, "nvim-surround")))
  end)

  -- Default keymaps kept as-is: assert each on the desc nvim-surround sets.
  local maps = {
    { "ys", "n", "Add a surrounding pair around a motion (normal mode)" },
    { "ds", "n", "Delete a surrounding pair" },
    { "cs", "n", "Change a surrounding pair" },
    { "S", "x", "Add a surrounding pair around a visual selection" },
    { "<C-g>s", "i", "Add a surrounding pair around the cursor (insert mode)" },
  }
  for _, m in ipairs(maps) do
    local lhs, mode, desc = m[1], m[2], m[3]
    it(lhs .. " is wired in " .. mode .. " mode", function()
      assert.equal(desc, vim.fn.maparg(lhs, mode, false, true).desc)
    end)
  end

  -- Functional check of the core add-surround loop: wrap a word in quotes.
  it('ysiw" wraps the word under the cursor in quotes', function()
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd('normal ysiw"')
    assert.equal('"hello"', vim.api.nvim_buf_get_lines(0, 0, -1, false)[1])
    vim.cmd("bwipeout!")
  end)
end)
