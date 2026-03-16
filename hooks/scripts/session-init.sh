#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $(dirname "$0")))}"
CONTEXT_FILE="$PLUGIN_ROOT/context/organization.json"

if [ -f "$CONTEXT_FILE" ]; then
  ORG_NAME=$(jq -r '.name // "Unknown"' "$CONTEXT_FILE" 2>/dev/null || echo "Unknown")
  echo "{\"systemMessage\": \"Enterpret Customer Insights plugin loaded. Organization: $ORG_NAME. Context available at context/organization.json.\"}"
else
  echo "{\"systemMessage\": \"IMPORTANT: This is the user's first session with the Enterpret Customer Insights plugin. Organization context has not been set up yet. You MUST automatically run the /start onboarding flow before doing anything else. Do not wait for the user to ask — greet them and begin the setup process immediately by loading the onboarding skill and following the /start command instructions. If the user's first message is a question or command, acknowledge it, explain you need to set up first, then run /start.\"}"
fi
