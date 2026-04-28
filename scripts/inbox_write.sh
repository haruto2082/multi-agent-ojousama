#!/bin/bash
# Mailbox System: inbox YAML への安全な追記
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
