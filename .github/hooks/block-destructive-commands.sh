#!/usr/bin/env bash
set -euo pipefail

allow() { printf '{"permissionDecision":"allow"}\n'; exit 0; }
deny()  { printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$1"; exit 0; }

payload="$(cat)"

# Extract tool name and command text from the JSON payload.
# toolArgs may arrive as a nested JSON string or a plain object depending on the caller.
tool_name=""
command_text=""

if command -v jq >/dev/null 2>&1; then
  tool_name="$(echo "$payload" | jq -r '.toolName // .tool_name // ""' 2>/dev/null || true)"
  command_text="$(echo "$payload" | jq -r '
    .tool_input.command //
    .tool_input.cmd //
    (try (
      if (.toolArgs | type) == "string"
      then (.toolArgs | fromjson | (.command // .cmd))
      else (.toolArgs | (.command // .cmd))
      end
    ) catch null) //
    .command //
    .cmd //
    ""
  ' 2>/dev/null || true)"
fi

# If jq is unavailable or no recognized command field was found, fall back to the
# raw payload so the destructive-command check still runs over received input.
[[ -z "$command_text" ]] && command_text="$payload"

# Block destructive commands regardless of tool.
echo "$command_text" | grep -qiE \
  'git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean[[:space:]]+-fd|git[[:space:]]+checkout[[:space:]]+--[[:space:]]|rm[[:space:]]+-rf[[:space:]]/' \
  && deny "Blocked destructive command by repository hook policy."

# Fast-allow read-only commands for known shell tools.
if [[ -z "$tool_name" || "$tool_name" =~ ^(bash|execute_command|run_in_terminal|terminal|shell)$ ]]; then
  echo "$command_text" | grep -qiE \
    '^\s*((cd[[:space:]]+[^;&|]+[[:space:]]*&&[[:space:]]*)?)(pwd|ls|cat|head|tail|wc|grep|rg|find|which|type|command[[:space:]]+-v|git[[:space:]]+(status|diff|log|show|branch))\b' \
    && allow
fi

allow
