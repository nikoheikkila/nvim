-- Busted helper (wired via .busted): loaded once inside the headless Neovim
-- before any integration spec runs.
--
-- Records every vim.notify message from the start of the session: the
-- missing-binary guard in plugins/markdown.lua notifies when nvim-lint first
-- ft-loads, which happens in whichever spec file first opens a markdown
-- buffer (e.g. :Daily in commands_spec) — not necessarily the spec that
-- asserts on it (markdown_lint_spec).
local log = {}

-- selene: allow(global_usage) -- _G is the only channel shared between the helper and specs
_G.__notify_log = log

local orig_notify = vim.notify
vim.notify = function(msg, ...)
  table.insert(log, tostring(msg))
  return orig_notify(msg, ...)
end
