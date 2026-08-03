local M = {}

-- nil = not looked yet, false = looked and there was no directory argument.
local startup_dir

-- Absolute path of `raw` when it names a directory that exists, else nil. A file
-- argument (`nvim README.md`), a path that doesn't exist yet (`nvim newdir/`),
-- and no argument at all each return nil, so `root()` falls through to its next
-- tier rather than treating any of them as an error.
--
-- `:p` absolutises because argv() hands back the path as typed, shortened
-- against the startup cwd ("notes", not "/home/me/notes"). vim.fs.normalize drops
-- the trailing slash `nvim <directory>/` leaves behind. vim.fn.resolve is
-- deliberately NOT called: a symlinked directory keeps the name that was typed,
-- which is also the name Neovim gives the buffer it opens for the argument.
function M.detect(raw)
  if raw == nil or raw == "" then
    return nil
  end

  local path = vim.fs.normalize(vim.fn.fnamemodify(raw, ":p"))
  if vim.fn.isdirectory(path) == 0 then
    return nil
  end

  return path
end

-- The directory Neovim was started with (`nvim <directory>`), or nil when it was
-- started bare or on a file. Only argv(0) is consulted -- the first argument is
-- the one Neovim opens first, so `nvim <dir1> <dir2>` scopes to <dir1>.
--
-- Memoised to pin the scope for the session: `:args`/`:argadd` rewrite the
-- arglist, and the project should not move out from under the picker when they
-- do. (It is *not* needed to survive the chdir in config/autocmds.lua -- Neovim
-- re-expands arglist entries against the new cwd, so a relative argument still
-- resolves correctly afterwards.)
function M.startup_dir()
  if startup_dir == nil then
    startup_dir = M.detect(vim.fn.argv(0)) or false
  end
  return startup_dir or nil
end

-- Directory a project-scoped tool (file picker, grep) should work in: a directory
-- argument first, then the Git repository enclosing the current buffer, then
-- Neovim's cwd. The argument outranks the repo on purpose -- naming a directory
-- states which tree to work in, so `nvim ~/monorepo/packages/api` searches the
-- package rather than the whole monorepo.
--
-- Only the first tier is frozen; the other two are re-derived per call, so a
-- session started without a directory argument tracks the current buffer and
-- `:cd` exactly as it did before this module existed. The chain is lazy, so a
-- session that has a directory argument never pays for the upward `.git` walk.
function M.root()
  return M.startup_dir() or vim.fs.root(0, { ".git" }) or vim.uv.cwd()
end

return M
