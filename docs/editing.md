# Editing

## Line Numbers

Absolute line numbers show in the left column of every buffer. In folding-enabled buffers (Markdown, and any
file whose language server supports folding) the number sits alongside the ▼/▶ fold indicator rather than
replacing it.

## General Shortcuts

The leader key is <kbd>Space</kbd>.

| Key                                             | Action                                                                             |
| ------------------------------------------------- | ------------------------------------------------------------------------------------- |
| <kbd>Space Space</kbd>                          | Fuzzy file picker (project-scoped, see [Project Scope](#project-scope))            |
| <kbd>Space .</kbd>                               | Live grep across the project                                                       |
| <kbd>Space S</kbd>                               | Search & replace across the project (see [Search & Replace](#search--replace))     |
| <kbd>Space e</kbd>                               | Toggle the file tree sidebar                                                       |
| <kbd>Space g g</kbd>                             | Open Lazygit for the current file's repository (quit with <kbd>q</kbd>)            |
| <kbd>Space n d</kbd>                             | Open today's vault note (see [Obsidian Vault](obsidian.md))                        |
| <kbd>Space o</kbd>                               | Obsidian command menu (see [Obsidian Vault](obsidian.md#commands))                 |
| <kbd>Shift+H</kbd> / <kbd>Shift+L</kbd>         | Previous / next buffer tab                                                         |
| <kbd>Ctrl+Z</kbd>                                | Toggle Zen Mode                                                                    |
| <kbd>Alt+Up</kbd> / <kbd>Alt+Down</kbd>         | Move current line or selection up / down                                           |
| <kbd>Alt+Shift+Up</kbd> / <kbd>Alt+Shift+Down</kbd> | Add a cursor on the line above / below (see [Multiple Cursors](#multiple-cursors)) |
| <kbd>g t</kbd> + a motion                       | Title-case the text the motion covers (see [Title Case](#title-case))              |
| Select text, then <kbd>t</kbd>                  | Title-case the selection (see [Title Case](#title-case))                           |

## Project Scope

<kbd>Space Space</kbd>, <kbd>Space .</kbd>, <kbd>Space S</kbd> and <kbd>Space g g</kbd> all search one directory — the
"project".
It is chosen like this:

1. **The folder you opened.** Start Neovim on a directory (`nvim <directory>`) and that directory is the project, even
   when it sits inside a bigger Git repository — `nvim ~/monorepo/packages/api` searches the package, not the monorepo.
   Neovim's working directory follows it, so the file tree (<kbd>Space e</kbd>) and `:e` completion agree.
2. **The Git repository of the file you are editing**, when you did not name a directory.
3. **The current working directory**, when the file is not in a repository at all.

Naming a directory fixes the scope for the whole session: after `nvim <directory>`, opening a file from another repository
does not move the picker. <kbd>Space g g</kbd> is the exception — Lazygit always follows the current file's repository,
since a repository is repository-wide anyway.

## Search & Replace

<kbd>Space S</kbd> opens a search & replace window over the [project](#project-scope), powered by
[grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim). Select some text first to search for it.

Type what to look for in **Search** and what to put in its place in **Replace**. Every match then shows up twice: the
current line in red and the line after the replacement in green. Nothing is written yet — that preview is the whole
point.

| Key                                   | Action                                                                                      |
| ------------------------------------- | ------------------------------------------------------------------------------------------- |
| <kbd>Tab</kbd> / <kbd>Shift+Tab</kbd> | Next / previous input                                                                       |
| <kbd>Ctrl+S</kbd>                     | **Accept:** apply every replacement in the project                                          |
| <kbd>Ctrl+Y</kbd>                     | Apply only the change under the cursor (from an input: the first one), then move on         |
| <kbd>q</kbd> / <kbd>Esc</kbd>         | Close without applying anything (Normal mode). <kbd>Space S</kbd> restores your input       |
| <kbd>Enter</kbd>                      | Jump to the result under the cursor; <kbd>Space S</kbd> brings the window back              |
| <kbd>Ctrl+P</kbd>                     | Peek at the result under the cursor without leaving the window                              |
| <kbd>Ctrl+T</kbd>                     | Search & replace history                                                                    |
| <kbd>Ctrl+E</kbd>                     | Switch between text search and code-aware search (ast-grep)                                 |
| <kbd>\ c</kbd>                        | Close and clear everything, for a fresh start next time (<kbd>\\</kbd> is the local leader) |
| <kbd>g ?</kbd>                        | All keys                                                                                    |

The <kbd>Ctrl</kbd> keys and <kbd>Tab</kbd> work while typing too. The line atop the window lists the same keys.

Closing the window only hides it: <kbd>Space S</kbd> brings back your search, replacement and results until you quit
Neovim, with the results searched again in case files changed meanwhile. Only <kbd>\ c</kbd> starts over.

**Search** is a regular expression in [ripgrep's syntax](https://docs.rs/regex/latest/regex/#syntax), case-sensitive
by default. Put capture groups in parentheses and refer to them in **Replace** as `$1`, `$2`, … — `foo(\d+)` →
`bar$1` turns `foo42` into `bar42`. To search for literal text, add `--fixed-strings` (`-F`) to **Flags**; `-i` makes
the search case-insensitive. **Files Filter** narrows the search to matching files (`*.lua`). Hidden files are
searched, but `.gitignore` is respected. <kbd>Tab</kbd> moves to the next input, so match a tab character with `\t`.

The window covers 80% of the editor by default; change `searchReplace` in `config.yml` to resize it. The diff colours
come from your theme — override `GrugFarResultsMatchAdded` / `GrugFarResultsMatchRemoved` under `groups` in
`theme.yml` (see [Theming](theming.md)). Search & replace needs `ripgrep`; ast-grep is installed for you.

## Title Case

Rewrites headings and titles to follow the [AMA title case rules](https://titlecapitalize.com/ama-title-case-rules/):
major words get a capital, while articles, coordinating conjunctions and short prepositions stay lowercase in the
middle of a title.

| Action                        | Result                                                     |
| ------------------------------ | ---------------------------------------------------------- |
| <kbd>g t i w</kbd>            | Title-case the word under the cursor                       |
| <kbd>g t $</kbd>              | Title-case from the cursor to the end of the line          |
| <kbd>g t j</kbd>              | Title-case this line and the next                          |
| Select text, then <kbd>t</kbd> | Title-case the selection (charwise, linewise or block)     |
| <kbd>.</kbd>                  | Repeat the last title-casing on wherever the cursor now is |
| <kbd>u</kbd>                  | Undo the whole title-casing in one step                    |

<kbd>g t</kbd> takes any motion or text object, the same way <kbd>d</kbd> and <kbd>y</kbd> do. Each **line** is
treated as its own title, so its first and last word are always capitalized.

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
  title-case it: `guu` then <kbd>g t $</kbd>, or select the line with <kbd>V</kbd> and press <kbd>u</kbd> then
  <kbd>t</kbd>. (`gu` is itself an operator, so it needs its own motion — `gugt$` does not work.) A lowercase
  abbreviation can't be recognised either, so `dna` becomes `Dna`.
- Prepositions of four letters or more (`With`, `Between`, `Through`) **are** capitalized according to AMA rules.
- <kbd>g t</kbd> replaces Neovim's built-in "go to next tab page". This config uses buffers as tabs, so nothing is
  really lost; `gT` and `:tabnext` still move between tab pages if you ever open one.
- In visual mode <kbd>t</kbd> replaces the built-in `t{char}` "till" motion. Use `f{char}` or `/` to extend a
  selection instead.

## Buffers

Open files show as tabs along the top. They behave like tabs, so **closing a buffer does not quit Neovim**.
The editor stays open with your other files.

| Action                                          | Result                                                             |
| ------------------------------------------------- | ------------------------------------------------------------------ |
| Click a tab's `✗` (or right-click a tab)        | Close only that buffer (prompts to save if it has unsaved changes) |
| `:q`                                             | Close the current buffer                                           |
| `:q!`                                            | Close the current buffer, discarding unsaved changes               |
| `:x` / `:wq`                                     | Save the current buffer, then close it                             |
| `:qa` / `:xa`                                    | Quit Neovim (all buffers) — `:xa` saves first                      |
| <kbd>Shift+H</kbd> / <kbd>Shift+L</kbd>         | Previous / next buffer tab                                         |
| <kbd>Space b n</kbd> / <kbd>Space b p</kbd>     | Next / previous buffer tab                                         |

To close a split **window** (rather than a buffer), use <kbd>Ctrl+W c</kbd> or `:close`. Closing the last buffer
leaves an empty buffer with Neovim still open; use `:qa` to quit for real.

## Multiple Cursors

Edit in several places at once, VS Code-style. Everything you type is mirrored at every cursor **in real time**.

| Action                                                | Result                                                                     |
| -------------------------------------------------------- | --------------------------------------------------------------------------- |
| <kbd>Alt+Shift+Up</kbd> / <kbd>Alt+Shift+Down</kbd>   | Add a cursor on the line above/below, same column (normal, visual, insert) |
| Select lines with <kbd>V</kbd>, then <kbd>I</kbd>     | A cursor at the **start** of every selected line, in insert mode           |
| Select lines with <kbd>V</kbd>, then <kbd>A</kbd>     | A cursor at the **end** of every selected line, in insert mode             |
| <kbd>Ctrl+Click</kbd> (right-click / two-finger tap)  | Add a cursor where you click — click an existing cursor to remove it       |
| Plain click anywhere                                  | Back to a single cursor, placed where you clicked                          |
| <kbd>Esc</kbd> (in normal mode)                        | Back to a single cursor                                                    |

Notes:

- The cursor commands simulate the common editing commands (<kbd>i</kbd>, <kbd>a</kbd>, <kbd>I</kbd>,
  <kbd>A</kbd>, <kbd>o</kbd>, <kbd>x</kbd>, <kbd>dd</kbd>, …) at every cursor. Exotic normal-mode commands may
  apply only to the real cursor.
- **Why right-click adds a cursor:** on a Mac trackpad, <kbd>Ctrl+Click</kbd> _is_ a right-click by the time it
  reaches the terminal, and some terminals (Warp) drop the `Ctrl` modifier entirely. Thus, the right button is
  bound too. Neovim's right-click popup menu is disabled to make room for this (`mousemodel=extend`).
