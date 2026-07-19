-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.yaml_utils")

describe("parse", function()
  it("parses a flat key-value map", function()
    assert.are.same({ variant = "github_dark_default" }, M.parse("variant: github_dark_default\n"))
  end)

  it("parses the shipped theme.yml schema with values kept as strings", function()
    local text = table.concat({
      "theme:",
      "  url: projekt0n/github-nvim-theme",
      "  name: github-theme",
      "  variant: github_dark_default",
      "  options:",
      "    styles:",
      "      comments: italic",
      "",
    }, "\n")
    assert.are.same({
      theme = {
        url = "projekt0n/github-nvim-theme",
        name = "github-theme",
        variant = "github_dark_default",
        options = { styles = { comments = "italic" } },
      },
    }, M.parse(text))
  end)

  it("dedents back to parent and top-level siblings after a nested block", function()
    local text = "a:\n  b:\n    c: 1\n  d: 2\ne: 3\n"
    assert.are.same({ a = { b = { c = 1 }, d = 2 }, e = 3 }, M.parse(text))
  end)

  it("skips blank lines and full-line comments", function()
    local text = "# header comment\n\na: 1\n   \n  # indented comment\nb: 2\n"
    assert.are.same({ a = 1, b = 2 }, M.parse(text))
  end)

  it("strips double and single quotes from values", function()
    assert.are.same({ a = "x y", b = "z" }, M.parse("a: \"x y\"\nb: 'z'\n"))
  end)

  it("coerces true and false to booleans", function()
    assert.are.same({ a = true, b = false }, M.parse("a: true\nb: false\n"))
  end)

  it("coerces integers and floats to numbers", function()
    assert.are.same({ priority = 1000, alpha = 0.8 }, M.parse("priority: 1000\nalpha: 0.8\n"))
  end)

  for name, newline in pairs({ LF = "\n", CRLF = "\r\n" }) do
    it("tolerates trailing whitespace and " .. name .. " line endings", function()
      local text = "a: 1  " .. newline .. "b:" .. newline .. "  c: 2 " .. newline
      assert.are.same({ a = 1, b = { c = 2 } }, M.parse(text))
    end)
  end

  it("returns nil for nil input", function()
    assert.is_nil(M.parse(nil))
  end)

  for _, input in ipairs({ 42, true, {} }) do
    it("returns nil for non-string input (" .. type(input) .. ")", function()
      assert.is_nil(M.parse(input))
    end)
  end

  it("returns nil when a line has no key-value shape", function()
    assert.is_nil(M.parse("a: 1\njust some text\n"))
  end)

  it("returns nil for list items (outside the supported subset)", function()
    assert.is_nil(M.parse("plugins:\n  - one\n  - two\n"))
  end)

  it("returns nil on tab indentation", function()
    assert.is_nil(M.parse("a:\n\tb: 1\n"))
  end)
end)
