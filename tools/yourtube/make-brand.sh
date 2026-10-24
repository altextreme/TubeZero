#!/usr/bin/env bash
# TubeZero: renders branding/*.svg (mark, wordmark, Roku tile, splash) into the app/lib images.
# The UI 9-patches are in make-assets.sh. Needs Google Chrome (headless) and ImageMagick (`magick`).
# Usage: tools/yourtube/make-brand.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BRAND="$ROOT/branding"
APP_IMG="$ROOT/playlet-app/src/images"
LIB_IMG="$ROOT/playlet-lib/src/images"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ROBOTO_BOLD="data:font/ttf;base64,$(base64 < "$ROOT/playlet-lib/src/fonts/roboto/Roboto-Bold.ttf" | tr -d '\n')"

# render <svg> <width> <height> <out.png>  (inlines Roboto Bold for the wordmark)
render() {
    local svg="$TMP/$(basename "$1")"
    python3 -c 'import sys; open(sys.argv[3],"w").write(open(sys.argv[1]).read().replace("../playlet-lib/src/fonts/roboto/Roboto-Bold.ttf", sys.argv[2]))' "$1" "$ROBOTO_BOLD" "$svg"
    set -- "$svg" "$2" "$3" "$4"
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
        --default-background-color=00000000 --window-size="$2,$3" \
        --screenshot="$4" "file://$1" >/dev/null 2>&1
}

render "$BRAND/mark.svg" 100 100 "$LIB_IMG/logo-fav.png"
render "$BRAND/logo-wordmark.svg" 254 100 "$LIB_IMG/logo-dark.png"
render "$BRAND/account-backend.svg" 256 256 "$LIB_IMG/youtube-logo.png"

render "$BRAND/poster.svg" 540 405 "$TMP/poster.png"
magick "$TMP/poster.png" "$APP_IMG/channel-poster_fhd.png"
magick "$TMP/poster.png" -resize 290x218! "$APP_IMG/channel-poster_hd.png"
magick "$TMP/poster.png" -resize 246x140! "$APP_IMG/channel-poster_sd.png"

render "$BRAND/splash.svg" 1920 1080 "$TMP/splash.png"
magick "$TMP/splash.png" -background "#0F0F0F" -flatten -quality 92 "$APP_IMG/splash-screen_fhd.jpg"
magick "$TMP/splash.png" -background "#0F0F0F" -flatten -resize 1280x720 -quality 92 "$APP_IMG/splash-screen_hd.jpg"
magick "$TMP/splash.png" -background "#0F0F0F" -flatten -resize 720x480! -quality 92 "$APP_IMG/splash-screen_sd.jpg"

