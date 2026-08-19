# Theming

The colour scheme is configured through an optional `theme.yml` file at the root of the configuration
directory (`~/.config/nvim/theme.yml`). At startup, `lua/plugins/theme.lua` reads the file and builds the
theme plugin's spec from it; anything the file does not specify keeps the built-in default. Edits take
effect on the next Neovim restart.

The shipped configuration:

```yaml
theme:
  url: projekt0n/github-nvim-theme
  name: github-theme
  variant: github_dark_default
  options:
    styles:
      comments: italic
  groups:
    all:
      # Inline code in markdown: regular (non-italic) red on dark grey.
      "@markup.raw.markdown_inline":
        fg: "#ff7b72"
        bg: "#2e2e2e"
      # render-markdown's own inline-code layer, pinned to the same colors.
      RenderMarkdownCodeInline:
        fg: "#ff7b72"
        bg: "#2e2e2e"
```

## Schema

| Key       | Default                        | Description                                                             |
| --------- | ------------------------------ | ----------------------------------------------------------------------- |
| `url`     | `projekt0n/github-nvim-theme`  | The plugin's GitHub repository (`owner/repo`), installed by `lazy.nvim` |
| `name`    | `github-theme`                 | Plugin name — must equal the theme's Lua module (used for `require()`)  |
| `variant` | `github_dark_default`          | The colorscheme applied with the `:colorscheme` command                 |
| `options` | `styles: { comments: italic }` | Passed as the `options` key of the theme's `setup()` call               |
| `groups`  | see above                      | Highlight-group overrides, passed as the `groups` key of `setup()`      |

## Highlight Group Overrides

`groups.all` maps highlight-group names to `fg` / `bg` / `style` attributes, following the override shape in `github-nvim-theme`
Overrides are applied when the colorscheme loads and reapplied whenever it reloads. A group
defined here **replaces** the theme's styling for that group entirely — the shipped configuration uses this
to render Markdown inline code non-italic (defining `@markup.raw.markdown_inline` without `style` removes
the theme's italic).

The shipped `theme.yml` also defines `HarperDiagnosticUnderline` and `ValeDiagnosticUnderline` — the colours
the two prose checkers are drawn in (dark red and violet). They are ordinary overrides, so recolour them here
like any other group; see [Terminal Setup](terminal.md) if the wave renders flat.

Two syntax notes: group names containing `@` (Tree-sitter captures) must be quoted, and hex colour values
must be quoted too — an unquoted `#` starts a YAML comment.

## Switching to Another Theme

Point `url`, `name`, and `variant` at the theme you want. For example, to use
[catppuccin](https://github.com/catppuccin/nvim):

```yaml
theme:
  url: catppuccin/nvim
  name: catppuccin
  variant: catppuccin-mocha
```

Restart Neovim — `lazy.nvim` installs the new plugin automatically on the next start. Run `:Lazy clean`
afterwards to remove the previous theme from disk.

## Caveats

- `name` does double duty: it names the plugin for `lazy.nvim` **and** is the Lua module passed to
  `require(...).setup()`. It must match the theme's actual module name.
- `options` and `groups` are passed as the same-named keys of the theme's `setup()` call, matching
  theme's configuration shape. Themes that take their configuration at the top level of
  `setup()` (catppuccin, for example) still load and apply their `variant`, but may ignore these tables.
- Only a minimal YAML subset is supported: nested maps via space indentation, `key: value` scalars, block
  sequences (`- item` lines, scalar items), quoted keys, blank lines, and full-line `#` comments. Anchors,
  multiline scalars, inline `{}`/`[]`, trailing comments after a value, and tabs are not.
- Missing, unreadable, or malformed `theme.yml` silently falls back to the defaults above — if your
  changes don't seem to apply, check the file against the supported subset.
- Switching to an uninstalled theme requires network access on the first start (`lazy.nvim` clones it). If
  the theme fails to load, start up continues with default colours and a warning notification.
