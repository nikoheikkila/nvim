-- Busted helper (wired via .busted): loaded once inside the headless Neovim
-- before any integration spec runs.
--
-- Records every vim.notify message from the start of the session: the
-- missing-binary guard in plugins/markdown.lua notifies when nvim-lint first
-- ft-loads, which happens in whichever spec file first opens a markdown
-- buffer (e.g. folding_spec's scratch notes) — not necessarily the spec that
-- asserts on it (markdown_lint_spec). Specs read the log with
-- require("notify_log").
--
-- Capturing REPLACES vim.notify rather than wrapping it: the suite's stdout is
-- the test report, and a passed-through notification prints into it. That noise
-- reads as a failing run in CI logs and buries busted's own output, so the
-- default is silence and the log is the only way to observe a notification.
-- Assert on the log; nothing in the suite should ever reach the terminal.
local log = {}
package.loaded["notify_log"] = log

vim.notify = function(msg)
  table.insert(log, tostring(msg))
end
