#!/usr/bin/env bash
set -euo pipefail

# Stage 5: PR processing
# This script processes candidate PRs, extracts information (simplified)
# Can be run independently: bash ./stage_5_process_prs.sh <TSV_input_file>
# Input format: TSV from stage_4_filter_prs.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tracker_config.sh"
source "$SCRIPT_DIR/tracker_extract.sh"
source "$SCRIPT_DIR/stage_6_message.sh"
source "$SCRIPT_DIR/stage_7_audit.sh"

# Stats counters
HIT_C=0
FILTER_Z=0
ERROR_E=0
NOW_EPOCH="$(date -u +%s)"

# Read watermark (from tracker_config.sh)

# Process a single PR
process_pr() {
    local PR_NUM="$1"
    local PR_UPDATED_AT="$2"
    local PR_TITLE="$3"
    local PR_URL="$4"

    echo "Processing PR #${PR_NUM}..."

    # Validate PR_NUM is a positive integer to prevent argument injection
    case "$PR_NUM" in
        ''|*[!0-9]*)
            echo "Error: Invalid PR number (non-numeric): $PR_NUM" >&2
            ERROR_E=$((ERROR_E + 1))
            return 1
            ;;
    esac

    # Check silent window
    PR_UPDATED_EPOCH="$(date -u -d "$PR_UPDATED_AT" +%s)" || {
        echo "Error parsing date for PR #$PR_NUM: $PR_UPDATED_AT"
        ERROR_E=$((ERROR_E + 1))
        return 1
    }

    if [ $((NOW_EPOCH - PR_UPDATED_EPOCH)) -lt "$PR_SILENT_WINDOW_SEC" ]; then
        echo "PR #$PR_NUM is in silent window (skipped)"
        FILTER_Z=$((FILTER_Z + 1))
        return 0
    fi

    # Get PR diff
    DIFF_RAW="$(gh pr diff "$PR_NUM" -R "$TARGET_REPO" | grep "^+" | grep -v "^+++" || true)"

    # Extract information
    TEACHER="$(extract_teacher "$DIFF_RAW")"
    EMAIL="$(extract_email "$DIFF_RAW")"

    # Count hits
    HIT_C=$((HIT_C + 1))

    # Display result
    echo "Result: PR#$PR_NUM | Name: ${TEACHER:-N/A} | Contact: ${EMAIL:-N/A}"

    # Send message (simplified)
    send_message "【保研情报推送】
院校院系：待解析
活动类型：PR 更新
信息级别：常规
更新详情：${PR_TITLE}
官方链接：${PR_URL}
来源参考：GitHub PR #${PR_NUM}
联系人：${EMAIL:-N/A}
老师：${TEACHER:-N/A}"

    # Update watermark if this PR is newer than last scan
    if [ "$PR_UPDATED_EPOCH" -gt "$LAST_SCAN_EPOCH" ]; then
        echo "$PR_UPDATED_AT" > "$WATERMARK_FILE"
        LAST_SCAN_EPOCH="$PR_UPDATED_EPOCH"
        echo "Watermark updated to: $PR_UPDATED_AT"
    fi

    return 0
}

# Main processing loop
process_all_prs() {
    local input_data="$1"
    local CANDIDATE_C=0

    while IFS=$'\t' read -r PR_NUM PR_UPDATED_AT PR_TITLE PR_URL; do
        [ -z "$PR_NUM" ] && continue
        CANDIDATE_C=$((CANDIDATE_C + 1))
        process_pr "$PR_NUM" "$PR_UPDATED_AT" "$PR_TITLE" "$PR_URL" || true
    done <<< "$input_data"

    echo
    echo "Processing summary:"
    echo "  Hits: $HIT_C"
    echo "  Filtered (silent window): $FILTER_Z"
    echo "  Errors: $ERROR_E"
}

# Read input from file or pipe
read_input() {
    if [ -n "${1:-}" ]; then
        if [ -f "$1" ]; then
            echo "Reading from file: $1"
            cat "$1"
        else
            echo "Error: File not found: $1" >&2
            exit 1
        fi
    else
        echo "Reading from standard input"
        cat
    fi
}

# Export stats for audit
export_stats() {
    local SCAN_N="${1:-0}"
    local CANDIDATE_C="${2:-0}"

    echo "SCAN_N=$SCAN_N"
    echo "CANDIDATE_C=$CANDIDATE_C"
    echo "HIT_C=$HIT_C"
    echo "FILTER_Z=$FILTER_Z"
    echo "ERROR_E=$ERROR_E"
}

# Main execution
echo "=== Stage 5: PR Processing ==="
read_watermark

INPUT_DATA="$(read_input "${1:-}")"
if [ -z "$INPUT_DATA" ]; then
    echo "No PRs to process"
    echo "=== Stage 5 completed ==="
    exit 0
fi

# Count candidate lines
CANDIDATE_C="$(echo "$INPUT_DATA" | grep -v '^$' | wc -l | tr -d ' ')"

process_all_prs "$INPUT_DATA"

if [ "${2:-}" = "--export" ]; then
    SCAN_N="${SCAN_N:-0}"
    export_stats "$SCAN_N" "$CANDIDATE_C"
fi

echo "=== Stage 5 completed ==="
