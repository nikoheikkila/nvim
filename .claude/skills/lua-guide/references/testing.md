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

- **`nvim -l script.lua` does NOT load the user config** *unless `-u` is given* (`:h -l`). Two working
  recipes against the full config: `nvim --headless -c "luafile script.lua" -c qa` (no script argv), or
  `nvim --cmd 'set loadplugins' -u <config>/init.lua -l script.lua [args...]` (argv lands in `_G.arg`;
  `-l` disables plugin loading unless 'loadplugins' is set first).

## Running Busted Inside Neovim (integration tests)

- Busted itself can run inside a fully-loaded headless Neovim: point a `.busted` task's `lua` option at
  a shim that execs `nvim -u init.lua -l` — busted re-executes its bootstrap under the shim, and specs
  get the real `vim` API. See `scripts/busted-nvim.sh` and the `integration` task in `.busted`.
- The rocks tree must be **Lua 5.1** (Neovim's LuaJIT ABI). Two traps, both hit in practice: the default
  homebrew tree (Lua 5.5) has C modules that cannot load into LuaJIT, and luarocks itself cannot parse
  the luarocks.org manifest *under LuaJIT* (luarocks/luarocks#1797) — install with
  `luarocks --lua-version=5.1 install busted` (PUC 5.1 builds are LuaJIT-ABI-compatible).
- **Never verify async behavior with a blind `vim.wait(ms)` sleep.** Prefer, in order: (1) synchronous
  seams — linter parsers are pure functions, `vim.diagnostic.set` renders immediately,
  `vim.system():wait()` blocks on real process exit; (2) `vim.wait` latched on a precise completion
  event (`DiagnosticChanged`, a `User` sync-point autocmd, `#lint.get_running() == 0`) so the timeout is
  only a failure bound; (3) a one-line `User` autocmd emitted from production code is an acceptable seam
  to make an otherwise-unobservable path latchable. Condition-*polled* waits (below) are fine;
  fixed-duration sleeps are not.
- **Force a lazy-loaded plugin to load before asserting on its resolved config.** A plugin gated on
  `event`/`keys`/`cmd` won't have run `setup()` yet in a headless script, so its config module holds defaults
  (or errors). Trigger it first with `require("lazy").load({ plugins = { "plugin.nvim" } })`, then read e.g.
  `require("bufferline.config").options` to assert a `close_command` is the function you set.
- **`nvim --cd <dir>` is not a real CLI flag** ("Unknown option argument") — `cd` in the shell before invoking,
  or pass `--cmd "cd <dir>"`.
- **Signal failures explicitly**: a Lua error inside `-c` does not reliably produce a non-zero exit. Call
  `vim.cmd("cquit 1")` from the script on assertion failure.
- `vim.ui.input()`/`vim.ui.select()` are blocking, modal calls — driving them through synthetic
  `vim.api.nvim_feedkeys()` in `nvim --headless` is timing-fragile (typed keys can leak into normal-mode
  commands instead of reaching the prompt), so don't rely on it as a test technique. Instead, call the logic
  that sits behind the prompt directly and feed its result straight into the next step, bypassing the
  interactive prompt entirely.
- **Stub a plugin's prompt module to e2e-test prompt-driven flows.** Plugins often wrap prompts in their own
  module (e.g. neo-tree's `neo-tree.ui.inputs`). Because Lua caches modules, replacing functions on the required
  table intercepts every internal call site:

  ```lua
  local inputs = require("neo-tree.ui.inputs")
  inputs.input = function(_, _, callback) callback("canned-answer") end
  inputs.confirm = function(_, callback) callback(true) end
  -- now call the plugin's underlying action functions directly
  ```

- **Plugin file operations are usually async** (libuv callbacks). Two sequential calls race — the second sees
  the first half-done and fails deep inside the plugin with a misleading nil-index error. Poll with
  `vim.wait(2000, cond_fn, 10)` for the expected state between steps instead of asserting immediately.
- **Verify buffer-local keymaps** by focusing the plugin's window, then checking
  `vim.fn.maparg(key, mode, false, true)`: `.buffer == 1` proves registration and `.desc` names the bound
  command. Works for visual-mode maps too (`mode = "x"`).
- **Verify global `<leader>` keymaps with the literal leader character** — `maparg()` does not resolve
  `"<leader>"` in the lhs; look up `vim.fn.maparg(vim.g.mapleader .. "nd", "n")`. An empty result for a map you
  know you created usually means the **mapleader load-order trap**: a `<leader>` mapping created before
  `vim.g.mapleader` is set silently binds under the default `\` with no error or warning. Set leader keys in the
  first module your `init.lua` loads, before any mapping and before the plugin manager.
- **Compare buffer names through `vim.fn.resolve()`** when asserting against temp paths — on macOS
  `vim.fn.tempname()` returns `/var/...` while buffer names resolve through the `/var -> /private/var` symlink,
  so a raw string comparison fails spuriously.
- **Don't trust `print()` line separation in headless output** — message lines can visually run together after
  buffer-switching commands (`:edit`, `:enew`). End prints with an explicit `"\n"` and make the exit code
  (`vim.cmd("cquit 1")` on failure) the authoritative result.
- **Verify user commands and command-line abbreviations** without driving the command line:
  `vim.api.nvim_get_commands({})` returns a table keyed by command name (`cmds.MyCmd ~= nil` proves
  registration), and `vim.fn.execute("cabbrev <lhs>")` returns the abbreviation listing as a string to `:find`
  the expected RHS in. Both are reliable where feedkeys into `:` is not.
- **Verify mode transitions** (e.g. a mapping that should enter Visual mode): `vim.api.nvim_feedkeys(key, "m",
  false)` then `vim.api.nvim_feedkeys("", "x", false)` to flush, then assert on `vim.fn.mode()`.
- To simulate a missing external binary without uninstalling it, build a scratch `PATH` containing symlinks to
  every entry of the real `PATH` except the target binary — don't just strip the target's whole directory from
  `$PATH`, since unrelated tools (including `nvim` itself) often live alongside it (e.g. both under
  `/opt/homebrew/bin`).
- **`event = "VeryLazy"` plugins never load in `--headless`.** lazy.nvim fires `VeryLazy` from a once-only
  `UIEnter` autocmd, and no UI ever attaches headlessly — the plugin's `config()` never runs no matter how long
  the script waits (this is stronger than "not yet loaded"). Force it with
  `require("lazy").load({ plugins = { "<name>" } })` before asserting anything it creates.
- **Mouse events cannot be simulated headlessly.** `nvim_input_mouse()` needs a UI grid to resolve the click;
  without an attached UI the synthesized events are silently inert — the cursor doesn't move and mappings don't
  fire, with no error. Key-routing through mouse mappings can't be tested headlessly at all: assert the
  mapping's registration (`maparg().desc`) and call its handler function directly instead.
- **Autocmd-driven input mirroring breaks under synthetic `feedkeys`.** Machinery built on
  `InsertCharPre`/`TextChangedI`/`SafeState` (multi-cursor mirroring, completion) sees a different event
  ordering from a single `feedkeys(..., "x")` flush than from real typed input — keys leak into the wrong mode
  and text lands mangled. Treat such behavior as interactively-verified only; headlessly, call the plugin's Lua
  API and assert on its state.
- **A modified scratch buffer hangs a headless `-c qa` forever** — there's no UI to answer the save prompt, and
  the process just wedges (times out in CI with no output). Quit test runners with `qa!`, and/or end scripts
  with `vim.bo.modified = false` / `:bwipeout!`.
- **Testing `statuscolumn`/`foldexpr`/`foldtext` functions means faking Vim's evaluation context, and not every
  `v:` variable is fakeable.** `v:lnum` is writable from Lua (`vim.api.nvim_set_vvar("lnum", n)`), but `v:virtnum`
  is read-only and raises `Key is read-only` if you try — leave it unset and rely on its default (`0`) rather than
  attempting to set it. When such a test flips a window-local option (e.g. `vim.wo.number`) to exercise a branch,
  restore it in `after_each`, not as the last line of the `it` block — an assertion failure earlier in the block
  skips an inline restore and leaks the changed value into every later spec sharing that window.
- **A registered mapping is not a delivered keypress.** The OS and terminal rewrite or swallow events before
  Neovim sees them (macOS: Ctrl+arrows → Mission Control, Ctrl+click → right-click synthesis; Warp: strips Ctrl
  from mouse reports). `:map <key>` proves registration only — diagnose delivery with a `vim.on_key` logger
  (`vim.fn.keytrans(key)` per event) and design bindings around what actually arrives.
