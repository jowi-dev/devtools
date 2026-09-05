#!/usr/bin/env bash
# Tests for the "jump back to root session" feature of tmux-session-picker.sh.
#
# Contract under test:
#   tmux-session-picker.sh root-session [<session>]
#     Prints the name of <session>'s root session (default: current session)
#     and exits 0, or prints nothing and exits non-zero if no root can be
#     resolved. Resolution order:
#       1. The @root_session tmux user option, if set to a non-empty value
#          (always wins over git-derived detection).
#       2. Fallback: if the session's #{session_path} is a linked git
#          worktree (a ".git" FILE, not directory), the root session name is
#          derived from the main checkout's directory basename, mapping
#          dots to dashes (mirrors session_name_of_dir in work.ml).
#   tmux-session-picker.sh jump-root [<session>]
#     Resolves the root session the same way, then switch-client's to it.
#     Never aborts: no resolvable root, root == self, or root session not
#     found all print a short message and exit 0 without switching.
#
# Both subcommands honor TMUX_PICKER_SOCKET (talk to `tmux -L <socket>`
# instead of the default socket) so tests run against an isolated server.
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tmux-session-picker.sh"
SOCK="picker-jump-test-$$"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/tsp-jump-test.XXXXXX")"
# macOS mktemp paths live under /var/folders, a symlink of /private/var.
# Normalize so #{session_path} (which tmux resolves via getcwd) matches the
# path git reports, or the worktree/basename comparisons could mismatch.
WORK="$(cd "$WORK" && pwd -P)"

cleanup() {
  tmux -L "$SOCK" kill-server >/dev/null 2>&1 || true
  rm -rf "$WORK"
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

git_c() { git -c user.email=t@t -c user.name=t "$@"; }

### Fixtures ###################################################################
# Main repo with a dot in its name, to exercise the dots -> dashes mapping
# (session_name_of_dir maps '.' to '-', so "my.proj" -> "my-proj").
git_c init -q -b main "$WORK/my.proj"
(
  cd "$WORK/my.proj"
  git_c commit --allow-empty -q -m "initial"
  git_c worktree add -q -b test-branch "$WORK/wt"
)

mkdir -p "$WORK/plain"

tmux -L "$SOCK" -f /dev/null new-session -d -s opt-sess -c "$WORK/wt"
tmux -L "$SOCK" set-option -t opt-sess @root_session explicit-target

tmux -L "$SOCK" new-session -d -s fallback-sess -c "$WORK/wt"

tmux -L "$SOCK" new-session -d -s plain-sess -c "$WORK/plain"

tmux -L "$SOCK" new-session -d -s ghost-sess -c "$WORK/wt"
tmux -L "$SOCK" set-option -t ghost-sess @root_session ghost-root

tmux -L "$SOCK" new-session -d -s empty-sess -c "$WORK/wt"
tmux -L "$SOCK" set-option -t empty-sess @root_session ""

### Case 1: explicit @root_session option wins over git fallback ##############
actual=$(TMUX_PICKER_SOCKET="$SOCK" bash "$SCRIPT" root-session opt-sess 2>&1)
code=$?
check "option wins: prints explicit-target" "explicit-target" "$actual"
check "option wins: exit 0" "0" "$code"

### Case 2: git fallback derives root name from main checkout basename #######
actual=$(TMUX_PICKER_SOCKET="$SOCK" bash "$SCRIPT" root-session fallback-sess 2>&1)
code=$?
check "git fallback: prints my-proj" "my-proj" "$actual"
check "git fallback: exit 0" "0" "$code"

### Case 3: non-worktree session has no resolvable root #######################
set +e
actual=$(TMUX_PICKER_SOCKET="$SOCK" bash "$SCRIPT" root-session plain-sess 2>&1)
code=$?
set -e
check "non-worktree: prints nothing" "" "$actual"
if [ "$code" -eq 0 ]; then
  fail=$((fail + 1))
  echo "FAIL - non-worktree: exit non-zero"
  echo "       expected: non-zero"
  echo "       actual:   0"
else
  pass=$((pass + 1))
  echo "ok   - non-worktree: exit non-zero"
fi

### Case 4: empty @root_session option falls through to git fallback #########
actual=$(TMUX_PICKER_SOCKET="$SOCK" bash "$SCRIPT" root-session empty-sess 2>&1)
code=$?
check "empty option falls through: prints my-proj" "my-proj" "$actual"
check "empty option falls through: exit 0" "0" "$code"

### Case 5: jump-root with an unresolvable target session doesn't switch #####
before=$(tmux -L "$SOCK" display-message -p -t ghost-sess '#S')
set +e
TMUX_PICKER_SOCKET="$SOCK" bash "$SCRIPT" jump-root ghost-sess >/dev/null 2>&1
code=$?
set -e
after=$(tmux -L "$SOCK" display-message -p -t ghost-sess '#S')
check "jump-root missing root: exit 0" "0" "$code"
check "jump-root missing root: session unchanged" "$before" "$after"

### Case 6: jump-root on a non-worktree session doesn't switch/abort #########
set +e
TMUX_PICKER_SOCKET="$SOCK" bash "$SCRIPT" jump-root plain-sess >/dev/null 2>&1
code=$?
set -e
check "jump-root non-worktree: exit 0" "0" "$code"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
