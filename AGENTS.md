# Neovim Configuration

`CLAUDE.md` is a symlink to this file — `AGENTS.md` is the single source of truth for project instructions.

## Directory Structure

```text
~/.config/nvim/
├── init.lua                   # Entry point — requires config.options, autocmds, keymaps, commands, then config.lazy
├── AGENTS.md                  # This file — project instructions (single source of truth)
├── CLAUDE.md                  # Symlink -> AGENTS.md
├── CONTRIBUTING.md            # Contributor guide (setup, tests, style, PR workflow); excluded from releases
├── lazy-lock.json             # Plugin version lockfile (commit-pinned)
├── Taskfile.yml                # Task runner: `task lint`, `task format` (stylua + markdownlint --fix), `task test`
├── .busted                    # Busted config: `unit` task (tests/unit) + `integration` task (tests/integration)
├── .markdownlint.jsonc        # Base markdownlint config for live linting (MD013 aligned to textwidth=120)
├── selene.toml                # Lua linter config (std = "busted+lua51+vim")
├── stylua.toml                # Lua formatter config (2-space indent, 120 columns; used by `task format` + conform.nvim)
├── vim.yml                    # Vendored selene std: declares the `vim` global
├── busted.yml                 # Vendored selene std: busted test globals (describe/it/luassert)
├── theme.yml                  # Theme configuration (sourced by plugins/theme.lua; see docs/theming.md)
├── config.yml                 # Editor configuration (:Daily note dir + filename format; Harper harper-ls options)
├── docs/                      # User documentation, linked from README.md's table of contents; ships in the release
├── scripts/
│   ├── busted-nvim.sh         # Busted interpreter shim: integration specs in a headless nvim; fixtures via NVIM_CONFIG_ROOT
│   ├── check.sh               # Everything CI runs, in order: lint, unit, integration, guard path
│   ├── debug-keys.lua         # :luafile it to log which key/mouse events actually reach Neovim
│   ├── headless-lua.sh        # Run a Lua script in a fully-loaded headless nvim (`nvim -l` skips user config)
│   ├── test-without-binary.sh # Run a command with one binary hidden from PATH (test executable-guard fallbacks)
│   └── verify-config-isolation.sh # Proves integration tests ignore the real config files (corrupt + byte-restore via trap)
└── lua/
    ├── config/
    │   ├── autocmds.lua       # Editor autocommands (auto-create parent dirs on save; auto-save on InsertLeave)
    │   ├── commands.lua       # Command-line overrides (:q/:x/:wq close current buffer) + :Daily note command (reads config.yml)
    │   ├── folding.lua        # Shared fold UX: <Tab> toggle, ▼/▶ statuscolumn indicator, click-to-toggle
    │   ├── keymaps.lua        # Core (non-plugin) keymaps (Alt+Up/Down move line, <leader>nd daily note)
    │   ├── lazy.lua           # lazy.nvim bootstrap + setup
    │   ├── lsp_servers.lua    # Language-server table (single source; plugins/lsp.lua + lsp_spec; harper_ls ← config.yml)
    │   ├── options.lua        # Leader keys + core editor options (wrap, textwidth, mouse, mousemodel)
    │   └── paths.lua          # Config-file path seam (config_root/config_file); NVIM_CONFIG_ROOT redirects to fixtures
    ├── lib/
    │   ├── daily_utils.lua    # Pure-Lua :Daily config resolver (config.yml over defaults, NVIM_NOTES_DIR override)
    │   ├── harper_utils.lua   # Pure-Lua harper-ls settings resolver (config.harper over harper's defaults)
    │   ├── markdown_fold.lua  # Pure-Lua fold-level computation (headings, list items, fenced code blocks)
    │   ├── markdown_utils.lua # Pure-Lua utility functions for markdown editing
    │   ├── path_utils.lua     # Pure-Lua path helpers (URI-scheme detection)
    │   ├── save_utils.lua     # Pure-Lua auto-save predicate (which buffers are safe to write)
    │   ├── search_utils.lua   # Pure-Lua case-insensitive substring matcher (grep fallback)
    │   └── yaml_utils.lua     # Pure-Lua minimal YAML-subset parser incl. block sequences (reads theme.yml + config.yml)
    └── plugins/
        ├── explorer.lua       # File-tree sidebar (neo-tree.nvim)
        ├── git.lua            # Lazygit integration (lazygit.nvim)
        ├── lsp.lua            # Language servers (nvim-lspconfig + mason) + completion (blink.cmp)
        ├── markdown.lua       # All markdown plugin specs
        ├── multicursor.lua    # Real-time multiple cursors (multiple-cursors.nvim)
        ├── picker.lua         # Fuzzy file picker + project grep (snacks.nvim, picker module only)
        ├── theme.lua          # Colorscheme — spec built from theme.yml merged over defaults (github-nvim-theme)
        ├── treesitter.lua     # nvim-treesitter (main branch) — highlight queries for code-fence syntax highlighting
        ├── ui.lua             # UI plugins (bufferline.nvim, lualine.nvim)
        └── zen.lua            # Distraction-free writing (zen-mode.nvim)
└── tests/
    ├── integration/               # Busted specs run INSIDE a fully-loaded headless Neovim (real vim API)
    │   ├── helper.lua             # Busted helper: records vim.notify from session start (require("notify_log"))
    │   ├── autosave_spec.lua      # auto_save contract (InsertLeave-only trigger, nested write autocmds)
    │   ├── commands_spec.lua      # :BufClose/:BufWriteClose + :q/:x/:wq abbreviations, :Daily end-to-end
    │   ├── folding_spec.lua       # Fold wiring (foldexpr/statuscolumn/<Tab>), toggling, ▼/▶ indicators
    │   ├── keymaps_spec.lua       # Global keymaps (<leader>nd, <leader>bn/bp, <leader>gg)
    │   ├── lsp_spec.lua           # LSP wiring (LspAttach keymaps, server configs) + guarded attach path
    │   ├── markdown_lint_spec.lua # nvim-lint wiring + functional/missing-binary guard paths
    │   ├── multicursor_spec.lua   # multiple-cursors.nvim maps, commands, virtual-cursor core loop
    │   ├── options_spec.lua       # Leader keys (load-order regression guard)
    │   └── theme_spec.lua         # theme.yml sourcing (variant applied, plugin name, italic comments)
    └── unit/                      # Pure-Lua Busted specs for lua/lib/ (no Neovim involved)
        ├── daily_utils_spec.lua
        ├── harper_utils_spec.lua
        ├── markdown_fold_spec.lua
        ├── markdown_utils_spec.lua
        ├── path_utils_spec.lua
        ├── save_utils_spec.lua
        ├── search_utils_spec.lua
        └── yaml_utils_spec.lua
```

`init.lua` calls the entry point that calls the following files:

- `config.options`
- `config.autocmd`
- `config.keymaps`
- `config.commands`
- `config.lazy`

All plugin specs live under `lua/plugins/` and
are auto-imported by lazy.nvim via `spec = { { import = "plugins" } }` in `lua/config/lazy.lua`. Adding a new
file to `lua/plugins/` is enough to activate new plugins.

Leader keys are set in `options.lua` because it loads first — a
`<leader>` mapping created before `vim.g.mapleader` is set silently and binds under the default.
Don't reorder the `require` lines, and don't set `<leader>` maps anywhere that loads
before `options.lua`.

Tests are run through the `Taskfile.yml` tasks (`task test`, `task test:unit`, `task test:integration`), not
by invoking `busted` directly — see [`dev-workflow.md`](.claude/instructions/dev-workflow.md).

**Never corrupt the real config files (`theme.yml`, `config.yml`, `.markdownlint.jsonc`) in place to test or
prove anything.** Integration tests read only the throwaway fixtures the harness injects via `NVIM_CONFIG_ROOT`
(`scripts/busted-nvim.sh`), so touching the real files is never required. To prove that isolation, run
`scripts/verify-config-isolation.sh` — it corrupts and then byte-restores them under a `trap`, so an interrupted or
failed run can't leave your config broken. Do **not** "restore" an overwritten real file with `git checkout` — it
silently discards uncommitted edits and can't recover untracked content. When a verification genuinely must mutate
tracked files, do it in an isolated `git worktree` or snapshot the exact bytes first and restore from that.

## Agentic Process

Always delegate the tasks to following subagents:

- `Plan` agent whenever the user asks to plan, design, architect, or research a task
- `Explore` agent when you need to perform rapid local codebase explorations
- `lua-docs-explorer` agent when you need to ground answers to Lua language documentation
- `nvim-docs-explorer` agent when you need to ground answers to Neovim documentation

General-purpose agent is suitable for all other tasks.

## Instructions

Detailed guidance lives under `.claude/instructions/` — read the relevant file before touching that area:

| File                                                      | Covers                                                                                                                                                                                                   |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`config.md`](.claude/instructions/config.md)             | lazy.nvim bootstrap, plugin globals vs `require`, editor options, core keymaps, `:q`/`:x`/`:wq` overrides, `:Daily` note command, autocommands (auto-create dirs, auto-save), the global keymap registry |
| [`markdown.md`](.claude/instructions/markdown.md)         | `lib/markdown_utils.lua`, `plugins/markdown.lua` (markdown-plus, render-markdown, conform, nvim-lint live linting), `<C-S-I>` terminal caveat                                                            |
| [`plugins.md`](.claude/instructions/plugins.md)           | theme, bufferline/lualine, zen-mode, lazygit, snacks.nvim picker                                                                                                                                         |
| [`explorer.md`](.claude/instructions/explorer.md)         | neo-tree file-tree sidebar                                                                                                                                                                               |
| [`lsp.md`](.claude/instructions/lsp.md)                   | language servers (`plugins/lsp.lua`): servers table, mason install flow, blink.cmp, LspAttach keymaps, refactor menu, diagnostics coexistence                                                            |
| [`dev-workflow.md`](.claude/instructions/dev-workflow.md) | Adding/fetching plugins, running tests, headless Lua verification                                                                                                                                        |

Check `config.md` file Global Keymap Registry before adding any new global keymap — eight files declare keys and
there's no other index.

**Before setting any editor option that affects the left gutter** (`number`, `relativenumber`, `signcolumn`,
`foldcolumn`), read `config/folding.lua` first. Its custom `statuscolumn` fully replaces Neovim's built-in gutter
rendering for every buffer where folding is enabled (markdown buffers, and any LSP buffer whose server advertises
`foldingRangeProvider` — i.e. most buffers in practice), so a built-in option's default rendering does **not**
apply automatically there. See `config.md`'s "Statuscolumn Ownership" section for what re-implementing it
involves (e.g. `number` needed a manually-composed, `numberwidth`-padded `%l` item).

**Bindings must survive the terminal.** This config runs in Warp on macOS with a trackpad: the OS and terminal
rewrite or swallow events before Neovim sees them. Ctrl+arrows go to Mission Control. Ctrl+click becomes a
right-click and Warp strips the Ctrl modifier from mouse reports.

Read `config.md` file "Mouse/terminal caveat"
before choosing any Ctrl-chord or mouse binding, and diagnose "dead" bindings with
`:luafile scripts/debug-keys.lua` — `:map` only proves registration, not delivery.
