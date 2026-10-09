-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.search_replace_utils")
local yaml_utils = require("lib.yaml_utils")

describe("resolve_config", function()
  it("returns the defaults for nil / missing section", function()
    assert.are.same({ width = 0.8, height = 0.8 }, M.resolve_config(nil))
    assert.are.same(M.DEFAULTS, M.resolve_config({ config = {} }))
    assert.are.same(M.DEFAULTS, M.resolve_config({ other = true }))
  end)

  it("reads the shipped config.yml schema through the parser", function()
    local parsed = yaml_utils.parse(table.concat({
      "config:",
      "  searchReplace:",
      "    width: 0.5",
      "    height: 0.6",
    }, "\n"))

    assert.are.same({ width = 0.5, height = 0.6 }, M.resolve_config(parsed))
  end)

  it("overrides one field and keeps the default for the other", function()
    local settings = M.resolve_config({ config = { searchReplace = { width = 1 } } })

    assert.are.same({ width = 1, height = 0.8 }, settings)
  end)

  it("falls back per field on a wrong type", function()
    local settings = M.resolve_config({ config = { searchReplace = { width = "wide", height = true } } })

    assert.are.same(M.DEFAULTS, settings)
  end)

  it("falls back per field on an out-of-range ratio", function()
    assert.are.same(M.DEFAULTS, M.resolve_config({ config = { searchReplace = { width = 0, height = -0.5 } } }))
    assert.are.same(M.DEFAULTS, M.resolve_config({ config = { searchReplace = { width = 1.5, height = 2 } } }))
  end)

  it("does not hand out the shared DEFAULTS table", function()
    M.resolve_config(nil).width = 0.1

    assert.are.equal(0.8, M.DEFAULTS.width)
  end)
end)

describe("float_geometry", function()
  it("centres the outer box and subtracts the border from the inner size", function()
    local geometry = M.float_geometry(100, 50, { width = 0.8, height = 0.8 })

    -- outer 80x40, inner 78x38, (100-80)/2 = 10 and (50-40)/2 = 5 cells of margin
    assert.are.same({ width = 78, height = 38, col = 10, row = 5 }, geometry)
  end)

  it("floors fractional cells", function()
    local geometry = M.float_geometry(101, 33, { width = 0.5, height = 0.5 })

    -- outer floor(50.5) = 50 x floor(16.5) = 16; margins floor(51/2) = 25, floor(17/2) = 8
    assert.are.same({ width = 48, height = 14, col = 25, row = 8 }, geometry)
  end)

  it("fills the editor at ratio 1", function()
    local geometry = M.float_geometry(80, 24, { width = 1, height = 1 })

    assert.are.same({ width = 78, height = 22, col = 0, row = 0 }, geometry)
  end)

  it("never returns a window smaller than one cell", function()
    local geometry = M.float_geometry(2, 2, { width = 0.1, height = 0.1 })

    assert.are.equal(1, geometry.width)
    assert.are.equal(1, geometry.height)
  end)
end)
