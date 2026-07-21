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
