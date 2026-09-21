#!/usr/bin/env bash
# statusLine wrapper: records rate-limit usage, then hands off to the
# user's own statusline (if configured) or prints a compact fallback line.
#
# IMPORTANT: this runs on every prompt render — it MUST stay fast (well
# under 1s) and MUST always exit 0. A top-level trap guarantees the exit
# code even if something below fails unexpectedly.

trap 'exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=../lib/common.sh
source "${PLUGIN_ROOT}/lib/common.sh"

INPUT="$(cat)"

SESSION_ID="$(json_field "$INPUT" '.session_id')"
VERSION="$(json_field "$INPUT" '.version')"
RATE_LIMITS="$(json_field "$INPUT" '.rate_limits')"

if [[ -n "$SESSION_ID" && -n "$RATE_LIMITS" && "$RATE_LIMITS" != "null" ]]; then
  SNAPSHOT="{\"rate_limits\":${RATE_LIMITS},\"session_id\":\"$(json_escape "$SESSION_ID")\",\"version\":\"$(json_escape "$VERSION")\"}"
  atomic_write "$(latest_snapshot_file "$SESSION_ID")" "$SNAPSHOT" || true
fi

# Passthrough to the user's own statusline, if one was saved.
INNER_CMD="${RIMO_USAGE_INNER_STATUSLINE:-}"
USER_STATUSLINE_FILE="${RIMO_USAGE_DIR}/user-statusline.json"
if [[ -z "$INNER_CMD" && -f "$USER_STATUSLINE_FILE" ]]; then
  INNER_CMD="$(json_field "$(cat "$USER_STATUSLINE_FILE")" '.command')"
fi

if [[ -n "$INNER_CMD" ]]; then
  printf '%s' "$INPUT" | bash -c "$INNER_CMD" 2>/dev/null
  exit 0
fi

# Fallback: compact built-in status line.
MODEL="$(json_field "$INPUT" '.model.display_name')"
CTX_PCT="$(json_field "$INPUT" '.context_window.used_percentage')"
FIVE_HOUR_PCT="$(json_field "$INPUT" '.rate_limits.five_hour.used_percentage')"
SEVEN_DAY_PCT="$(json_field "$INPUT" '.rate_limits.seven_day.used_percentage')"

LINE="${MODEL:-Claude}"
[[ -n "$CTX_PCT" ]] && LINE="${LINE} | ctx ${CTX_PCT}%"
[[ -n "$FIVE_HOUR_PCT" ]] && LINE="${LINE} | 5h ${FIVE_HOUR_PCT}%"
[[ -n "$SEVEN_DAY_PCT" ]] && LINE="${LINE} | 7d ${SEVEN_DAY_PCT}%"

printf '%s\n' "$LINE"
exit 0
