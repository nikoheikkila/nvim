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

  it("parses double-quoted keys with characters the plain pattern rejects", function()
    assert.are.same({ ["@markup.raw.markdown_inline"] = "x" }, M.parse('"@markup.raw.markdown_inline": x\n'))
  end)

  it("parses single-quoted keys", function()
    assert.are.same({ ["a key"] = 1 }, M.parse("'a key': 1\n"))
  end)

  it("parses a quoted key opening a nested map", function()
    local text = 'groups:\n  "@markup.raw.markdown_inline":\n    fg: "#ff7b72"\n    bg: "#2e2e2e"\n'
    assert.are.same({
      groups = { ["@markup.raw.markdown_inline"] = { fg = "#ff7b72", bg = "#2e2e2e" } },
    }, M.parse(text))
  end)

  it("returns nil on an unclosed quoted key", function()
    assert.is_nil(M.parse('"@markup.raw: x\n'))
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

  it("parses a block sequence of strings under a key", function()
    assert.are.same({ plugins = { "one", "two" } }, M.parse("plugins:\n  - one\n  - two\n"))
  end)

  it("coerces sequence item types and strips quotes", function()
    local text = table.concat({
      "items:",
      "  - 1",
      "  - true",
      '  - "a b"',
      "",
    }, "\n")
    assert.are.same({ items = { 1, true, "a b" } }, M.parse(text))
  end)

  it("parses a sequence under a nested key", function()
    local text = 'config:\n  harper:\n    excludePatterns:\n      - "*.min.js"\n      - vendor\n'
    assert.are.same({
      config = { harper = { excludePatterns = { "*.min.js", "vendor" } } },
    }, M.parse(text))
  end)

  it("dedents back to sibling keys after a sequence", function()
    local text = "a:\n  - x\n  - y\nb: 2\n"
    assert.are.same({ a = { "x", "y" }, b = 2 }, M.parse(text))
  end)

  it("does not parse inline flow sequences as lists", function()
    -- Inline [a, b] is unsupported; the value is taken verbatim as a string.
    assert.are.same({ a = "[x, y]" }, M.parse("a: [x, y]\n"))
  end)

  it("returns nil on tab indentation", function()
    assert.is_nil(M.parse("a:\n\tb: 1\n"))
  end)
end)

describe("read_file", function()
  it("returns nil for a missing file", function()
    assert.is_nil(M.read_file("/no/such/path/config.yml"))
  end)

  it("reads and parses an existing file", function()
    local path = os.tmpname()
    local f = assert(io.open(path, "w"))
    f:write("a:\n  - x\n  - y\nb: 2\n")
    f:close()
    assert.are.same({ a = { "x", "y" }, b = 2 }, M.read_file(path))
    os.remove(path)
  end)
end)
