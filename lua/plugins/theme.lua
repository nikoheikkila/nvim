local yaml_utils = require("lib.yaml_utils")

-- Hardcoded fallbacks; theme.yml (optional, config root) deep-merges over
-- these. Default styles.comments is 'NONE'; italic comments are wanted both in
-- regular code and inside markdown fences (injected @comment captures merge
-- italic over the non-italic fence-content group).
local defaults = {
  url = "projekt0n/github-nvim-theme",
  name = "github-theme", -- doubles as the require() module passed to setup()
  variant = "github_dark_default",
  options = { styles = { comments = "italic" } },
}

-- A missing, unreadable, or malformed theme.yml silently yields the defaults.
local function load_theme()
  local file = io.open(vim.fn.stdpath("config") .. "/theme.yml", "r")
  if not file then
    return defaults
  end
  local text = file:read("*a")
  file:close()
  local parsed = yaml_utils.parse(text)
  if type(parsed) ~= "table" or type(parsed.theme) ~= "table" then
    return defaults
  end
  return vim.tbl_deep_extend("force", defaults, parsed.theme)
end

local theme = load_theme()

return {
  {
    theme.url,
    name = theme.name,
    lazy = false,
    priority = 1000,
    config = function()
      -- setup() must run before the colorscheme command or style options
      -- don't apply. A typo'd name/variant in theme.yml degrades to default
      -- colors with a warning instead of a startup stack trace.
      local ok, err = pcall(function()
        -- groups (per-highlight-group overrides, github-nvim-theme shape) is
        -- optional in theme.yml; nil is fine for themes without overrides.
        require(theme.name).setup({ options = theme.options, groups = theme.groups })
        vim.cmd("colorscheme " .. theme.variant)
      end)
      if not ok then
        vim.notify("theme.yml: failed to apply theme: " .. tostring(err), vim.log.levels.WARN)
      end
    end,
  },
}
