# Obsidian Vault

[`obsidian.nvim`](https://github.com/obsidian-nvim/obsidian.nvim) turns Neovim into a full editor for an
Obsidian vault: wiki-links, back links, tags, templates, daily notes, and image attachments. It activates
automatically in Markdown files that live inside your vault, and stays out of the way everywhere else.

Everything on the [Markdown Features](markdown.md) page — formatting shortcuts, folding, live linting,
format-on-save, rendering — is active in vault notes too.

## Configuring the Vault

The vault location lives in `config.yml` at the config root:

```yaml
config:
  obsidian:
    vault: "$HOME/Vaults"
    dailyNotes:
      folder: "000 - Inbox/Journal"
      dateFormat: "YYYY-MM-DD"
```

| Key                     | Meaning                                                                |
| ----------------------- | ---------------------------------------------------------------------- |
| `vault`                 | Vault root. `$HOME`, `~`, and other environment variables are expanded |
| `dailyNotes.folder`     | Where daily notes go, relative to the vault root                       |
| `dailyNotes.dateFormat` | Daily-note filename, as a Moment.JS pattern                            |

A `/` in `dateFormat` creates subdirectories, so `"YYYY/MM/DD"` writes
`<folder>/2026/07/28.md`.

Omitting the file, a key, or leaving a value empty falls back to the defaults above. If the whole
`config.obsidian` block is missing, the vault defaults to `~/Vaults`.

Run `:checkhealth obsidian` to confirm the vault resolved and the optional tools were found.

## Keyboard Shortcuts

These are active only in notes inside the vault.

| Key                        | Action                                                                                       |
| --------------------------- | --------------------------------------------------------------------------------------------- |
| <kbd>Enter</kbd>            | Smart action — follows the link, toggles the checkbox, or folds the heading under the cursor |
| <kbd>] o</kbd>              | Jump to the next link                                                                        |
| <kbd>[ o</kbd>              | Jump to the previous link                                                                    |
| <kbd>g f</kbd>              | Follow the link under the cursor (built-in, taught to resolve wiki-links)                    |
| <kbd>g x</kbd>              | Open the link under the cursor in the browser (built-in)                                     |
| <kbd>Space n d</kbd>        | Open today's daily note (`:Obsidian today`)                                                  |
| <kbd>Space o</kbd>          | Open the Obsidian command menu — every command below, in a picker                            |

<kbd>Enter</kbd> picks its behaviour from what is under the cursor, so it covers link-following, checkbox
toggling, and heading folds with one key. In Insert mode <kbd>Enter</kbd> still continues the current list item.

Notes also get the standard [LSP shortcuts](lsp.md) — Obsidian ships an in-process language server, so
<kbd>Space c r</kbd> renames a note and updates every backlink to it, and <kbd>Space g r</kbd> lists the back
links.

## Commands

**<kbd>Space o</kbd> is the quickest way in** — it runs bare `:Obsidian`, which lists every command in a picker
so you can fuzzy-find one instead of remembering its name. You can also type `:Obsidian` and press <kbd>Tab</kbd>
to complete subcommands. The list is context-sensitive: note actions appear only inside a note, and the
visual-mode ones only with a selection (for those, use `:Obsidian` from visual mode rather than <kbd>Space o</kbd>).

| Command                  | Action                                                                       |
| ------------------------ | ---------------------------------------------------------------------------- |
| `:Obsidian today`        | Open today's daily note. Takes an offset or date, e.g. `:Obsidian today 3-1` |
| `:Obsidian yesterday`    | Open yesterday's daily note                                                  |
| `:Obsidian tomorrow`     | Open tomorrow's daily note                                                   |
| `:Obsidian dailies`      | List daily notes, e.g. `:Obsidian dailies -2 1`                              |
| `:Obsidian new`          | Create a note                                                                |
| `:Obsidian quick_switch` | Jump to a note by name                                                       |
| `:Obsidian search`       | Grep the vault                                                               |
| `:Obsidian tags`         | Browse tags                                                                  |
| `:Obsidian backlinks`    | List notes linking to the current one                                        |
| `:Obsidian toc`          | Jump to a heading in the current note                                        |
| `:Obsidian links`        | List the links in the current note                                           |
| `:Obsidian template`     | Insert a template                                                            |
| `:Obsidian rename`       | Rename the current note, updating every link to it                           |
| `:Obsidian extract_note` | Move the visual selection into a new note                                    |
| `:Obsidian paste_img`    | Paste an image from the clipboard into the vault                             |
| `:Obsidian workspace`    | Show or switch the active workspace                                          |
| `:Obsidian open`         | Open the current note in the Obsidian app                                    |

Pickers (`search`, `quick_switch`, `tags`, `backlinks`) open in the same
[snacks picker](plugins.md) used elsewhere in this config. Inside a picker, <kbd>Ctrl+X</kbd> creates a new note
from what you typed and <kbd>Ctrl+L</kbd> inserts a link to the selected note.

## Images

`:Obsidian paste_img` saves the image on your clipboard into the vault's `attachments/` folder and inserts a
Markdown image link to it. On macOS this needs `pngpaste`:

```sh
brew install pngpaste
```

Viewing images inline is handled by `snacks.image`, which resolves vault attachment paths through Obsidian so
that links written for the Obsidian app work here too. It renders images with the **kitty graphics protocol**,
which means it works in kitty, Ghostty, and WezTerm (in a floating window), and inside `tmux` with
pass through enabled.

Converting anything other than PNG needs ImageMagick:

```sh
brew install imagemagick
```

## Rendering

Markdown rendering is owned by [`render-markdown.nvim`](markdown.md), so Obsidian's own conceal-based UI is
turned off. That avoids two plugins decorating the same buffer, and matches where `obsidian.nvim` is heading —
upstream plans to drop its UI module in favour of dedicated rendering plugins.

Folding also stays with the Markdown implementation described in [Markdown Features](markdown.md#folding):
<kbd>Tab</kbd> folds headings, list items, and fenced code blocks in vault notes exactly as it does anywhere else.
