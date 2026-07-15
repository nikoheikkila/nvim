-- Diagnose which key and mouse events actually reach Neovim — terminals and
-- the OS rewrite or swallow events before Neovim sees them (macOS turns
-- Ctrl+click into a right-click; Warp strips the Ctrl modifier from mouse
-- reports; Mission Control eats <C-Up>/<C-Down>). When a mapping "doesn't
-- work", check what arrives before debugging the config.
--
-- Usage (inside a running Neovim):
--   :luafile scripts/debug-keys.lua
-- Then press the key or click — every received event is shown via vim.notify
-- as Neovim key notation (e.g. <RightMouse>, <C-LeftMouse>, <M-S-Up>).
-- Run again to stop logging.
--
-- Plain characters are skipped to keep typing usable; only special keys
-- (anything keytrans() renders in <...> notation) are reported.

local ns = vim.api.nvim_create_namespace("debug-keys")

if vim.g.debug_keys_active then
  vim.on_key(nil, ns)
  vim.g.debug_keys_active = false
  vim.notify("debug-keys: stopped")
  return
end

vim.on_key(function(key)
  local ok, name = pcall(vim.fn.keytrans, key)
  if ok and name:find("^<") then
    vim.notify("debug-keys: " .. name)
  end
end, ns)

vim.g.debug_keys_active = true
vim.notify("debug-keys: logging special keys and mouse events (run again to stop)")
