# rimo-usage

Tracks Claude Code rate-limit usage from the statusline and reports periodic
snapshots to Rimo's OTLP collector, without breaking your existing statusline.

## What it does

- **statusLine wrapper** — reads the statusline JSON Claude Code feeds it on
  every render. When `rate_limits` is present, it atomically saves the
  latest snapshot to `~/.claude/rimo-usage/latest-<session_id>.json`, then
  hands off to your own statusline command (if you've configured one) or
  prints a compact fallback line (model, context %, 5h %, 7d %). Always
  exits 0 in well under a second.
- **Stop / SessionEnd hooks** — send one OTLP `/v1/logs` record built from
  the session's latest snapshot to `$OTEL_EXPORTER_OTLP_ENDPOINT`, then
  prune snapshot files older than a day. Failures are silent — a network
  hiccup here never interrupts your session.
- **SessionStart hooks** — (1) print a one-line warning if
  `CLAUDE_CODE_ENABLE_TELEMETRY` or `OTEL_EXPORTER_OTLP_ENDPOINT` is not
  set (nothing is sent); (2) point `statusLine` in `~/.claude/settings.json`
  at the wrapper above. Plugins cannot declare a statusline in
  `plugin.json`, so this is how the wrapper gets activated. The change
  takes effect from the next session.

All hooks trap errors and always exit 0 — this plugin never fails a Claude
Code session.

## Keeping your own statusline

If `settings.json` already had a `statusLine` command when the plugin first
ran, it is saved to `~/.claude/rimo-usage/user-statusline.json` and the
wrapper keeps running it, feeding it the same JSON Claude Code gave the
wrapper. To change the inner command later, edit that file or set
`RIMO_USAGE_INNER_STATUSLINE`. To stop using the wrapper, uninstall the
plugin and put your own `statusLine` back in `settings.json`.

## Rate-limit snapshot contract

Each `rimo.rate_limit_snapshot` OTLP log record sent by the Stop /
SessionEnd hooks looks like:

| Field | Where | Notes |
| :--- | :--- | :--- |
| `event.name` | body + attribute | always `"rimo.rate_limit_snapshot"` |
| `resource.service.name` | resource attribute | always `"claude-code"` |
| `resource.service.version` | resource attribute | this plugin's version |
| `tool` | record attribute | always `"claude_code"` |
| `user.email` | record attribute | from `~/.claude.json` oauth account, else `git config user.email` |
| `session.id` | record attribute | the Claude Code session id |
| `five_hour_pct` | record attribute | omitted if the 5h window is absent |
| `seven_day_pct` | record attribute | omitted if the 7d window is absent |
| `five_hour_resets_at` | record attribute | unix seconds; omitted if absent |
| `seven_day_resets_at` | record attribute | unix seconds; omitted if absent |
| `plan` | record attribute | optional |
| `claude_code.version` | record attribute | optional |

A window's attributes are omitted entirely when that window isn't present
in the statusline data — a `0` is never sent as a stand-in for "unknown".

## Requirements

- `curl`, `git`, and either `jq` or Node.js (Claude Code requires Node.js,
  so it's always available as a fallback).
- Rate-limit percentages are only available for `claude.ai` Pro/Max logins,
  and only after the first API response in a session.

## Development

```
claude --plugin-dir ./plugins/rimo-usage
bash plugins/rimo-usage/tests/run-tests.sh
```
