#!/usr/bin/env bash
set -euo pipefail

# Locate sibling config and helper scripts regardless of current working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tracker_config.sh"
source "$SCRIPT_DIR/tracker_extract.sh"

# Fail fast if required CLI tools are missing.
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: missing required command: $cmd" >&2
        exit 1
    fi
}

# Append one standardized line to the audit log.
audit_line() {
    local line="$1"
    printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$line" >> "$AUDIT_LOG"
}

# Message sink hook: use MESSAGE_SINK_CMD when configured, otherwise print locally.
send_message() {
    local msg="$1"
    if [ -n "${MESSAGE_SINK_CMD:-}" ]; then
        printf "%s\n" "$msg" | bash -lc "$MESSAGE_SINK_CMD"
    else
        echo "[PUSH]"
        printf "%s\n" "$msg"
    fi
}

require_cmd git
require_cmd gh
require_cmd jq
require_cmd date

# Ensure tracker storage path exists for watermark and audit output.
mkdir -p "$TRACKER_DIR"

if [ ! -d "$REPO_DIR" ]; then
    echo "ERROR: REPO_DIR does not exist: $REPO_DIR" >&2
    echo "Hint: set REPO_DIR before running, e.g. REPO_DIR=/home/ubuntu/CSLabInfo2025 bash ./baoyan-tracker/scripts/tracker_main.sh" >&2
    exit 1
fi

if [ ! -f "$WATERMARK_FILE" ]; then
    date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%SZ" > "$WATERMARK_FILE"
fi

LAST_SCAN_TIME="$(cat "$WATERMARK_FILE")"
# Recover from malformed watermark by resetting to a safe baseline.
if ! LAST_SCAN_EPOCH="$(date -u -d "$LAST_SCAN_TIME" +%s 2>/dev/null)"; then
    LAST_SCAN_TIME="$(date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%SZ")"
    LAST_SCAN_EPOCH="$(date -u -d "$LAST_SCAN_TIME" +%s)"
    echo "$LAST_SCAN_TIME" > "$WATERMARK_FILE"
fi
NOW_EPOCH="$(date -u +%s)"

# Pull latest repo state before any commit/PR judgment.
cd "$REPO_DIR"
git pull --ff-only

LATEST_COMMIT_TIME="$(git log -1 --date=iso-strict --pretty=format:%cd)"
LATEST_COMMIT_EPOCH="$(date -u -d "$LATEST_COMMIT_TIME" +%s)"
COMMIT_AGE_SEC=$((NOW_EPOCH - LATEST_COMMIT_EPOCH))

SCAN_N=0
CANDIDATE_C=0
HIT_HIGH_X=0
HIT_NORMAL_Y=0
FILTER_Z=0
ERROR_E=0

# Early-exit path: if a fresh main-branch commit is detected, push commit summary only.
if [ "$LATEST_COMMIT_EPOCH" -gt "$LAST_SCAN_EPOCH" ] && [ "$COMMIT_AGE_SEC" -le "$COMMIT_EARLY_EXIT_WINDOW_SEC" ]; then
    echo "Found new commit on main branch."
    COMMIT_META="$(git log -1 --pretty=format:"%H%n%s%n%an%n%cd" --date=iso-strict)"
    COMMIT_FILES="$(git show --name-only --pretty=format: HEAD)"
    COMMIT_DIFF_ADDED="$(git show --unified=0 --pretty=format:"" HEAD | grep "^+" | grep -v "^+++" || true)"

    printf "%s\n%s\n%s\n" "$COMMIT_META" "$COMMIT_FILES" "$COMMIT_DIFF_ADDED"

    send_message "【保研情报推送】
活动类型：主分支最新提交
信息级别：常规
更新详情：检测到主分支 1 小时内新增提交，已提取关键变动。
来源参考：${TARGET_REPO}
提交信息：
${COMMIT_META}
改动文件：
${COMMIT_FILES}"

    echo "$LATEST_COMMIT_TIME" > "$WATERMARK_FILE"
    audit_line "扫描PR数: 0 | 候选PR数: 0 | 命中高优先级: 0 | 命中常规: 0 | 过滤干扰项: 0 | 错误数: 0 | 路径: CommitEarlyExit"
    exit 0
fi

# Fetch once, then filter in jq to avoid repeated API list calls.
PR_ROWS="$(gh pr list -R "$TARGET_REPO" --limit "$PR_LIMIT" --state all --json number,updatedAt,state,title,body,url)"
SCAN_N="$(echo "$PR_ROWS" | jq 'length')"

PR_CANDIDATES="$(echo "$PR_ROWS" | jq -r --arg last "$LAST_SCAN_TIME" '
    .[]
    | select(.updatedAt > $last)
    | select(.state == "OPEN" or .state == "MERGED")
    | [.number, .updatedAt, .title, .url]
    | @tsv')"

if [ -z "$PR_CANDIDATES" ]; then
    audit_line "Status: Idle (No relevant updates)."
    exit 0
fi

# Iterate tab-separated candidate rows: number, updatedAt, title, url.
while IFS=$'\t' read -r PR_NUM PR_UPDATED_AT PR_TITLE PR_URL; do
    [ -z "$PR_NUM" ] && continue
    CANDIDATE_C=$((CANDIDATE_C + 1))

    PR_UPDATED_EPOCH="$(date -u -d "$PR_UPDATED_AT" +%s)" || {
        ERROR_E=$((ERROR_E + 1))
        continue
    }

    # Keep a silence window for very recent PR updates to reduce noisy duplicates.
    if [ $((NOW_EPOCH - PR_UPDATED_EPOCH)) -lt "$PR_SILENT_WINDOW_SEC" ]; then
        FILTER_Z=$((FILTER_Z + 1))
        continue
    fi

    DIFF_RAW="$(gh pr diff "$PR_NUM" -R "$TARGET_REPO" | grep "^+" | grep -v "^+++" || true)"
    TEACHER="$(extract_teacher "$DIFF_RAW")"
    EMAIL="$(extract_email "$DIFF_RAW")"
    LEVEL="$(detect_priority_level "$DIFF_RAW")"

    if [ "$LEVEL" = "高优先级" ]; then
        HIT_HIGH_X=$((HIT_HIGH_X + 1))
    else
        HIT_NORMAL_Y=$((HIT_NORMAL_Y + 1))
    fi

    echo "Result: PR#$PR_NUM | Level: $LEVEL | Name: ${TEACHER:-N/A} | Contact: ${EMAIL:-N/A}"
    send_message "【保研情报推送】
院校院系：待解析
活动类型：PR 更新
信息级别：$LEVEL
更新详情：${PR_TITLE}
官方链接：${PR_URL}
来源参考：GitHub PR #${PR_NUM}
联系人：${EMAIL:-N/A}
老师：${TEACHER:-N/A}"

    # Move watermark forward only when processing newer items.
    if [ "$PR_UPDATED_EPOCH" -gt "$LAST_SCAN_EPOCH" ]; then
        echo "$PR_UPDATED_AT" > "$WATERMARK_FILE"
        LAST_SCAN_EPOCH="$PR_UPDATED_EPOCH"
    fi
done <<< "$PR_CANDIDATES"

# Final aggregate audit line for this run.
audit_line "扫描PR数: $SCAN_N | 候选PR数: $CANDIDATE_C | 命中高优先级: $HIT_HIGH_X | 命中常规: $HIT_NORMAL_Y | 过滤干扰项: $FILTER_Z | 错误数: $ERROR_E"
