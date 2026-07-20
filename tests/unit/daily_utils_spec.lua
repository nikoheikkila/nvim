-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.daily_utils")
local yaml_utils = require("lib.yaml_utils")

local DEFAULTS = { directory = "$HOME/Notes", filenamePattern = "%Y-%m-%d.md" }

describe("resolve_config", function()
  it("reads directory and filenamePattern from the shipped config.yml schema", function()
    local text = table.concat({
      "config:",
      "  daily:",
      '    directory: "$HOME/Notes"',
      '    filenamePattern: "%Y-%m-%d.md"',
      "",
    }, "\n")
    assert.are.same(
      { directory = "$HOME/Notes", filenamePattern = "%Y-%m-%d.md" },
      M.resolve_config(yaml_utils.parse(text))
    )
  end)

  it("honors custom values", function()
    local text = 'config:\n  daily:\n    directory: "/var/notes"\n    filenamePattern: "%Y/%m/%d.md"\n'
    assert.are.same(
      { directory = "/var/notes", filenamePattern = "%Y/%m/%d.md" },
      M.resolve_config(yaml_utils.parse(text))
    )
  end)

  it("falls back to defaults for nil input", function()
    assert.are.same(DEFAULTS, M.resolve_config(nil))
  end)

  it("falls back to defaults when config.daily is absent", function()
    assert.are.same(DEFAULTS, M.resolve_config({ config = {} }))
    assert.are.same(DEFAULTS, M.resolve_config({ other = true }))
  end)

  it("fills only the missing field on a partial config", function()
    local only_dir = M.resolve_config({ config = { daily = { directory = "/tmp/n" } } })
    assert.are.same({ directory = "/tmp/n", filenamePattern = DEFAULTS.filenamePattern }, only_dir)

    local only_pat = M.resolve_config({ config = { daily = { filenamePattern = "%Y.md" } } })
    assert.are.same({ directory = DEFAULTS.directory, filenamePattern = "%Y.md" }, only_pat)
  end)

  it("ignores wrong-typed fields and uses defaults", function()
    local parsed = { config = { daily = { directory = {}, filenamePattern = 42 } } }
    assert.are.same(DEFAULTS, M.resolve_config(parsed))
  end)
end)

describe("effective_directory", function()
  local cfg = { directory = "$HOME/Notes", filenamePattern = "%Y-%m-%d.md" }

  it("uses the env override when set and non-empty", function()
    assert.are.equal("/tmp/override", M.effective_directory(cfg, "/tmp/override"))
  end)

  it("uses the config directory when the env value is nil", function()
    assert.are.equal("$HOME/Notes", M.effective_directory(cfg, nil))
  end)

  it("uses the config directory when the env value is empty", function()
    assert.are.equal("$HOME/Notes", M.effective_directory(cfg, ""))
  end)
end)
