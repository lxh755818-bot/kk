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
        \"message_id\": \"msg_\$(date +%s)_\$\$\",
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

# ====== Step 2: 遍历所有任务，直到认领成功或全部失败 ======
log "Attempting to claim tasks from pool of $TASK_COUNT..."

# 用 python 提取所有 task_id 到临时文件
echo "$TASK_JSON" | python3 -c "
import sys, json
tasks = json.load(sys.stdin)
for t in tasks:
    tid = t.get('task_id', '')
    if tid:
        print(tid)
" 2>/dev/null > "$VALIDATION_DIR/task_ids.txt"

CLAIMED=0
while IFS= read -r TASK_ID; do
    [ -z "$TASK_ID" ] && continue
    
    log "Attempting to claim task: $TASK_ID"

    # 认领格式：不用 protocol envelope，直接 {"task_id": "...", "node_id": "..."}
    CLAIM_RESP=$(curl -s -X POST "https://evomap.ai/a2a/task/claim" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $NODE_SECRET" \
        -d "{\"task_id\": \"$TASK_ID\", \"node_id\": \"$NODE_ID\"}" 2>/dev/null)

    # 修复 Bug 1：同时检查 status 和 error 字段
    CLAIM_STATUS=$(echo "$CLAIM_RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # 优先检查 error 字段（task_full 等场景）
    err = d.get('error', '')
    if err:
        print('error_' + err)
    else:
        print(d.get('status', d.get('payload', {}).get('status', 'unknown')))
except:
    print('parse_error')
" 2>/dev/null || echo "error")

    log "Claim response: $CLAIM_STATUS"

    if echo "$CLAIM_STATUS" | grep -qE "claimed|success|accepted" && ! echo "$CLAIM_STATUS" | grep -q "error"; then
        log "Task claimed: $TASK_ID"
        echo "$CLAIM_RESP" > "$VALIDATION_DIR/claimed_$TASK_ID.json"
        CLAIMED=1
        
        # ====== Step 3: 获取任务详情 ======
        TASK_DETAIL=$(curl -s "https://evomap.ai/a2a/task/$TASK_ID?sender_id=$NODE_ID&message_id=msg_$(date +%s)" \
            -H "Authorization: Bearer $NODE_SECRET" 2>/dev/null)
        echo "$TASK_DETAIL" > "$VALIDATION_DIR/task_detail_$TASK_ID.json"
        
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
        log "Task data saved, validation pending"
        break

    elif echo "$CLAIM_STATUS" | grep -qE "error_task_full|error_conflict|error_duplicate|full|conflict|duplicate"; then
        log "Task $TASK_ID is full/conflict, trying next..."
        echo "$CLAIM_RESP" > "$VALIDATION_DIR/claim_full_$TASK_ID.json"
        continue
    else
        log "Claim failed for $TASK_ID: $CLAIM_RESP"
        echo "$CLAIM_RESP" > "$VALIDATION_DIR/claim_failed_$TASK_ID.json"
        continue
    fi
done < "$VALIDATION_DIR/task_ids.txt"

if [ "$CLAIMED" = "0" ]; then
    log "All tasks claim failed or none available"
fi

rm -f "$PID_FILE"
