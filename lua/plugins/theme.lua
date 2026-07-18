return {
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    lazy = false,
    priority = 1000,
    config = function()
      -- Default styles.comments is 'NONE'; italic comments are wanted both in
      -- regular code and inside markdown fences (injected @comment captures
      -- merge italic over the non-italic fence-content group).
      require("github-theme").setup({
        options = { styles = { comments = "italic" } },
      })
      vim.cmd("colorscheme github_dark_default")
    end,
  },
}
