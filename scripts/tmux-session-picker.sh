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

# Emit raw, tab-delimited, uncolored rows for the session table:
#   <name> <idx> <marker> <name> <wt-or-dash> <branch-or-dash> <status-or-dash>
# `name` appears twice deliberately: field 1 is the machine-readable key
# (never displayed, never padded/colored), field 4 is the display copy that
# gets column-aligned alongside the rest. Kept separate from format_rows()
# so the column-width/coloring logic can be unit-tested against fixed input
# without a live tmux server.
list_plain() {
  local current idx=0
  current=$(tmux display-message -p '#S' 2>/dev/null || true)

  while IFS='|' read -r name path; do
    idx=$((idx + 1))

    local marker="-"
    [ "$name" = "$current" ] && marker="*"

    local wt="-"
    if [ -d "$path" ] && [ -f "$path/.git" ]; then
      wt="wt"
    fi

    local raw branch="-" status="-"
    raw=$(branch_status "$path" 2>/dev/null || true)
    case "$raw" in
      *' [merged]') branch="${raw% \[merged\]}"; status="merged" ;;
      *' [unmerged]') branch="${raw% \[unmerged\]}"; status="unmerged" ;;
      '[detached]') status="detached" ;;
    esac

    printf '%s\t%d\t%s\t%s\t%s\t%s\t%s\n' "$name" "$idx" "$marker" "$name" "$wt" "$branch" "$status"
  done < <(tmux list-sessions -F '#{session_name}|#{session_path}' 2>/dev/null)
}

# Read list_plain()'s TSV rows from stdin, compute per-column max widths on
# the PLAIN text (this must happen before any ANSI codes are added, or the
# escape bytes would be counted and break alignment), then print final rows
# as two tab fields: bare session name, and a padded/colored display string.
# Prepends a pinned header row whose bare-name field is empty so it can
# never match a kill/switch lookup.
format_rows() {
  local h_idx='#' h_mark=' ' h_name='SESSION' h_wt='WT' h_branch='BRANCH' h_status='STATUS'
  local names=() idxs=() markers=() dispnames=() wts=() branches=() statuses=()
  local name idx marker dispname wt branch status

  while IFS=$'\t' read -r name idx marker dispname wt branch status; do
    names+=("$name"); idxs+=("$idx"); markers+=("$marker")
    dispnames+=("$dispname"); wts+=("$wt"); branches+=("$branch"); statuses+=("$status")
  done

  local w_idx=${#h_idx} w_name=${#h_name} w_wt=${#h_wt} w_branch=${#h_branch} w_status=${#h_status}
  local i
  for i in "${!names[@]}"; do
    (( ${#idxs[$i]} > w_idx )) && w_idx=${#idxs[$i]}
    (( ${#dispnames[$i]} > w_name )) && w_name=${#dispnames[$i]}
    (( ${#wts[$i]} > w_wt )) && w_wt=${#wts[$i]}
    (( ${#branches[$i]} > w_branch )) && w_branch=${#branches[$i]}
    (( ${#statuses[$i]} > w_status )) && w_status=${#statuses[$i]}
  done

  printf '\t%*s  %s  %-*s  %-*s  %-*s  %-*s\n' \
    "$w_idx" "$h_idx" "$h_mark" \
    "$w_name" "$h_name" "$w_wt" "$h_wt" "$w_branch" "$h_branch" "$w_status" "$h_status"

  for i in "${!names[@]}"; do
    local idx_pad name_pad wt_pad branch_pad status_pad status_disp
    idx_pad=$(printf '%*s' "$w_idx" "${idxs[$i]}")
    name_pad=$(printf '%-*s' "$w_name" "${dispnames[$i]}")
    wt_pad=$(printf '%-*s' "$w_wt" "${wts[$i]}")
    branch_pad=$(printf '%-*s' "$w_branch" "${branches[$i]}")
    status_pad=$(printf '%-*s' "$w_status" "${statuses[$i]}")

    case "${statuses[$i]}" in
      merged) status_disp=$(c_green "$status_pad") ;;
      unmerged|detached) status_disp=$(c_yellow "$status_pad") ;;
      *) status_disp="$status_pad" ;;
    esac

    printf '%s\t%s  %s  %s  %s  %s  %s\n' \
      "${names[$i]}" "$idx_pad" "${markers[$i]}" "$name_pad" "$wt_pad" "$(c_dim "$branch_pad")" "$status_disp"
  done
}

# Guard so this file can be `source`d (e.g. by tests, to reach the
# functions above) without also executing the CLI dispatch/main picker
# below.
if [[ "${BASH_SOURCE[0]:-}" != "${0}" ]]; then
  return 0
fi

case "${1:-}" in
  branch-status)
    shift
    branch_status "${1:-}" || true
    exit 0
    ;;
  list)
    shift
    if [ "${1:-}" = "--plain" ]; then
      list_plain
      exit 0
    fi
    list_plain | format_rows
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
  --delimiter=$'\t' \
  --with-nth=2.. \
  --header-lines=1 \
  --prompt="session > " \
  --header="enter:switch | x:kill | 1-9:jump | esc:cancel | [merged]=safe to close" \
  --bind="j:down,k:up" \
  --bind="x:execute-silent($SELF kill {1})+reload($SELF list)" \
  --expect="1,2,3,4,5,6,7,8,9" \
) || exit 0

# Parse fzf output: first line is the expect key, second is selected line
key=$(echo "$selected" | head -1)
choice=$(echo "$selected" | sed -n '2p')

# If a number key was pressed, jump to that session. Line 1 of `list` is the
# pinned header, so the Nth session is on line N+1.
if [[ -n "$key" && "$key" =~ ^[0-9]$ ]]; then
  session_name=$("$SELF" list | sed -n "$((key + 1))p" | awk -F'\t' '{print $1}')
else
  session_name=$(echo "$choice" | awk -F'\t' '{print $1}')
fi

if [[ -n "${session_name:-}" ]]; then
  tmux switch-client -t "$session_name"
fi
