#!/usr/bin/env bash
set -euo pipefail

# Stage 2: Repository sync
# This script pulls the latest state of the target repository
# Can be run independently: bash ./stage_2_sync_repo.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tracker_config.sh"

# Validate REPO_DIR
validate_repo() {
    if [ ! -d "$REPO_DIR" ]; then
        echo "ERROR: REPO_DIR does not exist: $REPO_DIR" >&2
        echo "Hint: set REPO_DIR before running, e.g. REPO_DIR=/home/ubuntu/CSLabInfo2025 bash $0" >&2
        exit 1
    fi

    if [ ! -d "$REPO_DIR/.git" ]; then
        echo "ERROR: REPO_DIR is not a git repository: $REPO_DIR" >&2
        exit 1
    fi
}

# Pull latest main branch
sync_repo() {
    echo "Syncing repository..."
    cd "$REPO_DIR"

    echo "Current branch: $(git rev-parse --abbrev-ref HEAD)"
    echo "Pulling latest changes..."
    git pull --ff-only

    local COMMIT_HASH="$(git rev-parse HEAD)"
    local COMMIT_TIME="$(git log -1 --date=iso-strict --pretty=format:%cd)"
    local COMMIT_MSG="$(git log -1 --pretty=format:%s)"

    echo "Latest commit:"
    echo "  Hash: $COMMIT_HASH"
    echo "  Time: $COMMIT_TIME"
    echo "  Msg:  $COMMIT_MSG"
}

# Export latest commit info for downstream use
export_commit_info() {
    cd "$REPO_DIR"

    LATEST_COMMIT_TIME="$(git log -1 --date=iso-strict --pretty=format:%cd)"
    LATEST_COMMIT_HASH="$(git rev-parse HEAD)"
    NOW_EPOCH="$(date -u +%s)"
    LATEST_COMMIT_EPOCH="$(date -u -d "$LATEST_COMMIT_TIME" +%s)"
    COMMIT_AGE_SEC=$((NOW_EPOCH - LATEST_COMMIT_EPOCH))

    echo "LATEST_COMMIT_TIME=$LATEST_COMMIT_TIME"
    echo "LATEST_COMMIT_HASH=$LATEST_COMMIT_HASH"
    echo "LATEST_COMMIT_EPOCH=$LATEST_COMMIT_EPOCH"
    echo "COMMIT_AGE_SEC=$COMMIT_AGE_SEC"
}

# Main execution
echo "=== Stage 2: Repository Sync ==="
validate_repo
sync_repo

if [ "${1:-}" = "--export" ]; then
    export_commit_info
fi

echo "=== Stage 2 completed ==="
