#!/usr/bin/env bash
# Tests for bypass functionality (lib/bypass.sh + pre-tool-use integration)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PLUGIN_ROOT}/lib/bypass.sh"

PASS=0
FAIL=0

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local desc="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: expected exit ${expected}, got ${actual}" >&2
  fi
}

SESSION="test-bypass-$(date +%s)-$$"

# Clean up any leftover files from previous runs
trap 'clear_bypass "${SESSION}-1"; clear_bypass "${SESSION}-2"; clear_bypass "${SESSION}-int"' EXIT

# --- Test 1: get_tmp_dir returns a valid directory ---
tmp_dir="$(get_tmp_dir)"
if [[ -d "$tmp_dir" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: get_tmp_dir should return an existing directory, got '${tmp_dir}'" >&2
fi

# --- Test 2: Bypass is not active by default ---
if is_bypass_active "${SESSION}-1"; then
  FAIL=$((FAIL + 1))
  echo "FAIL: Bypass should not be active by default" >&2
else
  PASS=$((PASS + 1))
fi

# --- Test 3: set_bypass activates the flag ---
set_bypass "${SESSION}-1"
if is_bypass_active "${SESSION}-1"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: Bypass should be active after set_bypass" >&2
fi

# --- Test 4: Cross-session isolation — other session unaffected ---
if is_bypass_active "${SESSION}-2"; then
  FAIL=$((FAIL + 1))
  echo "FAIL: Bypass for session-1 should not affect session-2" >&2
else
  PASS=$((PASS + 1))
fi

# --- Test 5: clear_bypass deactivates the flag ---
clear_bypass "${SESSION}-1"
if is_bypass_active "${SESSION}-1"; then
  FAIL=$((FAIL + 1))
  echo "FAIL: Bypass should be inactive after clear_bypass" >&2
else
  PASS=$((PASS + 1))
fi

# --- Test 6: Empty session_id → is_bypass_active returns false ---
if is_bypass_active ""; then
  FAIL=$((FAIL + 1))
  echo "FAIL: Empty session_id should not be active" >&2
else
  PASS=$((PASS + 1))
fi

# --- Test 7: get_bypass_file returns expected path ---
bypass_file="$(get_bypass_file "${SESSION}-1")"
expected_file="$(get_tmp_dir)/auto-worktree-bypass-${SESSION}-1"
if [[ "$bypass_file" == "$expected_file" ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: get_bypass_file returned '${bypass_file}', expected '${expected_file}'" >&2
fi

# --- Test 8: touch bypass file directly (simulates Claude running the command) ---
clear_bypass "${SESSION}-1"
touch "$(get_bypass_file "${SESSION}-1")"
if is_bypass_active "${SESSION}-1"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: touch on bypass file should activate bypass" >&2
fi
clear_bypass "${SESSION}-1"

# --- Integration tests with pre-tool-use.sh ---

TEMP_DIR="$(mktemp -d)"
trap 'cd /; rm -rf "$TEMP_DIR"; clear_bypass "${SESSION}-1"; clear_bypass "${SESSION}-2"; clear_bypass "${SESSION}-int"' EXIT
REMOTE_DIR="${TEMP_DIR}/remote.git"
git init --bare -b main "$REMOTE_DIR" &>/dev/null
REPO_DIR="${TEMP_DIR}/test-repo"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -b main &>/dev/null
git config commit.gpgsign false
git commit --allow-empty -m "initial commit" &>/dev/null
git remote add origin "$REMOTE_DIR" &>/dev/null

PRE_HOOK="${PLUGIN_ROOT}/hooks/pre-tool-use.sh"

# --- Test 9: Without bypass, Write is blocked (exit 2) ---
clear_bypass "${SESSION}-int"
exit_code=0
echo "{\"session_id\":\"${SESSION}-int\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${REPO_DIR}\"}" | bash "$PRE_HOOK" 2>/dev/null || exit_code=$?
assert_exit_code 2 "$exit_code" "Write without bypass should exit 2"

# --- Test 10: Pre-tool-use block message mentions bypass file path ---
stderr_output="$(echo "{\"session_id\":\"${SESSION}-int\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${REPO_DIR}\"}" | bash "$PRE_HOOK" 2>&1 >/dev/null || true)"
if echo "$stderr_output" | grep -q "auto-worktree-bypass-${SESSION}-int"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: Pre-tool-use stderr should contain bypass file path" >&2
fi

# --- Test 11: With bypass, Write is allowed (exit 0) ---
set_bypass "${SESSION}-int"
exit_code=0
echo "{\"session_id\":\"${SESSION}-int\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${REPO_DIR}\"}" | bash "$PRE_HOOK" 2>/dev/null || exit_code=$?
assert_exit_code 0 "$exit_code" "Write with bypass should exit 0"

# --- Test 12: With bypass, Bash redirect is allowed (exit 0) ---
exit_code=0
echo "{\"session_id\":\"${SESSION}-int\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo hello > src/main.py\"},\"cwd\":\"${REPO_DIR}\"}" | bash "$PRE_HOOK" 2>/dev/null || exit_code=$?
assert_exit_code 0 "$exit_code" "Bash redirect with bypass should exit 0"

# --- Test 13: With bypass, Edit is allowed (exit 0) ---
exit_code=0
echo "{\"session_id\":\"${SESSION}-int\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"test.txt\"},\"cwd\":\"${REPO_DIR}\"}" | bash "$PRE_HOOK" 2>/dev/null || exit_code=$?
assert_exit_code 0 "$exit_code" "Edit with bypass should exit 0"
clear_bypass "${SESSION}-int"

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
