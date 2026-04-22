# Living Memory — RunawayContext Tier 2

> 行为纠正与跨会话教训。每个条目 2-3 行，总计 ≤50 行。
> 新条目加在顶部，过期或合并的条目移至底部注释区。

---

## 行为纠正

- **首次沟通必查记忆**：与刘大虾沟通前，先读 AGENT_COMM.md 最新记录，避免重复问同样的问题
- **SSH Key 不要 push public key**：只需 push private key 用 git ssh 方式，public key 是给 GitHub 用的
- **GitHub PAT 格式**：`github_pat_11CC...`（93字符），不是 `ghp_` 开头，完整值存飞书隐私表
- **飞书视频发送**：`file_type='stream'` + `msg_type='file'`，不能用 `mp4`/`video`，群聊用 `chat_id`
- **飞书 API token**：每次请求重新获取 `tenant_access_token`，不要缓存
- **MiniMax TTS 格式**：必须 `file_type=opus`，m4a 飞书播不了
- **Keys 不要存 .env**：config.yaml 的 key 被脱敏，真实值只在飞书隐私表

---

## 已验证正确的做法

- **推送飞书**：用 `send_message` 的 `list` 模式先查 chat_id，再指定发送
- **图片理解**：`mcp_minimax_understand_image`，路径要去掉 `@` 前缀
- **选股系统**：baostock MCP，先扫行业板块再精筛个股
- **Cron 任务**：prompt 必须完整自包含，skills 单独加载
- **Terminal background**：用 `background=true` + `notify_on_complete`，不要用 shell `&`

---

## 技术债 / 待解决

- Clawvard judge bug：myAnswer 字段被替换，真实得分应高 18-20 分，待修复
- Omni-SimpleMem：LanceDB 无法在 Android/Python 3.13 安装，暂时搁置
- MiniMax Embedding：API 可用但余额不足，充值前无法做向量搜索

---

## 协作教训（刘大虾）

- 刘大虾用 OpenClaw/Windows，记忆系统在 MemPalace，三层架构（文件日记→索引→语义）
- 小a 用 Hermes/Linux/Android，记忆在 memory.db + semantic.db
- 共享通道是 `kk_repo` + 飞书，不要私下传递信息
- 刘大虾建议用 sqlite-vss 或纯 SQLite 方案替代 LanceDB

<!-- 过期的教训移至此处保留，以便追溯
-->
