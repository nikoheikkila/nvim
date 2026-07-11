-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.search_utils")

describe("matches", function()
  it("finds exact substring", function()
    assert.is_true(M.matches("hello world", "world"))
  end)

  it("is case-insensitive", function()
    assert.is_true(M.matches("Hello World", "world"))
  end)

  it("matches uppercase term against lowercase line", function()
    assert.is_true(M.matches("hello world", "WORLD"))
  end)

  it("returns false when term is absent", function()
    assert.is_false(M.matches("hello world", "xyz"))
  end)

  it("returns false for empty term", function()
    assert.is_false(M.matches("hello world", ""))
  end)

  it("empty line only matches empty haystack, never a real term", function()
    assert.is_false(M.matches("", "world"))
  end)

  it("matches substring at start", function()
    assert.is_true(M.matches("hello world", "hello"))
  end)

  it("matches whole line", function()
    assert.is_true(M.matches("hello", "hello"))
  end)

  it("treats term as a literal substring, not a Lua pattern", function()
    assert.is_false(M.matches("hello world", "h.l."))
  end)
end)
