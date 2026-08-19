# Neovim Patterns Reference

## Contents

- [Neovim Plugin Setup](#neovim-plugin-setup)

## Neovim Plugin Setup

```lua
local api, keymap = vim.api, vim.keymap
local M = {}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", { enabled = true, width = 80 }, opts or {})
  if not opts.enabled then return end

  local group = api.nvim_create_augroup("MyPlugin", { clear = true })
  api.nvim_create_autocmd("BufWritePre", {
    group = group, pattern = "*.lua",
    callback = function(ev)
      local lines = api.nvim_buf_get_lines(ev.buf, 0, -1, false)
      for i, line in ipairs(lines) do lines[i] = line:gsub("%s+$", "") end
      api.nvim_buf_set_lines(ev.buf, 0, -1, false, lines)
    end,
  })

  keymap.set("n", "<leader>mp", function()
    vim.notify("MyPlugin activated", vim.log.levels.INFO)
  end, { desc = "Activate MyPlugin" })
end

return M
```
