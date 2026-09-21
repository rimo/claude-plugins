#!/usr/bin/env bash
# JSON helpers for the rimo-usage plugin.
#
# Uses the real `jq` binary when available. Otherwise falls back to a
# Node.js one-liner — Claude Code requires Node.js, so it is always present
# even on machines without jq. No python3/perl dependency either way.

# Extract a dotted-path field (e.g. ".rate_limits.five_hour.used_percentage")
# from a JSON string. Prints an empty string if the path is missing, null,
# or the JSON is invalid. Object/array values print as compact JSON text.
json_field() {
  local json="$1"
  local path="$2"
  if command -v jq &>/dev/null; then
    # -r: unquote string results. -c: compact (single-line) object/array results,
    # so behavior matches the Node fallback below regardless of value type.
    printf '%s' "$json" | jq -rc "${path} // empty" 2>/dev/null || true
    return 0
  fi
  if command -v node &>/dev/null; then
    printf '%s' "$json" | node -e '
const fs = require("fs");
const path = process.argv[1];
try {
  const data = JSON.parse(fs.readFileSync(0, "utf8"));
  let cur = data;
  for (const key of path.replace(/^\./, "").split(".").filter(Boolean)) {
    if (cur == null) { cur = undefined; break; }
    cur = cur[key];
  }
  if (cur === undefined || cur === null) process.stdout.write("");
  else if (typeof cur === "object") process.stdout.write(JSON.stringify(cur));
  else process.stdout.write(String(cur));
} catch (e) { process.stdout.write(""); }
' -- "$path" || true
    return 0
  fi
  echo ""
}

# JSON-escape a raw string for embedding as a JSON string value (no surrounding quotes).
json_escape() {
  local str="$1"
  if command -v node &>/dev/null; then
    node -e 'process.stdout.write(JSON.stringify(process.argv[1]).slice(1, -1))' -- "$str"
  elif command -v jq &>/dev/null; then
    printf '%s' "$str" | jq -Rs '.' 2>/dev/null | sed -e 's/^"//' -e 's/"$//'
  else
    printf '%s' "$str" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
  fi
}
