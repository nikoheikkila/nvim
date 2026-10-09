-- Project-wide search & replace (plugins/search_replace.lua,
-- config/search_replace.lua): grug-far.nvim opened as a modal float.
--
-- Two halves. The prefill seams (scope, missing rg) swap require("grug-far")
-- for a capturing fake, like picker_spec does for snacks. The modal itself is
-- driven for real inside a throwaway tabpage, against a temp project: grug-far
-- fills its inputs and searches asynchronously, so each wait latches on its own
-- completion signals (instance:when_ready, the search status) rather than
-- sleeping.
describe("search & replace", function()
  local search_replace = require("config.search_replace")
  local search_replace_utils = require("lib.search_replace_utils")
  local project = require("config.project")
  local notify_log = require("notify_log")

  local leader_s = vim.g.mapleader .. "S"

  local function float_count()
    local count = 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        count = count + 1
      end
    end
    return count
  end

  it("maps <leader>S in normal and visual mode", function()
    for _, mode in ipairs({ "n", "x" }) do
      assert.equal("Search & Replace (Project)", vim.fn.maparg(leader_s, mode, false, true).desc)
    end
  end)

  it("reads the float size from config.yml", function()
    -- Sentinels from the scripts/busted-nvim.sh fixture, not the 0.8 defaults.
    assert.are.same({ width = 0.5, height = 0.6 }, search_replace.settings())
  end)

  describe("prefills", function()
    local real_grug_far, real_root, captured

    before_each(function()
      captured = nil
      real_grug_far = package.loaded["grug-far"]
      local buf = vim.api.nvim_create_buf(false, true)
      package.loaded["grug-far"] = {
        has_instance = function()
          return false
        end,
        open = function(opts)
          captured = opts
          return {
            get_buf = function()
              return buf
            end,
          }
        end,
      }
      real_root = project.root
    end)

    after_each(function()
      package.loaded["grug-far"] = real_grug_far
      project.root = real_root
      vim.fn.executable = nil -- drop any override, restoring real dispatch
    end)

    it("scopes the search to the project root, escaping spaces", function()
      project.root = function()
        return "/fake/project root"
      end

      search_replace.open()

      assert.equal("/fake/project\\ root", captured.prefills.paths)
      assert.equal(search_replace.INSTANCE, captured.instanceName)
    end)

    it("leaves the paths input empty when the project root is the cwd", function()
      project.root = function()
        return vim.uv.cwd()
      end

      search_replace.open()

      assert.is_nil(captured.prefills.paths)
    end)

    it("reports a missing rg and opens nothing", function()
      local orig = vim.fn.executable
      vim.fn.executable = function(name)
        return name == "rg" and 0 or orig(name)
      end
      local floats = float_count()

      search_replace.open()

      assert.is_nil(captured)
      assert.equal(floats, float_count())
      assert.equal("Search & Replace needs ripgrep (rg) on PATH", notify_log[#notify_log])
    end)
  end)

  describe("the modal", function()
    local dir, file, origin, float, buf, real_root, real_showmode, real_settings

    local function instance()
      return require("grug-far").get_instance(search_replace.INSTANCE)
    end

    local function wait_ready(inst)
      local ready = false
      inst:when_ready(function()
        ready = true
      end)
      assert.is_true(vim.wait(5000, function()
        return ready
      end, 10))
    end

    local function lines()
      return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end

    setup(function()
      dir = vim.fn.tempname()
      vim.fn.mkdir(dir, "p")
      file = vim.fs.joinpath(dir, "notes.txt")
      assert.equal(0, vim.fn.writefile({ "alpha needle omega", "beta needle" }, file))

      real_root = project.root
      project.root = function()
        return dir
      end
      -- grug-far opens in Insert mode (startInInsertMode), and the mode message
      -- would otherwise land in the suite's stdout, which is the test report.
      real_showmode = vim.o.showmode
      vim.o.showmode = false
      -- A full-width float, so the help line atop it shows several entries
      -- before it is cut off with "..." (the fixture's 0.5 of a headless 80
      -- columns fits two). Resizing the editor instead (vim.o.columns)
      -- segfaults a UI-less Neovim. "reads the float size from config.yml"
      -- above has already run against the real settings().
      real_settings = search_replace.settings
      search_replace.settings = function()
        return { width = 1, height = 0.6 }
      end

      -- The tab-local cwd is the temp project too, so even an empty Paths
      -- input cannot point a Replace at the real config repository.
      vim.cmd("tabnew")
      vim.cmd.tcd(vim.fn.fnameescape(dir))
      vim.cmd.edit(vim.fn.fnameescape(file))
      origin = vim.api.nvim_get_current_win()
      -- What config/folding.lua leaves on a markdown/LSP window. A float that
      -- inherited it would draw this gutter instead of grug-far's own.
      vim.wo[origin].statuscolumn = "%l "
      require("lazy").load({ plugins = { "grug-far.nvim" } })
    end)

    teardown(function()
      if require("grug-far").has_instance(search_replace.INSTANCE) then
        instance():close()
      end
      vim.cmd("stopinsert")
      vim.cmd("tabclose!")
      vim.cmd("bwipeout! " .. vim.fn.fnameescape(file))
      vim.fn.delete(dir, "rf")
      project.root = real_root
      vim.o.showmode = real_showmode
      search_replace.settings = real_settings
      assert.is_true(vim.bo.modifiable)
    end)

    it("opens from a visual selection with the selection as the search", function()
      vim.api.nvim_win_set_cursor(origin, { 1, 7 })
      vim.api.nvim_feedkeys(vim.keycode("viw" .. leader_s), "mx", false)

      float = vim.api.nvim_get_current_win()
      buf = vim.api.nvim_get_current_buf()
      wait_ready(instance())

      assert.equal("needle", lines()[1])
    end)

    it("is a centred float sized by settings()", function()
      local config = vim.api.nvim_win_get_config(float)
      local expected =
        search_replace_utils.float_geometry(vim.o.columns, vim.o.lines - vim.o.cmdheight, search_replace.settings())

      assert.equal("editor", config.relative)
      assert.equal(expected.width, config.width)
      assert.equal(expected.height, config.height)
      assert.equal(expected.row, config.row)
      assert.equal(expected.col, config.col)
    end)

    it("is a grug-far buffer kept out of the bufferline", function()
      assert.equal("grug-far", vim.bo[buf].filetype)
      assert.is_false(vim.bo[buf].buflisted)
    end)

    it("advertises only the modal's own keys in the help line atop it", function()
      -- The help line is a virt_lines extmark above the first input, cut to the
      -- window width with "..." (the float is full-width here, see setup).
      local header = {}
      local marks = vim.api.nvim_buf_get_extmarks(buf, -1, 0, 0, { details = true })
      for _, mark in ipairs(marks) do
        for _, virt_line in ipairs(mark[4].virt_lines or {}) do
          for _, chunk in ipairs(virt_line) do
            header[#header + 1] = chunk[1]
          end
        end
      end
      local text = table.concat(header)

      assert.truthy(text:find("Help g?", 1, true), text)
      assert.truthy(text:find("Replace <C-s>", 1, true), text)
      assert.truthy(text:find("History Open <C-t>", 1, true), text)
      assert.truthy(text:find("Goto <CR>", 1, true), text)
      assert.falsy(text:find("Sync", 1, true), text)
      assert.falsy(text:find("\\", 1, true), text) -- no <localleader> chords left
    end)

    it("binds the lean key set and unbinds the rest (g? help window)", function()
      instance():help()
      local help = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
      vim.cmd.close()
      vim.api.nvim_set_current_win(float)

      for _, entry in ipairs({
        "Help g?",
        "Replace <C-s>",
        "History Open <C-t>",
        "Goto <CR>",
        "Apply Next <C-y>",
        "Close q",
        "Swap Engine <C-e>",
        "Preview <C-p>",
        "Next Input <Tab>",
        "Prev Input <S-Tab>",
      }) do
        assert.truthy(help:find(entry, 1, true), entry)
      end
      for _, action in ipairs({ "Sync All", "Sync Line", "Open Next", "Open Prev", "Refresh", "Quickfix", "Abort" }) do
        assert.truthy(help:find(action .. " (unbound)", 1, true), action)
      end
    end)

    it("does not inherit the origin window's statuscolumn", function()
      assert.equal("", vim.wo[float].statuscolumn)
    end)

    it("<CR> on a result jumps to it in the origin window and hides the float", function()
      local inst = instance()
      assert.is_true(vim.wait(5000, function()
        return inst:get_status_info().status == "success"
      end, 10))
      local row
      for i, line in ipairs(lines()) do
        if i > 1 and line:find("alpha needle omega", 1, true) then
          row = i
          break
        end
      end
      assert.is_not_nil(row)
      vim.cmd("stopinsert")
      vim.api.nvim_win_set_cursor(float, { row, 0 })

      vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)

      assert.equal(origin, vim.api.nvim_get_current_win())
      assert.equal(1, vim.api.nvim_win_get_cursor(origin)[1])
      assert.is_false(vim.api.nvim_win_is_valid(float))
      assert.is_true(vim.api.nvim_buf_is_loaded(buf))
    end)

    it("<leader>S restores the hidden modal with its inputs", function()
      vim.api.nvim_feedkeys(vim.keycode(leader_s), "mx", false)

      float = vim.api.nvim_get_current_win()
      assert.equal("editor", vim.api.nvim_win_get_config(float).relative)
      assert.equal(buf, vim.api.nvim_get_current_buf())
      assert.equal("needle", lines()[1])
    end)

    it("a visual selection replaces the restored search", function()
      instance():hide()
      vim.api.nvim_win_set_cursor(origin, { 1, 0 })

      vim.api.nvim_feedkeys(vim.keycode("viw" .. leader_s), "mx", false)

      float = vim.api.nvim_get_current_win()
      assert.equal(buf, vim.api.nvim_get_current_buf())
      -- update_input_values fills on vim.schedule; the timeout only bounds a failure.
      assert.is_true(vim.wait(5000, function()
        return lines()[1] == "alpha"
      end, 10))
    end)

    it("<Tab> moves between inputs in Insert mode", function()
      vim.api.nvim_win_set_cursor(float, { 1, 0 })

      vim.api.nvim_feedkeys(vim.keycode("A<Tab>"), "x", false)

      -- A fed Insert-mode key's mapping runs on a later event-loop turn here,
      -- so latch on the move; the timeout only bounds a failure.
      assert.is_true(vim.wait(5000, function()
        return vim.api.nvim_win_get_cursor(float)[1] == 2
      end, 10))
    end)

    it("<C-y> from an input applies only the first match", function()
      local inst = instance()
      -- clearOld = false: clearing would also empty Paths, widening the search
      -- (and the Replace below) from the temp project to the whole cwd.
      inst:update_input_values({ search = "needle", replacement = "pin" }, false)
      -- Latch on the preview itself, not just the search status: searches are
      -- debounced, so a "success" status can still be an earlier search's. And
      -- on the status too: results stream in while rg still runs, and grug-far
      -- refuses to apply anything while a search is in progress. Both diff
      -- lines of each match are buffer text.
      assert.is_true(vim.wait(5000, function()
        local shown = lines()
        return vim.tbl_contains(shown, "alpha pin omega")
          and vim.tbl_contains(shown, "beta pin")
          and inst:get_status_info().status ~= "progress"
      end, 10))
      assert.is_true(vim.tbl_contains(lines(), "alpha needle omega"))
      vim.api.nvim_win_set_cursor(float, { 1, 0 })

      vim.api.nvim_feedkeys(vim.keycode("<C-y>"), "x", false)

      -- The sync is async. Latch on the write and on no task being left in
      -- progress: grug-far refuses a Replace while a sync (or search) runs.
      assert.is_true(vim.wait(5000, function()
        return vim.fn.readfile(file)[1] == "alpha pin omega" and inst:get_status_info().status ~= "progress"
      end, 10))
      assert.equal("alpha pin omega", vim.fn.readfile(file)[1])
      assert.equal("beta needle", vim.fn.readfile(file)[2])
    end)

    it("<C-s> applies every remaining replacement", function()
      vim.api.nvim_feedkeys(vim.keycode("<C-s>"), "x", false)

      assert.is_true(vim.wait(5000, function()
        return (instance():get_status_info().actionMessage or ""):find("replace completed", 1, true) ~= nil
      end, 10))
      assert.are.same({ "alpha pin omega", "beta pin" }, vim.fn.readfile(file))
    end)

    it("q only hides the modal", function()
      vim.api.nvim_feedkeys("q", "x", false)

      assert.is_false(vim.api.nvim_win_is_valid(float))
      assert.equal(origin, vim.api.nvim_get_current_win())
      assert.is_true(require("grug-far").has_instance(search_replace.INSTANCE))
    end)

    it("<leader>S after q restores the typed text and searches afresh", function()
      vim.api.nvim_feedkeys(vim.keycode(leader_s), "mx", false)

      float = vim.api.nvim_get_current_win()
      assert.equal(buf, vim.api.nvim_get_current_buf())
      assert.are.same({ "needle", "pin" }, { lines()[1], lines()[2] })
      -- Every needle was replaced before it was hidden, so a fresh search
      -- finds none. grug-far reports that as a "no matches" results line.
      assert.is_true(vim.wait(5000, function()
        return vim.tbl_contains(lines(), "no matches")
      end, 10))
    end)

    it("\\c starts over, discarding the modal for good", function()
      vim.cmd("stopinsert")
      vim.api.nvim_feedkeys(vim.g.maplocalleader .. "c", "x", false)

      assert.is_false(vim.api.nvim_win_is_valid(float))
      assert.is_false(require("grug-far").has_instance(search_replace.INSTANCE))
    end)
  end)
end)
