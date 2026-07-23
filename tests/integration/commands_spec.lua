-- Command-line overrides and :Daily (config/commands.lua), asserted against
-- the real command registry of a fully-loaded config.
local yaml_utils = require("lib.yaml_utils")
local daily_utils = require("lib.daily_utils")
local paths = require("config.paths")

describe("config.commands", function()
  local cmds = vim.api.nvim_get_commands({})

  describe("buffer-close overrides", function()
    it("defines :BufClose", function()
      assert.is_not_nil(cmds.BufClose)
    end)

    it("defines :BufWriteClose", function()
      assert.is_not_nil(cmds.BufWriteClose)
    end)

    it("rewrites :q to :BufClose", function()
      assert.truthy(vim.fn.execute("cabbrev q"):find("BufClose"))
    end)

    it("rewrites :x to :BufWriteClose", function()
      assert.truthy(vim.fn.execute("cabbrev x"):find("BufWriteClose"))
    end)

    it("rewrites :wq to :BufWriteClose", function()
      assert.truthy(vim.fn.execute("cabbrev wq"):find("BufWriteClose"))
    end)
  end)

  -- End-to-end against a scratch notes dir. $NVIM_NOTES_DIR is read at call
  -- time, so setting vim.env in-process is enough — no shell wrapper needed.
  describe(":Daily", function()
    local scratch, expected

    setup(function()
      scratch = vim.fn.tempname()
      vim.env.NVIM_NOTES_DIR = scratch
      -- Compare via resolve(): on macOS tempname() returns /var/... while
      -- buffer names resolve through the /var -> /private/var symlink.
      expected = vim.fn.resolve(vim.fs.joinpath(scratch, os.date("%Y-%m-%d") .. ".md"))
      vim.cmd("Daily")
    end)

    teardown(function()
      vim.fn.delete(scratch, "rf")
      vim.env.NVIM_NOTES_DIR = nil
    end)

    it("opens today's markdown note in $NVIM_NOTES_DIR, creating the directory", function()
      assert.equal(expected, vim.fn.resolve(vim.api.nvim_buf_get_name(0)))
      assert.equal("markdown", vim.bo.filetype)
      assert.equal(1, vim.fn.isdirectory(scratch))
    end)

    it("reopens the same note on a second :Daily", function()
      vim.cmd("enew")
      vim.cmd("Daily")
      assert.equal(expected, vim.fn.resolve(vim.api.nvim_buf_get_name(0)))
    end)

    -- config.yml specifies its own daily directory; NVIM_NOTES_DIR must win over
    -- it. Derive that configured dir from the SAME active config (config.paths —
    -- the harness fixture during tests) instead of hardcoding it, so this never
    -- depends on the real config.yml. The note landing in the scratch dir above
    -- (not the configured dir) proves the override.
    it("lets NVIM_NOTES_DIR override the config.yml directory", function()
      local cfg = daily_utils.resolve_config(yaml_utils.read_file(paths.config_file("config.yml")))
      local configured = vim.fn.resolve(vim.fn.expand(cfg.directory))
      assert.is_nil(vim.api.nvim_buf_get_name(0):find(configured, 1, true))
      assert.equal(expected, vim.fn.resolve(vim.api.nvim_buf_get_name(0)))
    end)
  end)
end)
