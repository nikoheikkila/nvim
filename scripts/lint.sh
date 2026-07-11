#!/usr/bin/env sh
# Same lint command CI runs (.github/workflows/ci.yml).
set -eu

if ! command -v luacheck >/dev/null 2>&1; then
  echo "luacheck not found. Install it with: luarocks install luacheck" >&2
  exit 1
fi

exec luacheck lua/
