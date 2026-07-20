local M = {}

-- Hardcoded fallbacks for the `:Daily` note location and filename. config.yml
-- (optional, config root) overrides these per field. `directory` is kept as the
-- literal `$HOME/...` string so this module stays free of vim/os calls — the
-- caller expands it (vim.fn.expand) and applies os.date to filenamePattern.
local DEFAULTS = { directory = "$HOME/Notes", filenamePattern = "%Y-%m-%d.md" }

-- Merge parsed `config.daily` over DEFAULTS, guarding each field's type so a
-- malformed or partial config.yml never yields a non-string where a string is
-- expected. `parsed` is yaml_utils.parse() output (table | nil).
function M.resolve_config(parsed)
  local daily = type(parsed) == "table" and type(parsed.config) == "table" and parsed.config.daily
  local function pick(key)
    if type(daily) == "table" and type(daily[key]) == "string" then
      return daily[key]
    end
    return DEFAULTS[key]
  end
  return { directory = pick("directory"), filenamePattern = pick("filenamePattern") }
end

-- The NVIM_NOTES_DIR override wins when set and non-empty; otherwise the
-- configured directory is used.
function M.effective_directory(cfg, env_dir)
  if env_dir ~= nil and env_dir ~= "" then
    return env_dir
  end
  return cfg.directory
end

return M
