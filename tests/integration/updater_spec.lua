-- `:Update` (config/updater.lua). The whole flow runs offline: the latest tag is
-- stubbed, the tarball is a fixture built here and served through a file://
-- URL, and the install being updated is a throwaway directory — never this
-- repository, which the git-checkout guard refuses anyway.
local updater = require("config.updater")
local update_utils = require("lib.update_utils")
local notify_log = require("notify_log")

local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local file = assert(io.open(path, "w"))
  file:write(text)
  file:close()
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return text
end

local function stamp(version)
  return ('return { version = "%s" }\n'):format(version)
end

---Build a release tarball for `tag` and return its file:// URL.
local function release(dir, tag)
  local tree = dir .. "/tree-" .. tag
  write(tree .. "/init.lua", "-- release " .. tag .. "\n")
  write(tree .. "/lua/config/version.lua", stamp(tag))
  write(tree .. "/config.yml", "release config\n")
  write(tree .. "/theme.yml", "release theme\n")
  write(tree .. "/.vale.ini", "StylesPath = vale-styles\n")
  local archive = dir .. "/" .. tag .. ".tar.gz"
  local result = vim.system({ "tar", "-czf", archive, "-C", tree, "." }):wait()
  assert(result.code == 0, result.stderr)
  return "file://" .. archive
end

---Run the updater to completion, latching on its on_done callback.
local function update(opts)
  local done, ok, info = false, nil, nil
  opts.report = opts.report or function() end
  opts.install_plugins = false
  opts.on_done = function(success, details)
    done, ok, info = true, success, details
  end
  updater.run(opts)
  assert(
    vim.wait(20000, function()
      return done
    end),
    "updater never finished"
  )
  return ok, info
end

local function latest(tag)
  return function(cb)
    cb(tag)
  end
end

describe("config.updater", function()
  it("defines :Update with a bang to force a reinstall", function()
    local cmd = vim.api.nvim_get_commands({}).Update
    assert.is_not_nil(cmd)
    assert.is_true(cmd.bang)
  end)

  it("checks for a new release on VeryLazy", function()
    local autocmds = vim.api.nvim_get_autocmds({ group = "config_update_check", event = "User" })
    assert.equal(1, #autocmds)
    assert.equal("VeryLazy", autocmds[1].pattern)
  end)

  it("reads config.updates.checkOnStartup from config.yml", function()
    local paths = require("config.paths")
    local parsed = require("lib.yaml_utils").read_file(paths.config_file("config.yml"))
    -- The fixture's sentinel is the opposite of the shipped default.
    assert.is_false(update_utils.resolve_config(parsed).checkOnStartup)
  end)

  it("ships the dev placeholder in the repository", function()
    assert.equal("dev", require("config.version").version)
    assert.equal("dev", updater.read_version(updater.root()))
  end)

  it("refuses to touch a git checkout", function()
    local checkout = vim.fn.tempname()
    vim.fn.mkdir(checkout .. "/.git", "p")
    local asked = false
    local ok, info = update({
      root = checkout,
      latest = function(cb)
        asked = true
        cb(nil, "stopped by the spec")
      end,
    })
    vim.fn.delete(checkout, "rf")
    assert.is_false(ok)
    assert.equal("checkout", info.reason)
    assert.is_false(asked)
  end)

  it("refuses a second update while one is running, without cancelling it", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    local pending, first, refusals = nil, nil, {}
    updater.run({
      root = root,
      report = function() end,
      latest = function(cb)
        pending = cb
      end,
      on_done = function(ok, info)
        first = { ok = ok, info = info }
      end,
    })
    for _ = 1, 2 do
      updater.run({
        root = root,
        on_done = function(ok, info)
          table.insert(refusals, { ok = ok, reason = info.reason })
        end,
      })
    end
    pending(nil, "stopped by the spec")
    vim.fn.delete(root, "rf")

    -- The first refusal must not clear the flag, or the second run would start.
    assert.same({ { ok = false, reason = "running" }, { ok = false, reason = "running" } }, refusals)
    assert.is_false(first.ok)
  end)

  -- The contracts the updater's comments name, enforced, so a drift fails here
  -- instead of on a user's machine after the next release.
  describe("contracts", function()
    local repo = updater.root()

    it("keeps every config file the editor reads", function()
      local kept = {}
      for _, name in ipairs(update_utils.USER_FILES) do
        kept[name] = true
      end
      local read = { [require("lib.vale_utils").CONFIG_FILE] = true }
      for _, file in
        ipairs(vim.fs.find(function(name)
          return name:match("%.lua$")
        end, { path = repo .. "/lua", type = "file", limit = math.huge }))
      do
        for name in (read_file(file) or ""):gmatch('config_file%("([^"]+)"%)') do
          read[name] = true
        end
      end
      for name in pairs(read) do
        assert.is_true(kept[name] == true, name .. " is read by the editor but missing from update_utils.USER_FILES")
      end
    end)

    it("downloads the asset CI publishes, from the repository install.sh uses", function()
      local ci, install = read_file(repo .. "/.github/workflows/ci.yml"), read_file(repo .. "/scripts/install.sh")
      assert.truthy(ci:find('artifact="' .. updater.ASSET .. '"', 1, true))
      assert.truthy(install:find('ASSET="' .. updater.ASSET .. '"', 1, true))
      assert.truthy(install:find('REPO="' .. updater.REPO .. '"', 1, true))
    end)
  end)

  describe("against a release install", function()
    local dir, root

    before_each(function()
      dir = vim.fn.tempname()
      root = dir .. "/nvim"
      write(root .. "/init.lua", "-- old\n")
      write(root .. "/lua/config/version.lua", stamp("2026.01.01"))
      write(root .. "/lua/config/removed.lua", "-- dropped by the new release\n")
      write(root .. "/config.yml", "user config\n")
      write(root .. "/.vale.ini", "StylesPath = vale-styles\n")
      write(root .. "/vale-styles/Pkg/Rule.yml", "synced\n")
    end)

    after_each(function()
      vim.fn.delete(dir, "rf")
    end)

    it("installs the newer release and keeps the user's files", function()
      local url = release(dir, "2026.12.01")
      local ok, info = update({
        root = root,
        latest = latest("2026.12.01"),
        asset_url = function()
          return url
        end,
      })

      assert.is_true(ok, info and info.reason)
      assert.same({ updated = true, from = "2026.01.01", to = "2026.12.01", previous = root .. ".previous" }, info)
      assert.equal("2026.12.01", updater.read_version(root))
      assert.equal("-- release 2026.12.01\n", read_file(root .. "/init.lua"))
      assert.is_nil(read_file(root .. "/lua/config/removed.lua"))
      -- Kept: edited by the user, or generated by :ValeSync.
      assert.equal("user config\n", read_file(root .. "/config.yml"))
      assert.equal("synced\n", read_file(root .. "/vale-styles/Pkg/Rule.yml"))
      -- The user had no theme.yml, so the release's is used.
      assert.equal("release theme\n", read_file(root .. "/theme.yml"))
      -- The replaced install is the rolling backup; nothing is left staged.
      assert.equal("2026.01.01", updater.read_version(root .. ".previous"))
      assert.equal("-- dropped by the new release\n", read_file(root .. ".previous/lua/config/removed.lua"))
      assert.is_nil(vim.uv.fs_stat(root .. ".update"))
    end)

    it("keeps only the latest backup", function()
      local first = release(dir, "2026.12.01")
      local second = release(dir, "2026.12.02")
      update({
        root = root,
        latest = latest("2026.12.01"),
        asset_url = function()
          return first
        end,
      })
      local ok = update({
        root = root,
        latest = latest("2026.12.02"),
        asset_url = function()
          return second
        end,
      })

      assert.is_true(ok)
      assert.equal("2026.12.02", updater.read_version(root))
      assert.equal("2026.12.01", updater.read_version(root .. ".previous"))
      assert.equal("user config\n", read_file(root .. "/config.yml"))
    end)

    it("downloads nothing when already up to date", function()
      local downloaded = false
      local ok, info = update({
        root = root,
        latest = latest("2026.01.01"),
        asset_url = function()
          downloaded = true
          return "file:///nonexistent"
        end,
      })

      assert.is_true(ok)
      assert.is_false(info.updated)
      assert.is_false(downloaded)
      assert.is_nil(vim.uv.fs_stat(root .. ".previous"))
    end)

    it("reinstalls the same version when forced", function()
      local url = release(dir, "2026.01.01")
      local ok, info = update({
        root = root,
        force = true,
        latest = latest("2026.01.01"),
        asset_url = function()
          return url
        end,
      })

      assert.is_true(ok)
      assert.is_true(info.updated)
      assert.equal("-- release 2026.01.01\n", read_file(root .. "/init.lua"))
    end)

    it("leaves the install untouched when the download is not a release", function()
      write(dir .. "/broken.tar.gz", "not a tarball")
      local before = #notify_log
      local statuses = {}
      local ok = update({
        root = root,
        latest = latest("2026.12.01"),
        asset_url = function()
          return "file://" .. dir .. "/broken.tar.gz"
        end,
        report = function(_, status)
          table.insert(statuses, status)
        end,
      })

      assert.is_false(ok)
      assert.equal("failed", statuses[#statuses])
      assert.truthy(notify_log[before + 1]:find("could not extract", 1, true))
      assert.equal("2026.01.01", updater.read_version(root))
      assert.is_nil(vim.uv.fs_stat(root .. ".previous"))
      assert.is_nil(vim.uv.fs_stat(root .. ".update"))
    end)
  end)
end)
