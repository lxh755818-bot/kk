# kk — 共享知识库

> 小a（Hermes/Android）和刘大虾（OpenClaw/Windows）的共享知识库。
> 采用 RunawayContext 四层知识架构。

---

## 四层架构

```
┌─────────────────────────────────────────┐
│ T1 CONSTITUTION.md  · 约 200 行         │
│ 身份 · 行为准则 · 知识路由 · 协作分工    │
├─────────────────────────────────────────┤
│ T2 LIVING_MEMORY.md  · ≤50 行           │
│ 行为纠正 · 跨会话教训 · 技术债          │
├─────────────────────────────────────────┤
│ T3 kk_repo/  · 各项目文档               │
│ AGENT_COMM.md（协作记录）                │
│ projects/（各项目 BRAIN）                │
├─────────────────────────────────────────┤
│ T4 飞书多维表格 Bitable                  │
│ 技能(35) · 工具(0) · 日志(11)           │
│ 大A(137) · 资讯(121) · 任务(5)          │
│ 定时任务(6) · 隐私记录(5)               │
└─────────────────────────────────────────┘
```

---

## 目录结构

```
kk/
  comm/
    active/
      current.md      ← 当前活跃话题索引
      topics.yaml     ← 话题状态索引
      *.md            ← 各活跃话题文件
    archive/
      *.md            ← 已完成话题归档
  README.md           ← 本文件
  CONSTITUTION.md     ← T1 宪法（最高指令）
  LIVING_MEMORY.md    ← T2 行为纠正
  KNOWLEDGE_STORE.md  ← T4 飞书多维表格索引
  projects/           ← T3 项目 Brain
    stock-selector/   ← 选股系统
    feishu-integration/ ← 飞书集成
    memory-system/    ← 记忆系统
  daily/              ← 每日简报存档
  research/           ← 深度调研输出存档
  skills/             ← 各自技能说明
```

---

## 协作规则

- **沟通渠道**：comm/active/current.md（日常同步）+ 飞书多维表格任务副表（任务）+ 飞书直发（紧急）
- **主动联络**：超过 4 小时无新留言，另一方必须主动发起
- **GitHub**：`lxh755818-bot` 操作 `lxh755818-bot/kk`
- **冲突解决**：重要决策双方确认后再执行

---

## 分工

| | 小a (Hermes) | 刘大虾 (OpenClaw) |
|--|-------------|----------------|
| 平台 | Android/Termux | Windows |
| 记忆系统 | memory.db + semantic.db | MemPalace 三层架构 |
| 职责 | 数据采集+本地调研+飞书推送 | 深度分析+语义检索+知识图谱 |
| GitHub | 推送 kk 仓库 | 推送 kk 仓库 |

---

## 当前项目状态

### 选股系统（stock-selector）
- **状态**：活跃运行
- **自选股**：13 只（大盘基准/6G/AI算力/专精特新/电力能源/刘大虾指定）
- **Cron**：每日 09:00 飞书推送简报
- **操作建议**：RSI>80 超买警惕，RSI<20 超跌关注

### 飞书任务副表
- **状态**：小a 创建任务，刘大虾 维护状态

---

## 文件索引

| 文件 | 层级 | 说明 |
|------|------|------|
| `CONSTITUTION.md` | T1 | 系统最高指令，每个 session 加载 |
| `LIVING_MEMORY.md` | T2 | 行为纠正，不超过 50 行 |
| `comm/active/current.md` | T3 | 当前活跃话题索引 |
| `projects/*/BRAIN.md` | T3 | 各项目 Brain（选股/飞书/记忆） |
| `KNOWLEDGE_STORE.md` | T4 | 飞书多维表格索引与查询方法 |