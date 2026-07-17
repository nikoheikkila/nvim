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
# CI overrides via $BUSTED_ROCKS_TREE (a hererocks Lua 5.1 prefix has the
# same share/lua/5.1 + lib/lua/5.1 layout).
#
# `-u init.lua` matters: plain `nvim -l` skips the user config entirely
# (see :h -l), and `--cmd 'set loadplugins'` re-enables plugin loading,
# which -l otherwise disables.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tree="${BUSTED_ROCKS_TREE:-$HOME/.luarocks}"
export LUA_PATH="$tree/share/lua/5.1/?.lua;$tree/share/lua/5.1/?/init.lua;;"
export LUA_CPATH="$tree/lib/lua/5.1/?.so;;"

exec nvim --cmd 'set loadplugins' -u "$root/init.lua" -l "$@"
