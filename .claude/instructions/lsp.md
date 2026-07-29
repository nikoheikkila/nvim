# LSP — `lua/plugins/lsp.lua`

Language-server support: auto-completion (blink.cmp), live diagnostics, navigation, and refactoring for the
languages in the `servers` table. Built on Neovim's native LSP client (`vim.lsp.config()` / `vim.lsp.enable()`,
requires ≥ 0.11) with nvim-lspconfig supplying base server configs and mason auto-installing the binaries.

## Adding a language server

One entry in `lua/config/lsp_servers.lua` — the single source of truth for the server set. The integration
spec iterates the same table (so a new entry is test-covered automatically), and the mason
`ensure_installed`/`automatic_enable` lists in `plugins/lsp.lua` are derived from its keys.

```lua
return {
  ts_ls = {}, -- key = lspconfig server name, value = config overrides ({} is enough for most)
}
```

- The key is the **lspconfig server name** (`:h lspconfig-all` lists them all).
- The value is merged onto nvim-lspconfig's base config via `vim.lsp.config()` — put `settings`, `cmd`,
  `root_markers`, etc. there. See the `lua_ls` entry for a non-trivial example.
- mason-lspconfig maps the name to a mason package and installs it on the next interactive launch.
  `automatic_enable` is allowlisted to the table's keys, so servers left in the mason data dir by earlier
  setups (vtsls, pyright, ...) never attach alongside the configured ones.
- Verify with `:Mason` (install state) and `:checkhealth vim.lsp` (attach state).

Server-choice rationale (per-server gotchas live as comments in the table itself): `ts_ls` over vtsls
because it exposes tsserver's `refactor.*` code actions with less surface; `basedpyright` is the maintained
pyright fork; `yamlls` has SchemaStore support built in — no schemastore.nvim; `lua_ls` gets `vim` as a
global and `$VIMRUNTIME` in the workspace library — no lazydev.nvim. `harper_ls` is Harper's
grammar/spell checker — diagnostics/code-actions only, attaching on nvim-lspconfig's default filetypes
(prose plus many programming languages, where it checks comments and string literals); its options are
resolved from `config.yml` (`config.harper.*`) via `lib/harper_utils.lua`, so `lsp_servers.lua` reads the
file at load time like `commands.lua`/`theme.lua` do. Harper's diagnostics are all Hint severity; the
`harper/underline` diagnostic handler (registered in `plugins/lsp.lua`, enabled per-namespace on its
`LspAttach`) replaces the flat, link-like default underline with a dark-red wavy one in the
`HarperDiagnosticUnderline` group from `theme.yml` — scoped to Harper so other servers' hints are untouched.

## Install flow and the headless guard

`ensure_installed` is passed to mason-lspconfig **only when a UI is attached**
(`#vim.api.nvim_list_uis() > 0`). Headless sessions — `task install`, CI, `busted-nvim.sh`, the headless
verification scripts — must never trigger server downloads: CI would be slow and flaky, and `task install` is
documented as fetching plugins only. Consequence: after `task install`, servers download on the **first
interactive launch** (mason shows progress; `:Mason` to inspect). Servers installed mid-session are enabled
immediately, but already-open buffers may need `:edit` to attach.

There is deliberately **no `vim.fn.executable` guard** for the servers (unlike lazygit/rg/markdownlint-cli2):
mason owns installation, missing servers simply never attach, and mason surfaces its own install errors.

## blink.cmp

- `version = "1.*"` — lazy.nvim checks out release tags, which ship a prebuilt Rust fuzzy-matcher binary
  (no cargo). Pinned via `lazy-lock.json` like everything else. If the binary download ever fails, blink falls
  back to its pure-Lua matcher with a warning; `fuzzy = { implementation = "lua" }` forces that permanently.
- `keymap = { preset = "enter" }` — `<CR>` accepts the selected item, `<C-n>`/`<C-p>`/arrows select,
  `<C-space>` opens manually. Selection is left at blink's defaults (`preselect = true, auto_insert = true`):
  the first suggestion is highlighted when the menu opens, so a bare `<CR>` accepts it directly; `<C-e>`
  closes the menu when a plain newline is wanted while it is open.
  This does not break markdown-plus's insert-mode `<CR>` (list continuation): that map is buffer-local to
  markdown buffers, and buffer-local maps shadow blink's global one — plus blink is disabled in markdown
  entirely. **Do not switch to the `super-tab` preset** without the same analysis: markdown-plus also owns
  `<Tab>`/`<S-Tab>` in insert mode for list indent/outdent.
- `enabled` returns false for `markdown` — prose buffers stay completion-free.

## Diagnostics

The global `vim.diagnostic.config()` call sets `severity_sort` and virtual text with source names. It is
namespace-transparent: the markdownlint presentation in `plugins/markdown.lua` is scoped to its own namespace
(`require("lint").get_namespace("markdownlint-cli2")`) and wins per key, so the two sources coexist —
`lsp_spec.lua` has a regression guard for exactly this. bufferline (`diagnostics = "nvim_lsp"`) and lualine's
diagnostics component pick LSP counts up with no extra wiring.

## Folding

The same `LspAttach` autocmd enables folding for non-markdown buffers, driven by the server's
`textDocument/foldingRange`. Unlike the keymaps above, this branch **is** capability-gated: it fetches the
client (`vim.lsp.get_client_by_id(ev.data.client_id)`) and only calls
`config.folding.enable(buf, { engine = "lsp", ... })` — with `vim.lsp.foldexpr()` / `vim.lsp.foldtext()` as the
source — when `client.server_capabilities.foldingRangeProvider` is set; no point wiring folds a server can't
supply. `ev.data` is guarded because a spec can fire `LspAttach` synthetically with no client (`lsp_spec.lua`).

`config/folding.lua` owns the shared UX (`<Tab>` toggle, the `▼`/`▶` `statuscolumn` indicator, click-to-toggle)
that markdown reuses with its own foldexpr — see `config.md` and `markdown.md`. Requires Neovim ≥ 0.11 for
`vim.lsp.foldexpr`/`foldtext` (0.12.4 here); LSP folds populate after the server answers, so they may appear a
beat after attach.

## Keymaps (buffer-local, registered on `LspAttach`)

All maps live in `setup_lsp_keymaps(buf)` and are created by the `lsp_keymaps` augroup's `LspAttach` autocmd —
buffer-local, so they exist only where a server is attached. They are registered **unconditionally on attach**
(not gated on client capabilities) so the integration spec can fire the autocmd on a scratch buffer without a
live server.

| Key                | Mode | Action                                                            |
| ------------------ | ---- | ----------------------------------------------------------------- |
| `<F2>`             | n, i | `vim.lsp.buf.rename`                                              |
| `<leader>cr`       | n    | `vim.lsp.buf.rename`                                              |
| `<F12>`            | n, i | `Snacks.picker.lsp_definitions()` — auto-jumps on a single result |
| `<leader>gd`       | n    | `Snacks.picker.lsp_definitions()`                                 |
| `<S-F12>`, `<F24>` | n, i | `Snacks.picker.lsp_references()` — modal picker                   |
| `<leader>gr`       | n    | `Snacks.picker.lsp_references()`                                  |
| `<leader>r`        | n, x | Refactor menu (see below)                                         |
| `<leader>ca`       | n    | Quick-fix menu (see below)                                        |

The insert-mode function-key maps leave insert mode first (so the prompt/picker opens from normal mode) and
restore it when the action finishes. The restore latches on completion signals, never timers: a one-shot
`WinEnter` latch for flows where a float takes focus (rename prompt, modal picker), plus the snacks picker's
`on_close` callback for flows that never open UI (single-result auto-jump, "No results"). An eager
`startinsert` right after the call would not work — the LSP round trip is async and snacks floats
`stopinsert` while closing. Known edge: `<F2>` on something unrenamable never opens the prompt
(`vim.lsp.buf.rename` exposes no close hook), so its pending latch fires on the next re-entry of that window;
the latch group is cleared on every new invocation. The `<leader>` chords are deliberately normal-mode only —
in insert mode they would collide with typing ordinary text.

Caveats:

- `<F2>` is shadowed in markdown buffers by markdown-plus's buffer-local "rename image" map — deliberate;
  `<leader>cr` still works there if a server is attached.
- `<F24>` exists because some terminals report Shift+F12 as F24. If `<F12>`/`<S-F12>` seem dead, macOS may be
  capturing function keys (System Settings → "Use F1, F2, etc. keys as standard function keys") or the terminal
  swallows them — diagnose with `:luafile scripts/debug-keys.lua` and add whatever sequence actually arrives as
  another lhs. The `<leader>` chords are the delivery-proof fallbacks.
- The `<leader>g` goto prefix (`gd`/`gr`) is why lazygit moved to `<leader>gg` — a bare `<leader>g` map would
  stall on `timeoutlen` (see the prefix caveat in `config.md`).
- Although buffer-local, these maps are listed in `config.md`'s Global Keymap Registry (rows marked "LSP") —
  they occupy their keys in effectively every code buffer.

## Refactor menu (`<leader>r`)

A static `vim.ui.select` menu (snacks.nvim's `ui_select` renders it as a modal — on by default in the picker
module). "Rename symbol" calls `vim.lsp.buf.rename`; every other entry fires a kind-filtered
`vim.lsp.buf.code_action` with `apply = true` (auto-applies a single match, otherwise Neovim lists the
matches). `only` matching is hierarchical — `"refactor"` catches every `refactor.*` kind. In visual mode the
code action operates on the selection.

Refactoring support is server-dependent: **ts_ls** exposes the full tsserver set (extract function/method,
extract constant, inline); **basedpyright**, **lua_ls**, **bashls**, and **yamlls** are essentially
rename-only — their menu entries report "No code actions available", which is honest and requires no
capability plumbing.

## Quick-fix menu (`<leader>ca`) and Harper's dictionaries

`quick_fix()` in `plugins/lsp.lua` is a plain `vim.lsp.buf.code_action()` plus one correction. It exists
because adding a word to a Harper dictionary is a **code action**, and two things stop the obvious call from
reaching it.

**1. Never pass `context.only` here.** Harper emits its dictionary entries as bare `lsp.Command`s with no
`kind`:

```text
Replace with: “autocompletion”                     kind="quickfix", workspace edit + HarperRecordLint
Ignore Harper error.                               kind=nil, HarperIgnoreLint
Add "auto-completion" to the user dictionary.       kind=nil, HarperAddToUserDict,  arguments={word, uri}
Add "auto-completion" to the workspace dictionary.  kind=nil, HarperAddToWSDict,    arguments={word, uri}
Add "auto-completion" to the file dictionary.       kind=nil, HarperAddToFileDict,  arguments={word, uri}
```

Neovim's `action_filter` (in `on_code_action_results`, `$VIMRUNTIME/lua/vim/lsp/buf.lua`) does
`if opts.context.only then if not a.kind then return false end` — so **any** `only` filter drops every
kind-less action. That is why the refactor menu above can never show these, and why adding a kind filter to
`quick_fix` would silently break the whole feature.

Everything past the menu is Neovim's: all six commands are advertised in
`executeCommandProvider.commands`, so `apply_action` → `client:exec_cmd` sends `workspace/executeCommand` and
**harper-ls writes the dictionary file itself**. No client-side dictionary writer, and no `codeAction/resolve`
(Harper sets `codeActionProvider: true` with no resolve provider).

**2. The request range must sit *inside* a lint span.** Measured against harper-ls 2.6.0 on a span at cols
25–40 of a 105-char line:

| requested range                | actions |
| ------------------------------ | ------- |
| empty range at col 25 (start)  | 5       |
| empty range at col 39 (end−1)  | 5       |
| empty range at col 40 (end)    | 0       |
| col 0 → line length            | 0       |
| col 0 → col 40                 | 0       |

A range *containing* the span does not count, so a whole-line request returns nothing and "cursor anywhere on
the offending line" has to be solved client-side. `lib/harper_utils.quick_fix_position` picks the position:
`nil` when the cursor already sits inside a span, otherwise the start of the nearest Harper span on that line
(leftmost on a tie). `quick_fix` feeds it to `opts.range` as an empty range — mark-indexed, so
`make_given_range_params` converts the byte columns from `vim.diagnostic.get()` to Harper's utf-16 offsets. The
cursor deliberately does **not** move: dismissing the menu must not relocate it.

`quick_fix_position` keys on Harper's spans alone, not on every diagnostic in the buffer. Widening it to "any
diagnostic contains the cursor → stay put" looks safer but breaks markdown: nvim-lint's markdownlint
diagnostics can cover most of a line and carry no code actions at all, so they would veto the snap in exactly
the prose buffers this is for. The residual trade-off — cursor inside another server's diagnostic on a line
that also carries a Harper flag — leaves the built-in `gra` as the unsnapped escape hatch.

Two upstream limits worth knowing before chasing a bug:

- The three add-to-dictionary actions are gated on `lint.lint_kind.is_spelling()`. `SpellCheck`, `SplitWords`
  and `DisjointPrefixes` qualify; `SentenceCapitalization`, `OxfordComma` and `UseTitleCase` do not, and offer
  only a replacement plus "Ignore Harper error.". `vim.diagnostic`'s `code` carries the *rule* name, not the
  lint kind, so the client cannot predict which is which — don't try to filter on it.
- After writing, Harper re-lints from the file **on disk** (`update_document_from_file`). With unsaved
  modifications the refreshed diagnostics reflect the saved file, and in a never-written buffer the read fails
  and the refresh is skipped entirely — the word is still added, and the next keystroke re-lints. Nothing here
  works around that.

### `:HarperDict [user|project]`

Lives in `config/commands.lua`, not here, so it also works before any server has attached. It opens the
dictionary for editing — Harper re-reads its dictionaries on every document change, so removing a word is
deleting a line and saving; no `:LspRestart`. The files are created on demand, so an empty new buffer is
normal.

Paths come from `config/lsp_servers.lua`'s already-resolved settings table, deliberately: that is the same
table handed to the server, so the command and Harper cannot disagree about which file is in play. Defaults
mirror harper-ls 2.6.0 — `dirs::config_dir()/harper-ls/dictionary.txt` (macOS:
`~/Library/Application Support/…`) and `.harper-dictionary.txt` in the LSP root. Harper's third target, the
file-local dictionary, lives under a name mangled from the document's full path and is not exposed.

`lsp_servers.lua` runs `vim.fn.expand` over the four optional path fields: Harper resolves `~` and
workspace-relative paths itself but **not** `$VAR`, which is the style `config.yml` already uses for
`obsidian.vault`. Without it, a `$HOME`-prefixed setting would send Harper to a literal `$HOME` directory under
the workspace root while `:HarperDict` opened the expanded path. `harper_utils` stays `vim`-free, so the
expansion belongs at that seam.

## Non-goals

- **Formatting**: conform.nvim owns it (`stylua` for Lua, `prettier` for markdown); `lsp_fallback` stays
  false and there are no LSP format keymaps.
- Neovim 0.11's built-in defaults (`K` hover, `grn`, `gra`, `grr`, …) are left intact; our maps are additions,
  not replacements.

## Testing

`tests/integration/lsp_spec.lua`, modeled on `markdown_lint_spec.lua`'s split:

- **Unconditional wiring** (all CI runs — the headless guard means CI has no servers): force-load
  `nvim-lspconfig` via `require("lazy").load`, assert the `lsp_keymaps` autocmd, fire `LspAttach` on a scratch
  buffer and check every buffer-local map, assert a resolved `vim.lsp.config[name]` for each server, the
  `lua_ls` `vim` global, the global diagnostic defaults, and the markdownlint-namespace no-clobber guard.
- **Functional path** (gated on `vim.lsp.config.lua_ls.cmd[1]` being executable — derived from the resolved
  config so the gate can't silently rot; true on dev machines after the first interactive launch, since
  mason's bin dir is on PATH once `mason.setup()` ran): open a repo Lua file and latch on
  `vim.lsp.get_clients` with a condition-`vim.wait` (never a blind sleep) until `lua_ls` attaches.
- **Harper functional path** (same gate shape, on `harper_ls.cmd[1]`): a throwaway temp dir with a `.git`
  marker — Harper canonicalizes its workspace root and misresolves paths without one — plus a one-line
  markdown fixture. Latches on attach, then on the first diagnostic in Harper's namespace, then asks from
  **column 0** of each flagged line and asserts an `Add "…" to the user dictionary.` title comes back, which
  only holds if the snap worked. It **requests only**: executing one of those commands would write the real
  user dictionary. `scripts/busted-nvim.sh`'s fixture `config.yml` sets `harper.userDictPath` to a literal
  `$NVIM_CONFIG_ROOT/…` so the `vim.fn.expand` pass is covered too.

Gotcha: `:edit` in the functional path replaces the unnamed scratch buffer (Vim auto-wipes an empty unnamed
buffer), so the teardown guards `bwipeout` with `nvim_buf_is_valid`.
