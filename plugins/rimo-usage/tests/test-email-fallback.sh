#!/usr/bin/env bash
# Verifies resolve_user_email prefers ~/.claude.json's oauthAccount email,
# and falls back to `git config user.email` when that file is absent or
# has no oauth email.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

source "${PLUGIN_ROOT}/lib/common.sh"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT
export HOME="$TMPDIR_TEST"

# Run from a scratch directory with no local git config of its own, so the
# test only ever sees the global config fixture set up below (avoids
# picking up this repository's own committer email as a false pass/fail).
SCRATCH_DIR="${TMPDIR_TEST}/scratch"
mkdir -p "$SCRATCH_DIR"
cd "$SCRATCH_DIR"
export GIT_CONFIG_NOSYSTEM=1

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

# --- Case 1: no ~/.claude.json at all → falls back to git config ---
export GIT_CONFIG_GLOBAL="${TMPDIR_TEST}/gitconfig-1"
git config --file "$GIT_CONFIG_GLOBAL" user.email "fallback@example.com" >/dev/null 2>&1
result="$(resolve_user_email)"
assert_eq "fallback@example.com" "$result" "Falls back to git config when claude.json is absent"

# --- Case 2: ~/.claude.json present with oauthAccount.emailAddress ---
cat >"${HOME}/.claude.json" <<'EOF'
{"oauthAccount": {"emailAddress": "oauth@example.com"}}
EOF
result="$(resolve_user_email)"
assert_eq "oauth@example.com" "$result" "Prefers oauthAccount.emailAddress when present"

# --- Case 3: ~/.claude.json present but without an oauth email → falls back ---
cat >"${HOME}/.claude.json" <<'EOF'
{"someOtherField": true}
EOF
result="$(resolve_user_email)"
assert_eq "fallback@example.com" "$result" "Falls back to git config when oauth email is missing"

echo "${PASS} passed, ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
