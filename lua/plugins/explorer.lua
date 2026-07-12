-- File-tree sidebar (neo-tree.nvim). Lazy-loaded on the toggle key or the
-- :Neotree command so it adds nothing to startup time.
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
      -- plenary.nvim and nvim-web-devicons are already installed (lazygit.nvim,
      -- bufferline/lualine); nui.nvim is the only genuinely new dependency.
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    cmd = "Neotree",
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file tree" },
    },
    opts = {
      -- Quitting the last real window exits Neovim instead of leaving the
      -- sidebar stranded as the only remaining window.
      close_if_last_window = true,
      window = {
        position = "right", -- neo-tree's default is left
        mappings = {
          -- Neo-tree's default `l` is focus_preview, not open — it MUST be
          -- remapped for l/<Right> to expand directories and open files, the
          -- counterpart of h/<Left> collapsing. Preview remains available on
          -- the default `P`. `<cr>` already opens files and toggles
          -- directories by default; j/k and the arrow keys are deliberately
          -- left unmapped so native cursor movement applies.
          ["l"] = "open",
          ["<Right>"] = "open",
          ["h"] = "close_node",
          ["<Left>"] = "close_node",
          -- Vim disables 'cursorline' while Visual mode is active, and
          -- charwise v highlights only one character until the selection
          -- grows, so the current entry appears to lose its highlight the
          -- moment visual mode starts. Tree entries are whole lines, so v
          -- enters linewise Visual mode instead, keeping the entry visibly
          -- highlighted from the first keypress.
          ["v"] = {
            function()
              vim.api.nvim_feedkeys("V", "n", false)
            end,
            desc = "visual select (linewise)",
          },
        },
      },
      filesystem = {
        -- This plugin is lazy-loaded, so it can never hijack `nvim <dir>` at
        -- startup anyway; disabling explicitly keeps `:e <dir>` behaving the
        -- same (netrw) before and after the first toggle.
        hijack_netrw_behavior = "disabled",
        -- Keep the tree cursor on the file being edited so the sidebar always
        -- shows where you are; complements the picker-first workflow where
        -- files are usually opened via <leader><leader>.
        follow_current_file = { enabled = true },
        window = {
          mappings = {
            -- Neo-tree defaults are `a` = add and `A` = add_directory; n/N are
            -- remapped to match muscle memory. Both prompts accept nested
            -- paths, and `n` treats a trailing slash as "create a directory".
            -- These are buffer-local to the tree, so search-next n/N is only
            -- shadowed inside it (where `/` is neo-tree's fuzzy filter anyway).
            ["n"] = "add",
            ["N"] = "add_directory",
          },
        },
      },
    },
    config = function(_, opts)
      require("neo-tree").setup(opts)

      -- Neo-tree's default confirmation is a NUI popup that requires typing
      -- y/n and then pressing <CR>. Replacing inputs.confirm with
      -- vim.fn.confirm() makes every confirmation (delete, overwrite on
      -- move/copy conflicts) act on a single keypress: y confirms
      -- immediately, n or <Esc> aborts, and bare <CR> means No. Text prompts
      -- (rename/add/move) keep their floating popups — only confirmations
      -- change. Same documented-patch approach as markdown.lua's italic
      -- pattern override; the original signature (blocking return when no
      -- callback is given) is preserved.
      local inputs = require("neo-tree.ui.inputs")
      inputs.confirm = function(message, callback)
        local confirmed = vim.fn.confirm(message, "&Yes\n&No", 2) == 1
        if callback then
          callback(confirmed)
        else
          return confirmed
        end
      end
    end,
  },
}
