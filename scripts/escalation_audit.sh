#!/usr/bin/env bash
# escalation_audit.sh
# Audit escalation_required flags in maid/shitsuji report YAMLs and verify
# they are reflected in kaseifu_to_ojousama.yaml issues.
#
# Usage:
#   bash scripts/escalation_audit.sh           # text mode (default)
#   bash scripts/escalation_audit.sh --json    # JSON mode
#
# Exit codes:
#   0 - all escalations reflected (or zero audited)
#   1 - one or more escalations missing in kaseifu_to_ojousama.yaml issues
#   2 - internal error (file unreadable, etc.)
#
# F-RULE-04: single-shot, no watcher loops, no polling.
# Sources scanned: queue/maid_*_report.yaml + queue/shitsuji_report.yaml
# Target check: queue/kaseifu_to_ojousama.yaml `issues:` block
#
# Detection rule:
#   A report is flagged when it contains an `escalation_required:` block
#   with a `needed: true` or `needed: yes` child. The report's top-level
#   `task_id:` and the block's `reason:` are extracted for the warning.
#
# task_062f / improvement_3_b / gap_3_2

set -uo pipefail
# NOTE: -e is intentionally OFF; we collect findings across files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OJOUSAMA_FILE="$PROJECT_ROOT/queue/kaseifu_to_ojousama.yaml"

# Extract first top-level scalar value for KEY from FILE.
yaml_get_top() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || return 1
    grep -E "^${key}:[[:space:]]" "$file" 2>/dev/null \
        | head -n1 \
        | sed -E "s/^${key}:[[:space:]]*//; s/^[\"']//; s/[\"']\$//; s/[[:space:]]+#.*\$//" \
        | sed -E 's/[[:space:]]+$//'
}

# Detect whether FILE contains `escalation_required:` with nested `needed: true|yes`.
# Emits "needed_value|reason" to stdout (one line) if positive, otherwise nothing.
extract_escalation() {
    local file="$1"
    [ -f "$file" ] || return 1
    awk '
        BEGIN { in_block=0; needed=""; reason="" }
        /^escalation_required:/ { in_block=1; next }
        in_block {
            if ($0 ~ /^[A-Za-z_]/) { in_block=0; next }
            if ($0 ~ /^[[:space:]]+needed:[[:space:]]*/) {
                v=$0
                sub(/^[[:space:]]+needed:[[:space:]]*/, "", v)
                gsub(/^["'"'"']/, "", v); gsub(/["'"'"']$/, "", v)
                gsub(/[[:space:]]+#.*$/, "", v)
                gsub(/[[:space:]]+$/, "", v)
                needed=v
            } else if ($0 ~ /^[[:space:]]+reason:[[:space:]]*/) {
                v=$0
                sub(/^[[:space:]]+reason:[[:space:]]*/, "", v)
                gsub(/^["'"'"']/, "", v); gsub(/["'"'"']$/, "", v)
                gsub(/[[:space:]]+$/, "", v)
                reason=v
            }
        }
        END {
            if (needed == "true" || needed == "yes") {
                print needed "|" reason
            }
        }
    ' "$file"
}

# Check whether kaseifu_to_ojousama.yaml `issues:` block mentions TASK_ID.
issues_mentions() {
    local task_id="$1"
    [ -f "$OJOUSAMA_FILE" ] || return 1
    awk -v needle="$task_id" '
        BEGIN { in_block=0; found=0 }
        /^issues:/ { in_block=1; next }
        in_block {
            if ($0 ~ /^[A-Za-z_]/) { in_block=0; next }
            if (index($0, needle) > 0) { found=1; exit }
        }
        END { exit (found ? 0 : 1) }
    ' "$OJOUSAMA_FILE"
}

# Collect findings into parallel arrays.
declare -a WARN_ROLES WARN_REPORTS WARN_TASK_IDS WARN_REASONS
AUDITED=0
WARNINGS=0

derive_role() {
    local base="$1"
    base="$(basename "$base")"
    if [[ "$base" == shitsuji_report.yaml ]]; then
        echo "shitsuji"
    elif [[ "$base" =~ ^maid_([0-9]+)_report\.yaml$ ]]; then
        echo "maid_${BASH_REMATCH[1]}"
    else
        echo "${base%.yaml}"
    fi
}

audit_file() {
    local file="$1"
    local result
    result="$(extract_escalation "$file")" || return 0
    [ -z "$result" ] && return 0

    AUDITED=$((AUDITED + 1))
    local needed reason role task_id
    needed="${result%%|*}"
    reason="${result#*|}"
    role="$(derive_role "$file")"
    task_id="$(yaml_get_top "$file" task_id)"
    [ -z "$task_id" ] && task_id="(unknown)"

    if [ -z "$task_id" ] || [ "$task_id" = "(unknown)" ]; then
        WARN_ROLES+=("$role")
        WARN_REPORTS+=("$file")
        WARN_TASK_IDS+=("(unknown)")
        WARN_REASONS+=("$reason")
        WARNINGS=$((WARNINGS + 1))
        return
    fi

    if issues_mentions "$task_id"; then
        return
    fi

    WARN_ROLES+=("$role")
    WARN_REPORTS+=("$file")
    WARN_TASK_IDS+=("$task_id")
    WARN_REASONS+=("$reason")
    WARNINGS=$((WARNINGS + 1))
}

main() {
    local mode="text"
    case "${1:-}" in
        --json) mode="json" ;;
        "" )    mode="text" ;;
        -h|--help)
            sed -n '2,30p' "$0" >&2
            exit 0
            ;;
        *)
            echo "[escalation_audit] unknown arg: $1" >&2
            exit 2
            ;;
    esac

    if [ ! -f "$OJOUSAMA_FILE" ]; then
        echo "[escalation_audit] kaseifu_to_ojousama.yaml not found: $OJOUSAMA_FILE" >&2
        exit 2
    fi

    local f
    for f in "$PROJECT_ROOT"/queue/maid_*_report.yaml \
             "$PROJECT_ROOT"/queue/shitsuji_report.yaml; do
        [ -f "$f" ] || continue
        audit_file "$f"
    done

    if [ "$mode" = "json" ]; then
        printf '{"audited":%d,"warnings":[' "$AUDITED"
        local i first=1
        for ((i=0; i<WARNINGS; i++)); do
            [ $first -eq 0 ] && printf ','
            first=0
            local role="${WARN_ROLES[$i]}"
            local rep="${WARN_REPORTS[$i]#$PROJECT_ROOT/}"
            local tid="${WARN_TASK_IDS[$i]}"
            local rsn="${WARN_REASONS[$i]}"
            rsn="${rsn//\\/\\\\}"; rsn="${rsn//\"/\\\"}"
            printf '{"role":"%s","report":"%s","task_id":"%s","reason":"%s"}' \
                "$role" "$rep" "$tid" "$rsn"
        done
        printf ']}\n'
    else
        local i
        for ((i=0; i<WARNINGS; i++)); do
            local role="${WARN_ROLES[$i]}"
            local rep="${WARN_REPORTS[$i]#$PROJECT_ROOT/}"
            local tid="${WARN_TASK_IDS[$i]}"
            local rsn="${WARN_REASONS[$i]}"
            printf '[WARN] role=%s report=%s task_id=%s reason="%s"\n' \
                "$role" "$rep" "$tid" "$rsn" >&2
        done
        if [ "$WARNINGS" -eq 0 ]; then
            echo "[OK] $AUDITED escalations audited, all reflected in kaseifu_to_ojousama.yaml"
        else
            echo "[OK] $AUDITED escalations audited, $WARNINGS missing in issues"
        fi
    fi

    if [ "$WARNINGS" -gt 0 ]; then
        exit 1
    fi
    exit 0
}

main "$@"
