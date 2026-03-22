#!/usr/bin/env bash
set -euo pipefail

# Tracker workflow orchestration example
# This script shows how to orchestrate the stage scripts in sequence
# This replaces the original monolithic tracker_main.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------- Main orchestration -----------------

echo "=== Starting Baoyan Tracker ==="

# Stage 1: Initialization and dependency check
echo "Stage 1: Initialization"
if ! bash "$SCRIPT_DIR/stage_1_init.sh"; then
    echo "ERROR: Stage 1 failed"
    exit 1
fi

# Stage 2: Repository sync
echo "Stage 2: Repository sync"
if ! bash "$SCRIPT_DIR/stage_2_sync_repo.sh"; then
    echo "ERROR: Stage 2 failed"
    exit 1
fi

# Stage 3: Commit check and early exit
echo "Stage 3: Commit check"
if bash "$SCRIPT_DIR/stage_3_check_commit.sh"; then
    echo "Stage 3: Early exit (new commit detected)"
    exit 0
fi

# Stage 4: PR filtering
echo "Stage 4: PR filtering"
TMP_DIR=$(mktemp -d -t tracker-XXXXXX)
CANDIDATES_FILE="$TMP_DIR/candidates.tsv"

if ! bash "$SCRIPT_DIR/stage_4_filter_prs.sh" > "$CANDIDATES_FILE"; then
    # Check if stage_4 returned 2 (no candidates)
    if [ $? -eq 2 ]; then
        echo "Stage 4: No candidate PRs"
        bash "$SCRIPT_DIR/stage_7_audit.sh" idle
        rm -rf "$TMP_DIR"
        echo "=== Done ==="
        exit 0
    else
        echo "ERROR: Stage 4 failed"
        rm -rf "$TMP_DIR"
        exit 1
    fi
fi

# Stage 5: PR processing
echo "Stage 5: PR processing"
if ! bash "$SCRIPT_DIR/stage_5_process_prs.sh" "$CANDIDATES_FILE" --export > "$TMP_DIR/stats.txt"; then
    echo "ERROR: Stage 5 failed"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Parse stage_5 stats
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$TMP_DIR/stats.txt" ]; then
    # Read stats into variables
    while IFS='=' read -r key value; do
        case "$key" in
            SCAN_N) SCAN_N="$value" ;;
            CANDIDATE_C) CANDIDATE_C="$value" ;;
            HIT_HIGH_X) HIT_HIGH_X="$value" ;;
            HIT_NORMAL_Y) HIT_NORMAL_Y="$value" ;;
            FILTER_Z) FILTER_Z="$value" ;;
            ERROR_E) ERROR_E="$value" ;;
        esac
    done < "$TMP_DIR/stats.txt"

    # Write audit line
    bash "$SCRIPT_DIR/stage_7_audit.sh" stats "$SCAN_N" "$CANDIDATE_C" "$HIT_HIGH_X" "$HIT_NORMAL_Y" "$FILTER_Z" "$ERROR_E"
fi

# Cleanup temporary files
rm -rf "$TMP_DIR"

echo "=== Done ==="
