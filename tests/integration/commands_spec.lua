-- Command-line overrides and :Daily (config/commands.lua), asserted against
-- the real command registry of a fully-loaded config.
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

    it("is defined", function()
      assert.is_not_nil(cmds.Daily)
    end)

    it("opens today's note in $NVIM_NOTES_DIR", function()
      assert.equal(expected, vim.fn.resolve(vim.api.nvim_buf_get_name(0)))
    end)

    it("gives the note buffer a markdown filetype", function()
      assert.equal("markdown", vim.bo.filetype)
    end)

    it("creates the notes directory", function()
      assert.equal(1, vim.fn.isdirectory(scratch))
    end)

    it("reopens the same note on a second :Daily", function()
      vim.cmd("enew")
      vim.cmd("Daily")
      assert.equal(expected, vim.fn.resolve(vim.api.nvim_buf_get_name(0)))
    end)
  end)
end)
