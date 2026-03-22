#!/usr/bin/env bash
set -euo pipefail

# Stage 1: Initialization and dependency check
# This script handles dependencies, storage initialization, and watermark setup
# Can be run independently: bash ./stage_1_init.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tracker_config.sh"

# Dependency check
check_dependencies() {
    echo "Checking dependencies..."
    require_cmd git
    require_cmd gh
    require_cmd jq
    require_cmd date
    echo "All dependencies installed"
}

# Storage initialization
init_storage() {
    echo "Initializing storage directories..."
    mkdir -p "$TRACKER_DIR"
    echo "Tracker directory created: $TRACKER_DIR"
}

# Watermark initialization
init_watermark() {
    echo "Initializing watermark..."
    if [ ! -d "$REPO_DIR" ]; then
        echo "ERROR: REPO_DIR does not exist: $REPO_DIR" >&2
        echo "Hint: set REPO_DIR before running, e.g. REPO_DIR=/home/ubuntu/CSLabInfo2025 bash $0" >&2
        exit 1
    fi

    if [ ! -f "$WATERMARK_FILE" ]; then
        date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%SZ" > "$WATERMARK_FILE"
        echo "Watermark file created with initial value: $(cat "$WATERMARK_FILE")"
    else
        echo "Watermark file exists: $(cat "$WATERMARK_FILE")"
    fi
}

# Recovery from malformed watermark
recover_watermark() {
    local LAST_SCAN_TIME="$(cat "$WATERMARK_FILE")"

    if ! LAST_SCAN_EPOCH="$(date -u -d "$LAST_SCAN_TIME" +%s 2>/dev/null)"; then
        echo "Recovering from malformed watermark..."
        LAST_SCAN_TIME="$(date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%SZ")"
        echo "$LAST_SCAN_TIME" > "$WATERMARK_FILE"
        echo "Watermark recovered to: $LAST_SCAN_TIME"
    else
        echo "Watermark is valid"
    fi
}

# Main execution
echo "=== Stage 1: Initialization ==="
check_dependencies
init_storage
init_watermark
recover_watermark
echo "=== Stage 1 completed ==="
