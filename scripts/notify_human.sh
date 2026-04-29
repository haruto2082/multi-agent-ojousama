#!/usr/bin/env bash
# notify_human.sh
# エージェント（家政婦・執事・お嬢様）が人間判断を要する場面で能動的に呼び出す通知script。
# task_015の precompact_notify.sh（受動・PreCompact hook）と契機が異なるため独立。
#
# Usage (旧 signature / 互換維持):
#   bash scripts/notify_human.sh <role> <context>
#
# Usage (新 signature / task_064d 拡張):
#   bash scripts/notify_human.sh <role> <context> [--severity <level>] [--category <id>] [--related-yaml <path>]
#     --severity        low (既定) | medium | high | critical
#     --category        d_rule | f_rule_09 | acceptance_unparseable | system_failure
#                       (severity=critical 時のみ必須)
#     --related-yaml    参照 YAML パス (任意)
#
# Routing:
#   severity=critical → (a) inbox_write.sh ojousama_critical 永続 append
#                       (b) tmux 2 ステップ送信 (ojousama:0.0)
#                       (c) ntfy push
#   severity=low|medium|high → 現状経路 (tmux + ntfy のみ / inbox 経由なし)
#
# F-RULE-08 緩和 (task_064d): severity=critical の通知のみ
#   queue/inbox/ojousama_critical.yaml を例外的に運用 (子→親方向の永続化)。
#   通常通信 (low/medium/high) は cmd YAML + tmux nudge を一次経路として維持。
#   詳細: instructions/common/forbidden_actions.md F-RULE-08 補項 (task_064e で文言化予定)
#
# Failure isolation:
#   各経路 (inbox / tmux / ntfy) の失敗は他経路を阻害しない。
#   notify_human.sh は exit 0 を維持し、呼出元 executor の動作を阻害しない。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<EOF >&2
Usage: $0 <role> <context> [--severity <level>] [--category <id>] [--related-yaml <path>]
  role            呼び出し元エージェント名（例: kaseifu, shitsuji, maid_NN）
  context         人間判断が必要な状況の説明
  --severity      low (default) | medium | high | critical
  --category      d_rule | f_rule_09 | acceptance_unparseable | system_failure
                  (severity=critical 時のみ必須)
  --related-yaml  参照 YAML パス (任意 / 未指定時 null 扱い)
EOF
    exit 2
}

severity="low"
category=""
related_yaml=""
positional=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --severity)
            severity="${2:-}"
            shift 2 || usage
            ;;
        --category)
            category="${2:-}"
            shift 2 || usage
            ;;
        --related-yaml)
            related_yaml="${2:-}"
            shift 2 || usage
            ;;
        --help|-h)
            usage
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                positional+=("$1")
                shift
            done
            ;;
        --*)
            echo "[ERROR] unknown flag: $1" >&2
            usage
            ;;
        *)
            positional+=("$1")
            shift
            ;;
    esac
done

if [ "${#positional[@]}" -lt 2 ]; then
    usage
fi

role="${positional[0]}"
context="${positional[1]}"

case "$severity" in
    low|medium|high|critical) ;;
    *)
        echo "[ERROR] invalid --severity: $severity" >&2
        usage
        ;;
esac

if [ "$severity" = "critical" ] && [ -z "$category" ]; then
    echo "[ERROR] --category required when --severity critical" >&2
    usage
fi

if [ -n "$category" ]; then
    case "$category" in
        d_rule|f_rule_09|acceptance_unparseable|system_failure) ;;
        *)
            echo "[ERROR] invalid --category: $category" >&2
            usage
            ;;
    esac
fi

msg="[$role] あなたのご判断が必要です: $context"

# (a) severity=critical のみ ojousama_critical inbox へ永続 append
# F-RULE-08 緩和の例外経路 (task_064d)。失敗しても他経路を阻害しない。
if [ "$severity" = "critical" ]; then
    INBOX_WRITE="$SCRIPT_DIR/inbox_write.sh"
    if [ -x "$INBOX_WRITE" ]; then
        body_yaml="severity=critical category=${category} related_yaml=${related_yaml:-null} msg=${context}"
        bash "$INBOX_WRITE" ojousama_critical "$body_yaml" "$role" >/dev/null 2>&1 || true
    fi
fi

# (b) tmux 2 ステップ送信 (ojousama:0.0) — 既存経路維持
OJOUSAMA_PANE="ojousama:0.0"
if command -v tmux >/dev/null 2>&1; then
    tmux send-keys -t "$OJOUSAMA_PANE" "$msg" 2>/dev/null || true
    sleep 0.2
    tmux send-keys -t "$OJOUSAMA_PANE" Enter 2>/dev/null || true
fi

# (c) ntfy push — 既存経路維持
NTFY_SH="$SCRIPT_DIR/ntfy.sh"
if [ -x "$NTFY_SH" ]; then
    bash "$NTFY_SH" -t "human_decision" -p high "$msg" >/dev/null 2>&1 || true
fi

exit 0
