#!/usr/bin/env bash
# Tests for the tmux-session-picker.sh modal fzf UI (GH-1).
#
# Contract under test: the picker opens in NORMAL mode with query input
# disabled, so keystrokes are single-letter commands. `i` enters INSERT
# mode (enables the query/filter), `esc` in INSERT returns to NORMAL,
# `esc`/`q` in NORMAL cancels the picker. Critically: typing a filter
# containing "x" in INSERT mode must NOT kill any session -- that's the
# bug this modal redesign fixes (x used to be bound to kill unconditionally
# regardless of mode).
#
# Drives the real picker script interactively inside an isolated tmux
# server (unique -L socket) so it never touches the caller's real tmux
# sessions. Every test session is created with an explicit -c into a
# throwaway mktemp directory -- NOT the caller's cwd -- because the
# picker's `kill` subcommand runs `git worktree remove --force <path>` /
# `rm -rf <path>` on a killed session's directory when that directory
# looks like a linked worktree. Letting a killed session inherit the
# ambient cwd here would risk deleting real, unrelated working-tree state.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tmux-session-picker.sh"
SOCK="picker-modal-test-$$"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/tsp-modal-test.XXXXXX")"

cleanup() {
  tmux -L "$SOCK" kill-server >/dev/null 2>&1 || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

pass=0
fail=0

check() {
  local desc="$1" cond="$2"
  if [ "$cond" = "0" ]; then
    pass=$((pass + 1))
    echo "ok   - $desc"
  else
    fail=$((fail + 1))
    echo "FAIL - $desc"
  fi
}

pane() {
  tmux -L "$SOCK" capture-pane -p -t runner 2>/dev/null || true
}

sessions() {
  tmux -L "$SOCK" list-sessions -F '#{session_name}' 2>/dev/null || true
}

pane_has() {
  pane | grep -qF "$1"
}

session_exists() {
  sessions | grep -qxF "$1"
}

pane_dead() {
  [ "$(tmux -L "$SOCK" display-message -p -t runner '#{pane_dead}' 2>/dev/null || echo 1)" = "1" ]
}

ui_drawn() { pane_has "SESSION" && pane_has "[N]"; }
in_insert_mode() { pane_has "[I]"; }
in_normal_mode() { pane_has "[N]"; }
victim_killed() { ! session_exists aaa-victim && session_exists runner; }
runner_gone() { ! session_exists runner || pane_dead; }

# wait_for <timeout-seconds> <predicate-fn> [args...]
# Polls the predicate (a function defined above, called directly so it
# shares this process -- no bash -c subshell, which would lose the
# function definitions) every 0.2s until it succeeds or the timeout
# elapses. On timeout, prints the runner pane's contents for debugging and
# returns failure.
wait_for() {
  local timeout="$1"; shift
  local waited=0
  while ! "$@"; do
    waited=$(awk "BEGIN{print $waited + 0.2}")
    if awk "BEGIN{exit !($waited >= $timeout)}"; then
      echo "FAIL - timed out waiting for: $*"
      echo "----- runner pane contents -----"
      pane
      echo "---------------------------------"
      return 1
    fi
    sleep 0.2
  done
  return 0
}

### setup #######################################################################
# aaa-victim first (alphabetically first data row, so it's never the
# picker's own "current" session) then the runner session that hosts the
# picker itself. Inside the runner pane, $TMUX points at this test socket,
# so the picker's own tmux calls (list-sessions, display-message,
# kill-session) hit only this isolated server. Both sessions are rooted in
# WORKDIR (a plain non-worktree directory), not the caller's cwd, so a
# kill's worktree-cleanup branch is inert.
tmux -L "$SOCK" -f /dev/null new-session -d -s aaa-victim -c "$WORKDIR"
tmux -L "$SOCK" -f /dev/null new-session -d -s runner -c "$WORKDIR" -x 120 -y 40 "bash '$SCRIPT'"

### a. picker UI is drawn, in NORMAL mode #######################################
if wait_for 10 ui_drawn; then
  check "picker UI drawn in NORMAL mode" 0
else
  check "picker UI drawn in NORMAL mode" 1
fi

### b. INSERT-mode safety: typing x must not kill anything ######################
tmux -L "$SOCK" send-keys -t runner i
if wait_for 10 in_insert_mode; then
  check "entered INSERT mode" 0
else
  check "entered INSERT mode" 1
fi

tmux -L "$SOCK" send-keys -t runner x
tmux -L "$SOCK" send-keys -t runner x
sleep 0.5

if session_exists aaa-victim && session_exists runner; then
  check "typing x while filtering does not kill any session" 0
else
  check "typing x while filtering does not kill any session" 1
fi

### c. back to NORMAL mode ######################################################
tmux -L "$SOCK" send-keys -t runner BSpace
tmux -L "$SOCK" send-keys -t runner BSpace
tmux -L "$SOCK" send-keys -t runner Escape

if wait_for 10 in_normal_mode; then
  check "esc in INSERT returns to NORMAL mode" 0
else
  check "esc in INSERT returns to NORMAL mode" 1
fi

### d. NORMAL-mode kill #########################################################
tmux -L "$SOCK" send-keys -t runner x

if wait_for 10 victim_killed; then
  check "x in NORMAL mode kills the selected session" 0
else
  check "x in NORMAL mode kills the selected session" 1
fi

### e. NORMAL-mode cancel #######################################################
tmux -L "$SOCK" send-keys -t runner q

if wait_for 10 runner_gone; then
  check "q in NORMAL mode cancels the picker" 0
else
  check "q in NORMAL mode cancels the picker" 1
fi

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
