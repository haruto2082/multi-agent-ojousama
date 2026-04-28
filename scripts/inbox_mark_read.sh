#!/bin/bash
# Mailbox System: inbox YAML の未読エントリを既読化する
#
# 使い方:
#   scripts/inbox_mark_read.sh <role>                       # 当該 role の inbox の未読を全て既読化
#   scripts/inbox_mark_read.sh <role> --filter <task_id>    # body に <task_id> を含む未読のみ既読化
#   scripts/inbox_mark_read.sh --all                        # queue/inbox/*.yaml 全件処理
#   scripts/inbox_mark_read.sh --all --filter <task_id>
#
# 仕様:
# - read: false のエントリを read: true に in-place 書換 (mkdir 方式の排他ロック)
# - 書換前に元ファイルを /tmp/<role>.yaml.bak に複製 (1世代のみ、上書き)
# - 外部依存ツール無し (bash + awk + mv + cp + mkdir のみ)
# - 単発実行のみ (watcher loop は持たない)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX_DIR="$REPO_ROOT/queue/inbox"

ALL=0
FILTER=""
ROLE=""

usage() {
  cat <<'USAGE' >&2
usage:
  inbox_mark_read.sh <role>                    mark all unread in queue/inbox/<role>.yaml
  inbox_mark_read.sh <role> --filter <task_id> mark only entries whose body contains <task_id>
  inbox_mark_read.sh --all                     process queue/inbox/*.yaml
  inbox_mark_read.sh --all --filter <task_id>
USAGE
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --all) ALL=1; shift ;;
    --filter)
      if [ $# -lt 2 ]; then echo "--filter requires an argument" >&2; usage; fi
      FILTER="$2"; shift 2 ;;
    -h|--help) usage ;;
    --*) echo "unknown option: $1" >&2; usage ;;
    *)
      if [ -z "$ROLE" ]; then ROLE="$1"; shift
      else echo "unexpected positional arg: $1" >&2; usage; fi ;;
  esac
done

if [ "$ALL" -eq 0 ] && [ -z "$ROLE" ]; then
  usage
fi

mark_one() {
  local file="$1"
  local target lock_dir tmp tries=0
  target="$(basename "$file" .yaml)"
  lock_dir="$INBOX_DIR/.lock-$target"

  while ! mkdir "$lock_dir" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 50 ]; then
      echo "failed to acquire lock: $lock_dir" >&2
      return 3
    fi
    sleep 0.1
  done

  cp "$file" "/tmp/$(basename "$file").bak"

  tmp="$file.markread.$$"
  awk -v filter_v="$FILTER" '
    {
      lines[NR] = $0
      n = NR
    }
    END {
      cur_body = ""
      for (i = 1; i <= n; i++) {
        line = lines[i]
        if (line ~ /^  - from: /) {
          cur_body = ""
        } else if (line ~ /^    body: ".*"[[:space:]]*$/) {
          v = line
          sub(/^    body: "/, "", v)
          sub(/"[[:space:]]*$/, "", v)
          cur_body = v
        } else if (line ~ /^    read: false[[:space:]]*$/) {
          should_mark = 1
          if (filter_v != "" && index(cur_body, filter_v) == 0) {
            should_mark = 0
          }
          if (should_mark) {
            sub(/false[[:space:]]*$/, "true", lines[i])
          }
        }
      }
      for (i = 1; i <= n; i++) print lines[i]
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"

  rmdir "$lock_dir" 2>/dev/null || true
}

if [ "$ALL" -eq 1 ]; then
  shopt -s nullglob
  for f in "$INBOX_DIR"/*.yaml; do
    mark_one "$f"
  done
else
  f="$INBOX_DIR/$ROLE.yaml"
  if [ ! -f "$f" ]; then
    echo "inbox file not found: $f" >&2
    exit 2
  fi
  mark_one "$f"
fi
