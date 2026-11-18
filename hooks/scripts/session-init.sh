#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $(dirname "$0")))}"
CONTEXT_FILE="$PLUGIN_ROOT/context/organization.json"

# Without a saved organization, say nothing. This hook runs at the start of every chat, including chats that
# have nothing to do with Enterpret, and Cowork starts each chat with a fresh copy of the plugin, so the file
# is missing in every Cowork chat. The commands and skills that need it already ask for /start.
if [ ! -f "$CONTEXT_FILE" ]; then
  exit 0
fi

# Try jq first, fall back to grep+sed for portability
if command -v jq &>/dev/null; then
  ORG_NAME=$(jq -r '.name // "Unknown"' "$CONTEXT_FILE" 2>/dev/null || echo "Unknown")
else
  ORG_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONTEXT_FILE" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"$//' || echo "Unknown")
fi
echo "{\"systemMessage\": \"Enterpret Customer Insights plugin loaded. Organization: $ORG_NAME. Context available at context/organization.json.\"}"
