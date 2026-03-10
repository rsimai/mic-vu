#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$PROJECT_DIR/plasmoid/org.kde.micvu"
PLASMOID_ID="org.kde.micvu"
VERSION="$(sed -n 's/.*"Version": "\([^"]*\)".*/\1/p' "$PKG_DIR/metadata.json" | head -n1)"
HELPER_SRC="$PKG_DIR/contents/helpers/mic_level.c"
HELPER_BIN="$PKG_DIR/contents/helpers/mic_level"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
  echo "kpackagetool6 not found. Install plasma6-sdk or plasma6-workspace tools first."
  exit 1
fi

if ! command -v cc >/dev/null 2>&1; then
  echo "C compiler not found. Install gcc (or clang) first."
  exit 1
fi

if [[ ! -f "$HELPER_SRC" ]]; then
  echo "Helper source not found: $HELPER_SRC"
  exit 1
fi

echo "Building helper binary..."
cc -O2 "$HELPER_SRC" -o "$HELPER_BIN" -lpulse-simple -lpulse -lm
chmod +x "$HELPER_BIN"

kpackagetool6 -t Plasma/Applet -r "$PLASMOID_ID" >/dev/null 2>&1 || true
kpackagetool6 -t Plasma/Applet -i "$PKG_DIR"

echo "Installed plasmoid: $PLASMOID_ID"
if [[ -n "$VERSION" ]]; then
  echo "Version: $VERSION"
fi
echo "Add widget in KDE panel: right-click panel -> Add Widgets -> Mic VU"
echo "If it does not appear immediately, run: kquitapp6 plasmashell && kstart6 plasmashell"
