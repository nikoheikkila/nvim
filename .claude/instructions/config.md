# Config Layer (`lua/config/`)

Covers `lazy.lua`, `options.lua`, `keymaps.lua`, `commands.lua` — the non-plugin core of this config.

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

## Command-line Overrides (`lua/config/commands.lua`)

Bufferline tabs are treated like tabs, so `:q` / `:x` / `:wq` close the **current buffer** rather than the window or Neovim. `:qa` / `:xa` are unchanged and remain the way to actually quit.

| Command | Result |
|---|---|
| `:q` | Close (delete) current buffer — prompts Yes/No/Cancel if modified |
| `:q!` | Force-close current buffer, discarding changes |
| `:x`, `:wq` | Write current buffer (if modified), then close it |
| `:x!`, `:wq!` | Force-write current buffer, then close it |
| `:qa`, `:xa`, `:qa!` | **Unchanged** — quit Neovim (all buffers) |

**Mechanism.** `:q`/`:x`/`:wq` are built-in lowercase Ex commands and cannot be redefined directly, so `commands.lua` defines two `-bang` user commands — `BufClose` and `BufWriteClose` — and rewrites the bare commands to them via `<expr>` command-line abbreviations (`cnoreabbrev`). The `-bang` command is essential to the force variants: when the abbreviation fires as the `!` is typed, the trailing `!` lands on the command as its bang instead of corrupting the expansion (`q!` is not itself an abbreviatable sequence, so this is the clean way to support it). This is the same documented-patch spirit as the markdown italic and neo-tree confirm patches.

The abbreviation guard `getcmdtype() ==# ':' && getcmdline() ==# '<word>'` fires only when the whole command line is exactly that bare word, so anything longer (`:qa`, `:xa`, `:wqa`, ranges) falls through to Vim's default. `:wq` gets its own abbreviation and does not collide with `q` (the `q` full-id abbreviation requires the preceding char to be non-keyword, and in `wq` it is the keyword char `w`).

Both commands delegate the actual delete to snacks.nvim's `bufdelete` module (`require("snacks.bufdelete").delete{...}`), which swaps an alternate/new buffer into every window showing the target **before** deleting it — so the window layout survives and Neovim never quits. snacks is `keys`-lazy-loaded, but lazy.nvim auto-loads it on the first `require` of a submodule, so the deferred `require` inside the callbacks is enough; nothing is eager-loaded. On a modified buffer, snacks prompts Yes (save+close) / No (discard+close) / Cancel (abort). `BufWriteClose` writes first (`:update`, or `:write!` with a bang) so the buffer is already unmodified and the prompt is skipped.

**Tradeoffs.** `:q` no longer closes a split window — it always closes the buffer; use `:close` or `<C-w>c` for windows/splits. Closing the last buffer leaves an empty `[No Name]` buffer (Neovim stays open, by design); use `:qa` to quit.

## Global Keymap Registry

Every **global** (non-buffer-local) keymap in this config, in one place. **Check this table before choosing a key for a new mapping, and add a row when you create one** — keymaps are otherwise scattered across `keys` tables in six files and finding a free key requires a grep sweep. Buffer-local maps (markdown `<C-*>` keys, the neo-tree tree buffer) are documented in their own files (`markdown.md`, `explorer.md`), not here.

| Key | Mode | Action | Source |
|---|---|---|---|
| `<M-Up>` / `<M-Down>` | n, i, v | Move line / selection up/down | `config/keymaps.lua` |
| `<S-h>` / `<S-l>` | n | Prev / next buffer tab | `plugins/ui.lua` |
| `[b` / `]b` | n | Prev / next buffer tab | `plugins/ui.lua` |
| `[B` / `]B` | n | Move buffer tab left / right | `plugins/ui.lua` |
| `<leader>n` / `<leader>p` | n | Next / prev buffer tab (duplicates `]b`/`[b`) | `plugins/ui.lua` |
| `<leader>bp` | n | Pin buffer | `plugins/ui.lua` |
| `<leader>bP` | n | Delete non-pinned buffers | `plugins/ui.lua` |
| `<leader>br` / `<leader>bl` | n | Delete buffers to the right / left | `plugins/ui.lua` |
| `<leader>bj` | n | Pick buffer | `plugins/ui.lua` |
| `<leader>g` | n | Lazygit (current file's repo) | `plugins/git.lua` |
| `<leader><leader>` | n | Fuzzy file picker (project) | `plugins/picker.lua` |
| `<leader>.` | n | Project grep | `plugins/picker.lua` |
| `<leader>e` | n | Toggle file tree sidebar | `plugins/explorer.lua` |
| `<C-z>` | n | Toggle Zen Mode | `plugins/zen.lua` |

**Prefix caveat:** `<leader>b` is a chord prefix (`bp`/`bP`/`br`/`bl`/`bj`). Mapping bare `<leader>b` would work but every press would pause for `timeoutlen` (~1s) while Neovim disambiguates — avoid single-key mappings that prefix an existing chord family.
