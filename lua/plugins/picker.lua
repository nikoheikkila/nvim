return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader><leader>",
        function()
          require("snacks").picker.files({ cwd = vim.fs.root(0, { ".git" }) })
        end,
        desc = "Find Files (Project)",
      },
    },
    opts = {
      -- Only the fuzzy file picker is wanted. Every other snacks.nvim module
      -- (dashboard, notifier, zen, terminal, explorer, ...) is opt-in by
      -- snacks.nvim's own design, so it's simply omitted rather than listed
      -- with enabled = false. zen-mode.nvim (lua/plugins/zen.lua) already
      -- covers distraction-free writing, so snacks' own zen module is
      -- deliberately left off.
      picker = {
        enabled = true,
      },
    },
  },
}
