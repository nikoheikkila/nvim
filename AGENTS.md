# Neovim Configuration

`CLAUDE.md` is a symlink to this file — `AGENTS.md` is the single source of truth for project instructions.

## Layout

- `init.lua` requires, in order: `config.options`, `config.autocmds`, `config.keymaps`, `config.commands`,
  `config.lazy`. Leader keys are set in `config/options.lua` because it loads first — a `<leader>` map created
  before `vim.g.mapleader` is set silently binds under the default `\`. Don't reorder those requires, and don't
  create `<leader>` maps in anything that loads before `options.lua`.
- `lua/plugins/*.lua` return lazy.nvim specs and are auto-imported via `spec = { { import = "plugins" } }` in
  `config/lazy.lua` — adding a file there is all it takes to activate a plugin.
- `lua/lib/*.lua` is pure Lua with no `vim` dependency, unit-tested outside Neovim (`tests/unit/`). Logic that can
  live there generally should: `tests/integration/` boots a real headless Neovim, and is slower and more coupled.
- `theme.yml` and `config.yml` are the user-facing configuration surface, parsed by `lib/yaml_utils.lua`. New
  user-tunable settings belong there rather than hardcoded in Lua — extend the parser if the shape doesn't fit.
- `scripts/` holds the test and verification harnesses. `Taskfile.yml` (`task -a`) is the entry point for
  lint, format, and test.

## Invariants

- Tests run through `Taskfile.yml` (`task test`, `task test:unit`, `task test:integration`). Invoking `busted`
  directly resolves the wrong rocks tree — see [`dev-workflow.md`](.claude/instructions/dev-workflow.md).
- Don't edit the real `theme.yml`, `config.yml`, or `.markdownlint.jsonc` to test or prove something. Integration
  specs read throwaway fixtures injected via `NVIM_CONFIG_ROOT` (`scripts/busted-nvim.sh`), so mutating the real
  files is never required — and `git checkout` won't restore uncommitted or untracked content afterwards.
  `scripts/verify-config-isolation.sh` demonstrates the isolation safely (corrupt + byte-restore under a `trap`).
- Check the Global Keymap Registry in `config.md` before choosing a key for a new mapping, and add a row when you
  create one. Keymaps are otherwise scattered across `keys` tables in a dozen files with no other index.
- `config/folding.lua` owns `statuscolumn` in markdown buffers and in any LSP buffer whose server advertises
  `foldingRangeProvider` — i.e. most buffers. It fully replaces Neovim's gutter rendering there, so `number`,
  `relativenumber`, `signcolumn`, and `foldcolumn` do not draw on their own. Read it, and "Statuscolumn Ownership"
  in `config.md`, before setting any gutter option.
- Bindings have to survive the terminal. This config runs in Warp on macOS with a trackpad, where the OS and
  terminal rewrite or swallow events before Neovim sees them: Ctrl+arrows go to Mission Control, and Ctrl+click
  arrives as a right-click with the modifier stripped. Read "Mouse/terminal caveat" in `config.md` before choosing
  a Ctrl-chord or mouse binding. `:map` proves registration, not delivery — `:luafile scripts/debug-keys.lua`
  proves delivery.

## Instructions

Detailed guidance lives under `.claude/instructions/`. Read the file covering an area before changing it.

- [`config.md`](.claude/instructions/config.md) — `lua/config/`: options, autocommands, core keymaps,
  `:q`/`:x`/`:wq` overrides, statuscolumn and fold-source ownership, the Global Keymap Registry, the
  mouse/terminal caveat
- [`markdown.md`](.claude/instructions/markdown.md) — `lib/markdown_utils.lua` and the markdown plugin stack:
  markdown-plus, render-markdown, conform, nvim-lint live linting, folding
- [`plugins.md`](.claude/instructions/plugins.md) — theme, treesitter, bufferline/lualine, zen-mode, lazygit,
  multicursor, snacks.nvim picker
- [`obsidian.md`](.claude/instructions/obsidian.md) — Obsidian vault: `config.yml` plumbing, the
  single-workspace decision, coexistence opts, snacks.image
- [`explorer.md`](.claude/instructions/explorer.md) — neo-tree file-tree sidebar
- [`lsp.md`](.claude/instructions/lsp.md) — language servers: the servers table, mason install flow, blink.cmp,
  LspAttach keymaps, refactor menu, diagnostics coexistence
- [`dev-workflow.md`](.claude/instructions/dev-workflow.md) — adding and fetching plugins, running the test
  suites, headless Lua verification
