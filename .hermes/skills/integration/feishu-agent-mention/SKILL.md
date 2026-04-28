# feishu-agent-mention

> 飞书群内 Agent 互@触发与回复全链路规范
> 适用版本：OpenClaw v2.1+ + 飞书（B2B/B2C 均适用）
> 置信度：高（5次实战验证 + 全链路压测）
> 维护人：OpenClaw 协作组 / 刘大虾
> 最后更新：2026-04-24
> 技能等级：Core（核心技能）

---

## 1. 核心结论（速查）

> **一句话执行准则**：飞书群内 @Agent 必须用 `<at user_id="ou_xxx">显示名</at>` XML 标签；被 @回复时需携带发起方 @标签发回原群，形成**对话闭环**；仅群聊生效，单聊不适用。

| 参数 | 强制要求 | 校验规则 |
|------|---------|---------|
| `user_id` | 是 | 必须以 `ou_` 开头，32位十六进制字符串 |
| `<at>` 标签 | 是 | 完整闭合，无嵌套，仅保留 `user_id` 属性 |
| 群 ID | 是 | 必须以 `oc_` 开头，对应普通群 / 部门群 |

---

## 2. Agent 通讯录

### 全局通用表格

| Agent 名称 | open_id | 飞书账号 | 用途 | 状态 |
|------------|---------|---------|------|------|
| 刘大虾 | `ou_9fcec3993063f9f71d76ac09f678f92a` | default | 主助理 | ✅ 已验证 |
| 刘二虾 | `ou_5cd536480f113363d55839b4bf9276ab` | liu2 | 副助理 | ✅ 已验证 |
| 刘三虾 | `ou_c6f93376dc5804501df694a988f8b7e7` | liu3 | 副助理 | ✅ 已验证 |
| info-shrimp | `ou_85045d6dafe0cb4da9118e4944adda79` | info-shrimp | 信息 Bot | ✅ 已验证 |
| repair-shrimp | `ou_f3199928cacad8fbd0d20529a442dc52` | repair-shrimp | 修复 Bot | ✅ 已验证 |
| Phone（小a） | `ou_d6da1a2b788b21a20b5c7410add9eb58` | 小a的Hermes | 多Agent协作 | ✅ 已验证（2026-04-25） |

**通用测试群**：`oc_5e9d682887056b9aa5db3bff44b743ff`（飞书显示名：刘氏三虾，Hermes 可用群名 `feishu:刘氏三虾`）
**获取 open_id**：调用 `feishu_get_user` 工具（无需参数，自动获取当前账号）

### 编程化配置（直接复用）

```json
{
  "agents": {
    "刘大虾": {"open_id": "ou_9fcec3993063f9f71d76ac09f678f92a", "role": "主助理"},
    "刘二虾": {"open_id": "ou_5cd536480f113363d55839b4bf9276ab", "role": "副助理"}
  },
  "test_group": "oc_5e9d682887056b9aa5db3bff44b743ff"
}
```

---

## 3. 全链路操作步骤

### 阶段 1：@触发目标 Agent（发起方）

1. 从通讯录获取已验证的 `open_id`，未收录则调用 `feishu_get_user` 查询
2. 使用 `message` 工具发送：
   ```
   action: send
   channel: feishu
   target: chat:{群ID}
   message: <at user_id="{open_id}">{显示名}</at> {指令}
   ```
3. 确认目标 Agent 收到合成消息事件

### 阶段 2：被 @后回复（目标 Agent 侧）

1. 从上下文提取发起方 `open_id` 和原群 ID（OpenClaw 自动注入）
2. 构造回复消息：`<at user_id="ou_发起方open_id">发起方名字</at> {回复内容}`
3. **发送到原群聊**，完成对话闭环

---

## 4. 格式规范（正确 / 错误对比）

| 场景 | ✅ 正确格式 | ❌ 错误格式 | 不触发原因 |
|------|------------|-----------|-----------|
| @触发 | `<at user_id="ou_xxx">刘二虾</at>` | `@刘二虾` / `[@刘二虾](open_id:ou_xxx)` | 飞书原生 @不触发 Bot，Hook 仅解析 XML 标签 |
| 被@回复 | `<at user_id="ou_xxx">刘大虾</at> 收到` | 纯文本回复 / 普通 @发起方 | 无对话闭环，无法触发发起方后续响应 |

---

## 5. 实战模板

### 模板 1：简单唤醒 + 回复

```text
# 发起方
<at user_id="ou_5cd536480f113363d55839b4bf9276ab">刘二虾</at> 测试
# 回复方（必须带发起方@）
<at user_id="ou_9fcec3993063f9f71d76ac09f678f92a">刘大虾</at> 测试成功
```

### 模板 2：任务指令 + 回复

```text
# 发起方
<at user_id="ou_5cd536480f113363d55839b4bf9276ab">刘二虾</at> 查明天产品部会议
# 回复方
<at user_id="ou_9fcec3993063f9f71d76ac09f678f92a">刘大虾</at> 9:00 产品评审会（飞书1号会议室）
```

### 模板 3：多 Agent 协作接龙

```text
# 发起方
<at user_id="ou_xxx1">info-shrimp</at> 查询订单12345信息
# info-shrimp 回复（@下一个执行者）
<at user_id="ou_9fcec3993063f9f71d76ac09f678f92a">刘大虾</at> 订单信息已获取，<at user_id="ou_xxx2">repair-shrimp</at> 排查异常
# repair-shrimp 回复
<at user_id="ou_xxx1">info-shrimp</at> 异常已修复，<at user_id="ou_9fcec3993063f9f71d76ac09f678f92a">刘大虾</at> 任务完成
```

---

## 6. 全链路原理

飞书原生限制：Bot 互发消息不触发事件 → OpenClaw Hook 拦截转发机制：

```
发送方@消息 → 全局Hook拦截 → 解析<at>标签 → 构造合成事件 → 调用目标Agent
目标Agent执行 → 构造带@回复 → 发送原群 → 发起方收到合成事件（闭环）
```

---

## 7. 错误排查清单（优先级从高到低）

1. **格式校验**：是否使用 `<at user_id="ou_xxx">名字</at>` 且标签闭合
2. **ID 校验**：`open_id` 是否以 `ou_` 开头，目标 Agent 是否在群内
3. **群类型校验**：是否为群聊（单聊不生效）
4. **工具校验**：发送时是否指定 `channel: feishu` 和 `target: chat:群ID`
5. **日志校验**：查看 `logs/hook/feishu-hook.log` 是否有标签解析记录

---

## 8. ⚠️ 实战坑点（已踩过）

**身份工具踩坑**：必须用 `message` 工具（机器人身份）发送，不能用 `feishu_im_user_message`（用户身份）；后者发 @ 会打到用户自己身上。

**网关并发上限**：一次性 @ 太多 Agent 会触发网关并发限制，导致部分 Bot 无法触发。

| 场景 | 建议 |
|------|------|
| 同时 @ 多个 Agent | **每次控制在 2 个以内**，间隔几秒再发下一批 |
| 多 Agent 接龙 | 先 @Agent1 → **等它回复** → 再 @Agent2 → 以此类推 |
| 批量查询 | 分批次发请求，不要在一条消息里 @超过 2 个 |

---

## 9. 横向展开指南

1. **分发文件路径**：`skills/feishu-agent-mention/SKILL.md`
2. **核心传授**：飞书 @Agent 用 `<at user_id="ou_xxx">名字</at>`，**回复必须带发起方 @标签**
3. **验证方法**：在测试群完成一次 @ + 回复全流程，确认双方均收到事件

---

## 10. 注意事项

- 禁止使用 `union_id` / `user_id` 替代 `open_id`
- 回复必须发送到原触发群聊，支持飞书富文本（`<br>` 换行、链接等）
- 多 Agent 协作时，每个回复需明确 @下一个执行者，避免任务中断
- **回复闭环是强制要求**：被@后不带发起方@的回复会导致对话链断裂

---

## 版本日志

| 版本 | 更新时间 | 变更内容 |
|------|---------|---------|
| V1.0 | 2026-04-24 | 初始版本，覆盖基础 @触发 |
| V2.0 | 2026-04-24 下午 | 融合大虾实战坑点（并发限制）+ 回复闭环规范 + 错误排查 |

*Source: 实战验证 + 《OpenClaw Bot-to-Bot Relay 方案 V2.1》 + 《飞书 Agent 对话闭环规范 V1.0} + 《飞书多Bot跨实例@协作通用教程手册 v1.0》(2026-04-27)*

---

## 11. 文档最佳实践补充（来源：《飞书多Bot跨实例@协作通用教程手册》v1.0）

### 11.1 核心结论（必须遵守）

1. **numeric user_id** 是跨Bot/跨App@的唯一可靠标识，在所有应用视角下完全一致
2. **open_id** 是应用视角隔离的，同一个用户/Bot在不同App中会获得不同的open_id，**绝对不能跨App使用**
3. 主流Agent框架（OpenClaw、Hermes）会自动处理@mention，优先使用**系统自动@**而非手动编写XML
4. 所有@操作的唯一验证标准：发送后消息中@标签显示为**蓝色**，且API响应的mentions数组包含有效ID

### 11.2 numeric user_id vs open_id

| 标识类型 | 全局唯一性 | 适用场景 | 格式 |
|----------|-----------|---------|------|
| Numeric User ID | ✅ 全局唯一 | 跨App@、跨Bot协作 | 纯数字 |
| Open ID | ❌ App内唯一 | 同App内消息发送 | `ou_`开头 |

**露丝（Hermes）Bot 的 numeric user_id 查询方法**：
```python
# 调用 /open-apis/contact/v3/users/{user_id}?user_id_type=open_id
# 响应中 user_id 字段即为 numeric user_id
```

### 11.3 标准消息发送与验证流程（5步）

1. **本地测试**：用 execute_code 打印 json.dumps 的输出，检查 XML@标签格式
2. **发送消息**：调用飞书API，使用正确的ID格式
3. **后端验证**：检查API响应中 mentions 数组是否包含有效ID
4. **前端验证**：飞书客户端查看消息，@标签是否为蓝色
5. **结果记录**：将测试结果和ID信息记录到文档

### 11.4 Python JSON 构建铁律

```python
# ✅ 正确：始终用 json.dumps
text = '<at user_id="123456">刘大虾</at>'
content = json.dumps({"text": text})

# ❌ 错误：手动拼接JSON字符串
text = '<at user_id=\"123456\">刘大虾</at>'  # 手动转义引号
content = '{"text": "' + text + '"}'         # 手动拼接
```

### 11.5 Memory 管理规范

- 添加新内容前**先检查容量**（超过80%先清理）
- 定期合并重复条目，删除冗余信息
- 重要信息单独存到飞书文档，不要全放Memory

### 11.6 快速验证清单（6项）

- [ ] 所有跨Bot@使用 **numeric user_id**（非open_id）
- [ ] 没有手动在Python字符串中转义@标签引号
- [ ] 使用 `json.dumps` 生成JSON请求体
- [ ] 发送消息后检查API响应的 **mentions数组**
- [ ] 飞书客户端中@标签显示为**蓝色**
- [ ] 添加新内容前检查Memory使用量

### 11.7 两种ID格式混用的危害

**现象**：@操作有时生效有时不生效，无明显规律
**原因**：代码中同时使用numeric user_id和open_id，在不同场景下切换混乱
**解决**：所有跨Bot/跨App协作时，强制使用 numeric user_id

---

## 版本日志

| 版本 | 更新时间 | 变更内容 |
|------|---------|---------|
| V1.0 | 2026-04-24 | 初始版本，覆盖基础 @触发 |
| V2.0 | 2026-04-24 下午 | 融合大虾实战坑点（并发限制）+ 回复闭环规范 + 错误排查 |
| V3.0 | 2026-04-29 | 融合《飞书多Bot跨实例@协作通用教程手册》v1.0：numeric user_id规范、json.dumps铁律、6项验证清单、Memory管理规范 |
