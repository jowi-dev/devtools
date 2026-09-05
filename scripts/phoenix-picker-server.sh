#!/usr/bin/env bash
# phoenix-picker-server.sh — tmux session picker plugin that marks the
# session owning the running Phoenix dev server. Sets/clears the
# @picker_server tmux user option so tmux-session-picker.sh can render a
# symbol on that session's row. Deliberately decoupled: the picker only
# reads @picker_server, it doesn't know this script exists.
#
# A dev server has no start/stop event to hook into, so this detects by
# scanning: find the pid listening on the configured port, walk its parent
# processes up to a tmux pane, map the pane to its session, set
# @picker_server on the owner, and unset it on every other session (so a
# stopped or moved server never leaves a stale symbol).
#
# Subcommands:
#   detect [port]  -- scan for a listener on `port` (positional arg, else
#                      $PICKER_SERVER_PORT, else 4000) and update
#                      @picker_server across all sessions accordingly.
#
# This must never fail or block the caller: every path exits 0, and all
# tmux calls are best-effort.
set -uo pipefail

SYMBOL="🔥"

# Optional: talk to `tmux -L "$TMUX_PICKER_SOCKET"` instead of the default
# socket. Lets tests run against an isolated tmux server; real usage leaves
# this unset and gets plain `tmux`, which resolves via the ambient $TMUX.
_tmux() {
  if [ -n "${TMUX_PICKER_SOCKET:-}" ]; then
    tmux -L "$TMUX_PICKER_SOCKET" "$@"
  else
    tmux "$@"
  fi
}

# Walk the parent chain of $1 (a pid) looking for a match among the
# pane_pids in $panes (global, "pid session_name" lines, one per line).
# Prints the owning session name and returns 0 on a match; returns 1 if no
# match is found within the hop limit.
find_owner_session() {
  local pid="$1" hop ppid line pane_pid pane_session

  hop=0
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null && [ "$hop" -lt 20 ]; do
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      pane_pid="${line%% *}"
      if [ "$pane_pid" = "$pid" ]; then
        pane_session=$(awk '{ i = index($0, " "); print substr($0, i + 1) }' <<<"$line")
        printf '%s\n' "$pane_session"
        return 0
      fi
    done <<<"$panes"

    ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -n "$ppid" ] || return 1
    pid="$ppid"
    hop=$((hop + 1))
  done

  return 1
}

cmd_detect() {
  local port="${1:-${PICKER_SERVER_PORT:-4000}}"
  local sessions panes owner_pid owner_session sess listener_pids pid

  sessions=$(_tmux list-sessions -F '#{session_name}' 2>/dev/null || true)
  [ -n "$sessions" ] || exit 0

  panes=$(_tmux list-panes -a -F '#{pane_pid} #{session_name}' 2>/dev/null || true)

  owner_session=""

  if command -v lsof >/dev/null 2>&1; then
    listener_pids=$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true)
    if [ -n "$listener_pids" ] && [ -n "$panes" ]; then
      while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        owner_session=$(find_owner_session "$pid") && [ -n "$owner_session" ] && break
        owner_session=""
      done <<<"$listener_pids"
    fi
  fi

  while IFS= read -r sess; do
    [ -n "$sess" ] || continue
    if [ "$sess" = "$owner_session" ]; then
      _tmux set-option -t "$sess" @picker_server "$SYMBOL" >/dev/null 2>&1 || true
    else
      _tmux set-option -t "$sess" -u @picker_server >/dev/null 2>&1 || true
    fi
  done <<<"$sessions"

  exit 0
}

main() {
  local cmd="${1:-}"

  case "$cmd" in
    detect)
      cmd_detect "${2:-}"
      ;;
    *)
      ;;
  esac

  exit 0
}

main "$@"
