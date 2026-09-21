#!/usr/bin/env bash
# Verifies every hook script always exits 0, even given garbage/malformed
# stdin, missing env vars, and no HOME state at all.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
export HOME="$TMPDIR_TEST"
unset OTEL_EXPORTER_OTLP_ENDPOINT CLAUDE_CODE_ENABLE_TELEMETRY RIMO_USAGE_INNER_STATUSLINE 2>/dev/null

PASS=0
FAIL=0

check_exit_zero() {
  local desc="$1"
  local input="$2"
  local script="$3"
  printf '%s' "$input" | bash "$script" >/dev/null 2>&1
  local code=$?
  if [[ "$code" -eq 0 ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: exited with ${code}, expected 0" >&2
  fi
}

for garbage in '' 'not json' '{"broken":' 'null' '12345' '{"session_id":null,"rate_limits":"oops"}'; do
  check_exit_zero "statusline.sh with input: ${garbage:0:20}" "$garbage" "${PLUGIN_ROOT}/hooks/statusline.sh"
  check_exit_zero "check-telemetry.sh with input: ${garbage:0:20}" "$garbage" "${PLUGIN_ROOT}/hooks/check-telemetry.sh"
  check_exit_zero "send-snapshot.sh with input: ${garbage:0:20}" "$garbage" "${PLUGIN_ROOT}/hooks/send-snapshot.sh"
done

# send-snapshot.sh with a bogus OTEL endpoint must still exit 0 (silent failure).
export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:1"
check_exit_zero "send-snapshot.sh with unreachable endpoint" '{"session_id":"sess-x"}' "${PLUGIN_ROOT}/hooks/send-snapshot.sh"
unset OTEL_EXPORTER_OTLP_ENDPOINT

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
