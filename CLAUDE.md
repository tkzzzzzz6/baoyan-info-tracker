```
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
```

## 项目概述

这是一个 **保研信息自动跟踪系统**，用于定时监控 GitHub 仓库 `CS-BAOYAN/CSLabInfo2025` 的更新，筛选出与计算机、生物医学工程、电子信息专业相关的保研招生和实习信息，并通过消息推送机制发送给用户。

## 代码架构与核心组件

### 简化版架构（推荐）
```
┌──────────────────────────────────────────────────┐
│            tracker_simple.sh                     │
│  ┌────────────────────────────────────────────┐ │
│  │ 核心功能：时间过滤 + 直接推送                │ │
│  ├────────────────────────────────────────────┤ │
│  │ - 依赖检查、初始化                           │ │
│  │ - 仓库同步、commit 早退判断                  │ │
│  │ - PR 拉取、时间过滤（水位线 + 静默窗口）     │ │
│  │ - 消息推送（完整 PR 信息）                   │ │
│  │ - 审计日志                                   │ │
│  └────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────┐
│ tracker_config.sh│
└──────────────────┘
```

### 原版架构（7阶段）
```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ tracker_config.sh│     │ tracker_extract.sh│     │ 阶段脚本         │
└──────────────────┘     └──────────────────┘     └──────────────────┘
          │                       │                       │
          ├───────────────────────┼───────────────────────┤
          │                       │                       │
          ▼                       ▼                       ▼
┌──────────────────────────────────────────────────────────────┐
│                      保研信息跟踪工作流                        │
└──────────────────────────────────────────────────────────────┘
          │                       │                       │
          ▼                       ▼                       ▼
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   配置管理模块    │     │   信息提取模块    │     │   调度控制模块    │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

### 2. 核心文件说明

#### 共享模块
| 文件名 | 功能 | 主要内容 |
|-------|------|----------|
| `tracker_config.sh` | 配置管理 | 路径配置、时间窗口设置、目标仓库、PR拉取上限，含共享工具函数 |
| `tracker_extract.sh` | 信息提取 | 老师姓名、邮箱、优先级判断的字段提取函数 |

#### 阶段脚本（按执行顺序）
| 文件名 | 功能 | 主要内容 |
|-------|------|----------|
| `stage_1_init.sh` | 阶段1 | 初始化与依赖检查、水位线初始化 |
| `stage_2_sync_repo.sh` | 阶段2 | 仓库同步（拉取最新状态） |
| `stage_3_check_commit.sh` | 阶段3 | Commit检查与早退判断 |
| `stage_4_filter_prs.sh` | 阶段4 | PR筛选（获取并筛选候选PR） |
| `stage_5_process_prs.sh` | 阶段5 | PR处理（提取信息、判断优先级） |
| `stage_6_message.sh` | 阶段6 | 消息推送 |
| `stage_7_audit.sh` | 阶段7 | 审计日志 |

#### 调度脚本
| 文件名 | 功能 | 主要内容 |
|-------|------|----------|
| `tracker_simple.sh` | **简化版（推荐）** | 单文件脚本，时间过滤+直接推送 |
| `tracker_main.sh` | 7阶段调度 | 组合所有阶段的执行流程 |

## 执行流程

### 简化版（推荐）
```bash
# 单文件执行（不需要阶段划分）
bash ./tracker_simple.sh

# 环境变量覆盖
REPO_DIR=/path/to/repo \
TRACKER_DIR=/path/to/tracker \
MESSAGE_SINK_CMD="your-push-command" \
bash ./tracker_simple.sh
```

### 原版（7阶段）
```bash
bash ./tracker_main.sh
```

### 阶段独立运行流程

#### 阶段1：初始化与依赖检查
```bash
# 检查依赖、创建存储目录、初始化水位线
bash ./stage_1_init.sh

# 环境变量覆盖
REPO_DIR=/path/to/repo bash ./stage_1_init.sh
```

#### 阶段2：仓库同步
```bash
# 拉取仓库最新状态
bash ./stage_2_sync_repo.sh

# 导出commit信息供下游使用
bash ./stage_2_sync_repo.sh --export
```

#### 阶段3：Commit检查与早退
```bash
# 检查最新commit，判断是否需要早退
# 返回0：应该早退，1：继续执行
bash ./stage_3_check_commit.sh
```

#### 阶段4：PR筛选
```bash
# 筛选候选PR，输出TSV格式
bash ./stage_4_filter_prs.sh

# 保存到文件
bash ./stage_4_filter_prs.sh > candidates.tsv

# 导出统计数据
bash ./stage_4_filter_prs.sh --export
```

#### 阶段5：PR处理
```bash
# 从文件读取并处理PR
bash ./stage_5_process_prs.sh candidates.tsv

# 从管道读取
cat candidates.tsv | bash ./stage_5_process_prs.sh
```

#### 阶段6：消息推送
```bash
# 发送消息
bash ./stage_6_message.sh "【保研情报推送】...消息内容..."

# 使用自定义sink
MESSAGE_SINK_CMD="your-push-command" bash ./stage_6_message.sh "msg"
```

#### 阶段7：审计日志
```bash
# 写入自定义日志
bash ./stage_7_audit.sh log "脚本已启动"

# 写入扫描统计
bash ./stage_7_audit.sh stats 50 5 2 3 0 0

# 写入idle状态
bash ./stage_7_audit.sh idle

# 查看最近日志
bash ./stage_7_audit.sh show 20
```

## 关键功能与设计理念

### 设计理念（简化版）

根据仓库 `CS-BAOYAN/CSLabInfo2025` 的特点，我们提供了两个版本：

1. **简化版**（推荐）：`tracker_simple.sh`
   - 仓库内容已经过审核和精炼
   - 文件名自带结构化信息（年份、学校、老师、招生类型）
   - 不需要复杂的优先级判定和内容提取
   - 只做时间过滤，直接推送所有新信息

2. **原版**：7阶段脚本，带优先级判定和内容提取

### 1. 时间窗口机制（两个版本都保留）

- **Commit早退窗口**：1小时（3600秒）- 若最新commit在1小时内，直接推送摘要并结束流程
- **PR静默窗口**：1小时（3600秒）- PR更新后1小时内不推送，避免重复推送
- **水位线机制**：记录上次扫描时间，实现增量扫描

### 2. 优先级判定（仅原版）

- **高优先级**：涉及前沿交叉学科或主流AI方向
  - 关键词：多模态、LLM/Agent、具身智能、AI4Science、计算医学、医疗影像、大模型安全、系统安全
- **常规**：标准招生流程信息
  - 关键词：夏令营、预推免、推免宣讲、直博生招收、导师意向征集、招生说明会

### 3. 部署与配置

#### 环境变量覆盖

```bash
# 运行时覆盖配置
REPO_DIR=/path/to/repo \
TRACKER_DIR=/path/to/tracker \
MESSAGE_SINK_CMD="your-push-command" \
TARGET_REPO="owner/repo" \
bash ./tracker_main.sh
```

#### 默认部署路径

- 脚本存放：`./baoyan-tracker/scripts/`
- 数据存储：`./baoyan-tracker/data/tracker/`

## 运行与维护

### 依赖检查

脚本会自动检查以下依赖：
- `git` - 版本控制
- `gh` - GitHub CLI
- `jq` - JSON处理
- `date` - 日期时间工具

### 审计日志

每轮执行后会写入审计日志（`llog`），记录：
- 扫描PR数
- 候选PR数
- 命中高优先级数量
- 命中常规数量
- 过滤干扰项数量
- 错误数

### 输出示例

#### Commit早退路径

```
Found new commit on main branch.
<commit信息>
<改动文件列表>
<新增内容>
```

#### PR处理路径

```
Result: PR#123 | Level: 高优先级 | Name: 张教授 | Contact: zhang@university.edu.cn
```

## 开发与扩展

### 字段提取函数扩展

在 `tracker_extract.sh` 中添加新的提取函数：

```bash
extract_new_field() {
    local diff_raw="$1"
    echo "$diff_raw" | grep -oP "your-pattern" | head -1
}
```

### 优先级判定规则扩展

在 `tracker_extract.sh` 中修改 `detect_priority_level()` 函数：

```bash
detect_priority_level() {
    local diff_raw="$1"
    if echo "$diff_raw" | grep -Eiq "new-keyword-1|new-keyword-2"; then
        echo "高优先级"
    elif echo "$diff_raw" | grep -Eiq "other-keyword"; then
        echo "常规"
    else
        echo "低优先级"
    fi
}
```

### 推送接口扩展

在 `stage_6_message.sh` 中修改 `send_message()` 函数：

```bash
send_message() {
    local msg="$1"
    if [ -n "${MESSAGE_SINK_CMD:-}" ]; then
        # 自定义推送命令
        printf "%s\n" "$msg" | bash -lc "$MESSAGE_SINK_CMD"
    else
        # 默认输出到控制台
        echo "[PUSH]"
        printf "%s\n" "$msg"
    fi
}
```
