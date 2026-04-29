#!/usr/bin/env bash
# notify_completion_audit.sh
# Audit completion notifications. Walks queue/{maid_*,shitsuji}_*_report.yaml,
# extracts task_id of reports with status: completed|done, and verifies that
# kaseifu inbox (queue/inbox/kaseifu.yaml) holds a notification entry for each.
#
# Usage:
#   bash scripts/notify_completion_audit.sh                    # audit all reports
#   bash scripts/notify_completion_audit.sh --role maid_03     # single role
#   bash scripts/notify_completion_audit.sh --role shitsuji    # shitsuji only
#   bash scripts/notify_completion_audit.sh --json             # JSON output
#
# Exit codes:
#   0 — all audited reports have a matching notification, OR audit set is empty
#   1 — one or more reports lack a notification entry (WARN)
#   2 — internal error (missing inbox file, unknown role, etc.)
#
# Design (task_062b improvement_1_b / gap_1_1 + gap_1_2):
#   - F-RULE-04 compliant: single-shot. No watcher loops, no polling.
#   - Read-only: never writes to inbox or report files.
#   - No external deps (yq/jq forbidden). bash + grep + awk + sed only.

set -uo pipefail
# NOTE: -e intentionally OFF; collect WARN across reports and aggregate rc.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QUEUE_DIR="$PROJECT_ROOT/queue"
INBOX_FILE="$QUEUE_DIR/inbox/kaseifu.yaml"

JSON_MODE=0
ROLE_FILTER=""

usage() {
    cat <<EOF >&2
Usage: $0 [--role <role>] [--json]
       $0 --help

Roles: maid_01..maid_08, shitsuji (default: all)
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --role)
            ROLE_FILTER="${2:-}"
            shift 2 || { usage; exit 64; }
            ;;
        --json)
            JSON_MODE=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] unknown argument: $1" >&2
            usage
            exit 64
            ;;
    esac
done

if [ ! -f "$INBOX_FILE" ]; then
    echo "[ERROR] kaseifu inbox not found: $INBOX_FILE" >&2
    exit 2
fi

# Resolve audit target list based on --role filter.
TARGETS=()
add_target() {
    local role="$1"
    local path="$2"
    if [ -f "$path" ]; then
        TARGETS+=("${role}|${path}")
    fi
}

if [ -z "$ROLE_FILTER" ]; then
    for f in "$QUEUE_DIR"/maid_*_report.yaml; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        role="${base%_report.yaml}"
        add_target "$role" "$f"
    done
    add_target "shitsuji" "$QUEUE_DIR/shitsuji_report.yaml"
else
    case "$ROLE_FILTER" in
        maid_0[1-8])
            add_target "$ROLE_FILTER" "$QUEUE_DIR/${ROLE_FILTER}_report.yaml"
            ;;
        shitsuji)
            add_target "shitsuji" "$QUEUE_DIR/shitsuji_report.yaml"
            ;;
        *)
            echo "[ERROR] unknown role: $ROLE_FILTER" >&2
            exit 2
            ;;
    esac
fi

# Extract first scalar value of KEY from a report YAML (top-level scalar only).
yaml_scalar() {
    local file="$1"
    local key="$2"
    grep -E "^${key}:[[:space:]]" "$file" 2>/dev/null \
        | head -n1 \
        | sed -E "s/^${key}:[[:space:]]*//; s/^[\"']//; s/[\"']\$//"
}

# mtime in ISO8601 UTC. macOS BSD stat / Linux GNU stat compatible.
file_mtime_iso() {
    local file="$1"
    if stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ" "$file" 2>/dev/null; then
        return 0
    fi
    if stat -c "%y" "$file" 2>/dev/null \
        | awk '{ gsub(/\..*/, "", $2); printf "%sT%sZ\n", $1, $2 }'; then
        return 0
    fi
    echo "unknown"
}

# Check inbox for any message body containing the given task_id.
inbox_has_task_id() {
    local tid="$1"
    grep -F "$tid" "$INBOX_FILE" >/dev/null 2>&1
}

AUDITED=0
WARN_ROLES=()
WARN_REPORTS=()
WARN_TASK_IDS=()
WARN_TS=()

for entry in "${TARGETS[@]}"; do
    role="${entry%%|*}"
    report="${entry#*|}"

    status="$(yaml_scalar "$report" status)"
    case "$status" in
        completed|done) ;;
        *) continue ;;
    esac

    task_id="$(yaml_scalar "$report" task_id)"
    if [ -z "$task_id" ]; then
        continue
    fi

    AUDITED=$((AUDITED + 1))

    if ! inbox_has_task_id "$task_id"; then
        ts="$(file_mtime_iso "$report")"
        WARN_ROLES+=("$role")
        WARN_REPORTS+=("$report")
        WARN_TASK_IDS+=("$task_id")
        WARN_TS+=("$ts")
    fi
done

WARN_COUNT="${#WARN_ROLES[@]}"

# Render report path relative to project root for cleaner output.
rel_path() {
    local abs="$1"
    case "$abs" in
        "$PROJECT_ROOT/"*) echo "${abs#$PROJECT_ROOT/}" ;;
        *) echo "$abs" ;;
    esac
}

if [ "$JSON_MODE" = "1" ]; then
    printf '{\n'
    printf '  "audited": %d,\n' "$AUDITED"
    printf '  "warnings": ['
    if [ "$WARN_COUNT" -gt 0 ]; then
        printf '\n'
        for i in $(seq 0 $((WARN_COUNT - 1))); do
            sep=","
            [ "$i" -eq "$((WARN_COUNT - 1))" ] && sep=""
            printf '    {"role": "%s", "report": "%s", "task_id": "%s", "ts": "%s"}%s\n' \
                "${WARN_ROLES[$i]}" \
                "$(rel_path "${WARN_REPORTS[$i]}")" \
                "${WARN_TASK_IDS[$i]}" \
                "${WARN_TS[$i]}" \
                "$sep"
        done
        printf '  '
    fi
    printf ']\n'
    printf '}\n'
else
    if [ "$WARN_COUNT" -gt 0 ]; then
        for i in $(seq 0 $((WARN_COUNT - 1))); do
            printf '[WARN] role=%s report=%s task_id=%s ts=%s\n' \
                "${WARN_ROLES[$i]}" \
                "$(rel_path "${WARN_REPORTS[$i]}")" \
                "${WARN_TASK_IDS[$i]}" \
                "${WARN_TS[$i]}" >&2
        done
    fi
    if [ "$WARN_COUNT" -eq 0 ]; then
        if [ "$AUDITED" -eq 0 ]; then
            echo "[OK] 0 reports audited, no completed/done reports found"
        else
            echo "[OK] $AUDITED reports audited, all notifications present"
        fi
    else
        echo "[OK] $AUDITED reports audited, $WARN_COUNT notification(s) missing"
    fi
fi

if [ "$WARN_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
