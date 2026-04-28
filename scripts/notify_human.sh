#!/usr/bin/env bash
# notify_human.sh
# エージェント（家政婦・執事・お嬢様）が人間判断を要する場面で能動的に呼び出す通知script。
# task_015の precompact_notify.sh（受動・PreCompact hook）と契機が異なるため独立。
#
# 使い方:
#   bash scripts/notify_human.sh <role> <context>
# 例:
#   bash scripts/notify_human.sh kaseifu "queue/kaseifu_to_ojousama.yaml を確認してください"

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<EOF >&2
Usage: $0 <role> <context>
  role     呼び出し元エージェント名（例: kaseifu, shitsuji, ojousama）
  context  人間判断が必要な状況の説明
EOF
    exit 2
}

if [ "$#" -lt 2 ]; then
    usage
fi

role="$1"
context="$2"
msg="[$role] あなたのご判断が必要です: $context"

OJOUSAMA_PANE="ojousama:0.0"
if command -v tmux >/dev/null 2>&1; then
    tmux send-keys -t "$OJOUSAMA_PANE" "$msg" 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$OJOUSAMA_PANE" Enter 2>/dev/null || true
fi

NTFY_SH="$SCRIPT_DIR/ntfy.sh"
if [ -x "$NTFY_SH" ]; then
    bash "$NTFY_SH" -t "human_decision" -p high "$msg" >/dev/null 2>&1 || true
fi

exit 0
