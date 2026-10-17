#!/usr/bin/env bash
# Smoke test: starts a virtual screen, takes a full and a cropped screenshot, checks their PNG sizes.
# Usage: test/smoke.sh   (run `./setup.sh` first)
set -euo pipefail

ROOT=$(dirname "$(dirname "$(readlink -f "$0")")")
LAUNCHSV=$ROOT/bin/launchsv
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

png_size() { python3 -c 'import struct,sys; print(*struct.unpack(">II", open(sys.argv[1], "rb").read()[16:24]))' "$1"; }
check() { # check LABEL EXPECTED ACTUAL
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'" >&2; exit 1; fi
}

"$LAUNCHSV" run -s 640x400 -- sh -c '"$1" shot "$2/full.png" && "$1" shot "$2/crop.png" 10 20 200 120' _ "$LAUNCHSV" "$OUT" >/dev/null
check "full screenshot is 640x400" "640 400" "$(png_size "$OUT/full.png")"
check "cropped screenshot is 200x120" "200 120" "$(png_size "$OUT/crop.png")"

"$LAUNCHSV" run -s 100x100 -- sh -c '! "$1" shot "$2/bad.png" 90 90 50 50 2>/dev/null' _ "$LAUNCHSV" "$OUT"
echo "ok   out-of-screen crop is rejected"

check "display is cleaned up" "0" "$(pgrep -fc "Xvfb.*-displayfd" || true)"
echo "all good"
