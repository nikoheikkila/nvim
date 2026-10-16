-- obsidian.nvim wiring (plugins/obsidian.lua): the workspace built from
-- config.yml, the coexistence settings that keep render-markdown and the snacks
-- picker in charge, and the buffer-local contract inside a vault note.
--
-- Expectations are derived through the same lib resolver plugins/obsidian.lua
-- uses, reading from the SAME active path (config.paths — the fixture config.yml
-- the harness generates), so the spec depends on the injected fixture and never
-- on the real, user-editable config.yml or the real vault.
local obsidian_utils = require("lib.obsidian_utils")
local yaml_utils = require("lib.yaml_utils")
local paths = require("config.paths")

describe("plugins.obsidian", function()
  local cfg = obsidian_utils.resolve_config(yaml_utils.read_file(paths.config_file("config.yml")))
  local vault = vim.fn.expand(cfg.vault)

  -- The merged spec opts, i.e. what setup() was handed.
  local function plugin_opts(name)
    local spec = require("lazy.core.config").plugins[name]
    assert.is_not_nil(spec, name .. " is not registered with lazy.nvim")
    return require("lazy.core.plugin").values(spec, "opts", false)
  end

  describe("workspace", function()
    local opts = plugin_opts("obsidian.nvim")

    it("registers exactly one workspace, for the whole vault", function()
      assert.equal(1, #opts.workspaces)
    end)

    -- The fixture vault lives under $NVIM_CONFIG_ROOT, so this also proves the
    -- $VAR in config.yml is expanded rather than passed through literally.
    it("takes the workspace path from config.yml", function()
      assert.equal(vault, opts.workspaces[1].path)
      assert.is_nil(opts.workspaces[1].path:find("$", 1, true))
    end)

    it("names the workspace after the vault's last path segment", function()
      assert.equal("fixture-vault", opts.workspaces[1].name)
    end)

    it("places daily notes where config.yml says", function()
      assert.equal(cfg.dailyNotes.folder, opts.daily_notes.folder)
      assert.equal(cfg.dailyNotes.dateFormat, opts.daily_notes.date_format)
      assert.is_false(opts.daily_notes.workdays_only)
    end)
  end)

  describe("coexistence with the rest of the config", function()
    local opts = plugin_opts("obsidian.nvim")

    it("delegates picking to snacks.nvim", function()
      assert.equal("snacks.picker", opts.picker.name)
    end)

    -- Regression guard: obsidian probes for a picker with api.get_plugin_info,
    -- which scans nvim_list_runtime_paths() — so "installed" is not enough, the
    -- plugin has to be LOADED. snacks is keys-lazy in plugins/picker.lua, so
    -- without the `dependencies` entry in plugins/obsidian.lua this returns nil
    -- and obsidian silently falls back to a vim.ui.select picker.
    it("has snacks on the runtimepath, so the configured picker resolves", function()
      assert.is_not_nil(require("obsidian.api").get_plugin_info("snacks.nvim"))
    end)

    -- render-markdown.nvim (plugins/markdown.lua) owns markdown rendering;
    -- obsidian's own extmark/conceal UI must stay off so nothing double-renders.
    it("leaves its own UI module off", function()
      assert.is_false(opts.ui.enable)
      assert.is_not_nil(require("lazy.core.config").plugins["render-markdown.nvim"])
    end)
  end)

  describe("commands", function()
    local cmds = vim.api.nvim_get_commands({})

    it("defines :Obsidian", function()
      assert.is_not_nil(cmds.Obsidian)
    end)

    -- Bare :Obsidian opens the subcommand menu. <leader>o is a bare single-key
    -- leader map, which is only safe because no <leader>o… chord family exists —
    -- adding one later would put a timeoutlen pause on every press.
    it("binds <leader>o to the bare :Obsidian menu", function()
      assert.equal("<Cmd>Obsidian<CR>", vim.fn.maparg(vim.g.mapleader .. "o", "n"))
    end)

    it("has no other <leader>o chord that would delay it", function()
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        local lhs = m.lhs or ""
        if lhs:sub(1, 2) == vim.g.mapleader .. "o" then
          assert.equal(vim.g.mapleader .. "o", lhs, "unexpected <leader>o chord: " .. lhs)
        end
      end
    end)

    -- The menu itself is a vim.ui.select call, which snacks replaces with its
    -- picker. That swap happens in snacks' UIEnter handler, and UIEnter never
    -- fires in a headless process — so assert the two preconditions instead of
    -- vim.ui.select's identity, which is always the built-in here.
    it("keeps the snacks ui_select swap armed, so the menu is a picker", function()
      assert.is_true(require("snacks.picker.config").get().ui_select)
      assert.equal(1, #vim.api.nvim_get_autocmds({ group = "snacks", event = "UIEnter" }))
    end)

    -- legacy_commands = false, so the deprecated :ObsidianFoo aliases upstream
    -- drops in 4.0.0 are never registered.
    it("registers no legacy :Obsidian* aliases", function()
      assert.is_false(plugin_opts("obsidian.nvim").legacy_commands)
      assert.is_nil(cmds.ObsidianToday)
      assert.is_nil(cmds.ObsidianSearch)
      assert.is_nil(cmds.ObsidianPasteImg)
    end)
  end)

  describe("snacks image viewing", function()
    local opts = plugin_opts("snacks.nvim")

    -- plugins/obsidian.lua contributes a second snacks spec; lazy.nvim merges
    -- its opts with plugins/picker.lua's, so both modules must survive.
    it("enables the image module without dropping the picker", function()
      assert.is_true(opts.image.enabled)
      assert.is_true(opts.picker.enabled)
    end)

    it("routes attachment paths through obsidian's resolver", function()
      assert.equal("function", type(opts.image.resolve))
    end)

    -- No `force`: snacks.image speaks the kitty graphics protocol only, so
    -- detection is left to decide. See docs/obsidian.md for the Warp caveat.
    it("leaves terminal detection to snacks", function()
      assert.is_nil(opts.image.force)
    end)
  end)

  describe("inside a vault note", function()
    local note = vault .. "/spec-note.md"
    local buf

    setup(function()
      vim.fn.writefile({ "# Spec note", "", "A [[wiki link]] and a list:", "- item" }, note)
      -- Entering the buffer is what wires obsidian up (its FileType autocmd
      -- installs a buffer-local BufEnter handler). Leaving and re-entering
      -- guarantees that handler has run regardless of headless event ordering.
      vim.cmd.edit(vim.fn.fnameescape(note))
      buf = vim.api.nvim_get_current_buf()
      vim.cmd("enew")
      vim.cmd("buffer " .. buf)
    end)

    teardown(function()
      -- bwipeout! discards the buffer without writing, so obsidian's
      -- BufWritePre frontmatter injection never runs.
      vim.cmd("bwipeout! " .. buf)
      vim.fn.delete(note)
    end)

    it("marks the buffer as an obsidian buffer", function()
      assert.is_true(vim.b[buf].obsidian_buffer)
    end)

    it("points includeexpr at obsidian's link resolver, so gf follows wiki-links", function()
      assert.truthy(vim.bo[buf].includeexpr:find("obsidian.link", 1, true))
    end)

    -- The plugin's three default maps. None of them collided with this config:
    -- <CR> was unmapped in normal mode (markdown-plus binds it in insert mode
    -- only) and ]o/[o were free. See .claude/instructions/config.md.
    it("binds <CR>, ]o and [o buffer-local", function()
      local cr = vim.fn.maparg("<CR>", "n", false, true)
      assert.equal("Obsidian Smart Action", cr.desc)
      assert.equal(1, cr.buffer)
      assert.equal("Obsidian Next Link", vim.fn.maparg("]o", "n", false, true).desc)
      assert.equal("Obsidian Previous Link", vim.fn.maparg("[o", "n", false, true).desc)
    end)

    it("leaves insert-mode <CR> to markdown-plus list continuation", function()
      assert.are_not.equal("Obsidian Smart Action", vim.fn.maparg("<CR>", "i", false, true).desc)
    end)

    -- The regression the folding guard in config/folding.lua prevents: obsidian
    -- runs an in-process LSP advertising foldingRangeProvider, and markdown must
    -- keep its own fold source (see folding_spec for the seam-level test).
    it("keeps the markdown fold engine", function()
      assert.equal("markdown", vim.b[buf].fold_engine)
      assert.truthy(vim.wo.foldexpr:find("markdown_foldexpr", 1, true))
    end)
  end)

  -- Feature: new note from template (<leader>nt -> :Obsidian new_from_template).
  -- The snacks picker and the title prompt are the external seams: both are
  -- stubbed so the real action, Note.create and buffer opening run synchronously.
  describe("new note from template", function()
    local work = vault .. "/work.md"
    local inbox = vault .. "/fixture-inbox"
    local outside_dir
    local orig_find_files, orig_input, orig_select, orig_notify, orig_subdir, orig_folder
    local tab, work_buf, cwd

    setup(function()
      vim.fn.writefile({ "# Work" }, work)
      vim.cmd("tabnew")
      tab = vim.api.nvim_get_current_tabpage()
      cwd = vim.fn.tempname()
      vim.fn.mkdir(cwd, "p")
      vim.cmd("tcd " .. vim.fn.fnameescape(cwd))
    end)

    before_each(function()
      vim.cmd.edit(vim.fn.fnameescape(work))
      work_buf = vim.api.nvim_get_current_buf()

      local picker = require("obsidian.picker")
      orig_find_files, orig_input, orig_select = picker.find_files, vim.fn.input, picker.select
      orig_notify, orig_subdir, orig_folder = vim.notify, Obsidian.opts.notes_subdir, Obsidian.opts.templates.folder
      picker.find_files = function(opts)
        opts.callback({ tostring(opts.dir) .. "/Interview.md" })
      end
      vim.fn.input = function()
        return ""
      end
    end)

    after_each(function()
      if outside_dir then
        local scratch = vim.fn.bufnr(outside_dir .. "/scratch.txt")
        if scratch ~= -1 then
          vim.cmd("bwipeout! " .. scratch)
        end
        vim.fn.delete(outside_dir, "rf")
        outside_dir = nil
      end
      local picker = require("obsidian.picker")
      picker.find_files = orig_find_files
      picker.select = orig_select
      vim.fn.input = orig_input
      vim.notify = orig_notify
      Obsidian.opts.notes_subdir = orig_subdir
      Obsidian.opts.templates.folder = orig_folder
      vim.fn.delete(inbox, "rf")
      vim.fn.delete(vault .. "/Meetings", "rf")
      vim.fn.delete(vault .. "/empty-templates", "rf")
      vim.fn.delete(vault .. "/" .. orig_folder .. "/image.png")
      vim.fn.delete(vault .. "/" .. orig_folder .. "/Notes.md")
    end)

    teardown(function()
      vim.cmd("tabclose! " .. vim.api.nvim_tabpage_get_number(tab))
      vim.fn.delete(work)
      vim.fn.delete(cwd, "rf")
    end)

    it("reads the notes folder from config.yml (new-note-from-template.feature)", function()
      assert.equal(
        "fixture-inbox",
        Obsidian.opts.notes_subdir,
        "expected notes_subdir to come from config.yml notesFolder via plugins/obsidian.lua"
      )
    end)

    it("creates a timestamped note in the inbox from the picked template, keeping the previous buffer", function()
      local today = os.date("%Y-%m-%d")

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)

      local files = vim.fn.glob(inbox .. "/*.md", false, true)
      assert.equal(1, #files, "expected one note in 'fixture-inbox' after <leader>nt")
      local id = vim.fn.fnamemodify(files[1], ":t:r")
      assert.truthy(id:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%d%d$"), "note ID is not YYYY-MM-DD-HHmmss: " .. id)
      assert.equal(today, id:sub(1, 10), "note ID date prefix is not today's date: " .. id)

      local lines = vim.fn.readfile(files[1])
      assert.is_true(vim.tbl_contains(lines, "# " .. id), "heading is not the timestamp ID")
      assert.is_true(vim.tbl_contains(lines, "Date: " .. today), "date line missing today's date")

      assert.equal(vim.fn.resolve(files[1]), vim.fn.resolve(vim.api.nvim_buf_get_name(0)))
      assert.is_true(vim.api.nvim_buf_is_loaded(work_buf))
      assert.same({ "# Work" }, vim.api.nvim_buf_get_lines(work_buf, 0, -1, false))
    end)

    it("works from a buffer outside the vault (new-note-from-template.feature)", function()
      outside_dir = vim.fn.tempname()
      vim.fn.mkdir(outside_dir, "p")
      local outside = outside_dir .. "/scratch.txt"
      vim.fn.writefile({ "outside" }, outside)
      vim.cmd.edit(vim.fn.fnameescape(outside))
      local outside_buf = vim.api.nvim_get_current_buf()

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)

      local files = vim.fn.glob(inbox .. "/*.md", false, true)
      assert.equal(1, #files, "expected one note in 'fixture-inbox' when invoked from outside the vault")
      assert.equal(vim.fn.resolve(files[1]), vim.fn.resolve(vim.api.nvim_buf_get_name(0)))
      assert.is_true(vim.api.nvim_buf_is_loaded(outside_buf), "expected the outside buffer to be kept")
      assert.same({ "outside" }, vim.api.nvim_buf_get_lines(outside_buf, 0, -1, false))
    end)

    it("creates the note in a custom notes folder (new-note-from-template.feature)", function()
      local meetings = vault .. "/Meetings"
      Obsidian.opts.notes_subdir = "Meetings"
      vim.fn.mkdir(meetings, "p")

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)

      local in_meetings = vim.fn.glob(meetings .. "/*.md", false, true)
      local in_inbox = vim.fn.glob(inbox .. "/*.md", false, true)

      assert.equal(1, #in_meetings, "expected one note in 'Meetings' after <leader>nt")
      assert.same({}, in_inbox, "expected no note in 'fixture-inbox' when notesFolder is 'Meetings'")
    end)

    it("creates the notes folder when it does not exist (new-note-from-template.feature)", function()
      local meetings = vault .. "/Meetings"
      assert.equal(0, vim.fn.isdirectory(meetings), "precondition: 'Meetings' must not exist")
      Obsidian.opts.notes_subdir = "Meetings"

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)

      local created = vim.fn.isdirectory(meetings)
      local in_meetings = vim.fn.glob(meetings .. "/*.md", false, true)

      assert.equal(1, created, "expected the missing 'Meetings' folder to be created")
      assert.equal(1, #in_meetings, "expected one note in the created 'Meetings' folder")
    end)

    it("creates no note and keeps the current buffer when the picker is cancelled", function()
      local opened = 0
      require("obsidian.picker").find_files = function()
        opened = opened + 1
      end

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)

      assert.equal(1, opened, "expected the template picker to open exactly once")
      assert.same({}, vim.fn.glob(inbox .. "/*", false, true), "expected no file in 'fixture-inbox' after cancelling")
      assert.equal(work_buf, vim.api.nvim_get_current_buf())
      assert.same({ "# Work" }, vim.api.nvim_buf_get_lines(work_buf, 0, -1, false))
    end)

    it("creates :Obsidian new notes with the default ID in the inbox (new-note-from-template.feature)", function()
      local today = os.date("%Y-%m-%d")

      vim.cmd("Obsidian new")

      local name = vim.fn.resolve(vim.api.nvim_buf_get_name(0))
      local id = vim.fn.fnamemodify(name, ":t:r")
      assert.equal(1, vim.fn.filereadable(name), "expected the new note to exist on disk: " .. name)
      assert.equal(today, id:sub(1, 10), "note ID date prefix is not today's date: " .. id)
      assert.equal(vim.fn.resolve(inbox), vim.fn.fnamemodify(name, ":h"), "expected 'fixture-inbox' as the folder")
      assert.truthy(id:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%d%d$"), "note ID is not YYYY-MM-DD-HHmmss: " .. id)
    end)

    it("names the note after the typed title", function()
      vim.fn.input = function()
        return "Ada Lovelace"
      end

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)

      local file = inbox .. "/Ada Lovelace.md"
      assert.equal(1, vim.fn.filereadable(file), "expected 'Ada Lovelace.md' in 'fixture-inbox'")
      assert.is_true(vim.tbl_contains(vim.fn.readfile(file), "# Ada Lovelace"), "heading is not the typed title")
    end)

    it("fills an unknown template variable from the prompt (new-note-from-template.feature)", function()
      local folder = vault .. "/" .. Obsidian.opts.templates.folder
      local template = folder .. "/Notes.md"
      vim.fn.mkdir(folder, "p")
      vim.fn.writefile({ "Candidate: {{candidate}}" }, template)
      require("obsidian.picker").find_files = function(opts)
        opts.callback({ template })
      end
      vim.fn.input = function(arg)
        local prompt = type(arg) == "table" and arg.prompt or arg
        if tostring(prompt):lower():find("candidate", 1, true) then
          return "Ada"
        end
        return ""
      end

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)

      local files = vim.fn.glob(inbox .. "/*.md", false, true)
      assert.equal(1, #files, "expected one note in 'fixture-inbox' after <leader>nt")
      assert.is_true(
        vim.tbl_contains(vim.fn.readfile(files[1]), "Candidate: Ada"),
        "expected 'Candidate: Ada' in the new note"
      )
    end)

    it("still creates the note when the unknown variable prompt is skipped (new-note-from-template.feature)", function()
      local folder = vault .. "/" .. Obsidian.opts.templates.folder
      local template = folder .. "/Notes.md"
      vim.fn.mkdir(folder, "p")
      vim.fn.writefile({ "Candidate: {{candidate}}" }, template)
      require("obsidian.picker").find_files = function(opts)
        opts.callback({ template })
      end
      local problems = {}
      vim.notify = function(msg, level, opts)
        if level and level >= vim.log.levels.WARN and opts and opts.title == "Obsidian.nvim" then
          table.insert(problems, tostring(msg))
        end
      end

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)

      assert.same({}, problems, "<leader>nt warned or errored when the variable prompt was skipped")
      local files = vim.fn.glob(inbox .. "/*.md", false, true)
      assert.equal(1, #files, "expected one note in 'fixture-inbox' after skipping the prompt")
      assert.is_true(
        vim.tbl_contains(vim.fn.readfile(files[1]), "Candidate: {{candidate}}"),
        "expected the unresolved 'Candidate: {{candidate}}' line in the new note"
      )
      local id = vim.fn.fnamemodify(files[1], ":t:r")
      assert.truthy(id:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%d%d%d%d$"), "note ID is not YYYY-MM-DD-HHmmss: " .. id)
    end)

    it("shows no templates and creates no note when the templates folder is empty", function()
      local picker = require("obsidian.picker")
      local empty = vault .. "/empty-templates"
      vim.fn.mkdir(empty, "p")
      Obsidian.opts.templates.folder = "empty-templates"
      picker.find_files = orig_find_files
      local shown
      picker.select = function(items)
        shown = items
      end

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)
      local listed = vim.wait(5000, function()
        return shown ~= nil
      end, 10)

      assert.is_true(listed, "expected the template picker to open")
      assert.same({}, shown, "expected the picker to list no templates")
      assert.same({}, vim.fn.glob(inbox .. "/*", false, true), "expected no file in 'fixture-inbox' after cancelling")
      assert.equal(work_buf, vim.api.nvim_get_current_buf())
    end)

    it("offers only Markdown files from the templates folder (new-note-from-template.feature)", function()
      local picker = require("obsidian.picker")
      local image = vault .. "/" .. Obsidian.opts.templates.folder .. "/image.png"
      vim.fn.writefile({ "not markdown" }, image)
      picker.find_files = orig_find_files
      local shown
      picker.select = function(items)
        shown = items
      end

      vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)
      local listed = vim.wait(5000, function()
        return shown ~= nil
      end, 10)

      assert.is_true(listed, "expected the template picker to open")
      local names = vim.tbl_map(function(item)
        return vim.fn.fnamemodify(type(item) == "table" and (item.filename or item.value or item[1]) or item, ":t")
      end, shown)
      assert.is_true(vim.tbl_contains(names, "Interview.md"), "expected 'Interview' listed: " .. vim.inspect(shown))
      assert.is_false(vim.tbl_contains(names, "image.png"), "expected 'image.png' not listed: " .. vim.inspect(shown))
    end)

    for state, folder in pairs({ ["unset"] = vim.NIL, ["a directory that is missing"] = "no-such-dir" }) do
      it("warns once and creates nothing when the templates folder is " .. state, function()
        local picked, notices = false, {}
        Obsidian.opts.templates.folder = folder ~= vim.NIL and folder or nil
        require("obsidian.picker").find_files = function()
          picked = true
        end
        vim.notify = function(msg, level)
          table.insert(notices, { msg = msg, level = level })
        end
        vim.v.errmsg = ""

        vim.api.nvim_feedkeys(vim.keycode(vim.g.mapleader .. "nt"), "x", false)

        local errmsg = vim.v.errmsg
        assert.equal("", errmsg, "<leader>nt raised an error")
        assert.is_false(picked, "picker must not open when the templates folder is unusable")
        local warnings = vim.tbl_filter(function(n)
          return n.level == vim.log.levels.WARN or n.level == vim.log.levels.ERROR
        end, notices)
        assert.equal(1, #warnings, "expected exactly one WARN/ERROR notification, got: " .. vim.inspect(notices))
        assert.truthy(
          tostring(warnings[1].msg):find("Templates folder is not defined or does not exist", 1, true),
          "unexpected warning: " .. vim.inspect(warnings[1])
        )
        assert.same({}, vim.fn.glob(inbox .. "/*", false, true), "expected no file in 'fixture-inbox'")
      end)
    end
  end)

  describe("daily notes alongside templates", function()
    local journal = vault .. "/fixture-journal"
    local tab, cwd

    -- obsidian.nvim opens notes at symlink-resolved paths (macOS /var -> /private/var).
    local function in_journal(name)
      return name ~= ""
        and vim.startswith(vim.fs.normalize(vim.fn.resolve(name)), vim.fs.normalize(vim.fn.resolve(journal)))
    end

    setup(function()
      vim.cmd("tabnew")
      tab = vim.api.nvim_get_current_tabpage()
      cwd = vim.fn.tempname()
      vim.fn.mkdir(cwd, "p")
      vim.cmd("tcd " .. vim.fn.fnameescape(cwd))
    end)

    after_each(function()
      -- Wipe the note buffer so it cannot outlive its deleted file.
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if in_journal(vim.api.nvim_buf_get_name(b)) then
          vim.cmd("bwipeout! " .. b)
        end
      end
      vim.fn.delete(journal, "rf")
    end)

    teardown(function()
      -- Wiping the note buffer may already have closed the tab's last window.
      if vim.api.nvim_tabpage_is_valid(tab) then
        vim.cmd("tabclose! " .. vim.api.nvim_tabpage_get_number(tab))
      end
      vim.fn.delete(cwd, "rf")
    end)

    it("opens today's note in the daily notes folder (new-note-from-template.feature)", function()
      vim.cmd("Obsidian today")
      -- Note:open() schedules the buffer switch; a sentinel scheduled after it
      -- runs after it, so it cannot land in a later spec's window.
      local flushed = false
      vim.schedule(function()
        flushed = true
      end)
      assert.is_true(
        vim.wait(1000, function()
          return flushed
        end, 1),
        "expected the scheduled buffer switch to flush"
      )
      assert.is_true(in_journal(vim.api.nvim_buf_get_name(0)), "expected today's note to be the current buffer")

      assert.same(
        { vim.fs.normalize(journal .. "/" .. os.date("%Y-%m-%d") .. ".md") },
        vim.tbl_map(vim.fs.normalize, vim.fn.glob(journal .. "/*", false, true)),
        "expected :Obsidian today to create today's note in dailyNotes.folder 'fixture-journal'"
      )
    end)
  end)
end)
