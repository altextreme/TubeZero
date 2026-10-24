#!/usr/bin/env bash
# YourTube: walks the TV through every screen over ECP and saves a screenshot of each to out/screens/.
# Screenshots use Playlet's tools/screenshot.js, which reads ROKU_DEV_TARGET / ROKU_DEVPASSWORD from .env.
# Run it yourself: tools/yourtube/capture-screens.sh   (takes about 2 minutes; leave the remote alone)
set -euo pipefail
cd "$(dirname "$0")/../.."

if [ ! -f .env ] || grep -q 'REPLACE_WITH_YOUR_PASSWORD' .env; then
    echo "Put your Roku developer password in .env first (replace REPLACE_WITH_YOUR_PASSWORD)."
    exit 1
fi

TV="$(sed -n 's/^ROKU_DEV_TARGET=//p' .env)"
TV="${TV:-192.168.1.164}"
ECP="http://$TV:8060"
OUT="out/screens"
mkdir -p "$OUT"

key() { curl -s -m 5 -d '' "$ECP/keypress/$1" >/dev/null; sleep "${2:-0.8}"; }
shot() {
    sleep "${2:-2}"
    node tools/screenshot.js "$OUT/$1" >/dev/null 2>&1 && echo "  saved $OUT/$1.jpg" || echo "  FAILED $1 (check the password in .env)"
}

echo "Launching YourTube..."
key Home 2
curl -s -m 5 -d '' "$ECP/launch/dev" >/dev/null
sleep 14
shot 01-home 1

key Right 1.2
shot 02-home-second-card 1

key Left; key Left 1.5
shot 03-nav-open 1

key Up 1.5
key Right 1.5
shot 04-search 1
for c in l o f i; do key "Lit_$c" 0.4; done
shot 05-search-typed 3
key Left 1.5          # suggestions
key Select 6          # search the first suggestion
key Down 1.5          # results row
shot 06-search-results 2

key Left 1.5
key Down 1.5          # Home
key Down 3            # Subscriptions
shot 07-subscriptions 2
key Down 3            # You
shot 08-you 2
key Down 2            # Bookmarks
shot 09-bookmarks 2
key Down 2            # Settings
shot 10-settings 1
key Right 1.5
shot 11-settings-focused 1
key Left 1.5
key Down 2            # Remote
shot 12-remote 1
key Down 2            # Info
shot 13-info 1

echo "Playing the first Home video..."
for i in 1 2 3 4 5 6; do key Up 0.6; done   # back to Home
key Right 1.5
key Select 12
key Select 2          # pause: shows the player overlay
shot 14-player-paused 1
key Right 0.8
shot 15-player-scrubbing 1
key Select 2
key Back 2
shot 16-back-from-player 2

echo "Done. Screenshots are in $OUT/"
