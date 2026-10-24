#!/usr/bin/env bash
# YourTube: renders branding/*.svg into the app/lib image files and draws the
# UI 9-patches. Needs Google Chrome (headless) and ImageMagick (`magick`).
# Usage: tools/yourtube/make-assets.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BRAND="$ROOT/branding"
APP_IMG="$ROOT/playlet-app/src/images"
LIB_IMG="$ROOT/playlet-lib/src/images"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# render <svg> <width> <height> <out.png>
render() {
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

# Roku 9-patch: 1px border. Top/left black pixels = stretch region,
# bottom/right black pixels = content area (anything outside is padding).
# ninepatch <body.png> <stretch_from> <stretch_to> <content_from> <content_to> <out>
ninepatch() {
    local body="$1" s0="$2" s1="$3" c0="$4" c1="$5" out="$6"
    local w h
    w=$(magick identify -format %w "$body")
    h=$(magick identify -format %h "$body")
    magick "$body" -background none -gravity center -extent "$((w + 2))x$((h + 2))" \
        -fill black \
        -draw "line $((s0 + 1)),0 $((s1 + 1)),0" \
        -draw "line 0,$((s0 + 1)) 0,$((s1 + 1))" \
        -draw "line $((c0 + 1)),$((h + 1)) $((c1 + 1)),$((h + 1))" \
        -draw "line $((w + 1)),$((c0 + 1)) $((w + 1)),$((c1 + 1))" \
        "$out"
}

# Per resolution: scale factor relative to 720p
for res in 480p:0.667 720p:1 1080p:1.5; do
    name="${res%%:*}"
    k="${res##*:}"
    px() { printf "%.0f" "$(echo "$1 * $k" | bc -l)"; }

    # Focus ring: white rounded ring drawn outside the item, gap 6 / stroke 3 at 720p.
    pad=$(px 11); core=$(px 24); stroke=$(px 3); gap=$(px 6); r=$(px 13)
    size=$((pad * 2 + core))
    o=$((pad - gap - (stroke + 1) / 2))
    magick -size "${size}x${size}" xc:none -fill none -stroke white -strokewidth "$stroke" \
        -draw "roundrectangle $o,$o $((size - 1 - o)),$((size - 1 - o)) $r,$r" "$TMP/ring.png"
    mid=$((size / 2))
    ninepatch "$TMP/ring.png" $((mid - 1)) $((mid + 1)) "$pad" $((pad + core - 1)) "$LIB_IMG/yt-focus-ring.$name.9.png"

    # Thumbnail corner mask: background-colored corners, transparent middle.
    r=$(px 8); size=$((r * 2 + 6))
    magick -size "${size}x${size}" xc:"#0F0F0F" -fill black \
        -draw "roundrectangle 0,0 $((size - 1)),$((size - 1)) $r,$r" \
        -alpha set -channel A -fx "(r+g+b)==0 && a==1 ? 0 : 1" +channel \
        -fill none "$TMP/mask.png"
    magick "$TMP/mask.png" -alpha set -channel RGB -fill "#0F0F0F" -colorize 100 +channel "$TMP/mask.png"
    mid=$((size / 2))
    ninepatch "$TMP/mask.png" $((mid - 1)) $((mid + 1)) 0 $((size - 1)) "$LIB_IMG/yt-card-mask.$name.9.png"

    # Solid white rounded rect for badges/pills (tint with blendColor).
    r=$(px 4); size=$((r * 2 + 6))
    magick -size "${size}x${size}" xc:none -fill white \
        -draw "roundrectangle 0,0 $((size - 1)),$((size - 1)) $r,$r" "$TMP/pill.png"
    mid=$((size / 2))
    ninepatch "$TMP/pill.png" $((mid - 1)) $((mid + 1)) 0 $((size - 1)) "$LIB_IMG/yt-rounded.$name.9.png"
done

echo "YourTube assets written."
