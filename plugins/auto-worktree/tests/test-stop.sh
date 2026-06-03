#!/usr/bin/env bash
# Tests for hooks/stop.sh — Stop hook session summary.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

TEMP_DIR="$(mktemp -d)"
trap 'cd /; rm -rf "$TEMP_DIR"' EXIT

REPO_DIR="${TEMP_DIR}/test-repo"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -b main &>/dev/null
git config commit.gpgsign false
git commit --allow-empty -m "initial commit" &>/dev/null

HOOK="${PLUGIN_ROOT}/hooks/stop.sh"

PASS=0
FAIL=0

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local desc="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: output does not contain '${needle}'" >&2
  fi
}

# --- Test 1: Stop in main repo → silent exit 0 ---
exit_code=0
output="$(echo '{"cwd":"'"${REPO_DIR}"'"}' | bash "$HOOK" 2>&1)" || exit_code=$?
if [[ "$exit_code" -eq 0 && -z "$output" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: stop in main repo should be silent exit 0" >&2
fi

# --- Test 2: Stop in worktree → prints summary ---
WT_PATH="${TEMP_DIR}/test-worktree"
git worktree add "$WT_PATH" -b "test-branch" &>/dev/null

exit_code=0
output="$(echo '{"cwd":"'"${WT_PATH}"'"}' | bash "$HOOK" 2>&1)" || exit_code=$?
if [[ "$exit_code" -eq 0 ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: stop in worktree should exit 0" >&2
fi
assert_contains "$output" "Auto-Worktree Session Summary" "Summary header"
assert_contains "$output" "test-branch" "Branch name in summary"

# --- Test 3: Worktree with uncommitted changes → shows changes ---
echo "test" > "${WT_PATH}/newfile.txt"
git -C "$WT_PATH" add newfile.txt &>/dev/null

output="$(echo '{"cwd":"'"${WT_PATH}"'"}' | bash "$HOOK" 2>&1)" || true
assert_contains "$output" "Uncommitted changes" "Uncommitted changes warning"

# --- Test 4: stop_hook_active=true → silent exit 0 (no infinite loop) ---
exit_code=0
output="$(echo '{"cwd":"'"${WT_PATH}"'","stop_hook_active":true}' | bash "$HOOK" 2>&1)" || exit_code=$?
if [[ "$exit_code" -eq 0 && -z "$output" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: stop_hook_active=true should be silent exit 0" >&2
fi

# --- Cleanup ---
git -C "$REPO_DIR" worktree remove "$WT_PATH" --force 2>/dev/null || true

echo "${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then exit 1; fi
