-- Move the current line (or visual selection) up/down with Alt/Option + arrow keys.
vim.keymap.set("n", "<M-Up>", "<cmd>m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("n", "<M-Down>", "<cmd>m .+1<CR>==", { desc = "Move line down" })

vim.keymap.set("i", "<M-Up>", "<esc><cmd>m .-2<CR>==gi", { desc = "Move line up" })
vim.keymap.set("i", "<M-Down>", "<esc><cmd>m .+1<CR>==gi", { desc = "Move line down" })

vim.keymap.set("v", "<M-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("v", "<M-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })

-- Open today's Markdown note (mnemonic: "new -> daily"). The `:Daily` command
-- is defined in config/commands.lua and resolved at press time, so the
-- keymaps-before-commands load order in init.lua does not matter.
vim.keymap.set("n", "<leader>nd", "<cmd>Daily<cr>", { desc = "Open today's note" })

-- Show the full diagnostic(s) for the current line in a floating window. Line
-- diagnostics (virtual text on the right) can't wrap and get truncated on long
-- lines; the float wraps, so this is how to read the whole message. Global (not
-- LSP-buffer-local) so it also covers linter diagnostics like markdownlint.
vim.keymap.set("n", "<leader>cd", function()
  vim.diagnostic.open_float(nil, { border = "rounded", source = true })
end, { desc = "Show line diagnostics" })
