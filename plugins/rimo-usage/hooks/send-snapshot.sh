#!/usr/bin/env bash
# Stop / SessionEnd hook: sends the session's latest rate-limit snapshot to
# the OTLP collector as a single /v1/logs record, then prunes old snapshot
# files. Never blocks or fails the session — always exits 0.

trap 'exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=../lib/common.sh
source "${PLUGIN_ROOT}/lib/common.sh"

INPUT="$(cat)"
SESSION_ID="$(json_field "$INPUT" '.session_id')"

send_snapshot() {
  [[ -n "$SESSION_ID" ]] || return 0
  [[ -n "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]] || return 0

  local snapshot_file
  snapshot_file="$(latest_snapshot_file "$SESSION_ID")"
  [[ -f "$snapshot_file" ]] || return 0

  local snapshot rate_limits
  snapshot="$(cat "$snapshot_file" 2>/dev/null)" || return 0
  [[ -n "$snapshot" ]] || return 0

  rate_limits="$(json_field "$snapshot" '.rate_limits')"
  [[ -n "$rate_limits" && "$rate_limits" != "null" ]] || return 0

  local five_hour seven_day
  five_hour="$(json_field "$rate_limits" '.five_hour')"
  seven_day="$(json_field "$rate_limits" '.seven_day')"

  local email version plugin_ver
  email="$(resolve_user_email)"
  version="$(json_field "$snapshot" '.version')"
  plugin_ver="$(plugin_version)"

  local attrs=""
  add_attr() {
    local key="$1" kind="$2" value="$3"
    [[ -n "$attrs" ]] && attrs="${attrs},"
    case "$kind" in
      string) attrs="${attrs}{\"key\":\"${key}\",\"value\":{\"stringValue\":\"$(json_escape "$value")\"}}" ;;
      double) attrs="${attrs}{\"key\":\"${key}\",\"value\":{\"doubleValue\":${value}}}" ;;
      int) attrs="${attrs}{\"key\":\"${key}\",\"value\":{\"intValue\":${value}}}" ;;
    esac
  }

  add_attr "event.name" string "rimo.rate_limit_snapshot"
  add_attr "tool" string "claude_code"
  [[ -n "$email" ]] && add_attr "user.email" string "$email"
  add_attr "session.id" string "$SESSION_ID"

  if [[ -n "$five_hour" && "$five_hour" != "null" ]]; then
    local pct resets_at unix_resets
    pct="$(json_field "$five_hour" '.used_percentage')"
    resets_at="$(json_field "$five_hour" '.resets_at')"
    [[ -n "$pct" && "$pct" != "null" ]] && add_attr "five_hour_pct" double "$pct"
    unix_resets="$(to_unix_seconds "$resets_at")"
    [[ -n "$unix_resets" ]] && add_attr "five_hour_resets_at" int "$unix_resets"
  fi

  if [[ -n "$seven_day" && "$seven_day" != "null" ]]; then
    local pct resets_at unix_resets
    pct="$(json_field "$seven_day" '.used_percentage')"
    resets_at="$(json_field "$seven_day" '.resets_at')"
    [[ -n "$pct" && "$pct" != "null" ]] && add_attr "seven_day_pct" double "$pct"
    unix_resets="$(to_unix_seconds "$resets_at")"
    [[ -n "$unix_resets" ]] && add_attr "seven_day_resets_at" int "$unix_resets"
  fi

  local plan
  plan="$(json_field "$rate_limits" '.plan')"
  [[ -n "$plan" && "$plan" != "null" ]] && add_attr "plan" string "$plan"
  [[ -n "$version" && "$version" != "null" ]] && add_attr "claude_code.version" string "$version"

  local payload
  payload="$(cat <<PAYLOAD
{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"claude-code"}},{"key":"service.version","value":{"stringValue":"$(json_escape "$plugin_ver")"}}]},"scopeLogs":[{"logRecords":[{"body":{"stringValue":"rimo.rate_limit_snapshot"},"attributes":[${attrs}]}]}]}]}
PAYLOAD
)"

  printf '%s' "$payload" | curl -sf --max-time 3 -X POST \
    "${OTEL_EXPORTER_OTLP_ENDPOINT%/}/v1/logs" \
    -H "Content-Type: application/json" \
    --data-binary @- \
    -o /dev/null 2>/dev/null || true
}

send_snapshot
prune_old_snapshots

exit 0
