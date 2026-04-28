#!/bin/bash
# setup.sh - ojousama manor multi-agent launcher.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/log.sh"

SESSION="ojousama"
MAID_COUNT=4
SETUP_ONLY=false
SILENT=false
KESSEN=false
DO_CLEAN=false

# Bloom routing defaults
MODEL_OJOUSAMA="opus"
MODEL_SHITSUJI="opus"
MODEL_KASEIFU="sonnet"
MODEL_MAID="sonnet"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] [maid_count]

Options:
  --clean         queue/* と workspace/* をバックアップしてリセット
  --setup-only    tmuxセットアップのみ実施（Claude起動なし）
  --silent        バナー出力を抑制
  --kessen        晩餐会の陣（全メイドを Opus で起動）
  --help, -h      このヘルプを表示

Bloom routing:
  お嬢様 = Opus
  執事   = Opus
  家政婦 = Sonnet
  メイド = Sonnet  (--kessen 時は Opus)

例:
  $(basename "$0")                    # メイド4体（既定）
  $(basename "$0") 6                  # メイド6体
  $(basename "$0") --clean --kessen 8 # クリーン後にメイド8体・全Opusで起動
  $(basename "$0") --setup-only       # tmuxのみ（Claude起動せず）
EOF
}

# parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --clean)      DO_CLEAN=true; shift ;;
        --setup-only) SETUP_ONLY=true; shift ;;
        --silent)     SILENT=true; shift ;;
        --kessen)     KESSEN=true; MODEL_MAID="opus"; shift ;;
        --help|-h)    usage; exit 0 ;;
        --*)
            log_error "未知のオプション: $1"
            usage >&2
            exit 2
            ;;
        *)
            MAID_COUNT="$1"; shift ;;
    esac
done

# banner
if [ "$SILENT" != true ]; then
    if [ -f "$SCRIPT_DIR/banner.sh" ]; then
        # shellcheck disable=SC1091
        . "$SCRIPT_DIR/banner.sh"
        ojousama_banner
    fi
fi

# clean (backup then reset)
if [ "$DO_CLEAN" = true ]; then
    BACKUP_DIR="$REPO_DIR/logs/backup_$(date +%Y%m%d_%H%M%S)"
    log_info "queue/* と workspace/* を $BACKUP_DIR にバックアップします"
    mkdir -p "$BACKUP_DIR"
    if [ -d "$REPO_DIR/queue" ]; then
        cp -R "$REPO_DIR/queue" "$BACKUP_DIR/queue" 2>/dev/null || true
        find "$REPO_DIR/queue" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -exec rm -rf {} + 2>/dev/null || true
    fi
    if [ -d "$REPO_DIR/workspace" ]; then
        cp -R "$REPO_DIR/workspace" "$BACKUP_DIR/workspace" 2>/dev/null || true
        find "$REPO_DIR/workspace" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -exec rm -rf {} + 2>/dev/null || true
    fi
    log_done "クリーン完了: $BACKUP_DIR"
fi

# claude detection (skipped in setup-only mode)
CLAUDE_CMD=""
if [ "$SETUP_ONLY" != true ]; then
    CLAUDE_CMD=$(command -v claude 2>/dev/null || true)
    if [ -z "$CLAUDE_CMD" ]; then
        CLAUDE_CMD=$(ls "$HOME"/.nvm/versions/node/*/bin/claude 2>/dev/null | tail -1 || true)
    fi
    if [ -z "$CLAUDE_CMD" ]; then
        log_error "claude コマンドが見つかりません"
        exit 1
    fi
    log_info "claude: $CLAUDE_CMD"
fi

# build launch command per role
launch_cmd() {
    role="$1"
    model="$2"
    if [ "$SETUP_ONLY" = true ]; then
        printf ''
    else
        printf 'env AGENT_ROLE=%s %s --model %s' "$role" "$CLAUDE_CMD" "$model"
    fi
}

# kill existing session
if tmux has-session -t "$SESSION" 2>/dev/null; then
    log_warn "既存セッションを停止します: $SESSION"
    tmux kill-session -t "$SESSION"
    sleep 0.5
fi

log_serve "お嬢様邸を開設します（メイド ${MAID_COUNT} 体${KESSEN:+ / 晩餐会の陣}）"

# Window 0: ojousama
CMD=$(launch_cmd ojousama "$MODEL_OJOUSAMA")
tmux new-session -d -s "$SESSION" -n "ojousama" -c "$REPO_DIR" -x 250 -y 50 "$CMD"

# Window 1: staff (shitsuji + kaseifu)
CMD=$(launch_cmd shitsuji "$MODEL_SHITSUJI")
tmux new-window -t "${SESSION}:" -n "staff" -c "$REPO_DIR" "$CMD"

CMD=$(launch_cmd kaseifu "$MODEL_KASEIFU")
tmux split-window -t "${SESSION}:1" -c "$REPO_DIR" "$CMD"
tmux select-layout -t "${SESSION}:1" even-horizontal

# Window 2: maids
CMD=$(launch_cmd maid_01 "$MODEL_MAID")
tmux new-window -t "${SESSION}:" -n "maids" -c "$REPO_DIR" "$CMD"

for i in $(seq 2 "$MAID_COUNT"); do
    MAID_NAME=$(printf "maid_%02d" "$i")
    CMD=$(launch_cmd "$MAID_NAME" "$MODEL_MAID")
    tmux split-window -t "${SESSION}:2" -c "$REPO_DIR" "$CMD"
    tmux select-layout -t "${SESSION}:2" tiled
done

sleep 0.5

# tag panes with @agent_id
tmux set-option -p -t "${SESSION}:0.0" @agent_id "ojousama"
tmux set-option -p -t "${SESSION}:1.0" @agent_id "shitsuji"
tmux set-option -p -t "${SESSION}:1.1" @agent_id "kaseifu"
for i in $(seq 1 "$MAID_COUNT"); do
    MAID_NAME=$(printf "maid_%02d" "$i")
    PANE_INDEX=$((i - 1))
    tmux set-option -p -t "${SESSION}:2.$PANE_INDEX" @agent_id "$MAID_NAME"
done

log_done "起動完了"
log_info "Bloom routing: ojousama=$MODEL_OJOUSAMA, shitsuji=$MODEL_SHITSUJI, kaseifu=$MODEL_KASEIFU, maid=$MODEL_MAID"

tmux select-window -t "${SESSION}:0"

if [ "$SETUP_ONLY" = true ]; then
    log_info "--setup-only のため Claude は起動していません"
    exit 0
fi

if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION"
else
    tmux attach-session -t "$SESSION"
fi
