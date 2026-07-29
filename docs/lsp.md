# Code Intelligence (LSP)

Language servers provide auto-completion, live diagnostics, navigation, and refactoring for **JavaScript,
TypeScript, Python, Bash, YAML, and Lua**.

The servers are downloaded automatically by mason.nvim on the first
interactive launch. Run `:Mason` inside Neovim to watch the progress or inspect the installed set.

These shortcuts become active in a buffer once its language server attaches:

| Key                            | Action                                                          |
| ------------------------------ | --------------------------------------------------------------- |
| `F2` or `Space` `c` `r`        | Rename the symbol under the cursor across the project           |
| `F12` or `Space` `g` `d`       | Go to definition (a picker opens when there are several)        |
| `Shift+F12` or `Space` `g` `r` | List all references in a modal picker                           |
| `Space` `r`                    | Refactoring menu — rename, extract function/constant, inline, … |
| `Space` `c` `a`                | Quick Fix menu — corrections for the problem under the cursor   |
| `Space` `c` `d`                | Show the line's full diagnostics in a wrapping popup            |

Completion pops up automatically while typing, with the first suggestion preselected: `Enter` accepts it,
`Ctrl+N` / `Ctrl+P` or the arrow keys pick another candidate, `Ctrl+E` closes the menu (for when you want a
plain newline instead), and `Ctrl+Space` opens the menu manually.

Diagnostics appear as virtual text at the
end of the line and as counts in the buffer tabs and status line. The inline text can't wrap, so a long
message is truncated on the right — press `Space` `c` `d` to read the current line's diagnostics in full in a
wrapping popup.

## Grammar checking (Harper)

[Harper](https://writewithharper.com) (`harper-ls`) adds grammar and spell checking on top of the code
servers. It attaches to prose (Markdown, text, …) and to comments and string literals in source files, and
is installed by mason.nvim like the other servers. Its flagged text is drawn as a **dark-red wavy
underline** to set it apart from code diagnostics.

Options — dialect, which lints run, dictionary paths, `excludePatterns`, and more — live under
`config.harper` in `config.yml`; the file documents each field. If the underline renders flat instead of
wavy, the terminal needs undercurl support — see [Terminal Setup](terminal.md).

### Teaching Harper a word

Harper flags jargon, product names, and internal terms as misspellings. To teach it one, put the cursor on
the flagged word — or anywhere on its line — and press `Space` `c` `a`:

| Action                                     | Effect                                                       |
| ------------------------------------------ | ------------------------------------------------------------ |
| `Replace with: “…”`                        | Accept Harper's correction                                   |
| `Add "…" to the user dictionary.`          | Accept the word everywhere, on this machine                  |
| `Add "…" to the workspace dictionary.`     | Accept it in this project — `.harper-dictionary.txt` at the repo root, so it can be committed |
| `Add "…" to the file dictionary.`          | Accept it in this one file                                   |
| `Ignore Harper error.`                     | Silence this one occurrence, without learning the word       |

Pick one and the underline goes away. If the buffer has unsaved changes the flag may linger for a keystroke —
Harper re-reads the file from disk when it updates the dictionary — so just keep typing or save.

Not every flag offers the dictionary entries: Harper only offers them for **spelling** complaints. Style ones —
"This sentence does not start with a capital letter", "An Oxford comma is necessary here" — offer a
correction and `Ignore Harper error.` only.

The dictionaries are plain text, one word per line (no comments — a `#` line becomes a literal word). To
remove a word you added by mistake, `:HarperDict` opens the user dictionary and `:HarperDict project` the
project one; delete the line, save, and the flag returns. Unless `config.yml` overrides the paths, the user
dictionary is at `~/Library/Application Support/harper-ls/dictionary.txt` on macOS and
`~/.config/harper-ls/dictionary.txt` on Linux.

## Notes

- The function keys (`F2`, `F12`, `Shift+F12`) also work while typing in insert mode. The prompt or picker
  opens from normal mode, and you are returned to insert mode once the action finishes (rename confirmed,
  jump landed, or picker closed).
- Refactorings beyond rename depend on the server: TypeScript/JavaScript has the richest set (extract
  function/constant, inline); most others support rename only. When nothing applies, Neovim reports
  _No code actions available_.
- In Markdown buffers completion stays off and `F2` keeps its Markdown meaning (rename image).
- If `F12`/`Shift+F12` appear dead, the terminal or macOS may be capturing them (enable "Use F1, F2, etc. keys
  as standard function keys" in macOS keyboard settings); the `Space`-based alternatives always work. Diagnose
  with `:luafile scripts/debug-keys.lua`.
- Formatting is intentionally **not** done via LSP — conform.nvim owns it (`prettier` for Markdown, `stylua`
  for Lua).

To add a language, add one entry to the `servers` table in `lua/plugins/lsp.lua` — the process is documented
in [the LSP instructions](../.claude/instructions/lsp.md).
