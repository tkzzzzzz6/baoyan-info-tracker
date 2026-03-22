#!/usr/bin/env bash

extract_teacher() {
    local diff_raw="$1"
    echo "$diff_raw" | grep -oP "(?<=# ).*" | head -1
}

extract_email() {
    local diff_raw="$1"
    echo "$diff_raw" | grep -oP "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" | head -1
}

detect_priority_level() {
    local diff_raw="$1"
    if echo "$diff_raw" | grep -Eiq "多模态|LLM|Agent|具身智能|AI4Science|计算医学|医疗影像|大模型安全|系统安全"; then
        echo "高优先级"
    else
        echo "常规"
    fi
}
