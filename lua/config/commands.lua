-- Make `:q` / `:x` / `:wq` close the CURRENT BUFFER instead of the window/Neovim,
-- treating bufferline tabs like tabs. `:qa` / `:xa` remain the way to quit Neovim.
-- Also defines `:Daily`, which opens today's Markdown note.
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

-- `:Daily` opens today's note, creating the directory on first use. Running it
-- again the same day reopens the same note. The notes directory and the
-- filename format come from config.yml (`config.daily.directory` /
-- `config.daily.filenamePattern`), falling back to hardcoded defaults
-- ($HOME/Notes, %Y-%m-%d.md) when config.yml is missing or malformed. The
-- NVIM_NOTES_DIR env var, when set and non-empty, overrides the directory. The
-- resolved directory is run through vim.fn.expand, so `$HOME`/`~`/other env vars
-- work in either source. Filetype detection sets markdown from the `.md` name.
local yaml_utils = require("lib.yaml_utils")
local daily_utils = require("lib.daily_utils")

-- Mirrors plugins/theme.lua: a missing/unreadable config.yml yields nil, so
-- resolve_config falls back to defaults.
local function read_config()
  local file = io.open(vim.fn.stdpath("config") .. "/config.yml", "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return yaml_utils.parse(text)
end

vim.api.nvim_create_user_command("Daily", function()
  local cfg = daily_utils.resolve_config(read_config())
  local dir = vim.fn.expand(daily_utils.effective_directory(cfg, vim.env.NVIM_NOTES_DIR))
  local ok, err = pcall(vim.fn.mkdir, dir, "p")
  if not ok then
    vim.notify("Daily: cannot create notes dir " .. dir .. ": " .. err, vim.log.levels.ERROR)
    return
  end
  vim.cmd.edit(vim.fs.joinpath(dir, os.date(cfg.filenamePattern)))
end, { desc = "Open today's Markdown note (dir/format from config.yml; NVIM_NOTES_DIR overrides dir)" })
