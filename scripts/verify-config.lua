-- Headless smoke test for config-level wiring that Busted cannot cover
-- (Busted runs pure Lua without Neovim: no user commands, keymaps, or leaders).
-- Checks the CURRENT contract of lua/config/ — extend it when adding user
-- commands or global keymaps. Run via: scripts/smoke-test.sh
--
-- Failures are signalled with `cquit 1` so shell callers see a non-zero exit;
-- printed PASS/FAIL lines can visually run together in headless output — the
-- exit code is the authoritative result.

local failures = 0

local function check(cond, label)
  if cond then
    print("PASS: " .. label .. "\n")
  else
    failures = failures + 1
    print("FAIL: " .. label .. "\n")
  end
end

-- Leader keys: must be set by config/options.lua BEFORE keymaps.lua runs.
-- A <leader> map created before vim.g.mapleader is set silently binds to the
-- default backslash — this check exists because exactly that regression shipped.
check(vim.g.mapleader == " ", "mapleader is <Space>")
check(vim.g.maplocalleader == "\\", "maplocalleader is backslash")

-- Buffer-close command overrides (config/commands.lua)
local cmds = vim.api.nvim_get_commands({})
check(cmds.BufClose ~= nil, ":BufClose is defined")
check(cmds.BufWriteClose ~= nil, ":BufWriteClose is defined")
check(vim.fn.execute("cabbrev q"):find("BufClose") ~= nil, ":q abbreviation rewrites to BufClose")
check(vim.fn.execute("cabbrev x"):find("BufWriteClose") ~= nil, ":x abbreviation rewrites to BufWriteClose")
check(vim.fn.execute("cabbrev wq"):find("BufWriteClose") ~= nil, ":wq abbreviation rewrites to BufWriteClose")

-- :Daily end-to-end against a scratch notes dir (env is read at call time,
-- so setting vim.env in-process is enough — no shell wrapper needed).
local scratch = vim.fn.tempname()
vim.env.NVIM_NOTES_DIR = scratch
check(cmds.Daily ~= nil, ":Daily is defined")
vim.cmd("Daily")
-- Compare via resolve(): on macOS tempname() returns /var/... while buffer
-- names resolve through the /var -> /private/var symlink.
local expected = vim.fn.resolve(vim.fs.joinpath(scratch, os.date("%Y-%m-%d") .. ".md"))
check(vim.fn.resolve(vim.api.nvim_buf_get_name(0)) == expected, ":Daily opens today's note in $NVIM_NOTES_DIR")
check(vim.bo.filetype == "markdown", ":Daily buffer has markdown filetype")
check(vim.fn.isdirectory(scratch) == 1, ":Daily creates the notes directory")
vim.cmd("enew")
vim.cmd("Daily")
check(vim.fn.resolve(vim.api.nvim_buf_get_name(0)) == expected, "second :Daily reopens the same note")
vim.fn.delete(scratch, "rf")

-- Global keymaps (registry: .claude/instructions/config.md). maparg needs the
-- LITERAL leader character in the lhs — "<leader>nd" is not resolved.
local leader = vim.g.mapleader
check(vim.fn.maparg(leader .. "nd", "n"):find("Daily") ~= nil, "<leader>nd is bound to :Daily")
check(vim.fn.maparg(leader .. "bn", "n", false, true).desc == "Next Buffer", "<leader>bn cycles to next buffer")
check(vim.fn.maparg(leader .. "bp", "n", false, true).desc == "Prev Buffer", "<leader>bp cycles to prev buffer")

if failures > 0 then
  print(failures .. " smoke check(s) FAILED\n")
  vim.cmd("cquit 1")
end
print("All smoke checks passed\n")
