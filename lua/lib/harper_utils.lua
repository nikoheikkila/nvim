local M = {}

-- harper-ls settings with meaningful non-empty defaults, mirrored from
-- https://writewithharper.com/docs/integrations/neovim. Parsed `config.harper`
-- (config.yml) overrides these per field; a missing/malformed/wrong-typed field
-- keeps the default. Free of vim/os calls so the module stays unit-testable
-- under plain busted, mirroring lib/daily_utils.lua.
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

-- Optional string settings deliberately left out of DEFAULTS: harper-ls has its
-- own sensible locations for these, so we forward one only when the user sets a
-- non-empty string. An empty value in config.yml means "let harper decide".
local OPTIONAL_PATHS = { "userDictPath", "workspaceDictPath", "fileDictPath", "ignoredLintsPath" }

-- Deep-merge `overrides` over `defaults`, accepting an override leaf only when
-- its Lua type matches the default's (recursing into nested maps). This is the
-- daily_utils type-guard generalised: a wrong-typed or absent field silently
-- falls back, so a malformed config.yml never yields an unexpected shape.
local function merge(defaults, overrides)
  if type(overrides) ~= "table" then
    overrides = {}
  end
  local result = {}
  for key, default in pairs(defaults) do
    local override = overrides[key] -- plain index: a `false` override must survive
    if type(default) == "table" then
      result[key] = merge(default, override)
    elseif type(override) == type(default) then
      result[key] = override
    else
      result[key] = default
    end
  end
  return result
end

-- Keep only the string entries of a parsed sequence; returns nil when nothing
-- usable remains so callers can omit the field entirely.
local function string_list(value)
  if type(value) ~= "table" then
    return nil
  end
  local out = {}
  for _, item in ipairs(value) do
    if type(item) == "string" then
      out[#out + 1] = item
    end
  end
  return #out > 0 and out or nil
end

-- Build the table for settings["harper-ls"] from yaml_utils.parse() output
-- (table | nil). Merges config.harper over DEFAULTS, then layers the optional
-- path fields and excludePatterns only when the user supplied usable values —
-- keeping empty ones out so harper-ls falls back to its own defaults.
function M.resolve_config(parsed)
  local harper = type(parsed) == "table" and type(parsed.config) == "table" and parsed.config.harper
  if type(harper) ~= "table" then
    harper = {}
  end
  local settings = merge(DEFAULTS, harper)
  for _, key in ipairs(OPTIONAL_PATHS) do
    if type(harper[key]) == "string" and harper[key] ~= "" then
      settings[key] = harper[key]
    end
  end
  local patterns = string_list(harper.excludePatterns)
  if patterns then
    settings.excludePatterns = patterns
  end
  return settings
end

return M
