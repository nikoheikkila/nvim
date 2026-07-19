#!/usr/bin/env sh
# Install the latest released build of this Neovim configuration.
#
# Meant to be piped straight from GitHub:
#   curl -sSL https://raw.githubusercontent.com/nikoheikkila/nvim/refs/heads/main/scripts/install.sh | sh
# so it sticks to strict POSIX sh and tools every base OS already ships
# (curl or wget, tar, grep, sed, cut, mktemp) -- no jq, no bash. Piped runs
# also mean stdin is the script itself, so nothing here may prompt.
#
# Usage: install.sh [-o|--out <dir>]
# Without a flag the config lands in $XDG_CONFIG_HOME/nvim (when that base
# directory exists) or $HOME/.config/nvim (created if missing). An existing
# non-empty target is moved aside to <dir>.bak.<timestamp>, never merged over.

set -eu

REPO="nikoheikkila/nvim"
MIN_VERSION="0.12.4"

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

usage() {
  echo "usage: install.sh [-o|--out <dir>]" >&2
  exit 1
}

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    fail "neither curl nor wget is available; install one and retry"
  fi
}

out=""
while [ $# -gt 0 ]; do
  case $1 in
    -o|--out)
      [ $# -ge 2 ] || usage
      out=$2
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

command -v nvim >/dev/null 2>&1 ||
  fail "nvim not found on PATH; install Neovim v$MIN_VERSION or newer first"

version=$(nvim --version | sed -n '1s/^NVIM v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
[ -n "$version" ] || fail "could not parse the version from 'nvim --version'"

have=$((
  $(echo "$version" | cut -d. -f1) * 1000000 +
  $(echo "$version" | cut -d. -f2) * 1000 +
  $(echo "$version" | cut -d. -f3)
))
want=$((
  $(echo "$MIN_VERSION" | cut -d. -f1) * 1000000 +
  $(echo "$MIN_VERSION" | cut -d. -f2) * 1000 +
  $(echo "$MIN_VERSION" | cut -d. -f3)
))
[ "$have" -ge "$want" ] ||
  fail "Neovim v$version is too old; v$MIN_VERSION or newer is required"

if [ -z "$out" ]; then
  if [ -n "${XDG_CONFIG_HOME:-}" ] && [ -d "$XDG_CONFIG_HOME" ]; then
    out="$XDG_CONFIG_HOME/nvim"
  else
    out="$HOME/.config/nvim"
  fi
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

echo "Resolving the latest release of $REPO..."
download "https://api.github.com/repos/$REPO/releases/latest" "$workdir/release.json"
asset_url=$(
  grep -o '"browser_download_url": *"[^"]*\.tar\.gz"' "$workdir/release.json" |
    head -n1 | sed 's/.*"\(https[^"]*\)"/\1/'
)
[ -n "$asset_url" ] || fail "no .tar.gz asset found in the latest release of $REPO"

echo "Downloading $asset_url..."
download "$asset_url" "$workdir/nvim-config.tar.gz"

if [ -d "$out" ] && [ -n "$(ls -A "$out" 2>/dev/null)" ]; then
  backup="$out.bak.$(date +%Y%m%d%H%M%S)"
  mv "$out" "$backup"
  echo "Existing configuration moved to $backup"
fi
mkdir -p "$out"
out=$(cd "$out" && pwd)
tar -xzf "$workdir/nvim-config.tar.gz" -C "$out"
echo "Extracted configuration into $out"

# Neovim resolves its config as $XDG_CONFIG_HOME/$NVIM_APPNAME regardless of
# the working directory, so both are pointed at the output directory -- a
# no-op for the default location, required for a custom --out. The cd runs in
# a subshell, leaving the caller's working directory untouched.
config_home=$(dirname "$out")
appname=$(basename "$out")
echo "Installing plugins (this may take a while)..."
if (
  cd "$out" &&
    XDG_CONFIG_HOME="$config_home" NVIM_APPNAME="$appname" \
      nvim --headless "+Lazy! install" +qa
) >"$workdir/lazy-install.log" 2>&1; then
  echo "Installation successful: $out"
  if [ "$config_home/$appname" != "${XDG_CONFIG_HOME:-$HOME/.config}/nvim" ]; then
    echo "Launch it with: XDG_CONFIG_HOME=\"$config_home\" NVIM_APPNAME=\"$appname\" nvim"
  fi
else
  echo "install.sh: plugin installation failed; nvim output follows:" >&2
  cat "$workdir/lazy-install.log" >&2
  exit 1
fi
