-- Background plugin updates (config/plugin_updates.lua). The checker and
-- VeryLazy never run headless, so these specs drive the seams directly, with
-- require("lazy").update and the lockfile writer stubbed: the real ones would
-- fetch and rewrite lazy-lock.json in this repository.
local plugin_updates = require("config.plugin_updates")
local lazy = require("lazy")
local lock = require("lazy.manage.lock")

describe("config.plugin_updates", function()
  local original_update, original_pending, original_drifted, original_write
  local calls, lock_writes

  before_each(function()
    original_update, original_pending = lazy.update, plugin_updates.pending
    original_drifted, original_write = plugin_updates.lock_drifted, lock.update
    calls, lock_writes = {}, 0
    lazy.update = function(opts)
      table.insert(calls, opts)
    end
    lock.update = function()
      lock_writes = lock_writes + 1
    end
    plugin_updates.lock_drifted = function()
      return {}
    end
    -- Clear any in-flight state left by a previous spec.
    vim.api.nvim_exec_autocmds("User", { pattern = "LazyUpdate", modeline = false })
  end)

  after_each(function()
    lazy.update, plugin_updates.pending = original_update, original_pending
    plugin_updates.lock_drifted, lock.update = original_drifted, original_write
    vim.api.nvim_exec_autocmds("User", { pattern = "LazyUpdate", modeline = false })
  end)

  it("keeps the checker fetching but silences its hit-enter notification", function()
    local checker = require("lazy.core.config").options.checker
    assert.is_true(checker.enabled)
    assert.is_false(checker.notify)
  end)

  it("hooks the startup and periodic checker events", function()
    local patterns = {}
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ group = "plugin_auto_update" })) do
      patterns[autocmd.pattern] = true
    end
    assert.is_true(patterns.VeryLazy)
    assert.is_true(patterns.LazyCheck)
    assert.is_true(patterns.LazyUpdate)
  end)

  it("updates the pending plugins without opening the lazy UI", function()
    plugin_updates.pending = function()
      return { "a.nvim", "b.nvim" }
    end
    plugin_updates.auto_update()
    assert.same({ { plugins = { "a.nvim", "b.nvim" }, show = false } }, calls)
  end)

  it("does nothing when no plugin has an update", function()
    plugin_updates.pending = function()
      return {}
    end
    plugin_updates.auto_update()
    assert.same({}, calls)
    assert.equal(0, lock_writes)
  end)

  it("rewrites a lockfile left behind the checkouts when nothing needs updating", function()
    plugin_updates.pending = function()
      return {}
    end
    plugin_updates.lock_drifted = function()
      return { "a.nvim" }
    end
    plugin_updates.auto_update()
    assert.same({}, calls)
    assert.equal(1, lock_writes)
  end)

  it("leaves the lockfile to the update when plugins are pending", function()
    plugin_updates.pending = function()
      return { "a.nvim" }
    end
    plugin_updates.lock_drifted = function()
      return { "a.nvim" }
    end
    plugin_updates.auto_update()
    assert.equal(1, #calls)
    assert.equal(0, lock_writes)
  end)

  it("does not start a second update until the first one finishes", function()
    plugin_updates.pending = function()
      return { "a.nvim" }
    end
    plugin_updates.auto_update()
    plugin_updates.auto_update()
    assert.equal(1, #calls)

    vim.api.nvim_exec_autocmds("User", { pattern = "LazyUpdate", modeline = false })
    plugin_updates.auto_update()
    assert.equal(2, #calls)
  end)

  it("lists only plugins whose fetched upstream is ahead", function()
    local names = original_pending()
    assert.is_table(names)
    for _, name in ipairs(names) do
      assert.is_table(require("lazy.core.config").plugins[name]._.updates)
    end
  end)

  it("lists only installed plugins whose checkout differs from the lockfile", function()
    local Config = require("lazy.core.config")
    local locked = vim.json.decode(table.concat(vim.fn.readfile(Config.options.lockfile), "\n"))
    for _, name in ipairs(original_drifted()) do
      local commit = require("lazy.manage.git").info(Config.plugins[name].dir).commit
      assert.is_not.equal(commit, (locked[name] or {}).commit)
    end
  end)
end)
