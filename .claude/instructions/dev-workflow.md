# Dev Workflow: Adding Plugins & Testing

## Adding New Plugins

Create a new file under `lua/plugins/`, e.g. `lua/plugins/lsp.lua`, and return a standard lazy.nvim spec table. It will
be picked up automatically on next start.

### Vet the plugin against the actual requirement first

A README feature list is not enough when a requirement is behavioral. Before installing, (1) search the plugin's issue
tracker for the core requirement — a closed issue can be a **wontfix** stating a deliberate design limit
(multicursor.nvim was chosen, shipped, and then replaced because "real-time insert at all cursors" turned out to be
wontfixed in issues #49/#75 — ten minutes of issue reading would have prevented a full plugin swap); (2) check
`pushed_at` for maintenance (vim-visual-multi was rejected partly for ~2 years of inactivity); (3) once installed, read
the plugin's source under `~/.local/share/nvim/lazy/<name>/lua/` instead of guessing at behavior — that's how
AddVisualArea's cursor placement, the `pre_hook`/`post_hook` timing, and `deinit()` semantics were confirmed here.

### Key and mouse bindings must survive the terminal

Neovim never sees what the OS or terminal swallows. On this setup (macOS + Warp + trackpad): Mission Control eats
`<C-Up>`/`<C-Down>`; macOS turns Ctrl+click into a right-click before any app sees it; Warp strips the Ctrl modifier
from mouse reports, so a "Ctrl+click" arrives as bare `<RightMouse>` (see `config.md`'s Mouse/terminal caveat and the
`user-terminal-warp` memory). When a binding "doesn't work" but `:map` shows it registered, diagnose what actually
arrives with `:luafile scripts/debug-keys.lua` before touching the config.

### Fetch with `install`, not `sync`

Fetch the new plugin with:

```sh
task install
# or directly: nvim --headless "+Lazy! install" +qa
```

**Do not run `:Lazy sync`** to fetch a single new plugin. `sync` is `install` + `clean` + `update` — it also bumps every
*already-installed* plugin to the latest commit on its tracked branch, silently expanding `lazy-lock.json` far beyond
the plugin you meant to add. `install` only fetches plugins that are in the spec but missing on disk; it leaves
already-installed plugins untouched.

If the lockfile picked up unintended version bumps (from `sync`, or from any headless Lazy operation — a spurious
`markdown-plus.nvim` bump has appeared after an innocent `install` + `clean` cycle, likely via `checker.enabled`):

```sh
git diff lazy-lock.json                               # see everything that changed
git checkout -- lazy-lock.json                        # back to the committed lockfile
nvim --headless "+Lazy! restore <plugin>" +qa         # re-checkout the bumped plugin(s) to the locked commit
task install                                          # re-record only the genuinely new plugin
```

Prefer this git-checkout + targeted-restore flow over hand-editing commit hashes in `lazy-lock.json` — hand-edits are
error-prone and (for agents) can trip security review, since editing a pinned hash is indistinguishable from pointing a
dependency at unvetted code.

Always `git diff lazy-lock.json` before committing a plugin addition — the diff should contain exactly one new entry (or
the version bump you intended), nothing else.

### Verifying a plugin loads

`:checkhealth <plugin>` can report `No healthcheck found for "<plugin>" plugin` for a `keys`-lazy-loaded plugin that
hasn't been triggered yet in the current session — a discovery quirk, not necessarily a real problem. To check directly
instead:

```sh
nvim --headless -c "lua print(pcall(require, 'plugin_name'))" -c "qa"
```

or call the plugin's health module directly: `require("plugin_name.health").check()`.

## Testing

Tests are run through the tasks in `Taskfile.yml`, not by invoking `busted` directly: `task test` runs the
full pipeline (`test:unit` then `test:integration`), and each is runnable individually. Under the hood, both
tasks wrap two [Busted](https://lunarmodules.github.io/busted/) suites, configured by `.busted` at the
project root:

- **Unit** (`task test:unit` = `busted --run=unit`) — `tests/unit/*_spec.lua`, one spec per `lua/lib/`
  module. Pure Lua, runs under the plain `busted` binary (homebrew Lua, no Neovim). The `package.path`
  preamble in each spec makes `lib.*` importable without Neovim.
- **Integration** (`task test:integration` = `busted --run=integration`) — `tests/integration/*_spec.lua`,
  the config-level contract: leader keys, `:Daily` end-to-end, the `:q`/`:x`/`:wq` abbreviations, global
  keymaps, auto-save, and plugin wiring (multicursor, markdown lint). `busted --run=integration` re-executes
  busted under `scripts/busted-nvim.sh`, an interpreter shim that boots a **fully-loaded headless Neovim**
  (`nvim -u init.lua -l`), so specs assert against the real `vim` API. **Extend these specs when
  adding a user command or global keymap.**

Integration-suite mechanics worth knowing before writing specs:

- `tests/integration/helper.lua` hooks `vim.notify` at session start and exposes the log as a
  module (`require("notify_log")`) — needed because once-per-session guards (e.g. the markdownlint
  missing-binary notification) can fire in whichever spec file first ft-loads the plugin, not the
  one asserting.
- File insulation is off (`["auto-insulate"] = false` in `.busted`): the editor process is shared
  global state, and restoring `package.loaded` between files would detach plugin modules from the
  autocmds that captured them. Clean up buffers in `teardown` instead.
- Files run sorted; tests within a file run in declaration order — some specs assert state their
  file's `setup()` created, so never run this suite with `--shuffle`.
- Never verify async behavior with a blind `vim.wait(ms)` sleep. Latch on a completion signal
  (`DiagnosticChanged`, the `User MarkdownLintRun` sync point from `lint_buf()`,
  `#lint.get_running() == 0`) so the wait returns the moment the work finishes and the timeout is
  only a failure bound — or better, test the synchronous seams directly: linter parsers are pure
  functions, `vim.diagnostic.set` renders immediately, and `vim.system():wait()` blocks on real
  process exit. See `tests/integration/markdown_lint_spec.lua` for all of these in use.

### Install

```sh
brew install luarocks
luarocks install busted                    # unit suite (default homebrew Lua tree)
luarocks --lua-version=5.1 install busted  # integration suite: Neovim's LuaJIT is 5.1-ABI (installs to ~/.luarocks)
brew install selene   # or: cargo install selene
brew install stylua   # or: cargo install stylua
```

Verify: `busted --version`, `selene --version`, and `stylua --version`

`selene` and `stylua` are standalone Rust binaries with no Lua/LuaRocks dependency — unlike a Lua-based linter or
formatter, they can never break due to a local Lua-version mismatch.

Do **not** set `lua = "luajit"` on the *default* `.busted` task — the default rocks tree is not 5.1 and
`busted.runner` won't resolve. The integration task instead points `lua` at `scripts/busted-nvim.sh`,
which wires `LUA_PATH`/`LUA_CPATH` to the `~/.luarocks` 5.1 tree before exec'ing `nvim -l`.

### Run

```sh
task test                 # full pipeline: test:unit then test:integration
task test:unit            # unit tests (tests/unit)
task test:integration     # integration tests inside a fully-loaded headless Neovim (tests/integration)
task lint                 # selene + stylua --check + markdownlint-cli2 + shellcheck (see Taskfile.yml)
task format               # stylua over all Lua + markdownlint-cli2 --fix over all Markdown
scripts/check.sh          # everything CI runs, in CI's order: lint, unit, integration, guard path
```

Lua formatting is StyLua (`stylua.toml`: 2-space indent, 120 columns — matching `textwidth`). It runs three ways:
`task format` from the CLI, format-on-save in the editor via conform.nvim (see `markdown.md`), and as an enforced
`stylua --check` inside `task lint`, so CI fails on formatting drift — run `task format` before committing Lua changes.

A bare `busted --run=unit` / `busted --run=integration` still works directly if `task` isn't
installed — but `task test*` is the documented entry point and what CI and `scripts/check.sh` use.

CI (`.github/workflows/ci.yml`) runs both suites on Ubuntu and macOS as three jobs: `lint` runs
`task lint`; `test` runs `task test:unit`; and `integration-test` installs a pinned Neovim release
binary, a Lua 5.1 busted tree via the same leafo actions (exported to the shim as
`BUSTED_ROCKS_TREE`), markdownlint-cli2, and the locked plugins (`task install` against
a `~/.config/nvim` symlink to the checkout) before running `task test:integration` — plus a
Linux-only rerun of the lint spec through `test-without-binary.sh` so the missing-binary guard path
stays covered.

### Verifying interactive/headless picker behavior

`vim.ui.input()` (and `vim.ui.select()`) are blocking, modal calls — driving them through synthetic
`vim.api.nvim_feedkeys()` in `nvim --headless` is timing-fragile (typed keys can leak into normal-mode commands instead
of reaching the prompt) and is not a reliable test technique. To verify code that sits behind a `vim.ui.input` prompt,
replicate/call the underlying logic directly (e.g. the same `vim.fs.dir` walk + matcher calls used by the fallback in
`lua/plugins/picker.lua`) and hand the result straight to the picker function, bypassing the interactive prompt
entirely.

To exercise an executable-guard fallback (e.g. `<leader>.`'s `rg`-missing path, or `<leader>g`'s `lazygit`-missing path)
without uninstalling the real binary, use `scripts/test-without-binary.sh <binary> -- <command...>`. It builds a
temporary `PATH` containing symlinks to everything except the named binary — safer than naively stripping the binary's
whole directory from `$PATH`, since unrelated tools (including `nvim` itself) often live alongside it (e.g. both under
`/opt/homebrew/bin`).

### Running Lua verification scripts headlessly

Use `scripts/headless-lua.sh <script.lua> [working-dir]` to run a Lua script inside a fully-initialized Neovim. The
pitfalls it exists to avoid:

- **`nvim -l script.lua` does NOT load the user config** — it runs in script mode, lazy.nvim never bootstraps, and
  `require("<any plugin>")` fails with `module not found`. The working invocation is `nvim --headless -c "luafile
  script.lua" -c qa`.
- **`nvim --cd <dir>` is not a real flag** (it errors with "Unknown option argument") — `cd` in the shell first, or use
  `--cmd "cd <dir>"`.
- **Exit codes**: a Lua error inside `-c` does not reliably fail the process. Call `vim.cmd("cquit 1")` from the script
  on assertion failure so CI/shell callers see a non-zero exit.

Patterns that proved reliable for verifying plugin behavior headlessly:

- **User commands and command-line abbreviations**: `vim.api.nvim_get_commands({})` returns a table keyed by command
  name (`cmds.BufClose ~= nil` proves registration); `vim.fn.execute("cabbrev q")` returns the abbreviation listing as a
  string to `:find` the expected RHS in. Both are reliable where feedkeys into `:` is not — this is how
  `config/commands.lua` was verified.
- **A `keys`/`cmd`/`event`-lazy plugin's resolved config**: force it to load first with `require("lazy").load({ plugins
  = { "bufferline.nvim" } })`, then read `require("bufferline.config").options` to assert e.g. `close_command` is the
  function you set. Before the load its `setup()` hasn't run, so the config holds defaults.
- **`event = "VeryLazy"` plugins never load in `--headless`**: lazy.nvim fires `VeryLazy` from a once-only `UIEnter`
  autocmd, and no UI ever attaches in headless mode — so the plugin's `config()` (keymaps, layers, autocmds) never runs
  no matter how long the script waits. `require("lazy").load({ plugins = { "<name>" } })` first, then assert. Related
  hang: a script that leaves a **modified** scratch buffer behind makes a plain `-c qa` block indefinitely (no UI to
  answer the save prompt) — `headless-lua.sh` quits with `qa!` for exactly this reason; keep `vim.bo.modified = false`
  in scripts anyway so they survive hand-rolled runners.
- **Mouse events cannot be simulated in `--headless`**: `nvim_input_mouse()` needs a UI grid to resolve the click, so
  synthesized clicks are silently inert — key-routing through mouse mappings can't be tested headlessly. Autocmd-driven
  input mirroring (e.g. multi-cursor `InsertCharPre` handlers) is likewise unreliable under synthetic `feedkeys` — event
  ordering differs from real typed input, and keys can leak into the wrong mode. Assert the *wiring* (maps, commands)
  and call the underlying Lua functions directly; leave click/typing behavior to interactive verification.
- **Buffer-local keymaps**: focus the plugin window (e.g. `:Neotree focus`), then check `vim.fn.maparg(key, mode, false,
  true)` — `.buffer == 1` proves the mapping registered, `.desc` usually names the plugin command it's bound to. Works
  for visual-mode maps too (`mode = "x"`).
- **Global `<leader>` keymaps**: `maparg()` needs the **literal** leader character in the lhs —
  `vim.fn.maparg(vim.g.mapleader .. "nd", "n")`, not `"<leader>nd"`. And assert against the *expected* leader: a
  `<leader>` map created before `vim.g.mapleader` is set silently binds under the default `\` and `maparg(" nd", ...)`
  returns `""` — exactly how the `<leader>nd` load-order bug was caught (leaders now live in `config/options.lua`, the
  first module `init.lua` loads; never create `<leader>` maps before it).
- **Env-var-driven commands** (e.g. `:Daily` reading `NVIM_NOTES_DIR`): read the variable **at call time** inside the
  command, not at module load — then a headless script can just set `vim.env.NVIM_NOTES_DIR = dir` in-process before
  invoking, no shell wrapper needed. Compare resulting buffer names through `vim.fn.resolve()` — on macOS `tempname()`
  returns `/var/...` while buffer names resolve through the `/var -> /private/var` symlink.
- **`print()` output interleaving**: in headless mode, message lines can visually run together after buffer-switching
  commands (`:edit`, `:enew`). End prints with an explicit `"\n"`, and treat the exit code (`cquit 1`) as the
  authoritative result, not the printed text.
- **Mode transitions** (e.g. "does pressing `v` enter linewise visual?"): `vim.api.nvim_feedkeys(key, "m", false)`
  followed by `vim.api.nvim_feedkeys("", "x", false)` to flush, then assert on `vim.fn.mode()`.
- **Prompt-driven file operations**: don't feedkeys into prompts — stub the plugin's own prompt module and call the
  underlying action functions directly (see `explorer.md`'s "Verifying file operations headlessly"). Lua module caching
  means every internal reference shares the stubbed table.
- **Async plugin fs operations**: plugin file actions (e.g. neo-tree's `fs_actions`) complete via async libuv callbacks.
  Calling two in a row races — the second sees the first's work half-done and fails deep inside the plugin with a
  confusing nil-index error. `vim.wait(2000, cond_fn, 10)` for the expected filesystem state between steps.
