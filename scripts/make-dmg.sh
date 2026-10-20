#!/usr/bin/env bash
# Builds a DMG: app on the left, Applications shortcut on the right.
# Usage: scripts/make-dmg.sh <path/to/App.app> <version> [out-dir]
#
# Uses dmgbuild, which writes the Finder layout itself. No Finder or AppleScript session
# is needed, so it behaves the same on a headless CI runner and on a laptop.
set -euo pipefail

APP=${1:?usage: make-dmg.sh <App.app> <version> [out-dir]}
VERSION=${2:?usage: make-dmg.sh <App.app> <version> [out-dir]}
OUT=${3:-dist}

[ -d "$APP" ] || { echo "error: $APP not found" >&2; exit 1; }

HERE=$(cd "$(dirname "$0")" && pwd)
NAME=$(basename "$APP" .app)
mkdir -p "$OUT"
DMG="$(cd "$OUT" && pwd)/$NAME-$VERSION.dmg"
WORK=$(mktemp -d)
MNT=$WORK/mnt
mkdir "$MNT"

# Spotlight can hold a fresh volume for a moment: retry, then force.
MOUNTED=0
detach() {
  [ "$MOUNTED" = 1 ] || return 0
  MOUNTED=0
  for _ in 1 2 3 4 5; do
    hdiutil detach "$MNT" -quiet 2>/dev/null && return 0
    sleep 1
  done
  hdiutil detach -force "$MNT" -quiet 2>/dev/null || true
}
cleanup() {
  detach
  rm -rf "$WORK"
}
trap cleanup EXIT

python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' || { echo "error: python3 >= 3.10 required" >&2; exit 1; }
python3 -m venv "$WORK/venv"
"$WORK/venv/bin/pip" install --quiet --disable-pip-version-check -r "$HERE/dmg-requirements.txt"

rm -f "$DMG"
"$WORK/venv/bin/dmgbuild" -s "$HERE/dmg-settings.py" -D app="$APP" "$NAME" "$DMG"

# Verify what was built, not what we meant to build.
hdiutil attach -readonly -nobrowse -mountpoint "$MNT" "$DMG" >/dev/null
MOUNTED=1
[ -d "$MNT/$NAME.app" ] || { echo "error: $NAME.app missing from DMG" >&2; exit 1; }
codesign --verify --deep --strict "$MNT/$NAME.app" || { echo "error: app signature broken inside DMG" >&2; exit 1; }
[ "$(readlink "$MNT/Applications")" = /Applications ] || { echo "error: Applications link missing from DMG" >&2; exit 1; }
"$WORK/venv/bin/python" - "$MNT/.DS_Store" "$NAME.app" <<'EOF'
import sys
from ds_store import DSStore

store, app = sys.argv[1:3]
loc, view = {}, {}
with DSStore.open(store, "r") as d:
    for e in d:
        if e.code == b"Iloc":
            loc[e.filename] = e.value
        if e.code == b"icvp" and e.filename == ".":
            view = e.value
(ax, ay), (bx, by) = loc[app], loc["Applications"]
assert ax < bx and ay == by, f"layout wrong: {app} {loc[app]} Applications {loc['Applications']}"
assert view["iconSize"] == 128, f"icon size {view['iconSize']}"
print(f"layout ok: {app} at {loc[app]}, Applications at {loc['Applications']}")
EOF
detach

echo "$DMG"
