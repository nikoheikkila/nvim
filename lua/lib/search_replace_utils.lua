local yaml_utils = require("lib.yaml_utils")

local M = {}

-- Size of the search & replace float as a fraction of the editor, per axis.
-- Parsed `config.searchReplace` (config.yml) overrides these per field.
M.DEFAULTS = {
  width = 0.8,
  height = 0.8,
}

-- A ratio is usable when it is a number in (0, 1]: zero or less would leave no
-- window at all, and more than 1 would push the float off the editor.
local function valid_ratio(value)
  return type(value) == "number" and value > 0 and value <= 1
end

-- Build the float settings from yaml_utils.parse() output (table | nil). A
-- missing, wrong-typed, or out-of-range field keeps its default.
function M.resolve_config(parsed)
  local settings = yaml_utils.resolve_section(parsed, "searchReplace", M.DEFAULTS)
  for key, default in pairs(M.DEFAULTS) do
    if not valid_ratio(settings[key]) then
      settings[key] = default
    end
  end
  return settings
end

-- Geometry of a float centred in an editor area of `columns` x `lines` cells,
-- in the shape nvim_open_win's config takes. `ratios` sizes the *outer* box
-- (border included), so the returned width/height are that minus the two
-- border cells per axis — never below 1, so a tiny editor still gets a window.
function M.float_geometry(columns, lines, ratios)
  local outer_width = math.floor(columns * ratios.width)
  local outer_height = math.floor(lines * ratios.height)

  return {
    width = math.max(outer_width - 2, 1),
    height = math.max(outer_height - 2, 1),
    col = math.max(math.floor((columns - outer_width) / 2), 0),
    row = math.max(math.floor((lines - outer_height) / 2), 0),
  }
end

return M
