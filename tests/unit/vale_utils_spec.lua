-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.vale_utils")
local yaml_utils = require("lib.yaml_utils")

-- Mirror of vale_utils' internal defaults. The optional strings (configPath,
-- valeBinaryPath, filter) are deliberately absent: vale-ls falls back to its own
-- behaviour for each, so forwarding an empty one would be a lie.
local DEFAULTS = {
  installVale = false,
  syncOnStartup = false,
  lintOnChange = true,
  debounceMs = 300,
  showMetrics = true,
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
      "  vale:",
      '    configPath: "$HOME/.vale.ini"',
      "    lintOnChange: false",
      "    debounceMs: 750",
      "    filter: \".Level in ['warning', 'error']\"",
      '    valeBinaryPath: ""',
      "    installVale: true",
      "    syncOnStartup: true",
      "    showMetrics: false",
    }, "\n")
    local settings = M.resolve_config(yaml_utils.parse(text))

    assert.equal("$HOME/.vale.ini", settings.configPath)
    assert.is_false(settings.lintOnChange)
    assert.equal(750, settings.debounceMs)
    -- Quoted values survive verbatim; the brackets and inner quotes are what a
    -- real filter expression looks like.
    assert.equal(".Level in ['warning', 'error']", settings.filter)
    assert.is_true(settings.installVale)
    assert.is_true(settings.syncOnStartup)
    assert.is_false(settings.showMetrics)
    -- Empty means "let vale-ls decide", so the key must not be forwarded at all.
    assert.is_nil(settings.valeBinaryPath)
  end)

  it("keeps the default when an override has the wrong type", function()
    local settings = M.resolve_config({
      config = { vale = { lintOnChange = "yes", debounceMs = "soon", showMetrics = {} } },
    })
    assert.is_true(settings.lintOnChange)
    assert.equal(300, settings.debounceMs)
    assert.is_true(settings.showMetrics)
  end)

  it("accepts a false override rather than treating it as absent", function()
    local settings = M.resolve_config({ config = { vale = { lintOnChange = false } } })
    assert.is_false(settings.lintOnChange)
  end)

  it("ignores a non-table vale section", function()
    assert.are.same(DEFAULTS, M.resolve_config({ config = { vale = "on" } }))
  end)

  it("drops empty optional strings and keeps non-empty ones", function()
    local settings = M.resolve_config({
      config = { vale = { configPath = "", valeBinaryPath = "/opt/bin/vale", filter = "" } },
    })
    assert.is_nil(settings.configPath)
    assert.equal("/opt/bin/vale", settings.valeBinaryPath)
    assert.is_nil(settings.filter)
  end)

  it("ignores a wrong-typed optional string", function()
    local settings = M.resolve_config({ config = { vale = { configPath = 42 } } })
    assert.is_nil(settings.configPath)
  end)
end)

describe("OPTIONAL_PATHS", function()
  -- config/lsp_servers.lua runs vim.fn.expand over exactly these; `filter` is an
  -- expression, and expanding it would mangle the brackets.
  it("names the path options and nothing else", function()
    assert.are.same({ "configPath", "valeBinaryPath" }, M.OPTIONAL_PATHS)
  end)
end)

describe("styles_path", function()
  it("returns the declared StylesPath", function()
    assert.equal("vale-styles", M.styles_path("StylesPath = vale-styles\nMinAlertLevel = suggestion\n"))
  end)

  it("tolerates surrounding whitespace and no spaces around the equals sign", function()
    assert.equal("styles", M.styles_path("  StylesPath=styles  \n"))
  end)

  it("strips one pair of surrounding quotes", function()
    assert.equal("my styles", M.styles_path('StylesPath = "my styles"\n'))
  end)

  it("returns nil when the file declares none", function()
    assert.is_nil(M.styles_path("MinAlertLevel = suggestion\n\n[*.md]\nBasedOnStyles = Vale\n"))
  end)

  it("skips commented-out declarations", function()
    assert.is_nil(M.styles_path("# StylesPath = styles\n; StylesPath = other\n"))
    assert.equal("real", M.styles_path("; StylesPath = commented\nStylesPath = real\n"))
  end)

  it("stops at the first section header", function()
    -- StylesPath is a global-section key; anything under a [format] section that
    -- looks like one is not one.
    assert.is_nil(M.styles_path("MinAlertLevel = suggestion\n[*.md]\nStylesPath = nope\n"))
  end)

  it("ignores an empty value and non-string input", function()
    assert.is_nil(M.styles_path("StylesPath =\n"))
    assert.is_nil(M.styles_path(nil))
    assert.is_nil(M.styles_path(42))
  end)

  it("tolerates CRLF line endings", function()
    assert.equal("styles", M.styles_path("StylesPath = styles\r\nMinAlertLevel = suggestion\r\n"))
  end)
end)
