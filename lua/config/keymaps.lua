-- Move the current line (or visual selection) up/down with Alt/Option + arrow keys.
vim.keymap.set("n", "<M-Up>", "<cmd>m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("n", "<M-Down>", "<cmd>m .+1<CR>==", { desc = "Move line down" })

vim.keymap.set("i", "<M-Up>", "<esc><cmd>m .-2<CR>==gi", { desc = "Move line up" })
vim.keymap.set("i", "<M-Down>", "<esc><cmd>m .+1<CR>==gi", { desc = "Move line down" })

vim.keymap.set("v", "<M-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("v", "<M-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
