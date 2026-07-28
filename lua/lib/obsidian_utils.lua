local M = {}

-- Hardcoded fallbacks for the Obsidian vault location and daily-note placement.
-- config.yml (optional, config root) overrides these per field. `vault` is kept
-- as the literal `$HOME/...` string so this module stays free of vim/os calls —
-- the caller expands it (vim.fn.expand) before handing it to obsidian.nvim.
-- `dateFormat` is a Moment.js-style pattern (obsidian.nvim's own format), not an
-- os.date one, so it is passed through verbatim.
local DEFAULTS = {
  vault = "$HOME/Vaults",
  dailyNotes = {
    -- Relative to the vault root. Matches the folder that already exists in the
    -- vault; obsidian.nvim creates it on first use if it is missing.
    folder = "000 - Inbox/Journal",
    dateFormat = "YYYY-MM-DD",
  },
}

-- Merge parsed `config.obsidian` over DEFAULTS, guarding each field's type so a
-- malformed or partial config.yml never yields a non-string where a string is
-- expected. An absent, empty, or wrong-typed value keeps the default — one rule
-- for every field. `parsed` is yaml_utils.parse() output (table | nil).
function M.resolve_config(parsed)
  local obsidian = type(parsed) == "table" and type(parsed.config) == "table" and parsed.config.obsidian
  if type(obsidian) ~= "table" then
    obsidian = {}
  end

  local daily = type(obsidian.dailyNotes) == "table" and obsidian.dailyNotes or {}

  local function pick(source, key, default)
    local value = source[key]
    if type(value) == "string" and value ~= "" then
      return value
    end
    return default
  end

  return {
    vault = pick(obsidian, "vault", DEFAULTS.vault),
    dailyNotes = {
      folder = pick(daily, "folder", DEFAULTS.dailyNotes.folder),
      dateFormat = pick(daily, "dateFormat", DEFAULTS.dailyNotes.dateFormat),
    },
  }
end

-- Last path segment of `path`, ignoring any trailing slashes. Hand-rolled rather
-- than vim.fs.basename so this module keeps running under plain busted.
local function basename(path)
  local trimmed = (path:gsub("/+$", ""))
  local name = trimmed:match("[^/]+$")
  -- Degenerate inputs ("", "/") leave nothing to name the workspace after.
  return name ~= nil and name ~= "" and name or "vault"
end

-- The obsidian.nvim `workspaces` list. `vault` must already be expanded (see
-- DEFAULTS above); the workspace is named after its last path segment.
function M.workspaces(vault)
  return { { name = basename(vault), path = vault } }
end

return M
