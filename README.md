# Neovim Configuration

A minimal Neovim setup built around a comprehensive Markdown editing experience.
Includes a full agentic harness for using with Claude Code.

## Requirements

| Requirement                                                                                       | Notes                                                   |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| Neovim ≥ 0.11                                                                                     | Required by nvim-treesitter (main) and the LSP client   |
| Git                                                                                               | Used by lazy.nvim to clone and update plugins           |
| A [Nerd Font](https://www.nerdfonts.com/)                                                         | Used by render-markdown.nvim for heading and list icons |
| `prettier`                                                                                        | Optional — needed for auto-format on save               |
| `markdownlint-cli2`                                                                               | Optional — needed for live Markdown linting             |
| A terminal with the [Kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/) | Optional — needed for `Ctrl+Shift+I` (insert image)     |

Compatible terminals for `Ctrl+Shift+I`: kitty, WezTerm, Ghostty, foot.

## Installation

1. **Back up any existing config**

   ```sh
   mv ~/.config/nvim ~/.config/nvim.bak
   ```

2. **Clone this configuration**

   ```sh
   git clone <repo-url> ~/.config/nvim
   ```

3. **Start Neovim** — lazy.nvim bootstraps itself on first launch and installs all plugins automatically:

   ```sh
   nvim
   ```

4. **Install `prettier`** (optional, for auto-formatting on save):

   ```sh
   # via npm
   npm install -g prettier

   # via Homebrew
   brew install prettier
   ```

5. **Install `markdownlint-cli2`** (optional, for live linting while writing):

   ```sh
   # via npm
   npm install -g markdownlint-cli2

   # via Homebrew
   brew install markdownlint-cli2
   ```

## Plugins

| Plugin                                                                                                    | Purpose                                                                             |
| --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [yousefhadder/markdown-plus.nvim](https://github.com/yousefhadder/markdown-plus.nvim)                     | Core Markdown editing: bold, italic, links, images, checklists, list management     |
| [MeanderingProgrammer/render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | In-buffer rendering of headings, code blocks, tables, and checkboxes                |
| [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim)                                         | Auto-format on save via `prettier`                                                  |
| [mfussenegger/nvim-lint](https://github.com/mfussenegger/nvim-lint)                                       | Live Markdown linting via `markdownlint-cli2`                                       |
| [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)                             | File tree sidebar with mouse support and bulk file operations                       |
| [folke/snacks.nvim](https://github.com/folke/snacks.nvim)                                                 | Fuzzy file picker and project-wide text search (picker module only)                 |
| [kdheepak/lazygit.nvim](https://github.com/kdheepak/lazygit.nvim)                                         | Lazygit in a floating window                                                        |
| [akinsho/bufferline.nvim](https://github.com/akinsho/bufferline.nvim)                                     | Buffer tabs at the top                                                              |
| [nvim-lualine/lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)                                 | Status line                                                                         |
| [folke/zen-mode.nvim](https://github.com/folke/zen-mode.nvim)                                             | Distraction-free writing mode                                                       |
| [brenton-leighton/multiple-cursors.nvim](https://github.com/brenton-leighton/multiple-cursors.nvim)       | Multiple cursors with real-time editing (see [Multiple Cursors](#multiple-cursors)) |
| [projekt0n/github-nvim-theme](https://github.com/projekt0n/github-nvim-theme)                             | Colorscheme (GitHub Dark)                                                           |
| [neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)                                         | Base configurations for language servers                                            |
| [mason-org/mason.nvim](https://github.com/mason-org/mason.nvim)                                           | Automatic language-server installation                                              |
| [mason-org/mason-lspconfig.nvim](https://github.com/mason-org/mason-lspconfig.nvim)                       | Bridges mason and lspconfig; auto-enables installed servers                         |
| [saghen/blink.cmp](https://github.com/saghen/blink.cmp)                                                   | Auto-completion (see [Code Intelligence](#code-intelligence-lsp))                   |

All plugins are managed by [folke/lazy.nvim](https://github.com/folke/lazy.nvim), which bootstraps itself automatically.

## General Shortcuts

The leader key is `Space`.

| Key                               | Action                                                                             |
| --------------------------------- | ---------------------------------------------------------------------------------- |
| `Space` `Space`                   | Fuzzy file picker (project-scoped)                                                 |
| `Space` `.`                       | Live grep across the project                                                       |
| `Space` `e`                       | Toggle the file tree sidebar                                                       |
| `Space` `g` `g`                   | Open Lazygit for the current file's repository (quit with `q`)                     |
| `Space` `n` `d`                   | Open today's daily note (see [Daily Notes](#daily-notes))                          |
| `Shift+H` / `Shift+L`             | Previous / next buffer tab                                                         |
| `Ctrl+Z`                          | Toggle Zen Mode                                                                    |
| `Alt+Up` / `Alt+Down`             | Move current line or selection up / down                                           |
| `Alt+Shift+Up` / `Alt+Shift+Down` | Add a cursor on the line above / below (see [Multiple Cursors](#multiple-cursors)) |

## Buffers

Open files show as tabs along the top. They behave like tabs, so **closing a buffer does not quit Neovim** —
the editor stays open with your other files.

| Action                                   | Result                                                             |
| ---------------------------------------- | ------------------------------------------------------------------ |
| Click a tab's `✗` (or right-click a tab) | Close only that buffer (prompts to save if it has unsaved changes) |
| `:q`                                     | Close the current buffer                                           |
| `:q!`                                    | Close the current buffer, discarding unsaved changes               |
| `:x` / `:wq`                             | Save the current buffer, then close it                             |
| `:qa` / `:xa`                            | Quit Neovim (all buffers) — `:xa` saves first                      |
| `Shift+H` / `Shift+L`                    | Previous / next buffer tab                                         |
| `Space` `b` `n` / `Space` `b` `p`        | Next / previous buffer tab                                         |

To close a split **window** (rather than a buffer), use `Ctrl+W` `c` or `:close`. Closing the last buffer leaves
an empty buffer with Neovim still open; use `:qa` to quit for real.

## Multiple Cursors

Edit in several places at once, VS Code-style. Everything you type is mirrored at every cursor **in real time**.

| Action                                      | Result                                                                     |
| ------------------------------------------- | -------------------------------------------------------------------------- |
| `Alt+Shift+Up` / `Alt+Shift+Down`           | Add a cursor on the line above/below, same column (normal, visual, insert) |
| Select lines with `V`, then `I`             | A cursor at the **start** of every selected line, in insert mode           |
| Select lines with `V`, then `A`             | A cursor at the **end** of every selected line, in insert mode             |
| `Ctrl+Click` (right-click / two-finger tap) | Add a cursor where you click — click an existing cursor to remove it       |
| Plain click anywhere                        | Back to a single cursor, placed where you clicked                          |
| `Esc` (in normal mode)                      | Back to a single cursor                                                    |

Notes:

- The cursor commands simulate the common editing commands (`i`, `a`, `I`, `A`, `o`, `x`, `dd`, …) at every
  cursor. Exotic normal-mode commands may apply only to the real cursor.
- **Why right-click adds a cursor:** on a Mac trackpad, `Ctrl+Click` _is_ a right-click by the time it reaches
  the terminal, and some terminals (Warp) drop the `Ctrl` modifier entirely — so the right button is bound too.
  Neovim's right-click popup menu is disabled to make room for this (`mousemodel=extend`).
- If a binding seems dead, check what your terminal actually delivers: `:luafile scripts/debug-keys.lua`, then
  press the key — each received event is shown as a notification. Run it again to stop.

## Code Intelligence (LSP)

Language servers provide auto-completion, live diagnostics, navigation, and refactoring for **JavaScript,
TypeScript, Python, Bash, YAML, and Lua**. The servers are downloaded automatically by mason.nvim on the first
interactive launch — run `:Mason` to watch the progress or inspect the installed set.

These shortcuts become active in a buffer once its language server attaches:

| Key                            | Action                                                          |
| ------------------------------ | --------------------------------------------------------------- |
| `F2` or `Space` `c` `r`        | Rename the symbol under the cursor across the project           |
| `F12` or `Space` `g` `d`       | Go to definition (a picker opens when there are several)        |
| `Shift+F12` or `Space` `g` `r` | List all references in a modal picker                           |
| `Space` `r`                    | Refactoring menu — rename, extract function/constant, inline, … |

Completion pops up automatically while typing, with the first suggestion preselected: `Enter` accepts it,
`Ctrl+N` / `Ctrl+P` or the arrow keys pick another candidate, `Ctrl+E` closes the menu (for when you want a
plain newline instead), and `Ctrl+Space` opens the menu manually. Diagnostics appear as virtual text at the
end of the line and as counts in the buffer tabs and status line.

Notes:

- The function keys (`F2`, `F12`, `Shift+F12`) also work while typing in insert mode — the prompt or picker
  opens from normal mode, and you are returned to insert mode once the action finishes (rename confirmed,
  jump landed, or picker closed).
- Refactorings beyond rename depend on the server: TypeScript/JavaScript has the richest set (extract
  function/constant, inline); most others support rename only. When nothing applies, Neovim reports
  "No code actions available".
- In Markdown buffers completion stays off and `F2` keeps its Markdown meaning (rename image).
- If `F12`/`Shift+F12` appear dead, the terminal or macOS may be capturing them (enable "Use F1, F2, etc. keys
  as standard function keys" in macOS keyboard settings); the `Space`-based alternatives always work. Diagnose
  with `:luafile scripts/debug-keys.lua`.
- Formatting is intentionally **not** done via LSP — conform.nvim owns it (`prettier` for Markdown, `stylua`
  for Lua).

To add a language, add one entry to the `servers` table in `lua/plugins/lsp.lua` — the process is documented
in [`lsp.md`](.claude/instructions/lsp.md).

## Daily Notes

`:Daily` (or `Space` `n` `d`) opens today's Markdown note — a file named `YYYY-MM-DD.md`. Running it again the
same day reopens the same note, so it works as a running daily scratchpad; all the Markdown features below are
active in it.

Notes are stored in `$NVIM_NOTES_DIR`, or `~/Notes` if the variable is unset. The directory is created
automatically on first use. To use a custom location, export an **absolute** path (a literal `~` in the value
is not expanded):

```sh
set -gx NVIM_NOTES_DIR "$HOME/Documents/notes"   # fish
export NVIM_NOTES_DIR="$HOME/Documents/notes"    # bash/zsh
```

## File Explorer

`Space e` toggles a file tree sidebar on the right. The tree follows the file you are editing and supports the
mouse (double-click opens files and expands/collapses directories; the wheel scrolls).

Inside the tree:

| Key                  | Action                                                                                               |
| -------------------- | ---------------------------------------------------------------------------------------------------- |
| `j`/`k`, `Up`/`Down` | Move between entries                                                                                 |
| `Enter`              | Open file / expand or collapse directory                                                             |
| `l`, `Right`         | Open file / expand directory                                                                         |
| `h`, `Left`          | Collapse directory                                                                                   |
| `d`                  | Delete — press `y` to confirm, `n` or `Esc` to abort                                                 |
| `r`                  | Rename (prompt pre-filled with the current name)                                                     |
| `n`                  | New file at a typed path (`sub/dir/file.md` creates the parents; a trailing `/` creates a directory) |
| `N`                  | New directory                                                                                        |
| `m`                  | Move to another path                                                                                 |
| `v` or `V`           | Visual mode — select multiple entries with `j`/`k` or mouse drag                                     |
| `/`                  | Fuzzy filter within the tree                                                                         |
| `?`                  | Show all mappings                                                                                    |

With a visual selection active: `d` deletes all selected entries after a single confirmation, `x` cuts and `p`
pastes them into a target directory (bulk move), `y` + `p` copies them.

## Markdown Features

All features activate automatically when a `.md` file is opened.

### Keyboard Shortcuts

These shortcuts are active only in Markdown buffers.

#### Formatting

| Key      | Mode           | Action                                            |
| -------- | -------------- | ------------------------------------------------- |
| `Ctrl+B` | Normal, Visual | Toggle **bold** (`**text**`) on word or selection |
| `Ctrl+I` | Normal, Visual | Toggle _italic_ (`_text_`) on word or selection   |

In Normal mode, formatting applies to the word under the cursor. In Visual mode, it applies to the selected
text. Pressing the key again on already-formatted text removes the markers.

#### Links and Images

| Key            | Mode   | Action                                                 |
| -------------- | ------ | ------------------------------------------------------ |
| `Ctrl+K`       | Normal | Insert a new link — prompts for text and URL           |
| `Ctrl+K`       | Visual | Wrap selected text as a link — prompts for URL         |
| `Ctrl+Shift+I` | Normal | Insert a new image tag — prompts for alt text and URL  |
| `Ctrl+Shift+I` | Visual | Wrap selected text as image alt text — prompts for URL |

`Ctrl+Shift+I` requires a terminal supporting the Kitty keyboard protocol.

#### Checklists

| Key      | Mode           | Action                                                  |
| -------- | -------------- | ------------------------------------------------------- |
| `Ctrl+L` | Normal, Insert | Cycle the current line through three states (see below) |
| `Ctrl+L` | Visual         | Toggle checkbox on all selected lines                   |

The three states on repeated `Ctrl+L` presses:

```text
Any plain text           →  - [ ] plain text
- [ ] unchecked item     →  - [x] unchecked item
- [x] checked item       →  - [ ] checked item
```

If the line is already an unordered list item (`- text`) the `-` prefix is preserved and a checkbox is added.
If it is a plain line, `-` is prepended.

#### List Continuation (Insert Mode)

| Key         | Behavior                                                                       |
| ----------- | ------------------------------------------------------------------------------ |
| `Enter`     | On a list line, creates a new item with the same marker (`-`, `*`, `1.`, etc.) |
| `Tab`       | Indents the current list item                                                  |
| `Shift+Tab` | Outdents the current list item                                                 |
| `Backspace` | On an empty list marker line, removes the marker                               |

### Auto-Format on Save

When a Markdown file is saved, `prettier` reformats it automatically. This normalises heading spacing, list
indentation, blank lines, and long lines.

If `prettier` is not installed, saving works normally and a one-time warning is logged.

### Live Linting

While you write, `markdownlint-cli2` checks the buffer — including unsaved changes — and marks every
offending line with a dark yellow background and the exact warning at the end of the line, for example
`MD022/blanks-around-headings Headings should be surrounded by blank lines`. Warnings appear about 300 ms
after you stop typing and disappear as soon as the issue is fixed.

Rule defaults live in `.markdownlint.jsonc` in this repository; the line-length limit (MD013) is aligned
with `textwidth` at 120 characters. A `.markdownlint.jsonc` (or `.json`/`.yaml`) file in the project you
are editing overrides these defaults.

If `markdownlint-cli2` is not installed, editing works normally and a one-time warning is logged.

### In-Buffer Rendering

`render-markdown.nvim` renders the Markdown visually inside the buffer without opening a separate preview window:

- Headings are styled with colour, icons, and a background highlight
- Checkboxes display as `✓` or `✗` icons
- Code blocks show a shaded background with the language label
- Tables are rendered with box-drawing characters
- Bold and italic are visually styled

The rendering is active in all modes. Raw syntax is revealed on the cursor line (controlled by `anti_conceal`).

### Additional Shortcuts (from markdown-plus.nvim defaults)

These `<localleader>` bindings (`\` by default) are always available in Markdown buffers alongside the Ctrl shortcuts:

| Key    | Action                                            |
| ------ | ------------------------------------------------- |
| `\ms`  | Toggle heading style (ATX `#` / setext underline) |
| `\mS`  | Toggle ~~strikethrough~~                          |
| `\m\`` | Toggle `inline code`                              |
| `\mr`  | Renumber ordered list items                       |
| `\mh`  | Insert horizontal rule                            |

## Updating Plugins

Open Neovim and run:

```text
:Lazy update
```

This updates plugins and records the new versions in `lazy-lock.json` — commit that file to pin the working set.

**Avoid `:Lazy sync`** — it also bumps every already-installed plugin to the latest commit, which silently
changes far more than intended when you only meant to fetch one new plugin. To fetch newly added plugins
without touching existing ones, use:

```sh
task install
```

If `sync` ran by mistake, `git diff lazy-lock.json`, revert the unintended entries, and run
`nvim --headless "+Lazy! restore" +qa` to re-checkout plugins to match the lockfile.

## Development

The configuration is tested by two [Busted](https://lunarmodules.github.io/busted/) suites under `tests/`:
unit specs for the pure-Lua `lua/lib/` modules, and integration specs that run inside a fully-loaded
headless Neovim against the real `vim` API. CI runs both on Ubuntu and macOS, plus a re-run of the lint
spec with `markdownlint-cli2` hidden so the missing-binary guard path stays covered.

```sh
# One-time setup
brew install luarocks selene
luarocks install busted                    # unit suite
luarocks --lua-version=5.1 install busted  # integration suite (Neovim's LuaJIT is 5.1-ABI)

# Everything CI runs: lint, unit, integration, guard path
scripts/check.sh
```

Tests are run through the tasks in `Taskfile.yml`, not by invoking `busted` directly: `task test` runs the full
pipeline, or individually `task test:unit`, `task test:integration`, `task lint` (selene, markdownlint,
shellcheck).
The integration harness and the rules for writing new specs are documented in
[`dev-workflow.md`](.claude/instructions/dev-workflow.md).

## Health Check

Run `:checkhealth` inside Neovim to verify that all plugins are set up correctly:

```text
:checkhealth markdown-plus
:checkhealth render-markdown
:checkhealth conform
:checkhealth lint
:checkhealth vim.lsp
:checkhealth mason
```
