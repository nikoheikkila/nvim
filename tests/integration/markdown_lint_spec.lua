-- Live markdown linting (plugins/markdown.lua, nvim-lint + markdownlint-cli2).
--
-- The async chain (event -> 300ms debounce -> lint_buf -> spawn -> parse ->
-- publish) is verified without blind sleeps: the deterministic pieces
-- (parser, diagnostic presentation, the binary itself) are asserted
-- synchronously, and the remaining event-loop waits latch on precise
-- completion signals (DiagnosticChanged, lint_buf's User MarkdownLintRun
-- sync point) so they return the moment the work finishes — the timeout is
-- only a failure bound.
--
-- Wiring checks run unconditionally; the end-to-end path needs the binary,
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
    vim.cmd("bwipeout! " .. md_buf)
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

  -- Parser contract: the configured parser (6-alternative errorformat that
  -- strips the cli2 >= 0.18 severity word) is a pure function — assert it
  -- synchronously on canned output, with or without the binary installed.
  it("parses cli2 output into WARN diagnostics, stripping the severity word", function()
    local parse = lint.linters["markdownlint-cli2"].parser
    local diags = parse(
      "stdin:1:1 error MD041/first-line-heading/first-line-h1 First line in a file should be a top-level heading\n",
      md_buf
    )
    assert.equal(1, #diags)
    local d = diags[1]
    assert.equal(warn, d.severity)
    assert.equal(0, d.lnum)
    assert.equal("markdownlint", d.source)
    assert.truthy(d.message:find("MD%d%d%d"))
    assert.is_nil(d.message:find("^error "))
  end)

  -- Presentation contract: vim.diagnostic.set renders synchronously, so a
  -- synthetic diagnostic proves the linehl extmark and the closed signcolumn
  -- without spawning anything (also covered when the binary is absent).
  it("renders a warning as a line highlight without opening the signcolumn", function()
    vim.diagnostic.set(lint_ns, md_buf, {
      { lnum = 0, col = 0, severity = warn, message = "MD000/spec-double", source = "markdownlint" },
    })
    local sign_ns
    for name, id in pairs(vim.api.nvim_get_namespaces()) do
      if name:find("markdownlint%-cli2") and name:find("signs") then
        sign_ns = id
      end
    end
    local marks = sign_ns and vim.api.nvim_buf_get_extmarks(md_buf, sign_ns, 0, -1, { details = true }) or {}
    assert.is_true(#marks > 0)
    assert.equal("MarkdownLintLine", marks[1][4].line_hl_group)
    assert.equal(0, vim.fn.getwininfo()[1].textoff)
    -- Clear the synthetic diagnostic: later tests assert on real publishes
    -- (functional path) or on staying empty (guard path).
    vim.diagnostic.set(lint_ns, md_buf, {})
  end)

  if vim.fn.executable("markdownlint-cli2") == 1 then
    describe("functional path (binary installed)", function()
      -- Binary/args/config contract: vim.system():wait() blocks on real
      -- process exit — a completion event, not a guessed timeout. The argv
      -- comes from the configured linter table, so this tracks config changes
      -- and proves the exact command nvim-lint will spawn produces the MD041
      -- finding the parser test consumes.
      it("real cli2 run over stdin reports MD041 on stderr with exit code 1", function()
        local linter = lint.linters["markdownlint-cli2"]
        local cmd = vim.list_extend({ linter.cmd }, linter.args)
        local res = vim.system(cmd, { stdin = "not a heading\n" }):wait()
        assert.equal(1, res.code) -- 1 = findings; 2+ would mean a config/usage error
        assert.truthy(res.stderr:find("stdin:1")) -- cli2 reports findings on stderr
        assert.truthy(res.stderr:find("MD041"))
      end)

      -- Thin end-to-end check of the remaining glue (autocmd -> debounce ->
      -- try_lint -> publish), latched on DiagnosticChanged.
      it("publishes diagnostics through the debounced event path", function()
        local published = false
        local group = vim.api.nvim_create_augroup("spec_diag_latch", { clear = true })
        vim.api.nvim_create_autocmd("DiagnosticChanged", {
          group = group,
          callback = function(a)
            if a.buf == md_buf then
              published = true
            end
          end,
        })
        vim.api.nvim_exec_autocmds("TextChanged", { group = "markdown_lint" })
        assert.is_true(
          vim.wait(10000, function()
            return published
          end, 10),
          "timed out waiting for DiagnosticChanged on the markdown buffer"
        )
        vim.api.nvim_del_augroup_by_id(group)
        assert.is_true(#vim.diagnostic.get(md_buf, { namespace = lint_ns }) > 0)
      end)
    end)
  else
    describe("guard path (binary missing)", function()
      -- Latch on lint_buf's User MarkdownLintRun sync point instead of
      -- sleeping out the 300ms debounce: each wait returns as soon as the
      -- debounced run actually happened, and fails loudly if it never does.
      it("notifies exactly once per session and attempts no lint", function()
        local runs = 0
        local group = vim.api.nvim_create_augroup("spec_lint_latch", { clear = true })
        vim.api.nvim_create_autocmd("User", {
          group = group,
          pattern = "MarkdownLintRun",
          callback = function()
            runs = runs + 1
          end,
        })
        -- The catch-up lint when nvim-lint first ft-loaded already notified
        -- once (recorded from session start by tests/integration/helper.lua,
        -- possibly during another spec's :Daily); this second run must not
        -- notify again, and nothing may be spawned.
        vim.api.nvim_exec_autocmds("TextChanged", { group = "markdown_lint" })
        assert.is_true(
          vim.wait(2000, function()
            return runs >= 1
          end, 10),
          "debounced run never fired after TextChanged"
        )
        vim.api.nvim_del_augroup_by_id(group)

        local guard_notes = 0
        for _, msg in ipairs(require("notify_log")) do
          if msg:find("markdownlint%-cli2 not found") then
            guard_notes = guard_notes + 1
          end
        end
        assert.equal(1, guard_notes)
        assert.equal(0, #lint.get_running(md_buf))
        assert.equal(0, #vim.diagnostic.get(md_buf, { namespace = lint_ns }))
      end)
    end)
  end
end)
