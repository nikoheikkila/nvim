-- Pure unit tests for lib.markdown_fold (no Neovim). Run with `task test:unit`.
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.markdown_fold")

describe("fold_levels", function()
  it("nests headings by their hash count", function()
    local out = M.fold_levels({ "# H1", "text", "## H2", "more", "# Another", "end" })
    assert.are.same({ ">1", "1", ">2", "2", ">1", "1" }, out)
  end)

  it("starts a fold on a list item that has children and not on leaves", function()
    local out = M.fold_levels({ "- a", "  - b", "  - c", "- d" })
    -- `a` owns b/c → fold start; children and the childless sibling `d` are leaves
    assert.are.same({ ">1", "1", "1", "0" }, out)
  end)

  it("folds each parent item independently, even a top-level item after a deep one", function()
    local out = M.fold_levels({ "- A", "  - B", "    - c", "- D", "  - e" })
    -- `- D` must be a forced start (>1) so it does not join A's fold
    assert.are.same({ ">1", ">2", "2", ">1", "1" }, out)
  end)

  it("treats ordered and task list items the same as unordered", function()
    local out = M.fold_levels({ "1. one", "   1. sub", "2. two", "- [ ] task", "  - [ ] child" })
    assert.are.same({ ">1", "1", "0", ">1", "1" }, out)
  end)

  it("folds fenced code blocks and ignores markdown syntax inside them", function()
    local out = M.fold_levels({ "# H", "```lua", "print(1)", "# not heading", "```", "after" })
    -- the interior `# not heading` stays at the fence body level, never a heading
    assert.are.same({ ">1", ">2", "2", "2", "2", "1" }, out)
  end)

  it("supports tilde fences", function()
    local out = M.fold_levels({ "~~~", "code", "~~~" })
    assert.are.same({ ">1", "1", "1" }, out)
  end)

  it("folds a fenced block nested inside a list item", function()
    local out = M.fold_levels({ "- item", "  ```", "  code", "  ```", "- next" })
    assert.are.same({ ">1", ">2", "2", "2", "0" }, out)
  end)

  it("keeps blank lines from breaking a fold", function()
    local out = M.fold_levels({ "# H", "", "text" })
    assert.are.same({ ">1", "=", "1" }, out)
  end)

  it("does not treat a 7-hash line or a hashless line as a heading", function()
    local out = M.fold_levels({ "####### too many", "#nospace" })
    assert.are.same({ "0", "0" }, out)
  end)

  it("does not treat a horizontal rule as a list item", function()
    local out = M.fold_levels({ "---" })
    assert.are.same({ "0" }, out)
  end)

  it("returns one value per input line", function()
    local lines = { "# H", "- a", "  - b", "", "text" }
    assert.are.equal(#lines, #M.fold_levels(lines))
  end)
end)
