-- Leader keys must be set before any `<leader>` mapping is created (keymaps.lua)
-- and before lazy.nvim loads plugin `keys` specs — options.lua is the first
-- module loaded from init.lua, so they live here.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.opt.clipboard = "unnamedplus"
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.textwidth = 120
vim.opt.colorcolumn = "120"
