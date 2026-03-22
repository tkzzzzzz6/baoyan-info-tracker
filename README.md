# 保研信息自动跟踪系统

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell Script](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)

一个自动化的保研信息跟踪系统，用于监控 GitHub 仓库 `CS-BAOYAN/CSLabInfo2025` 的更新，筛选计算机、生物医学工程、电子信息专业相关的保研招生和实习信息，并通过消息推送机制及时通知用户。

## 目录

- [项目概述](#项目概述)
- [核心功能](#核心功能)
- [系统架构](#系统架构)
- [快速开始](#快速开始)
- [安装部署](#安装部署)
- [使用指南](#使用指南)
- [配置说明](#配置说明)
- [开发扩展](#开发扩展)
- [常见问题](#常见问题)

## 项目概述

### 功能特点

- **自动监控**：定时监控目标仓库的 commit 和 PR 更新
- **智能筛选**：基于关键词和时间窗口的多层过滤机制
- **优先级判定**：区分高优先级（前沿交叉学科）和常规招生信息
- **消息推送**：支持自定义推送命令，灵活对接各类通知渠道
- **增量扫描**：水位线机制避免重复推送
- **审计日志**：完整的执行记录便于追溯和调试

### 适用场景

- 保研信息的实时跟踪与推送
- 科研实习机会的自动发现
- 招生宣讲会的及时通知
- 导师招生意向的快速获取

## 核心功能

### 1. 时间窗口机制

- **Commit早退窗口**（1小时）：最新 commit 在1小时内时，直接推送摘要并结束流程
- **PR静默窗口**（1小时）：PR 更新后1小时内不推送，避免重复
- **水位线机制**：记录上次扫描时间，实现增量扫描

### 2. 优先级判定

#### 高优先级关键词
涉及前沿交叉学科或主流 AI 方向：
- 多模态（Multimodal）
- 大模型（LLM/Agent）
- 具身智能（Embodied AI）
- AI4Science（AI4S）
- 计算医学
- 医疗影像
- 大模型安全
- 系统安全

#### 常规关键词
标准招生流程信息：
- 夏令营
- 预推免
- 推免宣讲
- 直博生招收
- 导师意向征集
- 招生说明会

### 3. 噪声过滤

自动过滤以下无效更新：
- 纯格式调整（Markdown 表格符号、空格、换行）
- 仓库维护（README 导航、文件重命名）
- 修复死链等非实质性内容

## 系统架构

### 工作流程

系统采用 **7 阶段流水线架构**，每个阶段独立运行，便于调试和扩展：

```
开始 → 阶段1 → 阶段2 → 阶段3 → 阶段4 → 阶段5 → 阶段6 → 阶段7 → 结束
       ↓       ↓       ↓       ↓       ↓       ↓       ↓
     初始化  仓库同步  Commit  PR筛选  PR处理  消息推送  审计日志
              检查
```

**执行流程说明：**

1. **阶段1 - 初始化**：检查依赖（git、gh、jq）、创建目录、初始化水位线
2. **阶段2 - 仓库同步**：拉取目标仓库最新状态
3. **阶段3 - Commit检查**：检测最新 commit，如在1小时内则直接推送并早退
4. **阶段4 - PR筛选**：根据时间窗口和水位线筛选候选 PR
5. **阶段5 - PR处理**：提取信息、判断优先级（高优先级/常规）
6. **阶段6 - 消息推送**：发送格式化的推送消息
7. **阶段7 - 审计日志**：记录执行统计和状态

**早退机制：**
- 若阶段3检测到新 commit 在1小时内 → 直接推送 commit 摘要，跳过阶段4-6
- 若无更新 → 记录 Idle 状态，结束流程

### 核心组件

#### 共享模块
| 文件名 | 功能 | 主要内容 |
|-------|------|----------|
| \`tracker_config.sh\` | 配置管理 | 路径配置、时间窗口设置、目标仓库、PR拉取上限，含共享工具函数 |
| \`tracker_extract.sh\` | 信息提取 | 老师姓名、邮箱、优先级判断的字段提取函数 |

#### 阶段脚本（按执行顺序）
| 文件名 | 阶段 | 功能说明 |
|-------|------|----------|
| \`stage_1_init.sh\` | 阶段1 | 初始化与依赖检查、水位线初始化 |
| \`stage_2_sync_repo.sh\` | 阶段2 | 仓库同步（拉取最新状态） |
| \`stage_3_check_commit.sh\` | 阶段3 | Commit检查与早退判断 |
| \`stage_4_filter_prs.sh\` | 阶段4 | PR筛选（获取并筛选候选PR） |
| \`stage_5_process_prs.sh\` | 阶段5 | PR处理（提取信息、判断优先级） |
| \`stage_6_message.sh\` | 阶段6 | 消息推送 |
| \`stage_7_audit.sh\` | 阶段7 | 审计日志 |

#### 调度脚本
| 文件名 | 功能 | 说明 |
|-------|------|------|
| \`tracker_main.sh\` | 完整流程调度 | 组合所有阶段的执行流程 |

## 快速开始

### 前置要求

确保系统已安装以下依赖：

\`\`\`bash
# 必需依赖
- git        # 版本控制
- gh         # GitHub CLI
- jq         # JSON处理
- date       # 日期时间工具
\`\`\`

### 快速运行

\`\`\`bash
# 1. 克隆仓库
git clone https://github.com/tkzzzzzz6/baoyan-info-tracker.git
cd baoyan-info-tracker

# 2. 配置环境（可选）
export REPO_DIR=/path/to/monitored/repo
export TRACKER_DIR=/path/to/data
export MESSAGE_SINK_CMD="your-push-command"

# 3. 运行完整流程
bash ./tracker_main.sh
\`\`\`

## 安装部署

### 标准部署

#### 1. 目录结构

\`\`\`
project-root/
├── baoyan-tracker/
│   ├── scripts/              # 脚本存放目录
│   │   ├── tracker_config.sh
│   │   ├── tracker_extract.sh
│   │   ├── tracker_main.sh
│   │   ├── stage_1_init.sh
│   │   ├── stage_2_sync_repo.sh
│   │   ├── stage_3_check_commit.sh
│   │   ├── stage_4_filter_prs.sh
│   │   ├── stage_5_process_prs.sh
│   │   ├── stage_6_message.sh
│   │   └── stage_7_audit.sh
│   └── data/
│       └── tracker/          # 数据存储目录
│           ├── watermark     # 水位线文件
│           └── llog          # 审计日志
\`\`\`

#### 2. 部署步骤

\`\`\`bash
# 创建目录结构
mkdir -p ./baoyan-tracker/scripts
mkdir -p ./baoyan-tracker/data/tracker

# 复制脚本文件到目标目录
cp *.sh ./baoyan-tracker/scripts/

# 设置执行权限
chmod +x ./baoyan-tracker/scripts/*.sh
\`\`\`

### 定时任务配置

使用 cron 配置定时执行：

\`\`\`bash
# 编辑 crontab
crontab -e

# 添加定时任务（每45分钟执行一次）
*/45 * * * * cd /path/to/project && bash ./baoyan-tracker/scripts/tracker_main.sh >> /var/log/baoyan-tracker.log 2>&1
\`\`\`

### Docker 部署（可选）

\`\`\`dockerfile
FROM ubuntu:22.04

# 安装依赖
RUN apt-get update && apt-get install -y \\
    git \\
    gh \\
    jq \\
    cron \\
    && rm -rf /var/lib/apt/lists/*

# 复制脚本
COPY . /app/baoyan-tracker
WORKDIR /app

# 配置 cron
RUN echo "*/45 * * * * cd /app && bash ./baoyan-tracker/scripts/tracker_main.sh" | crontab -

CMD ["cron", "-f"]
\`\`\`

## 使用指南

### 完整流程执行

\`\`\`bash
# 使用调度脚本（推荐）
bash ./tracker_main.sh
\`\`\`

### 阶段独立运行

#### 阶段1：初始化与依赖检查

\`\`\`bash
# 检查依赖、创建存储目录、初始化水位线
bash ./stage_1_init.sh

# 环境变量覆盖
REPO_DIR=/path/to/repo bash ./stage_1_init.sh
\`\`\`

#### 阶段2：仓库同步

\`\`\`bash
# 拉取仓库最新状态
bash ./stage_2_sync_repo.sh

# 导出commit信息供下游使用
bash ./stage_2_sync_repo.sh --export
\`\`\`

#### 阶段3：Commit检查与早退

\`\`\`bash
# 检查最新commit，判断是否需要早退
# 返回0：应该早退，1：继续执行
bash ./stage_3_check_commit.sh
\`\`\`

#### 阶段4：PR筛选

\`\`\`bash
# 筛选候选PR，输出TSV格式
bash ./stage_4_filter_prs.sh

# 保存到文件
bash ./stage_4_filter_prs.sh > candidates.tsv

# 导出统计数据
bash ./stage_4_filter_prs.sh --export
\`\`\`

#### 阶段5：PR处理

\`\`\`bash
# 从文件读取并处理PR
bash ./stage_5_process_prs.sh candidates.tsv

# 从管道读取
cat candidates.tsv | bash ./stage_5_process_prs.sh
\`\`\`

#### 阶段6：消息推送

\`\`\`bash
# 发送消息
bash ./stage_6_message.sh "【保研情报推送】...消息内容..."

# 使用自定义sink
MESSAGE_SINK_CMD="your-push-command" bash ./stage_6_message.sh "msg"
\`\`\`

#### 阶段7：审计日志

\`\`\`bash
# 写入自定义日志
bash ./stage_7_audit.sh log "脚本已启动"

# 写入扫描统计
bash ./stage_7_audit.sh stats 50 5 2 3 0 0

# 写入idle状态
bash ./stage_7_audit.sh idle

# 查看最近日志
bash ./stage_7_audit.sh show 20
\`\`\`

### 自定义组合流程

\`\`\`bash
#!/bin/bash
# 自定义组合示例

# 只运行初始化和仓库同步
bash ./stage_1_init.sh
bash ./stage_2_sync_repo.sh

# 或者只检查PR（跳过commit早退）
bash ./stage_1_init.sh
bash ./stage_2_sync_repo.sh
PR_LIST=$(bash ./stage_4_filter_prs.sh)
if [ -n "$PR_LIST" ]; then
    echo "$PR_LIST" | bash ./stage_5_process_prs.sh
fi
\`\`\`

## 配置说明

### 环境变量配置

所有配置项都可以通过环境变量覆盖：

| 环境变量 | 说明 | 默认值 |
|---------|------|--------|
| \`REPO_DIR\` | 监控仓库的本地路径 | 自动计算 |
| \`TRACKER_DIR\` | 数据存储目录 | \`./baoyan-tracker/data/tracker\` |
| \`TARGET_REPO\` | 目标GitHub仓库 | \`CS-BAOYAN/CSLabInfo2025\` |
| \`MESSAGE_SINK_CMD\` | 消息推送命令 | 默认输出到控制台 |
| \`MAX_PR_COUNT\` | PR拉取上限 | 50 |
| \`COMMIT_EARLY_EXIT_WINDOW\` | Commit早退窗口（秒） | 3600 |
| \`PR_SILENT_WINDOW\` | PR静默窗口（秒） | 3600 |

### 运行时覆盖配置

\`\`\`bash
# 完整示例
REPO_DIR=/path/to/repo \\
TRACKER_DIR=/path/to/tracker \\
MESSAGE_SINK_CMD="your-push-command" \\
TARGET_REPO="owner/repo" \\
MAX_PR_COUNT=100 \\
bash ./tracker_main.sh
\`\`\`

### 消息推送配置

#### 控制台输出（默认）

\`\`\`bash
bash ./tracker_main.sh
\`\`\`

#### 自定义推送命令

\`\`\`bash
# 示例：通过企业微信推送
MESSAGE_SINK_CMD="curl -X POST https://qyapi.weixin.qq.com/webhook/send" \\
bash ./tracker_main.sh

# 示例：通过钉钉推送
MESSAGE_SINK_CMD="./send_dingtalk.sh" \\
bash ./tracker_main.sh

# 示例：通过邮件推送
MESSAGE_SINK_CMD="mail -s 'Baoyan Info' user@example.com" \\
bash ./tracker_main.sh
\`\`\`

## 输出示例

### Commit早退路径

当检测到最新 commit 在1小时内：

\`\`\`
Found new commit on main branch.
Commit: abc1234
Author: John Doe <john@example.com>
Date: 2025-03-22 10:30:00
Message: Add 北京大学 2025 summer camp info

Changed files:
  M  docs/北京大学/2025年夏令营.md

New content:
+ 【北京大学计算机学院】
+ 2025年夏令营报名时间：2025年4月1日-4月30日
+ 研究方向：人工智能、系统安全
\`\`\`

### PR处理路径

正常处理 PR 时的输出：

\`\`\`
Result: PR#123 | Level: 高优先级 | Name: 张教授 | Contact: zhang@university.edu.cn
Result: PR#124 | Level: 常规 | Name: 李教授 | Contact: li@university.edu.cn
Result: PR#125 | Level: 常规 | Name: N/A | Contact: N/A
\`\`\`

### 审计日志

\`\`\`
[2025-03-22 10:45:00] 扫描PR数: 50 | 候选PR数: 5 | 命中高优先级: 2 | 命中常规: 3 | 过滤干扰项: 0 | 错误数: 0
[2025-03-22 11:30:00] Status: Idle (No relevant updates).
[2025-03-22 12:15:00] Status: CommitEarlyExit (New commit detected within 1h window)
\`\`\`

## 开发扩展

### 添加新的字段提取函数

在 \`tracker_extract.sh\` 中添加提取函数：

\`\`\`bash
extract_new_field() {
    local diff_raw="$1"
    echo "$diff_raw" | grep -oP "your-pattern" | head -1
}
\`\`\`

### 扩展优先级判定规则

修改 \`tracker_extract.sh\` 中的 \`detect_priority_level()\` 函数：

\`\`\`bash
detect_priority_level() {
    local diff_raw="$1"

    # 高优先级判定
    if echo "$diff_raw" | grep -Eiq "new-keyword-1|new-keyword-2"; then
        echo "高优先级"
        return
    fi

    # 常规判定
    if echo "$diff_raw" | grep -Eiq "other-keyword"; then
        echo "常规"
        return
    fi

    # 低优先级
    echo "低优先级"
}
\`\`\`

### 自定义推送接口

修改 \`stage_6_message.sh\` 中的 \`send_message()\` 函数：

\`\`\`bash
send_message() {
    local msg="$1"

    if [ -n "${MESSAGE_SINK_CMD:-}" ]; then
        # 自定义推送命令
        printf "%s\\n" "$msg" | bash -lc "$MESSAGE_SINK_CMD"
    else
        # 默认输出到控制台
        echo "[PUSH]"
        printf "%s\\n" "$msg"
    fi
}
\`\`\`

### 添加新的阶段脚本

创建 \`stage_8_custom.sh\`：

\`\`\`bash
#!/usr/bin/env bash
set -euo pipefail

# 计算脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置
source "$SCRIPT_DIR/tracker_config.sh"

# 你的自定义逻辑
echo "Running custom stage..."
\`\`\`

然后在 \`tracker_main.sh\` 中添加调用：

\`\`\`bash
# 在适当位置添加
bash "$SCRIPT_DIR/stage_8_custom.sh"
\`\`\`

## 常见问题

### Q1: 如何查看审计日志？

\`\`\`bash
# 查看最近20条日志
bash ./stage_7_audit.sh show 20

# 或直接查看日志文件
tail -n 50 ./baoyan-tracker/data/tracker/llog
\`\`\`

### Q2: 如何重置水位线？

\`\`\`bash
# 删除水位线文件
rm ./baoyan-tracker/data/tracker/watermark

# 下次运行时会重新初始化
\`\`\`

### Q3: 依赖检查失败怎么办？

\`\`\`bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install git gh jq

# macOS
brew install git gh jq

# 验证安装
git --version
gh --version
jq --version
\`\`\`

### Q4: 如何调试单个阶段？

\`\`\`bash
# 启用调试模式
set -x

# 运行单个阶段
bash ./stage_4_filter_prs.sh

# 禁用调试模式
set +x
\`\`\`

### Q5: 消息推送不工作？

\`\`\`bash
# 1. 检查环境变量
echo $MESSAGE_SINK_CMD

# 2. 测试推送命令
echo "test message" | bash -lc "$MESSAGE_SINK_CMD"

# 3. 查看日志
tail -f /var/log/baoyan-tracker.log
\`\`\`

### Q6: 如何处理脚本执行权限问题？

\`\`\`bash
# 添加执行权限
chmod +x *.sh

# 或使用 bash 显式执行
bash ./tracker_main.sh
\`\`\`

## 贡献指南

欢迎提交 Issue 和 Pull Request！

### 提交 PR 前的检查清单

- [ ] 代码遵循项目现有的编码风格
- [ ] 添加了必要的注释
- [ ] 更新了相关文档
- [ ] 测试通过

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 致谢

- 感谢 [CS-BAOYAN/CSLabInfo2025](https://github.com/CS-BAOYAN/CSLabInfo2025) 提供的保研信息数据源
- 感谢所有贡献者的支持

## 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 [Issue](https://github.com/tkzzzzzz6/baoyan-info-tracker/issues)
- 发送邮件至项目维护者

---

**注意**：本项目仅用于学习和研究目的，请遵守相关法律法规和 GitHub 使用条款。
