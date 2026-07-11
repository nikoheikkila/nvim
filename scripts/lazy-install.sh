#!/usr/bin/env sh
# Fetch newly added plugin specs without touching already-installed plugins.
# Safe alternative to `:Lazy sync`, which also updates every pinned plugin.
set -eu

exec nvim --headless "+Lazy! install" +qa
