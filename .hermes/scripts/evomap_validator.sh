#!/data/data/com.termux/files/usr/bin/bash
# EvoMap Validator Cron — 从 discover 拉取任务，认领后执行验证并提交报告
# 
# Bug 修复历史：
#   2026-04-28: 修复 discover 过滤器（去掉 opportunity_type）和认领格式（去掉 protocol envelope）

set -e
cd /data/data/com.termux/files/home

# 加载凭证
source /data/data/com.termux/files/home/.hermes/.env 2>/dev/null || true
NODE_ID="${EVOMAP_NODE_ID:-node_401b20c3dc6f18ea}"
NODE_SECRET="${EVOMAP_NODE_SECRET}"
VALIDATION_DIR="/data/data/com.termux/files/home/.hermes/evomap_validations"
LOG="$VALIDATION_DIR/validator.log"
mkdir -p "$VALIDATION_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

# 防止并发重叠
PID_FILE="$VALIDATION_DIR/validator.pid"
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        log "Validator already running (PID $OLD_PID), skipping"
        exit 0
    fi
fi
echo $$ > "$PID_FILE"

# ====== Step 1: Discover 任务（不过滤，直接读 result.tasks）======
log "Discovering available tasks..."

DISCOVER_RESP=$(curl -s -X POST "https://evomap.ai/a2a/discover" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $NODE_SECRET" \
    -d "{
        \"protocol\": \"gep-a2a\",
        \"protocol_version\": \"1.0.0\",
        \"message_type\": \"discover\",
        \"sender_id\": \"$NODE_ID\",
        \"message_id\": \"msg_$(date +%s)_\$\$\",
        \"timestamp\": \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"payload\": {\"max_results\": 5}
    }" 2>/dev/null)

# 关键修复：从 result.tasks 读（不是 result.payload.tasks）
TASK_JSON=$(echo "$DISCOVER_RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    tasks = d.get('tasks', d.get('payload', {}).get('tasks', []))
    print(json.dumps(tasks))
except:
    print('[]')
" 2>/dev/null || echo "[]")

TASK_COUNT=$(echo "$TASK_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
log "Discovered $TASK_COUNT tasks"

if [ "$TASK_COUNT" = "0" ] || [ "$TASK_COUNT" = "" ]; then
    log "No tasks available, exiting"
    rm -f "$PID_FILE"
    exit 0
fi

# ====== Step 2: 尝试认领第一个任务 ======
FIRST_TASK=$(echo "$TASK_JSON" | python3 -c "
import sys, json
tasks = json.load(sys.stdin)
if tasks:
    print(tasks[0].get('task_id',''))
" 2>/dev/null || echo "")

if [ -z "$FIRST_TASK" ]; then
    log "No valid task_id found"
    rm -f "$PID_FILE"
    exit 0
fi

log "Attempting to claim task: $FIRST_TASK"

# 认领格式：不用 protocol envelope，直接 {"task_id": "...", "node_id": "..."}
CLAIM_RESP=$(curl -s -X POST "https://evomap.ai/a2a/task/claim" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $NODE_SECRET" \
    -d "{\"task_id\": \"$FIRST_TASK\", \"node_id\": \"$NODE_ID\"}" 2>/dev/null)

CLAIM_STATUS=$(echo "$CLAIM_RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('status', d.get('payload', {}).get('status', 'unknown'))
except:
    print('parse_error')
" 2>/dev/null || echo "error")

ALREADY_JOINED=$(echo "$CLAIM_RESP" | python3 -c "
import sys,json; d=json.load(sys.stdin); print('true' if d.get('already_joined') else 'false')
" 2>/dev/null)

log "Claim response status: $CLAIM_STATUS (already_joined=$ALREADY_JOINED)"

# 若 already_joined=true，先查本节点是否已有 pending submission，有则跳过
if [ "$ALREADY_JOINED" = "true" ]; then
    log "Task already joined: $FIRST_TASK — checking submission status..."
    MY_SUBMISSION=$(curl -s "https://evomap.ai/a2a/task/my?node_id=$NODE_ID" \
        -H "Authorization: Bearer $NODE_SECRET" 2>/dev/null | \
        python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for t in d.get('tasks', []):
        if t.get('task_id') == '$FIRST_TASK':
            print(t.get('my_submission_status', 'none'))
            break
    else:
        print('none')
except:
    print('none')
" 2>/dev/null)
    if [ "$MY_SUBMISSION" = "pending" ] || [ "$MY_SUBMISSION" = "accepted" ]; then
        log "Task $FIRST_TASK already has submission ($MY_SUBMISSION) — skipping validation"
        rm -f "$PID_FILE"
        exit 0
    else
        log "No active submission found (status: $MY_SUBMISSION), will proceed with validation"
    fi
fi

if echo "$CLAIM_STATUS" | grep -qE "claimed|success|accepted" || [ "$ALREADY_JOINED" = "true" ]; then
    log "Task claimed: $FIRST_TASK"
    echo "$CLAIM_RESP" > "$VALIDATION_DIR/claimed_$FIRST_TASK.json"
    
    # ====== Step 3: 获取任务详情并执行验证 ======
    TASK_DETAIL=$(curl -s "https://evomap.ai/a2a/task/$FIRST_TASK?sender_id=$NODE_ID&message_id=msg_$(date +%s)" \
        -H "Authorization: Bearer $NODE_SECRET" 2>/dev/null)
    
    echo "$TASK_DETAIL" > "$VALIDATION_DIR/task_detail_$FIRST_TASK.json"
    
    # 提取 signals 和 question
    QUESTION=$(echo "$TASK_DETAIL" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    t = d.get('task', {})
    print(t.get('title', '')[:200])
except:
    print('')
" 2>/dev/null || echo "")
    
    SIGNALS=$(echo "$TASK_DETAIL" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    t = d.get('task', {})
    print(t.get('signals', '')[:300])
except:
    print('')
" 2>/dev/null || echo "")
    
    log "Task: $QUESTION"
    log "Signals: $SIGNALS"
    
    # 验证后提交报告
    # (这里需要根据任务类型执行实际验证，暂存原始数据供人工审查)
    log "Task data saved for review, validation pending"
    
elif echo "$CLAIM_STATUS" | grep -qE "full|conflict|duplicate"; then
    log "Task $FIRST_TASK is full/conflict, skipping"
    echo "$CLAIM_RESP" > "$VALIDATION_DIR/claim_full_$FIRST_TASK.json"
else
    log "Claim failed: $CLAIM_RESP"
    echo "$CLAIM_RESP" > "$VALIDATION_DIR/claim_failed_$FIRST_TASK.json"
fi

rm -f "$PID_FILE"
