---
name: dispatch
description: Launch an interactive Claude Code session in another repository. Opens a new tab in Terminal.app or iTerm2, moves to the specified repository, and runs `claude --dangerously-skip-permissions` with an initial prompt. Detects completion of the spawned child session in the background and reports the result automatically. Use for requests like "work on this in another repo", "fix this in rimo-frontend", or "run this plan in another repository".
---

# Dispatch: Launch Claude Code in another repository

A skill that launches an interactive Claude Code session in a new Terminal.app or iTerm2 tab, in a specified repository.
When work needs to happen in another repository (for example during PlanMode), you can hand the plan straight over and dispatch it.

On launch it **issues a session ID up front** and **injects a Stop hook** into the child session, so that when the child finishes its task the parent (this session) detects it automatically and reports the result (no fire-and-forget).

## Arguments

```
/dispatch <repo> "<prompt>"
```

- `<repo>`: repository name or path
  - No `/` → searched as a sibling directory of the same name under the current repository's parent directory
  - Contains `/` → used directly as a path (`~` is expanded)
- `<prompt>`: the initial prompt passed to Claude Code (if omitted, launches with no prompt)

## Examples

```
/dispatch rimo-frontend "Fix the bugs around authentication"
/dispatch rimo-backend "Execute the following plan:\n1. Add an API endpoint\n2. Write tests"
/dispatch ~/src/other-project "Update the README"
```

## Steps

### Step 1: Parse the arguments

Split the skill arguments into a repository specifier and a prompt.
- Everything up to the first space is the repository specifier
- Everything after that is the prompt (quotes are stripped)

### Step 2: Resolve the repository path

```bash
# If the repository specifier does NOT contain /: search the parent directory
REPO_NAME="<the given name>"
PARENT_DIR="$(cd .. && pwd)"
REPO_PATH="${PARENT_DIR}/${REPO_NAME}"

# If it contains /: use it as a path
REPO_PATH="<the given path>"  # ~ is expanded by the shell
```

If the repository path does not exist, report an error to the user and stop.

### Step 3: Prepare the session ID, prompt, and Stop hook settings

Issuing the session ID up front fixes the location of the child session's transcript (`~/.claude/projects/*/<UUID>.jsonl`).
In addition, inject a completion-detection Stop hook via `--settings`. The Stop hook creates a sentinel file at the end of each child turn (the parent watches for it).

```bash
SESSION_ID=$(uuidgen)
mkdir -p /tmp/claude-dispatch
SENTINEL="/tmp/claude-dispatch/${SESSION_ID}.done"

# Write the prompt to a temp file (handles long text and quoting; keeps the prompt body out of the typed command)
PROMPT_FILE=$(mktemp /tmp/claude-dispatch-XXXXXX.txt)
cat > "$PROMPT_FILE" << 'PROMPT_EOF'
<prompt content>
PROMPT_EOF

# Settings file that injects the Stop hook (creates the sentinel at the end of each child turn)
# --settings is merged additively onto existing settings, so the target repo's own hooks are preserved
SETTINGS_FILE=$(mktemp /tmp/claude-dispatch-settings-XXXXXX.json)
cat > "$SETTINGS_FILE" << SETTINGS_EOF
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "mkdir -p /tmp/claude-dispatch && touch '${SENTINEL}'" } ] }
    ]
  }
}
SETTINGS_EOF
```

### Step 4: Detect the terminal and launch Claude Code in a new tab

**Important**: perform the detection and the AppleScript execution in **a single Bash command**. Splitting them apart risks missing the detection result and opening in the wrong terminal.

Run the following script exactly, in a single Bash call (expand the variables `REPO_PATH` / `PROMPT_FILE` / `SETTINGS_FILE` / `SESSION_ID`):

```bash
REPO_PATH="<resolved path>"
PROMPT_FILE="<temp file path>"
SETTINGS_FILE="<settings file path>"
SESSION_ID="<issued UUID>"

# claude itself: fixed session ID + injected Stop hook. Clean up temp files after it runs
CMD="cd '${REPO_PATH}' && claude --dangerously-skip-permissions --session-id '${SESSION_ID}' --settings '${SETTINGS_FILE}' \"\$(cat '${PROMPT_FILE}')\" ; rm -f '${PROMPT_FILE}' '${SETTINGS_FILE}'"

# Prefix a space to exclude the typed command from zsh history (when HIST_IGNORE_SPACE is enabled)
SPACED_CMD=" ${CMD}"

if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
  osascript <<EOF
tell application "iTerm"
    activate
    tell current window
        create tab with default profile
        tell current session of current tab
            write text "${SPACED_CMD}"
        end tell
    end tell
end tell
EOF
else
  osascript <<EOF
tell application "Terminal"
    activate
    tell application "System Events" to keystroke "t" using command down
    delay 0.5
    do script "${SPACED_CMD}" in front window
end tell
EOF
fi
```

**Detection rules**:
- `TERM_PROGRAM` is `iTerm.app` → open in iTerm2
- Otherwise (`Apple_Terminal`, unset, or anything else) → open in Terminal.app
- `TERM_PROGRAM` is set automatically as a shell environment variable. It is accessible from the Bash tool.

**Key points:**
- **Combine detection and execution into a single Bash call** (do not split into two)
- Run `cd` → `claude` as one chained command
- The prompt is read from a temp file and deleted automatically after execution
- If the prompt is empty, run only `claude --dangerously-skip-permissions --session-id '<UUID>' --settings '<settings>'` (no prompt argument)
- The **leading space** keeps the typed command out of history. This only takes effect when `setopt HIST_IGNORE_SPACE` is enabled in the target shell (otherwise it is recorded normally; see "Setup")

### Step 5: Launch the completion watcher in the background

After opening the tab, start a **background watcher in the parent session**. Call the `Bash` tool with `run_in_background: true` and wait for the sentinel file to appear.
When the watcher exits, the harness re-invokes the parent session automatically, at which point you read and report the result.

Content to run via `Bash` (`run_in_background: true`):

```bash
SESSION_ID="<issued UUID>"
REPO_PATH="<resolved path>"
SENTINEL="/tmp/claude-dispatch/${SESSION_ID}.done"

# Wait up to 60 minutes (2s x 1800). The child's turn end triggers the Stop hook, which creates the sentinel
for i in $(seq 1 1800); do
  [ -f "$SENTINEL" ] && break
  sleep 2
done

if [ -f "$SENTINEL" ]; then
  echo "=== dispatch done: ${SESSION_ID} (${REPO_PATH}) ==="
  TRANSCRIPT=$(ls -t ~/.claude/projects/*/"${SESSION_ID}".jsonl 2>/dev/null | head -1)
  if [ -n "$TRANSCRIPT" ]; then
    # Extract the body of the last assistant message that contains text, as material for the summary
    # (the end of each turn may be thinking/tool_use only, so pick the last response that has text)
    jq -rs '[.[] | select(.type=="assistant") | select(.message.content | any(.type=="text"))] | last | .message.content[] | select(.type=="text") | .text' "$TRANSCRIPT" 2>/dev/null \
      | tail -n 60
  fi
  rm -f "$SENTINEL"
else
  echo "=== dispatch timeout (not finished within 60 min): ${SESSION_ID} ==="
fi
```

**After re-invocation**:
- Read the watcher output and **briefly report** to the user what the child session did
- If the user seems to be away (e.g. a long task), you may send a "dispatch done" notice via `PushNotification`
- Constraint: this notification is only delivered **while the parent session is alive**. If the parent is closed, it is not detected (in that case, use "Manual check" below to follow up later)

### Step 6: Report to the user (right after launch)

Tell the user that the session was launched:
- Which repository it launched in
- A summary of the prompt that was passed (just the beginning if long)
- The session ID (a handle for manual follow-up later)
- Add "I'll report automatically once it finishes"

## Manual check (when not using the watcher / if it was missed)

As long as you know the session ID, you can read the transcript at any time:

```bash
SESSION_ID="<UUID>"
TRANSCRIPT=$(ls -t ~/.claude/projects/*/"${SESSION_ID}".jsonl 2>/dev/null | head -1)
# The last assistant response that contains text
jq -rs '[.[] | select(.type=="assistant") | select(.message.content | any(.type=="text"))] | last | .message.content[] | select(.type=="text") | .text' "$TRANSCRIPT"
```

## Setup (to make history suppression effective)

Prefixing a space to keep the new tab's typed command out of history only works when the following is enabled in the target shell. Add to `~/.zshrc`:

```zsh
setopt HIST_IGNORE_SPACE
```

dispatch still works without it, but note that the `claude --session-id ...` line will remain in `~/.zsh_history`.

## Notes

- Assumes macOS + Terminal.app or iTerm2 (auto-detected via the `TERM_PROGRAM` environment variable)
- If the prompt contains single quotes, they must be escaped
- Execution in the new tab is asynchronous. You can check directly in the tab, but the completion watcher picks up the result automatically
- The Stop hook creates a sentinel at the **end of each child turn**. The watcher detects and exits on the first completion
- The `--settings` hooks are **merged additively** onto the target repo's own settings (the target repo's hooks are preserved)
- Sentinels and temp files live in `/tmp/claude-dispatch/`. They are cleared on OS restart
