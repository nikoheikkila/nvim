# Neovim Configuration

A minimal Neovim setup built around a comprehensive Markdown editing experience.

## Requirements

| Requirement | Notes |
|---|---|
| Neovim ≥ 0.10 | Required by render-markdown.nvim and markdown-plus.nvim |
| Git | Used by lazy.nvim to clone and update plugins |
| A [Nerd Font](https://www.nerdfonts.com/) | Used by render-markdown.nvim for heading and list icons |
| `prettier` | Optional — needed for auto-format on save |
| A terminal with the [Kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/) | Optional — needed for `Ctrl+Shift+I` (insert image) |

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

## Plugins

| Plugin | Purpose |
|---|---|
| [yousefhadder/markdown-plus.nvim](https://github.com/yousefhadder/markdown-plus.nvim) | Core Markdown editing: bold, italic, links, images, checklists, list management |
| [MeanderingProgrammer/render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | In-buffer rendering of headings, code blocks, tables, and checkboxes |
| [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim) | Auto-format on save via `prettier` |

All plugins are managed by [folke/lazy.nvim](https://github.com/folke/lazy.nvim), which bootstraps itself automatically.

## Markdown Features

All features activate automatically when a `.md` file is opened.

### Keyboard Shortcuts

These shortcuts are active only in Markdown buffers.

#### Formatting

| Key | Mode | Action |
|---|---|---|
| `Ctrl+B` | Normal, Visual | Toggle **bold** (`**text**`) on word or selection |
| `Ctrl+I` | Normal, Visual | Toggle _italic_ (`_text_`) on word or selection |

In Normal mode, formatting applies to the word under the cursor. In Visual mode, it applies to the selected text. Pressing the key again on already-formatted text removes the markers.

#### Links and Images

| Key | Mode | Action |
|---|---|---|
| `Ctrl+K` | Normal | Insert a new link — prompts for text and URL |
| `Ctrl+K` | Visual | Wrap selected text as a link — prompts for URL |
| `Ctrl+Shift+I` | Normal | Insert a new image tag — prompts for alt text and URL |
| `Ctrl+Shift+I` | Visual | Wrap selected text as image alt text — prompts for URL |

`Ctrl+Shift+I` requires a terminal supporting the Kitty keyboard protocol.

#### Checklists

| Key | Mode | Action |
|---|---|---|
| `Ctrl+L` | Normal, Insert | Cycle the current line through three states (see below) |
| `Ctrl+L` | Visual | Toggle checkbox on all selected lines |

The three states on repeated `Ctrl+L` presses:

```
Any plain text           →  - [ ] plain text
- [ ] unchecked item     →  - [x] unchecked item
- [x] checked item       →  - [ ] checked item
```

If the line is already an unordered list item (`- text`) the `- ` prefix is preserved and a checkbox is added. If it is a plain line, `- ` is prepended.

#### List Continuation (Insert Mode)

| Key | Behavior |
|---|---|
| `Enter` | On a list line, creates a new item with the same marker (`-`, `*`, `1.`, etc.) |
| `Tab` | Indents the current list item |
| `Shift+Tab` | Outdents the current list item |
| `Backspace` | On an empty list marker line, removes the marker |

### Auto-Format on Save

When a Markdown file is saved, `prettier` reformats it automatically. This normalises heading spacing, list indentation, blank lines, and long lines.

If `prettier` is not installed, saving works normally and a one-time warning is logged.

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

| Key | Action |
|---|---|
| `\ms` | Toggle heading style (ATX `#` / setext underline) |
| `\mS` | Toggle ~~strikethrough~~ |
| `\m\`` | Toggle `inline code` |
| `\mr` | Renumber ordered list items |
| `\mh` | Insert horizontal rule |

## Updating Plugins

Open Neovim and run:

```
:Lazy update
```

To pin all plugins to their current versions (updating `lazy-lock.json`):

```
:Lazy sync
```

## Health Check

Run `:checkhealth` inside Neovim to verify that all plugins are set up correctly:

```
:checkhealth markdown-plus
:checkhealth render-markdown
:checkhealth conform
```
