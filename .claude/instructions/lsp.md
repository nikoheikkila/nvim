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
global and `$VIMRUNTIME` in the workspace library — no lazydev.nvim.

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

Gotcha: `:edit` in the functional path replaces the unnamed scratch buffer (Vim auto-wipes an empty unnamed
buffer), so the teardown guards `bwipeout` with `nvim_buf_is_valid`.
