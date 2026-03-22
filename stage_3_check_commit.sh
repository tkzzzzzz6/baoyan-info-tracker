#!/usr/bin/env bash
set -euo pipefail

# Stage 3: Check commit and early exit
# This script checks for recent commits and decides whether to exit early
# Can be run independently: bash ./stage_3_check_commit.sh
# Returns exit code 0 if early exit should happen, 1 otherwise

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tracker_config.sh"
source "$SCRIPT_DIR/stage_6_message.sh"
source "$SCRIPT_DIR/stage_7_audit.sh"

# Get latest commit info
get_commit_info() {
    cd "$REPO_DIR"
    LATEST_COMMIT_TIME="$(git log -1 --date=iso-strict --pretty=format:%cd)"
    LATEST_COMMIT_EPOCH="$(date -u -d "$LATEST_COMMIT_TIME" +%s)"
    NOW_EPOCH="$(date -u +%s)"
    COMMIT_AGE_SEC=$((NOW_EPOCH - LATEST_COMMIT_EPOCH))
}

# Check if early exit condition is met
should_early_exit() {
    [ "$LATEST_COMMIT_EPOCH" -gt "$LAST_SCAN_EPOCH" ] && [ "$COMMIT_AGE_SEC" -le "$COMMIT_EARLY_EXIT_WINDOW_SEC" ]
}

# Get commit details
get_commit_details() {
    cd "$REPO_DIR"
    COMMIT_META="$(git log -1 --pretty=format:"%H%n%s%n%an%n%cd" --date=iso-strict)"
    COMMIT_FILES="$(git show --name-only --pretty=format: HEAD)"
    COMMIT_DIFF_ADDED="$(git show --unified=0 --pretty=format:"" HEAD | grep "^+" | grep -v "^+++" || true)"
}

# Build commit message
build_commit_message() {
    send_message "【保研情报推送】
活动类型：主分支最新提交
信息级别：常规
更新详情：检测到主分支 1 小时内新增提交，已提取关键变动。
来源参考：${TARGET_REPO}
提交信息：
${COMMIT_META}
改动文件：
${COMMIT_FILES}"
}

# Update watermark to latest commit time
update_watermark() {
    echo "$LATEST_COMMIT_TIME" > "$WATERMARK_FILE"
    echo "Watermark updated to: $LATEST_COMMIT_TIME"
}

# Main execution
echo "=== Stage 3: Commit Check ==="

if [ ! -d "$REPO_DIR" ]; then
    echo "ERROR: REPO_DIR does not exist: $REPO_DIR" >&2
    exit 2
fi

read_watermark
get_commit_info

echo "Watermark time: $LAST_SCAN_TIME"
echo "Latest commit time: $LATEST_COMMIT_TIME"
echo "Commit age: $COMMIT_AGE_SEC seconds"

if should_early_exit; then
    echo "Found new commit on main branch."
    echo "Early exit condition met - will process commit and skip PR scan"

    get_commit_details
    printf "%s\n%s\n%s\n" "$COMMIT_META" "$COMMIT_FILES" "$COMMIT_DIFF_ADDED"
    build_commit_message
    update_watermark

    audit_line "扫描PR数: 0 | 候选PR数: 0 | 命中: 0 | 过滤干扰项: 0 | 错误数: 0 | 路径: CommitEarlyExit"

    echo "=== Stage 3 completed (early exit) ==="
    exit 0
else
    echo "No new commit or commit older than early exit window"
    echo "Will proceed to PR scan"
    echo "=== Stage 3 completed ==="
    exit 1
fi
