-- Pure-Lua fold-level computation for markdown buffers. No Neovim API — the
-- Neovim glue (foldexpr wrapper, statuscolumn, caching) lives in
-- lua/config/folding.lua. Unit-tested in tests/unit/markdown_fold_spec.lua.
--
-- fold_levels(lines) returns one 'foldexpr' value per line (see :h fold-expr):
--   ">N"   start a fold of level N (forced — also ends a same/deeper fold)
--   "N"    plain level N (only auto-starts a fold when N > the previous level)
--   "="    same level as the previous line (used for blank lines)
--
-- Foldable constructs, each emitting a ">N" start so the glue can mark it with
-- a ▼/▶ indicator:
--   * ATX headings (level = number of leading '#')
--   * list items that have children — unordered (-/+/*), ordered (1./1)), and
--     task (- [ ]) alike; a task is just a list item, no special case
--   * fenced code blocks (``` or ~~~)
-- Leaf list items take their parent's level so they stay inside the parent fold
-- without becoming folds of their own.
local M = {}

local function indent_of(line)
  return #(line:match("^(%s*)") or "")
end

-- Returns the fence marker char ("`" or "~") when the line opens/continues a
-- fenced code block delimiter, else nil. Matches ``` optionally followed by an
-- info string (e.g. ```lua).
local function fence_marker(line)
  local body = line:match("^%s*(.*)$") or ""
  local ticks = body:match("^(`+)")
  if ticks and #ticks >= 3 then
    return "`", #ticks
  end
  local tildes = body:match("^(~+)")
  if tildes and #tildes >= 3 then
    return "~", #tildes
  end
  return nil
end

-- A closing fence is a run of >= the opening length of the same marker with
-- nothing but optional surrounding whitespace.
local function closes_fence(line, marker, len)
  local run = line:match("^%s*([" .. marker .. "]+)%s*$")
  return run ~= nil and #run >= len
end

local function is_list_item(line)
  return line:match("^%s*[%-%+%*]%s") ~= nil or line:match("^%s*%d+[%.%)]%s") ~= nil
end

-- True when a following non-blank line is indented deeper than `ind` before the
-- list dedents back to `ind` or shallower — i.e. the item at line `i` owns a
-- subtree (nested items or wrapped content) and should be foldable.
local function has_children(lines, i, ind)
  for j = i + 1, #lines do
    local l = lines[j]
    if not l:match("^%s*$") then
      return indent_of(l) > ind
    end
  end
  return false
end

function M.fold_levels(lines)
  local out = {}
  local heading = 0 -- current section level (0 before any heading)
  local list_stack = {} -- indent widths of currently-open list ancestors
  local in_fence, fmarker, flen, fbase = false, nil, nil, 0

  for i = 1, #lines do
    local line = lines[i]

    if in_fence then
      out[i] = tostring(fbase + 1)
      if closes_fence(line, fmarker, flen) then
        in_fence = false
      end
    elseif line:match("^%s*$") then
      out[i] = "="
    else
      local ind = indent_of(line)
      local hashes = line:match("^(#+)%s")
      local fm, fl = fence_marker(line)

      if hashes and #hashes <= 6 and ind == 0 then
        heading = #hashes
        list_stack = {}
        out[i] = ">" .. heading
      elseif fm then
        if ind == 0 then
          list_stack = {}
        end
        fbase = heading + #list_stack
        in_fence, fmarker, flen = true, fm, fl
        out[i] = ">" .. (fbase + 1)
      elseif is_list_item(line) then
        while #list_stack > 0 and list_stack[#list_stack] >= ind do
          table.remove(list_stack)
        end
        table.insert(list_stack, ind)
        local depth = #list_stack - 1
        if has_children(lines, i, ind) then
          -- Parent: forced start one level below its own depth, so leaf
          -- children (which sit at heading+depth) fall inside this fold.
          out[i] = ">" .. (heading + depth + 1)
        else
          out[i] = tostring(heading + depth)
        end
      elseif ind == 0 then
        list_stack = {}
        out[i] = tostring(heading)
      else
        -- Indented non-list line: wrapped continuation of the current item;
        -- keep it inside that item's fold.
        out[i] = tostring(heading + #list_stack)
      end
    end
  end

  return out
end

return M
