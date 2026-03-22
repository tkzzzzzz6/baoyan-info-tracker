#!/usr/bin/env bash
set -euo pipefail

# Stage 4: PR filtering
# This script fetches PRs and filters candidates based on time and state
# Can be run independently: bash ./stage_4_filter_prs.sh
# Outputs candidate PRs as TSV to stdout

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tracker_config.sh"

# Read watermark (from tracker_config.sh)

# Fetch PR list from GitHub
fetch_prs() {
    echo "Fetching PR list from $TARGET_REPO (limit: $PR_LIMIT)..." >&2
    PR_ROWS="$(gh pr list -R "$TARGET_REPO" --limit "$PR_LIMIT" --state all --json number,updatedAt,state,title,body,url)"
    SCAN_N="$(echo "$PR_ROWS" | jq 'length')"
    echo "Fetched $SCAN_N PRs" >&2
}

# Filter candidate PRs by time and state
filter_candidates() {
    echo "Filtering PRs updated after: $LAST_SCAN_TIME" >&2
    PR_CANDIDATES="$(echo "$PR_ROWS" | jq -r --arg last "$LAST_SCAN_TIME" '
        .[]
        | select(.updatedAt > $last)
        | select(.state == "OPEN" or .state == "MERGED")
        | [.number, .updatedAt, .title, .url]
        | @tsv')"

    CANDIDATE_C="$(echo "$PR_CANDIDATES" | grep -v '^$' | wc -l | tr -d ' ' || echo 0)"
    echo "Found $CANDIDATE_C candidate PR(s)" >&2
}

# Output results
output_results() {
    if [ -z "$PR_CANDIDATES" ]; then
        echo "No candidate PRs found" >&2
        exit 2
    fi

    echo "=== Candidate PRs ===" >&2
    echo "$PR_CANDIDATES" | while IFS=$'\t' read -r PR_NUM PR_UPDATED_AT PR_TITLE PR_URL; do
        [ -z "$PR_NUM" ] && continue
        echo "PR #$PR_NUM: $PR_TITLE" >&2
        echo "  Updated at: $PR_UPDATED_AT" >&2
        echo "  URL: $PR_URL" >&2
    done
    echo "=== End candidate PRs ===" >&2

    # Output TSV for downstream processing
    echo "$PR_CANDIDATES"
}

# Main execution
echo "=== Stage 4: PR Filtering ==="

if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh (GitHub CLI) not installed" >&2
    exit 1
fi

read_watermark
fetch_prs
filter_candidates

# Export SCAN_N and CANDIDATE_C for audit
if [ "${1:-}" = "--export" ]; then
    echo "SCAN_N=$SCAN_N"
    echo "CANDIDATE_C=$CANDIDATE_C"
fi

output_results

echo "=== Stage 4 completed ==="
