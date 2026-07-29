-- AMA title-case wiring: the gt operator and the visual-mode t map from
-- config/keymaps.lua, plus the buffer plumbing in config/title_case.lua. The
-- rules themselves are covered by tests/unit/title_case_spec.lua — keep this
-- file about ranges, modes and repeatability.
describe("title case", function()
  -- `normal` without ! so the mappings apply. bufhidden=wipe makes each scratch
  -- buffer disappear the moment the next one replaces it in the window —
  -- otherwise every case leaks a listed buffer into the rest of the suite, which
  -- surfaces as a confusing failure in an unrelated spec file (file insulation
  -- is off here, so the editor process is shared).
  local function given(lines)
    vim.cmd("enew!")
    vim.bo.bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end

  local function buffer()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
  end

  -- Hand the session back as one ordinary, unmodified window.
  teardown(function()
    vim.cmd("enew!")
  end)

  it("binds gt to the title case operator", function()
    assert.equal("Title case (operator)", vim.fn.maparg("gt", "n", false, true).desc)
  end)

  it("binds visual t to the title case selection", function()
    assert.equal("Title case selection", vim.fn.maparg("t", "x", false, true).desc)
  end)

  it("gtiw cases the word under the cursor only", function()
    given({ "journal of epidemiology" })
    vim.cmd("normal gtiw")
    assert.equal("Journal of epidemiology", buffer()[1])
  end)

  it("gt$ cases the rest of the line", function()
    given({ "journal of clinical epidemiology" })
    vim.cmd("normal 0gt$")
    assert.equal("Journal of Clinical Epidemiology", buffer()[1])
  end)

  it("gtj takes the linewise branch over two lines", function()
    given({ "principles of molecular genetics", "trials in medicine" })
    vim.cmd("normal gtj")
    assert.are.same({ "Principles of Molecular Genetics", "Trials in Medicine" }, buffer())
  end)

  it("keeps a multibyte character intact at the end of the range", function()
    given({ "pharmacology of \206\178-blocker therapy" })
    vim.cmd("normal 0gt$")
    assert.equal("Pharmacology of \206\178-Blocker Therapy", buffer()[1])
  end)

  it("repeats with dot", function()
    given({ "clinical trials in medicine" })
    vim.cmd("normal gtiw")
    vim.cmd("normal w.")
    assert.equal("Clinical Trials in medicine", buffer()[1])
  end)

  -- The operator cases exactly what the motion covers, treating that range as a
  -- title of its own — so a lone minor word is both its first and last word.
  it("capitalizes a minor word when the motion covers only that word", function()
    given({ "journal of epidemiology" })
    vim.cmd("normal wgtiw")
    assert.equal("journal Of epidemiology", buffer()[1])
  end)

  it("reverts a whole application with a single undo", function()
    given({ "journal of clinical epidemiology" })
    vim.cmd("let &undolevels = &undolevels")
    vim.cmd("normal 0gt$")
    vim.cmd("silent normal u")
    assert.equal("journal of clinical epidemiology", buffer()[1])
  end)

  it("cases a charwise selection", function()
    given({ "journal of epidemiology" })
    vim.cmd("normal viwt")
    assert.equal("Journal of epidemiology", buffer()[1])
  end)

  it("cases a linewise selection", function()
    given({ "principles of molecular genetics", "trials in medicine" })
    vim.cmd("normal Vjt")
    assert.are.same({ "Principles of Molecular Genetics", "Trials in Medicine" }, buffer())
  end)

  it("cases a blockwise selection column-by-column", function()
    given({ "abcd efgh", "ijkl mnop" })
    vim.cmd("normal " .. vim.keycode("<C-v>") .. "jllt")
    assert.are.same({ "Abcd efgh", "Ijkl mnop" }, buffer())
  end)

  it("clamps a blockwise selection to short lines", function()
    given({ "short", "much longer line here" })
    vim.cmd("normal " .. vim.keycode("<C-v>") .. "j$t")
    assert.are.same({ "Short", "Much Longer Line Here" }, buffer())
  end)
end)
