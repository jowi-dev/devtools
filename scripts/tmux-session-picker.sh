#!/usr/bin/env bash
# tmux session picker — launched via display-popup from prefix+s
# Supports: j/k nav, enter to switch, 1-9 to jump, x to kill (+ worktree prune)
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# Resolve the repo's default base branch, e.g. "origin/main".
# Tries origin/HEAD first, then falls back to well-known remote/local names.
# Prints nothing and returns 1 if no base branch can be determined.
resolve_base() {
  local path="$1"
  local base
  base=$(git -C "$path" rev-parse --abbrev-ref origin/HEAD 2>/dev/null) && [ -n "$base" ] && { echo "$base"; return 0; }
  if git -C "$path" show-ref --verify --quiet refs/remotes/origin/main; then echo "origin/main"; return 0; fi
  if git -C "$path" show-ref --verify --quiet refs/remotes/origin/master; then echo "origin/master"; return 0; fi
  if git -C "$path" show-ref --verify --quiet refs/heads/main; then echo "main"; return 0; fi
  if git -C "$path" show-ref --verify --quiet refs/heads/master; then echo "master"; return 0; fi
  return 1
}

# Print the plain-text (no ANSI) branch/merge-status annotation for a session
# path, or nothing if there's no useful annotation to show. One of:
#   ""                     -- not a git repo, on the default branch, or no
#                              base branch resolvable
#   "<branch> [merged]"    -- merged (ancestor OR squash-merged) into base
#   "<branch> [unmerged]"  -- has commits not present in base
#   "[detached]"           -- detached HEAD
branch_status() {
  local path="$1"

  [ -d "$path" ] || return 0
  git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  # `git branch --show-current` prints the bare branch name with no
  # shortening/disambiguation logic, unlike rev-parse --abbrev-ref or
  # symbolic-ref --short (both of which get confused into printing
  # "heads/main" when a tag happens to share the branch's name). It prints
  # an empty string on detached HEAD.
  local branch
  branch=$(git -C "$path" branch --show-current 2>/dev/null) || true
  if [ -z "$branch" ]; then
    echo "[detached]"
    return 0
  fi

  local base
  base=$(resolve_base "$path") || return 0

  local base_name="${base#origin/}"
  [ "$branch" = "$base_name" ] && return 0

  if git -C "$path" merge-base --is-ancestor HEAD "$base" 2>/dev/null; then
    echo "$branch [merged]"
    return 0
  fi

  # Squash-merge detection (github.com/not-an-aardvark/git-delete-squashed
  # technique): synthesize a commit with HEAD's tree on top of the merge
  # base, then check whether `git cherry` considers it already upstream.
  local mb tree synthetic cherry_out
  mb=$(git -C "$path" merge-base "$base" HEAD 2>/dev/null) || { echo "$branch [unmerged]"; return 0; }
  tree=$(git -C "$path" rev-parse "HEAD^{tree}" 2>/dev/null) || { echo "$branch [unmerged]"; return 0; }
  synthetic=$(git -C "$path" commit-tree "$tree" -p "$mb" -m _ 2>/dev/null) || { echo "$branch [unmerged]"; return 0; }
  cherry_out=$(git -C "$path" cherry "$base" "$synthetic" 2>/dev/null) || true
  if [[ "$cherry_out" == -* ]]; then
    echo "$branch [merged]"
  else
    echo "$branch [unmerged]"
  fi
}

c_dim() { printf '\033[2m%s\033[0m' "$1"; }
c_green() { printf '\033[32m%s\033[0m' "$1"; }
c_yellow() { printf '\033[33m%s\033[0m' "$1"; }

# Colorized annotation (with a leading space) to append after the session
# name for the `list` output, or empty string. Kept separate from
# branch_status() so the plain-text logic stays trivially testable.
colorized_annotation() {
  local path="$1"
  local raw
  raw=$(branch_status "$path" 2>/dev/null || true)
  [ -n "$raw" ] || return 0

  case "$raw" in
    *' [merged]')
      local br="${raw% \[merged\]}"
      printf ' %s %s' "$(c_dim "$br")" "$(c_green "[merged]")"
      ;;
    *' [unmerged]')
      local br="${raw% \[unmerged\]}"
      printf ' %s %s' "$(c_dim "$br")" "$(c_yellow "[unmerged]")"
      ;;
    '[detached]')
      printf ' %s' "$(c_yellow "[detached]")"
      ;;
  esac
}

case "${1:-}" in
  branch-status)
    shift
    branch_status "${1:-}" || true
    exit 0
    ;;
  list)
    current=$(tmux display-message -p '#S')
    tmux list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null | while IFS='|' read -r name path; do
      marker="-"
      [ "$name" = "$current" ] && marker="*"

      wt=""
      if [ -d "$path" ] && [ -f "$path/.git" ]; then
        wt=" [worktree]"
      fi

      status=$(colorized_annotation "$path")

      echo "${marker} ${name}${wt}${status}"
    done | nl -w2 -s' '
    exit 0
    ;;
  kill)
    shift
    session="$1"

    # Don't kill the session we're currently in
    current=$(tmux display-message -p '#S')
    [ "$session" = "$current" ] && exit 0

    # Grab the session path before killing (needed for worktree cleanup)
    path=$(tmux display-message -t "$session" -p '#{session_path}' 2>/dev/null || true)

    # Kill session first so processes release the directory
    tmux kill-session -t "$session" 2>/dev/null || true

    # Then clean up the worktree if applicable
    if [ -n "$path" ] && [ -d "$path" ]; then
      # A worktree has a .git file (not directory) pointing to the main repo
      if [ -f "$path/.git" ]; then
        main_repo=$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/\.git$||' || true)
        if [ -n "$main_repo" ]; then
          git -C "$main_repo" worktree remove --force "$path" 2>/dev/null || rm -rf "$path"
          git -C "$main_repo" worktree prune 2>/dev/null || true
        fi
      fi
    fi
    exit 0
    ;;
esac

# Main picker
selected=$("$SELF" list | fzf \
  --height=100% \
  --layout=reverse \
  --no-info \
  --no-sort \
  --ansi \
  --prompt="session > " \
  --header="enter:switch | x:kill | 1-9:jump | esc:cancel | [merged]=safe to close" \
  --bind="j:down,k:up" \
  --bind="x:execute-silent($SELF kill {3})+reload($SELF list)" \
  --expect="1,2,3,4,5,6,7,8,9" \
) || exit 0

# Parse fzf output: first line is the expect key, second is selected line
key=$(echo "$selected" | head -1)
choice=$(echo "$selected" | sed -n '2p')

# If a number key was pressed, jump to that session
if [[ -n "$key" && "$key" =~ ^[0-9]$ ]]; then
  session_name=$("$SELF" list | awk -v n="$key" '$1 == n {print $3}' | sed 's/ \[worktree\]//')
else
  session_name=$(echo "$choice" | awk '{print $3}' | sed 's/ \[worktree\]//')
fi

if [[ -n "${session_name:-}" ]]; then
  tmux switch-client -t "$session_name"
fi
