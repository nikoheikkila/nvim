#!/usr/bin/env bash
# Proves the integration tests do NOT depend on the real, user-editable config
# files (config.yml / theme.yml / .markdownlint.jsonc). It temporarily corrupts
# them, runs the integration suite -- which must still pass, because the specs
# read only the throwaway fixtures the harness injects via NVIM_CONFIG_ROOT
# (see scripts/busted-nvim.sh) -- then restores the EXACT original bytes.
#
# Why this script exists instead of doing it by hand:
#   - Restoration is guaranteed by a `trap` on EXIT/INT/TERM, so an interrupted
#     or failed run never leaves your real config corrupted. Overwriting a file
#     with `>` and restoring "later" by hand is a data-loss hazard if anything
#     in between fails.
#   - It backs up the CURRENT bytes (not HEAD), so it also preserves any
#     uncommitted local edits -- unlike `git checkout -- <file>`, which silently
#     discards uncommitted changes and cannot recover untracked content. Never
#     use `git checkout` to "undo" a file you corrupted for a test.
#
# Usage: scripts/verify-config-isolation.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

files=(".markdownlint.jsonc" "theme.yml" "config.yml")
backup="$(mktemp -d)"

restore() {
  for f in "${files[@]}"; do
    if [ -f "$backup/$f" ]; then
      cp -p "$backup/$f" "$root/$f"
    fi
  done
  rm -rf "$backup"
}
trap restore EXIT INT TERM

for f in "${files[@]}"; do
  cp -p "$root/$f" "$backup/$f"
done

# Corrupt each real file in a distinct way: invalid JSON, a bogus theme variant,
# and a sentinel daily dir. If any spec still read a real file, it would break.
# The literal `$HOME` is written verbatim on purpose (the YAML consumer expands
# it), so single quotes are correct here.
printf '{ "default": false, this is not valid json ]]]' > .markdownlint.jsonc
printf 'theme:\n  variant: this_variant_does_not_exist\n' > theme.yml
# shellcheck disable=SC2016
printf 'config:\n  daily:\n    directory: "$HOME/config-isolation-sentinel"\n' > config.yml

echo "Real config files corrupted in place; running integration tests..."
echo "(they must PASS -- specs use the NVIM_CONFIG_ROOT fixtures, not these files)"
task test:integration

echo
echo "PASS: integration tests are fully isolated from the real config files."
# The trap restores the originals on exit.
