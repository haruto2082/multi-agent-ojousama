#!/usr/bin/env bash
# watchdog.sh
# Detects stalled task reports (kaseifu_to_ojousama) and notifies via tmux + ntfy.
# Designed to be invoked periodically by launchd (every 5 minutes).
# F-RULE-04: This script itself does NOT loop; it is one-shot, externally driven.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CMD_FILE="$PROJECT_ROOT/queue/ojousama_to_kaseifu.yaml"
REPORT_FILE="$PROJECT_ROOT/queue/kaseifu_to_ojousama.yaml"
STATE_FILE="$PROJECT_ROOT/queue/.watchdog_state"
NTFY_SCRIPT="$PROJECT_ROOT/scripts/ntfy.sh"

THRESHOLD="${WATCHDOG_THRESHOLD_SECONDS:-600}"
TARGET_PANE="${WATCHDOG_TARGET_PANE:-ojousama:0.0}"

log() {
    echo "[watchdog $(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

# Extract first matching scalar value from a YAML file.
# Usage: yaml_get <file> <key>
yaml_get() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || return 1
    # Match "key: value" at top level (no leading whitespace), strip quotes.
    grep -E "^${key}:[[:space:]]" "$file" 2>/dev/null \
        | head -n1 \
        | sed -E "s/^${key}:[[:space:]]*//; s/^[\"']//; s/[\"']\$//" \
        || return 1
}

# Convert ISO8601 timestamp to epoch seconds. Cross-platform (macOS/Linux).
iso8601_to_epoch() {
    local ts="$1"
    # Strip trailing Z and fractional seconds for portability.
    local clean
    clean="$(echo "$ts" | sed -E 's/\.[0-9]+//; s/Z$//')"
    if date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" +%s 2>/dev/null; then
        return 0
    fi
    if date -d "$ts" +%s 2>/dev/null; then
        return 0
    fi
    return 1
}

# Read CMD_FILE (the source of truth for "what task is in flight").
if [ ! -f "$CMD_FILE" ]; then
    log "no cmd file; nothing to watch"
    exit 0
fi

CMD_TASK_ID="$(yaml_get "$CMD_FILE" task_id || true)"
CMD_TIMESTAMP="$(yaml_get "$CMD_FILE" timestamp || true)"

if [ -z "${CMD_TASK_ID:-}" ]; then
    log "cmd task_id missing; nothing to watch"
    exit 0
fi

if [ -z "${CMD_TIMESTAMP:-}" ]; then
    log "cmd timestamp missing (operation rule not yet adopted); skip"
    exit 0
fi

REPORT_TASK_ID=""
if [ -f "$REPORT_FILE" ]; then
    REPORT_TASK_ID="$(yaml_get "$REPORT_FILE" task_id || true)"
fi

if [ "${REPORT_TASK_ID:-}" = "$CMD_TASK_ID" ]; then
    log "task $CMD_TASK_ID already reported; ok"
    exit 0
fi

CMD_EPOCH=""
if ! CMD_EPOCH="$(iso8601_to_epoch "$CMD_TIMESTAMP")"; then
    log "cannot parse timestamp '$CMD_TIMESTAMP'; skip"
    exit 0
fi

NOW_EPOCH="$(date -u +%s)"
ELAPSED=$(( NOW_EPOCH - CMD_EPOCH ))

if [ "$ELAPSED" -lt "$THRESHOLD" ]; then
    log "task $CMD_TASK_ID elapsed=${ELAPSED}s < threshold=${THRESHOLD}s; ok"
    exit 0
fi

# Dedupe: skip if we already alerted on this task_id.
if [ -f "$STATE_FILE" ]; then
    LAST_ALERT="$(head -n1 "$STATE_FILE" 2>/dev/null || true)"
    if [ "${LAST_ALERT:-}" = "$CMD_TASK_ID" ]; then
        log "already alerted for $CMD_TASK_ID; skip"
        exit 0
    fi
fi

ELAPSED_MIN=$(( ELAPSED / 60 ))
MSG="[watchdog] $CMD_TASK_ID unreported for ${ELAPSED_MIN}min (threshold ${THRESHOLD}s)"

# tmux notification (2-step). Failure must NOT abort ntfy.
if command -v tmux >/dev/null 2>&1; then
    tmux send-keys -t "$TARGET_PANE" "$MSG" 2>/dev/null || log "tmux send-keys failed (pane=$TARGET_PANE)"
    tmux send-keys -t "$TARGET_PANE" Enter 2>/dev/null || true
else
    log "tmux not installed; skip pane notify"
fi

# ntfy notification. Failure must NOT abort the script (return 0 anyway).
if [ -x "$NTFY_SCRIPT" ] || [ -f "$NTFY_SCRIPT" ]; then
    if bash "$NTFY_SCRIPT" "$MSG" >/dev/null 2>&1; then
        log "ntfy ok"
    else
        log "ntfy send failed (likely missing NTFY_TOPIC or network); ignored"
    fi
else
    log "ntfy.sh not found at $NTFY_SCRIPT; skip"
fi

# Update dedupe state.
mkdir -p "$(dirname "$STATE_FILE")"
echo "$CMD_TASK_ID" > "$STATE_FILE"

log "alert sent for $CMD_TASK_ID"
exit 0
