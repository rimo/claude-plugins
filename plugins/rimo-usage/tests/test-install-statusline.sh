#!/usr/bin/env bash
# Verifies install-statusline.sh wires the wrapper into settings.json,
# preserves a pre-existing statusline, and is idempotent.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
HOOK="${PLUGIN_ROOT}/hooks/install-statusline.sh"

source "${PLUGIN_ROOT}/lib/json.sh"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
export HOME="$TMPDIR_TEST"
export CLAUDE_CONFIG_DIR="${TMPDIR_TEST}/.claude"
SETTINGS="${CLAUDE_CONFIG_DIR}/settings.json"
USER_FILE="${HOME}/.claude/rimo-usage/user-statusline.json"

PASS=0
FAIL=0

assert_eq() {
  if [[ "$1" == "$2" ]]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $3: expected '$1', got '$2'" >&2; fi
}

if ! command -v node >/dev/null 2>&1; then
  echo "node not available; skipping"
  exit 0
fi

# Fresh settings: wrapper installed, no user statusline saved.
printf '' | bash "$HOOK"; assert_eq "0" "$?" "hook exits 0 with no settings.json"
cmd="$(json_field "$(cat "$SETTINGS")" '.statusLine.command')"
assert_eq "bash \"${PLUGIN_ROOT}/hooks/statusline.sh\"" "$cmd" "wrapper installed into settings.json"
[[ -f "$USER_FILE" ]] && assert_eq "absent" "present" "no user statusline saved when none existed"

# Existing user statusline: saved, then replaced by the wrapper; other keys kept.
rm -rf "${HOME}/.claude/rimo-usage"
mkdir -p "$CLAUDE_CONFIG_DIR"
printf '{"model":"opus","statusLine":{"type":"command","command":"echo mine"}}\n' >"$SETTINGS"
printf '' | bash "$HOOK"
assert_eq "echo mine" "$(json_field "$(cat "$USER_FILE")" '.command')" "existing statusline saved for passthrough"
assert_eq "bash \"${PLUGIN_ROOT}/hooks/statusline.sh\"" "$(json_field "$(cat "$SETTINGS")" '.statusLine.command')" "wrapper replaces existing statusline"
assert_eq "opus" "$(json_field "$(cat "$SETTINGS")" '.model')" "unrelated settings preserved"

# Idempotent: second run leaves settings byte-identical and user file untouched.
before="$(cat "$SETTINGS")"
printf '' | bash "$HOOK"
assert_eq "$before" "$(cat "$SETTINGS")" "second run is a no-op"
assert_eq "echo mine" "$(json_field "$(cat "$USER_FILE")" '.command')" "saved user statusline not overwritten"

# Existing statusline with extra fields: padding kept on the wrapper entry, full entry saved.
rm -rf "${HOME}/.claude/rimo-usage"
printf '{"statusLine":{"type":"command","command":"echo mine","padding":2}}\n' >"$SETTINGS"
printf '' | bash "$HOOK"
assert_eq "2" "$(json_field "$(cat "$SETTINGS")" '.statusLine.padding')" "padding preserved on wrapper entry"
assert_eq "bash \"${PLUGIN_ROOT}/hooks/statusline.sh\"" "$(json_field "$(cat "$SETTINGS")" '.statusLine.command')" "wrapper installed alongside padding"
assert_eq "2" "$(json_field "$(cat "$USER_FILE")" '.padding')" "saved user entry keeps padding"
assert_eq "echo mine" "$(json_field "$(cat "$USER_FILE")" '.command')" "saved user entry keeps command"

# Invalid settings.json: hook exits 0 and leaves the file alone.
printf 'not json' >"$SETTINGS"
printf '' | bash "$HOOK"; assert_eq "0" "$?" "hook exits 0 on invalid settings.json"
assert_eq "not json" "$(cat "$SETTINGS")" "invalid settings.json left untouched"

echo "${PASS} passed, ${FAIL} failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
