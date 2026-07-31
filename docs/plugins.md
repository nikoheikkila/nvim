# Plugins

| Plugin                                                                                                      | Purpose                                                                                         |
| ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [`yousefhadder/markdown-plus.nvim`](https://github.com/yousefhadder/markdown-plus.nvim)                     | Core Markdown editing: bold, italic, links, images, checklists, list management                 |
| [`MeanderingProgrammer/render-markdown.nvim`](https://github.com/MeanderingProgrammer/render-markdown.nvim) | In-buffer rendering of headings, code blocks, tables, and checkboxes                            |
| [`stevearc/conform.nvim`](https://github.com/stevearc/conform.nvim)                                         | Auto-format on save via `prettier`                                                              |
| [`mfussenegger/nvim-lint`](https://github.com/mfussenegger/nvim-lint)                                       | Live Markdown linting via `markdownlint-cli2`                                                   |
| [`obsidian-nvim/obsidian.nvim`](https://github.com/obsidian-nvim/obsidian.nvim)                             | Obsidian vault support: wiki-links, back links, daily notes (see [Obsidian Vault](obsidian.md)) |
| [`nvim-neo-tree/neo-tree.nvim`](https://github.com/nvim-neo-tree/neo-tree.nvim)                             | File tree sidebar with mouse support and bulk file operations                                   |
| [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim)                                                 | Fuzzy file picker, project-wide text search, and inline image viewing                           |
| [`kdheepak/lazygit.nvim`](https://github.com/kdheepak/lazygit.nvim)                                         | Lazygit in a floating window                                                                    |
| [`akinsho/bufferline.nvim`](https://github.com/akinsho/bufferline.nvim)                                     | Buffer tabs at the top                                                                          |
| [`nvim-lualine/lualine.nvim`](https://github.com/nvim-lualine/lualine.nvim)                                 | Status line                                                                                     |
| [`folke/zen-mode.nvim`](https://github.com/folke/zen-mode.nvim)                                             | Distraction-free writing mode                                                                   |
| [`brenton-leighton/multiple-cursors.nvim`](https://github.com/brenton-leighton/multiple-cursors.nvim)       | Multiple cursors with real-time editing (see [Multiple Cursors](editing.md#multiple-cursors))   |
| [`projekt0n/github-nvim-theme`](https://github.com/projekt0n/github-nvim-theme)                             | Default colour scheme — configurable via `theme.yml` (see [Theming](theming.md))                |
| [`neovim/nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig)                                         | Base configurations for language servers                                                        |
| [`mason-org/mason.nvim`](https://github.com/mason-org/mason.nvim)                                           | Automatic language-server installation                                                          |
| [`mason-org/mason-lspconfig.nvim`](https://github.com/mason-org/mason-lspconfig.nvim)                       | Bridges mason and config; auto-enables installed servers                                        |
| [`saghen/blink.cmp`](https://github.com/saghen/blink.cmp)                                                   | Autocompletion (see [Code Intelligence](lsp.md))                                                |

All plugins are managed by [`folke/lazy.nvim`](https://github.com/folke/lazy.nvim), which bootstraps itself automatically.

## Updating Plugins

Open Neovim and run:

```text
:Lazy update
```

This updates plugins and records the new versions in `lazy-lock.json` — commit that file to pin the working set.
