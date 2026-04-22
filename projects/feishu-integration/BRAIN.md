# 飞书集成 Brain

## 基本信息
- **创建**: 2026-04-19
- **状态**: 稳定运行
- **平台**: 飞书 WebSocket 长连接

## 连接信息
- **App ID**: cli_a95a1e699d78dcb5
- **Home Channel**: oc_2e5cc02fdda5aef65a7f9ca03127eda5
- **Gateway**: WebSocket (not HTTP polling)

## 多维表格（共7个副表）
Base Token: `PlsLbTLynaIF3qsoVXCctXTcnnf`

| 表名 | Table ID | 用途 | 记录数 |
|------|----------|------|--------|
| 技能 | tblOYGQyXCgiv0H4 | 35个技能注册 | 35 |
| 工具 | tbly7MjpPbPLkasd | Hermes工具能力 | 12 |
| 日志/记忆库 | tblzpMIduHXxCxCP | 每日记事+记忆 | 11 |
| 大A | tbl9Eo8lorQklkLf | 每日荐股日志 | 137 |
| 资讯 | tblFxaLIZT15IRIp | 国际/军事/AI/政策热点 | - |
| 任务 | tblqDUgWa7XnXCr4 | 5条任务跟踪 | 5 |
| 定时任务 | tblfl0zwRYhihjek | 6条Cron任务 | 6 |

## 隐私副表
- **Table ID**: tbllup7e8aQvf4Lx
- **字段**: 名称/密钥(key加密存储)
- **用途**: 存储第三方API密钥（GitHub PAT、MiniMax API Key等）

## 已验证能力
- ✅ 消息接收/发送
- ✅ 图文消息推送
- ✅ 文件上传发送（file_type=stream + msg_type=file）
- ✅ 语音/TTS（file_type=opus）
- ✅ Bot WebSocket 长连接
- ❌ 群聊@机器人响应（需要检查 group_policy）

## 关键坑点
- 飞书视频发送：`file_type='stream'` 上传 + `msg_type='file'` 发送
- 飞书音频：`file_type=opus`，m4a 格式飞书播不了
- 图片发送：用 `msg_type='image'` 直接 image_key

## TODO
- [ ] 群聊@响应机制调查（group_policy）
- [ ] 飞书日历 API 接入
- [ ] 飞书审批流自动化
