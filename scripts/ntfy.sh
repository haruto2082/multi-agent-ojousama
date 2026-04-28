#!/usr/bin/env bash
# ntfy外部通知送信スクリプト
# 使い方:
#   ./scripts/ntfy.sh "メッセージ本文"
#   ./scripts/ntfy.sh -t "タイトル" -p high "メッセージ本文"
#
# 認証情報は config/ntfy_auth.env に置く（gitignore済み）。
# 必須: NTFY_TOPIC
# 任意: NTFY_SERVER（既定 https://ntfy.sh）, NTFY_TOKEN（Bearer）, NTFY_USER + NTFY_PASS（Basic）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/config/ntfy_auth.env"

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi

NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
TITLE=""
PRIORITY=""
TAGS=""

usage() {
    cat <<EOF
Usage: $0 [-t TITLE] [-p PRIORITY] [-T TAGS] "MESSAGE"
  -t TITLE     通知タイトル
  -p PRIORITY  min|low|default|high|urgent
  -T TAGS      カンマ区切りタグ
ENV (config/ntfy_auth.env):
  NTFY_TOPIC   (required)
  NTFY_SERVER  (default: https://ntfy.sh)
  NTFY_TOKEN   (Bearer auth)
  NTFY_USER, NTFY_PASS (Basic auth)
EOF
    exit 1
}

while getopts ":t:p:T:h" opt; do
    case "$opt" in
        t) TITLE="$OPTARG" ;;
        p) PRIORITY="$OPTARG" ;;
        T) TAGS="$OPTARG" ;;
        h|*) usage ;;
    esac
done
shift $((OPTIND - 1))

MESSAGE="${1:-}"
if [ -z "$MESSAGE" ]; then
    echo "ERROR: message body is empty" >&2
    usage
fi
if [ -z "${NTFY_TOPIC:-}" ]; then
    echo "ERROR: NTFY_TOPIC is not set (define it in $ENV_FILE)" >&2
    exit 2
fi

CURL_ARGS=(--silent --show-error --fail --max-time 15)

if [ -n "${NTFY_TOKEN:-}" ]; then
    CURL_ARGS+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
elif [ -n "${NTFY_USER:-}" ] && [ -n "${NTFY_PASS:-}" ]; then
    CURL_ARGS+=(-u "${NTFY_USER}:${NTFY_PASS}")
fi

[ -n "$TITLE" ]    && CURL_ARGS+=(-H "Title: $TITLE")
[ -n "$PRIORITY" ] && CURL_ARGS+=(-H "Priority: $PRIORITY")
[ -n "$TAGS" ]     && CURL_ARGS+=(-H "Tags: $TAGS")

curl "${CURL_ARGS[@]}" \
    -d "$MESSAGE" \
    "${NTFY_SERVER%/}/${NTFY_TOPIC}"
