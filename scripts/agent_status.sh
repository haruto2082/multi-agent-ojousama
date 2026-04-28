#!/usr/bin/env bash
# agent_status.sh — 各エージェントpaneの稼働状況とqueue最新statusを集計表示
#
# Usage:
#   scripts/agent_status.sh                # 全ロール
#   scripts/agent_status.sh --role maid_03 # 特定ロール
#
# 出力列: pane / role / status(busy/idle/absent) / last_active / current_task

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUEUE_DIR="$PROJECT_ROOT/queue"
LIB_LOG="$PROJECT_ROOT/scripts/lib/log.sh"

# 共有ログライブラリは maid_05 が作成中。存在すれば読み込む（参照のみ）。
if [[ -f "$LIB_LOG" ]]; then
  # shellcheck disable=SC1090
  source "$LIB_LOG"
fi

TARGET_ROLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      TARGET_ROLE="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '2,9p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

# ロール定義: role_name|pane_target （CLAUDE.md panes:セクションに整合）
declare -a ROLES=(
  "ojousama|ojousama:0.0"
  "shitsuji|ojousama:1.0"
  "kaseifu|ojousama:1.1"
  "maid_01|ojousama:2.0"
  "maid_02|ojousama:2.1"
  "maid_03|ojousama:2.2"
  "maid_04|ojousama:2.3"
  "maid_05|ojousama:2.4"
  "maid_06|ojousama:2.5"
  "maid_07|ojousama:2.6"
  "maid_08|ojousama:2.7"
)

# pane busy/idle 判定
pane_state() {
  local pane="$1"
  if ! tmux has-session -t "${pane%%:*}" 2>/dev/null; then
    echo "absent"
    return
  fi
  local content
  content="$(tmux capture-pane -t "$pane" -p 2>/dev/null | tail -n 5)"
  if [[ -z "$content" ]]; then
    echo "absent"
    return
  fi
  # Claude Code が処理中だと "esc to" がステータス行に出る
  if grep -qE 'esc to|tokens|Running' <<<"$content"; then
    echo "busy"
  else
    echo "idle"
  fi
}

# pane 最終更新時刻（最後にアクティビティがあった時間の近似）
pane_last_active() {
  local pane="$1"
  tmux display-message -t "$pane" -p '#{pane_active_time}' 2>/dev/null \
    | awk '{ if ($1 ~ /^[0-9]+$/) print strftime("%Y-%m-%d %H:%M", $1); else print "-" }'
}

# queue から該当ロールの最新report status / task_idを取得
queue_latest() {
  local role="$1"
  local report="$QUEUE_DIR/${role}_report.yaml"
  if [[ ! -f "$report" ]]; then
    echo "- -"
    return
  fi
  local task_id status
  task_id="$(grep -E '^task_id:' "$report" | head -1 | sed -E 's/^task_id:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
  status="$(grep -E '^status:' "$report" | head -1 | sed -E 's/^status:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
  echo "${task_id:--} ${status:--}"
}

printf '%-10s %-18s %-7s %-17s %-30s %s\n' "role" "pane" "state" "last_active" "current_task" "report_status"
printf '%-10s %-18s %-7s %-17s %-30s %s\n' "----" "----" "-----" "-----------" "------------" "-------------"

for entry in "${ROLES[@]}"; do
  role="${entry%%|*}"
  pane="${entry#*|}"
  if [[ -n "$TARGET_ROLE" && "$role" != "$TARGET_ROLE" ]]; then
    continue
  fi
  state="$(pane_state "$pane")"
  last="$(pane_last_active "$pane")"
  read -r task_id rep_status <<<"$(queue_latest "$role")"
  printf '%-10s %-18s %-7s %-17s %-30s %s\n' \
    "$role" "$pane" "$state" "$last" "$task_id" "$rep_status"
done
