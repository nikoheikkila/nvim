-- nvim-treesitter (main branch): supplies the highlight queries for the compiled
-- parsers in ~/.local/share/nvim/site/parser/. The site/queries/* entries are
-- symlinks into this plugin's runtime/queries/ — the plugin must exist on disk
-- at ~/.local/share/nvim/lazy/nvim-treesitter or code-fence highlighting dies.
-- Markdown buffers already get treesitter highlighting from Neovim's bundled
-- ftplugin; this plugin only needs to supply queries, so no setup() is required.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main", -- master is frozen; main needs nvim 0.11+ and the tree-sitter CLI
    lazy = false, -- upstream: main branch does not support lazy-loading
    build = ":TSUpdate", -- keep compiled parsers in sync with the plugin's queries
  },
}
