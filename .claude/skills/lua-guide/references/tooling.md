# Lua Tooling Reference

## Selene (Recommended)

A modern, actively-maintained Lua linter written in Rust (<https://github.com/Kampfkarren/selene>) — a standalone
binary with no Lua VM dependency, so it can never suffer a Lua-version incompatibility the way a Lua-based linter
can. Config is TOML, with English-named lints (not luacheck's numeric codes):

```toml
# selene.toml
std = "lua54"   -- or "lua51"/"luajit" depending on the target runtime

[rules]
```

For a project embedding Lua in a host application, vendor a custom std file declaring the host's injected
globals.

## Luacheck (Legacy)

Luacheck (<https://github.com/mpeterv/luacheck>) is unmaintained since October 2018 (v1.2.0 was the final
release) — prefer Selene above for new projects. If working on a legacy project that still uses it:

```lua
-- .luacheckrc
std = "lua54+busted"          -- or "luajit+busted"
max_line_length = 120
max_cyclomatic_complexity = 10
```

Being written in Lua itself (unlike Selene), luacheck is also vulnerable to Lua-version incompatibilities in its
own runtime — e.g. `luacheck` 1.2.0 crashes on load under Lua 5.5 (`attempt to assign to const variable`), so a
plain `luarocks install luacheck` on a machine whose default Lua targets 5.5 (as Homebrew's does) produces a
binary that cannot run at all.

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
