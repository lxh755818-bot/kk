---
name: skill-cycle-optimizer
description: 技能循环优化自进化技能。每2小时测试一个已注册技能，执行完整的评估审核流程，监控性能变化，输出优化建议和报告。
version: 1.1.0
author: 小哈
license: MIT
dependencies: []
metadata:
  hermes:
    tags: [Self-Evolution, Performance, Skill Testing, Cron]
    cron_schedule: "0 */2 * * *"
---

# 技能循环优化

## 核心原则

**每次只测试一个技能，严格按顺序循环，不一次测多个。**

每次测试必须产生实际、可量化的评估结果，包含完整的审核流程。

---

## 触发条件

- **Cron 表达式**: `0 */2 * * *`（每2小时）
- **手动触发**: `cronjob action=run job_id=<任务ID>`

---

## 执行流程

### 第一步：读取进度

读取 `~/.hermes/evolution_logs/skill_optimizer/state.json`：

```json
{
  "last_skill_index": 5,
  "total_skills": 83,
  "last_run": "2026-04-17T08:00:00"
}
```

如果文件不存在，初始化为 `last_skill_index: -1`。

### 第二步：确定本次技能

```
next_index = (last_skill_index + 1) % total_skills
```

扫描 `~/.hermes/skills/` 下所有 `SKILL.md` 并排序（使用 `Path.rglob` 递归扫描），得到技能列表：

```python
from pathlib import Path

hermes_home = Path.home() / ".hermes"
skills_dir = hermes_home / "skills"

# 递归扫描所有 SKILL.md
all_skills = []
for md_path in sorted(skills_dir.rglob("SKILL.md")):
    rel = md_path.relative_to(skills_dir)
    category = str(rel.parent)  # e.g. "apple/imessage"
    all_skills.append((category, md_path))

all_skills.sort(key=lambda x: x[0])
total_skills = len(all_skills)
# 技能索引: all_skills[next_index] = (category, md_path)
```

### 第三步：技能类型评估（修复版）

读取技能的 `SKILL.md`，根据 YAML frontmatter metadata.tags 判断类型：

```python
import yaml

def parse_frontmatter(skill_md_path):
    """正确解析 SKILL.md 的 YAML frontmatter"""
    with open(skill_md_path) as f:
        content = f.read()
    if not content.startswith("---"):
        return None, content
    end_idx = content.find("\n---\n", 3)
    if end_idx == -1:
        end_idx = content.find("\n--", 3)
        if end_idx == -1:
            return None, content
    yaml_text = content[3:end_idx].strip()
    body = content[end_idx+4:]
    try:
        frontmatter = yaml.safe_load(yaml_text)
    except yaml.YAMLError:
        return None, content
    return frontmatter, body

def get_skill_type(skill_md_path):
    """根据 frontmatter metadata.tags 正确判断技能类型"""
    fm, _ = parse_frontmatter(skill_md_path)
    if fm is None:
        return "sandbox"
    tags = fm.get("metadata", {}).get("hermes", {}).get("tags", [])
    if not isinstance(tags, list):
        tags = []
    tags_str = " ".join(tags).lower()

    if "jupyter" in tags_str or "kernel" in tags_str or "notebook" in tags_str:
        return "jupyter"
    elif "api" in tags_str:
        return "api"
    elif "cli" in tags_str or "command" in tags_str:
        return "cli"
    elif "file" in tags_str or "parser" in tags_str:
        return "file_parser"
    elif "integration" in tags_str or "platform" in tags_str:
        return "integration"
    elif "code" in tags_str or "generation" in tags_str:
        return "code_gen"
    else:
        return "sandbox"
```

**技能类型说明：**
- `jupyter`：Jupyter 内核类技能（hamelnb），不检查 API key
- `api`：调用外部 API 的技能
- `cli`：依赖本地命令的技能
- `file_parser`：解析文件的技能
- `integration`：平台集成类技能
- `code_gen`：代码生成类技能
- `sandbox`：其他沙箱类技能

### 第四步：文档完整性审核

正确解析 YAML frontmatter（`---` 分隔符之间的内容），然后检查必要字段：

```python
import yaml, re

def parse_frontmatter(skill_md_path):
    """正确解析 SKILL.md 的 YAML frontmatter"""
    with open(skill_md_path) as f:
        content = f.read()
    
    if not content.startswith("---"):
        return None, content
    
    # 找到第二个 --- 的位置（YAML 结束标记）
    end_idx = content.find("\n---\n", 3)
    if end_idx == -1:
        # 可能 frontmatter 一直延续到文件末尾（无 body）
        end_idx = content.find("\n---", 3)
        if end_idx == -1:
            return None, content
    
    yaml_text = content[3:end_idx].strip()
    body = content[end_idx+4:]
    
    try:
        frontmatter = yaml.safe_load(yaml_text)
    except yaml.YAMLError:
        return None, content
    
    return frontmatter, body

def audit_doc_complete(skill_md_path):
    """审核文档完整性"""
    fm, body = parse_frontmatter(skill_md_path)
    
    if fm is None:
        return False, "无法解析 YAML frontmatter"
    
    name = fm.get("name", "")
    desc = fm.get("description", "")
    has_name = bool(name and str(name).strip())
    has_desc = bool(desc and len(str(desc).strip()) > 10)
    
    # body 也要有实质内容（至少 50 字符）
    has_body = len(body.strip()) >= 50
    
    doc_complete = has_name and has_desc and has_body
    
    return doc_complete, {
        "has_name": has_name,
        "has_description": has_desc,
        "has_body": has_body,
        "name": name,
        "description": desc[:50] + "..." if len(str(desc)) > 50 else desc
    }
```

评分：`doc_complete_pass: bool`

**正确解析逻辑：**
1. 文件必须以 `---` 开头
2. 找到第一个换行后的第二个 `---` 作为结束标记
3. 取两个 `---` 之间的内容作为 YAML
4. 用 `yaml.safe_load` 解析
5. 检查 `name` 非空、`description` > 10 字符、`body` >= 50 字符

### 第五步：依赖可用性审核（修复版）

根据技能类型检查依赖：

| 类型 | 检查方式 |
|------|---------|
| `api` | 检查 `MINIMAX_API_KEY` / `OPENAI_API_KEY` 等环境变量 |
| `cli` | 用 `shutil.which` 检查命令是否存在 |
| `file_parser` | 检查文件路径是否可读 |
| `integration` | 检查平台相关环境变量或配置 |
| `jupyter` | 检查 hamelnb 脚本路径 `$HOME/.agent-skills/hamelnb/` 是否存在 |
| `sandbox` | 检查必要目录是否存在 |
| `code_gen` | 检查代码生成相关依赖 |

**注意**：`jupyter` 类型不检查任何 API key 环境变量，因为它是本地 Jupyter 连接工具。

### 第六步：执行测试

根据技能类型执行实际测试：

#### `api` 类型
```python
import time
t0 = time.time()
try:
    if skill == "minimax-image-generation":
        result = minimax_image_generate("test prompt", aspect_ratio="1:1")
        result_data = json.loads(result)
        success = result_data.get("success", False)
        output_valid = "image" in result_data
    # 其他 API 技能类似
except Exception as e:
    success = False
    error = str(e)
latency_ms = int((time.time() - t0) * 1000)
```

#### `cli` 类型
```python
import subprocess, shutil
cmd = skill_config.get("command", skill_name)
t0 = time.time()
try:
    result = subprocess.run(cmd, shell=True, capture_output=True, timeout=30)
    exit_code = result.returncode
    success = exit_code == 0
except subprocess.TimeoutExpired:
    success = False
    error = "timeout"
latency_ms = int((time.time() - t0) * 1000)
```

#### `file_parser` 类型
```python
import time
t0 = time.time()
with open(skill_path) as f:
    content = f.read()
    parsed = yaml.safe_load(content)  # 尝试解析
success = parsed is not None
latency_ms = int((time.time() - t0) * 1000)
output_valid = "name" in parsed if parsed else False
```

#### 其他类型
执行通用测试：读取文件 + 基础验证

### 第七步：性能稳定性审核

读取 `trends.json` 中该技能的历史数据：

```python
history = [r for r in trends.get("records", []) if r["skill"] == current_skill]
if history:
    last = history[-1]
    delta_pct = (latency_ms - last["latency_ms"]) / last["latency_ms"] * 100
    if abs(delta_pct) <= 10:
        perf_stable = "stable"
    elif delta_pct > 10:
        perf_stable = "degraded"
    else:
        perf_stable = "improved"
```

| 状态 | 判断标准 |
|------|---------|
| `stable` | 变化 ≤ ±10% |
| `degraded` | 变慢 > 10% |
| `improved` | 变快 > 10% |

### 第八步：错误率审核

统计该技能历史记录中的错误：

```python
total_runs = len([r for r in history if r["skill"] == current_skill])
error_runs = len([r for r in history if r["status"] != "success"])
error_rate = (error_runs / total_runs * 100) if total_runs > 0 else 0
```

| 错误率 | 评分 |
|--------|------|
| 0% | pass |
| < 5% | warning |
| >= 5% | fail |

### 第九步：生成完整审核报告

```json
{
  "task": "skill_cycle_optimizer",
  "timestamp": "2026-04-17T08:00:00",
  "current_index": 5,
  "total_skills": 83,
  "current": {
    "skill": "minimax-image-generation",
    "category": "media",
    "type": "api",
    "metrics": {
      "latency_ms": 8500,
      "success": false,
      "output_valid": true,
      "error": "MINIMAX_API_KEY not set"
    },
    "audit": {
      "doc_complete": "pass",
      "dep_available": "fail",
      "load_time_ms": 12,
      "error_rate_pct": 0,
      "perf_stable": "stable",
      "output_valid": true
    },
    "vs_last": null,
    "suggestions": [
      "依赖不可用: MINIMAX_API_KEY 未设置，建议配置或标记为 manual_only"
    ],
    "status": "warning"
  },
  "summary": {
    "audit_passed": 5,
    "audit_warnings": 1,
    "action": "依赖缺失，需要配置"
  }
}
```

### 第十步：保存所有数据

1. `~/.hermes/evolution_logs/skill_optimizer/current_benchmark.json`（覆盖）
2. `~/.hermes/evolution_logs/skill_optimizer/history/YYYYMMDD_HHMMSS_<skill>.json`
3. `~/.hermes/evolution_logs/skill_optimizer/trends.json`（追加）
4. `~/.hermes/evolution_logs/skill_optimizer/state.json`（更新索引）

### 第十一步：SkillTree 健康度记录

每次技能审核完成后，将结果写入 SkillTree：

```python
import sys
sys.path.insert(0, "/data/data/com.termux/files/home/hermes-agent")

from hermes_agent.evolution import SkillTree

st = SkillTree()
st.record_invocation(
    skill_name=current_skill,
    success=(report["current"]["status"] in ("healthy", "warning")),
    latency_ms=latency_ms,
    tags=skill_tags,
    category=skill_category,
)
```

### 第十二步：GapAnalyzer 缺口分析

每轮技能测试后运行缺口分析，识别系统性改进机会：

```python
from hermes_agent.evolution import GapAnalyzer

ga = GapAnalyzer()
gaps = ga.run_full_analysis()
if gaps:
    report_path = ga.save_report(gaps)
    print(f"🔍 Gap分析: 发现 {len(gaps)} 个缺口，已保存到 {report_path}")
    # 高 severity 缺口自动输出建议
    critical = [g for g in gaps if g.severity in ("critical", "high")]
    for g in critical:
        print(f"  [{g.severity}] {g.title}: {g.suggested_action}")
```

### 失败信号监控（每轮测试后执行）

每次技能测试完成后，立即运行完整的 HERMES DOJO 闭环：

```python
import subprocess, sys

LOG = Path.home() / ".hermes/evolution_logs/skill_optimizer"
MONITOR  = LOG / "monitor.py"
ANALYZER = LOG / "analyzer.py"
FIXER    = LOG / "fixer.py"
REPORTER = LOG / "reporter.py"
LEARNING = LOG / "learning_curve.py"
APPLY    = LOG / "apply_fixes.py"

# Step 1: Monitor — 采集失败信号
r = subprocess.run([sys.executable, str(MONITOR)], capture_output=True, text=True, timeout=30)
print(r.stdout)

# Step 2: Analyzer v2 — 动态评分
r = subprocess.run([sys.executable, str(ANALYZER)], capture_output=True, text=True, timeout=30)
print(r.stdout)

# Step 3: Fixer v2 — 诊断并输出修复方案（dry-run）
r = subprocess.run([sys.executable, str(FIXER), "--dry-run"], capture_output=True, text=True, timeout=60)
print(r.stdout)

# Step 4: Reporter — 生成 CLI/JSON 报告
r = subprocess.run([sys.executable, str(REPORTER)], capture_output=True, text=True, timeout=15)
print(r.stdout)

# Step 5: Learning Curve — 记录长期趋势
r = subprocess.run([sys.executable, str(LEARNING)], capture_output=True, text=True, timeout=15)
print(r.stdout)

# Step 6: Auto-Fixer — 检查可自动修复的内容（dry-run）
r = subprocess.run([sys.executable, str(APPLY), "--dry-run"], capture_output=True, text=True, timeout=30)
print(r.stdout)

# 飞书推送（可选）
from hermes_tools import send_message
send_message(action="send", target="feishu", message=dojo_report_text)
```

**完整数据流**：
```
trends.json（测试结果） ──┐
                          ├──► Monitor ──► failure_signals.json
error_ledger.md（错误） ──┘         │
                                    ▼
                         Analyzer v2 ──► improvement_plan.json
                                                  │
                                    ┌─────────────┴─────────────┐
                                    ▼                           ▼
                          Fixer v2                         Auto-Fixer
                          fixes_pending/                  (仅 doc_fail)
                          *_diag_v2.json
                          *_fix_v2.json
                                    │                           │
                                    └───────── human review ────┘
                                                   │
                                                   ▼
                                            修复 → 重新测试 → 闭环
```

**各模块职责**：

| 模块 | 职责 | 输出文件 |
|------|------|---------|
| Monitor | 采集48h内失败信号 | `failure_signals.json` |
| Analyzer v2 | 动态评分 → 决策 | `improvement_plan.json` |
| Fixer v2 | 诊断依赖 + 方案生成 | `fixes_pending/*.json` |
| Auto-Fixer | 对 doc_fail 执行写入 | 修改 SKILL.md（需 --approve）|
| Reporter | 生成 CLI/JSON 报告 | `reports/*.txt` |
| Learning Curve | 长期趋势 + WoW 对比 | `skill_history.json` |

**决策类型与对应动作**：

| Decision | 含义 | Fixer 行为 |
|----------|------|-----------|
| `deep_review` | 运行时错误 | 输出诊断报告，跳过自动修复 |
| `new_skill` | 文档问题 | 生成修复方案（auto_fixable=doc_fail） |
| `add_rule` | 需加规则 | 写入 HEARTBEAT.md |
| `archive` | 低优先级 | 归档，仅记录 |

**已知问题**：
- `error_ledger.md` 格式变化时 Monitor 正则解析会失效
- Fixer 的 `check_python_deps` 依赖 frontmatter `dependencies` 字段，字段为空时从 body 扫描 import，准确度降低
- deep_review 类型需要 human review 后手动处理，不自动执行

---

### 情报收集流程（index % 6 == 0 时执行）

**重要**：情报收集**不能**在 `execute_code` 中调用 MCP 工具。必须作为独立的**工具调用**执行。

当 `current_index % 6 == 0` 时，**分两步执行**：

#### 步骤 A（在 execute_code 中准备数据 + 保存占位）

```python
import json
from pathlib import Path
from datetime import datetime

hermes_home = Path.home() / ".hermes"
log_base = hermes_home / "evolution_logs" / "skill_optimizer"
intel_path = log_base / "intelligence_latest.json"
intel_path.parent.mkdir(parents=True, exist_ok=True)

# 先写入占位数据，标记为待填充
intel_data = {
    "collected_at": datetime.now().isoformat(),
    "collection_status": "pending",
    "hermes": {"stars": "", "position_trend": "", "recent_changes": []},
    "ecosystem": {"rising_stars": [], "falling": [], "new_entrants": [], "trending_topics": []},
    "insights": []
}
with open(intel_path, "w") as f:
    json.dump(intel_data, f, indent=2, ensure_ascii=False)

print(f"占位情报已保存: {intel_path}")
print("下一步: 使用 mcp_minimax_web_search 工具执行实际搜索")
```

#### 步骤 B（作为独立工具调用执行 web 搜索）

使用 `mcp_minimax_web_search` 工具对以下查询执行搜索：

1. `site:github.com/trending?since=weekly`
2. `github trending AI agent framework 2026 April`
3. `open source AI agent github stars ranking 2026`
4. `site:github.com/NousResearch/hermes-agent/releases`
5. `new AI agent framework released 2026 April`
6. `AI agent trending this week github`

每次搜索后，解析结果并更新 `intelligence_latest.json`。如果 API 返回 auth 错误，跳过该查询并记录。

#### 步骤 C（更新情报文件并执行闭环）

在 `execute_code` 中读取收集到的情报，执行 intelligence-action-loop 闭环逻辑：

```python
import json
from pathlib import Path

intel_path = Path.home() / ".hermes/evolution_logs/skill_optimizer/intelligence_latest.json"
with open(intel_path) as f:
    intel = json.load(f)

# 更新 collection_status
intel["collection_status"] = "complete"
with open(intel_path, "w") as f:
    json.dump(intel, f, indent=2, ensure_ascii=False)

# 情报闭环
from hermes_tools import skill_view
skill_view(name="intelligence-action-loop")
# 执行 intelligence-action-loop 的决策逻辑
```

**已知失败模式**：`mcp_minimax_web_search` 调用失败（auth error）时，直接跳过，不要在 `execute_code` 中尝试调用。

---

## 审核评分标准

| 审核项 | pass | warning | fail |
|--------|------|---------|------|
| `doc_complete` | 所有字段完整 | 缺少非关键字段 | 缺少 name/description |
| `dep_available` | 依赖都可用 | 部分缺失 | 核心依赖缺失 |
| `load_time` | < 500ms | 500-2000ms | > 2000ms |
| `error_rate` | 0% | < 5% | >= 5% |
| `perf_stable` | ±10% 内 | - | 变慢 > 10% |
| `output_valid` | 格式正确 | - | 格式错误或空 |

**最终状态判断：**
- `healthy`：所有审核项 pass
- `warning`：有 warning 项但无 fail
- `degraded`：有 fail 项

---

## 目录结构

```
~/.hermes/evolution_logs/skill_optimizer/
├── current_benchmark.json    # 当前测试报告
├── state.json               # 进度状态
├── trends.json              # 历史趋势（30条）
├── failure_signals.json     # Monitor 输出：失败信号
├── improvement_plan.json    # Analyzer 输出：改进决策（v2 动态评分）
├── skill_history.json       # Learning Curve：每日快照时间序列
├── monitor.py              # Monitor 模块（采集失败信号）
├── analyzer.py             # Analyzer 模块（v2 动态评分）
├── fixer.py               # Fixer 模块（v2 诊断+方案生成）
├── reporter.py             # Reporter 模块（CLI/JSON/飞书卡片报告）
├── learning_curve.py       # Learning Curve 模块（WoW 趋势对比）
├── apply_fixes.py          # Auto-Fixer（实际执行 doc_fail 修复）
├── dojo.py                # 完整闭环编排（一键运行全部6步）
├── fixes_pending/          # 待审批修复方案（Fixer 输出）
│   ├── _fixer_summary_v2.json
│   ├── <skill>_diag_v2.json      # 深度检修诊断报告
│   └── <skill>_fix_v2.json       # 文档修复方案
├── reports/                # 历史日报存档
│   └── report_YYYYMMDD_HHMMSS.txt
└── backups/               # Auto-Fixer 备份（修改前快照）
    └── YYYYMMDD_HHMMSS_<skill>.md
```

~/.hermes/evolution_logs/gap_analyzer/   # GapAnalyzer 输出
~/.hermes/evolution_logs/skill_tree/     # SkillTree 健康数据
~/.hermes/evolution_logs/cost_router/    # CostAwareRouter 路由日志
```

## 注意事项

- API 技能测试可能因为缺少 key 而失败，这是**预期行为**，记录但不阻塞
- CLI 技能如果没有对应命令，标记为 `manual_only`
- 沙箱测试后清理所有临时文件
- trends.json 只保留最近 30 条记录
- 递归避免：不要对 `skill-cycle-optimizer` 本身执行实际 API 调用
- **导入新模块**时需先将 hermes-agent 路径加入 sys.path：
  ```python
  import sys
  sys.path.insert(0, "/data/data/com.termux/files/home/hermes-agent")
  from hermes_agent.evolution import GapAnalyzer, SkillTree, CostAwareRouter
  ```

---

## 已知 Bug 和修复记录

### Bug 1: YAML frontmatter 解析错误（2026-04-17）

**问题现象**: `imessage` 技能有完整的 `name:` 和 `description:`，但审核报告 `doc_complete: fail`。

**根因**: 用正则 `re.search(r'^name:\s*\S', fm_text, re.MULTILINE)` 匹配多行文本时，位置判断错误；且只读取前 5 行，无法处理不同格式。

**正确做法**:
```python
import yaml

def parse_frontmatter(skill_md_path):
    with open(skill_md_path) as f:
        content = f.read()
    if not content.startswith("---"):
        return None, content
    # 找到第二个 --- 的位置
    end_idx = content.find("\n---\n", 3)
    if end_idx == -1:
        end_idx = content.find("\n---", 3)
        if end_idx == -1:
            return None, content
    yaml_text = content[3:end_idx].strip()
    body = content[end_idx+4:]
    try:
        frontmatter = yaml.safe_load(yaml_text)
    except yaml.YAMLError:
        return None, content
    return frontmatter, body
```

### Bug 2: 递归扫描技能列表遗漏（2026-04-17）

**问题现象**: 83 个技能中只扫到 1 个（dogfood），其余 82 个嵌套在子目录中的技能全部漏掉。

**根因**: 用 `skills_dir.iterdir()` 只扫描一层目录，很多技能在 `software-development/plan`、`apple/imessage` 等嵌套路径下。

**正确做法**:
```python
all_skills = []
for md_path in sorted(skills_dir.rglob("SKILL.md")):
    rel = md_path.relative_to(skills_dir)
    category = str(rel.parent)  # e.g. "apple/imessage"
    all_skills.append((category, md_path))
all_skills.sort(key=lambda x: x[0])
total_skills = len(all_skills)
```

### Bug 3: trends.json 写入 audit 字段路径错误（2026-04-17）

**问题现象**: trends.json 中每条记录的 `audit` 字段为空（`{}`），导致历史性能对比失效。

**根因**: `report["audit"]` 不存在，实际路径是 `report["current"]["audit"]`。

**正确做法**:
```python
audit_result = report["current"]["audit"]  # 不是 report["audit"]
trends["records"].append({..., "audit": audit_result})
```

### Bug 4: Cron Job 不加载更新后的 Skill 代码（2026-04-19）

**问题现象**: 更新了 skill-cycle-optimizer 的 SKILL.md 后，手动触发 cron job，情报收集轮次仍未执行。原因是 cron job 在创建时就固定了 prompt 内容，后续更新 skill 文件不会影响已创建的 job。

**解决方案**:
- 方案1：删除旧 cron job，重新创建（`cronjob remove` + 重新 `create`）
- 方案2：手动执行情报收集，将结果写入 `intelligence_latest.json`
- 方案3：创建新的独立 cron job 专门做情报收集，与技能测试分离

**验证**: 更新 skill 后检查 job 的 `prompt_preview` 是否包含新内容，或直接查看 `intelligence_latest.json` 是否更新。

### Bug 5: execute_code 跨调用状态不持久（2026-04-19）

**问题现象**: 技能执行时多次出现 `NameError: name 'xxx' is not defined`，例如 `log_base`、`current_path` 等变量在第二次 `execute_code` 调用时未定义。

**根因**: `execute_code` 每次调用都是全新 Python 进程，**所有变量和 import 均不跨调用保留**。脚本不能假设前一步定义的变量在后一步中仍然存在。

**正确做法**:
- 将完整工作流封装在**单个** `execute_code` 调用中
- 所有 import、函数定义、变量初始化都放在同一个代码块开头
- 不要拆分到多个 `execute_code` 调用中执行逐步调试

```python
# ✅ 正确：所有步骤在一个 execute_code 中
import json, yaml, time
from pathlib import Path

hermes_home = Path.home() / ".hermes"
skills_dir = hermes_home / "skills"
log_base = hermes_home / "evolution_logs" / "skill_optimizer"

def parse_frontmatter(path):
    ...

# ... 所有后续步骤 ...
# Step 1: scan
# Step 2: read state
# Step 3: determine skill
# Step 4-9: audit + test + save
print("Done")
```

```python
# ❌ 错误：跨调用依赖变量（会 NameError）
# --- 第一次调用 ---
log_base = Path.home() / ".hermes/evolution_logs/skill_optimizer"
# --- 第二次调用 ---
# log_base 未定义！
state_path = log_base / "state.json"  # NameError
```

**验证**: 技能执行过程中如果出现 `NameError`，立即将所有步骤合并到单一 `execute_code` 调用中重试。

### Bug 6: 情报收集中不能在 execute_code 里调用 MCP 工具（2026-04-21）

**问题现象**: 在 `execute_code` 中调用 `mcp_minimax_web_search(...)` 时出现 `NameError: name 'mcp_minimax_web_search' is not defined`。

**根因**: MCP 工具（如 `mcp_minimax_web_search`）是 agent 工具，只能通过 agent 的工具调用机制使用。`execute_code` 是独立 Python 进程，**不继承** agent 的工具函数命名空间。两者是完全独立的调用路径。

**正确做法**:
1. 在 `execute_code` 中准备好 `intel_data` 结构并写入 `intelligence_latest.json`（占位）
2. 然后用**独立的工具调用** `mcp_minimax_web_search` 执行实际搜索
3. 搜索完成后回到 `execute_code` 更新情报文件并执行闭环

```python
# ❌ 错误：在 execute_code 中调用 mcp_minimax_web_search
# 这会 NameError，因为 execute_code 没有这个函数
result = mcp_minimax_web_search(query="...")

# ✅ 正确：execute_code 只负责文件 IO
# 实际搜索用独立的工具调用
intel_data = {"collection_status": "pending", ...}
with open(intel_path, "w") as f:
    json.dump(intel_data, f)
print("请在下一步使用 mcp_minimax_web_search 工具执行搜索")
```

**验证**: 如果 `execute_code` 报 `NameError` 且错误信息包含 MCP 工具名，就说明违反了此规则。

### Bug 7: `success=None` 被错误计为失败（2026-04-28）

**问题现象**: 通过率显示 0-14%，但实际测试大部分通过。google-workspace 明明 `success=true` 却被计入失败。

**根因**: `not r.get("success")` 对 `None` 返回 `True`，将"测试无法运行"错误分类为"测试失败"。同时 `skill_history.json` 的 `passed` 字段计算也有同样问题——`if r.get("success")` 对 `None` 返回 `False`。

**正确做法**: 使用显式三值判断：
```python
def classify_run(r):
    success = r.get("success")
    status = r.get("status", "")
    error = str(r.get("error", "") or "").lower()
    EXPECTED_PATTERNS = ("not configured", "not installed", "not set", "not found", "missing", "unavailable")
    if success is True:
        return "pass"
    if success is None and status in ("healthy", "pass", "warning"):
        return "pass"  # 旧 schema 兼容
    if success is False:
        if any(p in error for p in EXPECTED_PATTERNS):
            return "expected_fail"  # 环境缺失，不算真正失败
        return "unexpected_fail"
    return "not_run"  # success=None 且无 healthy status → 未运行
```

**影响范围**: `reporter.py`（通过率计算）+ `learning_curve.py`（历史快照生成）+ `trends.json`（历史记录）

### Bug 8: trends.json 历史记录 schema 不一致（2026-04-28）

**问题现象**: 不同时间生成的 history 文件使用了不同 schema——新 schema 把结果嵌套在 `current.metrics` 下，旧 schema 直接放在顶层。导致分析工具读不到正确字段。

**根因**: skill-cycle-optimizer 在不同阶段迭代了不同版本的输出格式，但 trends.json 是追加写入的，混入了新旧两种格式。

**正确做法**: 读取 history 文件时同时兼容两种 schema：
```python
if "current" in data:
    # 新 schema
    skill = data["current"].get("skill", "?")
    success = data["current"].get("metrics", {}).get("success")
    error = data["current"].get("metrics", {}).get("error", "")
else:
    # 旧 schema
    skill = data.get("skill", "?")
    success = data.get("success")
    error = data.get("error", "")
```

**修复措施**: 已重建 `trends.json`（从 117 个 history 文件重新生成），以后 history 文件统一用新 schema。

### Bug 9: xiaoa-persona-system 重复注册导致双重统计（2026-04-28）

**问题现象**: `xiaoa-persona-system` 和 `mlops/xiaoa-persona-system` 都存在，前者是 0 字节空文件，后者是真实内容。rglob 扫描会扫到两个路径，导致同一个技能的失败被计两次。

**根因**: 历史上复制/移动技能时在两个路径各创建了一份。

**正确做法**: 删除空文件：
```bash
rm ~/.hermes/skills/xiaoa-persona-system/SKILL.md
# mlops/xiaoa-persona-system/SKILL.md 保留
```
同时在 `fixes_pending` 中清除对应的空修复方案。

### Bug 10: 修复后 trends.json 写入仍是错的（2026-04-28）

**问题现象**: 修了 reporter.py 和 learning_curve.py 的分类逻辑，但 trends.json 里存的仍是旧的错误分类（`success=None` 已被错误地当作 `false` 写入）。

**根因**: 这两个模块只读取 trends.json 计算，从不修改它。真正的写入发生在 skill-cycle-optimizer 执行测试时，它把 `success=True` 的 google-workspace 写成了什么？

**验证**: 读取 history 文件而不是 trends.json 作为数据源，可彻底绕过已损坏的数据。

The user has provided the following instruction alongside the skill invocation: