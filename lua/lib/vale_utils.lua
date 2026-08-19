local yaml_utils = require("lib.yaml_utils")

local M = {}

-- vale-ls initializationOptions at their upstream defaults, mirrored from
-- vale-ls 0.5.0's src/server.rs — the authority, because the published docs page
-- (https://docs.vale.sh/guides/lsp) lists an incomplete set. Parsed `config.vale`
-- (config.yml) overrides these per field; a missing/malformed/wrong-typed field
-- keeps the default. Free of vim/os calls so the module stays unit-testable under
-- plain busted, like every other resolver in lua/lib/.
local DEFAULTS = {
  installVale = false, -- true makes vale-ls download its own CLI into vale_bin/; mason supplies ours
  syncOnStartup = false, -- a `vale sync` on every server start; `:ValeSync` is the on-demand version
  lintOnChange = true, -- diagnostics as you type, not on save — the whole point of the integration
  debounceMs = 300, -- how long typing has to settle before a lint spawns
  -- Inert here, and kept at upstream's value rather than flipped: vale-ls only
  -- computes the metrics lens when a client asks for textDocument/codeLens, and
  -- nothing in this config calls vim.lsp.codelens.refresh(). Wiring lenses up
  -- later then needs no change on this side.
  showMetrics = true,
}

-- Optional strings deliberately left out of DEFAULTS: vale-ls reads "" as
-- "unset" for each and falls back to its own behaviour — search upward for a
-- .vale.ini, take `vale` from PATH, pass no --filter. Forward one only when the
-- user supplied a non-empty value.
local OPTIONAL_STRINGS = { "configPath", "valeBinaryPath", "filter" }

-- The subset of OPTIONAL_STRINGS naming a filesystem path. Exported because
-- config/vale.lua has to expand these with vim.fn.expand (this module stays
-- vim-free) and would otherwise repeat the list: a third path option added here
-- but missed there would be read from config.yml and silently left unexpanded. `filter` stays out on purpose — it is a Vale expression
-- (`.Level in ['warning', 'error']`), and expanding it would mangle it.
M.OPTIONAL_PATHS = { "configPath", "valeBinaryPath" }

-- Basename of the fallback config this setup ships beside config.yml. Named here
-- rather than in config/vale.lua so the vim-free half owns the naming; that
-- module joins it onto the config root.
M.CONFIG_FILE = ".vale.ini"

-- Build the initializationOptions table for vale_ls from yaml_utils.parse()
-- output (table | nil). Merges config.vale over DEFAULTS, then layers the
-- optional strings only when the user supplied usable values.
function M.resolve_config(parsed)
  return (yaml_utils.resolve_section(parsed, "vale", DEFAULTS, OPTIONAL_STRINGS))
end

-- The StylesPath a .vale.ini declares, or nil when it names none (Vale then uses
-- its own default location and never errors about a missing directory).
--
-- Read out of the file rather than hardcoded in Lua so editing .vale.ini cannot
-- silently desync from the readiness gate in config/vale.lua — Vale
-- aborts with E201 on *every* lint while a declared StylesPath is missing, and
-- each abort is an LSP showMessage error popup.
--
-- A line scan, not an INI parser: StylesPath is a global-section key, so the
-- scan stops at the first `[section]` header. Comment lines need no guard of
-- their own — the pattern is anchored at the key, so Vale's `#` and `;` leaders
-- fail to match like any other prefix. A relative value is resolved against the
-- .vale.ini itself (not the cwd), which is the caller's job.
function M.styles_path(ini_text)
  if type(ini_text) ~= "string" then
    return nil
  end
  for line in (ini_text .. "\n"):gmatch("(.-)\r?\n") do
    if line:match("^%s*%[") then
      return nil -- past the global section; anything below cannot be a StylesPath
    end
    local value = line:match("^%s*StylesPath%s*=%s*(.-)%s*$")
    if value and value ~= "" then
      return (value:gsub('^"(.*)"$', "%1"))
    end
  end
  return nil
end

return M
