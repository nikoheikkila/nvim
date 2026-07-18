# Explorer (`lua/plugins/explorer.lua`) — `nvim-neo-tree/neo-tree.nvim`

File-tree sidebar on the right (`window.position = "right"` — neo-tree's default is left; the default
width of 40 is deliberately not restated in `opts`). Lazy-loaded via `keys`/`cmd`, so startup is
unaffected; the first toggle has a one-time load delay. Adds one new dependency, `MunifTanjim/nui.nvim`
— `plenary.nvim` and `nvim-web-devicons` were already installed (lazygit.nvim, bufferline/lualine).
Netrw hijacking is explicitly disabled (`hijack_netrw_behavior = "disabled"`): lazy-loading means
neo-tree could never hijack `nvim <dir>` at startup anyway, and disabling it keeps `:e <dir>`
consistent after the plugin loads. `follow_current_file` keeps the tree cursor on the buffer being
edited. `close_if_last_window = true` exits Neovim cleanly instead of leaving the sidebar as the last
window.

## Global keymap

| Key           | Mode | Action                        |
| ------------- | ---- | ----------------------------- |
| `<leader>e`   | n    | Toggle the file tree sidebar  |

The toggle also works while the tree is focused: neo-tree registers its buffer-local `<space>`
(toggle_node) with `nowait = false`, so `<leader>`-prefixed chords still resolve. If upstream ever flips
that flag, add `["<space>"] = "none"` to `window.mappings`.

## Tree-buffer keymaps (buffer-local)

| Key | Action | Default or remapped? |
| --- | --- | --- |
| `j`/`k`, `<Up>`/`<Down>` | Move between entries | Native (deliberately unmapped) |
| `<CR>` | Open file / toggle directory | Default (`open`) |
| `l`, `<Right>` | Open file / expand directory | Remapped — default `l` is `focus_preview`; preview stays on `P` |
| `h`, `<Left>` | Collapse directory (on a file: jump to parent and collapse it) | Remapped (`close_node`) |
| `d` | Delete with confirm prompt | Default |
| `r` | Rename (prompt pre-filled) | Default |
| `m` | Move to another path (prompt, relative to tree root) | Default |
| `n` | New file at typed path (see note below on nested parents) | Remapped from default `a` |
| `N` | New directory (dedicated prompt) | Remapped from default `A` |
| `v` | Enter linewise Visual mode | Remapped — see visual-mode section below |
| `<2-LeftMouse>` | Open file / toggle directory (see note below on single click) | Default |
| `/` | Fuzzy filter within the tree | Default |

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

No highlight patching is needed (unlike `RenderMarkdownCode`, see `markdown.md`): laserwave's
`transparent = true` clears `Normal`'s background, `NormalNC` links to `Normal`, and laserwave's own
`groups/plugins/neotree.lua` deliberately leaves `NeoTreeNormal`/`NeoTreeNormalNC`/`NeoTreeEndOfBuffer`
undefined, so neo-tree's link-to-`Normal` defaults inherit the transparency (laserwave does ship
fg-only `NeoTreeGit*` status colors). If a future update introduces an opaque region, follow the
`markdown.lua` `ColorScheme`-autocmd precedent, clearing only `bg` and preserving `fg`.

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
