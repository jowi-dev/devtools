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

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
