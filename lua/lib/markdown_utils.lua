local M = {}

-- Scans line for markdown image spans (![alt](target)) and returns the target of
-- the one that col (1-based) falls inside, or nil when col is outside every
-- span. Trailing title attributes are stripped. The leading "!" is absorbed into
-- the span, so the cursor-on-bang case still resolves to the image.
function M.find_image_path_at(line, col)
  local pos = 1
  while pos <= #line do
    local s = line:find("%[", pos)
    if not s then
      break
    end

    -- A "[" not preceded by "!" opens a plain inline link, never an image.
    if s > 1 and line:sub(s - 1, s - 1) == "!" then
      s = s - 1

      local cb = line:find("%]%(", s)
      if not cb then
        break
      end

      local cp = line:find(")", cb + 2, true)
      if not cp then
        break
      end

      if col >= s and col <= cp then
        local raw = line:sub(cb + 2, cp - 1)
        return raw:match("^([^%s\"']+)")
      end

      pos = cp + 1
    else
      pos = s + 1
    end
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
  if line == "" then
    return line
  end

  if line:match("^%s*[%-%+%*]%s+%[.?%]") then
    return (
      line:gsub("%[(.?)%]", function(state)
        return (state == "x" or state == "X") and "[ ]" or "[x]"
      end, 1)
    )
  elseif line:match("^%s*[%-%+%*]%s") then
    return (line:gsub("^(%s*[%-%+%*]%s+)", "%1[ ] ", 1))
  else
    local indent = line:match("^(%s*)") or ""
    local content = line:match("^%s*(.*)") or ""
    return indent .. "- [ ] " .. content
  end
end

return M
