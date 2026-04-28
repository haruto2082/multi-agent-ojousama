#!/usr/bin/env bash
# lint_task_yaml.sh
# Pre-flight lint for kaseifu-issued task YAML files.
#
# Usage:
#   bash scripts/lint_task_yaml.sh queue/kaseifu_to_maid_05.yaml
#   bash scripts/lint_task_yaml.sh --all
#
# Checks (per file):
#   a) notify_target_override == "ojousama:1.1" (kaseifu pane).
#      mismatch -> warn (rc=1). missing -> info (rc=0, optional field).
#   b) notify_target_override does NOT equal the pane of the recipient role
#      (= self-pane misroute). violation -> error (rc=2).
#   c) target_files entries do not collide with other kaseifu_to_*.yaml
#      in the same directory (RACE-001). collision -> warn (rc=1).
#   d) action block references file paths (scripts/.. templates/.. etc.)
#      that are not listed in target_files. mismatch -> warn (rc=1).
#      heuristic / approximate match; false positives tolerated.
#      skipped when target_files is empty (investigation tasks).
#
# No external deps (yq/jq forbidden). bash + grep + awk only.
# F-RULE-04: single-shot, no watcher loops.

set -uo pipefail
# NOTE: -e is intentionally OFF; we collect issues across files and aggregate rc.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

KASEIFU_PANE="ojousama:1.1"

role_to_pane() {
    case "$1" in
        ojousama) echo "ojousama:0.0" ;;
        shitsuji) echo "ojousama:1.0" ;;
        kaseifu)  echo "$KASEIFU_PANE" ;;
        maid_01)  echo "ojousama:2.0" ;;
        maid_02)  echo "ojousama:2.1" ;;
        maid_03)  echo "ojousama:2.2" ;;
        maid_04)  echo "ojousama:2.3" ;;
        maid_05)  echo "ojousama:2.4" ;;
        maid_06)  echo "ojousama:2.5" ;;
        maid_07)  echo "ojousama:2.6" ;;
        maid_08)  echo "ojousama:2.7" ;;
        *) return 1 ;;
    esac
}

# Extract first top-level scalar value for KEY from FILE.
yaml_get() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || return 1
    grep -E "^${key}:[[:space:]]" "$file" 2>/dev/null \
        | head -n1 \
        | sed -E "s/^${key}:[[:space:]]*//; s/^[\"']//; s/[\"']\$//; s/[[:space:]]+#.*\$//" \
        | sed -E 's/[[:space:]]+$//'
}

# Extract a YAML literal block ("KEY: |") body. Stops at the next top-level key.
yaml_get_block() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || return 1
    awk -v k="$key" '
        $0 ~ "^"k":[[:space:]]*\\|" { in_block=1; next }
        in_block && /^[A-Za-z_]/ { in_block=0 }
        in_block { print }
    ' "$file"
}

# Extract list items under top-level KEY: (block list with leading "  - ").
yaml_get_list() {
    local file="$1"
    local key="$2"
    [ -f "$file" ] || return 1
    awk -v k="$key" '
        $0 ~ "^"k":" { in_block=1; next }
        in_block {
            if ($0 ~ /^[[:space:]]*-[[:space:]]/) {
                line=$0
                sub(/^[[:space:]]*-[[:space:]]*/, "", line)
                gsub(/^["'"'"']/, "", line)
                gsub(/["'"'"']$/, "", line)
                print line
            } else if ($0 ~ /^[A-Za-z_]/) {
                in_block=0
            }
        }
    ' "$file"
}

# rc accumulator: 0=ok, 1=warn, 2=error. Higher wins.
WORST_RC=0
bump_rc() {
    local cand="$1"
    if [ "$cand" -gt "$WORST_RC" ]; then
        WORST_RC="$cand"
    fi
}

emit() {
    local level="$1"; shift
    local file="$1"; shift
    local check="$1"; shift
    printf '[%s] %s :: %s :: %s\n' "$level" "$file" "$check" "$*"
}

lint_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        emit ERROR "$file" exists "file not found"
        bump_rc 2
        return
    fi

    local to_role
    to_role="$(yaml_get "$file" to)"
    local override
    override="$(yaml_get "$file" notify_target_override)"

    # Check (a): notify_target_override should equal kaseifu pane.
    if [ -z "$override" ]; then
        emit INFO "$file" notify_target_override "field missing (optional)"
    elif [ "$override" = "$KASEIFU_PANE" ]; then
        emit PASS "$file" notify_target_override "ok ($override)"
    else
        emit WARN "$file" notify_target_override "expected '$KASEIFU_PANE', got '$override'"
        bump_rc 1
    fi

    # Check (b): notify_target_override must not equal the recipient role's own pane.
    if [ -n "$override" ] && [ -n "$to_role" ]; then
        local recipient_pane
        if recipient_pane="$(role_to_pane "$to_role")"; then
            if [ "$override" = "$recipient_pane" ]; then
                emit ERROR "$file" self_pane_misroute \
                    "notify_target_override '$override' equals recipient '$to_role' own pane (=$recipient_pane). misroute."
                bump_rc 2
            else
                emit PASS "$file" self_pane_misroute "ok (recipient=$to_role pane=$recipient_pane)"
            fi
        else
            emit INFO "$file" self_pane_misroute "unknown recipient role '$to_role'; skip"
        fi
    fi

    # Check (c): target_files collision with other kaseifu_to_*.yaml.
    local files_in_this
    files_in_this="$(yaml_get_list "$file" target_files)"
    if [ -n "$files_in_this" ]; then
        local dir
        dir="$(dirname "$file")"
        local self
        self="$(basename "$file")"
        local collisions=""
        local other tf other_files
        for other in "$dir"/kaseifu_to_maid_*.yaml "$dir"/kaseifu_to_shitsuji_*.yaml; do
            [ -f "$other" ] || continue
            [ "$(basename "$other")" = "$self" ] && continue
            other_files="$(yaml_get_list "$other" target_files)"
            [ -z "$other_files" ] && continue
            while IFS= read -r tf; do
                [ -z "$tf" ] && continue
                if echo "$other_files" | grep -Fxq "$tf"; then
                    collisions="${collisions}${tf}<-vs->$(basename "$other")\n"
                fi
            done <<< "$files_in_this"
        done
        if [ -n "$collisions" ]; then
            emit WARN "$file" target_files_collision "RACE-001 candidates:"
            printf "%b" "$collisions" | sed 's/^/    /'
            bump_rc 1
        else
            emit PASS "$file" target_files_collision "ok"
        fi
    fi

    # Check (d): action block references file paths not listed in target_files.
    # Heuristic / approximate; false positives tolerated. Skipped when
    # target_files is empty (investigation tasks).
    if [ -n "$files_in_this" ]; then
        local action_block
        action_block="$(yaml_get_block "$file" action)"
        if [ -n "$action_block" ]; then
            local action_paths missing path
            action_paths="$(printf '%s\n' "$action_block" \
                | grep -oE '(scripts|templates|instructions|queue|workspace|tests|config|docs|skills)/[A-Za-z0-9_./{}-]+\.(sh|yaml|yml|md|py|js|ts|json)' \
                | sort -u)"
            missing=""
            if [ -n "$action_paths" ]; then
                while IFS= read -r path; do
                    [ -z "$path" ] && continue
                    # Skip placeholder paths containing template tokens like {NN}.
                    case "$path" in
                        *"{"*"}"*) continue ;;
                    esac
                    if ! printf '%s\n' "$files_in_this" | grep -Fxq "$path"; then
                        missing="${missing}${path}\n"
                    fi
                done <<< "$action_paths"
            fi
            if [ -n "$missing" ]; then
                emit WARN "$file" action_target_files_mismatch "paths in action not listed in target_files (Check d):"
                printf "%b" "$missing" | sed 's/^/    /'
                bump_rc 1
            else
                emit PASS "$file" action_target_files_mismatch "ok (Check d)"
            fi
        fi
    fi
}

main() {
    local files=()
    if [ "${1:-}" = "--all" ]; then
        local f
        for f in "$PROJECT_ROOT"/queue/kaseifu_to_maid_*.yaml \
                 "$PROJECT_ROOT"/queue/kaseifu_to_shitsuji_*.yaml; do
            [ -f "$f" ] && files+=("$f")
        done
        if [ "${#files[@]}" -eq 0 ]; then
            echo "[lint] no kaseifu_to_*.yaml files under queue/"
            exit 0
        fi
    elif [ -n "${1:-}" ]; then
        files=("$1")
    else
        cat <<EOF >&2
Usage: $0 <task_yaml_path>
       $0 --all
EOF
        exit 64
    fi

    local f
    for f in "${files[@]}"; do
        lint_file "$f"
    done

    echo "[lint] worst rc: $WORST_RC (0=ok, 1=warn, 2=error)"
    exit "$WORST_RC"
}

main "$@"
