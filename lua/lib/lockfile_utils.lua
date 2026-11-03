-- Comparison between lazy-lock.json and the plugin checkouts on disk. Free of
-- vim calls so it stays unit-testable under plain busted; the caller decodes
-- the lockfile and reads each checkout's commit.
local M = {}

---Names of installed plugins whose checkout differs from the lockfile entry,
---or that have no entry at all. Lockfile entries without an installed plugin
---are not drift: lazy.nvim keeps disabled and `cond` plugins in the lockfile.
---@param lock table<string, {commit?: string}>|nil decoded lazy-lock.json
---@param installed table<string, string> plugin name -> checked-out commit
---@return string[] sorted names
function M.drifted(lock, installed)
  lock = type(lock) == "table" and lock or {}
  local names = {}
  for name, commit in pairs(installed) do
    local entry = lock[name]
    if type(entry) ~= "table" or entry.commit ~= commit then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

return M
