#!/usr/bin/env bash
# Shared helpers for the rimo-usage plugin.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=./json.sh
source "${PLUGIN_ROOT}/lib/json.sh"

RIMO_USAGE_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/rimo-usage"

plugin_version() {
  local manifest="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  [[ -f "$manifest" ]] || { echo ""; return; }
  json_field "$(cat "$manifest")" '.version'
}

latest_snapshot_file() {
  local session_id="$1"
  echo "${RIMO_USAGE_DIR}/latest-${session_id}.json"
}

# Atomically write $2 (content) to $1 (path) via a temp file + rename.
atomic_write() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")" 2>/dev/null || return 1
  local tmp
  tmp="$(mktemp "${path}.XXXXXX" 2>/dev/null)" || return 1
  printf '%s' "$content" >"$tmp" 2>/dev/null || {
    rm -f "$tmp" 2>/dev/null
    return 1
  }
  mv "$tmp" "$path" 2>/dev/null
}

# Resolve the user's email: ~/.claude.json oauthAccount, then git config user.email.
resolve_user_email() {
  local claude_json="${HOME}/.claude.json"
  local email=""
  if [[ -f "$claude_json" ]]; then
    email="$(json_field "$(cat "$claude_json")" '.oauthAccount.emailAddress')"
    if [[ -z "$email" ]]; then
      email="$(json_field "$(cat "$claude_json")" '.oauthAccount.email')"
    fi
  fi
  if [[ -z "$email" ]]; then
    email="$(git config --get user.email 2>/dev/null)"
  fi
  echo "$email"
}

# Convert a resets_at value (ISO 8601 string or already-numeric unix seconds)
# to unix seconds. Prints an empty string if it cannot be parsed.
to_unix_seconds() {
  local val="$1"
  [[ -z "$val" || "$val" == "null" ]] && { echo ""; return; }
  if [[ "$val" =~ ^[0-9]+$ ]]; then
    echo "$val"
    return
  fi
  if command -v node &>/dev/null; then
    node -e '
const d = new Date(process.argv[1]);
process.stdout.write(isNaN(d.getTime()) ? "" : String(Math.floor(d.getTime() / 1000)));
' -- "$val"
  else
    echo ""
  fi
}

# Remove snapshot files older than 1 day (portable: no GNU-only find flags).
prune_old_snapshots() {
  [[ -d "$RIMO_USAGE_DIR" ]] || return 0
  local now cutoff
  now="$(date +%s)"
  cutoff=$((now - 86400))
  local f mtime
  for f in "${RIMO_USAGE_DIR}"/latest-*.json; do
    [[ -f "$f" ]] || continue
    mtime="$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo "$now")"
    if [[ "$mtime" -lt "$cutoff" ]]; then
      rm -f "$f" 2>/dev/null
    fi
  done
}
