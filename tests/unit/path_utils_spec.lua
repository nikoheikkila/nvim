-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.path_utils")

describe("has_uri_scheme", function()
  it("detects oil scheme", function()
    assert.is_true(M.has_uri_scheme("oil:///home/x"))
  end)

  it("detects fugitive scheme", function()
    assert.is_true(M.has_uri_scheme("fugitive:///repo/.git//0/file"))
  end)

  it("detects scp scheme", function()
    assert.is_true(M.has_uri_scheme("scp://host/file"))
  end)

  it("detects term scheme", function()
    assert.is_true(M.has_uri_scheme("term://./fish"))
  end)

  it("detects https scheme", function()
    assert.is_true(M.has_uri_scheme("https://example.com/x"))
  end)

  it("absolute path is not a uri", function()
    assert.is_false(M.has_uri_scheme("/abs/path/file.txt"))
  end)

  it("relative path is not a uri", function()
    assert.is_false(M.has_uri_scheme("relative/file.txt"))
  end)

  it("dot-relative path is not a uri", function()
    assert.is_false(M.has_uri_scheme("./file"))
  end)

  it("home-relative path is not a uri", function()
    assert.is_false(M.has_uri_scheme("~/notes/a.md"))
  end)

  it("bare filename is not a uri", function()
    assert.is_false(M.has_uri_scheme("file.txt"))
  end)

  it("empty string is not a uri", function()
    assert.is_false(M.has_uri_scheme(""))
  end)
end)
