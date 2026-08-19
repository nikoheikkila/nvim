-- LSP support (plugins/lsp.lua: nvim-lspconfig + mason + blink.cmp).
--
-- Wiring checks run unconditionally and need no server binaries — this is all
-- CI exercises, since the headless ensure_installed guard means mason never
-- downloads servers there. The functional path runs only where a server is
-- already installed (developer machines after the first interactive launch).
-- Force-loaded at collection time, not in setup(): the functional-path
-- executable check below needs mason.setup() to have prepended mason/bin to
-- PATH before the describe body evaluates it. (Event-lazy on
-- BufReadPre/BufNewFile, so nothing may have loaded it yet.)
require("lazy").load({ plugins = { "nvim-lspconfig" } })

local harper_utils = require("lib.harper_utils")

-- Both functional paths below wait the same way: never a blind sleep, always a
-- condition-vim.wait on the thing the next step needs. 10s is the budget for a
-- cold server start.
local function await_client(buf, name)
  assert.is_true(
    vim.wait(10000, function()
      return #vim.lsp.get_clients({ bufnr = buf, name = name }) > 0
    end, 10),
    "timed out waiting for " .. name .. " to attach"
  )
  local client = vim.lsp.get_clients({ bufnr = buf, name = name })[1]
  return client, vim.lsp.diagnostic.get_namespace(client.id)
end

local function await_diagnostics(buf, ns, name)
  assert.is_true(
    vim.wait(10000, function()
      return #vim.diagnostic.get(buf, { namespace = ns }) > 0
    end, 10),
    "timed out waiting for " .. name .. " diagnostics"
  )
  return vim.diagnostic.get(buf, { namespace = ns })
end

-- Stop every client of `name` and wipe `buf` if it survived. The functional
-- path's :edit replaces the unnamed scratch buffer (Vim auto-wipes an empty
-- unnamed one), so the guard is not optional.
local function stop_clients(name, buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.cmd("bwipeout! " .. buf)
  end
  for _, client in ipairs(vim.lsp.get_clients({ name = name })) do
    client:stop(true)
  end
end

describe("lsp support", function()
  local leader = vim.g.mapleader
  local buf

  setup(function()
    vim.cmd("enew")
    buf = vim.api.nvim_get_current_buf()
  end)

  teardown(function()
    -- The functional path's :edit replaces the unnamed scratch buffer (Vim
    -- auto-wipes an empty unnamed buffer), so it may already be gone.
    if vim.api.nvim_buf_is_valid(buf) then
      vim.cmd("bwipeout! " .. buf)
    end
  end)

  it("registers exactly one LspAttach autocmd in the lsp_keymaps group", function()
    assert.equal(1, #vim.api.nvim_get_autocmds({ group = "lsp_keymaps", event = "LspAttach" }))
  end)

  it("resolves a config for every server in the servers table", function()
    -- Iterates the real table, so a new entry in config/lsp_servers.lua is
    -- covered automatically.
    for name in pairs(require("config.lsp_servers")) do
      local config = vim.lsp.config[name]
      assert.is_table(config, name .. " has no resolved vim.lsp.config")
      assert.is_not_nil(config.cmd, name .. " resolved without a cmd")
    end
  end)

  it("teaches lua_ls the vim global", function()
    local globals = vim.lsp.config.lua_ls.settings.Lua.diagnostics.globals
    assert.is_true(vim.tbl_contains(globals, "vim"))
  end)

  it("resolves harper_ls settings from config.yml", function()
    local harper = vim.lsp.config.harper_ls.settings["harper-ls"]
    assert.is_table(harper, "harper_ls has no resolved settings")
    assert.is_string(harper.dialect)
    assert.is_boolean(harper.linters.SpellCheck)
  end)

  it("expands env vars in harper_ls dictionary paths", function()
    -- harper-ls resolves "~" and workspace-relative paths but not "$VAR", so
    -- config/lsp_servers.lua expands them; the fixture writes the path as a
    -- literal $NVIM_CONFIG_ROOT so the expansion is what makes these match.
    local harper = vim.lsp.config.harper_ls.settings["harper-ls"]
    local paths = require("config.paths")
    assert.equal(paths.config_file("fixture-dictionary.txt"), harper.userDictPath)
  end)

  for _, name in ipairs({ "harper/underline", "vale/underline" }) do
    it("registers the " .. name .. " diagnostic handler", function()
      local handler = vim.diagnostic.handlers[name]
      assert.is_table(handler, name .. " handler is not registered")
      assert.is_function(handler.show)
      assert.is_function(handler.hide)
    end)
  end

  it("resolves vale_ls init_options from config.yml", function()
    local vale = vim.lsp.config.vale_ls.init_options
    assert.is_table(vale, "vale_ls has no resolved init_options")
    -- Sentinels from the fixture config.yml, not vale_utils' own defaults.
    assert.equal(50, vale.debounceMs)
    assert.is_false(vale.showMetrics)
    -- Empty optional strings are dropped so vale-ls falls back to its own
    -- behaviour rather than being handed a meaningless "".
    assert.is_nil(vale.valeBinaryPath)
  end)

  it("expands env vars in the vale_ls configPath", function()
    -- Same shape as the harper dictionary check above: the fixture writes the
    -- path as a literal $NVIM_CONFIG_ROOT, so the expansion is what makes these
    -- match. This covers the *configured* path only — the fixture sets one, so
    -- the shipped-file fallback and its readiness gate never run here; they are
    -- driven directly in "shipped .vale.ini gate" below.
    local paths = require("config.paths")
    assert.equal(paths.config_file(".vale.ini"), vim.lsp.config.vale_ls.init_options.configPath)
  end)

  -- The gate config/vale.lua applies before handing the shipped .vale.ini to the
  -- server. Driven against throwaway directories rather than the fixture root,
  -- because every branch but the happy one has to be reached by *removing*
  -- something the fixture deliberately provides.
  describe("shipped .vale.ini gate", function()
    local vale = require("config.vale")
    local dir

    before_each(function()
      dir = vim.fn.tempname()
      assert.equal(1, vim.fn.mkdir(dir, "p"))
    end)

    after_each(function()
      vim.fn.delete(dir, "rf")
    end)

    local function write_ini(lines)
      vim.fn.writefile(lines, dir .. "/.vale.ini")
      return dir .. "/.vale.ini"
    end

    it("accepts a config whose declared StylesPath exists", function()
      local ini = write_ini({ "StylesPath = styles", "[*.md]", "BasedOnStyles = Vale" })
      assert.equal(1, vim.fn.mkdir(dir .. "/styles", "p"))
      local path, reason = vale.vet_config(ini)
      assert.equal(ini, path)
      assert.is_nil(reason)
    end)

    it("rejects a config whose StylesPath is missing, with a :ValeSync hint", function()
      -- Vale aborts with E201 on every lint in this state, so withholding the
      -- config is the difference between silence and an error popup per keystroke.
      local path, reason = vale.vet_config(write_ini({ "StylesPath = styles" }))
      assert.is_nil(path)
      assert.is_string(reason)
      assert.is_truthy(reason:find(":ValeSync", 1, true))
    end)

    it("accepts a config that declares no StylesPath at all", function()
      -- Vale falls back to its own location and never errors about it.
      local ini = write_ini({ "MinAlertLevel = suggestion" })
      assert.equal(ini, vale.vet_config(ini))
    end)

    it("stays silent about a missing file — that is how you opt out", function()
      local path, reason = vale.vet_config(dir .. "/.vale.ini")
      assert.is_nil(path)
      assert.is_nil(reason)
    end)
  end)

  -- Vale's --config is a full replacement, so the shipped fallback has to step
  -- aside wherever a project ships its own .vale.ini. root_markers is
  -- { ".vale.ini" }, which makes a resolved root_dir the signal. before_init is
  -- an ordinary function, so this needs no server.
  describe("vale_ls project-config precedence", function()
    local function run(root_dir)
      local client_config = { root_dir = root_dir, init_options = { configPath = "/shipped/.vale.ini" } }
      -- Through the resolved config, not config/vale.lua directly: the wiring is
      -- half of what is under test.
      vim.lsp.config.vale_ls.before_init({}, client_config)
      return client_config.init_options.configPath
    end

    it("drops the fallback when the project has its own .vale.ini", function()
      assert.equal("", run("/tmp/project-with-vale-ini"))
    end)

    it("keeps the fallback in a single-file (no root_dir) session", function()
      assert.equal("/shipped/.vale.ini", run(nil))
    end)
  end)

  it("sets global diagnostic defaults without clobbering the markdownlint namespace", function()
    assert.is_true(vim.diagnostic.config().severity_sort)
    -- Regression guard: plugins/markdown.lua scopes its presentation to the
    -- markdownlint namespace; the global LSP defaults must not leak into it.
    require("lazy").load({ plugins = { "nvim-lint" } })
    local lint_ns = require("lint").get_namespace("markdownlint-cli2")
    assert.is_false(vim.diagnostic.config(nil, lint_ns).underline)
  end)

  it("loads blink.cmp", function()
    require("lazy").load({ plugins = { "blink.cmp" } })
    require("blink.cmp") -- errors with the real message if the module is broken
  end)

  describe("buffer-local keymaps on LspAttach", function()
    -- The maps are registered unconditionally on attach (not gated on client
    -- capabilities), so firing the autocmd on a scratch buffer proves the
    -- wiring without a live server.
    setup(function()
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_exec_autocmds("LspAttach", { group = "lsp_keymaps", buffer = buf })
    end)

    local cases = {
      { "<F2>", "n", "Rename symbol" },
      { "<F2>", "i", "Rename symbol" },
      { leader .. "cr", "n", "Rename symbol" },
      { "<F12>", "n", "Go to definition" },
      { "<F12>", "i", "Go to definition" },
      { leader .. "gd", "n", "Go to definition" },
      { "<S-F12>", "n", "List references" },
      { "<S-F12>", "i", "List references" },
      { "<F24>", "n", "List references" },
      { "<F24>", "i", "List references" },
      { leader .. "gr", "n", "List references" },
      { leader .. "r", "n", "Refactor menu" },
      { leader .. "r", "x", "Refactor menu" },
      { leader .. "ca", "n", "Quick fix menu" },
    }

    for _, case in ipairs(cases) do
      local lhs, mode, desc = case[1], case[2], case[3]
      it(("binds %s (%s) to %s"):format(lhs, mode, desc), function()
        local map = vim.fn.maparg(lhs, mode, false, true)
        assert.equal(desc, map.desc)
        assert.equal(1, map.buffer, lhs .. " must be buffer-local")
      end)
    end
  end)

  -- Harper's "Add … to the … dictionary." actions are what <leader>ca exists
  -- for, and harper-ls only returns them for a request landing INSIDE a lint
  -- span — so this covers the snap end to end against the real server. Gated on
  -- the binary like the lua_ls block below, since CI installs no servers.
  if vim.fn.executable(vim.lsp.config.harper_ls.cmd[1]) == 1 then
    describe("functional path (harper-ls installed)", function()
      local dir, harper_buf

      setup(function()
        -- Harper canonicalizes its workspace root and misresolves paths without
        -- one, and nvim-lspconfig walks up for .git / .harper-dictionary.txt —
        -- so the fixture gets its own throwaway repo marker. One flaggable word
        -- per line keeps the snap unambiguous.
        dir = vim.fn.tempname()
        assert.equal(1, vim.fn.mkdir(dir .. "/.git", "p"))
        vim.fn.writefile({ "# Fixture", "", "Now the auto-completion popup.", "" }, dir .. "/fixture.md")
      end)

      teardown(function()
        stop_clients("harper_ls", harper_buf)
        vim.fn.delete(dir, "rf")
      end)

      it("returns dictionary code actions for a range snapped from column 0", function()
        vim.cmd.edit(dir .. "/fixture.md")
        harper_buf = vim.api.nvim_get_current_buf()
        local client, ns = await_client(harper_buf, "harper_ls")
        await_diagnostics(harper_buf, ns, "harper")

        -- Ask from column 0 of each flagged line — never on the word itself, so
        -- an unsnapped request would come back empty. Looping over the spans
        -- rather than hardcoding the one the fixture expects keeps this honest if
        -- a harper release changes which lints fire; it stops at the first hit, so
        -- the usual run is a single request.
        -- Only *requesting* here: executing one would write the real dictionary.
        local spans = vim.diagnostic.get(harper_buf, { namespace = ns })
        local titles, found = {}, false
        for _, span in ipairs(spans) do
          local pos = harper_utils.quick_fix_position({ lnum = span.lnum, col = 0 }, spans)
          assert.is_table(pos, "column 0 of line " .. span.lnum .. " snapped to nothing")
          local params = vim.lsp.util.make_given_range_params(
            { pos.lnum + 1, pos.col },
            { pos.lnum + 1, pos.col },
            harper_buf,
            client.offset_encoding
          )
          params.context = { diagnostics = {} }
          local response = client:request_sync("textDocument/codeAction", params, 10000, harper_buf)
          for _, action in ipairs(response and response.result or {}) do
            titles[#titles + 1] = action.title
            found = found or action.title:find("to the user dictionary%.$") ~= nil
          end
          if found then
            break
          end
        end
        assert.is_true(found, "no add-to-user-dictionary action among: " .. vim.inspect(titles))
      end)
    end)
  end

  -- Vale's code actions come from `context.diagnostics`, which Neovim fills
  -- from the cursor position unless an explicit range is passed — so the same
  -- snap Harper needs is what lets Vale answer from anywhere on the line. Same
  -- gate shape as above; also needs the `vale` CLI, which vale-ls shells out to.
  if vim.fn.executable(vim.lsp.config.vale_ls.cmd[1]) == 1 and vim.fn.executable("vale") == 1 then
    describe("functional path (vale-ls installed)", function()
      local dir, vale_buf

      setup(function()
        -- The fixture ships its own .vale.ini, so this also covers the
        -- before_init precedence path end to end: root_markers resolves a
        -- root_dir here, the shipped configPath is dropped, and Vale finds this
        -- one by walking up from the document. `BasedOnStyles = Vale` is the
        -- built-in style — no `vale sync`, so nothing touches the network — but
        -- the StylesPath directory still has to exist or Vale aborts with E201.
        dir = vim.fn.tempname()
        assert.equal(1, vim.fn.mkdir(dir .. "/styles", "p"))
        vim.fn.writefile(
          { "StylesPath = styles", "MinAlertLevel = suggestion", "", "[*.md]", "BasedOnStyles = Vale" },
          dir .. "/.vale.ini"
        )
        vim.fn.writefile({ "# Fixture", "", "This sentance has a typo.", "" }, dir .. "/fixture.md")
      end)

      teardown(function()
        stop_clients("vale_ls", vale_buf)
        vim.fn.delete(dir, "rf")
      end)

      it("returns code actions for a range snapped from column 0", function()
        vim.cmd.edit(dir .. "/fixture.md")
        vale_buf = vim.api.nvim_get_current_buf()
        local client, ns = await_client(vale_buf, "vale_ls")
        local spans = await_diagnostics(vale_buf, ns, "vale")

        -- Ask from column 0 of each flagged line, never on the word itself.
        -- vale-ls reads the alert back out of each diagnostic's `data`, so the
        -- request has to carry them: Neovim only skips its contains-the-cursor
        -- filter when an explicit range is passed, which is what the snap
        -- produces. Requesting only — the vocabulary actions would write files.
        local titles = {}
        for _, span in ipairs(spans) do
          local pos = harper_utils.quick_fix_position({ lnum = span.lnum, col = 0 }, spans)
          assert.is_table(pos, "column 0 of line " .. span.lnum .. " snapped to nothing")
          local params = vim.lsp.util.make_given_range_params(
            { pos.lnum + 1, pos.col },
            { pos.lnum + 1, pos.col },
            vale_buf,
            client.offset_encoding
          )
          -- Neovim's own conversion, the same thing vim.lsp.buf.code_action()
          -- puts in the context.
          params.context = {
            diagnostics = vim.lsp.diagnostic.from(vim.diagnostic.get(vale_buf, { namespace = ns, lnum = pos.lnum })),
          }
          local response = client:request_sync("textDocument/codeAction", params, 10000, vale_buf)
          for _, action in ipairs(response and response.result or {}) do
            titles[#titles + 1] = action.title
          end
        end
        assert.is_true(#titles > 0, "no code actions for any flagged line")
      end)
    end)
  end

  -- The binary name comes from the resolved config, so this gate cannot
  -- silently rot if the base config's cmd changes.
  if vim.fn.executable(vim.lsp.config.lua_ls.cmd[1]) == 1 then
    describe("functional path (lua-language-server installed)", function()
      -- Attachment only: definition/rename round-trips are interactive
      -- verification. Latched on the client list, never a blind sleep.
      it("attaches lua_ls to a Lua file from this repo", function()
        vim.cmd.edit(vim.fn.stdpath("config") .. "/lua/lib/path_utils.lua")
        local lua_buf = vim.api.nvim_get_current_buf()
        assert.is_true(
          vim.wait(10000, function()
            return #vim.lsp.get_clients({ bufnr = lua_buf, name = "lua_ls" }) > 0
          end, 10),
          "timed out waiting for lua_ls to attach"
        )
        for _, client in ipairs(vim.lsp.get_clients({ name = "lua_ls" })) do
          client:stop(true)
        end
        vim.cmd("bwipeout! " .. lua_buf)
      end)
    end)
  end
end)
