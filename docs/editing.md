# Editing

## General Shortcuts

The leader key is `Space`.

| Key                               | Action                                                                             |
| --------------------------------- | ---------------------------------------------------------------------------------- |
| `Space` `Space`                   | Fuzzy file picker (project-scoped)                                                 |
| `Space` `.`                       | Live grep across the project                                                       |
| `Space` `e`                       | Toggle the file tree sidebar                                                       |
| `Space` `g` `g`                   | Open Lazygit for the current file's repository (quit with `q`)                     |
| `Space` `n` `d`                   | Open today's daily note (see [Daily Notes](markdown.md#daily-notes))               |
| `Shift+H` / `Shift+L`             | Previous / next buffer tab                                                         |
| `Ctrl+Z`                          | Toggle Zen Mode                                                                    |
| `Alt+Up` / `Alt+Down`             | Move current line or selection up / down                                           |
| `Alt+Shift+Up` / `Alt+Shift+Down` | Add a cursor on the line above / below (see [Multiple Cursors](#multiple-cursors)) |

## Buffers

Open files show as tabs along the top. They behave like tabs, so **closing a buffer does not quit Neovim**.
The editor stays open with your other files.

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
  the terminal, and some terminals (Warp) drop the `Ctrl` modifier entirely. Thus, the right button is bound too.
  Neovim's right-click popup menu is disabled to make room for this (`mousemodel=extend`).
- If a binding seems dead, check what your terminal actually delivers: `:luafile scripts/debug-keys.lua`, then
  press the key — each received event is shown as a notification. Run it again to stop.
