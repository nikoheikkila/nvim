# Editing

## Line Numbers

Absolute line numbers show in the left column of every buffer. In folding-enabled buffers (Markdown, and any
file whose language server supports folding) the number sits alongside the ▼/▶ fold indicator rather than
replacing it.

## General Shortcuts

The leader key is `Space`.

| Key                               | Action                                                                             |
| --------------------------------- | ---------------------------------------------------------------------------------- |
| `Space` `Space`                   | Fuzzy file picker (project-scoped, see [Project Scope](#project-scope))            |
| `Space` `.`                       | Live grep across the project                                                       |
| `Space` `e`                       | Toggle the file tree sidebar                                                       |
| `Space` `g` `g`                   | Open Lazygit for the current file's repository (quit with `q`)                     |
| `Space` `n` `d`                   | Open today's vault note (see [Obsidian Vault](obsidian.md))                        |
| `Space` `o`                       | Obsidian command menu (see [Obsidian Vault](obsidian.md#commands))                 |
| `Shift+H` / `Shift+L`             | Previous / next buffer tab                                                         |
| `Ctrl+Z`                          | Toggle Zen Mode                                                                    |
| `Alt+Up` / `Alt+Down`             | Move current line or selection up / down                                           |
| `Alt+Shift+Up` / `Alt+Shift+Down` | Add a cursor on the line above / below (see [Multiple Cursors](#multiple-cursors)) |
| `g` `t` + a motion                | Title-case the text the motion covers (see [Title Case](#title-case))              |
| Select text, then `t`             | Title-case the selection (see [Title Case](#title-case))                           |

## Project Scope

`Space` `Space`, `Space` `.` and `Space` `g` `g` all search one directory — the "project". It is chosen like this:

1. **The folder you opened.** Start Neovim on a directory (`nvim <directory>`) and that directory is the project, even
   when it sits inside a bigger Git repository — `nvim ~/monorepo/packages/api` searches the package, not the monorepo.
   Neovim's working directory follows it, so the file tree (`Space` `e`) and `:e` completion agree.
2. **The Git repository of the file you are editing**, when you did not name a directory.
3. **The current working directory**, when the file is not in a repository at all.

Naming a directory fixes the scope for the whole session: after `nvim <directory>`, opening a file from another repository
does not move the picker. `Space` `g` `g` is the exception — Lazygit always follows the current file's repository, since
a repository is repository-wide anyway.

## Title Case

Rewrites headings and titles to follow the [AMA title case rules](https://titlecapitalize.com/ama-title-case-rules/):
major words get a capital, while articles, coordinating conjunctions and short prepositions stay lowercase in the
middle of a title.

| Action                | Result                                                     |
| --------------------- | ---------------------------------------------------------- |
| `g` `t` `i` `w`       | Title-case the word under the cursor                       |
| `g` `t` `$`           | Title-case from the cursor to the end of the line          |
| `g` `t` `j`           | Title-case this line and the next                          |
| Select text, then `t` | Title-case the selection (charwise, linewise or block)     |
| `.`                   | Repeat the last title-casing on wherever the cursor now is |
| `u`                   | Undo the whole title-casing in one step                    |

`g` `t` takes any motion or text object, the same way `d` and `y` do. Each **line** is treated as its own title, so
its first and last word are always capitalized.

What it does:

| Before                                          | After                                           |
| ----------------------------------------------- | ----------------------------------------------- |
| `journal of clinical epidemiology`              | `Journal of Clinical Epidemiology`              |
| `oncology: immunotherapy with anti-PD-1 agents` | `Oncology: Immunotherapy With Anti-PD-1 Agents` |
| `pharmacology of β-blocker therapy`             | `Pharmacology of β-Blocker Therapy`             |
| `diseases we care for`                          | `Diseases We Care For`                          |
| `meta-analysis methods for evidence synthesis`  | `Meta-Analysis Methods for Evidence Synthesis`  |

Notes:

- **Abbreviations are never touched.** Any word already carrying a capital beyond its first letter is left exactly as
  typed, which is what keeps `DNA`, `SARS-CoV-2`, `HbA1c`, `eGFR` and `PD-1` intact. Greek letters are left alone too.
- **The flipside:** an ALL-CAPS title counts as "already capitalized" and is left untouched. Lowercase it first, then
  title-case it: `guu` then `g` `t` `$`, or select the line with `V` and press `u` then `t`. (`gu` is itself an operator,
  so it needs its own motion — `gugt$` does not work.) A lowercase abbreviation can't be recognised either, so `dna`
  becomes `Dna`.
- Prepositions of four letters or more (`With`, `Between`, `Through`) **are** capitalized according to AMA rules.
- `g` `t` replaces Neovim's built-in "go to next tab page". This config uses buffers as tabs, so nothing is really
  lost; `gT` and `:tabnext` still move between tab pages if you ever open one.
- In visual mode `t` replaces the built-in `t{char}` "till" motion. Use `f{char}` or `/` to extend a selection instead.

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
