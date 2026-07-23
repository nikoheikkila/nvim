-- Theme sourcing from theme.yml: the colorscheme applied at startup must match
-- the configuration file (or the hardcoded defaults when the file is absent or
-- malformed). Expectations are derived through the same lib parser theme.lua
-- uses, and read from the SAME active path (config.paths — the fixture theme.yml
-- the harness generates), so the spec depends on the injected fixture, never on
-- the real, user-editable theme.yml.
local yaml_utils = require("lib.yaml_utils")
local paths = require("config.paths")

-- Mirrors the defaults in lua/plugins/theme.lua.
local defaults = {
  name = "github-theme",
  variant = "github_dark_default",
}

local function configured_theme()
  local file = io.open(paths.config_file("theme.yml"), "r")
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

  -- groups.all overrides from theme.yml are applied by the theme's setup() at
  -- colorscheme time. Expectations are derived from the file, so recoloring in
  -- theme.yml never breaks this spec.
  local groups = type(theme.groups) == "table" and theme.groups.all or nil
  for group, spec in pairs(groups or {}) do
    it("applies the theme.yml group override for " .. group, function()
      local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
      if spec.fg then
        assert.equal(tonumber(spec.fg:sub(2), 16), hl.fg)
      end
      if spec.bg then
        assert.equal(tonumber(spec.bg:sub(2), 16), hl.bg)
      end
      if spec.sp then
        assert.equal(tonumber(spec.sp:sub(2), 16), hl.sp)
      end
      if type(spec.style) == "string" and spec.style:find("undercurl") then
        assert.is_true(hl.undercurl)
      end
      -- A group defined without a style replaces the theme's styling entirely
      -- (this is what un-italicizes inline code).
      if not spec.style then
        assert.is_falsy(hl.italic)
      end
    end)
  end
end)
