#!/usr/bin/env bash
# Lua "interpreter" shim for Busted: executes the given Lua script inside a
# fully-initialized headless Neovim, so specs run against the real vim API
# with the user config and lazy.nvim plugins loaded.
#
# Busted re-executes its own bootstrap under this shim when a .busted task
# sets `lua = "scripts/busted-nvim.sh"` (the `integration` task) — the same
# mechanism as the community `nlua` shim.
#
# LUA_PATH/LUA_CPATH point at a Lua 5.1 luarocks tree: Neovim's LuaJIT
# speaks the 5.1 ABI, so busted must be installed with
# `luarocks --lua-version=5.1 install busted` (the default homebrew tree is
# Lua 5.5 — its C modules cannot load into LuaJIT). Defaults to ~/.luarocks;
# CI overrides via $BUSTED_ROCKS_TREE (any Lua 5.1 rocks tree with the
# standard share/lua/5.1 + lib/lua/5.1 layout works).
#
# `-u init.lua` matters: plain `nvim -l` skips the user config entirely
# (see :h -l), and `--cmd 'set loadplugins'` re-enables plugin loading,
# which -l otherwise disables.
#
# Config-file isolation: the specs must never depend on the real, editable
# config files (config.yml/theme.yml/.markdownlint.jsonc) — editing one would
# otherwise break tests. We generate throwaway fixtures with distinct sentinel
# values in a temp dir and point NVIM_CONFIG_ROOT at it (honored by
# lua/config/paths.lua); the trap removes them once nvim exits. This must happen
# BEFORE nvim starts: the theme plugin is lazy=false, so theme.yml is read at
# startup. Everything else (init.lua, lua/, plugins) still resolves through the
# real stdpath("config"). We run nvim (no `exec`) so the EXIT trap fires on both
# success and failure; `set -e` still propagates nvim's exit code.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tree="${BUSTED_ROCKS_TREE:-$HOME/.luarocks}"
export LUA_PATH="$tree/share/lua/5.1/?.lua;$tree/share/lua/5.1/?/init.lua;;"
export LUA_CPATH="$tree/lib/lua/5.1/?.so;;"

cfgroot="$(mktemp -d)"
trap 'rm -rf "$cfgroot"' EXIT
export NVIM_CONFIG_ROOT="${NVIM_CONFIG_ROOT:-$cfgroot}"

# theme.yml — keep the real plugin url/name (else lazy fetches an uninstalled
# repo); `variant`/group hexes are sentinels distinct from the real file.
cat > "$NVIM_CONFIG_ROOT/theme.yml" <<'EOF'
theme:
  url: projekt0n/github-nvim-theme
  name: github-theme
  variant: github_dark_dimmed
  options:
    styles:
      comments: italic
  groups:
    all:
      "@markup.raw.markdown_inline":
        fg: "#ff0000"
        bg: "#111111"
      RenderMarkdownCodeInline:
        fg: "#ff0000"
        bg: "#111111"
      HarperDiagnosticUnderline:
        sp: "#00ff00"
        style: undercurl
      ValeDiagnosticUnderline:
        sp: "#0000ff"
        style: undercurl
EOF

# A throwaway vault for obsidian.nvim to resolve its single workspace against:
# .obsidian/ is the marker it walks up for, and the directory must exist before
# nvim starts because plugins/obsidian.lua is lazy = false. Removed by the trap
# with the rest of $cfgroot.
mkdir -p "$NVIM_CONFIG_ROOT/fixture-vault/.obsidian"

# config.yml — obsidian.vault, harper.userDictPath and vale.configPath are written as the literal
# $NVIM_CONFIG_ROOT string, not the expanded path: the quoted heredoc keeps them
# verbatim and vim.fn.expand resolves env vars, so obsidian_spec and lsp_spec can
# recompute the same paths (and lsp_spec can prove the expansion happens at all).
# The values are sentinels distinct from the real config.yml. Harper and Vale
# values are sentinels too (lsp_spec otherwise only type-checks them).
cat > "$NVIM_CONFIG_ROOT/config.yml" <<'EOF'
config:
  obsidian:
    vault: "$NVIM_CONFIG_ROOT/fixture-vault"
    dailyNotes:
      folder: "fixture-journal"
      dateFormat: "YYYY-MM-DD"
  harper:
    dialect: "British"
    diagnosticSeverity: "warning"
    isolateEnglish: true
    maxFileLength: 5000
    userDictPath: "$NVIM_CONFIG_ROOT/fixture-dictionary.txt"
    codeActions:
      ForceStable: true
    markdown:
      IgnoreLinkTitle: true
    linters:
      SpellCheck: false
  vale:
    configPath: "$NVIM_CONFIG_ROOT/.vale.ini"
    debounceMs: 50
    showMetrics: false
EOF

# .vale.ini -- the fallback config lsp_spec asserts vale_ls was handed. Vale's
# built-in `Vale` style needs no `vale sync`, only an existing StylesPath, so
# nothing here touches the network; the directory is created below. The name is
# a sentinel distinct from the real file's `vale-styles`.
cat > "$NVIM_CONFIG_ROOT/.vale.ini" <<'EOF'
StylesPath = fixture-styles
MinAlertLevel = suggestion

[*.md]
BasedOnStyles = Vale
EOF
mkdir -p "$NVIM_CONFIG_ROOT/fixture-styles"

# .markdownlint.jsonc — exact basename required (cli2 recognizes it by name;
# otherwise it exits 2). "default": true keeps MD041 active so the functional
# path's exit-code-1 assertion holds regardless of the real file.
cat > "$NVIM_CONFIG_ROOT/.markdownlint.jsonc" <<'EOF'
{ "default": true, "MD013": { "line_length": 120, "tables": false } }
EOF

nvim --cmd 'set loadplugins' -u "$root/init.lua" -l "$@"
