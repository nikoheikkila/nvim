-- Live markdown linting (plugins/markdown.lua, nvim-lint + markdownlint-cli2).
-- Wiring checks run unconditionally; the functional path needs the binary,
-- the guard path is exercised via:
--   scripts/test-without-binary.sh markdownlint-cli2 -- scripts/smoke-test.sh
describe("live markdown linting", function()
  local lint, lint_ns, md_buf
  local warn = vim.diagnostic.severity.WARN

  setup(function()
    vim.cmd("enew")
    md_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(md_buf, 0, -1, false, { "not a heading" }) -- violates MD041
    vim.bo.filetype = "markdown" -- ft-loads nvim-lint (if another spec hasn't already)
    lint = require("lint")
    lint_ns = lint.get_namespace("markdownlint-cli2")
  end)

  teardown(function()
    vim.bo[md_buf].modified = false
    vim.cmd("bwipeout! " .. md_buf)
  end)

  it("loads nvim-lint for markdown buffers", function()
    assert.is_not_nil(lint)
  end)

  for _, ev in ipairs({ "TextChanged", "TextChangedI", "InsertLeave", "BufWritePost", "BufReadPost" }) do
    it("has a markdown_lint " .. ev .. " autocmd", function()
      assert.equal(1, #vim.api.nvim_get_autocmds({ group = "markdown_lint", event = ev }))
    end)
  end

  it("defines a bg for the MarkdownLintLine highlight", function()
    assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "MarkdownLintLine" }).bg)
  end)

  it("ships the .markdownlint.jsonc base config", function()
    assert.equal(1, vim.fn.filereadable(vim.fn.stdpath("config") .. "/.markdownlint.jsonc"))
  end)

  it("configures the diagnostic namespace: line highlight, no underline/signs", function()
    local dcfg = vim.diagnostic.config(nil, lint_ns)
    assert.is_false(dcfg.underline)
    assert.is_true(dcfg.virtual_text)
    assert.equal("MarkdownLintLine", dcfg.signs.linehl[warn])
    assert.equal("", dcfg.signs.text[warn])
  end)

  if vim.fn.executable("markdownlint-cli2") == 1 then
    describe("functional path (binary installed)", function()
      local function diags()
        return vim.diagnostic.get(md_buf, { namespace = lint_ns })
      end

      setup(function()
        -- Fire the debounced event path, wait out timer + async spawn.
        vim.api.nvim_exec_autocmds("TextChanged", { group = "markdown_lint" })
        vim.wait(10000, function()
          return #diags() > 0
        end, 50)
      end)

      it("produces diagnostics for a known violation", function()
        assert.is_true(#diags() > 0)
      end)

      it("reports WARN carrying the MDxxx rule id, severity word stripped", function()
        local d = diags()[1]
        assert.is_not_nil(d)
        assert.equal(warn, d.severity)
        assert.truthy(d.message:find("MD%d%d%d"))
        assert.is_nil(d.message:find("^error "))
      end)

      it("puts the linehl extmark on the offending line", function()
        local sign_ns
        for name, id in pairs(vim.api.nvim_get_namespaces()) do
          if name:find("markdownlint%-cli2") and name:find("signs") then
            sign_ns = id
          end
        end
        local marks = sign_ns and vim.api.nvim_buf_get_extmarks(md_buf, sign_ns, 0, -1, { details = true }) or {}
        assert.is_true(#marks > 0)
        assert.equal("MarkdownLintLine", marks[1][4].line_hl_group)
      end)

      it("does not open the signcolumn", function()
        assert.equal(0, vim.fn.getwininfo()[1].textoff)
      end)
    end)
  else
    describe("guard path (binary missing)", function()
      it("notifies exactly once per session and attempts no lint", function()
        -- The catch-up lint when nvim-lint first ft-loaded already notified
        -- once (recorded from session start by tests/integration/helper.lua,
        -- possibly during another spec's :Daily); further events must not
        -- notify again, and nothing may be spawned.
        vim.api.nvim_exec_autocmds("TextChanged", { group = "markdown_lint" })
        vim.wait(600)
        vim.api.nvim_exec_autocmds("InsertLeave", { group = "markdown_lint" })
        vim.wait(600)
        local guard_notes = 0
        -- selene: allow(global_usage) -- written by tests/integration/helper.lua
        for _, msg in ipairs(_G.__notify_log) do
          if msg:find("markdownlint%-cli2 not found") then
            guard_notes = guard_notes + 1
          end
        end
        assert.equal(1, guard_notes)
        assert.equal(0, #vim.diagnostic.get(md_buf, { namespace = lint_ns }))
      end)
    end)
  end
end)
