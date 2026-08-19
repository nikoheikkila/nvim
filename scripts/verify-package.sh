#!/usr/bin/env bash
# Show — and sanity-check — what the release tarball would actually contain.
#
# `.nvimignore` is an rsync merge-filter ALLOWLIST, not an ignore file: the
# "Package artifact" step in .github/workflows/ci.yml stages the repo with
# `rsync -a --filter='merge .nvimignore' ./ "$stage/"` and everything not
# explicitly `+`-listed is dropped. That inversion is easy to forget, and the
# failure mode is silent — a new top-level config file works perfectly from a
# git clone and is simply absent for everyone who installed from a release.
# Nothing in the test suites catches it, because they all run against the
# checkout.
#
# Run this after adding or renaming anything at the repository root.
#
# Usage:
#   scripts/verify-package.sh            # list the staged tree, then check it
#   scripts/verify-package.sh --tree     # list only, no assertions
set -euo pipefail

cd "$(dirname "$0")/.."

list_only=false
[[ "${1:-}" == "--tree" ]] && list_only=true

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

rsync -a --filter='merge .nvimignore' ./ "$stage/"

echo "== Release tarball contents =="
(cd "$stage" && find . -mindepth 1 -maxdepth 1 | sed 's|^\./|  |' | sort)

if [[ "$list_only" == true ]]; then
  exit 0
fi

status=0
note() {
  echo "verify-package: $*" >&2
  status=1
}

# Everything the editor needs to boot and read its configuration. Extend this
# list when a new user-facing file joins the root.
for required in \
  init.lua \
  lua \
  docs \
  lazy-lock.json \
  config.yml \
  theme.yml \
  .vale.ini; do
  [[ -e "$stage/$required" ]] || note "MISSING from the tarball: $required (add '+ /$required' to .nvimignore)"
done

# Development-only trees. `scripts/` in particular must stay out: install.sh is
# fetched from GitHub and runs against the *extracted* config, so anything it
# needs has to be inlined rather than called as a sibling script.
for excluded in \
  scripts \
  tests \
  Taskfile.yml \
  .claude \
  .github \
  AGENTS.md \
  CONTRIBUTING.md \
  vale-styles; do
  [[ ! -e "$stage/$excluded" ]] || note "UNEXPECTEDLY shipped: $excluded (tighten .nvimignore)"
done

# Every config file the editor resolves through config/paths.lua has to be in
# the tarball, or the feature reading it is dead on a released install. Derived
# from the source so a new one cannot be forgotten here too.
while read -r name; do
  [[ -e "$stage/$name" ]] || note "config/paths.lua reads '$name', which the tarball does not carry"
done < <(grep -rhoE 'config_file\("[^"]+"\)' lua/ | sed -E 's/config_file\("(.*)"\)/\1/' | sort -u)

if [[ "$status" -eq 0 ]]; then
  echo "verify-package: tarball contents look right"
fi
exit "$status"
