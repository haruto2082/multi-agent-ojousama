#!/bin/bash
# Mailbox System: inbox YAML 変更を検知し、対応 pane に nudge を送信
#
# 使い方: scripts/inbox_watcher.sh
#
# 動作:
# - queue/inbox/*.yaml の変更を fswatch で監視（macOS 前提）
# - 変更ファイル名からロールを抽出し、未読件数を数えて "inboxN" nudge を tmux pane へ送信
# - tmux send-keys は本文と Enter を分けた2ステップで送る（F-RULE-03準拠）
#
# Linux で動かす場合の代替（要 inotify-tools）:
#   inotifywait -m -e modify,close_write --format '%w%f' "$INBOX_DIR" \
#     | while read -r changed; do handle_change "$changed"; done

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX_DIR="$REPO_ROOT/queue/inbox"
SESSION="ojousama"

if ! command -v fswatch >/dev/null 2>&1; then
  echo "fswatch not found. Install with: brew install fswatch" >&2
  echo "(Linux代替: inotify-tools の inotifywait を使用すること)" >&2
  exit 1
fi

role_to_pane() {
  # task_055_urgent_pane_fix: 実 pane 配置 (tmux list-panes で確認済) に整合。
  # ojousama inbox は esc_4_01 で廃止済のため除外。
  case "$1" in
    kaseifu)  echo "$SESSION:1.1" ;;
    shitsuji) echo "$SESSION:1.0" ;;
    maid_01)  echo "$SESSION:2.0" ;;
    maid_02)  echo "$SESSION:2.1" ;;
    maid_03)  echo "$SESSION:2.2" ;;
    maid_04)  echo "$SESSION:2.3" ;;
    maid_05)  echo "$SESSION:2.4" ;;
    maid_06)  echo "$SESSION:2.5" ;;
    maid_07)  echo "$SESSION:2.6" ;;
    maid_08)  echo "$SESSION:2.7" ;;
    *)        echo "" ;;
  esac
}

count_unread() {
  grep -c 'read: false' "$1" 2>/dev/null || echo 0
}

handle_change() {
  local path="$1"
  local file="${path##*/}"
  local role="${file%.yaml}"
  case "$role" in
    *.tmp.*|.lock-*) return 0 ;;
  esac

  local pane
  pane="$(role_to_pane "$role")"
  if [ -z "$pane" ]; then
    return 0
  fi

  local unread
  unread="$(count_unread "$path")"
  if [ "$unread" -le 0 ]; then
    return 0
  fi

  tmux send-keys -t "$pane" "inbox$unread"
  sleep 0.3
  tmux send-keys -t "$pane" Enter
}

echo "watching: $INBOX_DIR"
fswatch -0 "$INBOX_DIR" | while IFS= read -r -d '' changed; do
  handle_change "$changed"
done
