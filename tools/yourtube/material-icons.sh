#!/usr/bin/env bash
# YourTube: renders Google Material Symbols (Rounded, Apache 2.0; sources in branding/material-symbols)
# into playlet-lib/src/images/icons/ms/. Each line: <symbol> <output name> <size px> [color]
# Sizes match the Playlet icons they replace, so layouts don't shift.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/branding/material-symbols"
OUT="$ROOT/playlet-lib/src/images/icons/ms"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

# render <svg> <size> <color> <out.png>: draw large in Chrome, then downscale for clean edges
render() {
    local svg="$TMP/in.svg"
    sed "s|<svg |<svg fill=\"$3\" |; s|height=\"24\"|height=\"192\"|; s|width=\"24\"|width=\"192\"|" "$1" > "$svg"
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
        --default-background-color=00000000 --window-size=192,192 --screenshot="$TMP/big.png" "file://$svg" >/dev/null 2>&1
    magick "$TMP/big.png" -resize "${2}x${2}" -depth 8 "PNG32:$4"
}

while read -r symbol name size color; do
    [ -z "$symbol" ] && continue
    render "$SRC/$symbol.svg" "$size" "${color:-#FFFFFF}" "$OUT/$name.png"
done <<'LIST'
home home 48
home_fill1 home_fill 48
search search 48
search_fill1 search_fill 48
subscriptions subscriptions 48
subscriptions_fill1 subscriptions_fill 48
video_library video_library 48
video_library_fill1 video_library_fill 48
bookmark bookmark 48
bookmark_fill1 bookmark_fill 48
settings settings 48
settings_fill1 settings_fill 48
smartphone smartphone 48
smartphone_fill1 smartphone_fill 48
info info 48
info_fill1 info_fill 48
live_tv live_tv 48
live_tv_fill1 live_tv_fill 48
star_fill1 star 24
subscriptions empty_subscriptions 96 #717171
video_library empty_you 96 #717171
home empty_home 96 #717171
star_fill1 star_dark 24 #0F0F0F
account_circle_fill1 account_circle 64
account_circle_fill1 account_circle_200 200
tune tune 64
language language 22
language language_dark 22 #0F0F0F
history history 36
history history_dark 36 #0F0F0F
mic_fill1 mic 64
mic_fill1 mic_dark 64 #0F0F0F
edit edit 48
workspace_premium workspace_premium 80
check_circle_fill1 check_circle 64 #2BA640
cancel_fill1 cancel 64 #FF4E45
play_arrow_fill1 play_arrow 63
pause_fill1 pause 63
picture_in_picture_alt picture_in_picture_alt 63
skip_next_fill1 skip_next 42
skip_previous_fill1 skip_previous 42
comment comment 63
chat chat 63
thumb_up like 63
thumb_up_fill1 like_fill 63
thumb_down dislike 63
thumb_down_fill1 dislike_fill 63
playlist_add save 63
playlist_add_check save_done 63
thumb_up thumb_up 20 #AAAAAA
LIST
# Player action glyphs fill their whole box; shrink it to sit inside the player button disc like the others.
for glyph in comment chat like like_fill dislike dislike_fill save save_done; do
    magick "$OUT/$glyph.png" -resize 48x48 -background none -gravity center -extent 63x63 "PNG32:$OUT/$glyph.png"
done
echo "Material Symbols rendered to $OUT"
