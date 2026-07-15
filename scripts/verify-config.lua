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

-- Multi-cursor (plugins/multicursor.lua, multiple-cursors.nvim). Lazy-loaded
-- plugins don't load on their own in --headless (keys/VeryLazy triggers never
-- fire), so force-load before asserting anything created at setup() time.
require("lazy").load({ plugins = { "multiple-cursors.nvim" } })
local ok_mc, mc = pcall(require, "multiple-cursors")
check(ok_mc, "multiple-cursors.nvim loads")
if ok_mc then
  check(vim.o.mouse:find("n") ~= nil, "mouse is enabled in normal mode (Ctrl+Click cursors)")
  check(vim.o.mousemodel == "extend", "mousemodel has no popup menu to swallow ctrl+clicks")
  local mc_cmds = vim.api.nvim_get_commands({})
  check(mc_cmds.MultipleCursorsAddDown ~= nil, ":MultipleCursorsAddDown is defined")
  check(mc_cmds.MultipleCursorsAddVisualArea ~= nil, ":MultipleCursorsAddVisualArea is defined")
  for _, mode in ipairs({ "n", "x", "i" }) do
    check(
      vim.fn.maparg("<M-S-Up>", mode, false, true).desc == "Add cursor above",
      "<M-S-Up> adds cursor above (" .. mode .. ")"
    )
    check(
      vim.fn.maparg("<M-S-Down>", mode, false, true).desc == "Add cursor below",
      "<M-S-Down> adds cursor below (" .. mode .. ")"
    )
  end
  for _, lhs in ipairs({ "<C-LeftMouse>", "<C-RightMouse>", "<RightMouse>" }) do
    for _, mode in ipairs({ "n", "i" }) do
      check(
        vim.fn.maparg(lhs, mode, false, true).desc == "Add or remove cursor at mouse click",
        lhs .. " toggles cursor at mouse click (" .. mode .. ")"
      )
    end
  end
  check(
    vim.fn.maparg("I", "x", false, true).desc == "Insert at start of selected lines",
    "visual I inserts at start of selected lines"
  )
  check(
    vim.fn.maparg("A", "x", false, true).desc == "Append at end of selected lines",
    "visual A appends at end of selected lines"
  )

  -- Functional check of the core loop: add a virtual cursor below, confirm the
  -- plain-click reset maps appear while cursors are active, then reset.
  local vcs = require("multiple-cursors.virtual_cursors")
  vim.cmd("enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "beta", "gamma" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  check(vcs.get_num_virtual_cursors() == 0, "no virtual cursors before functional test")
  local ok_add, err = pcall(vim.cmd, "MultipleCursorsAddDown")
  check(
    ok_add and vcs.get_num_virtual_cursors() == 1,
    "AddDown spawns a virtual cursor" .. (ok_add and "" or (": " .. tostring(err)))
  )
  check(vim.api.nvim_win_get_cursor(0)[1] == 2, "AddDown moves the real cursor to the next line")
  check(vim.fn.maparg("<LeftMouse>", "n", false, true).buffer == 1, "plain-click reset map active (n)")
  check(vim.fn.maparg("<LeftMouse>", "i", false, true).buffer == 1, "plain-click reset map active (i)")
  pcall(mc.deinit, true)
  check(vcs.get_num_virtual_cursors() == 0, "deinit resets to a single cursor")
  check(vim.fn.maparg("<LeftMouse>", "n") == "", "plain-click reset map removed after deinit")
  -- headless-lua.sh quits with `qa!`, but stay clean anyway so this script
  -- also works under a hand-rolled `-c qa` runner (which hangs on a modified
  -- buffer with no UI to answer the prompt).
  vim.bo.modified = false
end

if failures > 0 then
  print(failures .. " smoke check(s) FAILED\n")
  vim.cmd("cquit 1")
end
print("All smoke checks passed\n")
