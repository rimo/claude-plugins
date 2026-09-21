#!/usr/bin/env bash
# Verifies the statusLine wrapper preserves an existing user statusline:
# it still records the rate-limit snapshot, but the printed line comes
# from the user's own command, fed the same stdin JSON the wrapper got.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
export HOME="$TMPDIR_TEST"

mkdir -p "${HOME}/.claude/rimo-usage"
cat >"${HOME}/.claude/rimo-usage/user-statusline.json" <<'EOF'
{"command": "cat | node -e \"const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.stdout.write('inner:' + d.session_id)\""}
EOF

INPUT='{"session_id":"sess-passthrough","version":"1.2.3","rate_limits":{"five_hour":{"used_percentage":10,"resets_at":"2026-01-01T00:00:00Z"}}}'

OUTPUT="$(printf '%s' "$INPUT" | bash "${PLUGIN_ROOT}/hooks/statusline.sh")"
EXIT_CODE=$?

FAIL=0

if [[ "$EXIT_CODE" -ne 0 ]]; then
  echo "FAIL: expected exit 0, got ${EXIT_CODE}" >&2
  FAIL=1
fi

if [[ "$OUTPUT" != "inner:sess-passthrough" ]]; then
  echo "FAIL: expected passthrough output 'inner:sess-passthrough', got '${OUTPUT}'" >&2
  FAIL=1
fi

SNAPSHOT_FILE="${HOME}/.claude/rimo-usage/latest-sess-passthrough.json"
if [[ ! -f "$SNAPSHOT_FILE" ]]; then
  echo "FAIL: expected snapshot file to be written even with passthrough" >&2
  FAIL=1
elif ! grep -q '"session_id":"sess-passthrough"' "$SNAPSHOT_FILE"; then
  echo "FAIL: snapshot file missing session_id" >&2
  FAIL=1
fi

if [[ $FAIL -eq 0 ]]; then
  echo "1 passed, 0 failed"
else
  echo "0 passed, 1 failed"
  exit 1
fi
