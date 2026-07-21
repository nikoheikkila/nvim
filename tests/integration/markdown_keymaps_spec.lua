-- Buffer-local markdown keymap wiring (plugins/markdown.lua), run inside headless
-- Neovim. Lazy-loaded plugins don't self-load in --headless, so force-load
-- markdown-plus before its FileType autocmd can wire the buffer-local maps.
describe("markdown link navigation", function()
  setup(function()
    require("lazy").load({ plugins = { "markdown-plus.nvim" } })
  end)

  -- Fresh markdown buffer whose FileType event has run setup_keymaps on the window.
  local function markdown_buf(lines)
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo.filetype = "markdown"
    return buf
  end

  -- The <leader>gl mapping stores its handler as the map's Lua callback, so we can
  -- invoke the dispatch logic directly instead of feeding keys.
  local function gl_callback()
    return vim.fn.maparg(vim.g.mapleader .. "gl", "n", false, true).callback
  end

  describe("keymap registration", function()
    local buf
    setup(function()
      buf = markdown_buf({ "[text](target.md)" })
    end)
    teardown(function()
      vim.cmd("bwipeout! " .. buf)
    end)

    it("binds <leader>gl buffer-local in normal mode", function()
      local map = vim.fn.maparg(vim.g.mapleader .. "gl", "n", false, true)
      assert.equal("Open link under cursor", map.desc)
      assert.equal(1, map.buffer)
    end)
  end)

  describe("dispatch", function()
    local buf, orig_open, opened

    before_each(function()
      opened = nil
      orig_open = vim.ui.open
      vim.ui.open = function(target)
        opened = target
      end
    end)

    after_each(function()
      vim.ui.open = orig_open
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(b) then
          pcall(vim.cmd, "bwipeout! " .. b)
        end
      end
    end)

    it("opens an external URL in the browser", function()
      buf = markdown_buf({ "[ext](https://example.com)" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      gl_callback()()
      assert.equal("https://example.com", opened)
    end)

    it("ignores a mailto link without opening or navigating", function()
      buf = markdown_buf({ "[mail](mailto:x@y.com)" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      gl_callback()()
      assert.is_nil(opened)
      assert.equal(buf, vim.api.nvim_get_current_buf())
    end)

    it("opens an internal file in a buffer", function()
      -- Absolute path to a real repo file, so resolution needs no saved buffer.
      local target = vim.fn.getcwd() .. "/README.md"
      buf = markdown_buf({ "[int](" .. target .. ")" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      gl_callback()()
      assert.is_nil(opened)
      assert.equal(vim.fn.fnamemodify(target, ":p"), vim.api.nvim_buf_get_name(0))
    end)
  end)
end)
