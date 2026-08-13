#!/usr/bin/env bash
# Tests for claude-picker-attention.sh — sets/clears the @picker_status
# tmux user option consumed by the session picker's ATTN column.
#
# Contract under test:
#   claude-picker-attention.sh question   -- set @picker_status to ❓
#   claude-picker-attention.sh waiting    -- set @picker_status to ⏸,
#                                             UNLESS it is already ❓
#   claude-picker-attention.sh clear      -- unset @picker_status
#
# Target session resolution:
#   TMUX_SESSION=<name> overrides the ambient-session lookup (used here so
#   tests don't depend on which real session runs them).
#   TMUX_PICKER_SOCKET=<name> makes the script talk to `tmux -L <name>`
#   instead of the default socket, so tests run against an isolated server.
#
# The script must never fail or block the caller (it runs as a Claude Code
# hook): every subcommand exits 0 regardless of outcome.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/claude-picker-attention.sh"
SOCK="picker-attn-test-$$"

cleanup() {
  tmux -L "$SOCK" kill-server >/dev/null 2>&1 || true
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

get_status() {
  tmux -L "$SOCK" show-options -t testsess -v @picker_status 2>/dev/null || true
}

run_hook() {
  TMUX_PICKER_SOCKET="$SOCK" TMUX_SESSION=testsess "$SCRIPT" "$1"
}

tmux -L "$SOCK" -f /dev/null new-session -d -s testsess

### question sets ❓ ###########################################################
run_hook question
check "question sets ❓" "❓" "$(get_status)"

### clear unsets ###############################################################
run_hook clear
check "clear unsets ❓" "" "$(get_status)"

### waiting sets ⏸ when empty ##################################################
run_hook waiting
check "waiting sets ⏸ when empty" "⏸" "$(get_status)"

### waiting does not overwrite ❓ ###############################################
run_hook clear
run_hook question
run_hook waiting
check "waiting does not overwrite ❓" "❓" "$(get_status)"

### question overwrites ⏸ ######################################################
run_hook clear
run_hook waiting
run_hook question
check "question overwrites ⏸" "❓" "$(get_status)"

### clear unsets after question ################################################
run_hook clear
check "clear unsets after question" "" "$(get_status)"

### exits 0 with no tmux available #############################################
set +e
env -u TMUX -u TMUX_PANE -u TMUX_SESSION -u TMUX_PICKER_SOCKET bash "$SCRIPT" question
code=$?
set -e
check "exits 0 with no tmux available" "0" "$code"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
