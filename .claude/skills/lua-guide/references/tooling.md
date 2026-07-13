# Lua Tooling Reference

## Selene (Recommended)

A modern, actively-maintained Lua linter written in Rust (https://github.com/Kampfkarren/selene) — a standalone binary with no Lua VM dependency, so it can never suffer a Lua-version incompatibility the way a Lua-based linter can. Config is TOML, with English-named lints (not luacheck's numeric codes):

```toml
# selene.toml
std = "lua51+vim"   -- LuaJIT (Neovim's embedded Lua) is a Lua 5.1 dialect

[rules]
mixed_table = "allow"   -- lazy.nvim-style `{ "plugin", key = value }` specs trip this otherwise
```

Selene ships **no built-in Neovim/`vim` standard library** — only `lua51`/`lua52`/`lua53`/`lua54`/`roblox` are built in. For Neovim plugin/config code, vendor a small custom std file named `vim.yml` next to `selene.toml` (the modern YAML std format; TOML std files are the legacy format):

```yaml
# vim.yml
globals:
  vim:
    any: true
```

Many Neovim plugins export a convenience global alongside their module (e.g. `folke/snacks.nvim` sets `_G.Snacks`). If `vim.yml` doesn't declare that name, referencing it directly fails lint. Prefer `require("plugin_name")` over the bare global in config/keymaps — it produces identical behavior and needs no `vim.yml` change.

There is a second reason to prefer `require`: **lazy.nvim auto-loads a plugin the first time any of its submodules is `require`d** (its module searcher resolves the module to the owning plugin and loads it on demand). So a `keys`/`cmd`/`event`-lazy plugin can be safely referenced as `require("plugin.submodule").fn(...)` from eager code (a keymap callback, a user command, a `close_command` function) — the `require` runs only when the code fires, and it pulls the plugin in then. This lets you reuse a utility buried in an otherwise-lazy plugin (e.g. `require("snacks.bufdelete").delete(buf)`) without eager-loading the whole plugin or adding it to `dependencies`. The bare global (`Snacks.bufdelete`) would be `nil` until something else loads the plugin, so it does not get this guarantee.

## Luacheck (Legacy)

Luacheck (https://github.com/mpeterv/luacheck) is unmaintained since October 2018 (v1.2.0 was the final release) — prefer Selene above for new projects. If working on a legacy project that still uses it:

```lua
-- .luacheckrc
std = "lua54+busted"          -- or "luajit+busted"
globals = { "vim" }           -- for Neovim plugins
max_line_length = 120
max_cyclomatic_complexity = 10
```

Same `_G.Snacks`-style global caveat applies (`globals`/`read_globals` in `.luacheckrc`). Being written in Lua itself (unlike Selene), luacheck is also vulnerable to Lua-version incompatibilities in its own runtime — e.g. `luacheck` 1.2.0 crashes on load under Lua 5.5 (`attempt to assign to const variable`), so a plain `luarocks install luacheck` on a machine whose default Lua targets 5.5 (as Homebrew's does) produces a binary that cannot run at all.

## StyLua

```toml
# stylua.toml
column_width = 100
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

## Essential Commands

```bash
lua myfile.lua                # Run Lua script
luajit myfile.lua             # Run with LuaJIT
busted --verbose              # Run tests
selene .                      # Lint
stylua .                      # Format
luarocks install busted       # Install test framework
brew install selene           # Install linter (or: cargo install selene)
```
