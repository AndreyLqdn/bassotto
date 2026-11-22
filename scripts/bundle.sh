#!/usr/bin/env bash
# Builds Bassotto.app with the Command Line Tools only (no Xcode).
#   ./scripts/bundle.sh            build + bundle into build/Bassotto.app
#   ./scripts/bundle.sh --install  also copy to ~/Applications, register the widget and launch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Bassotto.app"
APPEX="$APP/Contents/PlugIns/BassottoWidget.appex"

cd "$ROOT"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS"

cp "$BIN/Bassotto"              "$APP/Contents/MacOS/Bassotto"
cp Support/App/Info.plist       "$APP/Contents/Info.plist"
cp "$BIN/BassottoWidget"        "$APPEX/Contents/MacOS/BassottoWidget"
cp Support/Widget/Info.plist    "$APPEX/Contents/Info.plist"

# Ad-hoc signing: inside-out (extension first, then the app).
codesign --force --sign - --timestamp=none \
  --entitlements Support/Widget/Widget.entitlements "$APPEX"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  DEST="$HOME/Applications/Bassotto.app"
  pkill -x Bassotto 2>/dev/null || true
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
  pluginkit -a "$DEST/Contents/PlugIns/BassottoWidget.appex"
  open "$DEST"
  echo "Installed $DEST"
fi
