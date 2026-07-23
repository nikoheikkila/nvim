local M = {}

-- Root directory the editor reads its YAML/JSONC config files from (config.yml,
-- theme.yml, .markdownlint.jsonc). Defaults to Neovim's config dir; the
-- NVIM_CONFIG_ROOT env var overrides it so the integration harness
-- (scripts/busted-nvim.sh) can point every config read at throwaway fixtures in
-- a temp dir instead of the real, user-editable files — a test never depends on
-- what those files happen to contain. An empty value is treated as unset
-- (an exported "" is a truthy Lua string), mirroring daily_utils.effective_directory.
function M.config_root()
  local override = vim.env.NVIM_CONFIG_ROOT
  if override ~= nil and override ~= "" then
    return override
  end
  return vim.fn.stdpath("config")
end

-- Absolute path to a config file under the active root.
function M.config_file(name)
  return M.config_root() .. "/" .. name
end

return M
