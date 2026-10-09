-- ast-grep comes from mason (plugins/lsp.lua), whose bin dir only joins PATH
-- once nvim-lspconfig loads on BufReadPre. An absolute path keeps the
-- structural engines working in a session that has not read a file.
local ast_grep = vim.fn.stdpath("data") .. "/mason/bin/ast-grep"

return {
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    keys = {
      {
        "<leader>S",
        function()
          require("config.search_replace").open()
        end,
        mode = { "n", "x" },
        desc = "Search & Replace (Project)",
      },
    },
    -- Global options, shared with plain :GrugFar. The modal float and its keys
    -- are per-instance overrides in config/search_replace.lua.
    opts = {
      engines = {
        ripgrep = {
          -- The same dotfile policy as the picker's `hidden = true`
          -- (plugins/picker.lua): search dotfiles, but never inside .git/,
          -- which --hidden alone would descend into.
          extraArgs = "--hidden --glob=!.git/",
        },
        astgrep = { path = ast_grep },
        ["astgrep-rules"] = { path = ast_grep },
      },
    },
  },
}
