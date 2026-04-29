#!/usr/bin/env bash
# postcompact_resume.sh - Claude Code PostCompact hook.
# <!-- task_056_followup_04 --> 全ロール対象 / inbox 自動 resume
# お嬢様承認 2026-04-29T08:56:45Z (esc_056_01 / bloom_level: L3)
#
# 役割: compaction 完了直後に自己 pane の inbox 未読件数 (read: false) を数え、
#       1件以上なら "inbox{N}" nudge を tmux 2 ステップ (F-RULE-03) で送り起床させる。
#       送信内容は "inbox{N}" 形式のみ (PreCompact 自己ループ防止)。
# INVARIANT: 末尾 exit 0 を維持 (非ゼロ exit は compaction 自体を阻害)。
#
# Troubleshooting:
# - Hook firing audit: tail -f scripts/hooks/.postcompact_history.log
#   Each invocation appends 1 line:
#   "<ISO8601> | role=... | matcher=... | pane=... | ppid=... | unread=N".
# - Manual smoke test:
#   echo '{"hook_event_name":"PostCompact","trigger":"manual"}' \
#     | bash scripts/hooks/postcompact_resume.sh
# - Live test: run real compact inside Claude Code, then watch history log.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HISTORY_LOG="$SCRIPT_DIR/.postcompact_history.log"
INBOX_DIR="$SCRIPT_DIR/../../queue/inbox"

# 1. read stdin JSON (PostCompact payload)
payload=$(cat 2>/dev/null || true)

extract_field() {
    field="$1"
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$payload" | jq -r --arg k "$field" '.[$k] // empty' 2>/dev/null
    else
        printf '%s' "$payload" \
            | grep -oE "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
            | head -n1 \
            | sed -E "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/"
    fi
}

matcher=$(extract_field trigger)
hook_event=$(extract_field hook_event_name)
[ -z "$matcher" ] && matcher="unknown"
[ -z "$hook_event" ] && hook_event="PostCompact"

# 2. extract TMUX_PANE from parent process env (PPID = Claude Code itself)
parent_pane=""
if [ -n "${PPID:-}" ]; then
    parent_pane=$(ps eww "$PPID" 2>/dev/null \
        | tr ' ' '\n' \
        | grep -m1 '^TMUX_PANE=' \
        | cut -d= -f2)
fi

# 3. resolve role with fallbacks (tmux @agent_id → AGENT_ROLE → "unknown")
role=""
if [ -n "$parent_pane" ] && command -v tmux >/dev/null 2>&1; then
    role=$(tmux display-message -t "$parent_pane" -p '#{@agent_id}' 2>/dev/null || echo "")
fi
[ -z "$role" ] && role="${AGENT_ROLE:-unknown}"

# 4. count unread messages (read: false) in own inbox; absent file = 0
unread=0
inbox_file="$INBOX_DIR/$role.yaml"
if [ -f "$inbox_file" ]; then
    unread=$(grep -c 'read: false' "$inbox_file" 2>/dev/null || true)
fi
case "$unread" in
    ''|*[!0-9]*) unread=0 ;;
esac

# 5. record fire history BEFORE notification, so the log survives even if
#    tmux paths fail. write failures are swallowed (`|| true`) so the hook
#    never aborts on log issues.
{
    iso8601=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "unknown")
    printf '%s | role=%s | matcher=%s | pane=%s | ppid=%s | unread=%s\n' \
        "$iso8601" "$role" "$matcher" "${parent_pane:-unknown}" "${PPID:-unknown}" "$unread" \
        >> "$HISTORY_LOG"
} 2>/dev/null || true

# 6. nudge self pane only when unread > 0 (F-RULE-03 / "inbox{N}" format only)
#    Self-loop guarantee: this hook NEVER sends a slash-command. Body is plain
#    "inbox{N}" text so the resumed agent reads its own inbox via Read tool.
if [ "$unread" -gt 0 ] \
    && [ -n "$parent_pane" ] \
    && command -v tmux >/dev/null 2>&1; then
    tmux send-keys -t "$parent_pane" "inbox$unread" 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$parent_pane" Enter 2>/dev/null || true
fi

# 7. never block compaction (INVARIANT)
exit 0
