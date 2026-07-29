-- Buffer plumbing for the AMA title-case operator. The rules themselves live in
-- lib/title_case.lua, which is pure Lua and unit-tested outside Neovim; this
-- file only turns a motion or a visual selection into a range and writes the
-- transformed text back. Keymaps are in config/keymaps.lua.

local title_case = require("lib.title_case")

local M = {}

-- Convert the INCLUSIVE byte column of a Vim mark into the EXCLUSIVE end column
-- nvim_buf_get_text wants. Two things go wrong without this: a multibyte final
-- character gets sliced mid-sequence (col + 1 lands inside it), and the huge
-- sentinel column that linewise and $-extended ranges report overruns the line.
-- str_utf_end is 1-indexed and returns the bytes remaining in the codepoint.
-- Callers that already hold the row's text pass it in to save a second fetch.
local function exclusive_end(row, col, line)
  line = line or vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1] or ""
  if col >= #line then
    return #line
  end
  return col + 1 + vim.str_utf_end(line, col + 1)
end

local function transform_charwise(start_row, start_col, end_row, end_col)
  local text = table.concat(vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {}), "\n")
  local cased = vim.split(title_case.transform(text), "\n", { plain = true })
  vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, cased)
end

local function transform_linewise(start_row, end_row)
  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
  for index, line in ipairs(lines) do
    lines[index] = title_case.transform_line(line)
  end
  vim.api.nvim_buf_set_lines(0, start_row, end_row + 1, false, lines)
end

-- A blockwise range is one column span per row, so each row is transformed on
-- its own and clamped: the block can reach past the end of a short line.
local function transform_blockwise(start_row, start_col, end_row, end_col)
  for row = start_row, end_row do
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1] or ""
    local from = math.min(start_col, #line)
    local to = exclusive_end(row, end_col, line)
    if to > from then
      transform_charwise(row, from, row, to)
    end
  end
end

-- Title-case the range between two (1-indexed row, 0-indexed byte col) marks.
local function transform_range(motion, start_mark, end_mark)
  local start_row, start_col = start_mark[1] - 1, start_mark[2]
  local end_row, end_col = end_mark[1] - 1, end_mark[2]

  if motion == "line" then
    transform_linewise(start_row, end_row)
  elseif motion == "block" then
    transform_blockwise(start_row, start_col, end_row, end_col)
  else
    transform_charwise(start_row, start_col, end_row, exclusive_end(end_row, end_col))
  end
end

-- 'operatorfunc' entry point for the gt operator: g@ has just set the [ and ]
-- marks around the text the motion covered. Reached through v:lua, so it must
-- stay a plain field on the returned module table.
function M.opfunc(motion)
  transform_range(motion, vim.api.nvim_buf_get_mark(0, "["), vim.api.nvim_buf_get_mark(0, "]"))
end

-- Visual-mode entry point. Called after the mapping has left visual mode, which
-- is what makes the < and > marks and visualmode() describe the selection.
function M.visual()
  local visual = vim.fn.visualmode()
  local motion = "char"
  if visual == "V" then
    motion = "line"
  elseif visual == vim.keycode("<C-v>") then
    motion = "block"
  end
  transform_range(motion, vim.api.nvim_buf_get_mark(0, "<"), vim.api.nvim_buf_get_mark(0, ">"))
end

return M
