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
end)
