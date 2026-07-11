# Neovim Configuration

`CLAUDE.md` is a symlink to this file — `AGENTS.md` is the single source of truth for project instructions.

## Directory Structure

```
~/.config/nvim/
├── init.lua                   # Entry point — requires config.options, autocmds, keymaps, then config.lazy
├── AGENTS.md                  # This file — project instructions (single source of truth)
├── CLAUDE.md                  # Symlink -> AGENTS.md
├── lazy-lock.json             # Plugin version lockfile (commit-pinned)
├── selene.toml                # Lua linter config (std = "lua51+vim")
├── vim.yml                    # Vendored selene std: declares the `vim` global
├── scripts/
│   ├── lazy-install.sh        # Safe plugin fetch: `:Lazy install`, not `:Lazy sync`
│   ├── lint.sh                # Runs `selene lua/` (same command CI runs)
│   └── test-without-binary.sh # Run a command with one binary hidden from PATH (test executable-guard fallbacks)
└── lua/
    ├── config/
    │   ├── autocmds.lua       # Editor autocommands (auto-create parent dirs on save)
    │   ├── keymaps.lua        # Core (non-plugin) keymaps (Alt+Up/Down move line)
    │   ├── lazy.lua           # lazy.nvim bootstrap + setup
    │   └── options.lua        # Core editor options (wrap, textwidth, colorcolumn)
    ├── lib/
    │   ├── markdown_utils.lua # Pure-Lua utility functions for markdown editing
    │   ├── path_utils.lua     # Pure-Lua path helpers (URI-scheme detection)
    │   └── search_utils.lua   # Pure-Lua case-insensitive substring matcher (grep fallback)
    └── plugins/
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

`init.lua` calls `require("config.options")`, then `require("config.autocmds")`, then `require("config.keymaps")`, then `require("config.lazy")`. All plugin specs live under `lua/plugins/` and are auto-imported by lazy.nvim via `spec = { { import = "plugins" } }` in `lua/config/lazy.lua`. Adding a new file to `lua/plugins/` is enough to activate new plugins.

## Plugin Manager

**lazy.nvim** is bootstrapped in `lua/config/lazy.lua`: if the repo is not found at `~/.local/share/nvim/lazy/lazy.nvim` it is cloned from GitHub, then added to `rtp`. Leader keys are set before `require("lazy").setup(...)` so all plugin keymaps inherit the correct leaders.

- `mapleader` = `<Space>`
- `maplocalleader` = `\`
- `install.colorscheme` = `habamax` (used only during `:Lazy install`)
- `checker.enabled` = true (background update checks)

### Neovim plugin globals vs `require`

Several plugins (e.g. `folke/snacks.nvim`) export a convenience global alongside their module (e.g. `_G.Snacks`). This repo's `selene.toml` sets `std = "lua51+vim"`, which recognizes only the `vim` global (declared in the vendored `vim.yml` std file) — not plugin-injected globals like `Snacks`. Prefer `require("plugin_name")` over the bare global in keymaps/config — it produces identical behavior and keeps `selene lua/` green without editing `vim.yml`. Only add a plugin's global to `vim.yml` if there's a specific reason to match upstream examples verbatim.

## Editor Options (`lua/config/options.lua`)

Sets core editor options applied before lazy.nvim loads:

| Option | Value | Effect |
|---|---|---|
| `wrap` | `true` | Soft-wrap long lines |
| `linebreak` | `true` | Break at word boundaries, not mid-word |
| `textwidth` | `120` | Hard-wrap column for formatting operators |
| `colorcolumn` | `"120"` | Visual ruler at column 120 |

## Core Keymaps (`lua/config/keymaps.lua`)

Global, non-plugin keymaps loaded from `init.lua` before lazy.nvim. Currently holds the line-move bindings, which move the current line (or a visual selection) up/down using the `:m[ove]` command with `==` to reindent:

| Key | Mode | Action |
|---|---|---|
| `<M-Up>` | n | Move current line up |
| `<M-Down>` | n | Move current line down |
| `<M-Up>` | i | Move current line up (returns to insert via `gi`) |
| `<M-Down>` | i | Move current line down (returns to insert via `gi`) |
| `<M-Up>` | x | Move selection up (stays selected via `gv=gv`) |
| `<M-Down>` | x | Move selection down (stays selected via `gv=gv`) |

**Terminal compatibility:** `<M-…>` is the Alt/Option key. On macOS the Option key does not send a Meta modifier by default — the terminal must be configured to (Kitty/Ghostty/WezTerm via the Kitty keyboard protocol, or iTerm2/Terminal.app with "Use Option as Meta key"). Where it is not, the mappings are silently inert. Verify registration with `:verbose imap <M-Up>`.

## Markdown Utilities (`lua/lib/markdown_utils.lua`)

Pure-Lua module with no Neovim API dependencies — safe to unit-test outside Neovim.

### Functions

**`find_image_path_at(line, col)`**
Scans `line` for Markdown image references `![alt](path)` and returns the path if the 1-based column `col` falls within an image span. Returns `nil` when `col` is outside any image span. Strips trailing title attributes (e.g. `"My Title"` or `'title'`).

**`is_remote_url(path)`**
Returns `true` when `path` starts with `http://` or `https://`.

**`replace_filename(path, new_name)`**
Replaces the filename component of `path` with `new_name`, preserving any directory prefix. E.g. `replace_filename("images/foo.png", "bar.png")` → `"images/bar.png"`.

**`toggle_checklist_line(line)`**
Returns a transformed copy of `line` with its checklist state cycled through three cases:
- Checklist item (`- [ ] …` or `- [x] …`) → toggle `[ ]` ↔ `[x]`
- Bare list item (`- item`) → insert `[ ] ` after the marker
- Plain line → prepend `- [ ] ` with indentation preserved

Returns the original line unchanged when it is empty.

## Markdown Plugins (`lua/plugins/markdown.lua`)

### 1. `yousefhadder/markdown-plus.nvim`

Loaded for `ft = "markdown"`. Provides the core editing operations through `<Plug>` mappings that are registered globally (not buffer-local) when the plugin enables itself for a buffer.

**Why `keymaps = { enabled = true }`**
The plugin's `keymaps.enabled` flag controls whether the default `<localleader>m*` bindings are applied. Critically, it also controls the `<CR>` → `<Plug>(MarkdownPlusListEnter)` mapping in insert mode that auto-continues list items. Setting this to `false` silently breaks list continuation. Keep it `true`; our custom Ctrl bindings sit alongside the defaults without conflict.

**Custom keymap setup**
`setup_keymaps(buf)` is called:
1. Immediately for any already-loaded markdown buffers (handles the case where `setup()` is called after the first buffer opens).
2. From a `FileType markdown` autocmd (group `MarkdownPlusKeymaps`) for every subsequent buffer.

The plugin registers its own `FileType markdown` autocmd inside `M.setup()`. Because `M.setup()` is called first inside the `config` function, the plugin's autocmd is registered before ours. When a file opens, the plugin's handler fires first (creating the `<Plug>` targets), then ours fires (mapping Ctrl keys to those targets). Order is guaranteed.

**Italic uses pattern-patching, not the `<Plug>` target**
`markdown-plus.nvim` hardcodes `italic = { wrap = "*" }` in `lua/markdown-plus/format/patterns.lua` with no config option. To honour the requirement of `_` for italic, `italic_visual()` and `italic_normal()` temporarily overwrite `patterns.patterns.italic.wrap` with `"_"`, call the plugin's toggle function synchronously, then restore the original value. This is safe because the toggle runs synchronously with no async callbacks.

**Checklist toggle delegates to `markdown_utils`**
The custom `checklist_toggle()` function in `markdown.lua` avoids `parse_list_line` entirely and delegates to `mu.toggle_checklist_line()` from `lib/markdown_utils.lua` (see Markdown Utilities section). This sidesteps a treesitter timing issue where `parse_list_line` returns a valid `list_info` with `list_info.checkbox = nil`, causing `add_checkbox_to_line` to fire on an already-checkboxed line and produce a duplicate `[ ]`.

**Image rename**
`rename_image_at_cursor()` uses `mu.find_image_path_at()` to locate the image reference under the cursor, validates the file exists, prompts for a new name via `vim.ui.input`, renames the file on disk with `os.rename`, then replaces all occurrences of the old path in the buffer.

#### `<Plug>` targets used

| `<Plug>` | Normal/Visual | Registered by |
|---|---|---|
| `MarkdownPlusBold` | n + x | format module |
| `MarkdownPlusItalic` | n + x | format module (not used — see italic section above) |
| `MarkdownPlusInsertLink` | n | links module |
| `MarkdownPlusSelectionToLink` | x | links module |
| `MarkdownPlusInsertImage` | n | images module |
| `MarkdownPlusSelectionToImage` | x | images module |
| `MarkdownPlusToggleCheckbox` | x | list module (used for visual-range toggle only) |
| `MarkdownPlusListEnter` | i | list module (bound to `<CR>` by plugin default) |

#### Buffer-local keymaps (markdown buffers only)

| Key | Mode | Action |
|---|---|---|
| `<C-b>` | n + x | Toggle bold |
| `<C-i>` | n + x | Toggle italic (`_`) |
| `<C-k>` | n + x | Insert / wrap link |
| `<C-l>` | n + i | Toggle checklist item (single line) |
| `<C-l>` | x | Toggle checklist range |
| `<C-S-I>` | n + x | Insert / wrap image |
| `<F2>` | n | Rename image file at cursor |

#### Default `<localleader>` bindings (from the plugin, always active)

These exist alongside the Ctrl bindings and do not conflict:

| Key | Action |
|---|---|
| `\mb` | Toggle bold |
| `\mi` | Toggle italic (`*`) |
| `\mS` | Toggle strikethrough |
| `\m\`` | Toggle inline code |
| `\ml` | Insert / wrap link |
| `\mL` | Insert / wrap image |
| `\mx` | Toggle checkbox |
| `\mr` | Renumber ordered lists |
| `<CR>` (insert) | Continue list item |
| `<Tab>` (insert) | Indent list item |
| `<S-Tab>` (insert) | Outdent list item |
| `<BS>` (insert) | Smart backspace (removes empty list marker) |

### 2. `MeanderingProgrammer/render-markdown.nvim`

Loaded for `ft = { "markdown" }`. Renders headings, bold, italic, code blocks, tables, and checkboxes as styled virtual text in the buffer. No external binaries required.

**Why `render_modes = true`**
The default is `{ 'n', 'c', 't' }` — insert and visual modes are excluded. Without this override, switching to insert or visual mode strips all rendering and changes the visual appearance of the buffer dramatically. `true` activates rendering in every mode. The `anti_conceal` feature (enabled by default) still reveals raw syntax on the cursor line regardless of `render_modes`.

**Code block background**
`render-markdown` sets opaque `RenderMarkdownCode` and `RenderMarkdownCodeBorder` highlights that block terminal transparency. Both are cleared to `bg = "NONE"` on startup and re-cleared on every `ColorScheme` event.

### 3. `stevearc/conform.nvim`

Loaded on `BufWritePre`. Runs `prettier` on markdown files before every save. If `prettier` is not found, conform logs a one-time warning and skips formatting silently — it does not block saving.

The formatter is set only for `markdown`. Adding formatters for other filetypes should extend `formatters_by_ft`, not replace it.

## Other Plugins

### `lua/plugins/theme.lua` — `ribru17/bamboo.nvim` (via `lcoram/laserwave.nvim`)

Loads the laserwave colorscheme with `transparent = true` so the terminal background shows through.

### `lua/plugins/ui.lua`

**`akinsho/bufferline.nvim`** — Buffer tabs at the top. Keymaps: `<S-h>`/`<S-l>` to cycle tabs, `<leader>bd` to delete buffer.

**`nvim-lualine/lualine.nvim`** — Status line showing mode, git branch, diagnostics, diff stats, and clock.

### `lua/plugins/zen.lua` — `folke/zen-mode.nvim`

Distraction-free writing mode. `<C-z>` toggles Zen Mode (global keymap). Disables line numbers, sign column, cursorline, and sets window width to 80 columns.

### `lua/plugins/git.lua` — `kdheepak/lazygit.nvim`

Opens Lazygit in a floating window ("modal") over the current buffer. Lazy-loaded via its `keys` and `cmd` triggers; depends on `nvim-lua/plenary.nvim` for path handling.

- `<leader>g` (global keymap) runs `:LazyGitCurrentFile`, scoping Lazygit to the **current file's Git repository** (falling back to the project/cwd Git root). Quit Lazygit with `q` to return to the buffer.
- A **PATH guard** checks `vim.fn.executable("lazygit")` first and emits a clean `vim.notify` error instead of a raw stack trace when the binary is missing.
- Floating-window options are set in `init` (`winblend = 0`, `scaling_factor = 0.9`) to stay consistent with the transparent laserwave theme.

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

## Adding New Plugins

Create a new file under `lua/plugins/`, e.g. `lua/plugins/lsp.lua`, and return a standard lazy.nvim spec table. It will be picked up automatically on next start.

### Fetch with `install`, not `sync`

Fetch the new plugin with:

```sh
scripts/lazy-install.sh
# or directly: nvim --headless "+Lazy! install" +qa
```

**Do not run `:Lazy sync`** to fetch a single new plugin. `sync` is `install` + `clean` + `update` — it also bumps every *already-installed* plugin to the latest commit on its tracked branch, silently expanding `lazy-lock.json` far beyond the plugin you meant to add. `install` only fetches plugins that are in the spec but missing on disk; it leaves already-installed plugins untouched.

If `sync` was already run by mistake:

```sh
git diff lazy-lock.json                              # see everything that changed
# hand-revert any entries you didn't intend to touch, then:
nvim --headless "+Lazy! restore" +qa                  # re-checkout plugin dirs to match the lockfile
```

Always `git diff lazy-lock.json` before committing a plugin addition — the diff should contain exactly one new entry (or the version bump you intended), nothing else.

### Verifying a plugin loads

`:checkhealth <plugin>` can report `No healthcheck found for "<plugin>" plugin` for a `keys`-lazy-loaded plugin that hasn't been triggered yet in the current session — a discovery quirk, not necessarily a real problem. To check directly instead:

```sh
nvim --headless -c "lua print(pcall(require, 'plugin_name'))" -c "qa"
```

or call the plugin's health module directly: `require("plugin_name.health").check()`.

## Testing

Tests live in `tests/markdown_utils_spec.lua` and `tests/search_utils_spec.lua`, and use [Busted](https://lunarmodules.github.io/busted/) with Lua 5.5.

### Install

```sh
brew install luarocks
luarocks install busted
brew install selene   # or: cargo install selene
```

Verify: `busted --version` and `selene --version`

`selene` is a standalone Rust binary with no Lua/LuaRocks dependency — unlike a Lua-based linter, it can never break due to a local Lua-version mismatch.

### Run

```sh
busted
scripts/lint.sh   # or: selene lua/
```

Reads `.busted` at the project root (`ROOT = { "tests" }`). The `package.path` preamble in the spec file makes `lib.markdown_utils` importable without Neovim. `selene lua/` is the same command CI runs (`.github/workflows/ci.yml`).

### Verifying interactive/headless picker behavior

`vim.ui.input()` (and `vim.ui.select()`) are blocking, modal calls — driving them through synthetic `vim.api.nvim_feedkeys()` in `nvim --headless` is timing-fragile (typed keys can leak into normal-mode commands instead of reaching the prompt) and is not a reliable test technique. To verify code that sits behind a `vim.ui.input` prompt, replicate/call the underlying logic directly (e.g. the same `vim.fs.dir` walk + matcher calls used by the fallback in `lua/plugins/picker.lua`) and hand the result straight to the picker function, bypassing the interactive prompt entirely.

To exercise an executable-guard fallback (e.g. `<leader>.`'s `rg`-missing path, or `<leader>g`'s `lazygit`-missing path) without uninstalling the real binary, use `scripts/test-without-binary.sh <binary> -- <command...>`. It builds a temporary `PATH` containing symlinks to everything except the named binary — safer than naively stripping the binary's whole directory from `$PATH`, since unrelated tools (including `nvim` itself) often live alongside it (e.g. both under `/opt/homebrew/bin`).

## Terminal Compatibility Note

`<C-S-I>` (Ctrl+Shift+I) requires the Kitty keyboard protocol. Supported terminals: kitty, WezTerm, Ghostty, and recent versions of foot. In terminals that do not support it the mapping is silently ignored.
