-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.harper_utils")
local yaml_utils = require("lib.yaml_utils")

-- Mirror of harper_utils' internal defaults (fields with meaningful values).
local DEFAULTS = {
  linters = {
    SpellCheck = true,
    SpelledNumbers = false,
    AnA = true,
    SentenceCapitalization = true,
    UnclosedQuotes = true,
    WrongApostrophe = false,
    LongSentences = true,
    RepeatedWords = true,
    Spaces = true,
    CorrectNumberSuffix = true,
  },
  codeActions = { ForceStable = false },
  markdown = { IgnoreLinkTitle = false },
  diagnosticSeverity = "hint",
  isolateEnglish = false,
  dialect = "American",
  maxFileLength = 120000,
}

describe("resolve_config", function()
  it("returns the defaults for nil / missing section", function()
    assert.are.same(DEFAULTS, M.resolve_config(nil))
    assert.are.same(DEFAULTS, M.resolve_config({ config = {} }))
    assert.are.same(DEFAULTS, M.resolve_config({ other = true }))
  end)

  it("reads the shipped config.yml schema through the parser", function()
    local text = table.concat({
      "config:",
      "  harper:",
      '    dialect: "British"',
      '    diagnosticSeverity: "warning"',
      "    isolateEnglish: true",
      "    maxFileLength: 5000",
      "    codeActions:",
      "      ForceStable: true",
      "    markdown:",
      "      IgnoreLinkTitle: true",
      "    linters:",
      "      SpellCheck: false",
      "      LongSentences: false",
      "",
    }, "\n")
    local settings = M.resolve_config(yaml_utils.parse(text))
    assert.are.equal("British", settings.dialect)
    assert.are.equal("warning", settings.diagnosticSeverity)
    assert.is_true(settings.isolateEnglish)
    assert.are.equal(5000, settings.maxFileLength)
    assert.is_true(settings.codeActions.ForceStable)
    assert.is_true(settings.markdown.IgnoreLinkTitle)
    -- Overridden linters take the new value; unspecified ones keep the default.
    assert.is_false(settings.linters.SpellCheck)
    assert.is_false(settings.linters.LongSentences)
    assert.is_true(settings.linters.AnA)
  end)

  it("ignores wrong-typed fields and keeps defaults", function()
    local parsed = { config = { harper = { dialect = 42, maxFileLength = "big", linters = "nope" } } }
    local settings = M.resolve_config(parsed)
    assert.are.equal("American", settings.dialect)
    assert.are.equal(120000, settings.maxFileLength)
    assert.are.same(DEFAULTS.linters, settings.linters)
  end)

  it("forwards a non-empty path field and omits empty/unset ones", function()
    local settings = M.resolve_config({
      config = { harper = { userDictPath = "/home/me/dict.txt", workspaceDictPath = "" } },
    })
    assert.are.equal("/home/me/dict.txt", settings.userDictPath)
    assert.is_nil(settings.workspaceDictPath)
    assert.is_nil(settings.fileDictPath)
  end)

  it("includes excludePatterns only when it is a non-empty string list", function()
    local with = M.resolve_config({ config = { harper = { excludePatterns = { "*.min.js", "vendor" } } } })
    assert.are.same({ "*.min.js", "vendor" }, with.excludePatterns)

    -- Empty list and non-list values are dropped.
    assert.is_nil(M.resolve_config({ config = { harper = { excludePatterns = {} } } }).excludePatterns)
    assert.is_nil(M.resolve_config({ config = { harper = { excludePatterns = "x" } } }).excludePatterns)
  end)

  it("keeps only string entries of excludePatterns", function()
    local settings = M.resolve_config({ config = { harper = { excludePatterns = { "a", 1, true, "b" } } } })
    assert.are.same({ "a", "b" }, settings.excludePatterns)
  end)

  it("round-trips excludePatterns from a parsed block sequence", function()
    local text = 'config:\n  harper:\n    excludePatterns:\n      - "*.min.js"\n      - vendor\n'
    assert.are.same({ "*.min.js", "vendor" }, M.resolve_config(yaml_utils.parse(text)).excludePatterns)
  end)
end)

describe("quick_fix_position", function()
  -- One span on line 2, covering columns 25..39 (end_col is exclusive).
  local function span(lnum, col, end_col)
    return { lnum = lnum, col = col, end_lnum = lnum, end_col = end_col }
  end

  local spans = { span(2, 25, 40) }

  it("stays on the cursor when it is inside a span", function()
    assert.is_nil(M.quick_fix_position({ lnum = 2, col = 30 }, spans))
  end)

  it("stays on the cursor at the span's first column", function()
    assert.is_nil(M.quick_fix_position({ lnum = 2, col = 25 }, spans))
  end)

  it("stays on the cursor at the last column of the span", function()
    assert.is_nil(M.quick_fix_position({ lnum = 2, col = 39 }, spans))
  end)

  it("snaps from the left of the only span on the line", function()
    assert.are.same({ lnum = 2, col = 25 }, M.quick_fix_position({ lnum = 2, col = 0 }, spans))
  end)

  it("snaps from the right of the only span on the line", function()
    assert.are.same({ lnum = 2, col = 25 }, M.quick_fix_position({ lnum = 2, col = 80 }, spans))
  end)

  -- end_col itself is one past the word: harper-ls returns zero actions there,
  -- so it must snap rather than be treated as inside the span.
  it("snaps when the cursor sits on the exclusive end column", function()
    assert.are.same({ lnum = 2, col = 25 }, M.quick_fix_position({ lnum = 2, col = 40 }, spans))
  end)

  it("picks the nearer of two spans on the line", function()
    local two = { span(2, 10, 15), span(2, 90, 99) }
    assert.are.same({ lnum = 2, col = 90 }, M.quick_fix_position({ lnum = 2, col = 80 }, two))
    assert.are.same({ lnum = 2, col = 10 }, M.quick_fix_position({ lnum = 2, col = 20 }, two))
  end)

  it("picks the leftmost span when two are equidistant", function()
    -- Cursor at 20: three columns past the first span's last column (17), and
    -- three columns short of the second span's start.
    local two = { span(2, 10, 18), span(2, 23, 30) }
    assert.are.same({ lnum = 2, col = 10 }, M.quick_fix_position({ lnum = 2, col = 20 }, two))
  end)

  it("ignores spans on other lines", function()
    assert.is_nil(M.quick_fix_position({ lnum = 5, col = 30 }, spans))
  end)

  it("returns nil when there is nothing to snap to", function()
    assert.is_nil(M.quick_fix_position({ lnum = 2, col = 0 }, {}))
  end)

  it("treats a multi-line span as covering the lines between its ends", function()
    local wide = { { lnum = 1, col = 40, end_lnum = 3, end_col = 5 } }
    assert.is_nil(M.quick_fix_position({ lnum = 2, col = 0 }, wide))
  end)
end)

describe("user_dict_path", function()
  it("uses harper's macOS default", function()
    assert.are.equal(
      "/Users/me/Library/Application Support/harper-ls/dictionary.txt",
      M.user_dict_path({ mac = true, home = "/Users/me" })
    )
  end)

  it("uses XDG_CONFIG_HOME off macOS", function()
    assert.are.equal(
      "/home/me/xdg/harper-ls/dictionary.txt",
      M.user_dict_path({ home = "/home/me", xdg_config_home = "/home/me/xdg" })
    )
  end)

  it("falls back to ~/.config when XDG_CONFIG_HOME is unset or empty", function()
    assert.are.equal("/home/me/.config/harper-ls/dictionary.txt", M.user_dict_path({ home = "/home/me" }))
    assert.are.equal(
      "/home/me/.config/harper-ls/dictionary.txt",
      M.user_dict_path({ home = "/home/me", xdg_config_home = "" })
    )
  end)

  it("prefers a configured path on every platform", function()
    assert.are.equal("/dict.txt", M.user_dict_path({ configured = "/dict.txt", mac = true, home = "/Users/me" }))
    assert.are.equal("/dict.txt", M.user_dict_path({ configured = "/dict.txt", home = "/home/me" }))
  end)

  it("treats an empty configured path as unset", function()
    assert.are.equal(
      "/Users/me/Library/Application Support/harper-ls/dictionary.txt",
      M.user_dict_path({ configured = "", mac = true, home = "/Users/me" })
    )
  end)
end)

describe("workspace_dict_path", function()
  it("defaults to .harper-dictionary.txt in the root", function()
    assert.are.equal("/repo/.harper-dictionary.txt", M.workspace_dict_path({ root = "/repo" }))
  end)

  it("prefers a configured path", function()
    assert.are.equal("/ws.txt", M.workspace_dict_path({ configured = "/ws.txt", root = "/repo" }))
    assert.are.equal("/repo/.harper-dictionary.txt", M.workspace_dict_path({ configured = "", root = "/repo" }))
  end)
end)
