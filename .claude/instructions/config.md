# Config Layer (`lua/config/`)

Covers `lazy.lua`, `options.lua`, `autocmds.lua`, `keymaps.lua`, `commands.lua`, `project.lua` — the non-plugin core of
this config.

## Plugin Manager

**lazy.nvim** is bootstrapped in `lua/config/lazy.lua`. Leader keys are set in `lua/config/options.lua`.
The first module loaded from `init.lua` — so both the core `<leader>` maps in `keymaps.lua`
and all plugin `keys` specs inherit the correct leaders.

### Neovim plugin globals vs `require`

Several plugins (e.g. `folke/snacks.nvim`) export a convenience global alongside their module (e.g. `_G.Snacks`). This
repo's `selene.toml` sets `std = "lua51+vim"`, which recognizes only the `vim` global (declared in the vendored
`vim.yml` std file) — not plugin-injected globals like `Snacks`.

Prefer `require("plugin_name")` over the bare global in
keymaps/config — it produces identical behavior and keeps `selene lua/` green without editing `vim.yml`. Only add a
plugin's global to `vim.yml` if there's a specific reason to match upstream examples verbatim.

## Editor Options (`lua/config/options.lua`)

Sets `mapleader` (`<Space>`) and `maplocalleader` (`\`) — they must precede both `keymaps.lua` and the lazy.nvim setup,
and `options.lua` is loaded first — plus core editor options applied before lazy.nvim loads:

<!-- markdownlint-disable MD013 -->

| Option        | Value      | Effect                                                                                                                                                                              |
| ------------- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `wrap`        | `true`     | Soft-wrap long lines                                                                                                                                                                |
| `linebreak`   | `true`     | Break at word boundaries, not mid-word                                                                                                                                              |
| `textwidth`   | `120`      | Hard-wrap column for formatting operators                                                                                                                                           |
| `colorcolumn` | `"120"`    | Visual ruler at column 120                                                                                                                                                          |
| `mouse`       | `"nvi"`    | Mouse in normal/visual/insert — pins the Neovim default because Ctrl+Click multi-cursor (`plugins/multicursor.lua`) depends on it                                                   |
| `mousemodel`  | `"extend"` | No right-click popup menu — macOS synthesizes right-clicks from Ctrl+click (trackpad), and the default `popup_setpos` menu would swallow them before the multi-cursor mappings fire |

<!-- markdownlint-enable MD013 -->

### Statuscolumn Ownership

`vim.opt.number` is set here, but **the number column does not render on its own in most buffers** — it's
overridden by `config/folding.lua`'s custom `statuscolumn`, installed via `M.enable()` on every markdown buffer and
every LSP buffer whose server advertises `foldingRangeProvider`. That statuscolumn is a full replacement, not an
addition: Neovim never composes its own gutter with a custom one, so anything the built-in gutter would normally
draw (line numbers, relative numbers, sign column, `foldcolumn`) has to be hand-built inside
`M.statuscolumn()`/`number_column()` or it silently disappears — this is exactly what shipped once (`number` was
turned on but only the fold ▼/▶ glyphs showed).

`number_column()` reproduces the built-in number column by composing `"%l"` (or `"%r"` for relative numbers) padded
to `vim.wo.numberwidth - 1` so it right-aligns the way Neovim's own does — a bare `"%l "` with no width reservation
drifts out of alignment once line counts pass a digit boundary (`9` → `10`). If you add another gutter concern
(sign column, diagnostics), extend this same function rather than composing a second parallel one.

### Fold-source Ownership

`M.enable()` refuses to switch a buffer that already has `vim.b.fold_engine == "markdown"` over to
`engine = "lsp"`. Markdown's fold source is `lib/markdown_fold.lua`, and the ▼/▶ indicator reads its authoritative
`">N"` markers (see `is_fold_start`), which LSP folding ranges do not produce — so a language server attaching to a
markdown buffer would silently degrade both folds and indicator. This is not hypothetical: obsidian.nvim runs an
in-process LSP (`obsidian-ls`) advertising `foldingRangeProvider`, so `plugins/lsp.lua`'s `LspAttach` handler really
does reach `enable()` with `engine = "lsp"` for every vault note. Upstream obsidian says the same thing — "pick one
folding source and set it for markdown buffers".

Keep this as one invariant inside `folding.lua` rather than a filetype check at each call site; it then also covers
any future markdown server (marksman, harper_ls). `tests/integration/folding_spec.lua` asserts it at the seam and
`obsidian_spec.lua` asserts it end-to-end in a vault note.

**Testing it:** `v:lnum` can be set directly with `vim.api.nvim_set_vvar("lnum", n)` from a spec, but `v:virtnum`
is read-only and cannot — leave it unset (defaults to `0`, i.e. "not a wrapped screen row") rather than trying to
set it. `vim.wo.number` is a window-local option a test can flip, but the window is shared across specs in the same
file, so an `after_each` must restore it (`vim.wo.number = true`, matching this file's default) — a test that
throws before an inline restore line runs will otherwise leak `false` into every later spec in the process.

## Autocommands (`lua/config/autocmds.lua`)

Three augroups, all created with `{ clear = true }` so reloads stay idempotent:

**`startup_dir`** — on `VimEnter` (`once = true`), makes a directory argument (`nvim <directory>`) Neovim's working
directory via `nvim_set_current_dir`. Neovim opens the directory in a buffer but leaves the cwd wherever the shell was,
so everything cwd-driven — netrw, `:e` completion, neo-tree, obsidian.nvim's workspace lookup, the cwd the `lazygit` job
inherits — pointed at the launch directory instead. Details and constraints in "Project Root Resolution" below.

**`auto_create_dir`** — on `BufWritePre`, creates the target file's missing parent directories so `:e
/new/nested/path/file` + `:w` succeeds without a manual `mkdir`. Skips URI-scheme buffer names (`oil://`, `term://`, …)
via `lib/path_utils.has_uri_scheme`.

**`auto_save`** — writes the buffer automatically when `InsertLeave` event takes place.

Which buffers are eligible is decided by `lib/save_utils.should_autosave` — a pure-Lua predicate (Busted-tested in
`tests/save_utils_spec.lua`) that skips unmodified, non-modifiable, readonly, special-`buftype`, unnamed, and URI-scheme
buffers.

Mechanics worth knowing before editing:

- Saves run `silent update` inside `nvim_buf_call` — `:update` is the write-if-modified idiom (same as `BufWriteClose`),
  `nvim_buf_call` targets the changed buffer even if focus moved, and `silent` (not `silent!`) hides the "written" message
  while keeping real errors, which are surfaced via `pcall` + `vim.notify(..., WARN)`.
- **The `InsertLeave` autocmd is `nested = true`, and must stay that way**: autocmds don't nest by default, so without
  the flag the `:update` inside the callback fires no `BufWritePre`/`BufWritePost` — conform's format-on-save and
  `auto_create_dir` are then silently skipped (this bug shipped once; the old debounced save masked it because `defer_fn`
  timers run outside autocmd context). For the same reason, never wrap the save in `noautocmd`.

The save path is integration-tested in `tests/integration/autosave_spec.lua` by firing events with
`nvim_exec_autocmds(..., { group = "auto_save" })` — it also asserts no `TextChanged`/`TextChangedI` autocmds exist in
the group. Extend those specs when changing the behavior.

## Core Keymaps (`lua/config/keymaps.lua`)

Global, non-plugin keymaps loaded from `init.lua` before lazy.nvim. Holds the line-move bindings, which move the current
line (or a visual selection) up/down using the `:m[ove]` command with `==` to reindent, and the daily-note map:

| Key          | Mode | Action                                                              |
| ------------ | ---- | ------------------------------------------------------------------- |
| `<M-Up>`     | n    | Move current line up                                                |
| `<M-Down>`   | n    | Move current line down                                              |
| `<M-Up>`     | i    | Move current line up (returns to insert via `gi`)                   |
| `<M-Down>`   | i    | Move current line down (returns to insert via `gi`)                 |
| `<M-Up>`     | x    | Move selection up (stays selected via `gv=gv`)                      |
| `<M-Down>`   | x    | Move selection down (stays selected via `gv=gv`)                    |
| `<leader>nd` | n    | Open today's vault note (`:Obsidian today`; mnemonic "new → daily") |
| `<leader>cd` | n    | Show line diagnostics in a wrapping float                           |
| `gt{motion}` | n    | Title-case the motion (AMA rules)                                   |
| `t`          | x    | Title-case the selection (AMA rules)                                |

**Title casing:** the AMA rules live in `lib/title_case.lua` — pure Lua, unit-tested in
`tests/unit/title_case_spec.lua`, and the place to change what gets capitalized (its `MINOR_WORDS` table is the
articles/conjunctions/short-prepositions set). `config/title_case.lua` is buffer plumbing only: it turns a motion or a
selection into a range and writes the result back. Three things there are easy to break:

- `gt` is an `<expr>` map returning `"g@"`, which is what hands the motion back to Vim and buys dot-repeat and counts.
  Setting `'operatorfunc'` to `v:lua.require'config.title_case'.opfunc` keeps the callback off `_G`, which selene wants.
- The visual map presses `<Esc>` before calling: the `<`/`>` marks and `visualmode()` only describe the selection once
  visual mode has ended.
- Mark columns are **inclusive** byte offsets, but `nvim_buf_get_text` wants an exclusive end. `exclusive_end()` walks
  to the end of the final codepoint via `vim.str_utf_end` and clamps to the line length — without the walk a multibyte
  character (`β`) is sliced mid-sequence, and without the clamp the huge sentinel column that linewise and `$`-extended
  ranges report overruns the line.

`gt` deliberately shadows the built-in "go to next tab page": buffers are the tabs in this config and nothing here binds
tab pages, so `gT` and `:tabnext` are left as the way to reach them. Because `gt` is an operator, it waits for a motion
rather than pausing for `timeoutlen`, so the prefix caveat below does not apply to it.

**Terminal compatibility:** `<M-…>` is the Alt/Option key. On macOS the Option key does not send a Meta modifier by
default — the terminal must be configured to (Kitty/Ghostty/WezTerm via the Kitty keyboard protocol, or
iTerm2/Terminal.app with "Use Option as Meta key"). Where it is not, the mappings are silently inert. Verify
registration with `:verbose imap <M-Up>`.

## Command-line Overrides (`lua/config/commands.lua`)

Bufferline tabs are treated like tabs, so `:q` / `:x` / `:wq` close the **current buffer** rather than the window or
Neovim. `:qa` / `:xa` are unchanged and remain the way to actually quit.

| Command              | Result                                                            |
| -------------------- | ----------------------------------------------------------------- |
| `:q`                 | Close (delete) current buffer — prompts Yes/No/Cancel if modified |
| `:q!`                | Force-close current buffer, discarding changes                    |
| `:x`, `:wq`          | Write current buffer (if modified), then close it                 |
| `:x!`, `:wq!`        | Force-write current buffer, then close it                         |
| `:qa`, `:xa`, `:qa!` | **Unchanged** — quit Neovim (all buffers)                         |

**Mechanism.** `:q`/`:x`/`:wq` are built-in lowercase Ex commands and cannot be redefined directly, so `commands.lua`
defines two `-bang` user commands — `BufClose` and `BufWriteClose` — and rewrites the bare commands to them via `<expr>`
command-line abbreviations (`cnoreabbrev`).

The `-bang` command is essential to the force variants: when the
abbreviation fires as the `!` is typed, the trailing `!` lands on the command as its bang instead of corrupting the
expansion (`q!` is not itself an abbreviatable sequence, so this is the clean way to support it). This is the same
documented-patch spirit as the markdown italic and neo-tree confirm patches.

The abbreviation guard `getcmdtype() ==# ':' && getcmdline() ==# '<word>'` fires only when the whole command line is
exactly that bare word, so anything longer (`:qa`, `:xa`, `:wqa`, ranges) falls through to Vim's default. `:wq` gets its
own abbreviation and does not collide with `q` (the `q` full-id abbreviation requires the preceding char to be
non-keyword, and in `wq` it is the keyword char `w`).

Both commands delegate the actual delete to snacks.nvim's `bufdelete` module
(`require("snacks.bufdelete").delete{...}`), which swaps an alternate/new buffer into every window showing the target
**before** deleting it — so the window layout survives and Neovim never quits. snacks is `keys`-lazy-loaded, but
lazy.nvim auto-loads it on the first `require` of a submodule, so the deferred `require` inside the callbacks is enough;
nothing is eager-loaded. On a modified buffer, snacks prompts Yes (save+close) / No (discard+close) / Cancel (abort).
`BufWriteClose` writes first (`:update`, or `:write!` with a bang) so the buffer is already unmodified and the prompt is
skipped.

## Project Root Resolution (`lua/config/project.lua`)

The directory a project-scoped tool should work in. `config.project.root()` is a lazy `or` chain over three signals, in
descending priority:

1. **The directory argument** — `nvim <directory>`, via `M.startup_dir()`.
2. **The Git root of the current buffer** — `vim.fs.root(0, { ".git" })`, the historical sole behaviour.
3. **Neovim's cwd** — `vim.uv.cwd()`, the last resort.

Consumers: the two `lua/plugins/picker.lua` keymaps (`<leader><leader>`, `<leader>.`). Two neighbours deliberately do not
use it: `lua/config/commands.lua`'s Harper dictionary lookup needs the LSP client's `root_dir` and a
`.harper-dictionary.txt` marker, and `lua/plugins/git.lua`'s `<leader>gg` lets `:LazyGitCurrentFile` resolve its own repo
from the buffer, then the cwd — which the `startup_dir` chdir has already aimed at the directory argument. Both are
correct without this module; resist routing them through it.

**The directory argument outranks the Git root on purpose.** Naming a directory states which tree to work in, so
`nvim ~/monorepo/packages/api` searches the package rather than the whole monorepo. The cwd cannot stand in for this
tier: launched bare inside that same package, cwd is also the package, but there the enclosing-repo answer is the one to
keep — only the argument distinguishes "named deliberately" from "inherited from the shell". The consequence to know
about: a directory argument pins the root for the session, so after `nvim <directory>`, opening a file from an unrelated
repo with `:e` leaves the picker scoped to that directory.

Mechanics worth knowing before editing:

- **`M.startup_dir()` is memoised to pin the scope, not to survive the chdir.** Neovim re-expands arglist entries against
  the new cwd, so `fnamemodify(argv(0), ":p")` gives the same answer before and after `startup_dir` chdirs (verified,
  including after a later manual `:cd`). What the memo buys is stability: `:args`/`:argadd` rewrite the arglist, and the
  project should not move out from under the picker when they do. Only `argv(0)` is read — the first argument is the one
  Neovim opens first, so `nvim ~/dir1 ~/dir2` scopes to `~/dir1`.
- **`M.detect()` does not call `vim.fn.resolve`.** A symlinked directory keeps the name that was typed. `:cd` is resolved
  by the OS regardless, so after the chdir `getcwd()` reports the physical path while `root()` reports the symlinked one
  — that asymmetry is deliberate. Anything comparing the two must resolve both sides (obsidian.nvim's `Workspace.find`
  already does).
- A file argument, a path that does not exist yet, and no argument at all each leave `startup_dir()` `nil` and fall
  through to the Git root — `nvim README.md` behaves exactly as it did before this module existed.
- **Testing it:** `scripts/busted-nvim.sh` runs `nvim -l` with no positional arguments, so `argv(0)` is `""` and the memo
  fixes `startup_dir()` at `nil` for the process. `tests/integration/project_spec.lua` still reaches the real capture
  with `:argadd` (it writes the same arglist `argv(0)` reads) and covers the precedence by overriding
  `M.startup_dir`/`M.root` on the module table. Because `VimEnter` fires even under `nvim -l`, the `once` chdir autocmd
  has already removed itself by the time specs run — an empty `nvim_get_autocmds` list for the group is the evidence it
  ran.

## Daily Notes

Daily notes come from obsidian.nvim (`:Obsidian today`), which writes into
the vault; `<leader>nd` in `keymaps.lua` is a plain `<cmd>Obsidian today<cr>` string rhs, resolved at press time,
so `keymaps.lua` loading before lazy.nvim is fine. Placement is `config.yml`'s `config.obsidian.dailyNotes` —
see [`obsidian.md`](obsidian.md).

## Global Keymap Registry

Every **global** (non-buffer-local) keymap in this config, in one place — plus the LSP set (rows marked
"LSP"): those maps are buffer-local via `LspAttach`, but they occupy their keys in effectively every code
buffer, so they belong in this index rather than an exception paragraph.

Check the table below before choosing a key for a new mapping, and add a row when you create one — keymaps are
otherwise scattered across `keys` tables in a dozen plugin specs, and finding a free key requires a grep sweep.

Filetype- and buffer-specific maps (markdown `<C-*>` keys, the neo-tree tree buffer) are documented in their
own files (`markdown.md`, `explorer.md`), not here; the design details behind the LSP rows live in `lsp.md`.

<!-- markdownlint-disable MD013 -->

| Key                               | Mode                             | Action                                                                                                                                                               | Source                    |
| --------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| `<M-Up>` / `<M-Down>`             | n, i, v                          | Move line / selection up/down                                                                                                                                        | `config/keymaps.lua`      |
| `<S-h>` / `<S-l>`                 | n                                | Prev / next buffer tab                                                                                                                                               | `plugins/ui.lua`          |
| `[b` / `]b`                       | n                                | Prev / next buffer tab                                                                                                                                               | `plugins/ui.lua`          |
| `[B` / `]B`                       | n                                | Move buffer tab left / right                                                                                                                                         | `plugins/ui.lua`          |
| `<leader>bn` / `<leader>bp`       | n                                | Next / prev buffer tab (duplicates `]b`/`[b`)                                                                                                                        | `plugins/ui.lua`          |
| `<leader>bP`                      | n                                | Delete non-pinned buffers                                                                                                                                            | `plugins/ui.lua`          |
| `<leader>br` / `<leader>bl`       | n                                | Delete buffers to the right / left                                                                                                                                   | `plugins/ui.lua`          |
| `<leader>bj`                      | n                                | Pick buffer                                                                                                                                                          | `plugins/ui.lua`          |
| `<leader>nd`                      | n                                | Open today's vault note (`:Obsidian today`)                                                                                                                          | `config/keymaps.lua`      |
| `<CR>`                            | n _(vault notes)_                | Obsidian smart action: follow link / toggle checkbox / cycle heading fold — buffer-local, plugin default. Insert-mode `<CR>` stays markdown-plus's list continuation | `plugins/obsidian.lua`    |
| `]o` / `[o`                       | n _(vault notes)_                | Next / previous link — buffer-local, plugin default                                                                                                                  | `plugins/obsidian.lua`    |
| `<leader>o`                       | n                                | Obsidian command menu — bare `:Obsidian`, a context-filtered subcommand picker. Bare single-key map: keep `<leader>o` free of chords or it gains a timeoutlen pause  | `plugins/obsidian.lua`    |
| `<leader>cd`                      | n                                | Show line diagnostics (full text) in a wrapping float (`vim.diagnostic.open_float`)                                                                                  | `config/keymaps.lua`      |
| `<leader>gg`                      | n                                | Lazygit (current file's repo)                                                                                                                                        | `plugins/git.lua`         |
| `<F2>`                            | n, i                             | Rename symbol (LSP) — markdown's buffer-local image-rename map shadows it there                                                                                      | `plugins/lsp.lua`         |
| `<F12>`                           | n, i                             | Go to definition (LSP)                                                                                                                                               | `plugins/lsp.lua`         |
| `<S-F12>` / `<F24>`               | n, i                             | List references (LSP; `<F24>` catches terminals that report Shift+F12 as F24)                                                                                        | `plugins/lsp.lua`         |
| `<leader>cr`                      | n                                | Rename symbol (LSP)                                                                                                                                                  | `plugins/lsp.lua`         |
| `<leader>gd` / `<leader>gr`       | n                                | Go to definition / list references (LSP)                                                                                                                             | `plugins/lsp.lua`         |
| `<leader>r`                       | n, x                             | Refactor menu (LSP)                                                                                                                                                  | `plugins/lsp.lua`         |
| `<leader>ca`                      | n                                | Quick-fix menu (LSP code actions; snaps the request to the nearest Harper flag on the line, which is what reaches Harper's add-to-dictionary actions)                 | `plugins/lsp.lua`         |
| `<leader><leader>`                | n                                | Fuzzy file picker (project)                                                                                                                                          | `plugins/picker.lua`      |
| `<leader>.`                       | n                                | Project grep                                                                                                                                                         | `plugins/picker.lua`      |
| `<leader>e`                       | n                                | Toggle file tree sidebar                                                                                                                                             | `plugins/explorer.lua`    |
| `<C-z>`                           | n                                | Toggle Zen Mode                                                                                                                                                      | `plugins/zen.lua`         |
| `<Tab>`                           | n _(folding buffers)_            | Toggle the fold under the cursor — buffer-local in markdown & LSP-foldable buffers; also binds `<C-i>` (same keycode)                                                | `config/folding.lua`      |
| `<M-S-Up>` / `<M-S-Down>`         | n, x, i                          | Duplicate cursor to line above/below, same column                                                                                                                    | `plugins/multicursor.lua` |
| `I` / `A`                         | x                                | Multi-cursor insert at start / append at end of selected lines                                                                                                       | `plugins/multicursor.lua` |
| `<C-LeftMouse>`                   | n, i                             | Add/remove cursor at mouse click (replaces built-in mouse jump-to-tag)                                                                                               | `plugins/multicursor.lua` |
| `<C-RightMouse>` / `<RightMouse>` | n, i                             | Same as `<C-LeftMouse>` — catches macOS's Ctrl+click→right-click synthesis, including terminals that strip the Ctrl modifier from mouse reports (Warp)               | `plugins/multicursor.lua` |
| `<Esc>`                           | n _(while cursors active)_       | Reset to a single cursor — plugin whitelist map, exists only in multi-cursor mode                                                                                    | `plugins/multicursor.lua` |
| `<LeftMouse>`                     | n, i, x _(while cursors active)_ | Reset cursors, then perform the normal click — buffer-local via `pre_hook`/`post_hook`                                                                               | `plugins/multicursor.lua` |
| `ys{motion}{char}` / `yss`        | n                                | Add surround around motion (`yss` = whole line); nvim-surround defaults                                                                                              | `plugins/surround.lua`    |
| `ds{char}` / `cs{old}{new}`       | n                                | Delete / change the surrounding pair                                                                                                                                 | `plugins/surround.lua`    |
| `S{char}`                         | x                                | Surround the visual selection                                                                                                                                        | `plugins/surround.lua`    |
| `<C-g>s` / `<C-g>S`               | i                                | Insert-mode surround (and its line-wise variant)                                                                                                                     | `plugins/surround.lua`    |
| `gt{motion}`                      | n                                | Title-case the motion under the AMA rules — an `<expr>`/`g@` operator, so it dot-repeats. Shadows the built-in next-tab page; `gT` still works                       | `config/keymaps.lua`      |
| `t`                               | x                                | Title-case the selection under the AMA rules. Shadows the built-in visual `t{char}` "till" motion                                                                    | `config/keymaps.lua`      |

<!-- markdownlint-enable MD013 -->

**Mouse/terminal caveat:** on macOS trackpads, Ctrl+click is synthesized into a right-click before Neovim sees it, and
some terminals additionally strip the Ctrl modifier from their mouse reports — Warp does (verified July 2026; Warp only
forwards right-clicks to TUI apps at all since Nov 2024, warpdotdev/Warp#2085). So "Ctrl+click" can reach Neovim as
`<C-LeftMouse>`, `<C-RightMouse>`, or a bare `<RightMouse>`, and the multi-cursor toggle is bound to all three.
Consequence: a plain right-click (two-finger tap) also toggles a cursor — acceptable because `mousemodel = "extend"`
already removed the right-click popup menu, leaving right-click otherwise jobless. The `<M-S-…>` maps need
Option-as-Meta, same as `<M-Up>`/`<M-Down>` above.

**Prefix caveat:** `<leader>b` (`bn`/`bp`/`bP`/`br`/`bl`/`bj`) and `<leader>n` (`nd`) are chord prefixes. Mapping bare
`<leader>b` or `<leader>n` would work but every press would pause for `timeoutlen` (~1s) while Neovim disambiguates —
avoid single-key mappings that prefix an existing chord family. (This is why the old bare `<leader>n`/`<leader>p`
buffer-cycle maps moved to `<leader>bn`/`<leader>bp` when `<leader>nd` was added, and why lazygit moved from
bare `<leader>g` to `<leader>gg` when the buffer-local LSP goto chords `<leader>gd`/`<leader>gr` arrived.)
`<leader>g` and `<leader>c` are chord prefixes too (LSP `gd`/`gr`/`gg` and `cr`).

The inverse applies to the bare single-key maps, `<leader>o` (Obsidian menu) and `<leader>r` (refactor menu): they are
only pause-free because nothing extends them. **Adding any `<leader>o…`/`<leader>r…` chord would silently put a
~1s pause on every press of the bare map** — put new Obsidian shortcuts somewhere else, or move the bare map first.
`obsidian_spec.lua` asserts no `<leader>o` chord exists.
