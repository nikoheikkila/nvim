# Lua Testing Reference

## Busted (Recommended)

```lua
local mymodule = require("mymodule")

describe("mymodule.process", function()
  it("returns ok for valid input", function()
    local result = mymodule.process({ name = "test" })
    assert.are.equal("ok", result.status)
  end)

  it("raises on missing name", function()
    assert.has_error(function() mymodule.process({}) end, "missing required field: name")
  end)
end)
```

## Testing Standards

- Test files: `spec/*_spec.lua` (busted) or `test_*.lua` (luaunit)
- Test names describe behavior: `it("returns nil when file not found")`
- Coverage: >80% for library modules, >60% overall
- Test edge cases: `nil`, empty tables, boundary values, type mismatches
- Run: `busted --verbose`
