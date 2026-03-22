#!/usr/bin/env bash
set -euo pipefail

# Stage 6: Message dispatch
# This script handles message dispatch logic - supports MESSAGE_SINK_CMD
# Can be run independently: bash ./stage_6_message.sh "message text"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tracker_config.sh"

# Dispatch message to configured sink or stdout
send_message() {
    local msg="$1"
    if [ -n "${MESSAGE_SINK_CMD:-}" ]; then
        echo "Dispatching message via MESSAGE_SINK_CMD..."
        # MESSAGE_SINK_CMD is operator-supplied shell code executed in a non-login
        # subshell.  Do NOT set this variable from untrusted input.
        printf "%s\n" "$msg" | bash -c "$MESSAGE_SINK_CMD"
    else
        echo "[PUSH]"
        printf "%s\n" "$msg"
    fi
}

# Main entry point
if [ $# -eq 0 ]; then
    echo "Usage: $0 \"message_text\""
    echo "Example: $0 \"【保研情报推送】...\""
    exit 1
fi

send_message "$1"
