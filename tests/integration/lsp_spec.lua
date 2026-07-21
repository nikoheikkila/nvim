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

  it("registers the harper/underline diagnostic handler", function()
    local handler = vim.diagnostic.handlers["harper/underline"]
    assert.is_table(handler, "harper/underline handler is not registered")
    assert.is_function(handler.show)
    assert.is_function(handler.hide)
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
