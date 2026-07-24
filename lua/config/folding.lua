-- Fold-toggle UX shared by every folding-enabled buffer: the <Tab> toggle, the
-- ▼/▶ left-gutter indicator (statuscolumn), and click-to-toggle. The fold
-- *source* differs per buffer — markdown uses markdown_foldexpr() below (pure
-- levels from lib.markdown_fold); other filetypes use the built-in
-- vim.lsp.foldexpr() when their server advertises foldingRangeProvider. Wired
-- from plugins/markdown.lua and plugins/lsp.lua. See .claude/instructions.
local markdown_fold = require("lib.markdown_fold")

local M = {}

-- Statuscolumn expression (re-evaluated per screen line with v:lnum set) and
-- the markdown foldexpr expression, referenced from Vimscript option strings.
local STATUSCOLUMN = "%!v:lua.require'config.folding'.statuscolumn()"
local ICON_OPEN, ICON_CLOSED = "▼", "▶"

-- Cache of computed markdown fold levels, keyed by buffer and invalidated by
-- changedtick, so foldexpr stays O(n) per edit instead of O(n²) per redraw.
local cache = {}

local function markdown_levels(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local entry = cache[buf]
  if not entry or entry.tick ~= tick then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    entry = { tick = tick, levels = markdown_fold.fold_levels(lines) }
    cache[buf] = entry
  end
  return entry.levels
end

-- foldexpr for markdown buffers (see :h fold-expr): returns the pre-computed
-- value for the line currently being evaluated.
function M.markdown_foldexpr()
  local levels = markdown_levels(vim.api.nvim_get_current_buf())
  return levels[vim.v.lnum] or "0"
end

-- Whether a line begins a fold. Markdown consults the authoritative ">N"
-- markers (the plain foldlevel(l) > foldlevel(l-1) heuristic misses a forced
-- start that follows a deeper line, e.g. a top-level item right after a nested
-- one). LSP folds have no such markers, so fall back to the level comparison.
local function is_fold_start(buf, lnum)
  if vim.b[buf].fold_engine == "markdown" then
    local value = markdown_levels(buf)[lnum]
    return type(value) == "string" and value:sub(1, 1) == ">"
  end
  return vim.fn.foldlevel(lnum) > vim.fn.foldlevel(lnum - 1)
end

-- The indicator glyph for a line: ▶ on a closed fold's first line, ▼ on an
-- open fold's start, nil otherwise (blank gutter). Split out so it is testable
-- with an explicit line rather than only through v:lnum.
function M.indicator(buf, lnum)
  local closed = vim.fn.foldclosed(lnum)
  if closed == lnum then
    return ICON_CLOSED
  end
  if closed == -1 and is_fold_start(buf, lnum) then
    return ICON_OPEN
  end
  return nil
end

local function labeled(icon)
  -- Click region → on_click; FoldColumn highlight (theme-driven, no hardcoded
  -- color); trailing space keeps every gutter two cells wide.
  return "%@v:lua.require'config.folding'.on_click@%#FoldColumn#" .. icon .. "%*%X "
end

-- Custom statuscolumn replaces Neovim's built-in one entirely, so the number
-- column has to be rebuilt here too — "%l" is the standard number-column item,
-- padded to 'numberwidth' so it right-aligns the way Neovim's own does.
local function number_column()
  if not vim.wo.number then
    return ""
  end
  return "%" .. (vim.wo.numberwidth - 1) .. "l "
end

function M.statuscolumn()
  local suffix
  -- Wrapped/virtual screen rows repeat the same v:lnum; only label the first.
  if vim.v.virtnum and vim.v.virtnum ~= 0 then
    suffix = "  "
  else
    local icon = M.indicator(vim.api.nvim_get_current_buf(), vim.v.lnum)
    suffix = icon and labeled(icon) or "  "
  end
  return number_column() .. suffix
end

-- Toggle the fold at `lnum` (open↔closed). Used by both the click handler and
-- tests.
function M.toggle_at(lnum)
  if not lnum or lnum <= 0 or vim.fn.foldlevel(lnum) <= 0 then
    return
  end
  local cmd = (vim.fn.foldclosed(lnum) ~= -1) and "foldopen" or "foldclose"
  pcall(vim.cmd, lnum .. cmd)
end

-- Clicking a ▼/▶ toggles that fold. The statuscolumn click passes no line, so
-- resolve it from the mouse position.
function M.on_click()
  M.toggle_at(vim.fn.getmousepos().line)
end

local function toggle_fold()
  if vim.fn.foldlevel(".") > 0 then
    vim.cmd("normal! za")
  end
end

-- Enable folding for `buf`. `opts.engine` ("markdown" | "lsp") selects the
-- indicator's fold-start detection; `opts.foldexpr`/`opts.foldtext` are the
-- Vimscript option strings for the chosen source. Idempotent.
function M.enable(buf, opts)
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= buf then
    win = vim.fn.bufwinid(buf)
  end

  vim.b[buf].fold_engine = opts.engine

  if win ~= -1 then
    vim.wo[win].foldmethod = "expr"
    vim.wo[win].foldexpr = opts.foldexpr
    vim.wo[win].foldtext = opts.foldtext or ""
    vim.wo[win].foldenable = true
    vim.wo[win].foldlevel = 99 -- start fully expanded (every indicator ▼)
    vim.wo[win].statuscolumn = STATUSCOLUMN
    vim.wo[win].fillchars = "fold: " -- drop the default trailing "···"
  end

  vim.keymap.set("n", "<Tab>", toggle_fold, { buffer = buf, desc = "Toggle fold" })
end

vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
  group = vim.api.nvim_create_augroup("markdown_fold_cache", { clear = true }),
  callback = function(ev)
    cache[ev.buf] = nil
  end,
})

return M
