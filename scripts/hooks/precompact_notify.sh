#!/usr/bin/env bash
# precompact_notify.sh - Claude Code PreCompact hook.
# Notifies ojousama pane that an agent reached compaction / context limit.
#
# Troubleshooting:
# - Hook firing audit: tail -f scripts/hooks/.precompact_history.log
#   Each invocation appends 1 line ("<ISO8601> | role=... | matcher=... | pane=... | ppid=...").
# - If history shows entries but ojousama pane receives no notification,
#   verify OJOUSAMA_PANE below and that the tmux pane actually exists.
# - Manual smoke test: echo '{}' | bash scripts/hooks/precompact_notify.sh
#   then tail -1 scripts/hooks/.precompact_history.log to see the appended row.
# - Live test: run /compact inside Claude Code to trigger the hook.
# - INVARIANT: this hook MUST exit 0 even on internal errors; non-zero exit
#   blocks compaction itself, which is worse than a missed notification.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OJOUSAMA_PANE="ojousama:0.0"
HISTORY_LOG="$SCRIPT_DIR/.precompact_history.log"

# 1. read stdin JSON (PreCompact payload)
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
[ -z "$hook_event" ] && hook_event="PreCompact"

# 2. extract TMUX_PANE from parent process env (PPID = Claude Code itself)
parent_pane=""
if [ -n "${PPID:-}" ]; then
    parent_pane=$(ps eww "$PPID" 2>/dev/null \
        | tr ' ' '\n' \
        | grep -m1 '^TMUX_PANE=' \
        | cut -d= -f2)
fi

# 3. resolve role with fallbacks
role="unknown"
if [ -n "$parent_pane" ]; then
    role=$(tmux display-message -t "$parent_pane" -p '#{@agent_id}' 2>/dev/null || echo "")
fi
[ -z "$role" ] && role="${AGENT_ROLE:-unknown}"

# 4. record fire history BEFORE notifications, so the log survives
#    even if tmux/ntfy paths fail. write failures are swallowed (`|| true`)
#    so the hook never aborts on log issues.
{
    iso8601=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "unknown")
    printf '%s | role=%s | matcher=%s | pane=%s | ppid=%s\n' \
        "$iso8601" "$role" "$matcher" "${parent_pane:-unknown}" "${PPID:-unknown}" \
        >> "$HISTORY_LOG"
} 2>/dev/null || true

# 5. build message
msg="[$role] context limit到達($matcher)。/clear または再起動が必要です"

# 6. tmux 2-step notify (F-RULE-03)
if command -v tmux >/dev/null 2>&1; then
    tmux send-keys -t "$OJOUSAMA_PANE" "$msg" 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$OJOUSAMA_PANE" Enter 2>/dev/null || true
fi

# 7. ntfy push (best-effort, never block hook)
NTFY_SH="$SCRIPT_DIR/../ntfy.sh"
if [ -x "$NTFY_SH" ]; then
    bash "$NTFY_SH" -t "compaction" -p high "$msg" >/dev/null 2>&1 || true
fi

# 8. 自動 /compact 送信 (お嬢様緊急要請 2026-04-29 / 緊急 stop 適用 2026-04-29):
#    発火元 pane に /compact を tmux 2 ステップ (F-RULE-03) で送り context limit 自己復旧を企図。
#    task_056_followup_01: 自己 /compact ループ (.precompact_history.log 2026-04-29T05:50/05:52
#    1 分 37 秒間隔 2 連発) 観測のためデフォルト無効化。opt-in 復活: PRECOMPACT_AUTO_COMPACT=1
#    お嬢様承認 2026-04-29T06:11:07Z / shitsuji_report task_056_shitsuji_analysis verdict=適用すべき
if [ "${PRECOMPACT_AUTO_COMPACT:-0}" != "0" ] \
    && [ -n "$parent_pane" ] \
    && command -v tmux >/dev/null 2>&1; then
    sleep 0.3
    tmux send-keys -t "$parent_pane" "/compact" 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$parent_pane" Enter 2>/dev/null || true
fi

# 9. task_066a (option_C / 2-hook flag 連携): PostCompact hook が unread=0 でも
#    'resume' nudge を送信できるよう flag を touch。flag は PostCompact 完了時に rm。
touch "$SCRIPT_DIR/.compaction_in_progress" 2>/dev/null || true

# 10. never block compaction
# task_066a / option_C 2-hook flag 連携
exit 0
