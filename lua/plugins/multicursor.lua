-- Multi-cursor editing with REAL-TIME updates at every cursor while typing.
-- multiple-cursors.nvim simulates whitelisted commands at each virtual cursor
-- (insert-mode text is mirrored live via InsertCharPre/TextChangedI); the
-- trade-off is that normal-mode commands outside its whitelist only affect the
-- real cursor. Chosen over jake-stewart/multicursor.nvim, whose insert-mode
-- edits appear at other cursors only on leaving insert mode (upstream wontfix).

-- In linewise visual mode, put a cursor on every selected line, then run
-- `key` ("I" or "A") through the plugin's active keymaps so all cursors enter
-- insert at the line start / end together.
local function visual_cursors_then(key)
  return function()
    if vim.fn.line("v") == vim.fn.line(".") then
      -- Single-line selection: AddVisualArea would be a no-op, so fall back
      -- to plain insert/append on that line.
      vim.api.nvim_feedkeys(vim.keycode("<Esc>") .. key, "n", false)
      return
    end
    -- AddVisualArea places a cursor on each selected line and queues an <Esc>
    -- to leave visual mode; queue the insert key after it WITH remapping so
    -- the plugin's whitelist I/A handler runs for every cursor.
    vim.cmd("MultipleCursorsAddVisualArea")
    vim.api.nvim_feedkeys(key, "m", false)
  end
end

return {
  {
    "brenton-leighton/multiple-cursors.nvim",
    version = "*",
    opts = function()
      -- Plain click resets cursors: the plugin has no built-in for this, so
      -- buffer-local <LeftMouse> maps exist only while cursors are active
      -- (pre_hook on first cursor, post_hook on exit).
      local click_buf
      return {
        pre_hook = function()
          click_buf = vim.api.nvim_get_current_buf()
          vim.keymap.set("n", "<LeftMouse>", function()
            require("multiple-cursors").deinit(true)
            -- "n" = noremap: the re-fed key runs the built-in click, and
            -- Neovim retains the mouse event's coordinates, so the cursor
            -- lands where clicked.
            vim.api.nvim_feedkeys(vim.keycode("<LeftMouse>"), "n", false)
          end, { buffer = click_buf, desc = "Reset cursors, then normal click" })
          vim.keymap.set({ "i", "x" }, "<LeftMouse>", function()
            -- Remap-fed <Esc> runs the plugin's insert/visual escape handler
            -- (finalizing this insert at every cursor); the click then hits
            -- the normal-mode map above, which resets and re-clicks.
            vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "m", false)
            vim.api.nvim_feedkeys(vim.keycode("<LeftMouse>"), "m", false)
          end, { buffer = click_buf, desc = "Leave insert/visual, then reset cursors" })
        end,
        post_hook = function()
          if click_buf and vim.api.nvim_buf_is_valid(click_buf) then
            pcall(vim.keymap.del, "n", "<LeftMouse>", { buffer = click_buf })
            pcall(vim.keymap.del, { "i", "x" }, "<LeftMouse>", { buffer = click_buf })
          end
          click_buf = nil
        end,
      }
    end,
    keys = {
      { "<M-S-Up>", "<Cmd>MultipleCursorsAddUp<CR>", mode = { "n", "x", "i" }, desc = "Add cursor above" },
      { "<M-S-Down>", "<Cmd>MultipleCursorsAddDown<CR>", mode = { "n", "x", "i" }, desc = "Add cursor below" },
      -- macOS synthesizes a right-click from Ctrl+click (trackpad), and some
      -- terminals (Warp) drop the Ctrl modifier from mouse reports entirely —
      -- so Ctrl+click can arrive as <C-LeftMouse>, <C-RightMouse>, or a bare
      -- <RightMouse>. Bind all three; plain right-click has no other job here
      -- (options.lua disables the popup menu via mousemodel).
      {
        "<C-LeftMouse>",
        "<Cmd>MultipleCursorsMouseAddDelete<CR>",
        mode = { "n", "i" },
        desc = "Add or remove cursor at mouse click",
      },
      {
        "<C-RightMouse>",
        "<Cmd>MultipleCursorsMouseAddDelete<CR>",
        mode = { "n", "i" },
        desc = "Add or remove cursor at mouse click",
      },
      {
        "<RightMouse>",
        "<Cmd>MultipleCursorsMouseAddDelete<CR>",
        mode = { "n", "i" },
        desc = "Add or remove cursor at mouse click",
      },
      { "I", visual_cursors_then("I"), mode = "x", desc = "Insert at start of selected lines" },
      { "A", visual_cursors_then("A"), mode = "x", desc = "Append at end of selected lines" },
    },
  },
}
