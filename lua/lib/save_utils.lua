local path_utils = require("lib.path_utils")

local M = {}

-- Decide whether a buffer is safe to auto-save. Takes plain values so Busted
-- can test it; the autocmd wiring in config/autocmds.lua gathers them from
-- vim.bo / nvim_buf_get_name.
--   props = { name, buftype, modified, modifiable, readonly }
function M.should_autosave(props)
  return props.modified == true
    and props.modifiable == true
    and props.readonly ~= true
    and props.buftype == ""
    and props.name ~= ""
    and not path_utils.has_uri_scheme(props.name)
end

return M
