#!/bin/bash
# Mailbox System: inbox YAML への安全な追記 + 受信者pane への直接nudge
#
# 使い方: scripts/inbox_write.sh <target_role> "<body>" <from>
# 例:    scripts/inbox_write.sh maid_01 "task: queue/kaseifu_to_maid_01.yaml" kaseifu
#
# 仕様:
# - queue/inbox/{target_role}.yaml に messages 配列要素を追記
# - flock(1) 互換が macOS 標準では無いため、mkdir 方式の排他ロックを使用
# - 1メッセージ = { from, ts, body, read: false }
# - dedupe (task_031): 同一 from + 同一 body + read:false の未読エントリが既存なら
#   新規追加せず ts のみを最新値に更新する。INBOX_WRITE_DEDUPE=0 で無効化可
# - nudge 統合 (task_055_urgent_pane_fix): 書込完了後、受信者pane へ "inboxN" を 2ステップ送信
#   (旧 inbox_watcher.sh + fswatch 依存を排除。書込と通知を同一trigger化し通知ロスを防止)
#   無効化: INBOX_WRITE_NUDGE=0
# - nudge 拡張 (task_056_followup_02): nudge メッセージを "inbox{N}: {body 先頭60字}" 形式へ
#   拡張。受信側は inbox を Read する前に緊急性を直感判断できる。
#   sanitize: 改行→空白 / シングル・ダブル引用符を除去 / cut -c1-60 で長さ制限。
#   tmux send-keys は -l (literal) で送り tmux のキー解釈を回避。F-RULE-03 (2 ステップ送信) 維持。
# - F-RULE-08 緩和 (task_064d): ojousama_critical inbox は F-RULE-08 緩和の例外経路
#   (severity=critical 限定)。通常通信 (low/medium/high) は子→親方向 inbox + cmd YAML
#   経路を維持。本 case 分岐に ojousama_critical → ojousama:0.0 を追加し、nudge 接頭辞も
#   "ojousama_critical{N}: ..." に切替えて通常 inbox と区別可能とする。
#   詳細: instructions/common/forbidden_actions.md F-RULE-08 補項 (task_064e で文言化予定)

set -euo pipefail

TARGET="${1:-}"
BODY="${2:-}"
FROM="${3:-}"

if [ -z "$TARGET" ] || [ -z "$BODY" ] || [ -z "$FROM" ]; then
  echo "usage: inbox_write.sh <target_role> <body> <from>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX_DIR="$REPO_ROOT/queue/inbox"
INBOX_FILE="$INBOX_DIR/$TARGET.yaml"
LOCK_DIR="$INBOX_DIR/.lock-$TARGET"

if [ ! -f "$INBOX_FILE" ]; then
  echo "inbox file not found: $INBOX_FILE" >&2
  exit 2
fi

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ESCAPED_BODY="$(printf '%s' "$BODY" | sed 's/"/\\"/g')"
DEDUPE_ENABLED="${INBOX_WRITE_DEDUPE:-1}"

acquire_lock() {
  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 50 ]; then
      echo "failed to acquire lock: $LOCK_DIR" >&2
      exit 3
    fi
    sleep 0.1
  done
}

release_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

trap release_lock EXIT
acquire_lock

if [ "$DEDUPE_ENABLED" != "0" ]; then
  TMP_OUT="$INBOX_FILE.dedupe.$$"
  if awk -v from_v="$FROM" -v body_v="$ESCAPED_BODY" -v new_ts="$TS" '
    {
      lines[NR] = $0
      n = NR
    }
    END {
      cur_from = ""
      cur_body = ""
      cur_ts_idx = 0
      found = 0
      for (i = 1; i <= n; i++) {
        line = lines[i]
        if (line ~ /^  - from: ".*"[[:space:]]*$/) {
          v = line
          sub(/^  - from: "/, "", v)
          sub(/"[[:space:]]*$/, "", v)
          cur_from = v
          cur_ts_idx = 0
          cur_body = ""
        } else if (line ~ /^    ts: ".*"[[:space:]]*$/) {
          cur_ts_idx = i
        } else if (line ~ /^    body: ".*"[[:space:]]*$/) {
          v = line
          sub(/^    body: "/, "", v)
          sub(/"[[:space:]]*$/, "", v)
          cur_body = v
        } else if (line ~ /^    read: false[[:space:]]*$/) {
          if (!found && cur_from == from_v && cur_body == body_v && cur_ts_idx > 0) {
            lines[cur_ts_idx] = "    ts: \"" new_ts "\""
            found = 1
          }
        }
      }
      for (i = 1; i <= n; i++) print lines[i]
      exit found ? 0 : 1
    }
  ' "$INBOX_FILE" > "$TMP_OUT"; then
    mv "$TMP_OUT" "$INBOX_FILE"
    exit 0
  else
    rm -f "$TMP_OUT"
  fi
fi

{
  echo "  - from: \"$FROM\""
  echo "    ts: \"$TS\""
  echo "    body: \"$ESCAPED_BODY\""
  echo "    read: false"
} >> "$INBOX_FILE"

# messages: [] のままなら、初回追記時に [] を消し、有効な配列に整形する必要がある
if grep -qE '^messages: \[\]' "$INBOX_FILE"; then
  TMP="$INBOX_FILE.tmp.$$"
  awk '
    /^messages: \[\]/ { print "messages:"; next }
    { print }
  ' "$INBOX_FILE" > "$TMP"
  mv "$TMP" "$INBOX_FILE"
fi

# task_055_urgent_pane_fix: 受信者pane への直接 nudge 発火 (watcher 不要化)
# 失敗しても本体処理 (inbox 書込) には影響させない
if [ "${INBOX_WRITE_NUDGE:-1}" != "0" ] && command -v tmux >/dev/null 2>&1; then
  SESSION="ojousama"
  # task_064d: ojousama_critical を case に追加 / nudge 接頭辞は target_role に応じて切替
  PREFIX="inbox"
  case "$TARGET" in
    kaseifu)           PANE="$SESSION:1.1" ;;
    shitsuji)          PANE="$SESSION:1.0" ;;
    maid_01)           PANE="$SESSION:2.0" ;;
    maid_02)           PANE="$SESSION:2.1" ;;
    maid_03)           PANE="$SESSION:2.2" ;;
    maid_04)           PANE="$SESSION:2.3" ;;
    maid_05)           PANE="$SESSION:2.4" ;;
    maid_06)           PANE="$SESSION:2.5" ;;
    maid_07)           PANE="$SESSION:2.6" ;;
    maid_08)           PANE="$SESSION:2.7" ;;
    ojousama_critical) PANE="$SESSION:0.0"; PREFIX="ojousama_critical" ;;
    *)                 PANE="" ;;
  esac
  if [ -n "$PANE" ]; then
    UNREAD="$(grep -c 'read: false' "$INBOX_FILE" 2>/dev/null || echo 0)"
    # task_056_followup_02: body 先頭60字を sanitize して nudge に同梱
    BODY_HEAD="$(printf '%s' "$BODY" | tr '\r\n' '  ' | tr -d "\"'" | cut -c1-60)"
    if [ -n "$BODY_HEAD" ]; then
      NUDGE_MSG="${PREFIX}${UNREAD}: ${BODY_HEAD}"
    else
      NUDGE_MSG="${PREFIX}${UNREAD}"
    fi
    tmux send-keys -t "$PANE" -l "$NUDGE_MSG" 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$PANE" Enter 2>/dev/null || true
  fi
fi
