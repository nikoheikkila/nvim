# Theming

The colorscheme is configured through an optional `theme.yml` file at the root of the configuration
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
```

## Schema

| Key       | Default                       | Description                                                            |
| --------- | ----------------------------- | ---------------------------------------------------------------------- |
| `url`     | `projekt0n/github-nvim-theme` | The plugin's GitHub repository (`owner/repo`), installed by lazy.nvim  |
| `name`    | `github-theme`                | Plugin name — must equal the theme's Lua module (used for `require()`) |
| `variant` | `github_dark_default`         | The colorscheme applied with the `:colorscheme` command                |
| `options` | `styles: { comments: italic }`| Passed as the `options` key of the theme's `setup()` call              |

## Switching to another theme

Point `url`, `name`, and `variant` at the theme you want. For example, to use
[catppuccin](https://github.com/catppuccin/nvim):

```yaml
theme:
  url: catppuccin/nvim
  name: catppuccin
  variant: catppuccin-mocha
```

Restart Neovim — lazy.nvim installs the new plugin automatically on the next start. Run `:Lazy clean`
afterwards to remove the previous theme from disk.

## Caveats

- `name` does double duty: it names the plugin for lazy.nvim **and** is the Lua module passed to
  `require(...).setup()`. It must match the theme's actual module name.
- `options` is passed as the `options` key of the theme's `setup()` call, matching github-nvim-theme's
  configuration shape. Themes that take their configuration at the top level of `setup()` (catppuccin,
  for example) still load and apply their `variant`, but may ignore the `options` table.
- Only a minimal YAML subset is supported: nested maps via space indentation, `key: value` scalars, blank
  lines, and full-line `#` comments. Lists, anchors, multiline scalars, inline `{}`/`[]`, and tabs are not.
- A missing, unreadable, or malformed `theme.yml` silently falls back to the defaults above — if your
  changes don't seem to apply, check the file against the supported subset.
- Switching to an uninstalled theme requires network access on the first start (lazy.nvim clones it). If
  the theme fails to load, startup continues with default colors and a warning notification.
