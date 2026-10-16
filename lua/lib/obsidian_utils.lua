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
  templates = {
    -- Where notes created from a template land when config.yml names no folder.
    -- templates.folder deliberately has no default; when it is not configured,
    -- the plugin's own warning shows.
    notesFolder = "000 - Inbox",
  },
}

-- A wrong-typed section is treated as empty so each of its fields falls back.
local function as_table(value)
  return type(value) == "table" and value or {}
end

-- An absent, empty, or wrong-typed value keeps the default — one rule for
-- every field.
local function pick(source, key, default)
  local value = source[key]
  if type(value) == "string" and value ~= "" then
    return value
  end
  return default
end

local function resolve_templates(templates)
  templates = as_table(templates)
  return {
    folder = pick(templates, "folder", nil),
    notesFolder = pick(templates, "notesFolder", DEFAULTS.templates.notesFolder),
  }
end

-- Merge parsed `config.obsidian` over DEFAULTS, guarding each field's type so a
-- malformed or partial config.yml never yields a non-string where a string is
-- expected (see pick). `parsed` is yaml_utils.parse() output (table | nil).
function M.resolve_config(parsed)
  local obsidian = as_table(as_table(as_table(parsed).config).obsidian)
  local daily = as_table(obsidian.dailyNotes)

  return {
    vault = pick(obsidian, "vault", DEFAULTS.vault),
    dailyNotes = {
      folder = pick(daily, "folder", DEFAULTS.dailyNotes.folder),
      dateFormat = pick(daily, "dateFormat", DEFAULTS.dailyNotes.dateFormat),
    },
    templates = resolve_templates(obsidian.templates),
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

-- obsidian.nvim's note_id_func: keep the user's title as the file name, and
-- fall back to a sortable timestamp instead of upstream's random-suffix ID.
function M.note_id(title)
  if title ~= nil and title ~= "" then
    return title
  end
  return os.date("%Y-%m-%d-%H%M%S")
end

return M
