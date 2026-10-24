#!/usr/bin/env bash
# YourTube: run this yourself in a terminal and leave it open. Whenever a new YourTube-*.zip appears in out/
# (e.g. after tools/yourtube-build.sh), it installs it on the TV with tools/yourtube/install-zip.js.
# With --capture it also runs tools/yourtube/capture-screens.sh after each install.
# Credentials come from .env; nothing else touches them. Stop with Ctrl-C.
set -uo pipefail
cd "$(dirname "$0")/../.."

capture=false
[ "${1:-}" = "--capture" ] && capture=true

newest() { ls -t out/YourTube-*.zip 2>/dev/null | head -1; }
last="$(newest)"
echo "Watching out/ for new YourTube builds (current: ${last:-none}). Ctrl-C to stop."

while true; do
    sleep 3
    current="$(newest)"
    if [ -n "$current" ] && [ "$current" != "$last" ]; then
        sleep 2 # let the build finish writing the zip
        echo "$(date '+%H:%M:%S') new build: $current"
        if node tools/yourtube/install-zip.js "$current"; then
            last="$current"
            if $capture; then
                sleep 15
                tools/yourtube/capture-screens.sh
                echo "$(date '+%H:%M:%S') screenshots ready in out/screens/" > out/screens/.captured
            fi
        else
            echo "  will retry on the next build"
            last="$current"
        fi
    fi
done
