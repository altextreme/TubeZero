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

    # Focus ring: white, 5 thick, sits on the thumbnail edge (outer edge 2px outside), radius 11 at 720p.
    pad=$(px 3); core=$(px 30); stroke=$(px 5); r=$(px 11)
    size=$((pad * 2 + core))
    o=$(echo "$pad - $(px 2) + $stroke / 2" | bc -l)
    magick -size "${size}x${size}" xc:none -fill none -stroke white -strokewidth "$stroke" \
        -draw "roundrectangle $o,$o $(echo "$size - 1 - $o" | bc -l),$(echo "$size - 1 - $o" | bc -l) $r,$r" "$TMP/ring.png"
    mid=$((size / 2))
    ninepatch "$TMP/ring.png" $((mid - 1)) $((mid + 1)) "$pad" $((pad + core - 1)) "$LIB_IMG/yt-focus-ring.$name.9.png"

    # Thumbnail corner mask: background-colored corners, transparent middle.
    r=$(px 10); size=$((r * 2 + 6))
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

# Fully rounded pills (suggestions, keys, chips): light = focused, dark = resting surface.
for res in 480p:0.667 720p:1 1080p:1.5; do
    name="${res%%:*}"
    k="${res##*:}"
    r=$(printf "%.0f" "$(echo "18 * $k" | bc -l)"); size=$((r * 2 + 4))
    for variant in light:#F1F1F1 dark:#282828; do
        magick -size "${size}x${size}" xc:none -fill "${variant##*:}" \
            -draw "roundrectangle 0,0 $((size - 1)),$((size - 1)) $r,$r" "$TMP/pill.png"
        mid=$((size / 2))
        ninepatch "$TMP/pill.png" $((mid - 1)) $((mid + 1)) 0 $((size - 1)) "$LIB_IMG/yt-pill-${variant%%:*}.$name.9.png"
    done
done

# List focus pill with 16px (720p) horizontal padding, so focused list text sits inset from the pill's edge.
for res in 480p:0.667 720p:1 1080p:1.5; do
    name="${res%%:*}"
    k="${res##*:}"
    r=$(printf "%.0f" "$(echo "18 * $k" | bc -l)"); p=$(printf "%.0f" "$(echo "16 * $k" | bc -l)")
    w=$((r * 2 + 4 + p * 2)); h=$((r * 2 + 4))
    magick -size "${w}x${h}" xc:none -fill "#F1F1F1" \
        -draw "roundrectangle 0,0 $((w - 1)),$((h - 1)) $r,$r" "$TMP/pill.png"
    mid=$((h / 2)); midx=$((w / 2))
    magick "$TMP/pill.png" -background none -gravity center -extent "$((w + 2))x$((h + 2))" -fill black \
        -draw "line $((midx)),0 $((midx + 2)),0" \
        -draw "line 0,$((mid)) 0,$((mid + 2))" \
        -draw "line $((p + 1)),$((h + 1)) $((w - p)),$((h + 1))" \
        -draw "line $((w + 1)),1 $((w + 1)),$h" \
        "PNG32:$LIB_IMG/yt-pill-light-padded.$name.9.png"
    # Same padding, invisible: the list footprint, so rows don't shift sideways when focus leaves the list.
    magick "$TMP/pill.png" -channel A -evaluate set 0 +channel -background none -gravity center -extent "$((w + 2))x$((h + 2))" -fill black \
        -draw "line $((midx)),0 $((midx + 2)),0" \
        -draw "line 0,$((mid)) 0,$((mid + 2))" \
        -draw "line $((p + 1)),$((h + 1)) $((w - p)),$((h + 1))" \
        -draw "line $((w + 1)),1 $((w + 1)),$h" \
        "PNG32:$LIB_IMG/yt-transparent-padded.$name.9.png"
done

# ButtonEx background: white, tinted in code. Radius 24 at 720p.
for res in 480p:0.667 720p:1 1080p:1.5; do
    name="${res%%:*}"
    k="${res##*:}"
    r=$(printf "%.0f" "$(echo "24 * $k" | bc -l)"); size=$((r * 2 + 4))
    magick -size "${size}x${size}" xc:none -fill white \
        -draw "roundrectangle 0,0 $((size - 1)),$((size - 1)) $r,$r" "$TMP/pill.png"
    mid=$((size / 2))
    ninepatch "$TMP/pill.png" $((mid - 1)) $((mid + 1)) 0 $((size - 1)) "$LIB_IMG/yt-button-pill.$name.9.png"
done

# Comment avatars: background-colored corners around a transparent circle (panel and focused card colors).
for c in 212121 3F3F3F; do
    magick -size 160x160 "xc:#$c" \( -size 160x160 xc:black -fill white -draw "circle 80,80 80,1" \) -alpha off \
        -compose CopyOpacity -composite -channel A -negate +channel -resize 80x80 "PNG32:$LIB_IMG/yt-avatar-ring-$c.png"
done

# Transparent 1px image (hides Roku-drawn key backgrounds)
magick -size 1x1 xc:none "PNG32:$LIB_IMG/yt-transparent.png"


# Player: scrubber fill (red -> pink, sized to the 1144px trackbar) and the bottom scrim.
for res in 480p:0.667 720p:1 1080p:1.5; do
    name="${res%%:*}"
    k="${res##*:}"
    w=$(printf "%.0f" "$(echo "1144 * $k" | bc -l)"); h=$(printf "%.0f" "$(echo "5 * $k" | bc -l)")
    magick -size "${h}x${w}" gradient:"#FD1C7A"-"#FB0034" -rotate 90 -depth 8 "PNG32:$LIB_IMG/yt-scrub-fill.$name.png"
done
magick -size 8x256 gradient:"rgba(0,0,0,0)"-"rgba(0,0,0,0.88)" -depth 8 "PNG32:$LIB_IMG/yt-player-scrim.png"



"$ROOT/tools/yourtube/material-icons.sh"

echo "YourTube assets written."
