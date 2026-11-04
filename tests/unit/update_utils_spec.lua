-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.update_utils")
local yaml_utils = require("lib.yaml_utils")

describe("parse", function()
  it("reads a plain CalVer tag with a zero counter", function()
    assert.are.same({ 2026, 11, 3, 0 }, M.parse("2026.11.03"))
  end)

  it("reads the same-day counter suffix", function()
    assert.are.same({ 2026, 11, 3, 12 }, M.parse("2026.11.03.12"))
  end)

  it("rejects anything else", function()
    for _, tag in ipairs({ "dev", "", "v2026.11.03", "2026.11.3", "2026.11.03.", "2026.11.03.x", "2026.11.03-rc" }) do
      assert.is_nil(M.parse(tag), tag)
    end
    assert.is_nil(M.parse(nil))
    assert.is_nil(M.parse(20261103))
  end)
end)

describe("is_newer", function()
  it("orders by date, then by counter", function()
    assert.is_true(M.is_newer("2026.11.10", "2026.11.03"))
    assert.is_true(M.is_newer("2026.11.03.1", "2026.11.03"))
    assert.is_true(M.is_newer("2026.11.03.10", "2026.11.03.9"))
    assert.is_true(M.is_newer("2027.01.01", "2026.12.31.4"))
  end)

  it("is false for the same or an older version", function()
    assert.is_false(M.is_newer("2026.11.03", "2026.11.03"))
    assert.is_false(M.is_newer("2026.11.03", "2026.11.03.1"))
    assert.is_false(M.is_newer("2026.10.31", "2026.11.03"))
  end)

  it("treats an unstamped install as outdated", function()
    assert.is_true(M.is_newer("2026.11.03", "dev"))
    assert.is_true(M.is_newer("2026.11.03", nil))
  end)

  it("never installs a latest that does not parse", function()
    assert.is_false(M.is_newer("latest", "2026.11.03"))
    assert.is_false(M.is_newer(nil, nil))
  end)
end)

describe("tag_from_url", function()
  it("reads the tag releases/latest redirects to", function()
    assert.equal("2026.11.03.1", M.tag_from_url("https://github.com/nikoheikkila/nvim/releases/tag/2026.11.03.1"))
  end)

  it("tolerates trailing whitespace from curl's -w output", function()
    assert.equal("2026.11.03", M.tag_from_url("https://github.com/o/r/releases/tag/2026.11.03\n"))
  end)

  it("is nil when there is no release to redirect to", function()
    -- A repository without releases leaves releases/latest on the list page.
    assert.is_nil(M.tag_from_url("https://github.com/o/r/releases"))
    assert.is_nil(M.tag_from_url("https://github.com/o/r/releases/tag/nightly"))
    assert.is_nil(M.tag_from_url(nil))
  end)
end)

describe("changes_url", function()
  it("compares against the installed release", function()
    assert.equal(
      "https://github.com/o/r/compare/2026.11.03...2026.11.10",
      M.changes_url("o/r", "2026.11.03", "2026.11.10")
    )
  end)

  it("falls back to the release page without a known starting point", function()
    assert.equal("https://github.com/o/r/releases/tag/2026.11.10", M.changes_url("o/r", nil, "2026.11.10"))
    assert.equal("https://github.com/o/r/releases/tag/2026.11.10", M.changes_url("o/r", "dev", "2026.11.10"))
  end)
end)

describe("should_check", function()
  local day = M.CHECK_INTERVAL

  it("is due without a previous check", function()
    assert.is_true(M.should_check(nil, 1000, day))
    assert.is_true(M.should_check("yesterday", 1000, day))
  end)

  it("waits a full interval", function()
    assert.is_false(M.should_check(1000, 1000 + day - 1, day))
    assert.is_true(M.should_check(1000, 1000 + day, day))
  end)

  it("is due when the timestamp lies in the future", function()
    assert.is_true(M.should_check(5000, 1000, day))
  end)
end)

describe("resolve_config", function()
  it("checks on startup by default", function()
    assert.are.same({ checkOnStartup = true }, M.resolve_config(nil))
    assert.are.same({ checkOnStartup = true }, M.resolve_config({ config = {} }))
  end)

  it("reads the shipped config.yml schema through the parser", function()
    local parsed = yaml_utils.parse(table.concat({
      "config:",
      "  updates:",
      "    checkOnStartup: false",
    }, "\n"))

    assert.are.same({ checkOnStartup = false }, M.resolve_config(parsed))
  end)

  it("falls back on a wrong type", function()
    assert.are.same({ checkOnStartup = true }, M.resolve_config({ config = { updates = { checkOnStartup = "no" } } }))
  end)
end)

describe("carry_over", function()
  it("always carries the user files", function()
    assert.are.same(M.USER_FILES, M.carry_over(nil))
  end)

  it("adds a StylesPath inside the config root", function()
    local paths = M.carry_over("vale-styles")
    assert.equal("vale-styles", paths[#paths])
    assert.equal(#M.USER_FILES + 1, #paths)
  end)

  it("normalises a leading ./ and a trailing slash", function()
    local paths = M.carry_over("./styles/vale/")
    assert.equal("styles/vale", paths[#paths])
  end)

  it("skips a StylesPath outside the config root", function()
    for _, styles in ipairs({ "/abs/styles", "../styles", "a/../../b", "~/styles", "$HOME/styles", ".", "" }) do
      assert.are.same(M.USER_FILES, M.carry_over(styles), styles)
    end
  end)
end)
