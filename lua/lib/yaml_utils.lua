local M = {}

-- Strips one pair of matching quotes (contents returned verbatim), coerces
-- "true"/"false" to booleans and numeric strings to numbers; anything else is
-- returned as the raw string.
local function coerce(value)
  local quoted = value:match('^"(.*)"$') or value:match("^'(.*)'$")
  if quoted then
    return quoted
  end
  if value == "true" then
    return true
  end
  if value == "false" then
    return false
  end
  return tonumber(value) or value
end

-- Parses a minimal YAML subset: nested maps via space indentation,
-- `key: value` scalars, blank lines, and full-line `#` comments (CRLF input is
-- tolerated). Returns a nested table, or nil when the input is not a string or
-- any line falls outside the subset — lists, anchors, multiline scalars,
-- inline {}/[] flow, trailing comments after values, and tab indentation are
-- all unsupported by design, so a malformed document never half-applies.
function M.parse(text)
  if type(text) ~= "string" then
    return nil
  end
  local root = {}
  local stack = { { indent = -1, node = root } } -- open maps, innermost last
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    local skippable = line:match("^%s*$") or line:match("^%s*#")
    if not skippable then
      if line:match("^ *\t") then
        return nil
      end
      local indent = #line:match("^( *)")
      local key, rest = line:match("^ *([%w_%-%.]+): *(.-)%s*$")
      if not key then
        return nil
      end
      while indent <= stack[#stack].indent do
        table.remove(stack)
      end
      local parent = stack[#stack].node
      if rest == "" then
        parent[key] = {}
        stack[#stack + 1] = { indent = indent, node = parent[key] }
      else
        parent[key] = coerce(rest)
      end
    end
  end
  return root
end

return M
