#!/usr/bin/env bash
# SessionStart hook: warns the user when the plugin cannot do its job —
# telemetry env vars unset (snapshots would not be sent) or no JSON tool on
# PATH. Plain stdout on SessionStart goes into Claude's context, not to the
# user, so the warning is returned as hook JSON `systemMessage`. Nothing is
# sent anywhere.

trap 'exit 0' ERR

MESSAGE=""

if [[ -z "${CLAUDE_CODE_ENABLE_TELEMETRY:-}" || -z "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]]; then
  MESSAGE="[rimo-usage] Telemetry is not configured, so rate-limit snapshots will not be sent. Run the setup script (curl -fsSL https://rimo.github.io/claude-otel-gcp/setup-rimo-usage.sh | bash) or set CLAUDE_CODE_ENABLE_TELEMETRY and OTEL_EXPORTER_OTLP_ENDPOINT."
fi

if ! command -v jq >/dev/null 2>&1 && ! command -v node >/dev/null 2>&1; then
  [[ -n "$MESSAGE" ]] && MESSAGE="${MESSAGE} "
  MESSAGE="${MESSAGE}[rimo-usage] Neither jq nor node is on PATH, so rate-limit usage cannot be read. Install jq (brew install jq) or Node.js."
elif ! command -v node >/dev/null 2>&1; then
  [[ -n "$MESSAGE" ]] && MESSAGE="${MESSAGE} "
  MESSAGE="${MESSAGE}[rimo-usage] node is not on PATH, so the statusline wrapper cannot be installed into settings.json. Install Node.js or add the statusLine entry by hand (see the plugin README)."
fi

if [[ -n "$MESSAGE" ]]; then
  printf '{"systemMessage":"%s"}\n' "$MESSAGE"
fi

exit 0
