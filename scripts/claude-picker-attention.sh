#!/usr/bin/env bash
# claude-picker-attention.sh — Claude Code hook plugin for the tmux session
# picker. Sets/clears the @picker_status tmux user option on a session so
# tmux-session-picker.sh can render an attention symbol on that session's
# row. Deliberately decoupled: the picker only reads @picker_status, it
# doesn't know this script (or Claude Code) exists — any other tool can set
# the same option to integrate.
#
# Subcommands:
#   question  -- set @picker_status to ❓ (AskUserQuestion is pending)
#   waiting   -- set @picker_status to ⏸, UNLESS it is already ❓ (a
#                pending question outranks a generic wait; Notification
#                events fire while a question is open and must not stomp it)
#   clear     -- unset @picker_status (question answered / prompt submitted
#                / session ended)
#
# This runs as a Claude Code hook: it must NEVER fail or block Claude, so
# every path below exits 0, and all tmux calls are best-effort.
set -uo pipefail

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

# Print the target session name, or return 1 if it can't be determined.
# TMUX_SESSION overrides everything (used by tests and lets other tools
# target an arbitrary session). Otherwise resolve the ambient session from
# inside a hook: prefer the pane we were invoked from ($TMUX_PANE), falling
# back to whatever `tmux` considers current. Requires $TMUX to be set (we
# must be inside tmux) unless TMUX_SESSION was given explicitly.
resolve_session() {
  if [ -n "${TMUX_SESSION:-}" ]; then
    printf '%s\n' "$TMUX_SESSION"
    return 0
  fi

  [ -n "${TMUX:-}" ] || return 1

  local session
  if [ -n "${TMUX_PANE:-}" ]; then
    session=$(_tmux display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null) || return 1
  else
    session=$(_tmux display-message -p '#S' 2>/dev/null) || return 1
  fi

  [ -n "$session" ] || return 1
  printf '%s\n' "$session"
}

main() {
  local cmd="${1:-}"
  local session
  session=$(resolve_session) || exit 0

  case "$cmd" in
    question)
      _tmux set-option -t "$session" @picker_status "❓" >/dev/null 2>&1 || true
      ;;
    waiting)
      local current
      current=$(_tmux show-options -t "$session" -v @picker_status 2>/dev/null || true)
      if [ "$current" != "❓" ]; then
        _tmux set-option -t "$session" @picker_status "⏸" >/dev/null 2>&1 || true
      fi
      ;;
    clear)
      _tmux set-option -t "$session" -u @picker_status >/dev/null 2>&1 || true
      ;;
    *)
      ;;
  esac

  exit 0
}

main "$@"
