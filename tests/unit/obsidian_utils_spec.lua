-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.obsidian_utils")
local yaml_utils = require("lib.yaml_utils")

local DEFAULTS = {
  vault = "$HOME/Vaults",
  dailyNotes = { folder = "000 - Inbox/Journal", dateFormat = "YYYY-MM-DD" },
}

describe("resolve_config", function()
  it("reads the shipped config.yml schema", function()
    local text = table.concat({
      "config:",
      "  obsidian:",
      '    vault: "$HOME/Vaults"',
      "    dailyNotes:",
      '      folder: "000 - Inbox/Journal"',
      '      dateFormat: "YYYY-MM-DD"',
      "",
    }, "\n")
    assert.are.same(DEFAULTS, M.resolve_config(yaml_utils.parse(text)))
  end)

  it("honors custom values", function()
    local text = table.concat({
      "config:",
      "  obsidian:",
      '    vault: "/srv/notes"',
      "    dailyNotes:",
      '      folder: "Journal/Daily"',
      '      dateFormat: "YYYY/MM/DD"',
      "",
    }, "\n")
    assert.are.same({
      vault = "/srv/notes",
      dailyNotes = { folder = "Journal/Daily", dateFormat = "YYYY/MM/DD" },
    }, M.resolve_config(yaml_utils.parse(text)))
  end)

  it("keeps a quoted numeric-looking folder a string", function()
    -- yaml_utils.coerce() turns bare numerics into numbers; the shipped folder
    -- starts with "000", so it must stay quoted in config.yml to survive.
    local parsed = yaml_utils.parse('config:\n  obsidian:\n    dailyNotes:\n      folder: "000 - Inbox"\n')
    assert.are.equal("000 - Inbox", M.resolve_config(parsed).dailyNotes.folder)
  end)

  it("falls back to defaults for nil input", function()
    assert.are.same(DEFAULTS, M.resolve_config(nil))
  end)

  it("falls back to defaults when config.obsidian is absent", function()
    assert.are.same(DEFAULTS, M.resolve_config({ config = {} }))
    assert.are.same(DEFAULTS, M.resolve_config({ other = true }))
  end)

  it("fills only the missing fields on a partial config", function()
    local only_vault = M.resolve_config({ config = { obsidian = { vault = "/tmp/v" } } })
    assert.are.same({ vault = "/tmp/v", dailyNotes = DEFAULTS.dailyNotes }, only_vault)

    local only_folder = M.resolve_config({ config = { obsidian = { dailyNotes = { folder = "Log" } } } })
    assert.are.same({
      vault = DEFAULTS.vault,
      dailyNotes = { folder = "Log", dateFormat = DEFAULTS.dailyNotes.dateFormat },
    }, only_folder)
  end)

  it("ignores wrong-typed fields and uses defaults", function()
    local parsed = { config = { obsidian = { vault = 42, dailyNotes = { folder = {}, dateFormat = false } } } }
    assert.are.same(DEFAULTS, M.resolve_config(parsed))
  end)

  it("ignores a wrong-typed dailyNotes table", function()
    assert.are.same(DEFAULTS, M.resolve_config({ config = { obsidian = { dailyNotes = "nope" } } }))
  end)

  it("treats empty strings as unset", function()
    local parsed = { config = { obsidian = { vault = "", dailyNotes = { folder = "", dateFormat = "" } } } }
    assert.are.same(DEFAULTS, M.resolve_config(parsed))
  end)
end)

describe("workspaces", function()
  it("returns a single workspace named after the vault's last path segment", function()
    assert.are.same({ { name = "Vaults", path = "/Users/x/Vaults" } }, M.workspaces("/Users/x/Vaults"))
  end)

  it("ignores trailing slashes when deriving the name", function()
    assert.are.same({ { name = "Vaults", path = "/Users/x/Vaults//" } }, M.workspaces("/Users/x/Vaults//"))
  end)

  it("keeps spaces in the vault name", function()
    assert.are.equal("My Vault", M.workspaces("/Users/x/My Vault")[1].name)
  end)

  it("handles a relative single-segment path", function()
    assert.are.same({ { name = "notes", path = "notes" } }, M.workspaces("notes"))
  end)

  it("falls back to a placeholder name for degenerate paths", function()
    assert.are.equal("vault", M.workspaces("/")[1].name)
    assert.are.equal("vault", M.workspaces("")[1].name)
  end)
end)
