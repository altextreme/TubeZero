#!/usr/bin/env bash
# YourTube: screenshots every interactive state over ECP (keys) + tools/screenshot.js (needs .env).
# Each section relaunches the app so it starts from a known state. Output: out/screens/all/<section>-<n>-<name>.jpg
# Usage: [OUT=out/screens/other] tools/yourtube/capture-all.sh [section...]   (sections: home nav search empty settings live profile player comments chat related channel filters menu exit)
set -uo pipefail
cd "$(dirname "$0")/../.."
TV="$(sed -n 's/^ROKU_DEV_TARGET=//p' .env)"; TV="${TV:-192.168.1.164}"
ECP="http://$TV:8060"
OUT="${OUT:-out/screens/all}"
mkdir -p "$OUT"

key() { curl -s -m 5 -d '' "$ECP/keypress/$1" >/dev/null; sleep "${2:-0.9}"; }
long_press() { curl -s -m 5 -d '' "$ECP/keydown/$1" >/dev/null; sleep 1.3; curl -s -m 5 -d '' "$ECP/keyup/$1" >/dev/null; sleep 1; }
keys() { local k; for k in "$@"; do key "$k"; done; }
type_text() { local c; for ((i = 0; i < ${#1}; i++)); do c="${1:$i:1}"; [ "$c" = " " ] && c="%20"; key "Lit_$c" 0.35; done; }
shot() { sleep "${2:-1.2}"; node tools/screenshot.js "$OUT/$1" >/dev/null 2>&1 && echo "  $1" || echo "  FAILED $1"; }
fresh() { key Home 2; curl -s -m 5 -d '' "$ECP/launch/dev" >/dev/null; sleep 15; }
nav_open() { keys Left Left; sleep 1; }   # from the first Home card into the rail (Home focused)

home() {
    echo "home"; fresh
    shot home-01-first-card
    key Right; shot home-02-second-card
    key Down; shot home-03-row2
    key Right; shot home-04-row2-card2
    keys Up Up; shot home-05-topbar
    key Left; shot home-06-topbar-left
}

nav() {
    echo "nav"; fresh; nav_open
    shot nav-01-home
    key Up; shot nav-02-search
    key Up; shot nav-03-profile
    keys Down Down Down; shot nav-04-subscriptions
    key Down; shot nav-05-you
    key Down; shot nav-06-live
    key Down; shot nav-07-bookmarks
    key Down; shot nav-08-settings
    key Down; shot nav-09-remote
    key Down; shot nav-10-info
    key Right; shot nav-11-collapsed-current-info
}

search() {
    echo "search"; fresh; nav_open; key Up 1.5; key Right 1.5
    shot search-01-keyboard
    type_text "lofi hip hop beats to relax and study to"; shot search-02-long-text 2
    keys Down Down Down Down; shot search-03-space-key
    keys Right Right; shot search-04-search-key
    keys Up Up Up Right Right Right Right Right Right Right; shot search-05-123-key
    key Select; shot search-06-symbols-page
    keys Left Left Left Left Left Left Left Left; shot search-07-suggestions 1.5
    key Select 6; shot search-08-results
    key Right; shot search-09-result-2
    key Up; shot search-10-back-up
}

empty() {
    echo "empty"; fresh; nav_open
    key Down 2; shot empty-01-subscriptions-nav 3
    key Right; shot empty-02-subscriptions-focused
    key Left; key Down 2; shot empty-03-you-nav 3
    key Right; shot empty-04-you-focused
}

settings() {
    echo "settings"; fresh; nav_open
    keys Down Down Down Down Down; shot settings-01-nav 2
    key Right; shot settings-02-category
    key Right; shot settings-03-control-1
    key Down; shot settings-04-control-2
    key Down; shot settings-05-control-3
    key Down; shot settings-06-control-4
    keys Left Down; shot settings-07-category-2
}

live() {
    echo "live"; fresh; nav_open
    keys Down Down Down; shot live-01-nav 2
    key Right; shot live-02-list
}

profile() {
    echo "profile"; fresh; nav_open
    keys Up Up; shot profile-01-nav 2
    key Right; shot profile-02-focused
}

player() {
    echo "player"; fresh
    key Select 12; shot player-01-playing
    key Select 2; shot player-02-paused
    key Up; shot player-03-buttons
    key Right; shot player-04-button-2
    key Down; key Right 0.6; shot player-05-scrub
    key Select 2; key Back 2; shot player-06-back
}

comments() {
    echo "comments"; fresh
    key Down 1.5; key Select 12; key Select 2; keys Up Right Right
    shot comments-00-button
    key Select 6; shot comments-01-panel
    key Down; shot comments-02-item-2
    local i; for i in $(seq 1 18); do key Down 0.4; done; shot comments-03-paged 4
    key Back 2; shot comments-04-closed
}

channel() {
    echo "channel"; fresh
    key Down 1.5; long_press Select; keys Down Down; key Select 6; shot channel-01-open
    key Down 2; shot channel-02-row
}

filters() {
    echo "filters"; fresh; nav_open; key Up 1.5; key Right 1.5
    key Up; shot filters-00-button
    key Select 3; shot filters-01-open
    key Down; key Select 1.5; shot filters-02-selected
    key Back
}

related() {
    echo "related"; key Home 2
    curl -s -m 5 -d '' "$ECP/launch/dev?contentId=LXb3EKWsInQ&mediaType=movie" >/dev/null; sleep 25
    key Select 2; key Down 3; shot related-01-open
    key Right; shot related-02-card-2
    key Up 2; shot related-03-closed
}

# Live streams come and go: pass one with chat as LIVE_ID=<videoId>.
chat() {
    echo "chat"; key Home 2
    curl -s -m 5 -d '' "$ECP/launch/dev?contentId=${LIVE_ID:-jfKfPfyJRdk}&mediaType=live" >/dev/null; sleep 20
    key Select 2; keys Up Right Right
    shot chat-00-button
    key Select 10; shot chat-01-open
    sleep 12; shot chat-02-later
    key Select 2; keys Up Right Right; key Select 3; shot chat-03-hidden
}

menu() {
    echo "menu"; fresh
    long_press Select; shot menu-01-context
    key Down; shot menu-02-context-item-2
    key Back
}

exit_dialog() {
    echo "exit"; fresh; nav_open
    key Back 2; shot exit-01-dialog
    key Down; shot exit-02-dialog-item-2
    key Back
}

sections=("$@")
[ ${#sections[@]} -eq 0 ] && sections=(home nav search empty settings live profile player comments chat related channel filters menu exit)
for s in "${sections[@]}"; do
    case "$s" in exit) exit_dialog ;; *) "$s" ;; esac
done
echo "Done: $OUT"
