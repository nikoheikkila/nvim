# Markdown Features

All features activate automatically when a `.md` file is opened.

## Keyboard Shortcuts

These shortcuts are active only in Markdown buffers.

### Formatting

| Key      | Mode           | Action                                            |
| -------- | -------------- | ------------------------------------------------- |
| `Ctrl+B` | Normal, Visual | Toggle **bold** (`**text**`) on word or selection |
| `Ctrl+I` | Visual         | Toggle _italic_ (`_text_`) on the selection       |

In Normal mode, `Ctrl+B` applies to the word under the cursor; in Visual mode it applies to the selection.
Pressing the key again on already-formatted text removes the markers. Italic is Visual-only: in a terminal
`Ctrl+I` and `Tab` are the same key, and `Tab` toggles folds in Normal mode (see [Folding](#folding)).

### Links and Images

| Key            | Mode   | Action                                                 |
| -------------- | ------ | ------------------------------------------------------ |
| `Ctrl+K`       | Normal | Insert a new link — prompts for text and URL           |
| `Ctrl+K`       | Visual | Wrap selected text as a link — prompts for URL         |
| `Ctrl+Shift+I` | Normal | Insert a new image tag — prompts for alt text and URL  |
| `Ctrl+Shift+I` | Visual | Wrap selected text as image alt text — prompts for URL |

`Ctrl+Shift+I` requires a terminal supporting the Kitty keyboard protocol.

### Checklists

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

### List Continuation (Insert Mode)

| Key         | Behavior                                                                       |
| ----------- | ------------------------------------------------------------------------------ |
| `Enter`     | On a list line, creates a new item with the same marker (`-`, `*`, `1.`, etc.) |
| `Tab`       | Indents the current list item                                                  |
| `Shift+Tab` | Outdents the current list item                                                 |
| `Backspace` | On an empty list marker line, removes the marker                               |

## Auto-Format on Save

When a Markdown file is saved, `prettier` reformats it automatically. This normalises heading spacing, list
indentation, blank lines, and long lines.

If `prettier` is not installed, saving works normally and a one-time warning is logged.

## Live Linting

While you write, `markdownlint-cli2` checks the buffer including unsaved changes and marks every
offending line with a dark yellow background and the exact warning at the end of the line, for example
`MD022/blanks-around-headings Headings should be surrounded by blank lines`. Warnings appear about 300 ms
after you stop typing and disappear as soon as the issue is fixed.

Rule defaults live in `.markdownlint.jsonc` in this repository; the line-length limit (MD013) is aligned
with `textwidth` at 120 characters. A `.markdownlint.jsonc` (or `.json`/`.yaml`) file in the project you
are editing overrides these defaults.

If `markdownlint-cli2` is not installed, editing works normally and a one-time warning is logged.

## In-Buffer Rendering

`render-markdown.nvim` renders the Markdown visually inside the buffer without opening a separate preview window:

- Headings are styled with colour, icons, and a background highlight
- Checkboxes display as `✓` or `✗` icons
- Code blocks show a shaded background with the language label
- Tables are rendered with box-drawing characters
- Bold and italic are visually styled

The rendering is active in all modes. Raw syntax is revealed on the cursor line (controlled by `anti_conceal`).

## Folding

Headings, list items that have nested children, and fenced code blocks can be collapsed and expanded.

| Key   | Mode   | Action                           |
| ----- | ------ | -------------------------------- |
| `Tab` | Normal | Toggle the fold under the cursor |

A marker in the left gutter shows each foldable line's state — `▼` when expanded, `▶` when collapsed.
Left-clicking the marker toggles that fold. Everything starts expanded when a file opens.

Folding for non-Markdown files is driven by the language server instead — any range it reports as
collapsible — with the same `Tab` toggle and gutter markers.

## Additional Shortcuts (from markdown-plus.nvim defaults)

These `<localleader>` bindings (`\` by default) are always available in Markdown buffers alongside the Ctrl shortcuts:

| Key    | Action                                            |
| ------ | ------------------------------------------------- |
| `\ms`  | Toggle heading style (ATX `#` / setext underline) |
| `\mS`  | Toggle ~~strikethrough~~                          |
| `\m\`` | Toggle `inline code`                              |
| `\mr`  | Renumber ordered list items                       |
| `\mh`  | Insert horizontal rule                            |

## Daily Notes

`:Daily` (or `Space` `n` `d`) opens today's Markdown note, which is a file named `YYYY-MM-DD.md`. Running it again the
same day reopens the same note, so it works as a running daily scratchpad; all the Markdown features on this
page are active in it.

Notes are stored in `$NVIM_NOTES_DIR`, or `~/Notes` if the variable is unset. The directory is created
automatically on first use. To use a custom location, export an **absolute** path (a literal `~` in the value
is not expanded):

```sh
set -gx NVIM_NOTES_DIR "$HOME/Documents/notes"   # fish
export NVIM_NOTES_DIR="$HOME/Documents/notes"    # bash/zsh
```
