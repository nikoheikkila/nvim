# Dev Workflow: Adding Plugins & Testing

## Adding New Plugins

Create a new file under `lua/plugins/`, e.g. `lua/plugins/lsp.lua`, and return a standard lazy.nvim spec table. It will be picked up automatically on next start.

### Fetch with `install`, not `sync`

Fetch the new plugin with:

```sh
scripts/lazy-install.sh
# or directly: nvim --headless "+Lazy! install" +qa
```

**Do not run `:Lazy sync`** to fetch a single new plugin. `sync` is `install` + `clean` + `update` — it also bumps every *already-installed* plugin to the latest commit on its tracked branch, silently expanding `lazy-lock.json` far beyond the plugin you meant to add. `install` only fetches plugins that are in the spec but missing on disk; it leaves already-installed plugins untouched.

If `sync` was already run by mistake:

```sh
git diff lazy-lock.json                              # see everything that changed
# hand-revert any entries you didn't intend to touch, then:
nvim --headless "+Lazy! restore" +qa                  # re-checkout plugin dirs to match the lockfile
```

Always `git diff lazy-lock.json` before committing a plugin addition — the diff should contain exactly one new entry (or the version bump you intended), nothing else.

### Verifying a plugin loads

`:checkhealth <plugin>` can report `No healthcheck found for "<plugin>" plugin` for a `keys`-lazy-loaded plugin that hasn't been triggered yet in the current session — a discovery quirk, not necessarily a real problem. To check directly instead:

```sh
nvim --headless -c "lua print(pcall(require, 'plugin_name'))" -c "qa"
```

or call the plugin's health module directly: `require("plugin_name.health").check()`.

## Testing

Tests live in `tests/markdown_utils_spec.lua` and `tests/search_utils_spec.lua`, and use [Busted](https://lunarmodules.github.io/busted/) with Lua 5.5.

### Install

```sh
brew install luarocks
luarocks install busted
brew install selene   # or: cargo install selene
```

Verify: `busted --version` and `selene --version`

`selene` is a standalone Rust binary with no Lua/LuaRocks dependency — unlike a Lua-based linter, it can never break due to a local Lua-version mismatch.

### Run

```sh
busted
scripts/lint.sh   # or: selene lua/
```

Reads `.busted` at the project root (`ROOT = { "tests" }`). The `package.path` preamble in the spec file makes `lib.markdown_utils` importable without Neovim. `selene lua/` is the same command CI runs (`.github/workflows/ci.yml`).

### Verifying interactive/headless picker behavior

`vim.ui.input()` (and `vim.ui.select()`) are blocking, modal calls — driving them through synthetic `vim.api.nvim_feedkeys()` in `nvim --headless` is timing-fragile (typed keys can leak into normal-mode commands instead of reaching the prompt) and is not a reliable test technique. To verify code that sits behind a `vim.ui.input` prompt, replicate/call the underlying logic directly (e.g. the same `vim.fs.dir` walk + matcher calls used by the fallback in `lua/plugins/picker.lua`) and hand the result straight to the picker function, bypassing the interactive prompt entirely.

To exercise an executable-guard fallback (e.g. `<leader>.`'s `rg`-missing path, or `<leader>g`'s `lazygit`-missing path) without uninstalling the real binary, use `scripts/test-without-binary.sh <binary> -- <command...>`. It builds a temporary `PATH` containing symlinks to everything except the named binary — safer than naively stripping the binary's whole directory from `$PATH`, since unrelated tools (including `nvim` itself) often live alongside it (e.g. both under `/opt/homebrew/bin`).

### Running Lua verification scripts headlessly

Use `scripts/headless-lua.sh <script.lua> [working-dir]` to run a Lua script inside a fully-initialized Neovim. The pitfalls it exists to avoid:

- **`nvim -l script.lua` does NOT load the user config** — it runs in script mode, lazy.nvim never bootstraps, and `require("<any plugin>")` fails with `module not found`. The working invocation is `nvim --headless -c "luafile script.lua" -c qa`.
- **`nvim --cd <dir>` is not a real flag** (it errors with "Unknown option argument") — `cd` in the shell first, or use `--cmd "cd <dir>"`.
- **Exit codes**: a Lua error inside `-c` does not reliably fail the process. Call `vim.cmd("cquit 1")` from the script on assertion failure so CI/shell callers see a non-zero exit.

Patterns that proved reliable for verifying plugin behavior headlessly:

- **User commands and command-line abbreviations**: `vim.api.nvim_get_commands({})` returns a table keyed by command name (`cmds.BufClose ~= nil` proves registration); `vim.fn.execute("cabbrev q")` returns the abbreviation listing as a string to `:find` the expected RHS in. Both are reliable where feedkeys into `:` is not — this is how `config/commands.lua` was verified.
- **A `keys`/`cmd`/`event`-lazy plugin's resolved config**: force it to load first with `require("lazy").load({ plugins = { "bufferline.nvim" } })`, then read `require("bufferline.config").options` to assert e.g. `close_command` is the function you set. Before the load its `setup()` hasn't run, so the config holds defaults.
- **Buffer-local keymaps**: focus the plugin window (e.g. `:Neotree focus`), then check `vim.fn.maparg(key, mode, false, true)` — `.buffer == 1` proves the mapping registered, `.desc` usually names the plugin command it's bound to. Works for visual-mode maps too (`mode = "x"`).
- **Mode transitions** (e.g. "does pressing `v` enter linewise visual?"): `vim.api.nvim_feedkeys(key, "m", false)` followed by `vim.api.nvim_feedkeys("", "x", false)` to flush, then assert on `vim.fn.mode()`.
- **Prompt-driven file operations**: don't feedkeys into prompts — stub the plugin's own prompt module and call the underlying action functions directly (see `explorer.md`'s "Verifying file operations headlessly"). Lua module caching means every internal reference shares the stubbed table.
- **Async plugin fs operations**: plugin file actions (e.g. neo-tree's `fs_actions`) complete via async libuv callbacks. Calling two in a row races — the second sees the first's work half-done and fails deep inside the plugin with a confusing nil-index error. `vim.wait(2000, cond_fn, 10)` for the expected filesystem state between steps.
