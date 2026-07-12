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

```lua
local function read_config(path)
  local f, err = io.open(path, "r")
  if not f then return nil, "cannot open config: " .. err end
  local content = f:read("*a")
  f:close()
  return content
end

local ok, result = xpcall(dangerous_operation, debug.traceback)
if not ok then log.error("failed: %s", result) end
```

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

## Key Patterns

### Module Pattern

```lua
local M = {}
local TIMEOUT_MS = 5000

local function validate(data)
  assert(type(data) == "table", "expected table, got " .. type(data))
  assert(data.name, "missing required field: name")
end

function M.process(data)
  validate(data)
  return { status = "ok", name = data.name }
end

return M
```

### OOP via Metatables

```lua
local Animal = {}
Animal.__index = Animal

function Animal.new(name, sound)
  return setmetatable({ name = name, sound = sound }, Animal)
end

function Animal:speak()
  return string.format("%s says %s", self.name, self.sound)
end

-- Inheritance
local Dog = setmetatable({}, { __index = Animal })
Dog.__index = Dog

function Dog.new(name)
  return setmetatable(Animal.new(name, "woof"), Dog)
end

function Dog:fetch(item)
  return string.format("%s fetches the %s", self.name, item)
end
```

### Coroutines

```lua
local function producer(items)
  return coroutine.wrap(function()
    for _, item in ipairs(items) do
      coroutine.yield(item)
    end
  end)
end

local function filter(predicate, iter)
  return coroutine.wrap(function()
    for item in iter do
      if predicate(item) then coroutine.yield(item) end
    end
  end)
end

local nums = producer({ 1, 2, 3, 4, 5, 6 })
local evens = filter(function(n) return n % 2 == 0 end, nums)
for v in evens do print(v) end  --> 2, 4, 6
```

### Custom Iterator

```lua
local function range(start, stop, step)
  step = step or 1
  local i = start - step
  return function()
    i = i + step
    if i <= stop then return i end
  end
end

for n in range(1, 10, 2) do print(n) end  --> 1, 3, 5, 7, 9
```

### Neovim Lua API

```lua
local api, keymap = vim.api, vim.keymap
local M = {}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", { enabled = true, width = 80 }, opts or {})
  if not opts.enabled then return end

  local group = api.nvim_create_augroup("MyPlugin", { clear = true })
  api.nvim_create_autocmd("BufWritePre", {
    group = group, pattern = "*.lua",
    callback = function(ev)
      local lines = api.nvim_buf_get_lines(ev.buf, 0, -1, false)
      for i, line in ipairs(lines) do lines[i] = line:gsub("%s+$", "") end
      api.nvim_buf_set_lines(ev.buf, 0, -1, false, lines)
    end,
  })

  keymap.set("n", "<leader>mp", function()
    vim.notify("MyPlugin activated", vim.log.levels.INFO)
  end, { desc = "Activate MyPlugin" })
end

return M
```

## Testing

### Busted (Recommended)

```lua
local mymodule = require("mymodule")

describe("mymodule.process", function()
  it("returns ok for valid input", function()
    local result = mymodule.process({ name = "test" })
    assert.are.equal("ok", result.status)
  end)

  it("raises on missing name", function()
    assert.has_error(function() mymodule.process({}) end, "missing required field: name")
  end)
end)
```

### Testing Standards

- Test files: `spec/*_spec.lua` (busted) or `test_*.lua` (luaunit)
- Test names describe behavior: `it("returns nil when file not found")`
- Coverage: >80% for library modules, >60% overall
- Test edge cases: `nil`, empty tables, boundary values, type mismatches
- Run: `busted --verbose`

### Headless Neovim Verification

- **`nvim -l script.lua` does NOT load the user config** — it runs in script mode, so the plugin manager never bootstraps and `require("<plugin>")` fails with `module not found`. To run a script against the full config, use `nvim --headless -c "luafile script.lua" -c qa` instead.
- **`nvim --cd <dir>` is not a real CLI flag** ("Unknown option argument") — `cd` in the shell before invoking, or pass `--cmd "cd <dir>"`.
- **Signal failures explicitly**: a Lua error inside `-c` does not reliably produce a non-zero exit. Call `vim.cmd("cquit 1")` from the script on assertion failure.
- `vim.ui.input()`/`vim.ui.select()` are blocking, modal calls — driving them through synthetic `vim.api.nvim_feedkeys()` in `nvim --headless` is timing-fragile (typed keys can leak into normal-mode commands instead of reaching the prompt), so don't rely on it as a test technique. Instead, call the logic that sits behind the prompt directly and feed its result straight into the next step, bypassing the interactive prompt entirely.
- **Stub a plugin's prompt module to e2e-test prompt-driven flows.** Plugins often wrap prompts in their own module (e.g. neo-tree's `neo-tree.ui.inputs`). Because Lua caches modules, replacing functions on the required table intercepts every internal call site:

  ```lua
  local inputs = require("neo-tree.ui.inputs")
  inputs.input = function(_, _, callback) callback("canned-answer") end
  inputs.confirm = function(_, callback) callback(true) end
  -- now call the plugin's underlying action functions directly
  ```

- **Plugin file operations are usually async** (libuv callbacks). Two sequential calls race — the second sees the first half-done and fails deep inside the plugin with a misleading nil-index error. Poll with `vim.wait(2000, cond_fn, 10)` for the expected state between steps instead of asserting immediately.
- **Verify buffer-local keymaps** by focusing the plugin's window, then checking `vim.fn.maparg(key, mode, false, true)`: `.buffer == 1` proves registration and `.desc` names the bound command. Works for visual-mode maps too (`mode = "x"`).
- **Verify mode transitions** (e.g. a mapping that should enter Visual mode): `vim.api.nvim_feedkeys(key, "m", false)` then `vim.api.nvim_feedkeys("", "x", false)` to flush, then assert on `vim.fn.mode()`.
- To simulate a missing external binary without uninstalling it, build a scratch `PATH` containing symlinks to every entry of the real `PATH` except the target binary — don't just strip the target's whole directory from `$PATH`, since unrelated tools (including `nvim` itself) often live alongside it (e.g. both under `/opt/homebrew/bin`).

## Tooling

### Selene (Recommended)

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

### Luacheck (Legacy)

Luacheck (https://github.com/mpeterv/luacheck) is unmaintained since October 2018 (v1.2.0 was the final release) — prefer Selene above for new projects. If working on a legacy project that still uses it:

```lua
-- .luacheckrc
std = "lua54+busted"          -- or "luajit+busted"
globals = { "vim" }           -- for Neovim plugins
max_line_length = 120
max_cyclomatic_complexity = 10
```

Same `_G.Snacks`-style global caveat applies (`globals`/`read_globals` in `.luacheckrc`). Being written in Lua itself (unlike Selene), luacheck is also vulnerable to Lua-version incompatibilities in its own runtime — e.g. `luacheck` 1.2.0 crashes on load under Lua 5.5 (`attempt to assign to const variable`), so a plain `luarocks install luacheck` on a machine whose default Lua targets 5.5 (as Homebrew's does) produces a binary that cannot run at all.

### StyLua

```toml
# stylua.toml
column_width = 100
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

### Essential Commands

```bash
lua myfile.lua                # Run Lua script
luajit myfile.lua             # Run with LuaJIT
busted --verbose              # Run tests
selene .                      # Lint
stylua .                      # Format
luarocks install busted       # Install test framework
brew install selene           # Install linter (or: cargo install selene)
```

## References

For detailed patterns and examples, see:

- [references/patterns.md](references/patterns.md) -- OOP via metatables, module patterns, coroutine pipelines

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
