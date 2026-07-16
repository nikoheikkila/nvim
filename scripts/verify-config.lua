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

-- Record vim.notify calls for the markdown-lint section's guard assertions.
-- Installed up here because nvim-lint ft-loads during the :Daily check below
-- (it opens a markdown buffer) — a missing-binary notification fires there,
-- long before the lint section runs.
local notifications = {}
local orig_notify = vim.notify
vim.notify = function(msg, ...)
  table.insert(notifications, tostring(msg))
  return orig_notify(msg, ...)
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

-- Auto-save (config/autocmds.lua): InsertLeave saves immediately and is the
-- ONLY trigger — no TextChanged debounce, so format-on-save never fires
-- mid-edit. Events are fired explicitly (feedkeys-driven autocmds are
-- unreliable headlessly) and scoped to the auto_save group so other plugins'
-- handlers stay out of the test.
local aus = vim.api.nvim_get_autocmds({ group = "auto_save", event = "InsertLeave" })
check(#aus == 1, "auto_save has an InsertLeave autocmd")
for _, ev in ipairs({ "TextChanged", "TextChangedI" }) do
  local debounced = vim.api.nvim_get_autocmds({ group = "auto_save", event = ev })
  check(#debounced == 0, "auto_save has no " .. ev .. " autocmd (debounce stays removed)")
end

local save_file = vim.fn.tempname() .. ".txt"
vim.cmd.edit(save_file)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "autosaved" })
check(vim.bo.modified, "buffer is modified before InsertLeave")
-- The InsertLeave autocmd must be `nested` — otherwise its `:update` fires no
-- write autocmds and conform/auto_create_dir are silently skipped.
local write_autocmds_fired = false
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("verify_nested_save", { clear = true }),
  callback = function()
    write_autocmds_fired = true
  end,
})
vim.api.nvim_exec_autocmds("InsertLeave", { group = "auto_save" })
check(vim.fn.filereadable(save_file) == 1, "InsertLeave writes the buffer to disk")
check(not vim.bo.modified, "InsertLeave clears 'modified'")
check(write_autocmds_fired, "InsertLeave save fires BufWritePre (nested autocmd)")
vim.api.nvim_del_augroup_by_name("verify_nested_save")
vim.fn.delete(save_file)
vim.cmd("bwipeout!")

-- Guard: unnamed scratch buffers must never be auto-saved.
vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "scratch" })
vim.api.nvim_exec_autocmds("InsertLeave", { group = "auto_save" })
check(vim.bo.modified, "unnamed buffer is not auto-saved")
vim.bo.modified = false -- keep hand-rolled `-c qa` runners from hanging

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

-- Live markdown linting (plugins/markdown.lua, nvim-lint + markdownlint-cli2).
-- Wiring checks run unconditionally; the functional path needs the binary,
-- the guard path is exercised via:
--   scripts/test-without-binary.sh markdownlint-cli2 -- scripts/smoke-test.sh
vim.cmd("enew")
local md_buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(md_buf, 0, -1, false, { "not a heading" }) -- violates MD041
vim.bo.filetype = "markdown" -- ft-loads nvim-lint (if :Daily hasn't already)

local ok_lint, lint = pcall(require, "lint")
check(ok_lint, "nvim-lint loads for markdown buffers")
if ok_lint then
  for _, ev in ipairs({ "TextChanged", "TextChangedI", "InsertLeave", "BufWritePost", "BufReadPost" }) do
    local lint_aus = vim.api.nvim_get_autocmds({ group = "markdown_lint", event = ev })
    check(#lint_aus == 1, "markdown_lint has a " .. ev .. " autocmd")
  end
  check(vim.api.nvim_get_hl(0, { name = "MarkdownLintLine" }).bg ~= nil, "MarkdownLintLine highlight defines a bg")
  check(
    vim.fn.filereadable(vim.fn.stdpath("config") .. "/.markdownlint.jsonc") == 1,
    ".markdownlint.jsonc base config exists"
  )

  local warn = vim.diagnostic.severity.WARN
  local lint_ns = lint.get_namespace("markdownlint-cli2")
  local dcfg = vim.diagnostic.config(nil, lint_ns)
  check(dcfg.underline == false, "markdownlint ns: underline is off")
  check(dcfg.virtual_text == true, "markdownlint ns: virtual_text is on")
  check(dcfg.signs.linehl[warn] == "MarkdownLintLine", "markdownlint ns: linehl is MarkdownLintLine")
  check(dcfg.signs.text[warn] == "", "markdownlint ns: sign text is empty (no signcolumn shift)")

  if vim.fn.executable("markdownlint-cli2") == 1 then
    -- Functional: fire the debounced event path, wait out timer + async spawn.
    vim.api.nvim_exec_autocmds("TextChanged", { group = "markdown_lint" })
    local got = vim.wait(10000, function()
      return #vim.diagnostic.get(md_buf, { namespace = lint_ns }) > 0
    end, 50)
    check(got, "markdownlint produces diagnostics for a known violation")
    if got then
      local d = vim.diagnostic.get(md_buf, { namespace = lint_ns })[1]
      check(d.severity == warn, "markdownlint diagnostics are WARN")
      check(d.message:find("MD%d%d%d") ~= nil, "diagnostic message carries the MDxxx rule id")
      check(d.message:find("^error ") == nil, "severity word is stripped from the message")
      local sign_ns
      for name, id in pairs(vim.api.nvim_get_namespaces()) do
        if name:find("markdownlint%-cli2") and name:find("signs") then
          sign_ns = id
        end
      end
      local marks = sign_ns and vim.api.nvim_buf_get_extmarks(md_buf, sign_ns, 0, -1, { details = true }) or {}
      check(
        #marks > 0 and marks[1][4].line_hl_group == "MarkdownLintLine",
        "offending line carries the linehl extmark"
      )
      check(vim.fn.getwininfo()[1].textoff == 0, "warning does not open the signcolumn")
    end
  else
    -- Guard path: the catch-up lint during :Daily already notified once;
    -- further events must not notify again, and nothing may be spawned.
    vim.api.nvim_exec_autocmds("TextChanged", { group = "markdown_lint" })
    vim.wait(600)
    vim.api.nvim_exec_autocmds("InsertLeave", { group = "markdown_lint" })
    vim.wait(600)
    local guard_notes = 0
    for _, msg in ipairs(notifications) do
      if msg:find("markdownlint%-cli2 not found") then
        guard_notes = guard_notes + 1
      end
    end
    check(guard_notes == 1, "missing-binary guard notifies exactly once per session")
    check(#vim.diagnostic.get(md_buf, { namespace = lint_ns }) == 0, "no diagnostics attempted without the binary")
  end
end
vim.notify = orig_notify
vim.bo.modified = false -- keep hand-rolled `-c qa` runners from hanging

if failures > 0 then
  print(failures .. " smoke check(s) FAILED\n")
  vim.cmd("cquit 1")
end
print("All smoke checks passed\n")
