#!/usr/bin/env bash
# Run a Lua script inside a fully-initialized headless Neovim (user config and
# lazy.nvim plugins loaded), optionally from a given working directory.
#
# Why this exists: `nvim -l script.lua` looks like the obvious tool but runs
# in script mode WITHOUT loading the user config, so require()ing any plugin
# fails. And `nvim --cd <dir>` is not a real flag. This wrapper sources the
# script after full startup instead.
#
# The script's failures must be signalled explicitly: call vim.cmd("cquit 1")
# on assertion failure so callers see a non-zero exit code.
#
# Quits with `qa!` (not `qa`): a script that leaves any modified scratch
# buffer behind would make plain `qa` prompt-and-hang forever in headless mode
# (no UI to answer the prompt) — this wedged CI-style runs twice before the
# bang was added. Headless verification scripts never have real unsaved work.
#
# Usage: scripts/headless-lua.sh <script.lua> [working-dir]
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <script.lua> [working-dir]" >&2
  exit 2
fi

# Resolve the script to an absolute path before changing directory.
script="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
dir="${2:-.}"

cd "$dir"
exec nvim --headless -c "luafile ${script}" -c "qa!"
