---
name: lua-guide
description: |
  Lua language guardrails, patterns, and best practices for AI-assisted development.
  Use when working with Lua files (.lua), or when the user mentions Lua/LuaJIT/Neovim/Love2D.
  Provides table patterns, metatable guidelines, coroutine usage,
  and embedding conventions specific to this project's coding standards.
license: MIT
metadata:
  author: samuel
  version: "1.0"
  category: language
  language: lua
  extensions: ".lua"
---

# Lua Guide

> Applies to: Lua 5.4+, LuaJIT 2.1, Neovim Plugins, Love2D, Embedded Scripting

## Core Principles

1. **Tables Are Everything**: Arrays, maps, objects, modules, and namespaces -- master them
2. **Local by Default**: Always declare variables `local`; globals are a performance and correctness hazard
3. **Explicit Error Handling**: Use `pcall`/`xpcall` for recoverable errors; `error()` for programmer mistakes
4. **Minimal Metatables**: Use metatables for genuine OOP needs, not as decoration on simple data
5. **Embed-Friendly Design**: Lua exists to be embedded; keep the host/script boundary clean and narrow

## Guardrails

### Code Style

- Use `local` for every variable and function unless it must be global
- Naming: `snake_case` for variables/functions, `PascalCase` for class-like tables, `UPPER_SNAKE_CASE` for constants
- Indent with 2 spaces; one statement per line; avoid semicolons
- Use `[[ ... ]]` long strings for multi-line text and SQL/HTML templates
- Prefer `#tbl` over `table.getn()` for sequence length

### Tables

- Arrays are 1-based; `for i = 1, #arr` not `for i = 0, #arr - 1`
- Use `ipairs` for sequential iteration, `pairs` for hash-map iteration
- Do not mix array indices and string keys in the same table (undefined `#` behavior)
- Use `table.insert` / `table.remove` for array ops; avoid manual index gaps
- Freeze config tables by setting a `__newindex` metamethod that errors

### Error Handling

- Use `pcall(fn, ...)` to catch errors; `xpcall(fn, handler, ...)` for tracebacks
- Return `nil, err_msg` from functions that can fail (idiomatic two-value return)
- Reserve `error("msg", level)` for violated preconditions (programmer errors)
- Never silently swallow errors; always log or propagate
- Example: [references/patterns.md#error-handling](references/patterns.md#error-handling)

### Performance

- Localize hot functions: `local insert = table.insert`
- Avoid closures inside hot loops (allocates every iteration)
- Use `table.concat` instead of `..` concatenation in loops
- LuaJIT: avoid `pairs()` in hot paths (not JIT-compiled); prefer arrays with `ipairs`
- LuaJIT: use FFI (`ffi.new`, `ffi.cast`) for C struct access instead of Lua tables

### Embedding

- Keep the Lua-to-host API surface small (<20 registered functions)
- Validate all arguments from Lua in C/host bindings
- Set memory limits via `lua_setallocf` or `lua_gc` configuration
- Use `debug.sethook` instruction-count hooks for untrusted scripts

## References

- [references/patterns.md](references/patterns.md) — OOP/metatables, mixins, modules, coroutines, custom
  iterators, Neovim plugin setup, error handling
- [references/testing.md](references/testing.md) — Busted patterns, testing standards, headless Neovim verification techniques
- [references/tooling.md](references/tooling.md) — Selene, Luacheck (legacy), StyLua, essential CLI commands

## External References

- [Lua 5.4 Reference Manual](https://www.lua.org/manual/5.4/)
- [Programming in Lua (4th ed)](https://www.lua.org/pil/)
- [LuaJIT Documentation](https://luajit.org/luajit.html)
- [LuaJIT FFI Tutorial](https://luajit.org/ext_ffi_tutorial.html)
- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [Busted Testing Framework](https://lunarmodules.github.io/busted/)
- [Selene Linter](https://github.com/Kampfkarren/selene)
- [Luacheck Linter](https://github.com/mpeterv/luacheck) (legacy/unmaintained since 2018)
- [StyLua Formatter](https://github.com/JohnnyMorganz/StyLua)
- [Love2D Wiki](https://love2d.org/wiki/Main_Page)
- [Lua Style Guide](https://github.com/Olivine-Labs/lua-style-guide)
