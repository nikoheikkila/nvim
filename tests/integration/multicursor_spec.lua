-- multiple-cursors.nvim wiring (plugins/multicursor.lua). Lazy-loaded plugins
-- don't load on their own in --headless (keys/VeryLazy triggers never fire),
-- so force-load before asserting anything created at setup() time.
describe("multiple-cursors.nvim", function()
  setup(function()
    require("lazy").load({ plugins = { "multiple-cursors.nvim" } })
  end)

  it("loads", function()
    assert.is_true((pcall(require, "multiple-cursors")))
  end)

  it("enables mouse in normal mode (Ctrl+Click cursors)", function()
    assert.truthy(vim.o.mouse:find("n"))
  end)

  it("has no popup mousemodel to swallow ctrl+clicks", function()
    assert.equal("extend", vim.o.mousemodel)
  end)

  it("defines the :MultipleCursors* commands", function()
    local cmds = vim.api.nvim_get_commands({})
    assert.is_not_nil(cmds.MultipleCursorsAddDown)
    assert.is_not_nil(cmds.MultipleCursorsAddVisualArea)
  end)

  for _, mode in ipairs({ "n", "x", "i" }) do
    it("<M-S-Up>/<M-S-Down> add cursor above/below (" .. mode .. ")", function()
      assert.equal("Add cursor above", vim.fn.maparg("<M-S-Up>", mode, false, true).desc)
      assert.equal("Add cursor below", vim.fn.maparg("<M-S-Down>", mode, false, true).desc)
    end)
  end

  for _, lhs in ipairs({ "<C-LeftMouse>", "<C-RightMouse>", "<RightMouse>" }) do
    for _, mode in ipairs({ "n", "i" }) do
      it(lhs .. " toggles cursor at mouse click (" .. mode .. ")", function()
        assert.equal(
          "Add or remove cursor at mouse click",
          vim.fn.maparg(lhs, mode, false, true).desc
        )
      end)
    end
  end

  it("maps visual I to insert at start of selected lines", function()
    assert.equal("Insert at start of selected lines", vim.fn.maparg("I", "x", false, true).desc)
  end)

  it("maps visual A to append at end of selected lines", function()
    assert.equal("Append at end of selected lines", vim.fn.maparg("A", "x", false, true).desc)
  end)

  -- Functional check of the core loop: add a virtual cursor below, confirm the
  -- plain-click reset maps appear while cursors are active, then reset.
  -- Real-time insert mirroring is autocmd-driven and can't be asserted
  -- headlessly (see dev-workflow.md) — verify it interactively. The tests in
  -- this block are an ordered sequence.
  describe("virtual-cursor core loop", function()
    local vcs

    setup(function()
      vcs = require("multiple-cursors.virtual_cursors")
      vim.cmd("enew")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
    end)

    teardown(function()
      vim.bo.modified = false
      vim.cmd("bwipeout!")
    end)

    it("starts with no virtual cursors", function()
      assert.equal(0, vcs.get_num_virtual_cursors())
    end)

    it(":MultipleCursorsAddDown spawns a virtual cursor", function()
      vim.cmd("MultipleCursorsAddDown")
      assert.equal(1, vcs.get_num_virtual_cursors())
    end)

    it("moves the real cursor to the next line", function()
      assert.equal(2, vim.api.nvim_win_get_cursor(0)[1])
    end)

    it("activates the plain-click reset maps while cursors are active", function()
      assert.equal(1, vim.fn.maparg("<LeftMouse>", "n", false, true).buffer)
      assert.equal(1, vim.fn.maparg("<LeftMouse>", "i", false, true).buffer)
    end)

    it("deinit resets to a single cursor and removes the reset maps", function()
      require("multiple-cursors").deinit(true)
      assert.equal(0, vcs.get_num_virtual_cursors())
      assert.equal("", vim.fn.maparg("<LeftMouse>", "n"))
    end)
  end)
end)
