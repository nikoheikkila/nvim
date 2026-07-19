# Installation

## Requirements

| Requirement                                                                                       | Notes                                                   |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| Neovim ≥ 0.12.4                                                                                   | Required by nvim-treesitter (main) and the LSP client   |
| Git                                                                                               | Used by lazy.nvim to clone and update plugins           |
| A [Nerd Font](https://www.nerdfonts.com/)                                                         | Used by render-markdown.nvim for heading and list icons |
| `prettier`                                                                                        | Optional — needed for auto-format on save               |
| `markdownlint-cli2`                                                                               | Optional — needed for live Markdown linting             |
| A terminal with the [Kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/) | Optional — needed for `Ctrl+Shift+I` (insert image)     |

Compatible terminals for `Ctrl+Shift+I`: kitty, WezTerm, Ghostty, foot.

## Quick Install (Recommended)

```sh
curl -sSL https://raw.githubusercontent.com/nikoheikkila/nvim/refs/heads/main/scripts/install.sh | sh
```

The script downloads the latest [release](https://github.com/nikoheikkila/nvim/releases), extracts it into
`$XDG_CONFIG_HOME/nvim` (or `~/.config/nvim` when `XDG_CONFIG_HOME` is unset), and pre-installs all plugins,
so the configuration is ready on the first launch of `nvim`. An existing configuration is moved aside to
`<dir>.bak.<timestamp>` first — nothing is overwritten.

To install into a custom Neovim configuration directory, pass the `-o` / `--out` flag (the `sh -s --` form
is required to forward flags through the pipe):

```sh
curl -sSL https://raw.githubusercontent.com/nikoheikkila/nvim/refs/heads/main/scripts/install.sh |
  sh -s -- --out ~/path/to/nvim
```

Neovim only loads configuration from its standard locations, so a custom directory must be launched with
`XDG_CONFIG_HOME` and `NVIM_APPNAME` pointing at it — the script prints the exact command when it finishes.

## Manual Install (From Source)

1. **Back up any existing config**

   ```sh
   mv ~/.config/nvim ~/.config/nvim.bak
   ```

2. **Clone this configuration**

   ```sh
   git clone <repo-url> ~/.config/nvim
   ```

3. **Start Neovim** — lazy.nvim bootstraps itself on first launch and installs all plugins automatically:

   ```sh
   nvim
   ```

## Optional Tools

1. **Install `prettier`** (optional, for auto-formatting on save):

   ```sh
   # via npm
   npm install -g prettier

   # via Homebrew
   brew install prettier
   ```

2. **Install `markdownlint-cli2`** (optional, for live linting while writing):

   ```sh
   # via npm
   npm install -g markdownlint-cli2

   # via Homebrew
   brew install markdownlint-cli2
   ```
