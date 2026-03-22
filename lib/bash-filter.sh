#!/usr/bin/env bash
# Heuristic to detect whether a Bash command is file-modifying (mutating).
# Used to decide whether the PreToolUse hook should intercept a Bash tool call.

# Check if a command is likely to modify files.
# Arguments: $1 = command string
# Returns: 0 if mutating, 1 if read-only.
is_mutating_command() {
  local cmd="$1"

  # Strip leading whitespace
  cmd="$(echo "$cmd" | sed 's/^[[:space:]]*//')"

  # Check for output redirects (but not /dev/null or stderr-only redirects)
  # Remove /dev/null redirects and stderr redirects before checking
  local sanitized
  sanitized="$(echo "$cmd" | sed -E 's/[0-9]*>[[:space:]]*\/dev\/null//g; s/[0-9]*>&[0-9]+//g')"
  if echo "$sanitized" | perl -ne 'BEGIN{$f=1} $f=0 if /(?<![0-9&])\s*>{1,2}\s/; END{exit $f}'; then
    return 0
  fi

  # List of commands/patterns that typically modify files or system state
  local -a mutating_patterns=(
    '\btee\b'
    '\bsed\s+-i'
    '\bperl\s+-i'
    '\bmv\b'
    '\bcp\b'
    '\brm\b'
    '\bmkdir\b'
    '\btouch\b'
    '\bchmod\b'
    '\bchown\b'
    '\bln\b'
    '\binstall\b'
    '\bpatch\b'
    '\btruncate\b'
    '\bgit\s+checkout\b'
    '\bgit\s+reset\b'
    '\bgit\s+merge\b'
    '\bgit\s+rebase\b'
    '\bgit\s+stash\b'
    '\bnpm\s+install\b'
    '\bnpm\s+i\b'
    '\bnpm\s+ci\b'
    '\bnpm\s+uninstall\b'
    '\byarn\s+add\b'
    '\byarn\s+install\b'
    '\byarn\s+remove\b'
    '\bpip\s+install\b'
    '\bpip3\s+install\b'
    '\bapt\b'
    '\bapt-get\b'
    '\bbrew\b'
    '\bcargo\s+install\b'
    '\bgo\s+install\b'
  )

  for pattern in "${mutating_patterns[@]}"; do
    if echo "$cmd" | perl -ne 'BEGIN{$f=1} $f=0 if /'"$pattern"'/; END{exit $f}'; then
      return 0
    fi
  done

  # Default: treat as read-only
  return 1
}
