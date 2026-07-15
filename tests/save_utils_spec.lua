-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.save_utils")

local function props(overrides)
  local base = {
    name = "/abs/path/file.txt",
    buftype = "",
    modified = true,
    modifiable = true,
    readonly = false,
  }
  for k, v in pairs(overrides or {}) do
    base[k] = v
  end
  return base
end

describe("should_autosave", function()
  it("saves a modified, writable, named file buffer", function()
    assert.is_true(M.should_autosave(props()))
  end)

  it("skips an unmodified buffer", function()
    assert.is_false(M.should_autosave(props({ modified = false })))
  end)

  it("skips a non-modifiable buffer", function()
    assert.is_false(M.should_autosave(props({ modifiable = false })))
  end)

  it("skips a readonly buffer", function()
    assert.is_false(M.should_autosave(props({ readonly = true })))
  end)

  for _, buftype in ipairs({ "nofile", "help", "terminal", "prompt", "quickfix", "acwrite" }) do
    it("skips a '" .. buftype .. "' buffer", function()
      assert.is_false(M.should_autosave(props({ buftype = buftype })))
    end)
  end

  it("skips an unnamed buffer", function()
    assert.is_false(M.should_autosave(props({ name = "" })))
  end)

  it("skips an oil buffer", function()
    assert.is_false(M.should_autosave(props({ name = "oil:///home/x" })))
  end)

  it("skips a terminal-named buffer", function()
    assert.is_false(M.should_autosave(props({ name = "term://./fish" })))
  end)

  it("skips a fugitive buffer", function()
    assert.is_false(M.should_autosave(props({ name = "fugitive:///repo/.git//0/file" })))
  end)
end)
