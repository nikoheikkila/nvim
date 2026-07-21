local M = {}

-- Scans line for markdown link spans and returns the target of the one that col
-- (1-based) falls inside, or nil when col is outside every span. Trailing title
-- attributes are stripped. When images_only is true only image spans
-- (![...](...)) match; otherwise both inline links and images match (a leading
-- "!" is absorbed so the cursor-on-bang case still resolves to the image).
local function find_span_target(line, col, images_only)
  local pos = 1
  while pos <= #line do
    local s = line:find("%[", pos)
    if not s then
      break
    end

    local is_image = s > 1 and line:sub(s - 1, s - 1) == "!"
    if images_only and not is_image then
      pos = s + 1
    else
      if is_image then
        s = s - 1
      end

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
    end
  end
  return nil
end

-- Returns nil when col is outside any image span. Strips trailing title attributes.
function M.find_image_path_at(line, col)
  return find_span_target(line, col, true)
end

-- Returns the target of the markdown link span (inline [text](target) or image
-- ![alt](target)) that col (1-based) falls inside, or nil when col is outside
-- every span. Strips trailing title attributes like find_image_path_at does.
function M.find_link_at(line, col)
  return find_span_target(line, col, false)
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
