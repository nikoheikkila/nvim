package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.lockfile_utils")

describe("lockfile_utils.drifted", function()
  it("is empty when every checkout matches the lockfile", function()
    local lock = { ["a.nvim"] = { branch = "main", commit = "aaa" }, ["b.nvim"] = { branch = "main", commit = "bbb" } }
    assert.same({}, M.drifted(lock, { ["a.nvim"] = "aaa", ["b.nvim"] = "bbb" }))
  end)

  it("lists plugins whose checkout moved past the locked commit, sorted", function()
    local lock = { ["a.nvim"] = { commit = "aaa" }, ["b.nvim"] = { commit = "bbb" }, ["c.nvim"] = { commit = "ccc" } }
    assert.same({ "a.nvim", "c.nvim" }, M.drifted(lock, { ["c.nvim"] = "new", ["b.nvim"] = "bbb", ["a.nvim"] = "new" }))
  end)

  it("lists installed plugins missing from the lockfile", function()
    assert.same(
      { "new.nvim" },
      M.drifted({ ["a.nvim"] = { commit = "aaa" } }, { ["a.nvim"] = "aaa", ["new.nvim"] = "x" })
    )
  end)

  it("ignores lockfile entries for plugins that are not installed", function()
    assert.same({}, M.drifted({ ["gone.nvim"] = { commit = "zzz" } }, {}))
  end)

  it("treats a missing or malformed lockfile as fully drifted", function()
    assert.same({ "a.nvim" }, M.drifted(nil, { ["a.nvim"] = "aaa" }))
    assert.same({ "a.nvim" }, M.drifted({ ["a.nvim"] = "not-a-table" }, { ["a.nvim"] = "aaa" }))
  end)
end)
