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

# Print the name of the project a path belongs to: for a linked worktree
# that's the parent repo's directory name (not the worktree dir's), for a
# regular checkout it's the repo root's own name, and "-" for anything that
# isn't a git repo or doesn't exist. Never fails under set -euo pipefail —
# this runs on every fzf reload, so a missing/racy path must not abort it.
project_name() {
  local path="$1"

  [ -d "$path" ] || { echo "-"; return 0; }

  local common_dir
  common_dir=$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "-"; return 0; }

  basename "${common_dir%/.git}"
}

# Optional: talk to `tmux -L "$TMUX_PICKER_SOCKET"` instead of the default
# socket. Lets tests run against an isolated tmux server; real usage leaves
# this unset and gets plain `tmux`, which resolves via the ambient $TMUX.
# Used only by the root-session/jump-root paths below — existing tmux calls
# are left untouched to keep this diff minimal.
_tmux() {
  if [ -n "${TMUX_PICKER_SOCKET:-}" ]; then
    tmux -L "$TMUX_PICKER_SOCKET" "$@"
  else
    tmux "$@"
  fi
}

# Resolve the "root session" for a worktree/ticket session: the session the
# user should jump back to when they're done. Prints the root session name
# and returns 0, or returns 1 with nothing printed if none can be resolved.
#
# The @root_session tmux user option always wins when set to a non-empty
# value (it's a shared cross-repo contract: any tool can point a session at
# its root by setting this option). Otherwise fall back to git: if the
# session's path is a linked worktree (a ".git" FILE, not directory — same
# check the `wt` column and `kill` use), derive the root session name from
# the main checkout's directory basename, mapping dots to dashes. This
# mirrors session_name_of_dir in work.ml, which names sessions
# `String.map (fun c -> if c = '.' then '-' else c) (Filename.basename dir)`.
root_session_of() {
  local session="$1"

  local opt
  opt=$(_tmux show-options -qv -t "$session" @root_session 2>/dev/null) || opt=""
  if [ -n "$opt" ]; then
    printf '%s\n' "$opt"
    return 0
  fi

  local path
  path=$(_tmux display-message -p -t "$session" '#{session_path}' 2>/dev/null) || return 1
  [ -n "$path" ] && [ -d "$path" ] || return 1
  [ -f "$path/.git" ] || return 1

  local common root_dir name
  common=$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  [ -n "$common" ] || return 1
  root_dir="${common%/.git}"
  name=$(basename "$root_dir" | tr '.' '-')
  [ -n "$name" ] || return 1
  printf '%s\n' "$name"
  return 0
}

# Switch the client back to a session's root session (see root_session_of).
# Never aborts and never auto-creates the target: if no root can be
# resolved, the root is the session itself, or the resolved root session
# doesn't exist, print a short message and return without switching.
jump_root() {
  local session="${1:-}"
  [ -n "$session" ] || session=$(_tmux display-message -p '#S' 2>/dev/null || true)
  [ -n "$session" ] || return 0

  local target
  if ! target=$(root_session_of "$session"); then
    _tmux display-message "no root session for '$session'" >/dev/null 2>&1 || true
    return 0
  fi

  if [ "$target" = "$session" ]; then
    _tmux display-message "already at root session '$session'" >/dev/null 2>&1 || true
    return 0
  fi

  if ! _tmux has-session -t "=$target" 2>/dev/null; then
    _tmux display-message "root session '$target' not found" >/dev/null 2>&1 || true
    return 0
  fi

  _tmux switch-client -t "=$target" >/dev/null 2>&1 || true
  return 0
}

c_dim() { printf '\033[2m%s\033[0m' "$1"; }
c_green() { printf '\033[32m%s\033[0m' "$1"; }
c_yellow() { printf '\033[33m%s\033[0m' "$1"; }

# Emit raw, tab-delimited, uncolored rows for the session table:
#   <name> <idx> <marker> <name> <attn-or-dash> <wt-or-dash> <project-or-dash> <branch-or-dash> <status-or-dash>
# `name` appears twice deliberately: field 1 is the machine-readable key
# (never displayed, never padded/colored), field 4 is the display copy that
# gets column-aligned alongside the rest. Kept separate from format_rows()
# so the column-width/coloring logic can be unit-tested against fixed input
# without a live tmux server.
list_plain() {
  local current idx=0
  current=$(tmux display-message -p '#S' 2>/dev/null || true)

  while IFS='|' read -r name path attn; do
    idx=$((idx + 1))

    local marker="-"
    [ "$name" = "$current" ] && marker="*"

    [ -n "$attn" ] || attn="-"

    local wt="-"
    if [ -d "$path" ] && [ -f "$path/.git" ]; then
      wt="wt"
    fi

    local project
    project=$(project_name "$path")

    local raw branch="-" status="-"
    raw=$(branch_status "$path" 2>/dev/null || true)
    case "$raw" in
      *' [merged]') branch="${raw% \[merged\]}"; status="merged" ;;
      *' [unmerged]') branch="${raw% \[unmerged\]}"; status="unmerged" ;;
      '[detached]') status="detached" ;;
    esac

    printf '%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$idx" "$marker" "$name" "$attn" "$wt" "$project" "$branch" "$status"
  done < <(tmux list-sessions -F '#{session_name}|#{session_path}|#{@picker_status}' 2>/dev/null)
}

# Read list_plain()'s TSV rows from stdin, compute per-column max widths on
# the PLAIN text (this must happen before any ANSI codes are added, or the
# escape bytes would be counted and break alignment), then print final rows
# as two tab fields: bare session name, and a padded/colored display string.
# Prepends a pinned header row whose bare-name field is empty so it can
# never match a kill/switch lookup.
format_rows() {
  local h_idx='#' h_mark=' ' h_name='SESSION' h_attn='ATTN' h_wt='WT' h_project='PROJECT' h_branch='BRANCH' h_status='STATUS'
  local names=() idxs=() markers=() dispnames=() attns=() wts=() projects=() branches=() statuses=()
  local name idx marker dispname attn wt project branch status

  while IFS=$'\t' read -r name idx marker dispname attn wt project branch status; do
    names+=("$name"); idxs+=("$idx"); markers+=("$marker")
    dispnames+=("$dispname"); attns+=("$attn"); wts+=("$wt"); projects+=("$project")
    branches+=("$branch"); statuses+=("$status")
  done

  local w_idx=${#h_idx} w_name=${#h_name} w_attn=${#h_attn} w_wt=${#h_wt} w_project=${#h_project} w_branch=${#h_branch} w_status=${#h_status}
  local i
  for i in "${!names[@]}"; do
    (( ${#idxs[$i]} > w_idx )) && w_idx=${#idxs[$i]}
    (( ${#dispnames[$i]} > w_name )) && w_name=${#dispnames[$i]}
    (( ${#attns[$i]} > w_attn )) && w_attn=${#attns[$i]}
    (( ${#wts[$i]} > w_wt )) && w_wt=${#wts[$i]}
    (( ${#projects[$i]} > w_project )) && w_project=${#projects[$i]}
    (( ${#branches[$i]} > w_branch )) && w_branch=${#branches[$i]}
    (( ${#statuses[$i]} > w_status )) && w_status=${#statuses[$i]}
  done

  printf '\t%*s  %s  %-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n' \
    "$w_idx" "$h_idx" "$h_mark" \
    "$w_name" "$h_name" "$w_attn" "$h_attn" "$w_wt" "$h_wt" "$w_project" "$h_project" "$w_branch" "$h_branch" "$w_status" "$h_status"

  for i in "${!names[@]}"; do
    local idx_pad name_pad attn_pad wt_pad project_pad branch_pad status_pad status_disp
    idx_pad=$(printf '%*s' "$w_idx" "${idxs[$i]}")
    name_pad=$(printf '%-*s' "$w_name" "${dispnames[$i]}")
    attn_pad=$(printf '%-*s' "$w_attn" "${attns[$i]}")
    wt_pad=$(printf '%-*s' "$w_wt" "${wts[$i]}")
    project_pad=$(printf '%-*s' "$w_project" "${projects[$i]}")
    branch_pad=$(printf '%-*s' "$w_branch" "${branches[$i]}")
    status_pad=$(printf '%-*s' "$w_status" "${statuses[$i]}")

    case "${statuses[$i]}" in
      merged) status_disp=$(c_green "$status_pad") ;;
      unmerged|detached) status_disp=$(c_yellow "$status_pad") ;;
      *) status_disp="$status_pad" ;;
    esac

    printf '%s\t%s  %s  %s  %s  %s  %s  %s  %s\n' \
      "${names[$i]}" "$idx_pad" "${markers[$i]}" "$name_pad" "$attn_pad" "$wt_pad" "$project_pad" "$(c_dim "$branch_pad")" "$status_disp"
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
  project-name)
    shift
    project_name "${1:-}" || true
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
  root-session)
    shift
    session="${1:-}"
    [ -n "$session" ] || session=$(_tmux display-message -p '#S' 2>/dev/null || true)
    root_session_of "$session"
    exit $?
    ;;
  jump-root)
    shift
    jump_root "${1:-}"
    exit 0
    ;;
esac

# Main picker
#
# Modal fzf: opens in NORMAL mode with query input disabled, so keystrokes
# are single-letter commands rather than filter text -- otherwise typing a
# filter containing "x" would trigger the kill bind below and destroy a
# session. `i` switches to INSERT mode (enables the query), `esc` while in
# INSERT drops back to NORMAL, and `esc`/`q` in NORMAL cancels the picker.
# fzf has no first-class notion of "mode", so the current mode is tracked
# via the prompt text itself (the "[N] " / "[I] " prefix); the `esc` bind's
# `transform` branches on $FZF_PROMPT to decide which of those two it
# should do.
#
# fzf's execute/transform actions run their snippet via `$SHELL -c`, and
# the user's login shell is fish, which doesn't understand the `case`/`[ ]`
# syntax below. Force SHELL=/bin/sh for this fzf invocation and keep every
# bind snippet in POSIX sh.
fzf_args=(
  --height=100%
  --layout=reverse
  --no-info
  --no-sort
  --ansi
  --delimiter=$'\t'
  --with-nth=2..
  --header-lines=1
  --disabled
  --prompt="[N] session > "
  --header="NORMAL — enter:switch | x:kill | g:root | 1-9:jump | i:filter | q/esc:quit | [merged]=safe to close"
  --bind="j:down,k:up"
  --bind="x:execute-silent($SELF kill {1})+reload($SELF list)"
  --bind="g:execute-silent($SELF jump-root)+abort"
  --bind="i:unbind(i,j,k,x,g,q,1,2,3,4,5,6,7,8,9)+enable-search+change-prompt([I] filter > )+change-header(INSERT — type to filter | enter:switch | esc:normal mode)"
  --bind='esc:transform:case "$FZF_PROMPT" in "[I] "*) echo "disable-search+change-prompt([N] session > )+change-header(NORMAL — enter:switch | x:kill | g:root | 1-9:jump | i:filter | q/esc:quit | [merged]=safe to close)+rebind(i,j,k,x,g,q,1,2,3,4,5,6,7,8,9)";; *) echo abort;; esac'
  --bind="q:abort"
)

# 1-9 jump to the Nth session, NORMAL mode only (the digits are unbound by
# the `i` bind above while filtering, so they type into the query instead).
# Each digit's transform is guarded by $FZF_MATCH_COUNT so pressing a digit
# past the number of visible rows is a no-op rather than accepting whatever
# the last row happens to be. --expect isn't used here: expect-keys fire
# even in INSERT mode, so typing "3" into a filter would otherwise
# immediately accept the current row.
for n in 1 2 3 4 5 6 7 8 9; do
  fzf_args+=(--bind="$n:transform:if [ \"\$FZF_MATCH_COUNT\" -ge $n ]; then echo \"pos($n)+accept\"; fi")
done

selected=$("$SELF" list | SHELL=/bin/sh fzf "${fzf_args[@]}") || exit 0

# fzf's output is just the selected row -- no --expect key line to parse,
# since digit jumps are handled above via pos(N)+accept.
session_name=$(echo "$selected" | awk -F'\t' '{print $1}')

if [[ -n "${session_name:-}" ]]; then
  tmux switch-client -t "$session_name"
fi
