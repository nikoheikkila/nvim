#!/usr/bin/env sh
# Prove a test can fail: apply one sed edit to a source file, run a command,
# and always restore the file -- also on failure or Ctrl-C.
#
# A spec that passes is only evidence once it has been seen to fail without the
# code it covers. The hand-rolled version of this (cp to a backup, sed -i, run,
# cp back) leaves the mutation in place when interrupted, and does not notice
# when the sed expression matched nothing -- a "surviving mutant" that was never
# applied.
#
# Exit status: 0 when the command fails (mutant killed -- the test works),
# 1 when it passes (mutant survived -- the test misses the change), 2 on usage
# errors or when the expression changes nothing.
#
# Usage: scripts/mutate.sh <file> <sed-expression> -- <command> [args...]
# Example:
#   scripts/mutate.sh lua/config/search_replace.lua 's/    instance:hide()/    -- hide/' -- \
#     task test:integration -- tests/integration/search_replace_spec.lua

set -eu

if [ $# -lt 4 ] || [ "$3" != "--" ]; then
  echo "usage: $0 <file> <sed-expression> -- <command> [args...]" >&2
  exit 2
fi

file=$1
expression=$2
shift 3

if [ ! -f "$file" ]; then
  echo "mutate: no such file: $file" >&2
  exit 2
fi

scratch=$(mktemp -d)
cp -p "$file" "$scratch/original"
# Restore by copying back, so the file keeps its inode and permissions.
trap 'cp -p "$scratch/original" "$file"; rm -rf "$scratch"' EXIT
trap 'exit 130' INT TERM

# Plain `sed -e` into a temp file: `sed -i` takes different arguments on BSD
# (macOS) and GNU sed.
sed -e "$expression" "$scratch/original" >"$scratch/mutated"
if cmp -s "$scratch/original" "$scratch/mutated"; then
  echo "mutate: '$expression' changes nothing in $file" >&2
  exit 2
fi
cp "$scratch/mutated" "$file"

echo "mutate: $file mutated with '$expression'" >&2
if "$@"; then
  echo "mutate: SURVIVED -- the command still passes with the mutation" >&2
  exit 1
fi
echo "mutate: KILLED -- the command fails with the mutation" >&2
exit 0
