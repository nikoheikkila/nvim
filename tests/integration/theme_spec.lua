-- Theme sourcing from theme.yml: the colorscheme applied at startup must match
-- the configuration file (or the hardcoded defaults when the file is absent or
-- malformed). Expectations are derived through the same lib parser theme.lua
-- uses, so editing theme.yml never breaks this spec.
local yaml_utils = require("lib.yaml_utils")

-- Mirrors the defaults in lua/plugins/theme.lua.
local defaults = {
  name = "github-theme",
  variant = "github_dark_default",
}

local function configured_theme()
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

describe("plugins.theme", function()
  local theme = configured_theme()

  it("applies the colorscheme variant from theme.yml", function()
    assert.equal(theme.variant, vim.g.colors_name)
  end)

  it("registers the plugin under the configured name", function()
    assert.is_not_nil(require("lazy.core.config").plugins[theme.name])
  end)

  -- Tracks the shipped defaults (styles.comments = italic); update this if
  -- the default styles change.
  it("renders comments in italic", function()
    assert.is_true(vim.api.nvim_get_hl(0, { name = "Comment" }).italic)
  end)
end)
