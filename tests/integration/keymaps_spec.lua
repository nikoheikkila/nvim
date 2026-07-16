-- Global keymaps (registry: .claude/instructions/config.md). maparg needs the
-- LITERAL leader character in the lhs — "<leader>nd" is not resolved.
describe("global keymaps", function()
  local leader = vim.g.mapleader

  it("binds <leader>nd to :Daily", function()
    assert.truthy(vim.fn.maparg(leader .. "nd", "n"):find("Daily"))
  end)

  it("binds <leader>bn to Next Buffer", function()
    assert.equal("Next Buffer", vim.fn.maparg(leader .. "bn", "n", false, true).desc)
  end)

  it("binds <leader>bp to Prev Buffer", function()
    assert.equal("Prev Buffer", vim.fn.maparg(leader .. "bp", "n", false, true).desc)
  end)
end)
