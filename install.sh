#!/usr/bin/env bash
# Install Bassotto, the dachshund who lives on your Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/AndreyLqdn/bassotto/main/install.sh | bash
#
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/AndreyLqdn/bassotto/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO="AndreyLqdn/bassotto"
APP="Bassotto.app"
URL="${BASSOTTO_URL:-https://github.com/$REPO/releases/latest/download/Bassotto.zip}"  # override to test

say()  { printf '\033[1m🐾 %s\033[0m\n' "$*"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Prefer /Applications; fall back to ~/Applications when it isn't writable.
if [[ -w /Applications ]]; then DEST_DIR="/Applications"; else DEST_DIR="$HOME/Applications"; fi
DEST="$DEST_DIR/$APP"

quit_running() { pkill -x Bassotto 2>/dev/null || true; }

if [[ "${1:-}" == "--uninstall" ]]; then
  quit_running
  rm -rf "/Applications/$APP" "$HOME/Applications/$APP"
  say "Bassotto has gone home. Bye!"
  exit 0
fi

[[ "$(uname -s)" == "Darwin" ]] || fail "Bassotto only runs on macOS."
[[ "$(uname -m)" == "arm64" ]] || fail "Bassotto currently needs an Apple Silicon Mac."
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
(( MAJOR >= 14 )) || fail "Bassotto needs macOS 14 Sonoma or later (you have $(sw_vers -productVersion))."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Fetching the latest Bassotto…"
curl -fsSL "$URL" -o "$TMP/Bassotto.zip" || fail "Download failed. Is there a release yet? https://github.com/$REPO/releases"
ditto -x -k "$TMP/Bassotto.zip" "$TMP"
[[ -d "$TMP/$APP" ]] || fail "The download didn't contain $APP."

quit_running
mkdir -p "$DEST_DIR"
rm -rf "$DEST"
mv "$TMP/$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

say "Installed to $DEST"
open "$DEST"
say "He's on your Dock now. Find him in the menu bar too."
