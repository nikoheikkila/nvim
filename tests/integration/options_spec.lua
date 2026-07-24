-- Leader keys: must be set by config/options.lua BEFORE any keymap module
-- loads. A <leader> map created before vim.g.mapleader is set silently binds
-- to the default backslash — this spec exists because exactly that regression
-- shipped.
describe("config.options", function()
  it("sets mapleader to <Space>", function()
    assert.equal(" ", vim.g.mapleader)
  end)

  it("sets maplocalleader to backslash", function()
    assert.equal("\\", vim.g.maplocalleader)
  end)

  it("enables absolute line numbers", function()
    assert.is_true(vim.opt.number:get())
  end)

  it("does not enable relative line numbers", function()
    assert.is_false(vim.opt.relativenumber:get())
  end)
end)
