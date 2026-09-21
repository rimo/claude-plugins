#!/usr/bin/env bash
# SessionStart hook: warns (stdout only, nothing is sent anywhere) when the
# telemetry environment variables that send-snapshot.sh needs are not set.

trap 'exit 0' ERR

if [[ -z "${CLAUDE_CODE_ENABLE_TELEMETRY:-}" || -z "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]]; then
  echo "[rimo-usage] Telemetry is not fully configured — rate-limit snapshots will not be sent. Set CLAUDE_CODE_ENABLE_TELEMETRY and OTEL_EXPORTER_OTLP_ENDPOINT to enable them."
fi

exit 0
