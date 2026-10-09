#!/usr/bin/env sh
# Run a command and fail if it changed the working tree.
#
# The integration suite drives real plugins inside a real Neovim, and some of
# them write files: grug-far's Replace rewrites every match under the paths it
# is given, and an empty Paths input means "the cwd" -- which, under
# `task test:integration`, is this repository. A spec that let one of those
# actions escape its temp directory once rewrote a file here, and nothing
# noticed. This makes that a hard failure instead of an accident to stumble on.
#
# The snapshot is a git tree object built through a throwaway index, so it
# covers tracked *and* untracked files (minus .gitignore'd ones) without
# touching the real index or the stash. Outside a git work tree (a release
# install has no .git) the command just runs.
#
# Editing files while the guarded command runs trips it too; rerun if so.
#
# Usage: scripts/guard-worktree.sh -- <command> [args...]

set -eu

if [ "${1:-}" = "--" ]; then
  shift
fi
if [ $# -eq 0 ]; then
  echo "usage: $0 -- <command> [args...]" >&2
  exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exec "$@"
fi

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# Tree hash of the whole work tree. Seeding the throwaway index from the real
# one lets `git add -A` skip rehashing unchanged files.
snapshot() {
  rm -f "$scratch/index"
  cp "$(git rev-parse --git-path index)" "$scratch/index" 2>/dev/null || :
  GIT_INDEX_FILE="$scratch/index" git add -A >/dev/null 2>&1
  GIT_INDEX_FILE="$scratch/index" git write-tree
}

before=$(snapshot)
status=0
"$@" || status=$?
after=$(snapshot)

if [ "$before" != "$after" ]; then
  {
    echo "guard-worktree: the command changed the working tree:"
    git diff --name-status "$before" "$after" | sed 's/^/  /'
    echo "A test wrote outside its temp directory. Confine file-writing specs with :tcd into a"
    echo "tempname() dir (see tests/integration/search_replace_spec.lua), then restore the files above."
  } >&2
  [ "$status" -ne 0 ] || status=1
fi

exit "$status"
