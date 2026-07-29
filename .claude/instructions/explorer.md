# Explorer (`lua/plugins/explorer.lua`) — `nvim-neo-tree/neo-tree.nvim`

File-tree sidebar on the right (`window.position = "right"` — neo-tree's default is left; the default
width of 40 is deliberately not restated in `opts`).

Lazy-loaded via `keys`/`cmd`, so startup is
unaffected; the first toggle has a one-time load delay.

Adds one new dependency, `MunifTanjim/nui.nvim`
— `plenary.nvim` and `nvim-web-devicons` are already installed (lazygit.nvim, bufferline/lualine).

Netrw hijacking is explicitly disabled (`hijack_netrw_behavior = "disabled"`): lazy-loading means
neo-tree could never hijack `nvim <dir>` at startup anyway, and disabling it keeps `:e <dir>`
consistent after the plugin loads. `follow_current_file` keeps the tree cursor on the buffer being
edited.

## `close_if_last_window` must stay `false`

It is not a cosmetic setting: neo-tree implements it as a `WinClosed` autocmd in
`plugin/neo-tree.lua` (always loaded, even before the plugin itself) that ends in `vim.cmd("q!")`
whenever the tree is the last non-floating window in the tab. The handler filters floats out of the
pane _count_ but never bails when the window being closed **is itself a float** — so dismissing any
float over a lone sidebar quits Neovim outright: the nui rename/add prompt, a snacks picker, lazygit,
zen-mode. `vim.cmd` does not expand command-line abbreviations, so `commands.lua`'s `:q` →
`:BufClose` override cannot intercept it; this is the one code path in the config that can still quit
Neovim behind that override.

That is upstream [#1818](https://github.com/nvim-neo-tree/neo-tree.nvim/issues/1818), fixed by
[#1819](https://github.com/nvim-neo-tree/neo-tree.nvim/pull/1819) (`84c3df0`) with a
`previous_window_floating` guard, which the [#1830](https://github.com/nvim-neo-tree/neo-tree.nvim/pull/1830)
(`7eadf08`) rewrite then deleted — so the regression is live at the pinned commit and updating does
not help. The originally reported symptom here was "rename a file from the sidebar, Neovim quits";
it presents as a crash but is a plain `:q!`, so no crash report is ever written.

Little is lost by disabling it, but not nothing. Bare `:q` was never affected — `commands.lua`
rewrites it to `:BufClose`, which deletes the buffer and keeps the layout — so the option only ever
fired for `:close`, `<C-w>c`/`<C-w>q` and `nvim_win_close`. Those now leave the sidebar as the only
window instead of quitting; press `<leader>e` to close it, or `:qa` to quit. That is the intended
trade: restoring the behaviour means owning a re-implementation of the handler (an own `WinClosed`
autocmd returning early when `require("neo-tree.utils").is_floating(closing_win)`, closing the window
rather than issuing `q!`) against upstream code that was rewritten twice in two PRs.

`tests/integration/explorer_spec.lua` pins both the setting and the behaviour, and a regression there
exits the editor rather than failing a test — so its `setup` re-asserts the option (via
`ensure_config()`, the merged table the handler reads) before any window surgery. Two of its three
specs are behavioural: the float-close spec is the class invariant, the rename spec the originally
reported symptom.

## Global keymap

| Key         | Mode | Action                       |
| ----------- | ---- | ---------------------------- |
| `<leader>e` | n    | Toggle the file tree sidebar |

The toggle also works while the tree is focused: neo-tree registers its buffer-local `<space>`
(toggle_node) with `nowait = false`, so `<leader>`-prefixed chords still resolve. If upstream ever flips
that flag, add `["<space>"] = "none"` to `window.mappings`.

## Tree-buffer keymaps (buffer-local)

| Key                      | Action                                                         | Default or remapped?                                            |
| ------------------------ | -------------------------------------------------------------- | --------------------------------------------------------------- |
| `j`/`k`, `<Up>`/`<Down>` | Move between entries                                           | Native (deliberately unmapped)                                  |
| `<CR>`                   | Open file / toggle directory                                   | Default (`open`)                                                |
| `l`, `<Right>`           | Open file / expand directory                                   | Remapped — default `l` is `focus_preview`; preview stays on `P` |
| `h`, `<Left>`            | Collapse directory (on a file: jump to parent and collapse it) | Remapped (`close_node`)                                         |
| `d`                      | Delete with confirm prompt                                     | Default                                                         |
| `r`                      | Rename (prompt pre-filled)                                     | Default                                                         |
| `m`                      | Move to another path (prompt, relative to tree root)           | Default                                                         |
| `n`                      | New file at typed path (see note below on nested parents)      | Remapped from default `a`                                       |
| `N`                      | New directory (dedicated prompt)                               | Remapped from default `A`                                       |
| `v`                      | Enter linewise Visual mode                                     | Remapped — see visual-mode section below                        |
| `<2-LeftMouse>`          | Open file / toggle directory (see note below on single click)  | Default                                                         |
| `/`                      | Fuzzy filter within the tree                                   | Default                                                         |

For `n`, nested parents are auto-created and a trailing `/` creates a directory instead of a file. For
`<2-LeftMouse>`, a single click positions the cursor and the wheel scrolls — Neovim's default `mouse=nvi`.

`n`/`N` shadow search-next/prev only inside the tree buffer (all mappings are buffer-local), where `/`
is neo-tree's fuzzy filter rather than vim search anyway. Single-click-to-open was deliberately not
bound: it would make it impossible to click merely to focus the tree, and it fights mouse-drag visual
selection. If ever wanted, it's one line: `["<LeftRelease>"] = "open"`.

## Visual-mode bulk operations

For every mapping, neo-tree's renderer looks up `state.commands[func .. "_visual"]` and, when it exists,
auto-maps the same key buffer-locally in visual mode. So `v`/`V` + motion (or mouse drag) selects
multiple entries, then `d` bulk-deletes with a single confirm, `x` cuts and `p` on a directory
bulk-moves, `y` + `p` bulk-copies. `r` and `m` have no `_visual` variants — bulk move is the `x`+`p`
flow.

**Why `v` is remapped to linewise `V`:** Vim disables `'cursorline'` while Visual mode is active, and
charwise `v` highlights only the single character under the cursor until the selection grows — so
entering visual mode appeared to lose the current-entry highlight entirely. Tree entries are whole
lines, so `v` enters linewise Visual mode via a function mapping (`nvim_feedkeys("V", "n", false)`),
keeping the entry visibly highlighted from the first keypress.

## Single-keypress confirmations

Neo-tree's default confirmation dialog is a NUI popup that requires typing `y`/`n` and then pressing
`<CR>`. The `config` function in `explorer.lua` replaces `require("neo-tree.ui.inputs").confirm` with a
`vim.fn.confirm()`-based implementation: `y` confirms immediately, `n` or `<Esc>` aborts, and bare
`<CR>` defaults to No. This affects every neo-tree confirmation (delete, overwrite on move/copy
conflicts); text prompts (rename/add/move) keep their floating popups because only `confirm` is
patched, not `input`. This is the same documented-patch approach as `markdown.lua`'s italic pattern
override (see `markdown.md`) — if the patch ever breaks after a neo-tree update, check that
`M.confirm`'s signature in `lua/neo-tree/ui/inputs.lua` still matches `(message, callback?)` with a
blocking boolean return when `callback` is nil.

## Transparency

`explorer.lua` patches no highlight groups, unlike `RenderMarkdownCode` (see `markdown.md`). neo-tree
leaves `NeoTreeNormal`/`NeoTreeNormalNC`/`NeoTreeEndOfBuffer` linked to `Normal` unless the colorscheme
defines them, so the sidebar inherits whatever background the theme sets. If a theme change introduces
an opaque region, follow the `markdown.lua` `ColorScheme`-autocmd precedent, clearing only `bg` and
preserving `fg`.

## Verifying file operations headlessly

The `d`/`r`/`n`/`m`/`N` prompts are nui popups — like `vim.ui.input`, unreliable to drive with feedkeys
headlessly. Instead, stub the prompt module directly and call the same `fs_actions` functions the
mappings invoke (this is how the setup was originally verified):

```lua
local inputs = require("neo-tree.ui.inputs")
inputs.input = function(_, _, callback) callback("canned-answer") end
inputs.confirm = function(_, callback) callback(true) end
local fs = require("neo-tree.sources.filesystem.lib.fs_actions")
-- fs.create_node(dir, nil, dir) / fs.rename_node(path, nil) / etc.
```

The operations complete via async libuv callbacks — `vim.wait()` for the expected filesystem state
instead of asserting immediately.

Two neo-tree-specific hazards when a spec opens a real tree (see `explorer_spec.lua`):

- **Close the tree with `:Neotree close`, never `nvim_win_close`.** Closing it behind the plugin's
  back leaves a stale winid in its source state; once a later spec creates a window that reuses that
  id, neo-tree renders the tree buffer into it. Source state is keyed by tabid, so doing the whole
  thing in a throwaway `tabnew` keeps it out of the shared session too.
- **File operations echo their own INFO messages** ("Renamed x successfully"), which pollute test
  output. Silence them with `require("neo-tree.log").set_level({ file = <old>, console = "warn" })`
  and restore in `teardown`. The **table** form is required: the scalar form clamps console to
  `math.max(level, INFO)`, so it can never suppress INFO.
- **Wait for the tree's first render, not just for its window.** `:Neotree show` creates the window
  synchronously but fills it from an async `fs_scan`, so the buffer is still empty when the window
  appears. Acting on the tree before that scan renders lets its stale result land after your own
  refresh, leaving the tree showing pre-operation contents indefinitely. Latch on the fixture name
  appearing in the tree buffer.
- **Pass the refresh callback that the real mapping passes.** `fs_actions.rename_node(path)` on its
  own leaves the redraw to an incidental buffer-event subscription whose ordering is not dependable —
  it worked on macOS and timed out on Ubuntu CI. Mirror `filesystem/commands.lua`:
  `rename_node(path, function() fs._navigate_internal(state, nil, nil, done, false) end)`, and latch
  on `done`. That is a real completion signal, and it leaves no `fs_scan` in flight at teardown — one
  that lands later has `renderer.acquire_window` build a fresh tree window in whatever window is
  current by then, which broke `markdown_keymaps_spec` with "Buffer is not 'modifiable'" three spec
  files later.
