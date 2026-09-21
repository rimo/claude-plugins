#!/usr/bin/env bash
# Tests for lib/json.sh — shared JSON helpers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PLUGIN_ROOT}/lib/json.sh"

PASS=0
FAIL=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local desc="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: expected '${expected}', got '${actual}'" >&2
  fi
}

result="$(json_field '{"session_id":"abc"}' '.session_id')"
assert_eq "abc" "$result" "Top-level field extraction"

result="$(json_field '{"rate_limits":{"five_hour":{"used_percentage":42}}}' '.rate_limits.five_hour.used_percentage')"
assert_eq "42" "$result" "Nested field extraction"

result="$(json_field '{"a":1}' '.missing')"
assert_eq "" "$result" "Missing field returns empty"

result="$(json_field '{"a":null}' '.a')"
assert_eq "" "$result" "Null field returns empty"

result="$(json_field '{"rate_limits":{"five_hour":{"used_percentage":10}}}' '.rate_limits')"
assert_eq '{"five_hour":{"used_percentage":10}}' "$result" "Object field returns compact JSON"

result="$(json_field 'not json at all' '.a')"
assert_eq "" "$result" "Invalid JSON returns empty, does not throw"

result="$(json_escape 'hello "world"\')"
assert_eq 'hello \"world\"\\' "$result" "Escapes quotes and backslashes"

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
