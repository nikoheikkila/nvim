# Markdown Features

All features activate automatically when a `.md` file is opened.

## Keyboard Shortcuts

These shortcuts are active only in Markdown buffers.

### Formatting

| Key                  | Mode           | Action                                            |
| --------------------- | -------------- | --------------------------------------------------- |
| <kbd>Ctrl+B</kbd>     | Normal, Visual | Toggle **bold** (`**text**`) on word or selection |
| <kbd>Ctrl+I</kbd>     | Visual         | Toggle _italic_ (`_text_`) on the selection       |

In Normal mode, <kbd>Ctrl+B</kbd> applies to the word under the cursor; in Visual mode it applies to the
selection. Pressing the key again on already-formatted text removes the markers. Italic is Visual-only: in a
terminal <kbd>Ctrl+I</kbd> and <kbd>Tab</kbd> are the same key, and <kbd>Tab</kbd> toggles folds in Normal mode
(see [Folding](#folding)).

### Links and Images

| Key                      | Mode   | Action                                                 |
| ------------------------- | ------ | --------------------------------------------------------- |
| <kbd>Ctrl+K</kbd>         | Normal | Insert a new link — prompts for text and URL           |
| <kbd>Ctrl+K</kbd>         | Visual | Wrap selected text as a link — prompts for URL         |
| <kbd>Ctrl+Shift+I</kbd>   | Normal | Insert a new image tag — prompts for alt text and URL  |
| <kbd>Ctrl+Shift+I</kbd>   | Visual | Wrap selected text as image alt text — prompts for URL |

<kbd>Ctrl+Shift+I</kbd> requires a terminal supporting the Kitty keyboard protocol.

### Checklists

| Key                | Mode           | Action                                                  |
| ------------------- | -------------- | ---------------------------------------------------------- |
| <kbd>Ctrl+L</kbd>   | Normal, Insert | Cycle the current line through three states (see below) |
| <kbd>Ctrl+L</kbd>   | Visual         | Toggle checkbox on all selected lines                   |

The three states on repeated <kbd>Ctrl+L</kbd> presses:

```text
Any plain text           →  - [ ] plain text
- [ ] unchecked item     →  - [x] unchecked item
- [x] checked item       →  - [ ] checked item
```

If the line is already an unordered list item (`- text`) the `-` prefix is preserved and a checkbox is added.
If it is a plain line, `-` is prepended.

### List Continuation (Insert Mode)

| Key                    | Behavior                                                                       |
| ----------------------- | ------------------------------------------------------------------------------ |
| <kbd>Enter</kbd>       | On a list line, creates a new item with the same marker (`-`, `*`, `1.`, etc.) |
| <kbd>Tab</kbd>         | Indents the current list item                                                  |
| <kbd>Shift+Tab</kbd>   | Outdents the current list item                                                 |
| <kbd>Backspace</kbd>   | On an empty list marker line, removes the marker                               |

## Auto-Format on Save

When a Markdown file is saved, `prettier` reformats it automatically. This normalises heading spacing, list
indentation, blank lines, and long lines.

If `prettier` is not installed, saving works normally and a one-time warning is logged.

## Live Linting

While you write, `markdownlint-cli2` checks the buffer including unsaved changes and marks every
offending line with a dark yellow background and the exact warning at the end of the line, for example
`MD022/blanks-around-headings Headings should be surrounded by blank lines`. Warnings appear about 300 milliseconds
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

| Key            | Mode   | Action                           |
| --------------- | ------ | --------------------------------- |
| <kbd>Tab</kbd> | Normal | Toggle the fold under the cursor |

A marker in the left gutter shows each foldable line's state — `▼` when expanded, `▶` when collapsed.
Left-clicking the marker toggles that fold. Everything starts expanded when a file opens.

Folding for non-Markdown files is driven by the language server instead — any range it reports as
collapsible — with the same <kbd>Tab</kbd> toggle and gutter markers.

## Additional Shortcuts (from Plugin Defaults)

These `<localleader>` bindings (`\` by default) are always available in Markdown buffers
alongside the Control-prefixed shortcuts:

| Key                  | Action                                            |
| --------------------- | ------------------------------------------------- |
| <kbd>\ms</kbd>       | Toggle heading style (ATX `#` / setext underline) |
| <kbd>\mS</kbd>       | Toggle ~~strike through~~                         |
| <kbd>\m`</kbd>       | Toggle `inline code`                              |
| <kbd>\mr</kbd>       | Renumber ordered list items                       |
| <kbd>\mh</kbd>       | Insert horizontal rule                            |

## Daily Notes

<kbd>Space n d</kbd> (or `:Obsidian today`) opens today's note. Running it again the same day reopens the same
note, so it works as a running daily scratchpad, and every feature on this page is active in it.

Daily notes live in your Obsidian vault, so where they land and what they are named is configured alongside the
vault — see [Obsidian Vault](obsidian.md#configuring-the-vault).

## Link Navigation

In vault notes, <kbd>Enter</kbd> follows the link under the cursor. Everywhere else use the built-in key bindings:

- <kbd>g f</kbd> opens the file a relative link points at
- <kbd>g x</kbd> opens a URL in the browser

See [Obsidian Vault](obsidian.md#keyboard-shortcuts) for the full set.
