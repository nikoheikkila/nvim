local M = {}

-- Returns nil when col is outside any image span. Strips trailing title attributes.
function M.find_image_path_at(line, col)
  local pos = 1
  while pos <= #line do
    local s = line:find("!%[", pos)
    if not s then break end

    local cb = line:find("%]%(", s)
    if not cb then break end

    local cp = line:find(")", cb + 2, true)
    if not cp then break end

    if col >= s and col <= cp then
      local raw = line:sub(cb + 2, cp - 1)
      return raw:match("^([^%s\"']+)")
    end

    pos = cp + 1
  end
  return nil
end

function M.is_remote_url(path)
  return path:match("^https?://") ~= nil
end

-- E.g. replace_filename("images/foo.png", "bar.png") → "images/bar.png"
function M.replace_filename(path, new_name)
  return (path:gsub("([^/]+)$", new_name, 1))
end

-- Return a transformed copy of line with its checklist state toggled:
--   checklist item  →  toggle [ ] ↔ [x]
--   bare list item  →  insert [ ] after the marker
--   plain line      →  prepend "- [ ] " (indentation preserved)
-- Returns the original line unchanged when it is empty.
function M.toggle_checklist_line(line)
  if line == "" then return line end

  if line:match("^%s*[%-%+%*]%s+%[.?%]") then
    return (line:gsub("%[(.?)%]", function(state)
      return (state == "x" or state == "X") and "[ ]" or "[x]"
    end, 1))
  elseif line:match("^%s*[%-%+%*]%s") then
    return (line:gsub("^(%s*[%-%+%*]%s+)", "%1[ ] ", 1))
  else
    local indent = line:match("^(%s*)") or ""
    local content = line:match("^%s*(.*)") or ""
    return indent .. "- [ ] " .. content
  end
end

return M
