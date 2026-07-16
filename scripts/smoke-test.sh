#!/usr/bin/env bash
# Config-level integration tests: leader keys, user commands (:Daily,
# :BufClose/:BufWriteClose + their :q/:x/:wq abbreviations), global keymaps,
# auto-save, and plugin wiring (multicursor, markdown lint).
#
# Runs the tests/integration/ Busted suite inside a fully-loaded headless
# Neovim (see the `integration` task in .busted and scripts/busted-nvim.sh).
# Complements plain `busted` (pure-Lua tests/unit) and `selene` (static lint).
#
# Usage: scripts/smoke-test.sh
set -euo pipefail

cd "$(dirname "$0")/.."
exec busted --run=integration
