# Lua Testing Reference

## Busted (Recommended)

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

## Testing Standards

- Test files: `spec/*_spec.lua` (busted) or `test_*.lua` (luaunit)
- Test names describe behavior: `it("returns nil when file not found")`
- Coverage: >80% for library modules, >60% overall
- Test edge cases: `nil`, empty tables, boundary values, type mismatches
- Run: `busted --verbose`

## Headless Neovim Verification

- **`nvim -l script.lua` does NOT load the user config** — it runs in script mode, so the plugin manager never bootstraps and `require("<plugin>")` fails with `module not found`. To run a script against the full config, use `nvim --headless -c "luafile script.lua" -c qa` instead.
- **Force a lazy-loaded plugin to load before asserting on its resolved config.** A plugin gated on `event`/`keys`/`cmd` won't have run `setup()` yet in a headless script, so its config module holds defaults (or errors). Trigger it first with `require("lazy").load({ plugins = { "plugin.nvim" } })`, then read e.g. `require("bufferline.config").options` to assert a `close_command` is the function you set.
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
- **Verify user commands and command-line abbreviations** without driving the command line: `vim.api.nvim_get_commands({})` returns a table keyed by command name (`cmds.MyCmd ~= nil` proves registration), and `vim.fn.execute("cabbrev <lhs>")` returns the abbreviation listing as a string to `:find` the expected RHS in. Both are reliable where feedkeys into `:` is not.
- **Verify mode transitions** (e.g. a mapping that should enter Visual mode): `vim.api.nvim_feedkeys(key, "m", false)` then `vim.api.nvim_feedkeys("", "x", false)` to flush, then assert on `vim.fn.mode()`.
- To simulate a missing external binary without uninstalling it, build a scratch `PATH` containing symlinks to every entry of the real `PATH` except the target binary — don't just strip the target's whole directory from `$PATH`, since unrelated tools (including `nvim` itself) often live alongside it (e.g. both under `/opt/homebrew/bin`).
