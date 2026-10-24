#!/usr/bin/env bash
# YourTube smoke test over ECP (port 8060) + the BrightScript console (port 8085).
# No device password needed. Assumes the YourTube zip is already sideloaded as the dev app.
#
# Usage: tools/smoke.sh [tv-ip]        (default 192.168.1.164, or $ROKU_DEV_TARGET)
# Exit code is non-zero if any step fails. The console log is saved to out/smoke-console.log.
set -uo pipefail

TV="${1:-${ROKU_DEV_TARGET:-192.168.1.164}}"
ECP="http://$TV:8060"
OUT="$(cd "$(dirname "$0")/.." && pwd)/out"
LOG="$OUT/smoke-console.log"
mkdir -p "$OUT"
FAILURES=0

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILURES=$((FAILURES + 1)); }
step() { printf '\n== %s\n' "$1"; }
key() { curl -s -m 5 -d '' "$ECP/keypress/$1" >/dev/null; sleep "${2:-0.6}"; }
active_app() { curl -s -m 5 "$ECP/query/active-app"; }
player_state() { curl -s -m 5 "$ECP/query/media-player" | sed -n 's/.*<player [^>]*state="\([a-z]*\)".*/\1/p' | head -1; }

step "Device"
if ! curl -s -m 5 "$ECP/query/device-info" >/dev/null; then
    echo "  Cannot reach $ECP. If ping works, enable Local Network access for this terminal app"
    echo "  (System Settings > Privacy & Security > Local Network). Or re-resolve the TV:"
    echo "  dns-sd -G v4 X00300KTT906.local"
    exit 2
fi
pass "ECP reachable at $TV"

# Record the debug console for the whole run (keeps stdin open so nc doesn't exit).
: >"$LOG"
(tail -f /dev/null | nc "$TV" 8085 >>"$LOG" 2>&1) &
CONSOLE_PID=$!
trap 'kill $CONSOLE_PID 2>/dev/null; pkill -P $CONSOLE_PID 2>/dev/null' EXIT
sleep 1

step "Cold launch"
key Home 2
curl -s -m 5 -d '' "$ECP/launch/dev" >/dev/null
sleep 12
if active_app | grep -q 'id="dev"'; then pass "dev app is active"; else fail "dev app not active: $(active_app | tr -d '\n')"; fi

step "Navigate Home -> nav rail -> each section -> back"
key Left
for i in 1 2 3 4 5; do key Down 1.2; done
for i in 1 2 3 4 5; do key Up 0.8; done
key Right 1.5
if active_app | grep -q 'id="dev"'; then pass "still running after nav"; else fail "app left during nav"; fi

step "Search screen"
key Left; key Up; key Up; key Up 1.5
key Right 1; key Select; key Select; key Down; key Select 2
key Back 1; key Right 1
if active_app | grep -q 'id="dev"'; then pass "still running after search"; else fail "app left during search"; fi

step "Play first Home video for 20s"
key Down 1; key Select 8
state="$(player_state)"
if [ "$state" = "play" ] || [ "$state" = "buffer" ]; then pass "player state: $state"; else fail "player state: ${state:-none}"; fi
sleep 12
key Select 1.5
key Right 1; key Right 1
state="$(player_state)"
[ -n "$state" ] && pass "player responds to keys (state: $state)" || fail "no player state"
key Back 2

step "Deep link (Live tab, Phase 6) - expected to be ignored until implemented"
curl -s -m 5 -d '' "$ECP/input?u=$(python3 -c 'import urllib.parse;print(urllib.parse.quote("https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"))')&f=hls&t=Smoke" >/dev/null
sleep 3
if active_app | grep -q 'id="dev"'; then pass "app survives roInput"; else fail "app left after roInput"; fi

step "Console check"
sleep 1
if grep -qE 'BrightScript Micro Debugger|Runtime Error|STOP \(runtime error|Execution timeout' "$LOG"; then
    fail "crash markers in console (see $LOG)"
    grep -nE 'BrightScript Micro Debugger|Runtime Error|STOP \(runtime error|Execution timeout' "$LOG" | head -5
else
    pass "no crash markers in console"
fi
grep -q 'YT_PROBE' "$LOG" && echo "  (codec probe output present: grep YT_PROBE $LOG)"

printf '\n%s\n' "$([ $FAILURES -eq 0 ] && echo 'All smoke steps passed.' || echo "$FAILURES step(s) failed.")"
exit $FAILURES
