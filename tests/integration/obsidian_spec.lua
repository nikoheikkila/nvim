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
end)
