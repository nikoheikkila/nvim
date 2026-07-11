local M = {}

-- Case-insensitive substring match, loosely mirroring rg's default search behaviour.
-- Returns false for an empty term so callers don't have to special-case it.
function M.matches(line, term)
  if term == "" then return false end
  return line:lower():find(term:lower(), 1, true) ~= nil
end

return M
