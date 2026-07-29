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

-- `:HarperDict [user|project]` opens a Harper dictionary for editing, so a word
-- added through the `<leader>ca` quick-fix menu can be taken back out again.
-- harper-ls re-reads its dictionaries on every document change, so saving the
-- file is enough — no `:LspRestart`. Harper creates them on demand, so an empty
-- new buffer is the normal first sight of one and writing it creates the file.
--
-- The resolved settings from config/lsp_servers.lua are the shared source of
-- truth for the paths (already `vim.fn.expand`ed there), so this command and the
-- server cannot disagree about which file is in play. `user` and `project` are
-- the two Harper writes with a stable location; the third target it offers,
-- the file-local dictionary, lives under a name mangled from the document's full
-- path and is deliberately not exposed here.
--
-- Defined here rather than in plugins/lsp.lua so it also works in a session where
-- no server has attached yet.
vim.api.nvim_create_user_command("HarperDict", function(opts)
  local harper_utils = require("lib.harper_utils")
  -- Asserted, not assumed: this reaches through the servers table's shape, and a
  -- renamed key would otherwise leave every path silently on harper's default.
  -- (An accessor function on that module is not an option — lsp_spec iterates it
  -- with pairs() and treats every key as a server name.)
  local settings = require("config.lsp_servers").harper_ls.settings["harper-ls"]
  assert(type(settings) == "table", "HarperDict: harper_ls settings moved in config/lsp_servers.lua")
  local which = opts.args ~= "" and opts.args or "user"

  local path
  if which == "user" then
    path = harper_utils.user_dict_path({
      configured = settings.userDictPath,
      mac = vim.fn.has("mac") == 1,
      home = vim.env.HOME,
      xdg_config_home = vim.env.XDG_CONFIG_HOME,
    })
  elseif which == "project" then
    -- Harper's root when it is attached; otherwise the markers nvim-lspconfig
    -- gives harper_ls, so the answer matches what it would pick on attach.
    local client = vim.lsp.get_clients({ bufnr = 0, name = "harper_ls" })[1]
    local root = client and client.root_dir or vim.fs.root(0, { ".harper-dictionary.txt", ".git" })
    path = harper_utils.workspace_dict_path({
      configured = settings.workspaceDictPath,
      root = root or vim.fn.getcwd(),
    })
  else
    return vim.notify(("HarperDict: expected `user` or `project`, got `%s`"):format(which), vim.log.levels.WARN)
  end

  -- fnameescape, not a bare string: harper's own macOS default path contains a
  -- space (~/Library/Application Support/...).
  vim.cmd.edit(vim.fn.fnameescape(path))
end, {
  nargs = "?",
  complete = function()
    return { "user", "project" }
  end,
  desc = "Open a Harper dictionary (user or project) for editing",
})

-- Rewrite only the exact bare commands; anything longer (`:qa`, `:xa`, `:wqa`,
-- ranges, ...) fails the `getcmdline()` guard, falls through to Vim's default,
-- and still quits Neovim.
vim.cmd([[
  cnoreabbrev <expr> q  (getcmdtype() ==# ':' && getcmdline() ==# 'q')  ? 'BufClose'      : 'q'
  cnoreabbrev <expr> x  (getcmdtype() ==# ':' && getcmdline() ==# 'x')  ? 'BufWriteClose' : 'x'
  cnoreabbrev <expr> wq (getcmdtype() ==# ':' && getcmdline() ==# 'wq') ? 'BufWriteClose' : 'wq'
]])
