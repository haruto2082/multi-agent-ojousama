#!/usr/bin/env bash
# watchdog.sh
# Detects stalled task reports and notifies via tmux + ntfy.
# Designed to be invoked periodically by launchd (every 5 minutes).
# F-RULE-04: This script itself does NOT loop; it is one-shot, externally driven.
#
# Phase-4 (task_064f / 2026-04-29) で legacy 経路削除済 / 本 script は
# walk_cmd_log + check_context_limit_recovery のみで構成。
# walk_cmd_log は queue/cmd_log.yaml を walk し並走 cmd を per-task age check。
# check_context_limit_recovery (task_066) は context limit auto-recovery 並走機能。
#
# State file (queue/.watchdog_state) — Phase-2 YAML schema:
#   version: "2"
#   alerted:
#     <task_id>: "<last_event_ts>"
# Phase-1 single-line plaintext (= last_alerted_task_id) is read-compatible:
#   on read, treated as alerted at "1970-01-01T00:00:00Z" so dedupe still works.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

STATE_FILE="$PROJECT_ROOT/queue/.watchdog_state"
COMPACT_STATE_FILE="$PROJECT_ROOT/scripts/.watchdog_compact_state"
CMD_LOG_FILE="${WATCHDOG_CMD_LOG:-$PROJECT_ROOT/queue/cmd_log.yaml}"
NTFY_SCRIPT="$PROJECT_ROOT/scripts/ntfy.sh"

THRESHOLD="${WATCHDOG_THRESHOLD_SECONDS:-600}"
TARGET_PANE="${WATCHDOG_TARGET_PANE:-ojousama:0.0}"
COMPACT_DEDUPE_SECONDS="${WATCHDOG_COMPACT_DEDUPE_SECONDS:-300}"

# Panes monitored for "Context limit reached" auto-recovery (task_066).
# Covers shitsuji (1.0), kaseifu (1.1), and maid_01..maid_08 (2.0..2.7).
CONTEXT_LIMIT_PANES=(
    "ojousama:1.0"
    "ojousama:1.1"
    "ojousama:2.0"
    "ojousama:2.1"
    "ojousama:2.2"
    "ojousama:2.3"
    "ojousama:2.4"
    "ojousama:2.5"
    "ojousama:2.6"
    "ojousama:2.7"
)

log() {
    echo "[watchdog $(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

# -----------------------------------------------------------------------------
# Helpers <!-- task_064c -->
# -----------------------------------------------------------------------------

# Extract first matching scalar value from a YAML file at top level.
yaml_get() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || return 1
    grep -E "^${key}:[[:space:]]" "$file" 2>/dev/null \
        | head -n1 \
        | sed -E "s/^${key}:[[:space:]]*//; s/^[\"']//; s/[\"']\$//" \
        || return 1
}

# Convert ISO8601 timestamp to epoch seconds. Cross-platform (macOS/Linux).
iso8601_to_epoch() {
    local ts="$1"
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

# read_alerted_ts <task_id> -> stdout last_event_ts (empty = never alerted).
# Reads either Phase-2 YAML (version: "2") or Phase-1 plaintext (single line).
# Phase-1 fallback: if the legacy line == task_id, return epoch-zero so that
# a subsequent comparison with a real ts will differ and re-alert is possible.
read_alerted_ts() {
    local tid="$1"
    [ -f "$STATE_FILE" ] || return 0
    if grep -q '^version:' "$STATE_FILE" 2>/dev/null; then
        awk -v key="$tid" '
            /^alerted:/ { in_block=1; next }
            in_block && /^[^[:space:]#]/ { in_block=0 }
            in_block && $0 ~ "^[[:space:]]+"key":[[:space:]]" {
                v=$0
                sub(/^[[:space:]]+[^:]+:[[:space:]]*/, "", v)
                gsub(/["\047]/, "", v)
                gsub(/[[:space:]]+$/, "", v)
                print v
                exit
            }
        ' "$STATE_FILE"
    else
        local legacy
        legacy="$(head -n1 "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')"
        if [ -n "$legacy" ] && [ "$legacy" = "$tid" ]; then
            echo "1970-01-01T00:00:00Z"
        fi
    fi
}

# write_alerted_ts <task_id> <last_event_ts>: insert/update in YAML state.
# Migrates legacy plaintext state into Phase-2 YAML on first write.
write_alerted_ts() {
    local tid="$1"
    local ts="$2"
    mkdir -p "$(dirname "$STATE_FILE")"
    local tmp
    tmp="$(mktemp)"
    if [ -f "$STATE_FILE" ] && grep -q '^version:' "$STATE_FILE" 2>/dev/null; then
        cp "$STATE_FILE" "$tmp"
    elif [ -f "$STATE_FILE" ]; then
        local legacy
        legacy="$(head -n1 "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')"
        {
            echo 'version: "2"'
            echo 'alerted:'
            if [ -n "$legacy" ] && [ "$legacy" != "$tid" ]; then
                printf '  %s: "1970-01-01T00:00:00Z"\n' "$legacy"
            fi
        } > "$tmp"
    else
        {
            echo 'version: "2"'
            echo 'alerted:'
        } > "$tmp"
    fi
    local tmp2
    tmp2="$(mktemp)"
    awk -v key="$tid" '
        $0 ~ "^[[:space:]]+"key":[[:space:]]" { next }
        { print }
    ' "$tmp" > "$tmp2"
    if ! grep -q '^alerted:' "$tmp2"; then
        echo 'alerted:' >> "$tmp2"
    fi
    printf '  %s: "%s"\n' "$tid" "$ts" >> "$tmp2"
    mv "$tmp2" "$STATE_FILE"
    rm -f "$tmp"
}

# -----------------------------------------------------------------------------
# task_066: context-limit auto-recovery (preserved verbatim).
# -----------------------------------------------------------------------------
check_context_limit_recovery() {
    if ! command -v tmux >/dev/null 2>&1; then
        return 0
    fi
    local pane buf last_ts now
    now="$(date +%s)"
    for pane in "${CONTEXT_LIMIT_PANES[@]}"; do
        buf="$(tmux capture-pane -t "$pane" -p 2>/dev/null || true)"
        [ -z "$buf" ] && continue
        if ! printf '%s' "$buf" | grep -q 'Context limit reached'; then
            continue
        fi
        last_ts=""
        if [ -f "$COMPACT_STATE_FILE" ]; then
            last_ts="$(grep "^$pane=" "$COMPACT_STATE_FILE" 2>/dev/null | cut -d= -f2)"
        fi
        if [ -n "$last_ts" ] && [ $((now - last_ts)) -le "$COMPACT_DEDUPE_SECONDS" ]; then
            log "context limit on $pane; deduped (last sent ${last_ts})"
            continue
        fi
        tmux send-keys -t "$pane" "/compact" 2>/dev/null || true
        sleep 0.2
        tmux send-keys -t "$pane" Enter 2>/dev/null || true
        mkdir -p "$(dirname "$COMPACT_STATE_FILE")"
        if [ -f "$COMPACT_STATE_FILE" ]; then
            sed -i.bak "/^$pane=/d" "$COMPACT_STATE_FILE" 2>/dev/null || true
            rm -f "$COMPACT_STATE_FILE.bak"
        fi
        printf '%s=%s\n' "$pane" "$now" >> "$COMPACT_STATE_FILE"
        log "context limit detected on $pane; sent /compact (dedupe=${COMPACT_DEDUPE_SECONDS}s)"
    done
}

# -----------------------------------------------------------------------------
# task_064c: walk queue/cmd_log.yaml and alert on stalled open tasks.
# -----------------------------------------------------------------------------
# An open task = has cmd_issued, lacks cmd_completed.
# alert key = <task_id, last_event_ts> so a fresh event resets dedupe and
# allows re-alert when progress observably resumes then stalls again.
walk_cmd_log() {
    [ -f "$CMD_LOG_FILE" ] || return 0
    local tmp_state
    tmp_state="$(mktemp)"

    awk '
        function strip(v) {
            sub(/^[[:space:]]*[a-z_]+:[[:space:]]*/, "", v)
            gsub(/^["\047]/, "", v)
            gsub(/["\047]$/, "", v)
            gsub(/[[:space:]]+$/, "", v)
            return v
        }
        /^  - event_id:/ {
            cur_ts=""; cur_event_type=""; cur_task_id=""
            in_event=1
            next
        }
        in_event && /^    ts:/         { cur_ts         = strip($0); next }
        in_event && /^    event_type:/ { cur_event_type = strip($0); next }
        in_event && /^    task_id:/    { cur_task_id    = strip($0); next }
        in_event && /^    severity:/ {
            tid = cur_task_id; et = cur_event_type; ts = cur_ts
            in_event = 0
            if (tid == "" || et == "" || ts == "") { next }
            if (et == "cmd_issued") {
                issued[tid] = ts
            } else if (et == "cmd_completed") {
                completed[tid] = 1
            }
            last_ts[tid]   = ts
            last_type[tid] = et
            if (!(tid in seen)) { tasks[++n] = tid; seen[tid] = 1 }
            next
        }
        END {
            for (i=1; i<=n; i++) {
                tid = tasks[i]
                if (tid in completed) continue
                if (!(tid in issued)) continue
                printf "%s\t%s\t%s\t%s\n", tid, issued[tid], last_ts[tid], last_type[tid]
            }
        }
    ' "$CMD_LOG_FILE" > "$tmp_state"

    local now_epoch
    now_epoch="$(date -u +%s)"

    local task_id issued_ts last_ts_v last_type
    while IFS=$'\t' read -r task_id issued_ts last_ts_v last_type; do
        [ -z "$task_id" ] && continue
        local issued_epoch elapsed last_alerted_ts elapsed_min msg
        if ! issued_epoch="$(iso8601_to_epoch "$issued_ts")"; then
            log "cmd_log: cannot parse issued_ts '$issued_ts' for $task_id; skip"
            continue
        fi
        elapsed=$(( now_epoch - issued_epoch ))
        if [ "$elapsed" -lt "$THRESHOLD" ]; then
            log "cmd_log: $task_id elapsed=${elapsed}s < threshold=${THRESHOLD}s; ok"
            continue
        fi
        last_alerted_ts="$(read_alerted_ts "$task_id")"
        if [ -n "$last_alerted_ts" ] && [ "$last_alerted_ts" = "$last_ts_v" ]; then
            log "cmd_log: $task_id already alerted at $last_ts_v; skip"
            continue
        fi
        elapsed_min=$(( elapsed / 60 ))
        msg="[watchdog/cmd_log] $task_id open last=$last_type ${elapsed_min}min (threshold ${THRESHOLD}s)"
        if command -v tmux >/dev/null 2>&1; then
            tmux send-keys -t "$TARGET_PANE" "$msg" 2>/dev/null || log "tmux send-keys failed (pane=$TARGET_PANE)"
            tmux send-keys -t "$TARGET_PANE" Enter 2>/dev/null || true
        fi
        if [ -x "$NTFY_SCRIPT" ] || [ -f "$NTFY_SCRIPT" ]; then
            bash "$NTFY_SCRIPT" "$msg" >/dev/null 2>&1 || log "ntfy send failed for $task_id (cmd_log)"
        fi
        write_alerted_ts "$task_id" "$last_ts_v"
        log "alert sent for $task_id (cmd_log; last=$last_type)"
    done < "$tmp_state"

    rm -f "$tmp_state"
}

# -----------------------------------------------------------------------------
# main: run two checks; one failure must not silence the other.
# task_064f / Phase-4 legacy removal
# -----------------------------------------------------------------------------
check_context_limit_recovery || log "context_limit_recovery failed (ignored)"
walk_cmd_log                  || log "walk_cmd_log failed (ignored)"

# task_064f / Phase-4 legacy removal
exit 0
