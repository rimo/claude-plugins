#!/usr/bin/env bash
# Verifies check-telemetry.sh surfaces its warning to the user as hook JSON
# (SessionStart plain stdout goes to Claude's context, not the user) and
# stays silent when telemetry is configured.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
HOOK="${PLUGIN_ROOT}/hooks/check-telemetry.sh"
# shellcheck source=../lib/json.sh
source "${PLUGIN_ROOT}/lib/json.sh"

PASS=0
FAIL=0
assert_eq() {
  if [[ "$1" == "$2" ]]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $3: expected '$1', got '$2'" >&2; fi
}

# Unset telemetry: one JSON object with a systemMessage naming the fix.
unset CLAUDE_CODE_ENABLE_TELEMETRY OTEL_EXPORTER_OTLP_ENDPOINT
out="$(printf '{"session_id":"s1"}' | bash "$HOOK")"; assert_eq "0" "$?" "exits 0 when telemetry unset"
msg="$(json_field "$out" '.systemMessage')"
assert_eq "true" "$([[ "$msg" == *"[rimo-usage]"* ]] && echo true || echo false)" "systemMessage carries the plugin tag"
assert_eq "true" "$([[ "$msg" == *"setup-rimo-usage.sh"* ]] && echo true || echo false)" "systemMessage names the setup script"
assert_eq "true" "$([[ "$msg" == *"OTEL_EXPORTER_OTLP_ENDPOINT"* ]] && echo true || echo false)" "systemMessage names the env vars"
assert_eq "1" "$(printf '%s\n' "$out" | grep -c .)" "output is a single line"

# Only one of the two vars set still warns.
out="$(CLAUDE_CODE_ENABLE_TELEMETRY=1 bash "$HOOK" </dev/null)"
assert_eq "true" "$([[ -n "$(json_field "$out" '.systemMessage')" ]] && echo true || echo false)" "warns when only CLAUDE_CODE_ENABLE_TELEMETRY is set"

# Both set (and a JSON tool present): silent.
out="$(CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.example.test bash "$HOOK" </dev/null)"
assert_eq "0" "$?" "exits 0 when telemetry configured"
assert_eq "" "$out" "silent when telemetry configured"

echo "${PASS} passed, ${FAIL} failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
