#!/usr/bin/env bash
# Verifies send-snapshot.sh builds the exact OTLP payload shape from a
# fixture snapshot, and that an absent window's attributes are omitted
# rather than sent as zeros.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
export HOME="$TMPDIR_TEST"

mkdir -p "${HOME}/.claude/rimo-usage"

# Fixture: five_hour window present, seven_day window absent.
cat >"${HOME}/.claude/rimo-usage/latest-sess-fixture.json" <<'EOF'
{"rate_limits":{"five_hour":{"used_percentage":37,"resets_at":"2026-01-01T00:00:00Z"}},"session_id":"sess-fixture","version":"9.9.9"}
EOF

CAPTURE_FILE="${TMPDIR_TEST}/captured-payload.json"
FAKE_BIN_DIR="${TMPDIR_TEST}/bin"
mkdir -p "$FAKE_BIN_DIR"
cat >"${FAKE_BIN_DIR}/curl" <<EOF
#!/usr/bin/env bash
cat > "${CAPTURE_FILE}"
exit 0
EOF
chmod +x "${FAKE_BIN_DIR}/curl" 2>/dev/null || true

export PATH="${FAKE_BIN_DIR}:${PATH}"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:9999"
export GIT_CONFIG_GLOBAL="${TMPDIR_TEST}/gitconfig"
git config --file "$GIT_CONFIG_GLOBAL" user.email "fixture@example.com" >/dev/null 2>&1 || true

INPUT='{"session_id":"sess-fixture","hook_event_name":"Stop"}'
printf '%s' "$INPUT" | bash "${PLUGIN_ROOT}/hooks/send-snapshot.sh" >/dev/null 2>&1
EXIT_CODE=$?

FAIL=0

if [[ "$EXIT_CODE" -ne 0 ]]; then
  echo "FAIL: expected exit 0, got ${EXIT_CODE}" >&2
  FAIL=1
fi

if [[ ! -f "$CAPTURE_FILE" ]]; then
  echo "FAIL: expected curl to be invoked with a captured payload" >&2
  exit 1
fi

PAYLOAD="$(cat "$CAPTURE_FILE")"

require_contains() {
  local needle="$1"
  local desc="$2"
  if [[ "$PAYLOAD" != *"$needle"* ]]; then
    echo "FAIL: ${desc} — payload missing '${needle}'" >&2
    echo "payload was: $PAYLOAD" >&2
    FAIL=1
  fi
}

require_contains '"key":"event.name","value":{"stringValue":"rimo.rate_limit_snapshot"}' "event.name attribute"
require_contains '"body":{"stringValue":"rimo.rate_limit_snapshot"}' "body"
require_contains '"key":"service.name","value":{"stringValue":"claude-code"}' "resource service.name"
require_contains '"key":"service.version","value":{"stringValue":"0.1.0"}' "resource service.version"
require_contains '"key":"tool","value":{"stringValue":"claude_code"}' "tool attribute"
require_contains '"key":"session.id","value":{"stringValue":"sess-fixture"}' "session.id attribute"
require_contains '"key":"five_hour_pct","value":{"doubleValue":37}' "five_hour_pct attribute"
require_contains '"key":"five_hour_resets_at"' "five_hour_resets_at attribute"
require_contains '"key":"claude_code.version","value":{"stringValue":"9.9.9"}' "claude_code.version attribute"

if [[ "$PAYLOAD" == *"seven_day_pct"* ]]; then
  echo "FAIL: absent seven_day window must not appear in payload at all" >&2
  FAIL=1
fi

if [[ "$PAYLOAD" == *'"doubleValue":0}'* ]]; then
  echo "FAIL: payload must never send a zero standing in for an absent value" >&2
  FAIL=1
fi

if [[ $FAIL -eq 0 ]]; then
  echo "1 passed, 0 failed"
else
  echo "0 passed, 1 failed"
  exit 1
fi
