# Smaller Plugins

Covers `theme.lua`, `treesitter.lua`, `ui.lua`, `zen.lua`, `git.lua`, `multicursor.lua`, `picker.lua`,
`search_replace.lua`.
See `explorer.md` for neo-tree (kept standalone — the longest single-plugin section) and `markdown.md`
for the markdown plugin stack.

## `lua/plugins/theme.lua` — `projekt0n/github-nvim-theme` (default)

The lazy spec is built at spec-eval time from the optional root-level `theme.yml` (schema: `url`, `name`,
`variant`, `options`, `groups`), parsed with `lib/yaml_utils.parse` and deep-merged over hardcoded defaults
with `vim.tbl_deep_extend("force", ...)` — so anything the YAML omits keeps the current value. User docs
live in `docs/theming.md`.

- Defaults: `projekt0n/github-nvim-theme`, name `github-theme`, variant `github_dark_default`,
  `options = { styles = { comments = "italic" } }` — the theme's default is `'NONE'`, and italic comments
  are wanted both in regular code and inside markdown fences (injected `@comment` captures merge italic
  over the non-italic fence-content group set in `markdown.lua`'s `fix_highlights`).
- `theme.options` is passed as the **`options` key** of `require(name).setup()` (github-nvim-theme's
  shape) — `name` doubles as the lazy-spec name and the `require()` module.
- `theme.groups` is passed as the **`groups` key** of `setup()` — github-nvim-theme's per-highlight-group
  override mechanism (`groups: { all: { <Group>: { fg/bg/style } } }`), applied at `:colorscheme` time and
  reapplied on colorscheme reloads. The shipped `theme.yml` uses it to render markdown inline code
  (`@markup.raw.markdown_inline` + `RenderMarkdownCodeInline`) non-italic red on dark grey — a group
  defined without `style` fully replaces the theme's italic `@markup.raw` styling. Group names containing
  `@` must be quoted in the YAML.
- `setup()` must run _before_ the `colorscheme` command or the style options don't apply; both are wrapped
  in `pcall` + `vim.notify` so a typo'd `name`/`variant` degrades to default colors, not a startup error.
- `lib/yaml_utils.parse` fails whole-file (returns nil) on any line outside its subset (no lists, anchors,
  multiline scalars, or tabs); quoted keys (double or single) are supported for characters the plain key
  pattern rejects, e.g. `@`; missing/unreadable/malformed `theme.yml` silently yields the defaults.
- Test coverage: `tests/unit/yaml_utils_spec.lua` (parser) and `tests/integration/theme_spec.lua` (variant
  applied, plugin registered, italic comments, `groups.all` overrides applied — expectations derived from
  `theme.yml` via the same parser).

## `lua/plugins/treesitter.lua` — `nvim-treesitter/nvim-treesitter` (branch `main`)

Supplies the treesitter highlight queries that make syntax highlighting inside markdown code fences
work.

Neovim's bundled ftplugin already starts treesitter for markdown buffers and the injection query
parses fence content with the matching language parser — but without this plugin's query files,
injected code gets **zero highlight captures** (the symptom: fences render as uniform theme-colored
text).

- `branch = "main"` — `master` is frozen upstream; `main` requires Neovim 0.11+ and the `tree-sitter`
  CLI ≥ 0.25 (`brew install tree-sitter-cli` — note the plain `tree-sitter` formula now installs only
  the library).
- `lazy = false` — upstream states the main branch does not support lazy-loading.
- `build = ":TSUpdate"` keeps compiled parsers in sync with the plugin's queries. The build is async;
  to run it synchronously (e.g. after a headless install):
  `nvim --headless -c "lua require('nvim-treesitter').update():wait(300000)" -c "qa!"`.
- **Fragile coupling**: the entries in `~/.local/share/nvim/site/queries/` are _symlinks into this
  plugin's_ `runtime/queries/` directory, and compiled parsers live in
  `~/.local/share/nvim/site/parser/`. Removing the plugin (e.g. via `:Lazy clean` after deleting the
  spec) leaves the parsers behind but breaks every query symlink — fence highlighting dies silently
  while `vim.treesitter.language.add()` still succeeds. Diagnose with
  `:lua =vim.treesitter.query.get("javascript", "highlights")` (nil = queries missing).
- No `setup()` call and no per-filetype `vim.treesitter.start()` autocmd — markdown injection only
  needs parsers + queries on disk. Auto-starting treesitter highlighting for standalone code buffers
  would be a deliberate, separate addition here.

## `lua/plugins/ui.lua`

**`akinsho/bufferline.nvim`** — Buffer tabs at the top. Cycling: `<S-h>`/`<S-l>`, `[b`/`]b`, and
`<leader>n`/`<leader>p`; reordering: `[B`/`]B`; pin/close/pick: `<leader>bp`/`bP`/`br`/`bl`/`bj` (full
list in `config.md`'s Global Keymap Registry).

The tab `X` button and right-click both close **only
that buffer** — `close_command`/`right_mouse_command` are set to
`function(n) require("snacks.bufdelete").delete(n) end` (not the previous `"bdelete! %d"`), so they
preserve the window layout and never quit Neovim; they prompt before discarding a modified buffer.

There is no `<leader>bd`-style delete keymap. See `config.md`'s "Command-line Overrides" for the
matching `:q`/`:x` behavior.

**`nvim-lualine/lualine.nvim`** — Status line showing mode, git branch, diagnostics, diff stats, and
clock.

## `lua/plugins/zen.lua` — `folke/zen-mode.nvim`

Distraction-free writing mode. `<C-z>` toggles Zen Mode (global keymap).

Disables line numbers, sign
column, cursorline, and sets window width to 80 columns.

## `lua/plugins/git.lua` — `kdheepak/lazygit.nvim`

Opens Lazygit in a floating window ("modal") over the current buffer. Lazy-loaded via its `keys` and
`cmd` triggers; depends on `nvim-lua/plenary.nvim` for path handling.

- `<leader>gg` (global keymap) runs `:LazyGitCurrentFile`, scoping Lazygit to the **current file's Git
  repository**, then the cwd. Quit Lazygit with `q` to return to the buffer.
- **`nvim <directory>` works here without any root logic of its own**, and that is worth understanding
  before "fixing" it again. The command resolves the repo from `expand("%:p:h")`, which for the unnamed
  buffer netrw leaves on a directory is the cwd; when its own `git rev-parse` finds nothing it omits `-p`
  and the `lazygit` job inherits Neovim's cwd. Both paths land on the cwd — which `config/autocmds.lua`'s
  `startup_dir` augroup has already pointed at the directory argument. (This binding did once resolve the
  repo by hand and pass it as `lazygit -p <repo>`; that was redundant once the chdir existed. Note
  `fnamemodify(<dir>, ":p:h")` is the directory itself, not its parent — `:p` appends the slash that `:h`
  then strips.)
- A second guard calls `vim.fs.root(0, { ".git" })` purely to replace lazygit's own "not a git
  repository" init prompt with a `vim.notify` warning. It predicts that outcome because `vim.fs.root`
  falls back to the cwd for unnamed buffers, the same signal lazygit ends up using.
- A **PATH guard** checks `vim.fn.executable("lazygit")` first and emits a clean `vim.notify` error
  instead of a raw stack trace when the binary is missing.
- Floating-window options are set in `init` (`winblend = 0`, `scaling_factor = 0.9`) to stay consistent
  with the transparent theme background.

## `lua/plugins/multicursor.lua` — `brenton-leighton/multiple-cursors.nvim`

VS Code-style multiple cursors with **real-time** updates: every keystroke is mirrored at each virtual
cursor live (insert-mode text via `InsertCharPre`/`TextChangedI` autocmds).

- `<M-S-Up>` / `<M-S-Down>` (n, x, i) duplicate the cursor to the adjacent line at the same column
  (`:MultipleCursorsAddUp`/`AddDown`).
- Visual `I` / `A` run `:MultipleCursorsAddVisualArea` (which puts a cursor at **column 1 of every
  selected line** in linewise mode) and then feed `I`/`A` _with remapping_ so the plugin's whitelist
  handler enters insert at first non-blank / line end for every cursor, typing live. Single-line
  selections fall back to a plain `<Esc>I`/`<Esc>A` (AddVisualArea is a no-op on one line).
- `<C-LeftMouse>`, `<C-RightMouse>`, and plain `<RightMouse>` (n, i) all toggle a cursor at the click
  (`:MultipleCursorsMouseAddDelete`). Three bindings because macOS trackpads synthesize a right-click
  from Ctrl+click and some terminals (Warp) strip the Ctrl modifier from mouse reports, so the same
  physical gesture can arrive as any of the three; `mousemodel = "extend"` in `options.lua` keeps
  Neovim's popup menu from swallowing it (see `config.md`'s mouse/terminal caveat).
- **Reset**: `<Esc>` in normal mode is the plugin's built-in exit (clears all virtual cursors). Plain
  `<LeftMouse>` reset is hand-rolled: `pre_hook` (fires when the first cursor is added) sets
  buffer-local `<LeftMouse>` maps — normal mode calls `require("multiple-cursors").deinit(true)` then
  re-feeds the click noremap (Neovim retains the mouse event's coordinates); insert/visual mode feeds
  `<Esc>` _with remapping_ first so the plugin finalizes the mode at every cursor, then the click hits
  the normal-mode map. `post_hook` deletes the maps on exit — they have zero footprint otherwise.
- Deliberately `keys`-lazy (no drag/release event triples to lose, unlike the old plugin): all entry
  points — the maps above — live in the `keys` spec, and `setup()` creates the user commands on first
  use.
- Test coverage: `tests/integration/multicursor_spec.lua` force-loads the plugin, asserts every map's
  `desc` and the user commands, and functionally runs `:MultipleCursorsAddDown`, checks
  `virtual_cursors.get_num_virtual_cursors()` and the presence of the buffer-local click-reset maps,
  then `deinit(true)` and checks both are gone. Real-time insert mirroring is autocmd-driven and
  **cannot be asserted headlessly** (synthetic `feedkeys` ordering differs from real UI input — see
  `dev-workflow.md`); verify it interactively.

## `lua/plugins/picker.lua` — `folke/snacks.nvim` (picker module only)

Fuzzy file finder and project grep, scoped to the current project.

- `<leader><leader>` (mapleader pressed twice) runs `Snacks.picker.files({ hidden = true })`, an
  fzf-style fuzzy finder: type to filter, `<Up>`/`<Down>` (or `<C-j>`/`<C-k>`) to move the selection,
  `<Enter>` to open the selected file in the current buffer. These are snacks.nvim's picker defaults —
  no custom keymaps or confirm actions were added. `hidden = true` surfaces dotfiles and
  dot-directories (`.claude/`, `.busted`, …); `ignored` is left at its default (`false`) so `.gitignore`
  (repo + global + `.git/info/exclude`) is still honoured, and `.git/` is always excluded by snacks'
  own base args (`fd -E .git` / `rg -g '!.git'`).
- `<leader>.` runs a full-project text search. If `rg` is on PATH, it calls
  `Snacks.picker.grep({ cwd = ..., hidden = true })` — snacks' own live-grep-as-you-type picker, using
  the same default `<Up>`/`<Down>`/`<Enter>`/`q` keymaps as `files` and the same hidden/gitignore
  behaviour as above (dotfiles searched, `.gitignore` honoured, `.git`/`.bare` excluded). If `rg` is
  missing, it `vim.notify`s a
  warning and falls back to a native-Lua search: prompt for a term via `vim.ui.input`, walk the project
  once with `vim.fs.dir`, match lines with `lib/search_utils.lua`, and open the same picker UI
  (`Snacks.picker.pick({ items = ... })`) with the static results.
- **Project scoping**: `cwd` comes from `config.project.root()` — a directory argument given to `nvim`
  first, then `vim.fs.root(0, { ".git" })` (walking up from the current buffer to the enclosing Git repo
  root), then Neovim's cwd. `<leader>S` (search & replace, below) is its only other caller; see
  "Project Root Resolution" in [`config.md`](config.md) for the precedence rationale and for why `git.lua` and `commands.lua`
  deliberately resolve their own roots instead.
- No external binary is required for `files` — it opportunistically shells out to `fd`/`ripgrep` if
  present for faster scanning, otherwise falls back to a pure-Lua directory walker. `grep` has no such
  built-in fallback in snacks itself (`rg` is hardcoded in its source, confirmed by reading
  `snacks.nvim/lua/snacks/picker/source/grep.lua`) — the native-Lua fallback described above is
  hand-rolled in this repo, not provided by snacks.

**Custom picker items without a custom finder**
`Snacks.picker.pick()` accepts a plain `items` table directly (`{ items = {...} }`) — no async
`finder` function is required for a static result set; this is what the `<leader>.` fallback relies
on. Each item needs: `file` (path, joined with `cwd`), `cwd`, `pos = { line_1based, col_0based }` (used
for the jump target and preview), `line` (raw text, rendered in the list), and `text` (used by the
picker's own fuzzy re-filter over what's typed). `format = "file"` renders it the same as
`files`/`grep`.

**`vim.fs.dir`'s `skip` polarity is inverted from the naive expectation**
The `skip(dir_name)` callback passed to `vim.fs.dir(path, { skip = ... })` must return `false` to _stop_
recursing into that directory — any other return value (including `true`) continues the walk
(confirmed in the Neovim runtime source, `vim/fs.lua`'s `opts.skip(f) ~= false` check). Easy to get
backwards when writing an ignore-list predicate, e.g.
`skip = function(name) return not SKIP_DIRS[vim.fs.basename(name)] end`.

## `lua/plugins/search_replace.lua` — `MagicDuck/grug-far.nvim`

Project-wide search & replace as a modal float, opened with `<leader>S` (normal, or visual to prefill the search with
the selection). The spec is thin; the behaviour lives in `lua/config/search_replace.lua`, with the pure float sizing and
`config.yml` resolution in `lib/search_replace_utils.lua`.

- **The preview diff is grug-far's own.** Its ripgrep engine defaults to `showReplaceDiff = true`, rendering every match
  as a removed line and an added line (`GrugFarResultsMatchRemoved` → `DiffDelete`, `GrugFarResultsMatchAdded` →
  `DiffAdd`, from `lua/grug-far/highlights.lua`). Nothing is written until `\r` (`<localleader>r`, Replace). Recolour
  through `theme.yml`'s `groups`, not in Lua.
- **grug-far has no float mode; the float is borrowed.** `windowCreationCommand` is a string, and `_createWindow` in
  `lua/grug-far.lua` records `context.prevWin` _before_ passing it to `vim.cmd`. Pointing it at
  `lua require('config.search_replace').open_float()` yields a float while goto/open actions still target the window
  underneath (`openTargetWindow.preferredLocation = "prev"`). grug-far's close action also only closes the window when
  `initialWin ~= prevWin`, which a float always satisfies.
- **`style = "minimal"` on that float is load-bearing.** A float inherits the window options of the window it opens
  from, and `config/folding.lua` sets `statuscolumn` per window in markdown and LSP buffers. grug-far then sets the
  options it needs (`foldcolumn`, `wrap`, …) itself in `_setupWindow`.
- **One named instance that is hidden, never destroyed, by our keys.** `q`/`<Esc>` (Normal mode) and `<CR>` (jump to
  the result) all call `instance:hide()`, keeping the buffer (inputs and results) alive so an accidental close loses
  no typing; the next `<leader>S` re-shows it, replacing the search when there is a visual selection. Only `\c`
  (our map to `instance:close()`, deliberately unadvertised) or quitting Neovim destroys it. That is why the buffer
  is **not** `transient` (which sets `bufhidden=wipe`) but unlisted by hand, to stay out of the bufferline.
- **Re-showing re-searches.** Files may have changed while the float was hidden, and `<C-y>` writes a result line back
  to its file _as shown_ — a stale line would overwrite those edits. So `reopen()` calls `instance:search()` unless a
  search is already running or a visual selection is about to change the inputs (which searches anyway).
- **The `KEYMAPS` table is both the keys and the help line.** The line atop the modal and the `g?` window list
  grug-far's actions in its fixed order (`farBuffer.lua`'s action list), each labelled with its Normal-mode lhs from
  the `keymaps` option (`utils.getActionMapping`); an action whose lhs is `false` is left out. So a key mapped only
  by us never shows there, and every grug-far default we don't want has to be unbound explicitly — leaving the
  `<localleader>` defaults in place is what crowded the line with `Sync All \s`, `Sync Line \l`, …. The lean set
  kept: Help `g?`, Replace `<C-s>`, History Open `<C-t>`, Goto `<CR>`, Apply Next `<C-y>`, Close `q`, Swap Engine
  `<C-e>`, Preview `<C-p>`, Next/Prev Input `<Tab>`/`<S-Tab>`. A string lhs binds Normal and Insert mode (grug-far's
  defaults are Normal-only), which is where typing happens; Close stays Normal-only so `q` can still be typed. The
  `KEYMAPS` comment lists what is unbound and why.
- **Where we map the same lhs, ours wins and the label stays.** `setup_buffer` runs after `open()` returns, by which
  point grug-far's synchronous `setupBuffer` has mapped its own keys, so our buffer-local `<C-s>`, `<C-y>`, `<CR>`, and
  `q` replace grug-far's. That is how Close reads `q` while `q` only hides. `<C-s>`/`<C-y>` `stopinsert` first.
  `<C-y>` is `apply_next_change({ open_location = false })`: opening the location would load the file into the
  editor window hidden behind the float. grug-far's applyChange silently does nothing off a match, so from an input
  `<C-y>` first jumps to the first match; telling the two apart needs `render.resultsList` and the instance's private
  `_context`, as no public API answers "is the cursor on a match".
- **Every modal override is per-instance.** The float, `preferredLocation`, and the keys are passed to this instance's
  `open()`, not `setup()`, so a plain `:GrugFar` still opens grug-far's default vertical split and never leaves an
  unnamed hidden instance behind.
- **Scope matches `<leader>.`**: the Paths input is prefilled with `config.project.root()` when it differs from the cwd
  (spaces backslash-escaped — the input splits on whitespace), and the global `engines.ripgrep.extraArgs` is
  `--hidden --glob=!.git/`, the picker's `hidden = true` policy. `--hidden` alone would descend into `.git/`.
- **ripgrep is required, not bundled.** mason's registry has no `ripgrep` package, so `<leader>S` reports a missing
  `rg` with an error instead of opening a broken window (unlike `<leader>.`, there is no native fallback).
- **ast-grep comes from mason** (`mason-tool-installer` in `plugins/lsp.lua`, `MasonInstall ast-grep` in
  `scripts/install.sh`) and backs the `astgrep`/`astgrep-rules` engines (`\e` cycles them). The engine `path` is the
  absolute `stdpath("data") .. "/mason/bin/ast-grep"`: mason's bin dir only joins `PATH` once `nvim-lspconfig` loads on
  `BufReadPre`, so a session that has not read a file yet would not find it.
- **Async in specs**: grug-far fills its inputs two `vim.schedule` hops after `open()` returns, and searches after
  that. `tests/integration/search_replace_spec.lua` latches on `instance:when_ready()` and turns `showmode` off
  because grug-far's `startinsert!` would print `-- INSERT --` into the suite's stdout. Three traps it hit:
  - A "success" status can belong to an **earlier** search (searches are debounced 500 ms), and results **stream in**
    while rg still runs. Latch on the rendered preview line _and_ `status ~= "progress"` before applying anything —
    grug-far refuses an apply/Replace while a search or sync is in progress ("search in progress").
  - Zero matches is `status = "error"` with a `no matches` results line, not a "success" with zero stats.
  - **A spec's Replace runs wherever Paths/cwd point.** `update_input_values(values, true)` clears the inputs not
    given — Paths included — which widened one run's Replace to the whole cwd, the config repository itself. The
    modal specs therefore `:tcd` into their temp project and pass `clearOld = false`; keep both.
  - The help line is cut to the window width, so a help-line assertion needs a wide float. The modal specs override
    `config.search_replace.settings()` to full width; setting `vim.o.columns` instead **segfaults** a UI-less
    Neovim (`--headless`/`-l`).
