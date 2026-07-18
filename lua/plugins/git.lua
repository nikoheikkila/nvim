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
          vim.cmd("LazyGitCurrentFile")
        end,
        desc = "Lazygit (current file repo)",
      },
    },
    init = function()
      -- Floating window styling; transparent-friendly to match the laserwave theme.
      vim.g.lazygit_floating_window_winblend = 0
      vim.g.lazygit_floating_window_scaling_factor = 0.9
      vim.g.lazygit_floating_window_use_plenary = 0
      vim.g.lazygit_use_neovim_remote = 0
    end,
  },
}
