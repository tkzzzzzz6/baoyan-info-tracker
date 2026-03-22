#!/usr/bin/env bash
# shellcheck disable=SC2034

# Configurations for tracker workflow
# Priority: environment variable > default value
# BASE_DIR defaults to parent of scripts directory (e.g. ./baoyan-tracker)
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
BASE_DIR="${BASE_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# Repo path can be overridden when running script:
# REPO_DIR=/home/ubuntu/CSLabInfo2025 bash ./baoyan-tracker/scripts/tracker_main.sh
REPO_DIR="${REPO_DIR:-/home/ubuntu/CSLabInfo2025}"

# Tracker data path defaults under BASE_DIR
TRACKER_DIR="${TRACKER_DIR:-${BASE_DIR}/data/tracker}"
WATERMARK_FILE="${WATERMARK_FILE:-${TRACKER_DIR}/last_scan_time.txt}"
AUDIT_LOG="${AUDIT_LOG:-${TRACKER_DIR}/llog}"

# Time window settings (seconds)
COMMIT_EARLY_EXIT_WINDOW_SEC=3600
PR_SILENT_WINDOW_SEC=3600

# PR fetch settings
TARGET_REPO="${TARGET_REPO:-CS-BAOYAN/CSLabInfo2025}"
PR_LIMIT="${PR_LIMIT:-50}"
# Validate PR_LIMIT is a positive integer to prevent argument injection
case "$PR_LIMIT" in
    ''|*[!0-9]*) echo "ERROR: PR_LIMIT must be a positive integer, got: $PR_LIMIT" >&2; exit 1 ;;
esac

# ----------------- Shared utility functions -----------------

# Dependency check (used by stage_1_init.sh)
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: missing required command: $cmd" >&2
        exit 1
    fi
}

# Create directory if not exists
mkdir_p() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" >/dev/null 2>&1 || {
            echo "ERROR: Failed to create directory: $dir" >&2
            exit 1
        }
    fi
}

# Print debug information (only if DEBUG=true)
debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "DEBUG: $*" >&2
    fi
}

# Read and validate watermark file
read_watermark() {
    if [ ! -f "$WATERMARK_FILE" ]; then
        echo "ERROR: Watermark file not found: $WATERMARK_FILE" >&2
        exit 1
    fi
    LAST_SCAN_TIME="$(cat "$WATERMARK_FILE")"
    LAST_SCAN_EPOCH="$(date -u -d "$LAST_SCAN_TIME" +%s 2>/dev/null || echo 0)"
}

# Get absolute path from relative
abs_path() {
    local path="$1"
    if [ -z "$path" ]; then
        echo ""
        return 0
    fi
    if [ "${path:0:1}" = "/" ]; then
        echo "$path"
    else
        echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi
}
