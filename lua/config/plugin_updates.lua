-- Install plugin updates in the background instead of announcing them.
--
-- lazy.nvim's checker only fetches: `checker.report()` then lists the pending
-- plugins through a multi-line vim.notify, which (with no notifier plugin)
-- lands in the command line and demands <Enter>. lazy.nvim has no
-- auto-update option, so config/lazy.lua sets `checker.notify = false` and
-- this module runs the update itself whenever the checker has found work.
--
-- Both triggers come from lazy.nvim's pinned source
-- (~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/):
--   * VeryLazy: core/config.lua starts the checker here, and its
--     `fast_check()` marks updates already fetched by an earlier session.
--   * LazyCheck: the periodic `checker.check()` fetch fires it on completion,
--     after `fast_check({ report = false })` refreshed `plugin._.updates`
--     (manage/init.lua, `M.run`).
-- Neither fires in --headless (VeryLazy comes from UIEnter), so the test
-- suites and `task install`/`task update` never trigger an update from here.
local M = {}

local running = false

---Names of installed plugins whose fetched upstream is ahead of the checkout.
---@return string[]
function M.pending()
  require("lazy.manage.checker").fast_check({ report = false })
  local names = {}
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    if plugin._.updates then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

---Names of installed plugins whose checkout disagrees with lazy-lock.json.
---lazy.nvim decides "has updates" from checkout vs upstream and never reads
---the lockfile for it, so a lockfile left behind the checkouts (a reverted or
---dropped `chore: update plugins` commit, an update interrupted before
---manage/lock.lua's `M.update` ran) is invisible to `pending()`. Read fresh
---from disk rather than through manage/lock.lua's `M.load`, which caches the
---file once per session.
---@return string[]
function M.lock_drifted()
  local Config = require("lazy.core.config")
  local Git = require("lazy.manage.git")
  local installed = {}
  for name, plugin in pairs(Config.plugins) do
    if plugin._.installed and not plugin._.is_local then
      local info = Git.info(plugin.dir)
      if info and info.commit then
        installed[name] = info.commit
      end
    end
  end
  local ok, lock = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(Config.options.lockfile), "\n"))
  end)
  return require("lib.lockfile_utils").drifted(ok and lock or nil, installed)
end

---Update every pending plugin without opening the lazy.nvim UI; with nothing
---to update, bring a drifted lockfile back in line with the checkouts. A no-op
---while an earlier update is still running (cleared on `User LazyUpdate`).
function M.auto_update()
  if running then
    return
  end
  local names = M.pending()
  if #names > 0 then
    running = true
    -- Rewrites lazy-lock.json when done (manage/init.lua, `M.update`).
    require("lazy").update({ plugins = names, show = false })
  elseif #M.lock_drifted() > 0 then
    -- The same lockfile write `M.update` ends with, minus the network.
    require("lazy.manage.lock").update()
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("plugin_auto_update", { clear = true })
  local function schedule_update()
    vim.schedule(M.auto_update)
  end
  vim.api.nvim_create_autocmd("User", { group = group, pattern = "VeryLazy", once = true, callback = schedule_update })
  vim.api.nvim_create_autocmd("User", { group = group, pattern = "LazyCheck", callback = schedule_update })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "LazyUpdate",
    callback = function()
      running = false
    end,
  })
end

return M
