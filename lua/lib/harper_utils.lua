local M = {}

-- harper-ls settings with meaningful non-empty defaults, mirrored from
-- https://writewithharper.com/docs/integrations/neovim. Parsed `config.harper`
-- (config.yml) overrides these per field; a missing/malformed/wrong-typed field
-- keeps the default. Free of vim/os calls so the module stays unit-testable
-- under plain busted, like every other resolver in lua/lib/.
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
-- `userDictPath`/`workspaceDictPath` name a file; `fileDictPath`/
-- `ignoredLintsPath` name a directory. harper-ls's fifth path option, statsPath,
-- is deliberately absent: upstream's config.rs assigns it to `file_dict_path`,
-- so setting it silently relocates the file-local dictionaries instead.
--
-- Exported because config/lsp_servers.lua has to expand these with vim.fn.expand
-- (this module stays vim-free) and would otherwise repeat the list: a fifth path
-- option added here but missed there would be read from config.yml and silently
-- left unexpanded.
M.OPTIONAL_PATHS = { "userDictPath", "workspaceDictPath", "fileDictPath", "ignoredLintsPath" }

-- Deep-merge `overrides` over `defaults`, accepting an override leaf only when
-- its Lua type matches the default's (recursing into nested maps). This is the
-- per-field type guard the other resolvers apply, generalised to nested tables:
-- a wrong-typed or absent field silently falls back, so a malformed config.yml
-- never yields an unexpected shape.
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
  for _, key in ipairs(M.OPTIONAL_PATHS) do
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

-- Is (lnum, col) inside `span`? end_col is exclusive, matching both
-- vim.diagnostic and harper-ls: a request one column past a span gets no code
-- actions at all.
local function covers(span, lnum, col)
  local after_start = span.lnum < lnum or (span.lnum == lnum and span.col <= col)
  local before_end = span.end_lnum > lnum or (span.end_lnum == lnum and span.end_col > col)
  return after_start and before_end
end

-- Columns between the cursor and a span on the same line.
local function distance(span, col)
  if col < span.col then
    return span.col - col
  end
  return col - (span.end_col - 1)
end

-- harper-ls answers textDocument/codeAction only when the requested range sits
-- INSIDE a lint span. Measured against harper-ls 2.6.0 on a span at cols 25-40:
-- an empty range anywhere from col 25 to col 39 returns the five actions, while
-- col 40 (the exclusive end), the whole line, and col 0->40 all return nothing —
-- a range *containing* the span does not count. So offering the dictionary
-- actions with the cursor merely on the offending line means snapping the
-- request into a span here, client-side.
--
-- `cursor` is { lnum, col }: 0-indexed row, 0-indexed byte column. `spans` are
-- Harper's diagnostics as { lnum, col, end_lnum, end_col }, i.e. straight out of
-- vim.diagnostic.get(). Returns the position to request from, or nil to leave the
-- request on the cursor — either because it already sits inside a span, or
-- because this line has no Harper span to snap to. Snap candidates are the spans
-- starting on the cursor's own line, so the request never jumps to another line.
function M.quick_fix_position(cursor, spans)
  local best, best_distance
  for _, span in ipairs(spans) do
    if covers(span, cursor.lnum, cursor.col) then
      return nil -- already on a flagged word
    end
    if span.lnum == cursor.lnum then
      local away = distance(span, cursor.col)
      -- Strict `<` keeps the leftmost span on a tie, so the pick is deterministic.
      if not best_distance or away < best_distance then
        best, best_distance = span, away
      end
    end
  end
  return best and { lnum = best.lnum, col = best.col } or nil
end

-- "Non-empty string wins", the rule resolve_config applies to the path fields
-- and config/paths.lua applies to NVIM_CONFIG_ROOT.
local function non_empty(value, fallback)
  if type(value) == "string" and value ~= "" then
    return value
  end
  return fallback
end

-- Where harper-ls keeps the user dictionary when config.yml leaves the path
-- empty: dirs::config_dir()/harper-ls/dictionary.txt, which is
-- ~/Library/Application Support on macOS and $XDG_CONFIG_HOME (or ~/.config)
-- elsewhere. Platform facts arrive as plain values in `opts`
-- ({ configured, mac, home, xdg_config_home }) so this stays vim-free.
function M.user_dict_path(opts)
  opts = type(opts) == "table" and opts or {}
  local home = opts.home or ""
  local config_home = opts.mac and (home .. "/Library/Application Support")
    or non_empty(opts.xdg_config_home, home .. "/.config")
  return non_empty(opts.configured, config_home .. "/harper-ls/dictionary.txt")
end

-- The workspace dictionary defaults to .harper-dictionary.txt in the LSP root —
-- the same name nvim-lspconfig lists in harper_ls's root_markers.
function M.workspace_dict_path(opts)
  opts = type(opts) == "table" and opts or {}
  return non_empty(opts.configured, (opts.root or ".") .. "/.harper-dictionary.txt")
end

return M
