#!/usr/bin/env bash
set -euo pipefail

# Stage 7: Audit log
# This script handles audit logging for tracking runs
# Can be run independently: bash ./stage_7_audit.sh "log message"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tracker_config.sh"

# Append one standardized line to the audit log
audit_line() {
    local line="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_line="[$timestamp] $line"

    mkdir -p "$TRACKER_DIR"
    printf "%s\n" "$log_line" >> "$AUDIT_LOG"
    echo "$log_line"
}

# Write scan statistics (main PR processing case)
write_scan_stats() {
    local scan_n="${1:-0}"
    local candidate_c="${2:-0}"
    local hit_c="${3:-0}"
    local filter_z="${4:-0}"
    local error_e="${5:-0}"
    local path="${6:-}"

    local stats_line="扫描PR数: $scan_n | 候选PR数: $candidate_c | 命中: $hit_c | 过滤干扰项: $filter_z | 错误数: $error_e"

    if [ -n "$path" ]; then
        stats_line="$stats_line | 路径: $path"
    fi

    audit_line "$stats_line"
}

# Write idle log line
write_idle() {
    audit_line "Status: Idle (No relevant updates)."
}

# Display audit log tail
show_recent() {
    local lines="${1:-10}"
    echo "Recent $lines audit entries:"
    if [ -f "$AUDIT_LOG" ]; then
        tail -n "$lines" "$AUDIT_LOG"
    else
        echo "No audit log exists yet"
    fi
}

# Main entry point
if [ $# -eq 0 ]; then
    echo "Usage: $0 [command] [arguments]"
    echo "Commands:"
    echo "  log <message>          Write a custom log line"
    echo "  stats <scan> <candidate> <hit> <filter> <error> [path]"
    echo "  idle                   Write idle status"
    echo "  show [lines]           Show recent entries (default: 10)"
    echo
    echo "Examples:"
    echo '  $0 log "Script started"'
    echo "  $0 stats 50 5 5 0 0"
    echo "  $0 stats 0 0 0 0 0 CommitEarlyExit"
    echo "  $0 idle"
    echo "  $0 show 20"
    exit 1
fi

case "$1" in
    log)
        shift
        audit_line "$*"
        ;;
    stats)
        if [ $# -lt 5 ]; then
            echo "Usage: $0 stats <scan> <candidate> <hit> <filter> <error> [path]" >&2
            exit 1
        fi
        write_scan_stats "$2" "$3" "$4" "$5" "$6" "${7:-}"
        ;;
    idle)
        write_idle
        ;;
    show)
        shift
        show_recent "${1:-10}"
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Use '$0' without arguments for help" >&2
        exit 1
        ;;
esac
