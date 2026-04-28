#!/bin/bash
# stop.sh - tear down ojousama session and reap orphaned watchers.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/log.sh"

SESSION="ojousama"

log_info "孤児プロセスを回収します"
reaped=0
for pat in inbox_watcher.sh ntfy_listener.sh; do
    if pkill -f "$pat" 2>/dev/null; then
        log_done "pkill -f $pat"
        reaped=$((reaped + 1))
    fi
done
[ "$reaped" -eq 0 ] && log_info "回収対象なし"

if tmux kill-session -t "$SESSION" 2>/dev/null; then
    log_done "お嬢様邸を閉鎖しました（session=$SESSION）"
else
    log_warn "セッション '$SESSION' が見つかりません"
fi
