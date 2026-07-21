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

describe("classify_link", function()
  it("https is external", function()
    assert.are.equal(M.classify_link("https://example.com/x"), "external")
  end)

  it("http is external", function()
    assert.are.equal(M.classify_link("http://example.com"), "external")
  end)

  it("ftp with slashes is external", function()
    assert.are.equal(M.classify_link("ftp://host/file"), "external")
  end)

  it("mailto is ignored", function()
    assert.are.equal(M.classify_link("mailto:x@y.com"), "ignored")
  end)

  it("tel is ignored", function()
    assert.are.equal(M.classify_link("tel:+123456"), "ignored")
  end)

  it("bare anchor is ignored", function()
    assert.are.equal(M.classify_link("#section"), "ignored")
  end)

  it("bare filename is internal", function()
    assert.are.equal(M.classify_link("notes.md"), "internal")
  end)

  it("dot-relative path is internal", function()
    assert.are.equal(M.classify_link("./a.md"), "internal")
  end)

  it("absolute path is internal", function()
    assert.are.equal(M.classify_link("/abs/x.md"), "internal")
  end)

  it("subdirectory path is internal", function()
    assert.are.equal(M.classify_link("img/p.png"), "internal")
  end)

  it("file with anchor is internal", function()
    assert.are.equal(M.classify_link("notes.md#section"), "internal")
  end)
end)

describe("strip_anchor", function()
  it("strips a trailing anchor", function()
    assert.are.equal(M.strip_anchor("notes.md#section"), "notes.md")
  end)

  it("leaves a target without an anchor unchanged", function()
    assert.are.equal(M.strip_anchor("notes.md"), "notes.md")
  end)

  it("strips a bare anchor to empty", function()
    assert.are.equal(M.strip_anchor("#section"), "")
  end)
end)
