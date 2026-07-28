local M = {}

-- Returns true when name looks like a URI scheme (e.g. "oil://", "scp://host/file").
-- Used to skip non-file buffers when auto-creating parent directories on save.
function M.has_uri_scheme(name)
  return name:match("^%w%w+://") ~= nil
end

return M
