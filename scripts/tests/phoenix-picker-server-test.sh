#!/usr/bin/env bash
# Tests for phoenix-picker-server.sh — marks the tmux session that owns a
# running Phoenix dev server (or any listener on the configured port) with
# the @picker_server tmux user option consumed by the session picker's ATTN
# column.
#
# Contract under test:
#   phoenix-picker-server.sh detect [port]  -- scan for a process listening
#     on `port` (positional arg, else $PICKER_SERVER_PORT, else 4000), walk
#     its parent chain to find the owning tmux pane/session, set
#     @picker_server on that session, and clear it on every other session.
#
# TMUX_PICKER_SOCKET=<name> makes the script talk to `tmux -L <name>`
# instead of the default socket, so tests run against an isolated server.
#
# The script must never fail or block the caller: every path exits 0.
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/phoenix-picker-server.sh"
SOCK="picker-server-test-$$"
SYMBOL="🔥"

OWNER_DIR="$(mktemp -d)"
OTHER_DIR="$(mktemp -d)"
NC_PID=""

cleanup() {
  [ -n "$NC_PID" ] && kill "$NC_PID" >/dev/null 2>&1 || true
  tmux -L "$SOCK" kill-server >/dev/null 2>&1 || true
  rm -rf "$OWNER_DIR" "$OTHER_DIR"
}
trap cleanup EXIT

pass=0
fail=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass=$((pass + 1))
    echo "ok   - $desc"
  else
    fail=$((fail + 1))
    echo "FAIL - $desc"
    echo "       expected: [$expected]"
    echo "       actual:   [$actual]"
  fi
}

get_srv() {
  tmux -L "$SOCK" show-options -t "$1" -v @picker_server 2>/dev/null || true
}

run_detect() {
  TMUX_PICKER_SOCKET="$SOCK" PICKER_SERVER_PORT="$PORT" bash "$SCRIPT" detect
}

run_detect_positional() {
  TMUX_PICKER_SOCKET="$SOCK" bash "$SCRIPT" detect "$PORT"
}

PORT=$((20000 + RANDOM % 20000))

tmux -L "$SOCK" -f /dev/null new-session -d -s owner -c "$OWNER_DIR"
tmux -L "$SOCK" new-session -d -s other -c "$OTHER_DIR"

# Start a real listener inside the owner session's pane.
tmux -L "$SOCK" send-keys -t owner "nc -l $PORT" C-m

# Poll until the listener is up.
listener_pid=""
for _ in $(seq 1 50); do
  listener_pid="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null | head -n1 || true)"
  [ -n "$listener_pid" ] && break
  sleep 0.1
done

if [ -z "$listener_pid" ]; then
  echo "FAIL - listener never came up on port $PORT"
  fail=$((fail + 1))
else
  NC_PID="$listener_pid"

  ### detect with live listener -> owner gets symbol ###########################
  run_detect
  check "detect sets symbol on owner session" "$SYMBOL" "$(get_srv owner)"

  ### other session has no @picker_server #######################################
  check "detect leaves other session unset" "" "$(get_srv other)"

  ### stale-symbol clearing ######################################################
  tmux -L "$SOCK" set-option -t other @picker_server "$SYMBOL" >/dev/null 2>&1
  run_detect
  check "detect clears stale symbol on other session" "" "$(get_srv other)"
  check "detect keeps symbol on owner session after clearing pass" "$SYMBOL" "$(get_srv owner)"

  ### positional port arg works ##################################################
  tmux -L "$SOCK" set-option -t owner -u @picker_server >/dev/null 2>&1
  run_detect_positional
  check "detect via positional port arg sets owner symbol" "$SYMBOL" "$(get_srv owner)"

  ### listener stops -> owner gets cleared #######################################
  kill "$NC_PID" >/dev/null 2>&1 || true
  for _ in $(seq 1 50); do
    still="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null || true)"
    [ -z "$still" ] && break
    sleep 0.1
  done
  NC_PID=""
  run_detect
  check "detect clears owner symbol once listener stops" "" "$(get_srv owner)"
fi

### unknown subcommand is a no-op, exits 0 #####################################
tmux -L "$SOCK" set-option -t owner @picker_server "$SYMBOL" >/dev/null 2>&1
TMUX_PICKER_SOCKET="$SOCK" bash "$SCRIPT" bogus
code=$?
check "unknown subcommand exits 0" "0" "$code"
check "unknown subcommand does not change owner state" "$SYMBOL" "$(get_srv owner)"
tmux -L "$SOCK" set-option -t owner -u @picker_server >/dev/null 2>&1

### no tmux server available at all -> exits 0 #################################
# Point at a socket with no server rather than unsetting TMUX_PICKER_SOCKET:
# detect doesn't need $TMUX, so a bare `tmux` would reach the user's real
# server and mutate its sessions.
env -u TMUX -u TMUX_PANE TMUX_PICKER_SOCKET="$SOCK-nosrv" bash "$SCRIPT" detect
code=$?
check "exits 0 with no tmux available" "0" "$code"

### wrong port -> nothing set, exits 0 #########################################
WRONG_PORT=$((PORT + 1))
if [ "$WRONG_PORT" -gt 65535 ]; then
  WRONG_PORT=$((PORT - 1))
fi
tmux -L "$SOCK" set-option -t owner -u @picker_server >/dev/null 2>&1
tmux -L "$SOCK" set-option -t other -u @picker_server >/dev/null 2>&1
TMUX_PICKER_SOCKET="$SOCK" PICKER_SERVER_PORT="$WRONG_PORT" bash "$SCRIPT" detect
code=$?
check "wrong port exits 0" "0" "$code"
check "wrong port leaves owner unset" "" "$(get_srv owner)"
check "wrong port leaves other unset" "" "$(get_srv other)"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
