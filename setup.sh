#!/usr/bin/env bash
# One-time launchvs installation.
#   root:     installs packages.txt with apt.
#   non-root: unprivileged bootstrap, the .deb files are downloaded and extracted into $LAUNCHVS_HOME.
# Usage: ./setup.sh [--force]
set -euo pipefail

ROOT=$(dirname "$(readlink -f "$0")")
HOME_DIR=${LAUNCHVS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/launchvs}
SYSROOT=$HOME_DIR/root
FORCE=0; [ "${1:-}" = "--force" ] && FORCE=1
PKGS=$(grep -vE '^[[:space:]]*(#|$)' "$ROOT/packages.txt" | tr '\n' ' ')
HASH=$(sha256sum "$ROOT/packages.txt" | cut -c1-16)
say() { echo "[launchvs setup] $*"; }

command -v apt-get >/dev/null || { echo "launchvs setup: apt-get not found (Debian/Ubuntu only)" >&2; exit 1; }
command -v python3 >/dev/null || { echo "launchvs setup: python3 is required" >&2; exit 1; }
mkdir -p "$HOME_DIR"

if [ "$(id -u)" = 0 ]; then
  say "running as root: installing packages with apt"
  rm -f "$HOME_DIR/.bootstrap"
  apt-get update -qq
  # shellcheck disable=SC2086
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $PKGS
else
  say "not root: bootstrapping into $HOME_DIR (no apt install)"
  if [ "$FORCE" = 0 ] && [ "$(cat "$HOME_DIR/.bootstrap" 2>/dev/null || true)" = "$HASH" ]; then
    say "packages already extracted (packages.txt unchanged, use --force to redo)"
  else
    APT=(-o "Dir::State::lists=$HOME_DIR/apt/lists" -o "Dir::Cache=$HOME_DIR/apt/cache"
         -o "Dir::Cache::archives=$HOME_DIR/apt/cache/archives" -o Debug::NoLocking=true)
    mkdir -p "$HOME_DIR/apt/lists/partial" "$HOME_DIR/apt/cache/archives/partial" "$HOME_DIR/debs"
    # Ubuntu's docker-clean hook prints a harmless "cannot remove /var/cache/apt/..." error for non-root users.
    apt-get update -qq "${APT[@]}" 2>&1 | { grep -v '/var/cache/apt/archives/partial' || true; }
    cd "$HOME_DIR/debs"
    rm -f ./*.deb
    # shellcheck disable=SC2086
    if ! apt-get download -qq "${APT[@]}" $PKGS 2>"$HOME_DIR/download.err"; then
      say "bulk download failed, retrying package by package"
      for p in $PKGS; do apt-get download -qq "${APT[@]}" "$p" 2>/dev/null || say "WARNING: $p is unavailable"; done
    fi
    rm -rf "$SYSROOT"; mkdir -p "$SYSROOT"
    for f in ./*.deb; do dpkg-deb -x "$f" "$SYSROOT"; done
    say "$(ls ./*.deb | wc -l) packages extracted"

    # Xvfb hardcodes /usr/bin (xkbcomp) and /usr/share/X11/xkb. Outside /usr it cannot find them, so we
    # patch a copy of the binary with shorter paths (/tmp/xb, /tmp/xk) that launchvs symlinks at every start.
    python3 - "$SYSROOT/usr/bin/Xvfb" "$HOME_DIR/Xvfb-relocated" <<'PY'
import sys
from pathlib import Path

src = Path(sys.argv[1]).read_bytes()
for old, new in [(b"/usr/bin", b"/tmp/xb"), (b"/usr/share/X11/xkb", b"/tmp/xk")]:
    assert src.count(old) >= 1, f"{old!r} not found in Xvfb (incompatible version?)"
    src = src.replace(old, new + b"\0" * (len(old) - len(new)))
out = Path(sys.argv[2])
out.write_bytes(src)
out.chmod(0o755)
PY
    cat >"$HOME_DIR/fonts.conf" <<FONTS
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>/usr/share/fonts</dir>
  <dir>$SYSROOT/usr/share/fonts</dir>
  <cachedir>$HOME_DIR/font-cache</cachedir>
  <alias><family>emoji</family><prefer><family>Noto Color Emoji</family></prefer></alias>
</fontconfig>
FONTS
    echo "$HASH" >"$HOME_DIR/.bootstrap"
  fi
fi

# Playwright, needed by 'launchvs browser'
if command -v node >/dev/null && command -v npm >/dev/null; then
  mkdir -p "$HOME_DIR/node"; cd "$HOME_DIR/node"
  [ -f package.json ] || echo '{"private":true,"type":"module"}' >package.json
  if [ ! -d node_modules/playwright ]; then
    say "installing playwright"
    npm install --no-audit --no-fund --silent playwright@^1.58
  fi
  say "installing Playwright's Chromium (Chrome) and Firefox (no-op when already cached)"
  # Playwright prints a "missing host dependencies" warning in bootstrap mode: the libraries are provided by launchvs.
  npx --no-install playwright install chromium firefox >/dev/null 2>&1
else
  say "node/npm not found: 'launchvs browser' will be unavailable (everything else works)"
fi

say "self-test"
"$ROOT/bin/launchvs" run -s 320x200 -- sh -c \
  'xwd -root -silent | python3 "$1" - "$2" && echo "virtual screen OK"' _ "$ROOT/lib/xwd2png.py" "$HOME_DIR/selftest.png"
