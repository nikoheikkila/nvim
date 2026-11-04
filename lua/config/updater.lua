-- `:Update` and the daily update check: replace a release install of this
-- configuration with the latest GitHub release, from inside Neovim. It is the
-- in-editor counterpart of scripts/install.sh, which cannot be called because
-- `scripts/` is not in the release tarball. Network and extraction run through
-- vim.system callbacks, so the editor stays responsive, and progress is one
-- progress message updated in place: a multi-line vim.notify would end in a
-- hit-enter prompt (see config/plugin_updates.lua). Pure logic lives in
-- lib/update_utils.lua; the user-facing behaviour is in docs/updating.md.
local update_utils = require("lib.update_utils")
local vale_utils = require("lib.vale_utils")

local M = {}

-- Both are also spelled out in scripts/install.sh and the package job of
-- .github/workflows/ci.yml; updater_spec fails if they drift apart.
M.REPO = "nikoheikkila/nvim"
M.ASSET = "nvim-config.tar.gz"

local running = false

---The config directory, symlinks resolved: renaming a symlink would move the
---link and leave its target behind.
---@return string
function M.root()
  local config = vim.fn.stdpath("config")
  return vim.uv.fs_realpath(config) or config
end

---The version stamped into the install at `root`, read from disk rather than
---through require(): after an update the cached module still names the old one.
---@param root string
---@return string|nil
function M.read_version(root)
  local ok, stamp = pcall(dofile, root .. "/lua/config/version.lua")
  if ok and type(stamp) == "table" and type(stamp.version) == "string" then
    return stamp.version
  end
  return nil
end

---@param root string
---@return boolean
function M.is_checkout(root)
  return vim.uv.fs_stat(root .. "/.git") ~= nil
end

---Run `cmd` asynchronously and call `cb(result)` on the main loop. A missing
---executable makes vim.system throw; it is reported like a failed command.
local function run(cmd, cb)
  local ok, err = pcall(vim.system, cmd, { text = true }, vim.schedule_wrap(cb))
  if not ok then
    vim.schedule(function()
      cb({ code = -1, stdout = "", stderr = tostring(err) })
    end)
  end
end

---The useful line of a failed command's output.
local function reason(result)
  local text = vim.trim((result.stderr ~= "" and result.stderr) or result.stdout or "")
  return text ~= "" and text or ("exit code " .. tostring(result.code))
end

-- curl's --retry skips HTTP errors, and GitHub answers a rate limit with 403.
-- --retry-all-errors (curl >= 7.71) makes those retryable, so it is
-- feature-probed exactly like install.sh does. Probed once per session.
local retry_flags
local function curl_retry_flags()
  if not retry_flags then
    retry_flags = { "--retry", "5", "--retry-max-time", "120", "--retry-connrefused" }
    local ok, help = pcall(function()
      return vim.system({ "curl", "--help", "all" }, { text = true }):wait(5000)
    end)
    if ok and help.code == 0 and (help.stdout or ""):find("--retry-all-errors", 1, true) then
      table.insert(retry_flags, "--retry-all-errors")
    end
  end
  return retry_flags
end

---`curl` with the shared timeouts and retries, then `args`.
local function curl(max_time, args, cb)
  local cmd = { "curl", "-fsSL", "--connect-timeout", "10", "--max-time", tostring(max_time) }
  vim.list_extend(cmd, curl_retry_flags())
  run(vim.list_extend(cmd, args), cb)
end

---Resolve the newest release tag from the redirect of github.com's
---releases/latest — not the REST API, whose unauthenticated rate limit answers
---403 on shared IP addresses (the same reasoning as install.sh).
---@param cb fun(tag: string|nil, err: string|nil)
function M.fetch_latest(cb)
  local url = ("https://github.com/%s/releases/latest"):format(M.REPO)
  curl(60, { "-o", "/dev/null", "-w", "%{url_effective}", url }, function(result)
    if result.code ~= 0 then
      return cb(nil, reason(result))
    end
    local tag = update_utils.tag_from_url(result.stdout)
    if not tag then
      return cb(nil, "no release found at " .. url)
    end
    cb(tag)
  end)
end

---Pinned to the resolved tag, so a release published mid-update cannot mix
---versions.
---@param tag string
---@return string
function M.asset_url(tag)
  return ("https://github.com/%s/releases/download/%s/%s"):format(M.REPO, tag, M.ASSET)
end

---The default progress reporter: one progress message, updated in place.
local function progress_reporter()
  local id
  return function(text, status, percent)
    id = vim.api.nvim_echo({ { text } }, status ~= "running", {
      id = id,
      kind = "progress",
      title = "Update",
      source = "config.updater",
      status = status,
      percent = percent,
    })
  end
end

---The paths to keep from the install at `root` (lib/update_utils.lua,
---`carry_over`), including the StylesPath its .vale.ini names.
local function kept_paths(root)
  local ini = root .. "/" .. vale_utils.CONFIG_FILE
  local styles
  if vim.fn.filereadable(ini) == 1 then
    styles = vale_utils.styles_path(table.concat(vim.fn.readfile(ini), "\n"))
  end
  return update_utils.carry_over(styles)
end

---Copy each of `paths` that exists under `from` into `to`, replacing what the
---release shipped. Local and small (four files and the Vale styles), so it runs
---synchronously.
---@return string|nil err
local function carry_over(from, to, paths)
  for _, path in ipairs(paths) do
    local src, dst = from .. "/" .. path, to .. "/" .. path
    if vim.uv.fs_stat(src) then
      vim.fn.delete(dst, "rf")
      vim.fn.mkdir(vim.fs.dirname(dst), "p")
      local result = vim.system({ "cp", "-Rp", src, dst }, { text = true }):wait()
      if result.code ~= 0 then
        return ("could not keep %s: %s"):format(path, reason(result))
      end
    end
  end
end

---Offer to restart into the new version. `:restart` restores the session
---(windows, buffers) but stops Nvim with `:qall`, which refuses while a buffer
---is modified — hence the save-first variant.
local function offer_restart(tag)
  local modified = vim.tbl_filter(function(buf)
    return vim.bo[buf].buflisted and vim.bo[buf].modified
  end, vim.api.nvim_list_bufs())
  local restart = #modified > 0 and "Save all and restart" or "Restart now"

  vim.ui.select({ restart, "Later" }, {
    prompt = ("Neovim config updated to %s. Restart to apply?"):format(tag),
  }, function(_, idx)
    if idx ~= 1 then
      return vim.notify(("Restart Neovim to finish updating to %s"):format(tag))
    end
    local ok, err = pcall(function()
      if #modified > 0 then
        vim.cmd("wall")
      end
      vim.cmd("restart")
    end)
    if not ok then
      vim.notify(("Update: could not restart — %s"):format(err), vim.log.levels.ERROR)
    end
  end)
end

---@class UpdaterRunOpts
---@field root? string config directory to update (default: M.root())
---@field force? boolean reinstall even when already up to date
---@field latest? fun(cb: fun(tag: string|nil, err: string|nil)) (default: M.fetch_latest)
---@field asset_url? fun(tag: string): string (default: M.asset_url)
---@field install_plugins? boolean pre-install plugins headlessly (default: true)
---@field report? fun(text: string, status: string, percent: integer)
---@field on_done? fun(ok: boolean, info: table)

---Update the install at `opts.root`: download, extract beside it as
---`<root>.update`, keep the user's files, then swap so `<root>` becomes the one
---rolling backup `<root>.previous`. The defaults are what `:Update` uses; the
---options let the specs run the whole flow offline against a temp dir.
---@param opts? UpdaterRunOpts
function M.run(opts)
  opts = opts or {}

  local on_done = opts.on_done or function() end
  -- Before the run starts: leaves `running` alone, since a refused second
  -- `:Update` must not clear the flag of the one in flight.
  local function refuse(level, message, why)
    vim.notify("Update: " .. message, level)
    on_done(false, { reason = why })
  end

  if running then
    return refuse(vim.log.levels.WARN, "an update is already running", "running")
  end
  local root = opts.root or M.root()
  if M.is_checkout(root) then
    return refuse(vim.log.levels.WARN, ("%s is a git checkout — update it with `git pull`"):format(root), "checkout")
  end
  for _, exe in ipairs({ "curl", "tar" }) do
    if vim.fn.executable(exe) == 0 then
      return refuse(vim.log.levels.ERROR, ("`%s` is required but not on PATH"):format(exe), "missing " .. exe)
    end
  end

  running = true
  -- Every exit of a started run goes through here, so none can leave
  -- `running` set.
  local function settle(ok, info)
    running = false
    on_done(ok, info)
  end
  local report = opts.report or progress_reporter()
  local installed = M.read_version(root)
  local staging, previous = root .. ".update", root .. ".previous"
  local archive = vim.fn.tempname() .. ".tar.gz"

  local function fail(message)
    vim.fn.delete(archive)
    vim.fn.delete(staging, "rf")
    report("Update failed: " .. message, "failed", 100)
    vim.notify("Update: " .. message, vim.log.levels.ERROR)
    settle(false, { reason = message })
  end

  local function finish(tag, plugins_ok)
    report(
      ("Updated to %s — changes: %s"):format(tag, update_utils.changes_url(M.REPO, installed, tag)),
      "success",
      100
    )
    if not plugins_ok then
      vim.notify(
        "Update: could not pre-install plugins; lazy.nvim installs them on the next start",
        vim.log.levels.WARN
      )
    end
    settle(true, { updated = true, from = installed, to = tag, previous = previous })
  end

  local function install_plugins(tag)
    if opts.install_plugins == false then
      return finish(tag, true)
    end
    report("Installing plugins…", "running", 80)
    -- The child inherits this session's environment, so it resolves the same
    -- config directory — which now holds the new release. VeryLazy never fires
    -- headless, so it cannot recurse into the update check.
    run({ vim.v.progpath, "--headless", "+Lazy! install", "+qa" }, function(result)
      finish(tag, result.code == 0)
    end)
  end

  local function swap(tag)
    -- Only now, with the new release staged and complete, is the old backup
    -- expendable.
    vim.fn.delete(previous, "rf")
    local ok, err = vim.uv.fs_rename(root, previous)
    if not ok then
      return fail(("could not move %s aside: %s"):format(root, err))
    end
    ok, err = vim.uv.fs_rename(staging, root)
    if not ok then
      vim.uv.fs_rename(previous, root)
      return fail(("could not install the new version: %s"):format(err))
    end
    install_plugins(tag)
  end

  local function stage(tag)
    report(("Installing %s…"):format(tag), "running", 55)
    vim.fn.delete(staging, "rf")
    vim.fn.mkdir(staging, "p")
    run({ "tar", "-xzf", archive, "-C", staging }, function(result)
      vim.fn.delete(archive)
      if result.code ~= 0 then
        return fail("could not extract the release: " .. reason(result))
      end
      if not vim.uv.fs_stat(staging .. "/init.lua") or M.read_version(staging) ~= tag then
        return fail(("the downloaded release does not contain version %s"):format(tag))
      end
      local err = carry_over(root, staging, kept_paths(root))
      if err then
        return fail(err)
      end
      swap(tag)
    end)
  end

  local function download(tag)
    report(("Downloading %s…"):format(tag), "running", 25)
    local url = (opts.asset_url or M.asset_url)(tag)
    curl(300, { "-o", archive, url }, function(result)
      if result.code ~= 0 then
        return fail(("could not download %s: %s"):format(url, reason(result)))
      end
      stage(tag)
    end)
  end

  report("Checking for updates…", "running", 0)
  local latest = opts.latest or M.fetch_latest
  latest(function(tag, err)
    if not tag then
      return fail("could not check for a new release: " .. tostring(err))
    end
    if not opts.force and not update_utils.is_newer(tag, installed) then
      report(("Already up to date (%s)"):format(installed), "success", 100)
      return settle(true, { updated = false, from = installed, to = tag })
    end
    download(tag)
  end)
end

---`:Update[!]`: offers a restart when a UI is attached. Headless callers see
---only the exit code, so a failure there exits non-zero — the convention
---`:ValeSync` follows.
---@param opts? { force?: boolean }
function M.update(opts)
  M.run({
    force = opts and opts.force,
    on_done = function(ok, info)
      local has_ui = #vim.api.nvim_list_uis() > 0
      if ok and info.updated and has_ui then
        offer_restart(info.to)
      elseif not ok and not has_ui then
        vim.cmd("cquit 1")
      end
    end,
  })
end

local function state_file()
  return vim.fn.stdpath("state") .. "/config-update.json"
end

local function last_check()
  local ok, state = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(state_file()), "\n"))
  end)
  return ok and type(state) == "table" and state.last_check or nil
end

---The background check: at most once per CHECK_INTERVAL, and only for a
---stamped release install with `config.updates.checkOnStartup` on. It only ever
---notifies; installing stays the user's call. Network errors stay silent — a
---laptop offline at startup is not news. Cheapest guards first: the throttle
---rejects almost every launch.
function M.check()
  local now = os.time()
  if not update_utils.should_check(last_check(), now, update_utils.CHECK_INTERVAL) then
    return
  end
  -- A git checkout carries the "dev" placeholder, which never parses, so this
  -- also keeps checkouts out (M.run guards against them separately).
  local installed = M.read_version(M.root())
  if not update_utils.parse(installed) then
    return
  end
  local paths = require("config.paths")
  local settings = update_utils.resolve_config(require("lib.yaml_utils").read_file(paths.config_file("config.yml")))
  if not settings.checkOnStartup then
    return
  end
  -- Recorded before the request, so an unreachable GitHub is retried tomorrow
  -- rather than on every launch.
  vim.fn.mkdir(vim.fs.dirname(state_file()), "p")
  vim.fn.writefile({ vim.json.encode({ last_check = now }) }, state_file())

  M.fetch_latest(function(tag)
    if tag and update_utils.is_newer(tag, installed) then
      vim.notify(("Neovim config %s is available (installed %s) — run :Update"):format(tag, installed))
    end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config_update_check", { clear = true })
  -- VeryLazy comes from UIEnter, so headless runs (the test suites, install.sh,
  -- the plugin step above) never check.
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VeryLazy",
    once = true,
    callback = function()
      vim.schedule(M.check)
    end,
  })
end

return M
