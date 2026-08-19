# Code Intelligence (LSP)

Language servers provide autocompletion, live diagnostics, navigation, and refactoring for various languages.

The servers are downloaded automatically by `mason.nvim` plugin on the first
interactive launch. Run `:Mason` inside Neovim to watch the progress or inspect the installed set.

These shortcuts become active in a buffer once its language server attaches:

| Key                                              | Action                                                          |
| -------------------------------------------------- | ------------------------------------------------------------------- |
| <kbd>F2</kbd> or <kbd>Space c r</kbd>             | Rename the symbol under the cursor across the project           |
| <kbd>F12</kbd> or <kbd>Space g d</kbd>            | Go to definition (a picker opens when there are several)        |
| <kbd>Shift+F12</kbd> or <kbd>Space g r</kbd>      | List all references in a modal picker                           |
| <kbd>Space r</kbd>                                | Refactoring menu — rename, extract function/constant, inline, … |
| <kbd>Space c a</kbd>                              | Quick Fix menu — corrections for the problem under the cursor   |
| <kbd>Space c d</kbd>                               | Show the line's full diagnostics in a wrapping popup            |

Completion pops up automatically while typing, with the first suggestion selected: <kbd>Enter</kbd> accepts it,
<kbd>Ctrl+N</kbd> / <kbd>Ctrl+P</kbd> or the arrow keys pick another candidate, <kbd>Ctrl+E</kbd> closes the menu
(for when you want a plain newline instead), and <kbd>Ctrl+Space</kbd> opens the menu manually.

Diagnostics appear as virtual text at the
end of the line and as counts in the buffer tabs and status line. The inline text can't wrap, so a long
message is truncated on the right — press <kbd>Space c d</kbd> to read the current line's diagnostics in full in
a wrapping popup.

## Grammar Checking with Harper

[Harper](https://writewithharper.com) (`harper-ls`) adds grammar and spell checking on top of the code
servers. It attaches to prose (Markdown, text, …) and to comments and string literals in source files, and
is installed by `mason.nvim` like the other servers. Its flagged text is drawn as a **dark-red wavy
underline** to set it apart from code diagnostics.

Options — dialect, which lints run, dictionary paths, `excludePatterns`, and more — live under
`config.harper` in `config.yml`; the file documents each field. If the underline renders flat instead of
wavy, the terminal needs an underline support — see [Terminal Setup](terminal.md).

### Teaching Harper a Word

Harper flags jargon, product names, and internal terms as misspellings. To teach it one, put the cursor on
the flagged word — or anywhere on its line — and press <kbd>Space c a</kbd>.

| Action                                 | Effect                                                                                        |
| -------------------------------------- | --------------------------------------------------------------------------------------------- |
| `Replace with: “…”`                    | Accept Harper's correction                                                                    |
| `Add "…" to the user dictionary.`      | Accept the word everywhere, on this machine                                                   |
| `Add "…" to the workspace dictionary.` | Accept it in this project — `.harper-dictionary.txt` at the repo root, so it can be committed |
| `Add "…" to the file dictionary.`      | Accept it in this one file                                                                    |
| `Ignore Harper error.`                 | Silence this one occurrence, without learning the word                                        |

Pick one and the underline goes away. If the buffer has unsaved changes the flag may linger for a keystroke —
Harper rereads the file from disk when it updates the dictionary — so just keep typing or save.

Not every flag offers the dictionary entries: Harper only offers them for **spelling** complaints. Style ones —
"This sentence does not start with a capital letter", "An Oxford comma is necessary here" — offer a
correction and a possibility to ignore the Harper error only.

### Dictionaries

The dictionaries are plain text, one word per line (no comments — a `#` line becomes a literal word). To
remove a word you added by mistake, `:HarperDict` opens the user dictionary and `:HarperDict project` the
project one; delete the line, save, and the flag returns. Unless `config.yml` overrides the paths, the user
dictionary is at `~/Library/Application Support/harper-ls/dictionary.txt` on macOS and
`~/.config/harper-ls/dictionary.txt` on Linux.

## Prose Style with Vale

[Vale](https://vale.sh) (`vale-ls`) checks the _style_ of your prose where Harper checks its grammar: wordy
phrases, weasel words, passive voice, clichés, and redundancies. Both run at once in Markdown, plain text,
reStructuredText, AsciiDoc and LaTeX, and they are colour-coded so you can tell them apart at a glance:

| Underline                     | Source        | Complains about                            |
| ----------------------------- | ------------- | ------------------------------------------ |
| Dark-red wavy                 | Harper        | Spelling, grammar, capitalisation          |
| Violet wavy                   | Vale          | Wordiness, weasel words, clichés           |
| Dark-yellow band on the line  | markdownlint  | Markdown structure — headings, lists, ...  |

Vale needs its style packages downloaded once. The installer does it for you; if you cloned the repository by
hand, run <kbd>:ValeSync</kbd> inside Neovim and restart. Until then Vale stays quiet and says so on startup.

Press <kbd>Space c a</kbd> on a flagged phrase — or anywhere on its line — for Vale's suggested rewrites,
alongside Harper's corrections. Fixes apply straight to the buffer.

### Choosing the Rules

Which rules run is decided by `.vale.ini` next to `config.yml`; <kbd>:ValeConfig</kbd> opens it. It ships with
[write-good](https://github.com/btford/write-good) and [proselint](https://github.com/amperser/proselint),
with the rules that only repeat what Harper already says switched off. Add a package to `Packages` and its
name to `BasedOnStyles`, then run <kbd>:ValeSync</kbd> again — `Microsoft`, `Google`, and `alex` are the
popular ones. Turn a single noisy rule off with a `RuleName = NO` line.

A project with its own `.vale.ini` always wins: open a file inside one and Vale follows that repository's
house style instead, which is the point of committing one. Delete the shipped file to switch Vale off
everywhere else.

The behaviour of the server itself — how quickly it reacts to typing, whether it lints as you type at all, and
which severities reach the buffer — lives under `config.vale` in `config.yml`.

## Notes

- The function keys (<kbd>F2</kbd>, <kbd>F12</kbd>, <kbd>Shift+F12</kbd>) also work while typing in insert mode.
  The prompt or picker opens from normal mode, and you are returned to insert mode once the action finishes
  (rename confirmed, jump landed, or picker closed).
- Refactorings beyond rename depend on the server: TypeScript/JavaScript has the richest set (extract
  function/constant, inline); most others support rename only. When nothing applies, Neovim reports
  _No code actions available_.
- In Markdown buffers completion stays off and <kbd>F2</kbd> keeps its Markdown meaning (rename image).
- If <kbd>F12</kbd>/<kbd>Shift+F12</kbd> appear dead, the terminal, or macOS may be capturing them (enable
  "Use F1, F2, etc. keys as standard function keys" in macOS keyboard settings); the <kbd>Space</kbd>-based
  alternatives always work. Diagnose with `:luafile scripts/debug-keys.lua`.
- Formatting is intentionally **not** done via LSP — `conform.nvim` owns it (`prettier` for Markdown, `stylua`
  for Lua).

To add a language, add one entry to the `servers` table in `lua/plugins/lsp.lua` — the process is documented
in [the LSP instructions](../.claude/instructions/lsp.md).
