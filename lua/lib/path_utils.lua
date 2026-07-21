local M = {}

-- Returns true when name looks like a URI scheme (e.g. "oil://", "scp://host/file").
-- Used to skip non-file buffers when auto-creating parent directories on save.
function M.has_uri_scheme(name)
  return name:match("^%w%w+://") ~= nil
end

-- Classifies a markdown link target for navigation:
--   "external" — a scheme://… URL to open in the browser
--   "ignored"  — a bare #anchor or single-colon scheme (mailto:, tel:, …)
--   "internal" — a relative/absolute file path to open in a buffer
function M.classify_link(target)
  if target:sub(1, 1) == "#" then
    return "ignored"
  end
  if M.has_uri_scheme(target) then
    return "external"
  end
  if target:match("^%a[%w+.%-]*:") then
    return "ignored"
  end
  return "internal"
end

-- Strips a trailing #anchor fragment from a link target ("notes.md#top" → "notes.md").
function M.strip_anchor(target)
  return (target:gsub("#.*$", ""))
end

return M
