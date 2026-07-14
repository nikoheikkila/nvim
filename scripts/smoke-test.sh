#!/usr/bin/env bash
# Headless smoke test for config-level wiring: leader keys, user commands
# (:Daily, :BufClose/:BufWriteClose + their :q/:x/:wq abbreviations), and
# global keymaps. Complements `busted` (pure-Lua lib/ only) and `selene`
# (static lint) — this is the only check that exercises a fully-loaded config.
#
# Usage: scripts/smoke-test.sh
set -euo pipefail

cd "$(dirname "$0")/.."
exec scripts/headless-lua.sh scripts/verify-config.lua
