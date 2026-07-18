# Markdown (`lib/markdown_utils.lua`, `plugins/markdown.lua`)

## Markdown Utilities (`lua/lib/markdown_utils.lua`)

Pure-Lua module with no Neovim API dependencies — safe to unit-test outside Neovim.

### Functions

**`find_image_path_at(line, col)`**
Scans `line` for Markdown image references `![alt](path)` and returns the path if the 1-based column `col`
falls within an image span. Returns `nil` when `col` is outside any image span. Strips trailing title
attributes (e.g. `"My Title"` or `'title'`).

**`is_remote_url(path)`**
Returns `true` when `path` starts with `http://` or `https://`.

**`replace_filename(path, new_name)`**
Replaces the filename component of `path` with `new_name`, preserving any directory prefix. E.g.
`replace_filename("images/foo.png", "bar.png")` → `"images/bar.png"`.

**`toggle_checklist_line(line)`**
Returns a transformed copy of `line` with its checklist state cycled through three cases:

- Checklist item (`- [ ] …` or `- [x] …`) → toggle `[ ]` ↔ `[x]`
- Bare list item (`- item`) → insert `[ ]` after the marker
- Plain line → prepend `- [ ]` with indentation preserved

Returns the original line unchanged when it is empty.

## Markdown Plugins (`lua/plugins/markdown.lua`)

### 1. `yousefhadder/markdown-plus.nvim`

Loaded for `ft = "markdown"`. Provides the core editing operations through `<Plug>` mappings that are
registered globally (not buffer-local) when the plugin enables itself for a buffer.

**Why `keymaps = { enabled = true }`**
The plugin's `keymaps.enabled` flag controls whether the default `<localleader>m*` bindings are applied.
Critically, it also controls the `<CR>` → `<Plug>(MarkdownPlusListEnter)` mapping in insert mode that
auto-continues list items. Setting this to `false` silently breaks list continuation. Keep it `true`; our
custom Ctrl bindings sit alongside the defaults without conflict.

**Custom keymap setup**
`setup_keymaps(buf)` is called:

1. Immediately for any already-loaded markdown buffers (handles the case where `setup()` is called after the
   first buffer opens).
2. From a `FileType markdown` autocmd (group `MarkdownPlusKeymaps`) for every subsequent buffer.

The plugin registers its own `FileType markdown` autocmd inside `M.setup()`. Because `M.setup()` is called
first inside the `config` function, the plugin's autocmd is registered before ours. When a file opens, the
plugin's handler fires first (creating the `<Plug>` targets), then ours fires (mapping Ctrl keys to those
targets). Order is guaranteed.

**Italic uses pattern-patching, not the `<Plug>` target**
`markdown-plus.nvim` hardcodes `italic = { wrap = "*" }` in `lua/markdown-plus/format/patterns.lua` with no
config option. To honour the requirement of `_` for italic, `italic_visual()` and `italic_normal()`
temporarily overwrite `patterns.patterns.italic.wrap` with `"_"`, call the plugin's toggle function
synchronously, then restore the original value. This is safe because the toggle runs synchronously with no
async callbacks.

**Checklist toggle delegates to `markdown_utils`**
The custom `checklist_toggle()` function in `markdown.lua` avoids `parse_list_line` entirely and delegates to
`mu.toggle_checklist_line()` from `lib/markdown_utils.lua` (see Markdown Utilities section above). This
sidesteps a treesitter timing issue where `parse_list_line` returns a valid `list_info` with
`list_info.checkbox = nil`, causing `add_checkbox_to_line` to fire on an already-checkboxed line and produce
a duplicate `[ ]`.

**Image rename**
`rename_image_at_cursor()` uses `mu.find_image_path_at()` to locate the image reference under the cursor,
validates the file exists, prompts for a new name via `vim.ui.input`, renames the file on disk with
`os.rename`, then replaces all occurrences of the old path in the buffer.

#### `<Plug>` targets used

| `<Plug>` | Normal/Visual | Registered by |
| --- | --- | --- |
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
| --- | --- | --- |
| `<C-b>` | n + x | Toggle bold |
| `<C-i>` | n + x | Toggle italic (`_`) |
| `<C-k>` | n + x | Insert / wrap link |
| `<C-l>` | n + i | Toggle checklist item (single line) |
| `<C-l>` | x | Toggle checklist range |
| `<C-S-I>` | n + x | Insert / wrap image |
| `<F2>` | n | Rename image file at cursor |

**Terminal compatibility:** `<C-S-I>` (Ctrl+Shift+I) requires the Kitty keyboard protocol. Supported terminals:
kitty, WezTerm, Ghostty, and recent versions of foot. In terminals that do not support it the mapping is
silently ignored.

#### Default `<localleader>` bindings (from the plugin, always active)

These exist alongside the Ctrl bindings and do not conflict:

| Key | Action |
| --- | --- |
| `\mb` | Toggle bold |
| `\mi` | Toggle italic (`*`) |
| `\mS` | Toggle strikethrough |
| `` \m` `` | Toggle inline code |
| `\ml` | Insert / wrap link |
| `\mL` | Insert / wrap image |
| `\mx` | Toggle checkbox |
| `\mr` | Renumber ordered lists |
| `<CR>` (insert) | Continue list item |
| `<Tab>` (insert) | Indent list item |
| `<S-Tab>` (insert) | Outdent list item |
| `<BS>` (insert) | Smart backspace (removes empty list marker) |

### 2. `MeanderingProgrammer/render-markdown.nvim`

Loaded for `ft = { "markdown" }`. Renders headings, bold, italic, code blocks, tables, and checkboxes as
styled virtual text in the buffer. No external binaries required — but syntax highlighting *inside* code
fences depends on `plugins/treesitter.lua` supplying treesitter queries for the fence languages (see
`plugins.md`); render-markdown only draws the block chrome.

**Code blocks: `code.sign = false`**
render-markdown's defaults render the fence language twice: an icon in the sign column (`sign = true`) *and*
an inline icon+name label overlaying the delimiter line. `sign = false` keeps only the inline label.

**Why `render_modes = true`**
The default is `{ 'n', 'c', 't' }` — insert and visual modes are excluded. Without this override, switching
to insert or visual mode strips all rendering and changes the visual appearance of the buffer dramatically.
`true` activates rendering in every mode. The `anti_conceal` feature (enabled by default) still reveals raw
syntax on the cursor line regardless of `render_modes`.

**Highlight overrides (`fix_highlights`)**
A single function applies all highlight overrides on startup and re-applies them on every `ColorScheme` event:

- `RenderMarkdownCode` / `RenderMarkdownCodeBorder` are cleared to `bg = "NONE"` — the plugin's opaque
  code-block backgrounds block terminal transparency.
- `@markup.raw.block.markdown` is redefined non-italic (keeping the theme's `@markup.raw` fg, read via
  `nvim_get_hl`). github-theme styles `@markup.raw` italic and leaves `@markup.raw.block` undefined, so
  fence content falls back to italic — and injected language captures set fg but not italic in extmark
  attribute merging, so the italic bleeds through highlighted code. Only the block group is overridden;
  inline code (`@markup.raw` on `markdown_inline`) keeps the theme's italic styling.
- H1 renders in magenta: `RenderMarkdownH1` (fg `#ff00ff`, bold) and `RenderMarkdownH1Bg` (bg `#3a0d3a`). The
  shades differ deliberately — the `#` marker is drawn with the fg group *over* the bg band, so identical
  values would make it invisible. The plugin's fg group only covers the marker and sign; the heading text is
  highlighted by treesitter, so `@markup.heading.1.markdown` is set to the same magenta.

**Icon overrides**
Headings render their literal ATX markers (`#`–`######`) instead of nerd-font icons. With the default
`heading.position = 'overlay'` each icon string is laid *over* the raw markers, so every entry must be
exactly as wide as the markers it covers (level N = N hashes + 1 space) or the overlay clips/leaks.
Checkboxes render as `○` (unchecked, `DiagnosticError` red) and `●` (checked, `DiagnosticOk` green) —
Diagnostic groups are used so the colors track any theme without custom highlight management. Plain list
bullets render as `•` at every indent level with the `Normal` foreground.

### 3. `stevearc/conform.nvim`

Loaded on `BufWritePre`. Runs `prettier` on markdown files before every save. If `prettier` is not found,
conform logs a one-time warning and skips formatting silently — it does not block saving.

The formatter is set only for `markdown`. Adding formatters for other filetypes should extend
`formatters_by_ft`, not replace it.

### 4. `mfussenegger/nvim-lint` (live markdownlint)

Loaded for `ft = "markdown"`. Runs `markdownlint-cli2` over the **unsaved buffer content** (stdin) and publishes
the findings as diagnostics: offending lines get a dark-yellow background (`MarkdownLintLine`, `#3a2f1a`,
re-applied on `ColorScheme` like render-markdown's `fix_highlights`) and the exact warning message — MDxxx rule
id included — as end-of-line virtual text. This is the repo's first and only `vim.diagnostic.config()` call, and
it is **namespace-scoped** to `require("lint").get_namespace("markdownlint-cli2")` so any future LSP/linter
diagnostics keep Neovim's default styling.

**Why markdownlint-cli2 (not markdownlint-cli v1):** same engine (David Anson's `markdownlint` library), but
cli2's `--config` is applied as a *base* configuration that per-directory `.markdownlint*` files still override,
it's maintained by the markdownlint author (same engine as vscode-markdownlint), and it's what the wider
nvim-lint ecosystem configures today.

**Config layering:** `.markdownlint.jsonc` at the repo root (the filename is constrained by cli2's `--config`,
which requires a recognized config name) is passed as the base config on every run — it aligns MD013
`line_length` with `textwidth = 120` from `options.lua`. Project-local `.markdownlint*` files override it, but
note stdin linting resolves them against **Neovim's cwd**, not the buffer's directory. Tune global rules in that
file; never in the Lua spec.

**Parser override:** cli2 ≥ 0.18 prefixes findings with a severity word (`stdin:3:121 error MD013/... message`);
nvim-lint's bundled errorformat predates that and would leak the word `error` into every message (and
`%t`-style parsing would misfile them as ERROR, escaping the WARN-keyed `linehl`). The spec overrides the parser
with an errorformat that strips `error`/`warning` and keeps old-format fallbacks, forcing severity WARN.

**Debounce (the `timer` upvalue):** nvim-lint has no internal debounce and every run spawns a node process
(~100–300ms startup). Restarting an active `vim.uv` timer on each event coalesces bursts — an `InsertLeave`
triggers auto-save → prettier → `BufWritePost` (plus `TextChanged` from the reformat), and all of it collapses
into **one** lint of the post-prettier content 300ms later.

**Events live in the `markdown_lint` augroup, never `auto_save`:** the integration spec asserts `auto_save` has no
`TextChanged` autocmds (that debounced-save regression is not allowed back). Lint-on-`TextChanged` is fine — it
only reads the buffer.

**Empty sign text (`signs.text = { [WARN] = "" }`):** the whole-line background rides on diagnostic *sign*
extmarks. If `signs.text` is unset, the runtime defaults it to `"W"` (`runtime/lua/vim/diagnostic.lua`, signs
handler), and a visible sign opens/shifts the auto signcolumn on every appearing/disappearing warning. An
explicitly empty string keeps `line_hl_group` working with `textoff == 0` (verified on 0.12.4 and asserted in
the integration spec).

**Missing-binary guard:** checked inside `lint_buf()` before any spawn, notifying once per session (`warned`
upvalue) — the house idiom from `git.lua`/`picker.lua`. Wiring (augroup, highlight, namespace config) is set up
unconditionally so the integration spec asserts it with or without the binary; the guard branch is exercised via
`scripts/test-without-binary.sh markdownlint-cli2 -- task test:integration`. If the binary appears mid-session,
linting starts working without a restart (only the notification is one-shot). `lint_buf()` ends by firing
`User MarkdownLintRun` — a no-op with no listeners — as the deterministic sync point
`tests/integration/markdown_lint_spec.lua` latches on instead of sleeping out the debounce.

**ft-lazy catch-up loop:** `config()` runs during the first markdown buffer's `FileType` event — after that
buffer's `BufReadPost` — so already-open markdown buffers are linted directly at setup (same pattern as
markdown-plus's keymap catch-up). Buffers created via `BufNewFile` (a fresh `:Daily` note) get their first lint
on the first edit.

Known cosmetic caveat: render-markdown's heading background bands use a higher extmark priority (4096) than
diagnostic signs (10), so on a *heading* line the band wins over the dark-yellow background — the virtual-text
message still shows. If that ever matters, add `signs.priority` to the namespace config; don't pre-fix it.
