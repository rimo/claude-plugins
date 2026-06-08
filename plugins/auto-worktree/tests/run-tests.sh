#!/usr/bin/env bash
# Test runner for auto-worktree plugin.
# Executes all test-*.sh files and reports results.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors (if terminal supports them)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  NC='\033[0m'
  PASS_MARK="${GREEN}✔ PASS${NC}"
  FAIL_MARK="${RED}✘ FAIL${NC}"
else
  GREEN='' RED='' YELLOW='' NC=''
  PASS_MARK='✔ PASS'
  FAIL_MARK='✘ FAIL'
fi

total=0
passed=0
failed=0
failed_tests=()

echo "========================================"
echo " auto-worktree plugin test suite"
echo "========================================"
echo ""

for test_file in "${SCRIPT_DIR}"/test-*.sh; do
  if [[ ! -f "$test_file" ]]; then
    continue
  fi

  test_name="$(basename "$test_file")"
  total=$((total + 1))

  echo -n "Running ${test_name}... "

  # Run each test file in a subshell with its own temp directory
  output=""
  if output="$(bash "$test_file" 2>&1)"; then
    echo -e "${PASS_MARK}"
    passed=$((passed + 1))
  else
    echo -e "${FAIL_MARK}"
    failed=$((failed + 1))
    failed_tests+=("$test_name")
    # Print failure output indented
    if [[ -n "$output" ]]; then
      echo "$output" | sed 's/^/  | /'
    fi
  fi
done

echo ""
echo "========================================"
echo -e " Results: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}, ${total} total"

if [[ ${#failed_tests[@]} -gt 0 ]]; then
  echo ""
  echo " Failed tests:"
  for t in "${failed_tests[@]}"; do
    echo -e "   ${RED}✗${NC} ${t}"
  done
fi

echo "========================================"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
exit 0
