#!/usr/bin/env sh
# Install the latest released build of this Neovim configuration.
#
# Meant to be piped straight from GitHub:
#   curl -sSL https://raw.githubusercontent.com/nikoheikkila/nvim/refs/heads/main/scripts/install.sh | sh
# so it sticks to strict POSIX sh and tools every base OS already ships
# (curl or wget, tar, grep, sed, cut, mktemp) -- no jq, no bash. Piped runs
# also mean stdin is the script itself, so nothing here may prompt.
#
# The release asset is fetched from github.com's releases/latest/download/
# endpoint rather than the REST API, whose unauthenticated rate limit is charged
# to the caller's IP address and returns 403 once drained. Downloads retry with
# backoff on top of that.
#
# Usage: install.sh [-o|--out <dir>]
# Without a flag the config lands in $XDG_CONFIG_HOME/nvim (when that base
# directory exists) or $HOME/.config/nvim (created if missing). An existing
# non-empty target is moved aside to <dir>.bak.<timestamp>, never merged over.

set -eu

REPO="nikoheikkila/nvim"
MIN_VERSION="0.12.4"
# Stable, version-agnostic asset name attached to every release alongside the
# CalVer-stamped tarball, so the download URL never needs resolving. Renaming it
# here means renaming it in the package job of .github/workflows/ci.yml too.
ASSET="nvim-config.tar.gz"

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

usage() {
  echo "usage: install.sh [-o|--out <dir>]" >&2
  exit 1
}

# --retry skips 4xx by design, and GitHub answers a rate limit with 403, so
# --retry-all-errors (curl >= 7.71) is what makes a 403 retryable at all -- and
# only in combination with -f. It's feature-probed because macOS system curl
# ranges from 7.64 to 8.4+ depending on the release. No --retry-delay: curl's
# default backoff is exponential and honours a Retry-After header, which is what
# GitHub's own best-practices guide asks for. The cost is that a genuine 404
# burns all five attempts before failing.
download_with_curl() {
  retry_all=""
  if curl --help all 2>/dev/null | grep -q -- --retry-all-errors; then
    retry_all=--retry-all-errors
  fi

  # Unquoted on purpose: an empty retry_all must expand to no argument at all.
  # shellcheck disable=SC2086
  curl -fsSL --connect-timeout 10 --max-time 300 \
    --retry 5 --retry-max-time 120 --retry-connrefused \
    $retry_all -o "$2" "$1"
}

# wget already retries 20 times by default but treats every 4xx as fatal, so a
# 403 needs --retry-on-http-error to be retried at all. Its backoff is linear
# rather than exponential, and it has no --retry-max-time equivalent. BusyBox
# wget supports none of this, hence the probe.
download_with_wget() {
  retry_http=""
  if wget --help 2>&1 | grep -q -- --retry-on-http-error; then
    retry_http=--retry-on-http-error=403,429,500,502,503,504
  fi

  # shellcheck disable=SC2086
  wget -q --tries=5 --waitretry=5 --timeout=30 $retry_http -O "$2" "$1"
}

download() {
  if command -v curl >/dev/null 2>&1; then
    download_with_curl "$1" "$2"
  elif command -v wget >/dev/null 2>&1; then
    download_with_wget "$1" "$2"
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

# This endpoint on github.com redirects straight to the asset without touching
# api.github.com, whose unauthenticated limit is 60 requests per hour shared
# across every caller on the same IP address -- the source of the intermittent
# 403s this avoids. Each retry re-follows the redirect from here, so the
# short-lived signature on the final CDN URL is never reused.
asset_url="https://github.com/$REPO/releases/latest/download/$ASSET"

echo "Downloading $asset_url..."
download "$asset_url" "$workdir/$ASSET" || fail "could not download $asset_url.
GitHub answers with HTTP 403 when requests from your IP address are rate limited
(shared office, VPN, and CI addresses hit this). Wait a few minutes and retry, or
install from source -- see docs/installation.md."

if [ -d "$out" ] && [ -n "$(ls -A "$out" 2>/dev/null)" ]; then
  backup="$out.bak.$(date +%Y%m%d%H%M%S)"
  mv "$out" "$backup"
  echo "Existing configuration moved to $backup"
fi
mkdir -p "$out"
out=$(cd "$out" && pwd)
tar -xzf "$workdir/$ASSET" -C "$out"
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
