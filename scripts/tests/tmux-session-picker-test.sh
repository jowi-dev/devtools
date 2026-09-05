#!/usr/bin/env bash
# Tests for `tmux-session-picker.sh branch-status <path>` merge-detection logic.
#
# Contract under test:
#   tmux-session-picker.sh branch-status <path>
# prints (plain text, no ANSI color) one of:
#   ""                      -- not a git repo, missing path, on the default
#                               branch already, or no default branch resolvable
#   "<branch> [merged]"     -- branch is merged into the default branch
#                               (fast-forward ancestor OR squash-merged)
#   "<branch> [unmerged]"   -- branch has commits not in the default branch
#   "[detached]"            -- HEAD is detached
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tmux-session-picker.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/tsp-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

check() {
  local desc="$1" path="$2" expected="$3" actual
  actual=$("$SCRIPT" branch-status "$path" 2>&1 || true)
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

check_project() {
  local desc="$1" path="$2" expected="$3" actual
  actual=$("$SCRIPT" project-name "$path" 2>&1 || true)
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

git_c() { git -c user.email=t@t -c user.name=t "$@"; }

# Set up a bare "origin" and a repo cloned from it, so origin/HEAD resolves
# the same way it would in Joe's real repos.
make_repo() {
  local name="$1"
  local origin="$WORK/$name-origin.git"
  local repo="$WORK/$name"

  git init --bare -q -b main "$origin"

  git_c init -q -b main "$repo"
  (
    cd "$repo"
    git_c commit --allow-empty -q -m "initial"
    git remote add origin "$origin"
    git push -q origin main
    git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  )
  echo "$repo"
}

### Case 1: branch merged via merge commit ###################################
repo=$(make_repo case1)
(
  cd "$repo"
  git_c checkout -q -b feature-merge
  echo "a" >file-a.txt
  git_c add file-a.txt
  git_c commit -q -m "feature work"
  git_c checkout -q main
  git_c merge -q --no-ff feature-merge -m "merge feature-merge"
  git push -q origin main
  git_c checkout -q feature-merge
)
check "merge-commit merged branch" "$repo" "feature-merge [merged]"

### Case 2: branch squash-merged (not an ancestor of main) ###################
repo=$(make_repo case2)
(
  cd "$repo"
  git_c checkout -q -b feature-squash
  echo "b1" >file-b.txt
  git_c add file-b.txt
  git_c commit -q -m "squash work 1"
  echo "b2" >>file-b.txt
  git_c add file-b.txt
  git_c commit -q -m "squash work 2"

  git_c checkout -q main
  # Apply the same resulting tree as a single squash commit on main,
  # without merging (so feature-squash is NOT an ancestor of main).
  git_c checkout -q feature-squash -- file-b.txt
  git_c add file-b.txt
  git_c commit -q -m "squashed feature-squash"
  git push -q origin main
  git_c checkout -q feature-squash
)
check "squash-merged branch" "$repo" "feature-squash [merged]"

### Case 3: unmerged branch with unique commits ###############################
repo=$(make_repo case3)
(
  cd "$repo"
  git_c checkout -q -b feature-unmerged
  echo "c" >file-c.txt
  git_c add file-c.txt
  git_c commit -q -m "unmerged work"
)
check "unmerged branch" "$repo" "feature-unmerged [unmerged]"

### Case 4: checked out on the default branch itself ##########################
repo=$(make_repo case4)
check "on default branch" "$repo" ""

### Case 5: non-git directory ##################################################
nongit="$WORK/not-a-repo"
mkdir -p "$nongit"
check "non-git directory" "$nongit" ""

### Case 6: detached HEAD ######################################################
repo=$(make_repo case6)
(
  cd "$repo"
  git_c checkout -q --detach main
)
check "detached HEAD" "$repo" "[detached]"

### Case 7: project-name — regular git repo ###################################
repo=$(make_repo case7)
check_project "regular repo reports its own name" "$repo" "$(basename "$repo")"

### Case 8: project-name — linked worktree reports the PARENT repo's name #####
repo=$(make_repo case8)
wt="$WORK/case8-wt"
(
  cd "$repo"
  git_c worktree add -q -b case8-wt-branch "$wt"
)
check_project "linked worktree reports parent repo name" "$wt" "$(basename "$repo")"

### Case 9: project-name — non-git directory ###################################
nongit2="$WORK/not-a-repo-2"
mkdir -p "$nongit2"
check_project "non-git directory" "$nongit2" "-"

### Case 10: project-name — nonexistent path ###################################
check_project "nonexistent path" "$WORK/does-not-exist" "-"

### Case 11: list formatting — column alignment + delimiter parsing ############
# Feeds fixed TSV rows (bypassing tmux/git entirely) into the script's
# internal `list_plain | format_rows` pipeline via a small harness, so the
# padding/coloring logic is testable without a live tmux server or repos.
check_list_format() {
  local desc="$1"
  local out
  out=$(
    printf 'alpha\t1\t*\talpha\t-\t-\t-\t-\t-\nlong-session-name\t2\t-\tlong-session-name\t?\twt\tdevtools\tfeature-branch\tmerged\n' \
      | bash -c '
          source "'"$SCRIPT"'" 2>/dev/null || true
          format_rows
        ' 2>/dev/null
  )

  # Field 1 (bare name) must be exactly the machine-readable key, untouched
  # by padding or color, for every non-header row.
  local f1_alpha f1_long
  f1_alpha=$(echo "$out" | awk -F'\t' 'NR==2{print $1}')
  f1_long=$(echo "$out" | awk -F'\t' 'NR==3{print $1}')
  if [ "$f1_alpha" != "alpha" ] || [ "$f1_long" != "long-session-name" ]; then
    fail=$((fail + 1))
    echo "FAIL - $desc (field 1 mismatch)"
    echo "       alpha field1: [$f1_alpha]  long field1: [$f1_long]"
    return
  fi

  # Header row's bare-name field (field 1) must be empty.
  local header_f1
  header_f1=$(echo "$out" | awk -F'\t' 'NR==1{print $1}')
  if [ -n "$header_f1" ]; then
    fail=$((fail + 1))
    echo "FAIL - $desc (header field 1 not empty: [$header_f1])"
    return
  fi

  # Display fields (field 2), stripped of ANSI, must be equal width across
  # all rows including the header, i.e. the grid is actually aligned.
  local plain_widths
  plain_widths=$(echo "$out" | awk -F'\t' '{print $2}' | sed $'s/\033\\[[0-9;]*m//g' | awk '{print length}' | sort -u)
  local n_widths
  n_widths=$(echo "$plain_widths" | wc -l | tr -d ' ')
  if [ "$n_widths" != "1" ]; then
    fail=$((fail + 1))
    echo "FAIL - $desc (display column widths not aligned: $plain_widths)"
    return
  fi

  # ANSI escapes must only appear in field 2 (display), never in field 1.
  if echo "$out" | awk -F'\t' '{print $1}' | grep -q $'\033'; then
    fail=$((fail + 1))
    echo "FAIL - $desc (ANSI escape leaked into field 1)"
    return
  fi

  pass=$((pass + 1))
  echo "ok   - $desc"
}
check_list_format "list_plain rows format into an aligned, delimiter-safe grid"

### Case 8: ATTN cell carries a combined status+server symbol #################
# Mirrors how list_plain() concatenates @picker_status and @picker_server
# into one ATTN cell: a session with both gets "❓🔥", one with only the
# server symbol gets "🔥" alone. Field 1 (bare name) must stay untouched.
check_attn_combo() {
  local desc="$1"
  local out
  out=$(
    printf 'both\t1\t*\tboth\t\xe2\x9d\x93\xf0\x9f\x94\xa5\t-\t-\t-\nserver-only\t2\t-\tserver-only\t\xf0\x9f\x94\xa5\t-\t-\t-\n' \
      | bash -c '
          source "'"$SCRIPT"'" 2>/dev/null || true
          format_rows
        ' 2>/dev/null
  )

  local f1_both f1_srv attn_both attn_srv
  f1_both=$(echo "$out" | awk -F'\t' 'NR==2{print $1}')
  f1_srv=$(echo "$out" | awk -F'\t' 'NR==3{print $1}')
  if [ "$f1_both" != "both" ] || [ "$f1_srv" != "server-only" ]; then
    fail=$((fail + 1))
    echo "FAIL - $desc (field 1 mismatch)"
    echo "       both field1: [$f1_both]  server-only field1: [$f1_srv]"
    return
  fi

  attn_both=$(echo "$out" | awk -F'\t' 'NR==2{print $2}')
  attn_srv=$(echo "$out" | awk -F'\t' 'NR==3{print $2}')
  if ! echo "$attn_both" | grep -qF $'\xe2\x9d\x93\xf0\x9f\x94\xa5'; then
    fail=$((fail + 1))
    echo "FAIL - $desc (combined ATTN cell missing from row: [$attn_both])"
    return
  fi
  if ! echo "$attn_srv" | grep -qF $'\xf0\x9f\x94\xa5'; then
    fail=$((fail + 1))
    echo "FAIL - $desc (server-only ATTN cell missing from row: [$attn_srv])"
    return
  fi

  pass=$((pass + 1))
  echo "ok   - $desc"
}
check_attn_combo "format_rows renders combined status+server ATTN cells"

### Case 9: live list --plain — detection runs at list time, renders in ATTN ##
# Runs the real picker (list --plain) against an isolated tmux server with a
# real listener on one session and a stale @picker_server on another, to
# prove end-to-end that detection happens fresh at list time and lands in
# the ATTN cell without disturbing @picker_status.
LIST_SOCK="picker-list-test-$$"
LIST_OWNER_DIR="$(mktemp -d)"
LIST_OTHER_DIR="$(mktemp -d)"
LIST_OUT_DIR="$(mktemp -d)"
LIST_NC_PID=""

list_cleanup() {
  [ -n "$LIST_NC_PID" ] && kill "$LIST_NC_PID" >/dev/null 2>&1 || true
  tmux -L "$LIST_SOCK" kill-server >/dev/null 2>&1 || true
  rm -rf "$LIST_OWNER_DIR" "$LIST_OTHER_DIR" "$LIST_OUT_DIR"
}
trap 'list_cleanup; rm -rf "$WORK"' EXIT

# lsowner will run the `list --plain` capture; lsother hosts the real
# listener (a pane can't easily run both a background listener and the
# capture command at once).
tmux -L "$LIST_SOCK" -f /dev/null new-session -d -s lsowner -c "$LIST_OWNER_DIR"
tmux -L "$LIST_SOCK" new-session -d -s lsother -c "$LIST_OTHER_DIR"

LIST_PORT=$((20000 + RANDOM % 20000))
tmux -L "$LIST_SOCK" send-keys -t lsother "nc -l $LIST_PORT" C-m

listener_pid=""
for _ in $(seq 1 50); do
  listener_pid="$(lsof -nP -iTCP:"$LIST_PORT" -sTCP:LISTEN -t 2>/dev/null | head -n1 || true)"
  [ -n "$listener_pid" ] && break
  sleep 0.1
done

if [ -z "$listener_pid" ]; then
  fail=$((fail + 1))
  echo "FAIL - list --plain live case: listener never came up on port $LIST_PORT"
else
  LIST_NC_PID="$listener_pid"

  # Pre-seed a stale server symbol on lsowner (should be cleared by fresh
  # detection) and a @picker_status on lsowner (must survive untouched).
  tmux -L "$LIST_SOCK" set-option -t lsowner @picker_server "🔥" >/dev/null 2>&1 || true
  tmux -L "$LIST_SOCK" set-option -t lsowner @picker_status "❓" >/dev/null 2>&1 || true

  LIST_OUT="$LIST_OUT_DIR/out.tsv"
  LIST_DONE="$LIST_OUT_DIR/done"
  tmux -L "$LIST_SOCK" send-keys -t lsowner \
    "PICKER_SERVER_PORT=$LIST_PORT bash '$SCRIPT' list --plain > '$LIST_OUT' 2>/dev/null; touch '$LIST_DONE'" C-m

  waited=0
  while [ ! -f "$LIST_DONE" ] && [ "$waited" -lt 50 ]; do
    sleep 0.1
    waited=$((waited + 1))
  done

  if [ ! -f "$LIST_DONE" ]; then
    fail=$((fail + 1))
    echo "FAIL - list --plain live case: capture never completed"
  else
    lsother_attn=$(awk -F'\t' '$1=="lsother"{print $5}' "$LIST_OUT")
    lsowner_attn=$(awk -F'\t' '$1=="lsowner"{print $5}' "$LIST_OUT")
    lsother_fields=$(awk -F'\t' '$1=="lsother"{print NF}' "$LIST_OUT")
    lsowner_fields=$(awk -F'\t' '$1=="lsowner"{print NF}' "$LIST_OUT")

    check_eq() {
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
    check_eq "list --plain: lsother (live listener owner) gets server symbol in ATTN" "🔥" "$lsother_attn"
    check_eq "list --plain: lsowner's stale server symbol cleared, @picker_status untouched" "❓" "$lsowner_attn"
    check_eq "list --plain: lsother row has 9 tab-separated fields" "9" "$lsother_fields"
    check_eq "list --plain: lsowner row has 9 tab-separated fields" "9" "$lsowner_fields"
  fi
fi

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
