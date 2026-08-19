-- Language servers configured by plugins/lsp.lua — the single source of
-- truth, also iterated by tests/integration/lsp_spec.lua so every entry is
-- covered automatically. Key = lspconfig server name (:h lspconfig-all);
-- value = overrides merged onto nvim-lspconfig's base config via
-- vim.lsp.config() (settings, cmd, root_markers, ...) — {} is enough for
-- most servers. mason-lspconfig maps the name to a mason package, installs
-- it on the first interactive launch, and auto-enables it.
local yaml_utils = require("lib.yaml_utils")
local harper_utils = require("lib.harper_utils")
local vale = require("config.vale")
local paths = require("config.paths")

-- A missing/unreadable config.yml yields nil, so resolve_config falls back to
-- harper's defaults. (Vale reads the file itself, via config/vale.lua.)
local config = yaml_utils.read_file(paths.config_file("config.yml"))

-- harper-ls resolves "~" and workspace-relative paths itself, but not "$VAR" —
-- and config.yml uses that style elsewhere (config.obsidian.vault). Expand here,
-- at the vim-side seam, so harper and :HarperDict always name the same file.
-- harper_utils stays free of vim, like every other resolver in lua/lib/.
local harper = harper_utils.resolve_config(config)
for _, key in ipairs(harper_utils.OPTIONAL_PATHS) do
  if harper[key] then
    harper[key] = vim.fn.expand(harper[key])
  end
end

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
    settings = { ["harper-ls"] = harper },
  },
  -- Vale prose style checking, the complement to Harper: Harper owns grammar and
  -- spelling, Vale's write-good/proselint packages own wordiness, weasel words,
  -- passive voice and clichés. Diagnostics/code-actions only, on nvim-lspconfig's
  -- default filetypes (markdown, text, rst, asciidoc, tex, html, xml). It lints
  -- the buffer as you type — vale-ls debounces `debounceMs` and pipes the unsaved
  -- text through Vale's stdin — but never an unnamed buffer, which has no path to
  -- resolve syntax and config against. Its options (`config.vale.*` in
  -- config.yml), the shipped-.vale.ini fallback, and the project-config-wins
  -- hook all live in config/vale.lua — see there for why each works as it does.
  vale_ls = {
    init_options = vale.init_options(),
    before_init = vale.before_init,
  },
}
