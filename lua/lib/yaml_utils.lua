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
-- `key: value` scalars, block sequences (`- item` lines indented under their
-- key, scalar items only), quoted keys (for characters the plain pattern
-- rejects, e.g. `@` in highlight-group names), blank lines, and full-line `#`
-- comments (CRLF input is tolerated). Returns a nested table, or nil when the
-- input is not a string or any line falls outside the subset — anchors,
-- multiline scalars, inline {}/[] flow, maps nested inside sequence items,
-- trailing comments after values, and tab indentation are all unsupported by
-- design, so a malformed document never half-applies.
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
      -- Close every map/sequence more indented than this line before handling
      -- it. Identical for keys and sequence items (both depend only on indent),
      -- so it runs once here rather than in each branch.
      while indent <= stack[#stack].indent do
        table.remove(stack)
      end
      -- Block-sequence item: `- value`. Checked before the key patterns since a
      -- `- ...` line has no colon and would otherwise fail the key match. Items
      -- are scalars appended to the container the owning `key:` opened; they are
      -- leaves, so no stack frame is pushed (siblings share the same parent).
      local item = line:match("^ *%- +(.-)%s*$")
      if item then
        table.insert(stack[#stack].node, coerce(item))
      else
        local key, rest = line:match('^ *"([^"]+)" *: *(.-)%s*$')
        if not key then
          key, rest = line:match("^ *'([^']+)' *: *(.-)%s*$")
        end
        if not key then
          key, rest = line:match("^ *([%w_%-%.]+): *(.-)%s*$")
        end
        if not key then
          return nil
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
  end
  return root
end

-- Deep-merge `overrides` over `defaults`, accepting an override leaf only when
-- its Lua type matches the default's (recursing into nested maps). This is the
-- per-field type guard every config resolver in lua/lib/ applies, generalised to
-- nested tables: a wrong-typed or absent field silently falls back, so a
-- malformed config.yml never yields an unexpected shape. Lives here rather than
-- in one resolver because harper_utils and vale_utils both need it verbatim.
function M.merge_defaults(defaults, overrides)
  if type(overrides) ~= "table" then
    overrides = {}
  end
  local result = {}
  for key, default in pairs(defaults) do
    local override = overrides[key] -- plain index: a `false` override must survive
    if type(default) == "table" then
      result[key] = M.merge_defaults(default, override)
    elseif type(override) == type(default) then
      result[key] = override
    else
      result[key] = default
    end
  end
  return result
end

-- "Non-empty string wins" — the rule the resolvers apply to their optional
-- string fields and config/paths.lua applies to NVIM_CONFIG_ROOT. An empty
-- value in config.yml means "no answer here", never "the empty string".
function M.non_empty(value, fallback)
  if type(value) == "string" and value ~= "" then
    return value
  end
  return fallback
end

-- Resolve one `config.<name>` section of a parsed config.yml into a settings
-- table: merge the section over `defaults`, then layer each key in
-- `optional_strings` only when the user supplied a non-empty string for it.
--
-- That last rule is what keeps a server on its own default: an empty value in
-- config.yml means "no answer here", so the key is left out of the result
-- entirely rather than forwarded as "". Returns the settings table and the raw
-- section, the latter for callers with a field that does not fit this shape
-- (harper's excludePatterns list).
--
-- The whole contract — where sections live, what a wrong type does, what an
-- empty string means — lives here so harper_utils and vale_utils cannot drift
-- apart on it.
function M.resolve_section(parsed, name, defaults, optional_strings)
  local section = type(parsed) == "table" and type(parsed.config) == "table" and parsed.config[name]
  if type(section) ~= "table" then
    section = {}
  end
  local settings = M.merge_defaults(defaults, section)
  for _, key in ipairs(optional_strings or {}) do
    if type(section[key]) == "string" and section[key] ~= "" then
      settings[key] = section[key]
    end
  end
  return settings, section
end

-- Reads the YAML file at `path` and returns M.parse of its contents, or nil
-- when the file is missing/unreadable (so callers fall back to their defaults).
-- The caller passes an absolute path — it owns the vim.fn.stdpath lookup — so
-- this stays free of vim APIs and unit-testable with a temp file. Shared by
-- config/commands.lua, config/lsp_servers.lua, and plugins/theme.lua.
function M.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return M.parse(text)
end

return M
