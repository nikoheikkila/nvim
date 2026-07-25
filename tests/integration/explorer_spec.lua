-- neo-tree sidebar (plugins/explorer.lua). Pins `close_if_last_window = false`
-- and the behaviour it protects: neo-tree implements that option as a WinClosed
-- autocmd ending in `vim.cmd("q!")` that never bails when the window being
-- closed is itself a float, so a float dismissed over a lone sidebar quits the
-- editor. See explorer.md for the upstream history and for why prompt-driven
-- file operations are stubbed rather than driven with feedkeys.
--
-- A regression here does not fail a test — it exits Neovim and kills every
-- remaining spec file, so setup re-asserts the option before any window surgery.
describe("neo-tree explorer", function()
  local spec = require("plugins.explorer")[1]

  it("declares close_if_last_window = false", function()
    assert.equal(false, spec.opts.close_if_last_window)
  end)

  describe("with the sidebar as the only window", function()
    local dir, file, tree_win, real_log_level

    local function tree_window()
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
          return win
        end
      end
    end

    local function tree_text()
      local buf = vim.api.nvim_win_get_buf(tree_win)
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end

    setup(function()
      -- Must be the FIRST statement, and is deliberately a duplicate of the
      -- `it` above: it fires before any tab, window or tree exists, so a
      -- re-enabled option aborts setup with nothing built and the rest of the
      -- suite still runs. Asserting only the merged value below is not enough —
      -- by then the tree is open, and the suite dies partway through instead of
      -- reporting a failure (verified by flipping the option).
      assert.equal(false, spec.opts.close_if_last_window)

      dir = vim.fn.tempname()
      vim.fn.mkdir(dir, "p")
      file = vim.fs.joinpath(dir, "old.md")
      assert.equal(0, vim.fn.writefile({ "# heading" }, file))

      -- Everything happens in a throwaway tabpage. neo-tree keys its source
      -- state by tabid, so tearing the tab down keeps this file's window
      -- surgery out of the state the rest of the shared session sees.
      vim.cmd("tabnew")
      require("lazy").load({ plugins = { "neo-tree.nvim" } })

      -- Keep neo-tree's own INFO chatter ("Renamed new.md successfully") out of
      -- the suite's output. set_level rebuilds the log functions on the shared
      -- logger, so this reaches the `log.info` call inside fs_actions; the table
      -- form is required because the scalar form clamps console to max(level,
      -- INFO) and so can never silence INFO.
      local log = require("neo-tree.log")
      real_log_level = vim.deepcopy(log.minimum_level)
      log.set_level({ file = real_log_level.file, console = log.levels.WARN })

      -- Open the file first, so the rename below also exercises neo-tree's
      -- buffer churn (bufadd/replace-in-windows/nvim_buf_delete) on a real,
      -- still-loaded buffer.
      vim.cmd.edit(file)
      vim.cmd("Neotree show dir=" .. dir)
      assert.is_true(vim.wait(5000, function()
        return tree_window() ~= nil
      end, 25))
      tree_win = tree_window()

      -- Wait for the tree's FIRST render, not just for its window: `Neotree
      -- show` creates the window synchronously but fills it from an async
      -- fs_scan. Renaming before that scan renders lets its pre-rename result
      -- land *after* the refresh in the rename spec, so the tree keeps showing
      -- the old name and never redraws again. That is what made this file pass
      -- on macOS (an incidental later refresh corrected it) and time out on
      -- Linux.
      assert.is_true(vim.wait(5000, function()
        return tree_text():find("old.md", 1, true) ~= nil
      end, 25))

      -- Guards the suite, at the only altitude that counts: ensure_config() is
      -- the merged table neo-tree's WinClosed handler actually reads, so this
      -- catches an upstream default flip as well as a local edit. It has to
      -- precede the window surgery below — that surgery is what leaves the tree
      -- as the last pane, which is the state the handler quits on.
      assert.equal(false, require("neo-tree").ensure_config().close_if_last_window)

      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if win ~= tree_win then
          vim.api.nvim_win_close(win, true)
        end
      end
      assert.equal(1, #vim.api.nvim_tabpage_list_wins(0))
    end)

    -- The editor process is shared global state (auto-insulate is off), so this
    -- must hand back a single ordinary window on a modifiable buffer — a leaked
    -- neo-tree buffer breaks every later spec file with "Buffer is not
    -- 'modifiable'". The closing assertions keep that contract honest.
    teardown(function()
      -- Close through neo-tree's own command before dropping the tab, so the
      -- plugin updates its own state instead of holding a stale winid: a later
      -- spec creating a window that reuses that id makes neo-tree render the
      -- tree buffer into it, which is how this file first broke
      -- markdown_keymaps_spec with "Buffer is not 'modifiable'".
      vim.cmd("new") -- a normal window, so the tree window can be closed
      vim.cmd("Neotree close")
      vim.cmd("tabclose")
      -- Match on resolved paths: tempname() hands back /var/... while buffer
      -- names come back through the /var -> /private/var symlink, so a plain
      -- prefix check silently leaves the file buffers behind.
      local resolved_dir = vim.fn.resolve(dir)
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.fn.resolve(vim.api.nvim_buf_get_name(buf))
        if vim.startswith(name, resolved_dir) or vim.bo[buf].filetype == "neo-tree" then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
      vim.fn.delete(dir, "rf")
      require("neo-tree.log").set_level(real_log_level)

      assert.equal(1, #vim.api.nvim_tabpage_list_wins(0))
      assert.is_true(vim.bo.modifiable)
    end)

    -- The class invariant: this covers every float that can close over the
    -- sidebar (nui prompts, snacks picker, lazygit, zen-mode) without touching
    -- neo-tree's async machinery. If the spec below ever becomes a maintenance
    -- liability, this is the one to keep.
    it("survives a float closing over it", function()
      local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, {
        relative = "editor",
        row = 1,
        col = 1,
        width = 10,
        height = 3,
      })
      vim.api.nvim_win_close(float, true)

      -- Queue behind anything already scheduled: a pending `vim.cmd("q!")` from
      -- neo-tree's handler would run before this resolves.
      local flushed = false
      vim.schedule(function()
        flushed = true
      end)
      assert.is_true(vim.wait(2000, function()
        return flushed
      end, 10))

      assert.is_true(vim.api.nvim_win_is_valid(tree_win))
    end)

    -- The originally reported symptom, kept because it drives neo-tree's real
    -- rename path (prompt -> uv.fs_rename -> buffer churn) end to end.
    it("renames a file and stays open", function()
      local inputs = require("neo-tree.ui.inputs")
      local real_input = inputs.input
      inputs.input = function(_, _, callback)
        callback("new.md")
      end
      finally(function()
        inputs.input = real_input
      end)

      -- Pass the refresh callback, exactly as neo-tree's own `r` mapping does
      -- (filesystem/commands.lua's `rename` wraps `fs._navigate_internal`).
      -- Without it the tree redraws only incidentally, via the
      -- buffer-add/delete subscription, at an ordering the spec cannot depend on
      -- — that is what timed out on Ubuntu while passing on macOS. The callback
      -- is a real completion signal, and driving the refresh explicitly also
      -- leaves no fs_scan in flight at teardown: one that lands later has
      -- renderer.acquire_window build a fresh tree window in whatever window is
      -- current by then, wrecking a later spec file.
      local fs = require("neo-tree.sources.filesystem")
      local state = require("neo-tree.sources.manager").get_state("filesystem")
      local refreshed = false

      require("neo-tree.sources.filesystem.lib.fs_actions").rename_node(file, function()
        fs._navigate_internal(state, nil, nil, function()
          refreshed = true
        end, false)
      end)

      -- on_rename runs after uv.fs_rename completed, and the navigate callback
      -- after the tree was redrawn, so both the disk and the tree are settled.
      assert.is_true(vim.wait(5000, function()
        return refreshed
      end, 10))

      assert.is_truthy(tree_text():find("new.md", 1, true))
      assert.equal(1, vim.fn.filereadable(vim.fs.joinpath(dir, "new.md")))
      assert.equal(0, vim.fn.filereadable(file))
      assert.is_true(vim.api.nvim_win_is_valid(tree_win))
    end)
  end)
end)
