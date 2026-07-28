-- Make `:q` / `:x` / `:wq` close the CURRENT BUFFER instead of the window/Neovim,
-- treating bufferline tabs like tabs. `:qa` / `:xa` remain the way to quit Neovim.
--
-- These are built-in lowercase Ex commands and cannot be redefined directly, so
-- we expand them via command-line abbreviations to `-bang` user commands. The
-- `-bang` command is what lets the force variants (`:q!`, `:x!`, `:wq!`) work:
-- when the abbreviation fires on the `!`, the trailing `!` lands on the command
-- as its bang instead of corrupting the expansion.
--
-- Buffer deletion is delegated to snacks.nvim's `bufdelete` module, which
-- swaps in an alternate/new buffer in every window showing the target *before*
-- deleting it, so the window layout is preserved and Neovim never quits. On a
-- modified buffer it prompts Yes/No/Cancel (save+close / discard+close / abort).
-- snacks is `keys`-lazy-loaded, but lazy.nvim auto-loads it on first `require`
-- of a submodule, so the deferred `require` inside these callbacks is enough.

-- `:q`  -> BufClose  (prompts if the buffer is modified)
-- `:q!` -> BufClose! (force: discard changes and close)
vim.api.nvim_create_user_command("BufClose", function(opts)
  require("snacks.bufdelete").delete({ force = opts.bang })
end, { bang = true, desc = "Close (delete) the current buffer, keeping the window layout" })

-- `:x`/`:wq`  -> BufWriteClose  (write-if-modified via :update, then close)
-- `:x!`/`:wq!` -> BufWriteClose! (force write via :write!, then close)
-- After the write the buffer is unmodified, so delete() does not re-prompt.
vim.api.nvim_create_user_command("BufWriteClose", function(opts)
  vim.cmd(opts.bang and "write!" or "update")
  require("snacks.bufdelete").delete()
end, { bang = true, desc = "Write the current buffer, then close it, keeping the window layout" })

-- Rewrite only the exact bare commands; anything longer (`:qa`, `:xa`, `:wqa`,
-- ranges, ...) fails the `getcmdline()` guard, falls through to Vim's default,
-- and still quits Neovim.
vim.cmd([[
  cnoreabbrev <expr> q  (getcmdtype() ==# ':' && getcmdline() ==# 'q')  ? 'BufClose'      : 'q'
  cnoreabbrev <expr> x  (getcmdtype() ==# ':' && getcmdline() ==# 'x')  ? 'BufWriteClose' : 'x'
  cnoreabbrev <expr> wq (getcmdtype() ==# ':' && getcmdline() ==# 'wq') ? 'BufWriteClose' : 'wq'
]])
