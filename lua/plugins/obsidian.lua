local yaml_utils = require("lib.yaml_utils")
local obsidian_utils = require("lib.obsidian_utils")
local paths = require("config.paths")

-- Vault location and daily-note placement come from config.yml
-- (config.obsidian), resolved at spec-eval time exactly as plugins/theme.lua
-- reads theme.yml. A missing or malformed file silently yields the defaults in
-- lib/obsidian_utils.lua. vim.fn.expand handles the `$HOME`/`~` in the stored
-- path, which the pure resolver deliberately leaves literal.
local cfg = obsidian_utils.resolve_config(yaml_utils.read_file(paths.config_file("config.yml")))
local vault = vim.fn.expand(cfg.vault)

return {
  {
    "obsidian-nvim/obsidian.nvim",
    -- Latest release rather than main: upstream warns that main's README may
    -- reference unreleased features.
    version = "*",
    -- No ft/event/cmd trigger. Upstream documents no lazy-loading anywhere, and
    -- the plugin's own FileType autocmd is what registers the BufEnter hook
    -- that installs buffer keymaps and starts its in-process LSP — creating
    -- that autocmd *during* the FileType event it needs would miss the first
    -- buffer, the trap plugins/markdown.lua works around with catch-up loops.
    -- Same reasoning as plugins/treesitter.lua's lazy = false.
    lazy = false,
    -- snacks must be on the runtimepath, not merely installed: obsidian probes
    -- for a picker with api.get_plugin_info, which scans nvim_list_runtime_paths
    -- — so a keys-lazy snacks reads as "not available" and obsidian silently
    -- falls back to a vim.ui.select picker. Declaring the dependency makes
    -- lazy.nvim load snacks first, which costs a little startup time and is the
    -- price of `picker.name` below actually taking effect.
    dependencies = { "folke/snacks.nvim" },
    ---@module 'obsidian'
    ---@type obsidian.config
    opts = {
      -- One workspace for the whole vault, not one per subdirectory: ~/Vaults
      -- is itself the vault. See lib/obsidian_utils.lua for the full reasoning.
      workspaces = obsidian_utils.workspaces(vault),

      -- Reuse the picker snacks.nvim already provides (plugins/picker.lua).
      -- "snacks.picker" is the exact value obsidian.config.Picker expects.
      picker = { name = "snacks.picker" },

      -- render-markdown.nvim (plugins/markdown.lua) owns markdown rendering.
      -- obsidian detects it and skips its own UI anyway, but saying so
      -- explicitly avoids a `git rev-parse` shell-out per lookup and matches
      -- upstream's stated direction of removing the UI module.
      ui = { enable = false },

      -- Only the `:Obsidian <subcommand>` form; drops the legacy
      -- :ObsidianFoo aliases, which upstream stops maintaining in 4.0.0.
      legacy_commands = false,

      daily_notes = {
        folder = cfg.dailyNotes.folder,
        date_format = cfg.dailyNotes.dateFormat,
        -- Upstream defaults this to true, which only shifts what
        -- `:Obsidian yesterday`/`tomorrow` resolve to. Off keeps them literal.
        workdays_only = false,
      },
    },
  },

  -- snacks.nvim opts fragment (lazy.nvim merges it with plugins/picker.lua's).
  -- Image viewing lives here rather than there so the require("obsidian.api")
  -- below sits in the file that owns obsidian.
  {
    "folke/snacks.nvim",
    opts = {
      image = {
        enabled = true,
        -- Vault attachments are referenced by their encoded base name, not a
        -- path relative to the note, so snacks cannot find them on its own.
        -- This is the hook obsidian's wiki documents for the job; it is scoped
        -- to notes, leaving image resolution in other markdown files alone.
        resolve = function(path, src)
          local api = require("obsidian.api")
          if api.path_is_note(path) then
            return api.resolve_attachment_path(src)
          end
        end,
      },
    },
  },
}
