# Contributing

💚 Thanks for your interest in improving my Neovim configuration!

This document covers everything you need to
get a working development environment, make a change, and land it: tooling, tests, style rules, git hooks, and
how CI and releases work.

Bug reports and feature ideas are welcome as [issues](https://github.com/nikoheikkila/nvim/issues). Submit code and
documentation changes as pull requests against `main`.

## Prerequisites

| Tool                                                        | Purpose                                                       |
| ----------------------------------------------------------- | ------------------------------------------------------------- |
| Neovim ≥ 0.12.4                                             | The editor itself; integration tests run inside it            |
| [Task](https://taskfile.dev/)                               | Task runner — all lint/format/test commands go through it     |
| [lefthook](https://github.com/evilmartians/lefthook)        | Git hooks (installed automatically by `task install`)         |
| LuaRocks + [Busted](https://lunarmodules.github.io/busted/) | Test framework for both suites                                |
| [selene](https://github.com/Kampfkarren/selene)             | Lua linter                                                    |
| [StyLua](https://github.com/JohnnyMorganz/StyLua)           | Lua formatter (checked in CI — formatting drift fails `lint`) |
| shellcheck                                                  | Shell-script linter                                           |
| `markdownlint-cli2`                                         | Markdown linter (also used by the live-linting feature)       |
| `prettier`                                                  | Markdown formatter (format-on-save inside the editor)         |

On macOS with Homebrew:

```sh
brew install \
    go-task \
    lefthook \
    luarocks \
    selene \
    stylua \
    shellcheck \
    markdownlint-cli2 \
    prettier

luarocks install busted                    # unit suite (default Homebrew Lua tree)
luarocks --lua-version=5.1 install busted  # integration suite (installs to ~/.luarocks)
```

Busted is installed **twice** on purpose: the unit suite runs under your regular Lua, while the integration
suite runs inside Neovim, whose LuaJIT speaks the Lua 5.1 ABI, so it needs a 5.1 rocks tree.

If you have suggestions on how to work around this, please share!

`selene` and `stylua` are standalone Rust binaries with no Lua dependency, so they never break on a local
Lua-version mismatch.

## Getting Started

1. Fork and clone the repository as your Neovim configuration directory (the integration suite loads the real
   config, so `stdpath("config")` must resolve to your checkout):

   ```sh
   mv ~/.config/nvim ~/.config/nvim.bak   # back up any existing config
   git clone git@github.com:<you>/nvim.git ~/.config/nvim
   cd ~/.config/nvim
   ```

2. Install the plugins pinned by `lazy-lock.json` — this also installs the git hooks via lefthook:

   ```sh
   task install
   ```

3. Verify your environment by running everything CI runs:

   ```sh
   scripts/check.sh
   ```

Run `task -a` at any time to list all available tasks.

## Project Layout

Contributions done via Claude Code are welcome, too. I kindly ask you to self-review the pull requests because AI slop
will be mercilessly rejected.

The annotated directory tree lives in [`AGENTS.md`](AGENTS.md), and detailed per-area guidance (config,
markdown, plugins, LSP, explorer, dev workflow) lives under
[`.claude/instructions/`](.claude/instructions/). Have your Claude Code read the relevant file before touching that area.
User-facing documentation lives under [`docs/`](docs/) and ships with each release.

## Development Workflow

| Command                 | What it does                                                     |
| ----------------------- | ---------------------------------------------------------------- |
| `task lint`             | selene + `stylua --check` + markdownlint-cli2 + shellcheck       |
| `task format`           | StyLua + `markdownlint-cli2 --fix`                               |
| `task test`             | Both test suites (unit, then integration)                        |
| `task test:unit`        | Pure-Lua specs for `lua/lib/` (no Neovim involved)               |
| `task test:integration` | Specs running inside a fully-loaded headless Neovim              |
| `task install`          | Fetch plugins to match `lazy-lock.json` + install git hooks      |
| `scripts/check.sh`      | Everything CI runs, in CI's order — green here means green in CI |

Pass arguments to a task after `--`, e.g. run a single spec file:

```sh
task test:integration -- tests/integration/commands_spec.lua
```

### Git Hooks

lefthook installs two hooks (configured in `lefthook.yml`):

- **pre-commit** — runs `task format` (auto-fixes are re-staged) and `task lint`
- **pre-push** — runs both test suites

If a hook blocks you unexpectedly, fix the underlying issue rather than bypassing the hook. CI pipeline runs the same
checks so you won't save time there.

## Coding Style

- **Lua** — formatted by StyLua (`stylua.toml`: 2-space indent, 120 columns) and linted by selene
  (`selene.toml`, `std = "busted+lua51+vim"`). CI runs `stylua --check`, so run `task format` before
  committing Lua changes.
- **Markdown** — linted by markdownlint-cli2 (`.markdownlint.jsonc`; MD013 line length is 120, tables exempt).
  Inside the editor, prettier reformats Markdown on save.
- **Shell** — every `*.sh` must pass shellcheck.

## Testing

Tests are run through the Taskfile tasks — **never** invoke `busted` directly. There are two suites,
configured by `.busted` at the project root:

- **Unit** (`tests/unit/`) — one spec per `lua/lib/` module. Pure Lua, no Neovim. New pure logic belongs in
  `lua/lib/` with a matching spec here.
- **Integration** (`tests/integration/`) — the config-level contract: leader keys, user commands, global
  keymaps, auto-save, and plugin wiring. `scripts/busted-nvim.sh` boots a fully-loaded headless Neovim so
  specs assert against the real `vim` API. **Extend these specs whenever you add a user command or a global
  keymap.**

Rules to know before writing integration specs (details and rationale in
[`dev-workflow.md`](.claude/instructions/dev-workflow.md)):

- The editor process is shared state across spec files (`auto-insulate` is off) — clean up buffers in
  `teardown`, and never run the suite with `--shuffle`.
- Never verify async behavior with a blind `vim.wait(ms)` sleep. Latch on a completion signal (an autocmd, a
  `User` event, a queue-empty predicate) so the timeout is only a failure bound — or test the synchronous
  seams directly. See `tests/integration/markdown_lint_spec.lua` for examples.
- To exercise a missing-binary fallback without uninstalling anything, use
  `scripts/test-without-binary.sh <binary> -- <command...>` — CI covers the markdownlint guard path this way.
- `vim.notify` calls are recorded from session start by `tests/integration/helper.lua` and exposed via
  `require("notify_log")` — use it to assert one-time warnings regardless of which spec triggered them.

For ad-hoc verification of plugin behavior, use `scripts/headless-lua.sh <script.lua>` — plain `nvim -l`
skips the user config entirely and is the most common source of false "module not found" confusion.

## Adding or Updating Plugins

- A new file under `lua/plugins/` returning a lazy.nvim spec table is picked up automatically — no registration
  step. Before adding one, vet the plugin: search its issue tracker for your core requirement (a closed
  **wontfix** is a deliberate design limit), and check that it is still maintained.
- Fetch newly added plugins with `task install`, which silently bumps every installed
  plugin. Update deliberately with `task update` (or `:Lazy update`) and commit the resulting
  `lazy-lock.json` so the working set stays pinned.
- Before adding any global keymap, check the Global Keymap Registry in
  [`config.md`](.claude/instructions/config.md) — seven files declare keys and that table is the only index.
  Bindings must also survive the terminal (see the mouse/terminal caveat there); diagnose dead bindings with
  `:luafile scripts/debug-keys.lua`.

## Commits and Pull Requests

- Follow [Conventional Commits](https://www.conventionalcommits.org/)
- Keep commits focused: include the `lazy-lock.json` change in the same commit as the plugin change that
  caused it.
- Open pull requests against `main`. CI must be green: lint (Ubuntu) plus unit and integration suites on both
  Ubuntu and macOS, including a rerun of the lint spec with `markdownlint-cli2` hidden.
- Every green push to `main` automatically publishes a GitHub release, tagged with CalVer (`YYYY.MM.DD`, with
  a same-day counter suffix). The artifact contains everything except the paths listed in `.nvimignore` —
  development files (tests, scripts, Taskfile, this document) are excluded; user docs under `docs/` ship.

## Health Check

After changing plugin configuration, verify the wiring inside Neovim:

```text
:checkhealth markdown-plus
:checkhealth render-markdown
:checkhealth conform
:checkhealth lint
:checkhealth vim.lsp
:checkhealth mason
```

Note that `:checkhealth <plugin>` can report "No healthcheck found" for a lazy-loaded plugin that has not been
triggered yet in the session — force it to load first with `require("lazy").load({ plugins = { "<name>" } })`.
