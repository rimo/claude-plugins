#!/usr/bin/env bash
# Sanity checks for .claude-plugin/plugin.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST="${PLUGIN_ROOT}/.claude-plugin/plugin.json"

source "${PLUGIN_ROOT}/lib/json.sh"

PASS=0
FAIL=0

assert_eq() {
  if [[ "$1" == "$2" ]]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $3: expected '$1', got '$2'" >&2; fi
}

assert_neq() {
  local unexpected="$1"
  local actual="$2"
  local desc="$3"
  if [[ "$actual" != "$unexpected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: ${desc}: got unexpected '${actual}'" >&2
  fi
}

manifest="$(cat "$MANIFEST")"

name="$(json_field "$manifest" '.name')"
assert_neq "" "$name" "manifest has a name"

version="$(json_field "$manifest" '.version')"
assert_neq "" "$version" "manifest has a version"

statusline_cmd="$(json_field "$manifest" '.statusLine.command')"
assert_eq "" "$statusline_cmd" "manifest does not declare statusLine (not a plugin.json field)"

hooks="$(cat "${PLUGIN_ROOT}/hooks/hooks.json")"
assert_neq "" "$(json_field "$hooks" '.hooks.SessionStart')" "hooks.json wires SessionStart"
assert_neq "" "$(json_field "$hooks" '.hooks.Stop')" "hooks.json wires Stop"
assert_neq "" "$(json_field "$hooks" '.hooks.SessionEnd')" "hooks.json wires SessionEnd"
case "$hooks" in *install-statusline.sh*) PASS=$((PASS + 1));; *) FAIL=$((FAIL + 1)); echo "FAIL: SessionStart runs install-statusline.sh" >&2;; esac

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
