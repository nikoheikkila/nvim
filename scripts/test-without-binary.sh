#!/usr/bin/env sh
# Run a command with one binary hidden from PATH, without hiding everything
# else that happens to live alongside it (e.g. `nvim` and `rg` are both under
# /opt/homebrew/bin on macOS -- naively stripping that whole directory from
# PATH would also hide nvim itself).
#
# Useful for exercising executable-guard fallback code paths, e.g.
# lua/plugins/git.lua's `lazygit` guard or lua/plugins/picker.lua's `rg`
# guard, without uninstalling the real binary.
#
# Usage: scripts/test-without-binary.sh <binary-name> -- <command> [args...]
# Example:
#   scripts/test-without-binary.sh rg -- \
#     nvim --headless -c 'lua print(vim.fn.executable("rg"))' -c qa

set -eu

if [ $# -lt 1 ]; then
  echo "usage: $0 <binary-name> -- <command> [args...]" >&2
  exit 1
fi

binary=$1
shift
if [ "${1:-}" = "--" ]; then
  shift
fi

if [ $# -eq 0 ]; then
  echo "usage: $0 <binary-name> -- <command> [args...]" >&2
  exit 1
fi

fakebin=$(mktemp -d)
trap 'rm -rf "$fakebin"' EXIT

old_ifs=$IFS
IFS=':'
for dir in $PATH; do
  IFS=$old_ifs
  [ -d "$dir" ] || continue
  for entry in "$dir"/*; do
    [ -e "$entry" ] || continue
    name=$(basename "$entry")
    [ "$name" = "$binary" ] && continue
    [ -e "$fakebin/$name" ] && continue
    ln -sf "$entry" "$fakebin/$name" 2>/dev/null || true
  done
  IFS=':'
done
IFS=$old_ifs

PATH="$fakebin" exec "$@"
