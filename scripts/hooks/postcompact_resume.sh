#!/usr/bin/env bash
# postcompact_resume.sh - Claude Code PostCompact hook.
# <!-- task_056_followup_04 / task_066a (option_C 2-hook flag 連携) -->
# 全ロール対象 / inbox 自動 resume + unread=0 flag 検知 resume
# お嬢様承認 2026-04-29T08:56:45Z + option_C 採用 2026-04-29T13:46:07Z
#
# 役割: compaction 完了直後に自己 pane の inbox 未読件数 (read: false) を数え、
#       (a) unread > 0 → "inbox{N}" nudge / (b) unread = 0 + flag 存在 → "resume" nudge /
#       (c) unread = 0 + flag 不在 → 旧来通り skip (task_055_esc_02 / 058 / 059 skip 仕様復活)
# INVARIANT: 末尾 exit 0 維持 / nudge 内容は plain text のみ (slash command 禁止 / self-loop 防止)
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

# 6a. 古い flag (.compaction_in_progress) 残留対策 (異常終了時の補正 / mtime > 60 分で強制削除)
FLAG_FILE="$SCRIPT_DIR/.compaction_in_progress"
find "$FLAG_FILE" -mmin +60 -delete 2>/dev/null || true

# 6b. nudge 送信判定 (option_C / 2-hook flag 連携 / task_066a)
#    Self-loop guarantee: this hook NEVER sends a slash-command. Body is
#    "inbox{N}" (unread>0) or plain "resume" (flag 存在 + unread=0) — both non-slash.
if [ -n "$parent_pane" ] && command -v tmux >/dev/null 2>&1; then
    if [ "$unread" -gt 0 ]; then
        NUDGE_MSG="inbox$unread"
        SEND_NUDGE=1
    elif [ -f "$FLAG_FILE" ]; then
        NUDGE_MSG="resume"
        SEND_NUDGE=1
    else
        SEND_NUDGE=0
    fi

    if [ "$SEND_NUDGE" = "1" ]; then
        tmux send-keys -t "$parent_pane" "$NUDGE_MSG" 2>/dev/null || true
        sleep 0.2
        tmux send-keys -t "$parent_pane" Enter 2>/dev/null || true
    fi
fi

# 6c. flag (.compaction_in_progress) は条件問わず削除 (連続発火時の重複 nudge 防止 / option_C 安全性 3)
rm -f "$FLAG_FILE" 2>/dev/null || true

# 7. never block compaction (INVARIANT)
# task_066a / option_C 2-hook flag 連携
exit 0
