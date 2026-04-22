# 记忆系统 Brain

## 基本信息
- **创建**: 2026-04-22
- **架构版本**: RunawayContext v1.0 四层

## 四层架构（RunawayContext）

### T1 系统宪法 (CONSTITUTION.md)
- 身份定义、行为准则
- 知识路由规则
- 协作分工（刘大虾：小a = PC端：移动端）
- 索引路由（skill → memory → session_search → kk_repo）

### T2 行为纠正 (LIVING_MEMORY.md)
- Cass 规则学习机制
- 置信度衰减（久未访问降级）
- 每日蒸馏教训
- 当前记录：选股系统教训、飞书隐私副表教训

### T3 项目 Brain（本层）
- 各项目的子记忆
- stock-selector/BRAIN.md
- feishu-integration/BRAIN.md
- memory-system/BRAIN.md

### T4 知识库 (KNOWLEDGE_STORE.md)
- 飞书多维表格结构索引
- 工具副表（12个已注册）
- 资讯/任务/定时任务

## 本地记忆系统

### semantic.db（活跃记忆）
- 路径: `~/.hermes/memory/semantic.db`
- 表: memories (P0/P1/P2), memories_archive
- 字段: id/text/category/tokens/created_at/access_count/priority/last_accessed/ttl_days
- 机制: 置信度衰减 = `last_accessed` 老化 + `access_count` 计数
- 当前: 10条记忆，9条活跃

### sessions.db（历史检索）
- 路径: `~/.hermes/sessions/sessions.json`
- 检索: FTS5 关键词搜索
- 用途: 跨session回溯历史决策

### kk_repo（协作记忆）
- 路径: `git@github.com:lxh755818-bot/kk.git`
- 用途: 小a ↔ 刘大虾 Bot-to-Bot 共享知识
- 格式: Markdown 文件

## 与刘大虾的协作分工
| 方向 | 小a (Android) | 刘大虾 (PC) |
|------|--------------|-------------|
| 语义检索 | ❌ | ✅ MemPalace ChromaDB |
| 快速采集 | ✅ Termux | ❌ |
| 飞书 | ✅ 推送 | ✅ 全家桶 |
| 记忆共享 | ✅ kk_repo | ✅ kk_repo |
| 深度推理 | ❌ | ✅ |

## 当前缺口
1. **Layer 3 向量语义**: 无（ChromaDB/sqlite-vss 不可用）
2. **每日蒸馏 Cron**: 未实现
3. **置信度衰减**: 有字段但无自动衰减逻辑
4. **三层互相印证**: 完全缺失

## TODO
- [ ] 每日蒸馏 Cron（22:00自动执行）
- [ ] 置信度衰减脚本（基于 access_count + last_accessed）
- [ ] Layer 3 替代方案（轻量embedding？）
