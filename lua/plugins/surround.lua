-- Add/change/delete surrounding pairs (quotes, brackets, tags) with the
-- standard ys/ds/cs operators. Default keymaps kept as-is (see the Global
-- Keymap Registry in config.md); VeryLazy because surround maps are
-- operator-prefixes, not single keys that lazy.nvim can trigger via `keys`.
return {
  {
    "kylechui/nvim-surround",
    version = "*", -- latest stable tag; exact commit pinned in lazy-lock.json
    event = "VeryLazy",
    opts = {}, -- empty = plugin defaults (ys/ds/cs + visual S)
  },
}
