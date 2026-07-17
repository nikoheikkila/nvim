#!/usr/bin/env sh
# Same lint command CI runs (.github/workflows/ci.yml).
set -eu

if ! command -v selene >/dev/null 2>&1; then
  echo "selene not found. Install it with: brew install selene (or: cargo install selene)" >&2
  exit 1
fi

exec selene lua/ tests/
