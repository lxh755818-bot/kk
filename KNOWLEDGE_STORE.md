# Knowledge Store — RunawayContext Tier 4

> 飞书多维表格是本系统的外部知识库，所有可检索的事实/技能/工具/资讯存在这里。
> 本文件是索引，不是内容本身。内容通过飞书 API 实时查询。

---

## 飞书多维表格

**Base Token**：`PlsLbTLynaIF3qsoVXCctXTcnnf`
**链接**：https://cifc3zva2a8.feishu.cn/base/PlsLbTLynaIF3qsoVXCctXTcnnf

---

## 副表索引

| 副表 | Table ID | 记录数 | 字段 | 用途 |
|------|---------|-------|------|------|
| **技能** | `tblOYGQyXCgiv0H4` | 35 | 名称/分类/触发条件/描述/状态 | 45+ 技能清单与状态 |
| **工具** | `tbly7MjpPbPLkasd` | 0 | 名称/类型/端点/用途/状态 | API 端点与工具索引 |
| **日志** | `tblzpMIduHXxCxCP` | 11 | 日期/话题/具体事项/状态 | 流水账，7×24 更新 |
| **大A** | `tbl9Eo8lorQklkLf` | 137 | 日期/代码/名称/操作/信号/建议/结果 | A股选股日志 |
| **资讯** | `tblFxaLIZT15IRIp` | 121 | 日期/类别/标题/摘要/板块/链接 | 国际/军事/AI/政策热点 |
| **任务** | `tblqDUgWa7XnXCr4` | 5 | 任务/描述/优先级/状态/负责人/截止 | 周例会任务跟踪 |
| **定时任务** | `tblfl0zwRYhihjek` | 6 | 任务/Cron/脚本/描述/状态/最近执行 | Cron 任务管理 |
| **隐私记录** | `tbllup7e8aQvf4Lx` | 5 | 名称/类型/密钥/用途/备注 | 密钥集中管理 |

---

## 快速查询

```python
# 飞书 API 查询模板
import urllib.request, json

BASE_TOKEN = "PlsLbTLynaIF3qsoVXCctXTcnnf"
TABLE_ID = "<table_id>"

# 1. 获取 token
req = urllib.request.Request("https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
    data=json.dumps({"app_id": "cli_a95a1e699d78dcb5",
                      "app_secret": "hnvbzkROjEbjJjYDJA1gdjSzx2DEMOgT"}).encode(),
    headers={"Content-Type": "application/json"}, method="POST")
token = json.loads(urllib.request.urlopen(req).read())["tenant_access_token"]

# 2. 查询记录
req2 = urllib.request.Request(
    f"https://open.feishu.cn/open-apis/bitable/v1/apps/{BASE_TOKEN}/tables/{TABLE_ID}/records",
    headers={"Authorization": f"Bearer {token}"})
records = json.loads(urllib.request.urlopen(req2).read())["data"]["items"]
```

---

## 各副表说明

### 技能 (`tblOYGQyXCgiv0H4`)
- 记录 Hermes 已注册的 35+ 技能
- 字段：名称、分类、触发条件、描述、状态
- 飞书 DM 查询用：搜索"技能"关键字

### 工具 (`tbly7MjpPbPLkasd`)
- API 端点与工具索引，目前 0 条记录，待填充
- 可记录 MCP servers、API 端点、CLI 命令

### 日志 (`tblzpMIduHXxCxCP`)
- 每日工作流水账
- 字段：日期、话题、具体事项、状态
- 由 Cron 每日自动更新

### 大A (`tbl9Eo8lorQklkLf`)
- A股选股信号日志，137 条记录
- 字段：代码、名称、操作（买/卖/观望）、信号依据、技术信号、操作建议
- 可查询最近 RSI 金叉/死叉信号

### 资讯 (`tblFxaLIZT15IRIp`)
- 121 条资讯存档，分类：国际/军事/AI/政策
- 字段：日期、类别、标题、摘要、相关板块、链接

### 任务 (`tblqDUgWa7XnXCr4`)
- 5 条活跃任务，周例会 12 条事项跟踪
- 字段：任务名称、描述、优先级、状态、负责人、截止日期
- 刘小豪负责嘉尚项目（XHB-25158）

### 定时任务 (`tblfl0zwRYhihjek`)
- 6 条 Cron 任务
- 包含每日 09:00 A股简报推送（Cron ID: bf439e3dd7e6）

### 隐私记录 (`tbllup7e8aQvf4Lx`)
- 5 条密钥记录，**永不输出**
- MiniMax API Key、飞书 Bot Token、GitHub PAT、Clawvard Token、Tavily Key

---

## 知识写入规则

- **技能/工具**：新增技能后记录到对应副表
- **日志**：Cron 任务自动写入
- **大A/资讯**：选股系统每日更新
- **任务**：周例会后同步
- **隐私记录**：仅允许读取，禁止写入（已有备份）
