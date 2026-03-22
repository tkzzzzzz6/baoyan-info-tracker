---
name: 保研信息自动化跟踪-保包
description: |
  监控GitHub仓库CS-BAOYAN/CSLabInfo2025的更新，跟踪计算机、生物医学工程、电子信息专业的保研招生和实习信息。
  【重要原则】：没有新的更新或不满足条件时，绝对不能发送任何消息推送，必须完全静默。
---

一、核心任务与执行环境
1. 监控目标：
	Github 仓库 CS-BAOYAN/CSLabInfo2025
2. 核心职责：利用 gh 命令行工具获取实时更新，跟踪符合的计算机与生物医学工程以及电子信息专业的保研情报。
3. 【最高原则】：没有更新、不满足时间窗口条件时，必须完全静默，不发送任何消息！

3. 执行工具（按阶段拆分）：

生产环境将所有脚本安装到了指定目录（如：$SCRIPT_DIR）。
1) 默认从 tracker_config.sh 读取路径。
2) 数据存储路径由 TRACKER_DIR 配置。
先执行 SCRIPT_DIR=$HOME/baoyan-info-tracker/scripts 命令，将当前环境变量 SCRIPT_DIR 设置为脚本所在目录，后续脚本中使用 $SCRIPT_DIR 进行路径引用。


1) tracker_config.sh
   作用：统一配置路径、时间窗口、目标仓库、PR 拉取上限。
2) tracker_extract.sh
   作用：字段提取函数（老师姓名、邮箱、优先级判断）。
3) stage_1_init.sh
   作用：阶段1-初始化与依赖检查（检查依赖、创建存储目录、初始化水位线）。
4) stage_2_sync_repo.sh
   作用：阶段2-仓库同步（拉取仓库最新状态）。
5) stage_3_check_commit.sh
   作用：阶段3-Commit检查与早退（判断是否符合早退条件）。
6) stage_4_filter_prs.sh
   作用：阶段4-PR筛选（筛选符合条件的PR）。
7) stage_5_process_prs.sh
   作用：阶段5-PR处理（处理PR、提取信息）。
8) stage_6_message.sh
   作用：阶段6-消息推送（发送推送消息）。
9) stage_7_audit.sh
   作用：阶段7-审计日志（记录执行统计和状态）。

执行命令：

SCRIPT_DIR=$HOME/baoyan-info-tracker/scripts \
REPO_DIR=$HOME/ \
TRACKER_DIR=$HOME/ \

# 在配置好环境变量后运行：
bash $SCRIPT_DIR/stage_1_init.sh
bash $SCRIPT_DIR/stage_2_sync_repo.sh
bash $SCRIPT_DIR/stage_3_check_commit.sh
bash $SCRIPT_DIR/stage_4_filter_prs.sh
bash $SCRIPT_DIR/stage_5_process_prs.sh candidates.tsv
bash $SCRIPT_DIR/stage_6_message.sh "消息内容"
bash $SCRIPT_DIR/stage_7_audit.sh log "日志内容"

早期退出规则：
规则 A：若检测到最新 commit 晚于水位线且在 1 小时窗口内，本轮立即退出，不再执行 PR 扫描。
规则 B：若无新的 commit 且无符合条件的 PR，记录 Idle 后退出。

预期输出：
1) Commit 早退路径：
   输出 Found new commit on main branch.
   输出 commit 摘要和关键变动行。
   写入 llog，路径标记为 CommitEarlyExit。
2) PR 处理路径：
   输出 Result: PR#<编号> | Name: <教师名或N/A> | Contact: <邮箱或N/A>
   结束后写入 llog 统计行（扫描PR数、候选PR数、命中、过滤、错误）。
3) 空结果路径：
   写入 [YYYY-MM-DD HH:MM:SS] Status: Idle (No relevant updates).
4) 异常路径：
   单条 PR 失败累计错误计数并继续，整体不中断。

二、过滤与筛选规则
1. 去重规则：
	同一条信息只在首次发现时推送一次，后续更新不重复推送，除非信息内容发生实质性变化。
2. 时间过滤：
	优先规则：先检查最新 commit 时间。
	若 当前时间 - 最新 commit 时间 <= 1 小时：直接走 commit 变动整合推送，跳过 PR 流程。
	若 当前时间 - 最新 commit 时间 > 1 小时：再使用 PR.updatedAt 进行后续筛选。
	PR 筛选公式：当前扫描时间 - PR.updatedAt。
	若 PR 时间差 >= 1 小时：允许进入内容筛选流程。
	若 PR 时间差 < 1 小时：保持静默不推送（防止最近发布的 PR 被重复推送）。
	若 PR.updatedAt <= 上次扫描时间：判定为旧消息，直接跳过。

3. 【严格要求】：任何不满足条件的情况，必须完全静默，绝对不能发送消息！

三、推送内容格式
1. 发现匹配信息时：
	【保研情报推送】
	院校院系：[填入具体院校与学院名称]
	活动类型：[如：2025 年夏令营 / 预推免 / 科研实习 / 直博招生]
	更新详情：[精炼描述更新的具体内容]
	官方链接：[提取原始 URL]
2. 无效更新时：
	完全静默，不触发任何消息推送。

四、审计日志规范
任务执行完毕后，将结果追加至 data/tracker/llog 路径：
[YYYY-MM-DD HH:MM:SS] 扫描PR数: N | 候选PR数: C | 命中: H | 过滤干扰项: Z | 错误数: E

若无更新则记录：
[YYYY-MM-DD HH:MM:SS] Status: Idle (No relevant updates).
