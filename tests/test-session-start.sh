#!/usr/bin/env bash
# Integration tests for hooks/session-start.sh
# Tests that the hook outputs proactive instructions on the default branch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Create a temporary git repo for testing
TEMP_DIR="$(mktemp -d)"
trap 'cd /; rm -rf "$TEMP_DIR"' EXIT

# Create a bare remote so that the test repo has a remote configured
REMOTE_DIR="${TEMP_DIR}/remote.git"
git init --bare -b main "$REMOTE_DIR" &>/dev/null

REPO_DIR="${TEMP_DIR}/test-repo"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -b main &>/dev/null
git config commit.gpgsign false
git commit --allow-empty -m "initial commit" &>/dev/null
git remote add origin "$REMOTE_DIR" &>/dev/null

HOOK="${PLUGIN_ROOT}/hooks/session-start.sh"

PASS=0
FAIL=0

assert_output() {
  local expected_pattern="$1"
  local actual="$2"
  local desc="$3"
  if echo "$actual" | grep -q "$expected_pattern"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: expected pattern '${expected_pattern}' not found in output" >&2
  fi
}

assert_empty() {
  local actual="$1"
  local desc="$2"
  if [[ -z "$actual" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: expected empty output, got: ${actual}" >&2
  fi
}

run_hook() {
  local json="$1"
  echo "$json" | bash "$HOOK" 2>/dev/null || true
}

# --- Test 1: On default branch in main repo → should output instruction ---
output="$(run_hook "{\"cwd\":\"${REPO_DIR}\"}")"
assert_output "EnterWorktree" "$output" "On default branch should mention EnterWorktree"

# --- Test 2: Output should mention auto-worktree ---
assert_output "auto-worktree" "$output" "Output should mention auto-worktree"

# --- Test 3: In a worktree → no output ---
WORKTREE_DIR="${TEMP_DIR}/test-worktree"
git worktree add "$WORKTREE_DIR" -b test-branch &>/dev/null
output="$(run_hook "{\"cwd\":\"${WORKTREE_DIR}\"}")"
assert_empty "$output" "In worktree should produce no output"

# --- Test 4: On non-default branch → no output ---
git -C "$REPO_DIR" checkout -b feature-branch &>/dev/null
output="$(run_hook "{\"cwd\":\"${REPO_DIR}\"}")"
assert_empty "$output" "On non-default branch should produce no output"
git -C "$REPO_DIR" checkout main &>/dev/null

# --- Test 5: Non-git directory → no output ---
NON_GIT_DIR="$(mktemp -d)"
output="$(run_hook "{\"cwd\":\"${NON_GIT_DIR}\"}")"
assert_empty "$output" "Non-git directory should produce no output"
rmdir "$NON_GIT_DIR"

# --- Test 6: Empty JSON → no output (fail open) ---
output="$(run_hook "{}")"
assert_empty "$output" "Empty JSON should produce no output"

# --- Test 7: Exit code is always 0 ---
exit_code=0
echo "{\"cwd\":\"${REPO_DIR}\"}" | bash "$HOOK" 2>/dev/null || exit_code=$?
if [[ "$exit_code" -eq 0 ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: Exit code should always be 0, got ${exit_code}" >&2
fi

# --- Test 8: No remote configured → no output ---
NO_REMOTE_DIR="${TEMP_DIR}/no-remote-repo"
mkdir -p "$NO_REMOTE_DIR"
git -C "$NO_REMOTE_DIR" init -b main &>/dev/null
git -C "$NO_REMOTE_DIR" config commit.gpgsign false
git -C "$NO_REMOTE_DIR" commit --allow-empty -m "init" &>/dev/null
output="$(run_hook "{\"cwd\":\"${NO_REMOTE_DIR}\"}")"
assert_empty "$output" "No remote configured should produce no output"

# --- Cleanup ---
git -C "$REPO_DIR" worktree remove "$WORKTREE_DIR" 2>/dev/null || true

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
