#!/usr/bin/env bash
# cmd_log_append.sh
# Append-only event logger for queue/cmd_log.yaml.
#
# Usage:
#   cmd_log_append.sh <task_id> <event_type> <actor> <payload_yaml_inline> [parent_cmd] [severity]
#
# Arguments:
#   task_id              — task_<NNN>[<a-z>] format (e.g., task_064a)
#   event_type           — cmd_issued | cmd_acknowledged | cmd_dispatched
#                          | cmd_qc_started | cmd_aggregated | cmd_completed
#   actor                — ojousama | kaseifu | shitsuji | maid_NN
#   payload_yaml_inline  — YAML inline mapping (e.g., '{key: val}'); empty -> '{}'
#   parent_cmd           — parent task_id (optional; emits parent_cmd: null when absent)
#   severity             — low | medium | high | critical (optional; default low)
#
# Exit codes:
#   0  — append succeeded
#   1  — argument error (missing or invalid)
#   2  — lock timeout (concurrent writer held the lock too long)
#
# Design (task_064a / task_063 cmd_log_design Section 1):
#   - Append-only: uses '>>' redirection only. Never edits existing events.
#   - Lock: mkdir queue/.lock-cmd_log (mirrors scripts/inbox_write.sh pattern).
#     Busy -> sleep 0.2s, retry up to 25 times (= 5s) before giving up rc=2.
#   - F-RULE-04 compliant: single-shot append. No watcher loops, no polling.
#   - event_id: evt_<NNNN>_<task_id>_<event_type> where NNNN = current event count + 1.

set -uo pipefail
# NOTE: -e intentionally OFF; we want to handle lock-acquire failure explicitly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QUEUE_DIR="$PROJECT_ROOT/queue"
CMD_LOG="$QUEUE_DIR/cmd_log.yaml"
LOCK_DIR="$QUEUE_DIR/.lock-cmd_log"

usage() {
    cat <<EOF >&2
Usage: $0 <task_id> <event_type> <actor> <payload_yaml_inline> [parent_cmd] [severity]

Required:
  task_id              task_<NNN>[<a-z>] (e.g., task_064a)
  event_type           cmd_issued | cmd_acknowledged | cmd_dispatched | cmd_qc_started | cmd_aggregated | cmd_completed
  actor                ojousama | kaseifu | shitsuji | maid_NN
  payload_yaml_inline  YAML inline mapping ('{}' when empty)

Optional:
  parent_cmd           parent task_id (default: null)
  severity             low | medium | high | critical (default: low)

Exit codes: 0=ok, 1=arg error, 2=lock timeout
EOF
}

TASK_ID="${1:-}"
EVENT_TYPE="${2:-}"
ACTOR="${3:-}"
PAYLOAD_INLINE="${4:-}"
PARENT_CMD="${5:-}"
SEVERITY="${6:-low}"

if [ -z "$TASK_ID" ] || [ -z "$EVENT_TYPE" ] || [ -z "$ACTOR" ] || [ -z "${4-}" ]; then
    usage
    exit 1
fi

case "$EVENT_TYPE" in
    cmd_issued|cmd_acknowledged|cmd_dispatched|cmd_qc_started|cmd_aggregated|cmd_completed) ;;
    *)
        echo "[ERROR] invalid event_type: $EVENT_TYPE" >&2
        usage
        exit 1
        ;;
esac

case "$SEVERITY" in
    low|medium|high|critical) ;;
    *)
        echo "[ERROR] invalid severity: $SEVERITY" >&2
        exit 1
        ;;
esac

if [ ! -f "$CMD_LOG" ]; then
    echo "[ERROR] cmd_log not found: $CMD_LOG" >&2
    exit 1
fi

# Default empty payload to '{}'.
if [ -z "$PAYLOAD_INLINE" ]; then
    PAYLOAD_INLINE="{}"
fi

acquire_lock() {
    local tries=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        tries=$((tries + 1))
        if [ "$tries" -gt 25 ]; then
            echo "[ERROR] failed to acquire lock after 25 tries: $LOCK_DIR" >&2
            exit 2
        fi
        sleep 0.2
    done
}

release_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

trap release_lock EXIT

acquire_lock

# Compute next sequence number from existing event_id entries (lock held).
# NOTE: grep -c with no match returns rc=1 but still emits "0"; using `|| echo 0`
# would double-emit "0\n0" and break $((...)). Read the count plainly and
# fall back to 0 only when the variable is empty.
EVENT_COUNT="$(grep -cE '^  - event_id:' "$CMD_LOG" 2>/dev/null)"
[ -z "$EVENT_COUNT" ] && EVENT_COUNT=0
NEXT_SEQ=$((EVENT_COUNT + 1))
SEQ_PADDED="$(printf '%04d' "$NEXT_SEQ")"
EVENT_ID="evt_${SEQ_PADDED}_${TASK_ID}_${EVENT_TYPE}"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Render parent_cmd: quoted task_id or unquoted null.
if [ -z "$PARENT_CMD" ]; then
    PARENT_CMD_LINE='    parent_cmd: null'
else
    PARENT_CMD_LINE="    parent_cmd: \"${PARENT_CMD}\""
fi

# If events: is the empty inline list, normalize it to a block list before append.
if grep -qE '^events:[[:space:]]*\[\][[:space:]]*$' "$CMD_LOG"; then
    TMP_NORM="$CMD_LOG.norm.$$"
    awk '
        /^events:[[:space:]]*\[\][[:space:]]*$/ { print "events:"; next }
        { print }
    ' "$CMD_LOG" > "$TMP_NORM"
    mv "$TMP_NORM" "$CMD_LOG"
fi

# Append-only write. Never edits existing entries.
{
    echo "  - event_id: \"${EVENT_ID}\""
    echo "    ts: \"${TS}\""
    echo "    event_type: \"${EVENT_TYPE}\""
    echo "    task_id: \"${TASK_ID}\""
    echo "${PARENT_CMD_LINE}"
    echo "    actor: \"${ACTOR}\""
    echo "    payload: ${PAYLOAD_INLINE}"
    echo "    severity: \"${SEVERITY}\""
} >> "$CMD_LOG"

echo "[OK] appended ${EVENT_ID}"
exit 0
