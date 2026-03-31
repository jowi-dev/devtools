#!/usr/bin/env bash
# tmux session picker — launched via display-popup from prefix+s
# Supports: j/k nav, enter to switch, 1-9 to jump, x to kill (+ worktree prune)
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

case "${1:-}" in
  list)
    current=$(tmux display-message -p '#S')
    tmux list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null | while IFS='|' read -r name path; do
      marker=" "
      [ "$name" = "$current" ] && marker="*"

      wt=""
      if [ -d "$path" ]; then
        git_dir=$(git -C "$path" rev-parse --git-dir 2>/dev/null || true)
        if [ -n "$git_dir" ] && [ -f "$git_dir" ]; then
          wt=" [worktree]"
        fi
      fi

      echo "${marker} ${name}${wt}"
    done | nl -w2 -s' '
    exit 0
    ;;
  kill)
    shift
    session="$1"

    # Check if session dir is a worktree, prune if so
    path=$(tmux display-message -t "$session" -p '#{session_path}' 2>/dev/null || true)
    if [ -n "$path" ] && [ -d "$path" ]; then
      git_dir=$(git -C "$path" rev-parse --git-dir 2>/dev/null || true)
      if [ -n "$git_dir" ] && [ -f "$git_dir" ]; then
        git worktree remove "$path" 2>/dev/null || true
      fi
    fi

    tmux kill-session -t "$session" 2>/dev/null || true
    exit 0
    ;;
esac

# Main picker
selected=$("$SELF" list | fzf \
  --height=100% \
  --layout=reverse \
  --no-info \
  --no-sort \
  --prompt="session > " \
  --header="enter:switch | x:kill | 1-9:jump | esc:cancel" \
  --bind="j:down,k:up" \
  --bind="x:execute-silent($SELF kill {4})+reload($SELF list)" \
  --expect="1,2,3,4,5,6,7,8,9" \
) || exit 0

# Parse fzf output: first line is the expect key, second is selected line
key=$(echo "$selected" | head -1)
choice=$(echo "$selected" | sed -n '2p')

# If a number key was pressed, jump to that session
if [[ -n "$key" && "$key" =~ ^[0-9]$ ]]; then
  session_name=$("$SELF" list | awk -v n="$key" '$1 == n {print $4}' | sed 's/ \[worktree\]//')
else
  session_name=$(echo "$choice" | awk '{print $4}' | sed 's/ \[worktree\]//')
fi

if [[ -n "${session_name:-}" ]]; then
  tmux switch-client -t "$session_name"
fi
