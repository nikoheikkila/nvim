# Lua Patterns Reference

## Contents

- [OOP via Metatables](#oop-via-metatables)
- [Mixins](#mixins)
- [Module Pattern](#module-pattern)
- [Coroutine Pipelines](#coroutine-pipelines)
- [Read-Only Tables](#read-only-tables)
- [Observer Pattern](#observer-pattern)
- [Custom Iterator](#custom-iterator)
- [Neovim Plugin Setup](#neovim-plugin-setup)
- [Error Handling](#error-handling)

## OOP via Metatables

```lua
local Shape = {}
Shape.__index = Shape

function Shape.new(kind)
  return setmetatable({ kind = kind, _area = 0 }, Shape)
end

function Shape:area() return self._area end

function Shape:__tostring()
  return string.format("Shape(%s, area=%.2f)", self.kind, self._area)
end

-- Derived class: Circle
local Circle = setmetatable({}, { __index = Shape })
Circle.__index = Circle

function Circle.new(radius)
  local self = Shape.new("circle")
  self.radius = radius
  self._area = math.pi * radius * radius
  return setmetatable(self, Circle)
end

function Circle:circumference()
  return 2 * math.pi * self.radius
end

local c = Circle.new(5)
print(c:area())           --> 78.54
print(c:circumference())  --> 31.42
print(tostring(c))        --> Shape(circle, area=78.54)
```

## Mixins

```lua
local Serializable = {}

function Serializable:serialize()
  local parts = {}
  for k, v in pairs(self) do
    if type(v) ~= "function" then
      parts[#parts + 1] = string.format("%s=%s", k, tostring(v))
    end
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function apply_mixin(class, mixin)
  for k, v in pairs(mixin) do
    if class[k] == nil then class[k] = v end
  end
end

apply_mixin(Circle, Serializable)
print(Circle.new(3):serialize())
```

## Module Pattern

```lua
-- db.lua: private state, public API
local M = {}

local connections = {}
local MAX_POOL_SIZE = 10

local function create_conn(dsn)
  return { dsn = dsn, alive = true }
end

function M.connect(dsn)
  if #connections >= MAX_POOL_SIZE then
    return nil, "connection pool exhausted"
  end
  local conn = create_conn(dsn)
  connections[#connections + 1] = conn
  return conn
end

function M.close_all()
  for _, c in ipairs(connections) do c.alive = false end
  connections = {}
end

return M
```

## Coroutine Pipelines

```lua
local function source(data)
  return coroutine.wrap(function()
    for _, item in ipairs(data) do coroutine.yield(item) end
  end)
end

local function map(fn, iter)
  return coroutine.wrap(function()
    for item in iter do coroutine.yield(fn(item)) end
  end)
end

local function filter(pred, iter)
  return coroutine.wrap(function()
    for item in iter do
      if pred(item) then coroutine.yield(item) end
    end
  end)
end

local function collect(iter)
  local r = {}
  for item in iter do r[#r + 1] = item end
  return r
end

local nums = source({ 1, 2, 3, 4, 5, 6, 7, 8 })
local evens = filter(function(n) return n % 2 == 0 end, nums)
local doubled = map(function(n) return n * 2 end, evens)
local result = collect(doubled)  --> { 4, 8, 12, 16 }
```

## Read-Only Tables

```lua
local function readonly(tbl)
  return setmetatable({}, {
    __index = tbl,
    __newindex = function(_, key)
      error(string.format("attempt to modify read-only field '%s'", key), 2)
    end,
    __len = function() return #tbl end,
  })
end

local CONFIG = readonly({ db_host = "localhost", db_port = 5432 })
print(CONFIG.db_host)     --> localhost
-- CONFIG.db_host = "x"   --> error: attempt to modify read-only field 'db_host'
```

## Observer Pattern

```lua
local EventEmitter = {}
EventEmitter.__index = EventEmitter

function EventEmitter.new()
  return setmetatable({ _listeners = {} }, EventEmitter)
end

function EventEmitter:on(event, cb)
  self._listeners[event] = self._listeners[event] or {}
  local l = self._listeners[event]
  l[#l + 1] = cb
end

function EventEmitter:emit(event, ...)
  for _, cb in ipairs(self._listeners[event] or {}) do cb(...) end
end

local bus = EventEmitter.new()
bus:on("user:created", function(u) print("Welcome, " .. u.name) end)
bus:emit("user:created", { name = "Alice" })  --> Welcome, Alice
```

## Custom Iterator

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

## Neovim Plugin Setup

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

## Error Handling

Return `nil, err_msg` from functions that can fail (idiomatic two-value return); reserve `error()` for violated
preconditions; use `xpcall` with `debug.traceback` to catch programmer errors with a stack trace.

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
