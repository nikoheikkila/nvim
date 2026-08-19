# Neovim Tooling Reference

## Selene for Neovim

Selene ships **no built-in Neovim/`vim` standard library** — only `lua51`/`lua52`/`lua53`/`lua54`/`roblox` are
built in. For Neovim plugin/config code, vendor a small custom std file named `vim.yml` next to `selene.toml`
(the modern YAML std format; TOML std files are the legacy format):

```toml
# selene.toml
std = "lua51+vim"   -- LuaJIT (Neovim's embedded Lua) is a Lua 5.1 dialect

[rules]
mixed_table = "allow"   -- lazy.nvim-style `{ "plugin", key = value }` specs trip this otherwise
```

```yaml
# vim.yml
globals:
  vim:
    any: true
```

Many Neovim plugins export a convenience global alongside their module (e.g. `folke/snacks.nvim` sets
`_G.Snacks`). If `vim.yml` doesn't declare that name, referencing it directly fails lint. Prefer
`require("plugin_name")` over the bare global in config/keymaps — it produces identical behavior and needs no
`vim.yml` change.

There is a second reason to prefer `require`: **lazy.nvim auto-loads a plugin the first time any of its
submodules is `require`d** (its module searcher resolves the module to the owning plugin and loads it on
demand). So a `keys`/`cmd`/`event`-lazy plugin can be safely referenced as `require("plugin.submodule").fn(...)`
from eager code (a keymap callback, a user command, a `close_command` function) — the `require` runs only when
the code fires, and it pulls the plugin in then. This lets you reuse a utility buried in an otherwise-lazy
plugin (e.g. `require("snacks.bufdelete").delete(buf)`) without eager-loading the whole plugin or adding it to
`dependencies`. The bare global (`Snacks.bufdelete`) would be `nil` until something else loads the plugin, so it
does not get this guarantee.

## Luacheck for Neovim

```lua
-- .luacheckrc
std = "lua54+busted"          -- or "luajit+busted"
globals = { "vim" }           -- for Neovim plugins
max_line_length = 120
max_cyclomatic_complexity = 10
```

Same `_G.Snacks`-style global caveat applies (`globals`/`read_globals` in `.luacheckrc`).
