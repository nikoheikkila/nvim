#!/usr/bin/env bash
# Run every check CI runs, in CI's order: lint, unit tests, integration tests,
# and the missing-binary guard path of the markdown-lint spec. Green here
# means green in .github/workflows/ci.yml.
#
# Usage: scripts/check.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Lint =="
task lint

echo "== Unit tests =="
task test:unit

echo "== Integration tests =="
task test:integration

echo "== Integration tests: missing-binary guard path =="
scripts/test-without-binary.sh markdownlint-cli2 -- \
  task test:integration -- tests/integration/markdown_lint_spec.lua

echo "All checks passed"
