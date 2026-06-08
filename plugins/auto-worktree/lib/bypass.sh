#!/usr/bin/env bash
# Bypass helpers for auto-worktree plugin.
# Manages session-scoped bypass flags that disable worktree enforcement.

# Get a portable temporary directory path.
# Checks TMPDIR (macOS), TMP/TEMP (Windows Git Bash), falls back to /tmp.
get_tmp_dir() {
  echo "${TMPDIR:-${TMP:-${TEMP:-/tmp}}}"
}

# Get the bypass flag file path for a given session.
# Arguments: $1 = session_id
get_bypass_file() {
  local session_id="$1"
  echo "$(get_tmp_dir)/auto-worktree-bypass-${session_id}"
}

# Check if bypass is active for a given session.
# Arguments: $1 = session_id
# Returns: 0 if bypass is active, 1 otherwise.
is_bypass_active() {
  local session_id="$1"
  [[ -n "$session_id" ]] && [[ -f "$(get_bypass_file "$session_id")" ]]
}

# Activate bypass for a given session.
# Arguments: $1 = session_id
set_bypass() {
  local session_id="$1"
  if [[ -n "$session_id" ]]; then
    touch "$(get_bypass_file "$session_id")"
  fi
}

# Deactivate bypass for a given session.
# Arguments: $1 = session_id
clear_bypass() {
  local session_id="$1"
  if [[ -n "$session_id" ]]; then
    rm -f "$(get_bypass_file "$session_id")"
  fi
}
