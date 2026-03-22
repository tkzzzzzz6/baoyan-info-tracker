#!/usr/bin/env bash

# Configurations for tracker workflow
# Priority: environment variable > default value
# BASE_DIR defaults to parent of scripts directory (e.g. ./baoyan-tracker)
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
