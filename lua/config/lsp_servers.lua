-- Language servers configured by plugins/lsp.lua — the single source of
-- truth, also iterated by tests/integration/lsp_spec.lua so every entry is
-- covered automatically. Key = lspconfig server name (:h lspconfig-all);
-- value = overrides merged onto nvim-lspconfig's base config via
-- vim.lsp.config() (settings, cmd, root_markers, ...) — {} is enough for
-- most servers. mason-lspconfig maps the name to a mason package, installs
-- it on the first interactive launch, and auto-enables it.
local yaml_utils = require("lib.yaml_utils")
local harper_utils = require("lib.harper_utils")

-- A missing/unreadable config.yml yields nil, so resolve_config falls back to
-- harper's defaults.
local config = yaml_utils.read_file(vim.fn.stdpath("config") .. "/config.yml")

return {
  ts_ls = {}, -- JavaScript + TypeScript; exposes tsserver refactor.* code actions (extract/inline)
  basedpyright = {}, -- Python (maintained pyright fork)
  bashls = {}, -- Bash; spawns shellcheck from PATH for extra diagnostics when present
  yamlls = {}, -- YAML; SchemaStore support is built in and enabled by default
  lua_ls = { -- Lua; formatting stays with stylua via conform.nvim
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        diagnostics = { globals = { "vim" } },
        workspace = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
      },
    },
  },
  -- Harper grammar/spell checking. Attaches on nvim-lspconfig's default
  -- filetypes (prose + many programming languages, where it checks comments and
  -- string literals). Options come from config.yml (`config.harper.*`) via
  -- lib/harper_utils.lua, falling back to harper's defaults when absent.
  harper_ls = {
    settings = { ["harper-ls"] = harper_utils.resolve_config(config) },
  },
}
