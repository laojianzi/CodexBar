#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
export LC_CTYPE=C
export LANG=C

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="${CODEXBAR_DEPENDENCY_OVERRIDE_DIR:-${RUNNER_TEMP:-"$ROOT_DIR/.build"}/codexbar-macos12-deps}"

rm -rf "$DEPS_DIR"
mkdir -p "$DEPS_DIR"

git -C "$DEPS_DIR" clone --quiet --no-checkout --depth 1 \
  https://github.com/steipete/Commander.git Commander
git -C "$DEPS_DIR/Commander" fetch --quiet --depth 1 origin ae2ce746b386ff94b26648cfe5625cfa8d02639b
git -C "$DEPS_DIR/Commander" -c advice.detachedHead=false checkout --quiet FETCH_HEAD

git -C "$DEPS_DIR" clone --quiet --no-checkout --depth 1 \
  https://github.com/steipete/SweetCookieKit.git SweetCookieKit
git -C "$DEPS_DIR/SweetCookieKit" fetch --quiet --depth 1 origin 21bedea672a3e63ccad24d744051e76cdf0462dd
git -C "$DEPS_DIR/SweetCookieKit" -c advice.detachedHead=false checkout --quiet FETCH_HEAD

perl -0pi -e 's/\.macOS\(\.v14\)/.macOS(.v12)/' "$DEPS_DIR/Commander/Package.swift"
perl -0pi -e 's/\.macOS\(\.v13\)/.macOS(.v12)/' "$DEPS_DIR/SweetCookieKit/Package.swift"

grep -F '.macOS(.v12)' "$DEPS_DIR/Commander/Package.swift" >/dev/null
grep -F '.macOS(.v12)' "$DEPS_DIR/SweetCookieKit/Package.swift" >/dev/null

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "CODEXBAR_USE_LOCAL_COMMANDER=1"
    echo "CODEXBAR_COMMANDER_PATH=$DEPS_DIR/Commander"
    echo "CODEXBAR_USE_LOCAL_SWEETCOOKIEKIT=1"
    echo "CODEXBAR_SWEETCOOKIEKIT_PATH=$DEPS_DIR/SweetCookieKit"
  } >> "$GITHUB_ENV"
else
  cat <<EOF
export CODEXBAR_USE_LOCAL_COMMANDER=1
export CODEXBAR_COMMANDER_PATH="$DEPS_DIR/Commander"
export CODEXBAR_USE_LOCAL_SWEETCOOKIEKIT=1
export CODEXBAR_SWEETCOOKIEKIT_PATH="$DEPS_DIR/SweetCookieKit"
EOF
fi
