-- Command-line overrides (config/commands.lua), asserted against the real
-- command registry of a fully-loaded config.
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

  describe("harper dictionaries", function()
    it("defines :HarperDict taking an optional argument", function()
      assert.is_not_nil(cmds.HarperDict)
      assert.equal("?", cmds.HarperDict.nargs)
    end)

    -- The command resolves its path through config/lsp_servers.lua's already
    -- expanded settings, so it cannot drift from what harper-ls was handed. The
    -- fixture config.yml sets userDictPath, so this is the configured branch.
    it("opens the configured user dictionary", function()
      local paths = require("config.paths")
      vim.cmd("HarperDict")
      local opened = vim.api.nvim_buf_get_name(0)
      vim.cmd("bwipeout!")
      -- Both sides through resolve(): :edit records the real path, and the
      -- fixture root lives under macOS's /var -> /private/var symlink.
      assert.equal(vim.fn.resolve(paths.config_file("fixture-dictionary.txt")), vim.fn.resolve(opened))
    end)

    it("warns on an unknown dictionary name", function()
      local log = require("notify_log")
      local before = #log
      vim.cmd("HarperDict bogus")
      assert.equal(before + 1, #log)
      assert.truthy(log[#log]:find("bogus"))
    end)
  end)
end)
