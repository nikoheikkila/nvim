-- Auto-save contract (config/autocmds.lua): InsertLeave saves immediately and
-- is the ONLY trigger — no TextChanged debounce, so format-on-save never fires
-- mid-edit. Events are fired explicitly (feedkeys-driven autocmds are
-- unreliable headlessly) and scoped to the auto_save group so other plugins'
-- handlers stay out of the test.
describe("auto_save", function()
  it("has exactly one InsertLeave autocmd", function()
    local aus = vim.api.nvim_get_autocmds({ group = "auto_save", event = "InsertLeave" })
    assert.equal(1, #aus)
  end)

  for _, ev in ipairs({ "TextChanged", "TextChangedI" }) do
    it("has no " .. ev .. " autocmd (debounce stays removed)", function()
      assert.equal(0, #vim.api.nvim_get_autocmds({ group = "auto_save", event = ev }))
    end)
  end

  it("InsertLeave writes a modified, named buffer via nested write autocmds", function()
    local save_file = vim.fn.tempname() .. ".txt"
    vim.cmd.edit(save_file)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "autosaved" })
    -- The InsertLeave autocmd must be `nested` — otherwise its `:update`
    -- fires no write autocmds and conform/auto_create_dir are silently
    -- skipped.
    local write_autocmds_fired = false
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("verify_nested_save", { clear = true }),
      callback = function()
        write_autocmds_fired = true
      end,
    })
    vim.api.nvim_exec_autocmds("InsertLeave", { group = "auto_save" })

    assert.equal(1, vim.fn.filereadable(save_file))
    assert.is_false(vim.bo.modified)
    assert.is_true(write_autocmds_fired)

    vim.api.nvim_del_augroup_by_name("verify_nested_save")
    vim.fn.delete(save_file)
    vim.cmd("bwipeout!")
  end)

  it("never auto-saves an unnamed scratch buffer", function()
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "scratch" })
    vim.api.nvim_exec_autocmds("InsertLeave", { group = "auto_save" })
    assert.is_true(vim.bo.modified)
    vim.cmd("bwipeout!")
  end)
end)
