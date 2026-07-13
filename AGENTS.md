# Neovim Configuration

`CLAUDE.md` is a symlink to this file — `AGENTS.md` is the single source of truth for project instructions.

## Directory Structure

```
~/.config/nvim/
├── init.lua                   # Entry point — requires config.options, autocmds, keymaps, commands, then config.lazy
├── AGENTS.md                  # This file — project instructions (single source of truth)
├── CLAUDE.md                  # Symlink -> AGENTS.md
├── lazy-lock.json             # Plugin version lockfile (commit-pinned)
├── selene.toml                # Lua linter config (std = "lua51+vim")
├── vim.yml                    # Vendored selene std: declares the `vim` global
├── scripts/
│   ├── headless-lua.sh        # Run a Lua script in a fully-loaded headless nvim (`nvim -l` skips user config)
│   ├── lazy-install.sh        # Safe plugin fetch: `:Lazy install`, not `:Lazy sync`
│   ├── lint.sh                # Runs `selene lua/` (same command CI runs)
│   └── test-without-binary.sh # Run a command with one binary hidden from PATH (test executable-guard fallbacks)
└── lua/
    ├── config/
    │   ├── autocmds.lua       # Editor autocommands (auto-create parent dirs on save)
    │   ├── commands.lua       # Command-line overrides (:q/:x/:wq close current buffer, not Neovim)
    │   ├── keymaps.lua        # Core (non-plugin) keymaps (Alt+Up/Down move line)
    │   ├── lazy.lua           # lazy.nvim bootstrap + setup
    │   └── options.lua        # Core editor options (wrap, textwidth, colorcolumn)
    ├── lib/
    │   ├── markdown_utils.lua # Pure-Lua utility functions for markdown editing
    │   ├── path_utils.lua     # Pure-Lua path helpers (URI-scheme detection)
    │   └── search_utils.lua   # Pure-Lua case-insensitive substring matcher (grep fallback)
    └── plugins/
        ├── explorer.lua       # File-tree sidebar (neo-tree.nvim)
        ├── git.lua            # Lazygit integration (lazygit.nvim)
        ├── markdown.lua       # All markdown plugin specs
        ├── picker.lua         # Fuzzy file picker + project grep (snacks.nvim, picker module only)
        ├── theme.lua          # Colorscheme (laserwave.nvim, transparent)
        ├── ui.lua             # UI plugins (bufferline.nvim, lualine.nvim)
        └── zen.lua            # Distraction-free writing (zen-mode.nvim)
└── tests/
    ├── markdown_utils_spec.lua  # Busted unit tests for lib/markdown_utils.lua
    └── search_utils_spec.lua    # Busted unit tests for lib/search_utils.lua
```

`init.lua` calls `require("config.options")`, then `require("config.autocmds")`, then `require("config.keymaps")`, then `require("config.commands")`, then `require("config.lazy")`. All plugin specs live under `lua/plugins/` and are auto-imported by lazy.nvim via `spec = { { import = "plugins" } }` in `lua/config/lazy.lua`. Adding a new file to `lua/plugins/` is enough to activate new plugins.

## Instructions

Detailed guidance lives under `.claude/instructions/` — read the relevant file before touching that area:

| File | Covers |
|---|---|
| [`config.md`](.claude/instructions/config.md) | lazy.nvim bootstrap, plugin globals vs `require`, editor options, core (Alt-key) keymaps, `:q`/`:x`/`:wq` overrides, the global keymap registry |
| [`markdown.md`](.claude/instructions/markdown.md) | `lib/markdown_utils.lua`, `plugins/markdown.lua` (markdown-plus, render-markdown, conform), `<C-S-I>` terminal caveat |
| [`plugins.md`](.claude/instructions/plugins.md) | theme, bufferline/lualine, zen-mode, lazygit, snacks.nvim picker |
| [`explorer.md`](.claude/instructions/explorer.md) | neo-tree file-tree sidebar |
| [`dev-workflow.md`](.claude/instructions/dev-workflow.md) | Adding/fetching plugins, running tests, headless Lua verification |

Check `config.md`'s Global Keymap Registry before adding any new global keymap — six files declare keys and there's no other index.
