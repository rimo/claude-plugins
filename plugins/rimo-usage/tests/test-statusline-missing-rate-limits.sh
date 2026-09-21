#!/usr/bin/env bash
# Verifies the statusLine wrapper writes no snapshot file when rate_limits
# is absent, still prints a fallback line, and always exits 0.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
export HOME="$TMPDIR_TEST"

INPUT='{"session_id":"sess-no-rl","version":"1.2.3","model":{"display_name":"Sonnet"},"context_window":{"used_percentage":15}}'

OUTPUT="$(printf '%s' "$INPUT" | bash "${PLUGIN_ROOT}/hooks/statusline.sh")"
EXIT_CODE=$?

FAIL=0

if [[ "$EXIT_CODE" -ne 0 ]]; then
  echo "FAIL: expected exit 0, got ${EXIT_CODE}" >&2
  FAIL=1
fi

if [[ -z "$OUTPUT" ]]; then
  echo "FAIL: expected a fallback status line, got empty output" >&2
  FAIL=1
fi

if [[ "$OUTPUT" != *"Sonnet"* ]]; then
  echo "FAIL: expected fallback line to include model name, got '${OUTPUT}'" >&2
  FAIL=1
fi

if [[ -d "${HOME}/.claude/rimo-usage" ]] && [[ -n "$(ls -A "${HOME}/.claude/rimo-usage" 2>/dev/null)" ]]; then
  echo "FAIL: expected no snapshot file when rate_limits is absent" >&2
  FAIL=1
fi

if [[ $FAIL -eq 0 ]]; then
  echo "1 passed, 0 failed"
else
  echo "0 passed, 1 failed"
  exit 1
fi
