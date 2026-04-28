#!/usr/bin/env bash
# ntfy SSE 購読リスナー
# 使い方: ./scripts/ntfy_listener.sh
# config/ntfy_auth.env から NTFY_TOPIC, NTFY_SERVER, 認証情報を読み込み、
# ntfy トピックを SSE (/json) で購読し、受信メッセージを
# queue/inbox/ojousama.yaml へ追記する。
#
# 注意:
#   - inbox 構造設計（フィールド/フォーマット）は maid_04 が定義する
#     scripts/inbox_write.sh があれば優先して呼び出す。
#     なければフォールバックで簡易追記する。
#   - 本スクリプト自身はポーリングを行わない。SSE は ntfy 側からの push。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/config/ntfy_auth.env"
INBOX_FILE="$PROJECT_ROOT/queue/inbox/ojousama.yaml"
INBOX_WRITER="$PROJECT_ROOT/scripts/inbox_write.sh"

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi

NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

if [ -z "${NTFY_TOPIC:-}" ]; then
    echo "ERROR: NTFY_TOPIC is not set (define it in $ENV_FILE)" >&2
    exit 2
fi

mkdir -p "$(dirname "$INBOX_FILE")"

CURL_ARGS=(--silent --show-error --no-buffer --max-time 0)
if [ -n "${NTFY_TOKEN:-}" ]; then
    CURL_ARGS+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
elif [ -n "${NTFY_USER:-}" ] && [ -n "${NTFY_PASS:-}" ]; then
    CURL_ARGS+=(-u "${NTFY_USER}:${NTFY_PASS}")
fi

URL="${NTFY_SERVER%/}/${NTFY_TOPIC}/json"

append_inbox() {
    local raw_json="$1"
    if [ -x "$INBOX_WRITER" ]; then
        printf '%s\n' "$raw_json" | "$INBOX_WRITER" --source ntfy --target ojousama
        return
    fi
    # フォールバック: 簡易追記（inbox 構造設計が確定するまでの暫定）
    {
        printf -- '- received_at: "%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '  source: ntfy\n'
        printf '  raw: %s\n' "$(printf '%s' "$raw_json" | sed 's/"/\\"/g' | awk 'BEGIN{printf "\""} {printf "%s", $0} END{printf "\"\n"}')"
    } >> "$INBOX_FILE"
}

echo "[ntfy_listener] subscribing: $URL" >&2
echo "[ntfy_listener] inbox: $INBOX_FILE" >&2

curl "${CURL_ARGS[@]}" "$URL" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
        '{'*) append_inbox "$line" ;;
        *) ;;
    esac
done
