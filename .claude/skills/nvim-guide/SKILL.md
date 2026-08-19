---
name: nvim-guide
description: |
  Neovim-specific Lua guardrails and patterns for AI-assisted development: plugin/config
  authoring, the `vim` global, lazy-loading semantics, and headless Neovim verification.
  Use when working on this Neovim config or a Neovim plugin, or when the user mentions
  Neovim/nvim/lazy.nvim/headless testing.
license: MIT
metadata:
  author: Niko Heikkilä
  version: "1.0"
  category: editor
  language: lua
  extensions: ".lua"
---

# Neovim Guide

> Applies to: Neovim Lua (`:h lua-guide`), lazy.nvim plugin specs, Neovim plugin authoring

## Core Principles

1. **`vim` Is Always Global**: no `require` needed for the `vim` table itself; only plugin
   modules need `require`
2. **`M.setup(opts)` Is the Convention**: merge user opts over defaults with
   `vim.tbl_deep_extend("force", defaults, opts or {})`, and let `enabled = false` short-circuit
3. **Lazy-Loading Changes What "Startup" Means**: a plugin gated on `event`/`keys`/`cmd`/`ft`
   hasn't run its `setup()` yet when a script or another plugin references it — see
   [Guardrails](#lazy-loading) below
4. **Prove Behavior Headlessly, Don't Reason About It**: `~/.local/share/nvim/lazy/<plugin>/`
   and `$VIMRUNTIME/lua/vim/**` are on disk and pinned — read them, or drive a headless script,
   rather than guessing from memory or upstream docs
5. **Terminals Rewrite Input**: a registered keymap is not a delivered keypress — see the
   mouse/terminal caveat below

## Guardrails

### Lazy-Loading

- A lazily-loaded plugin never sees `VimEnter` if it wasn't the reason Neovim loaded that file —
  drive its setup explicitly (e.g. via `event`/`keys`/`cmd`/`ft` in its lazy.nvim spec) rather
  than trusting a `run_on_start`-style option baked into the plugin itself
- `event = "VeryLazy"` fires from a once-only `UIEnter` autocmd — it never fires headlessly
  (`--headless` attaches no UI), so such a plugin's `config()` never runs in a headless script no
  matter how long it waits
- To force-load a lazy plugin (in a script, or to assert on its resolved config):
  `require("lazy").load({ plugins = { "plugin.nvim" } })`

### Module Access vs. Bare Globals

- Many plugins export a convenience global alongside their module (e.g. `folke/snacks.nvim` sets
  `_G.Snacks`). Prefer `require("plugin_name")` over the bare global in config/keymaps — it
  behaves identically and needs no linter global declaration
- lazy.nvim's module searcher auto-loads a plugin the first time any of its submodules is
  `require`d, so a `keys`/`cmd`/`event`-lazy plugin can safely be referenced as
  `require("plugin.submodule").fn(...)` from eager code (a keymap callback, a user command) — the
  `require` only runs when that code fires, pulling the plugin in on demand without adding it as
  an eager `dependencies` entry. The bare global does not get this guarantee; it stays `nil` until
  something else loads the plugin.

### Mouse/Terminal Caveat

- The OS and terminal rewrite or swallow input before Neovim sees it (macOS: Ctrl+arrows go to
  Mission Control, Ctrl+click arrives as a right-click with the modifier stripped; Warp strips
  Ctrl from mouse reports entirely). `:map <key>` proves registration only, never delivery.
- Diagnose delivery with a `vim.on_key` logger (`vim.fn.keytrans(key)` per event) and design
  bindings around what actually arrives, not what should arrive.

### Mapleader Load Order

- A `<leader>` mapping created before `vim.g.mapleader` is set silently binds under the default
  `\` with no error or warning. Set leader keys in the first module `init.lua` loads, before any
  mapping and before the plugin manager.

## References

- [references/patterns.md](references/patterns.md) — Neovim plugin/config setup pattern
- [references/testing.md](references/testing.md) — headless Neovim verification, running Busted
  inside a real Neovim process, config-fixture testing traps
- [references/tooling.md](references/tooling.md) — Selene/Luacheck configuration for the `vim`
  global and lazy.nvim-shaped tables

## External References

- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [lazy.nvim](https://github.com/folke/lazy.nvim)
- [Busted Testing Framework](https://lunarmodules.github.io/busted/)
- [Selene Linter](https://github.com/Kampfkarren/selene)
