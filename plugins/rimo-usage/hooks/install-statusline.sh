#!/usr/bin/env bash
# SessionStart hook: points the user's statusLine at this plugin's wrapper.
# Plugins cannot declare a statusLine in plugin.json, so the setting has to
# live in the user's settings.json. Any pre-existing statusline command is
# saved once so the wrapper can keep running it. Idempotent; always exits 0.

trap 'exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=../lib/common.sh
source "${PLUGIN_ROOT}/lib/common.sh"

command -v node >/dev/null 2>&1 || exit 0

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
SETTINGS="${CONFIG_DIR}/settings.json"
WRAPPER="${PLUGIN_ROOT}/hooks/statusline.sh"
USER_STATUSLINE_FILE="${RIMO_USAGE_DIR}/user-statusline.json"

mkdir -p "$CONFIG_DIR" "$RIMO_USAGE_DIR" 2>/dev/null || exit 0

node - "$SETTINGS" "$WRAPPER" "$USER_STATUSLINE_FILE" <<'EOF'
const fs = require("fs");
const [settingsPath, wrapper, userFile] = process.argv.slice(2);
const wrapperCmd = `bash "${wrapper}"`;
let settings = {};
if (fs.existsSync(settingsPath)) {
  try { settings = JSON.parse(fs.readFileSync(settingsPath, "utf8")); } catch (e) { process.exit(0); }
}
const current = settings.statusLine;
const isOurs = current && typeof current.command === "string" && /rimo-usage\/hooks\/statusline\.sh/.test(current.command);
if (current && current.command && !isOurs && !fs.existsSync(userFile)) {
  fs.writeFileSync(userFile, JSON.stringify({ command: current.command }) + "\n");
}
if (isOurs && current.command === wrapperCmd) process.exit(0);
settings.statusLine = { type: "command", command: wrapperCmd };
const tmp = settingsPath + ".rimo-usage.tmp";
fs.writeFileSync(tmp, JSON.stringify(settings, null, 2) + "\n");
fs.renameSync(tmp, settingsPath);
EOF

exit 0
