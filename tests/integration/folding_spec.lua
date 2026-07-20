-- Folding wiring (config/folding.lua + plugins/markdown.lua + plugins/lsp.lua),
-- run inside headless Neovim. Lazy-loaded plugins don't self-load in --headless,
-- so force-load markdown-plus before its FileType autocmd can wire folding.
describe("folding", function()
  local folding = require("config.folding")

  setup(function()
    require("lazy").load({ plugins = { "markdown-plus.nvim" } })
  end)

  -- Fresh markdown buffer whose FileType event has wired folding on the current
  -- window. Layout: heading (1) > list parent (2) with child (3) > fenced code
  -- block (4-6) — one of each foldable construct.
  local function markdown_buf()
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "# Title",
      "- parent",
      "  - child",
      "```lua",
      "print(1)",
      "```",
    })
    vim.bo.filetype = "markdown"
    return buf
  end

  describe("markdown buffer wiring", function()
    local buf
    setup(function()
      buf = markdown_buf()
    end)
    teardown(function()
      vim.cmd("bwipeout! " .. buf)
    end)

    it("uses an expr foldmethod backed by the markdown foldexpr", function()
      assert.equal("expr", vim.wo.foldmethod)
      assert.truthy(vim.wo.foldexpr:find("markdown_foldexpr", 1, true))
      assert.equal("markdown", vim.b[buf].fold_engine)
    end)

    it("installs the fold-indicator statuscolumn and clean foldtext", function()
      assert.truthy(vim.wo.statuscolumn:find("folding", 1, true))
      assert.equal("", vim.wo.foldtext)
    end)

    it("starts fully expanded", function()
      assert.equal(99, vim.wo.foldlevel)
    end)

    it("binds <Tab> to the fold toggle (buffer-local), replacing normal-mode italic", function()
      local tab = vim.fn.maparg("<Tab>", "n", false, true)
      assert.equal("Toggle fold", tab.desc)
      assert.equal(1, tab.buffer)
      -- <C-i> is the same keycode as <Tab>, so normal-mode italic is gone…
      assert.are_not.equal("Toggle italic (_)", vim.fn.maparg("<C-i>", "n", false, true).desc)
      -- …while visual-mode <C-i> italic remains.
      assert.equal("Toggle italic (_)", vim.fn.maparg("<C-i>", "x", false, true).desc)
    end)
  end)

  describe("computed fold levels", function()
    local buf
    setup(function()
      buf = markdown_buf()
    end)
    teardown(function()
      vim.cmd("bwipeout! " .. buf)
    end)

    -- Reading foldlevel() forces the expr to evaluate.
    it("assigns a fold level to heading, list parent, and code fence", function()
      assert.equal(1, vim.fn.foldlevel(1)) -- # Title
      assert.equal(2, vim.fn.foldlevel(2)) -- - parent
      assert.equal(2, vim.fn.foldlevel(4)) -- ```lua
    end)
  end)

  describe("toggling and indicators", function()
    local buf
    before_each(function()
      buf = markdown_buf()
    end)
    after_each(function()
      vim.cmd("bwipeout! " .. buf)
    end)

    it("closes and reopens a heading fold with normal! za", function()
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("normal! za")
      assert.are_not.equal(-1, vim.fn.foldclosed(1))
      vim.cmd("normal! za")
      assert.equal(-1, vim.fn.foldclosed(1))
    end)

    it("folds the list parent and the code fence independently", function()
      vim.api.nvim_win_set_cursor(0, { 2, 0 }) -- - parent
      vim.cmd("normal! za")
      assert.are_not.equal(-1, vim.fn.foldclosed(2))

      vim.api.nvim_win_set_cursor(0, { 4, 0 }) -- ```lua
      vim.cmd("normal! za")
      assert.are_not.equal(-1, vim.fn.foldclosed(4))
    end)

    it("toggle_at (the click target) flips a fold open↔closed", function()
      assert.equal(-1, vim.fn.foldclosed(1))
      folding.toggle_at(1)
      assert.are_not.equal(-1, vim.fn.foldclosed(1))
      folding.toggle_at(1)
      assert.equal(-1, vim.fn.foldclosed(1))
    end)

    it("shows ▼ on an open fold start, ▶ when closed, nothing on plain lines", function()
      assert.equal("▼", folding.indicator(buf, 1)) -- heading, open
      assert.is_nil(folding.indicator(buf, 3)) -- leaf child, not a fold start
      folding.toggle_at(1)
      assert.equal("▶", folding.indicator(buf, 1)) -- heading, closed
    end)
  end)

  -- The shared mechanism the LSP path reuses (plugins/lsp.lua calls this with
  -- vim.lsp.foldexpr on capable servers). Exercised here with a trivial expr so
  -- no live language server is required.
  describe("enable() on a non-markdown buffer", function()
    local buf
    setup(function()
      vim.cmd("enew")
      buf = vim.api.nvim_get_current_buf()
      folding.enable(buf, { engine = "lsp", foldexpr = "0", foldtext = "v:lua.vim.lsp.foldtext()" })
    end)
    teardown(function()
      vim.cmd("bwipeout! " .. buf)
    end)

    it("sets fold options and the <Tab> map", function()
      assert.equal("expr", vim.wo.foldmethod)
      assert.equal("lsp", vim.b[buf].fold_engine)
      assert.equal("Toggle fold", vim.fn.maparg("<Tab>", "n", false, true).desc)
      assert.truthy(vim.wo.statuscolumn:find("folding", 1, true))
    end)
  end)
end)
