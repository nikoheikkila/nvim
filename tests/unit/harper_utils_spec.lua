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
