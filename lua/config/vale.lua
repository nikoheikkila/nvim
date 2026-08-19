-- Vale's client-side plumbing: the resolved initializationOptions for vale_ls,
-- the shipped .vale.ini fallback and the gate deciding whether it is usable, and
-- the per-client hook that lets a project's own config win.
--
-- Lives here rather than inline in config/lsp_servers.lua for two reasons: that
-- file is a declarative servers table, and the gate needs to be callable on its
-- own so a spec can drive both its branches. config/commands.lua asks this
-- module for the config path instead of reaching through the servers table.
-- lib/vale_utils.lua stays vim-free; everything needing vim.fn is here.
local paths = require("config.paths")
local vale_utils = require("lib.vale_utils")
local yaml_utils = require("lib.yaml_utils")

local M = {}

-- Absolute path of the .vale.ini shipped beside config.yml. Says nothing about
-- whether it exists.
function M.shipped_config()
  return paths.config_file(vale_utils.CONFIG_FILE)
end

-- Vet `ini` for use as Vale's --config, returning the path when it is usable or
-- nil plus a reason when it is not.
--
-- A missing file is silent: deleting the shipped .vale.ini is how you opt out
-- and hand config discovery back to Vale. Missing styles are not, because the
-- file promises a directory that is one command away from existing — and Vale
-- aborts with E201 on *every* lint while a declared StylesPath is absent, each
-- abort arriving as an LSP showMessage error popup. A relative StylesPath
-- resolves against the .vale.ini rather than the cwd, hence the join.
function M.vet_config(ini)
  if vim.fn.filereadable(ini) == 0 then
    return nil
  end
  local styles = vale_utils.styles_path(table.concat(vim.fn.readfile(ini), "\n"))
  if styles and vim.fn.isdirectory(vim.fs.joinpath(vim.fs.dirname(ini), styles)) == 0 then
    return nil, "Vale: style packages are not installed yet — run :ValeSync once to fetch them"
  end
  return ini
end

-- initializationOptions for vale_ls, resolved from config.yml (`config.vale.*`)
-- and memoized: config/lsp_servers.lua hands the table to the server and
-- config/commands.lua reads the same one, so the two cannot disagree, and the
-- file I/O happens once per session.
local resolved

function M.init_options()
  if resolved then
    return resolved
  end

  local config = yaml_utils.read_file(paths.config_file("config.yml"))
  resolved = vale_utils.resolve_config(config)
  -- vale-ls resolves neither "~" nor "$VAR"; config.yml uses the latter style
  -- elsewhere (config.obsidian.vault). Expanding at this vim-side seam keeps
  -- lib/vale_utils.lua free of vim.
  for _, key in ipairs(vale_utils.OPTIONAL_PATHS) do
    if resolved[key] then
      resolved[key] = vim.fn.expand(resolved[key])
    end
  end

  -- Fall back to the shipped .vale.ini, so Vale has a config in every prose
  -- buffer the way Harper needs none — without one it reports nothing at all.
  if not resolved.configPath then
    local path, reason = M.vet_config(M.shipped_config())
    resolved.configPath = path
    if reason then
      -- Scheduled because the first caller is plugins/lsp.lua's config(), which
      -- can run before the UI is ready to show a message. Memoization above
      -- keeps it to once per session.
      vim.schedule(function()
        vim.notify(reason, vim.log.levels.WARN)
      end)
    end
  end

  return resolved
end

-- Which .vale.ini :ValeSync and :ValeConfig act on, plus whether the running
-- server actually got it. False means the server started without one, and since
-- nothing re-resolves that mid-session, a sync now only takes effect after a
-- restart.
--
-- The fallback to the shipped file even when the gate rejected it is the point:
-- the gate rejects *because* the styles are missing, which is exactly when
-- :ValeSync is needed. Nil only when there is no shipped file either.
function M.config_path()
  local configured = M.init_options().configPath
  if configured then
    return configured, true
  end
  local shipped = M.shipped_config()
  return (vim.fn.filereadable(shipped) == 1 and shipped or nil), false
end

-- Vale's --config is a full replacement, not a base the project's own file
-- layers onto (unlike markdownlint-cli2's). root_markers is { ".vale.ini" }, so
-- a resolved root_dir means exactly "this project ships one" — drop our fallback
-- there and let Vale find the project's by walking up from the document.
-- Everywhere else the fallback is what makes Vale work at all.
--
-- Mutate the field, never replace init_options: vim/lsp/client.lua has already
-- aliased the table into initializationOptions by the time this runs, so a fresh
-- table would never reach the server. Safe to mutate because vim/lsp.lua
-- deep-copies the config per activation.
function M.before_init(_, client_config)
  if client_config.root_dir and client_config.init_options then
    client_config.init_options.configPath = ""
  end
end

return M
