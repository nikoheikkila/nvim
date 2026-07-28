# Obsidian (`lua/plugins/obsidian.lua`)

[obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) (the `obsidian-nvim/` community fork, pinned to
the latest release with `version = "*"`). User-facing docs: [`docs/obsidian.md`](../../docs/obsidian.md).

## Vault configuration flows through `config.yml`

`config.obsidian` (`vault`, `dailyNotes.folder`, `dailyNotes.dateFormat`) is read at **spec-eval time** —
`yaml_utils.read_file` → `obsidian_utils.resolve_config` → `vim.fn.expand` — the same pattern
`plugins/theme.lua` uses for `theme.yml`. `lib/obsidian_utils.lua` stays free of vim/os calls so it runs under
plain busted; the plugin file does the expansion. Never hardcode a vault path in Lua.

Both `config.yml` values must stay **quoted**: `yaml_utils`' `coerce()` turns bare numerics into numbers, which
would mangle a folder name like `000 - Inbox`. `resolve_config` treats absent, empty, and wrong-typed values
identically — the shipped default wins.

## Coexistence settings

Each of these exists to stop obsidian from taking over something another plugin already owns:

- `ui = { enable = false }` — render-markdown.nvim (`plugins/markdown.lua`) owns markdown rendering. obsidian
  auto-detects render-markdown and skips its own UI anyway, but being explicit avoids a `git rev-parse`
  shell-out per lookup and matches upstream's plan to delete the UI module entirely.
- `picker = { name = "snacks.picker" }` — reuses the picker from `plugins/picker.lua`. `"snacks.picker"` is the
  exact string in the `obsidian.config.Picker` enum; `"snacks"` and `"snacks.nvim"` are not it.
- `dependencies = { "folke/snacks.nvim" }` — **required for the line above to work.** obsidian resolves its
  picker through `api.get_plugin_info`, which scans `nvim_list_runtime_paths()`, so a plugin only counts as
  available once it is **loaded**, not merely installed. snacks is `keys`-lazy in `plugins/picker.lua`, so
  without this dependency `:Obsidian search` as the first action of a session hits
  `'Configured picker "snacks.picker" is not available; falling back to native picker'` and you silently get a
  `vim.ui.select` list instead. The cost is snacks loading at startup. `:checkhealth obsidian` catches a
  regression here ("[Pickers]" goes from `OK snacks.nvim` back to a WARNING), and `obsidian_spec.lua` guards it.
- `legacy_commands = false` — only the `:Obsidian <subcommand>` form. Upstream drops the `:ObsidianFoo` aliases
  in 4.0.0.
- Folding is guarded in `config/folding.lua`, not here — see [`config.md`](config.md)'s "Fold-source
  Ownership". This matters because obsidian runs an in-process LSP (`obsidian-ls`) advertising
  `foldingRangeProvider`, so `plugins/lsp.lua`'s `LspAttach` handler really does fire for vault notes.

`completion` is left at its defaults: completion now comes from the `obsidian-ls` LSP, which blink.cmp picks up
automatically. The old `completion.nvim_cmp` / `completion.blink` keys are deprecated no-ops.

## Not lazy-loaded

`lazy = false`, with no `ft`/`event`/`cmd` trigger. Upstream documents no lazy-loading anywhere, and the
plugin's `FileType` autocmd is what installs the buffer-local `BufEnter` handler that wires keymaps,
`includeexpr` and the LSP. Creating that autocmd _during_ the `FileType` event it needs would miss the first
buffer — the trap `plugins/markdown.lua` and the nvim-lint spec work around with catch-up loops.
`plugins/treesitter.lua` sets the same precedent.

## Keymaps

The plugin sets exactly three, all buffer-local to vault notes, all normal-mode, none `<leader>`-prefixed:
`<CR>` (smart action), `]o` and `[o` (link navigation). They are in the registry in
[`config.md`](config.md).

To disable them, upstream offers `vim.g.obsidian_default_keymap = false` (a Vim global, checked with `~= false`,
deliberately not a config key) or `vim.keymap.del` on the `User ObsidianNoteEnter` autocmd.

Because `obsidian-ls` attaches, vault notes also pick up the `LspAttach` keymaps from `plugins/lsp.lua`:
`<leader>cr` renames the note and updates its backlinks, `<leader>gr` lists them. `<F2>` is the markdown
image rename, which shadows the LSP rename there as it always has.

## snacks.image

`plugins/obsidian.lua` contributes a **second** `folke/snacks.nvim` spec whose only job is
`image = { enabled = true, resolve = … }`; lazy.nvim merges its `opts` with `plugins/picker.lua`'s. It lives
here rather than in `picker.lua` so the `require("obsidian.api")` inside `resolve` sits in the file that owns
obsidian. `obsidian_spec.lua` asserts both modules survive the merge.

The `resolve` hook is required, not cosmetic: vault attachments are referenced by encoded base name, not a path
relative to the note, so snacks cannot find them alone. It is scoped with `api.path_is_note(path)` so image
resolution in non-vault markdown is untouched.

## Testing

`tests/unit/obsidian_utils_spec.lua` covers the pure resolver. `tests/integration/obsidian_spec.lua` asserts the
merged spec opts plus the buffer-local contract inside a note in the **fixture** vault that
`scripts/busted-nvim.sh` creates at `$NVIM_CONFIG_ROOT/fixture-vault/.obsidian` — never the real vault. The
fixture `config.yml` stores the vault as the literal `$NVIM_CONFIG_ROOT/fixture-vault`, relying on
`vim.fn.expand` to resolve the env var, so the spec can recompute the same path.

The spec leaves and re-enters the buffer (`:enew` then `:buffer <n>`) to guarantee obsidian's `BufEnter` handler
has run without depending on headless event ordering, and tears down with `bwipeout!` so obsidian's
`BufWritePre` frontmatter injection never fires.
