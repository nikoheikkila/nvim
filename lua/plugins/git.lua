return {
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "LazyGit",
      "LazyGitCurrentFile",
      "LazyGitConfig",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    keys = {
      {
        "<leader>gg",
        function()
          if vim.fn.executable("lazygit") == 0 then
            vim.notify("lazygit not found on PATH", vim.log.levels.ERROR)
            return
          end

          -- :LazyGitCurrentFile resolves the repo from the current buffer and
          -- falls back to the cwd, which the `startup_dir` autocmd
          -- (config/autocmds.lua) has already pointed at a directory argument --
          -- so `nvim <directory>` needs nothing extra here. This guard only
          -- replaces lazygit's own "not a git repository" init prompt with a
          -- clean message; it predicts that outcome because vim.fs.root falls
          -- back to the cwd for the unnamed buffer netrw leaves on a directory.
          if not vim.fs.root(0, { ".git" }) then
            vim.notify("No Git repository here", vim.log.levels.WARN)
            return
          end

          vim.cmd("LazyGitCurrentFile")
        end,
        desc = "Lazygit (current file repo)",
      },
    },
    init = function()
      -- Floating window styling; transparent-friendly to match the theme background.
      vim.g.lazygit_floating_window_winblend = 0
      vim.g.lazygit_floating_window_scaling_factor = 0.9
      vim.g.lazygit_floating_window_use_plenary = 0
      vim.g.lazygit_use_neovim_remote = 0
    end,
  },
}
