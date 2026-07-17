# Smaller Plugins

Covers `theme.lua`, `treesitter.lua`, `ui.lua`, `zen.lua`, `git.lua`, `multicursor.lua`, `picker.lua`. See `explorer.md` for neo-tree (kept standalone — the longest single-plugin section) and `markdown.md` for the markdown plugin stack.

### `lua/plugins/theme.lua` — `projekt0n/github-nvim-theme`

Loads the `github_dark_default` colorscheme. `setup()` is called with `styles = { comments = "italic" }` — the theme's default is `'NONE'`, and italic comments are wanted both in regular code and inside markdown fences (injected `@comment` captures merge italic over the non-italic fence-content group set in `markdown.lua`'s `fix_highlights`). `setup()` must run *before* the `colorscheme` command or the style options don't apply.

### `lua/plugins/treesitter.lua` — `nvim-treesitter/nvim-treesitter` (branch `main`)

Supplies the treesitter highlight queries that make syntax highlighting inside markdown code fences work. Neovim's bundled ftplugin already starts treesitter for markdown buffers and the injection query parses fence content with the matching language parser — but without this plugin's query files, injected code gets **zero highlight captures** (the symptom: fences render as uniform theme-colored text).

- `branch = "main"` — `master` is frozen upstream; `main` requires Neovim 0.11+ and the `tree-sitter` CLI ≥ 0.25 (`brew install tree-sitter-cli` — note the plain `tree-sitter` formula now installs only the library).
- `lazy = false` — upstream states the main branch does not support lazy-loading.
- `build = ":TSUpdate"` keeps compiled parsers in sync with the plugin's queries. The build is async; to run it synchronously (e.g. after a headless install): `nvim --headless -c "lua require('nvim-treesitter').update():wait(300000)" -c "qa!"`.
- **Fragile coupling**: the entries in `~/.local/share/nvim/site/queries/` are *symlinks into this plugin's* `runtime/queries/` directory, and compiled parsers live in `~/.local/share/nvim/site/parser/`. Removing the plugin (e.g. via `:Lazy clean` after deleting the spec) leaves the parsers behind but breaks every query symlink — fence highlighting dies silently while `vim.treesitter.language.add()` still succeeds. Diagnose with `:lua =vim.treesitter.query.get("javascript", "highlights")` (nil = queries missing).
- No `setup()` call and no per-filetype `vim.treesitter.start()` autocmd — markdown injection only needs parsers + queries on disk. Auto-starting treesitter highlighting for standalone code buffers would be a deliberate, separate addition here.

### `lua/plugins/ui.lua`

**`akinsho/bufferline.nvim`** — Buffer tabs at the top. Cycling: `<S-h>`/`<S-l>`, `[b`/`]b`, and `<leader>n`/`<leader>p`; reordering: `[B`/`]B`; pin/close/pick: `<leader>bp`/`bP`/`br`/`bl`/`bj` (full list in `config.md`'s Global Keymap Registry). The tab `X` button and right-click both close **only that buffer** — `close_command`/`right_mouse_command` are set to `function(n) require("snacks.bufdelete").delete(n) end` (not the previous `"bdelete! %d"`), so they preserve the window layout and never quit Neovim; they prompt before discarding a modified buffer. There is no `<leader>bd`-style delete keymap. See `config.md`'s "Command-line Overrides" for the matching `:q`/`:x` behavior.

**`nvim-lualine/lualine.nvim`** — Status line showing mode, git branch, diagnostics, diff stats, and clock.

### `lua/plugins/zen.lua` — `folke/zen-mode.nvim`

Distraction-free writing mode. `<C-z>` toggles Zen Mode (global keymap). Disables line numbers, sign column, cursorline, and sets window width to 80 columns.

### `lua/plugins/git.lua` — `kdheepak/lazygit.nvim`

Opens Lazygit in a floating window ("modal") over the current buffer. Lazy-loaded via its `keys` and `cmd` triggers; depends on `nvim-lua/plenary.nvim` for path handling.

- `<leader>g` (global keymap) runs `:LazyGitCurrentFile`, scoping Lazygit to the **current file's Git repository** (falling back to the project/cwd Git root). Quit Lazygit with `q` to return to the buffer.
- A **PATH guard** checks `vim.fn.executable("lazygit")` first and emits a clean `vim.notify` error instead of a raw stack trace when the binary is missing.
- Floating-window options are set in `init` (`winblend = 0`, `scaling_factor = 0.9`) to stay consistent with the transparent theme background.

### `lua/plugins/multicursor.lua` — `brenton-leighton/multiple-cursors.nvim`

VS Code-style multiple cursors with **real-time** updates: every keystroke is mirrored at each virtual cursor live (insert-mode text via `InsertCharPre`/`TextChangedI` autocmds). This replaced `jake-stewart/multicursor.nvim`, whose insert-mode edits appear at other cursors only on leaving insert mode — an upstream **wontfix** (issues #49/#75: real-time would require simulating insert mode, which that plugin refuses on correctness grounds). The trade-off accepted here: multiple-cursors.nvim simulates a *whitelist* of commands, so normal-mode commands outside the whitelist affect only the real cursor, and its README warns Backspace/Delete/Enter/Tab "may behave incorrectly, in particular with less common indentation options".

- `<M-S-Up>` / `<M-S-Down>` (n, x, i) duplicate the cursor to the adjacent line at the same column (`:MultipleCursorsAddUp`/`AddDown`).
- Visual `I` / `A` run `:MultipleCursorsAddVisualArea` (which puts a cursor at **column 1 of every selected line** in linewise mode) and then feed `I`/`A` *with remapping* so the plugin's whitelist handler enters insert at first non-blank / line end for every cursor, typing live. Single-line selections fall back to a plain `<Esc>I`/`<Esc>A` (AddVisualArea is a no-op on one line).
- `<C-LeftMouse>`, `<C-RightMouse>`, and plain `<RightMouse>` (n, i) all toggle a cursor at the click (`:MultipleCursorsMouseAddDelete`). Three bindings because macOS trackpads synthesize a right-click from Ctrl+click and some terminals (Warp) strip the Ctrl modifier from mouse reports, so the same physical gesture can arrive as any of the three; `mousemodel = "extend"` in `options.lua` keeps Neovim's popup menu from swallowing it (see `config.md`'s mouse/terminal caveat).
- **Reset**: `<Esc>` in normal mode is the plugin's built-in exit (clears all virtual cursors). Plain `<LeftMouse>` reset is hand-rolled: `pre_hook` (fires when the first cursor is added) sets buffer-local `<LeftMouse>` maps — normal mode calls `require("multiple-cursors").deinit(true)` then re-feeds the click noremap (Neovim retains the mouse event's coordinates); insert/visual mode feeds `<Esc>` *with remapping* first so the plugin finalizes the mode at every cursor, then the click hits the normal-mode map. `post_hook` deletes the maps on exit — they have zero footprint otherwise.
- Deliberately `keys`-lazy (no drag/release event triples to lose, unlike the old plugin): all entry points — the maps above — live in the `keys` spec, and `setup()` creates the user commands on first use.
- Test coverage: `tests/integration/multicursor_spec.lua` force-loads the plugin, asserts every map's `desc` and the user commands, and functionally runs `:MultipleCursorsAddDown`, checks `virtual_cursors.get_num_virtual_cursors()` and the presence of the buffer-local click-reset maps, then `deinit(true)` and checks both are gone. Real-time insert mirroring is autocmd-driven and **cannot be asserted headlessly** (synthetic `feedkeys` ordering differs from real UI input — see `dev-workflow.md`); verify it interactively.

### `lua/plugins/picker.lua` — `folke/snacks.nvim` (picker module only)

Fuzzy file finder and project grep, scoped to the current project.

- `<leader><leader>` (mapleader pressed twice) runs `Snacks.picker.files()`, an fzf-style fuzzy finder: type to filter, `<Up>`/`<Down>` (or `<C-j>`/`<C-k>`) to move the selection, `<Enter>` to open the selected file in the current buffer. These are snacks.nvim's picker defaults — no custom keymaps or confirm actions were added.
- `<leader>.` runs a full-project text search. If `rg` is on PATH, it calls `Snacks.picker.grep({ cwd = ... })` — snacks' own live-grep-as-you-type picker, using the same default `<Up>`/`<Down>`/`<Enter>`/`q` keymaps as `files`. If `rg` is missing, it `vim.notify`s a warning and falls back to a native-Lua search: prompt for a term via `vim.ui.input`, walk the project once with `vim.fs.dir`, match lines with `lib/search_utils.lua`, and open the same picker UI (`Snacks.picker.pick({ items = ... })`) with the static results.
- **Project scoping**: `cwd` is computed via `vim.fs.root(0, { ".git" })`, walking up from the current buffer to the enclosing Git repo root, falling back to Neovim's cwd outside a repo — the same pattern already used by `lua/plugins/git.lua`'s Lazygit binding.
- **Why only the picker module is enabled**: snacks.nvim bundles many unrelated features (dashboard, notifier, indent guides, scratch buffers, terminal, zen mode, file explorer, and more). Every module is opt-in by snacks' own design, so leaving a module out of `opts` keeps it disabled — only `picker = { enabled = true }` is set. `zen-mode.nvim` already covers this repo's distraction-free-writing needs, so snacks' own `zen` module is deliberately left off to avoid a redundant, competing implementation.
- No external binary is required for `files` — it opportunistically shells out to `fd`/`ripgrep` if present for faster scanning, otherwise falls back to a pure-Lua directory walker. `grep` has no such built-in fallback in snacks itself (`rg` is hardcoded in its source, confirmed by reading `snacks.nvim/lua/snacks/picker/source/grep.lua`) — the native-Lua fallback described above is hand-rolled in this repo, not provided by snacks.

**Custom picker items without a custom finder**
`Snacks.picker.pick()` accepts a plain `items` table directly (`{ items = {...} }`) — no async `finder` function is required for a static result set; this is what the `<leader>.` fallback relies on. Each item needs: `file` (path, joined with `cwd`), `cwd`, `pos = { line_1based, col_0based }` (used for the jump target and preview), `line` (raw text, rendered in the list), and `text` (used by the picker's own fuzzy re-filter over what's typed). `format = "file"` renders it the same as `files`/`grep`.

**`vim.fs.dir`'s `skip` polarity is inverted from the naive expectation**
The `skip(dir_name)` callback passed to `vim.fs.dir(path, { skip = ... })` must return `false` to *stop* recursing into that directory — any other return value (including `true`) continues the walk (confirmed in the Neovim runtime source, `vim/fs.lua`'s `opts.skip(f) ~= false` check). Easy to get backwards when writing an ignore-list predicate, e.g. `skip = function(name) return not SKIP_DIRS[vim.fs.basename(name)] end`.
