-- Leader keys must be set before any `<leader>` mapping is created (keymaps.lua)
-- and before lazy.nvim loads plugin `keys` specs — options.lua is the first
-- module loaded from init.lua, so they live here.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.opt.clipboard = "unnamedplus"
-- Ctrl+Click multi-cursor (plugins/multicursor.lua) needs mouse support in
-- normal mode — pin the Neovim default rather than relying on it silently.
vim.opt.mouse = "nvi"
-- No right-click popup menu: macOS synthesizes right-clicks from Ctrl+click
-- (trackpad), and the default popup_setpos menu would swallow them before the
-- multi-cursor <C-RightMouse> mapping ever fires in a ctrl-stripping terminal.
vim.opt.mousemodel = "extend"
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.textwidth = 120
vim.opt.colorcolumn = "120"
vim.opt.number = true
