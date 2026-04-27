#!/bin/bash

SESSION="ojousama"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAID_COUNT=${1:-4}

# claudeのフルパスを取得
CLAUDE_CMD=$(which claude 2>/dev/null)
if [ -z "$CLAUDE_CMD" ]; then
    CLAUDE_CMD=$(ls ~/.nvm/versions/node/*/bin/claude 2>/dev/null | tail -1)
fi
if [ -z "$CLAUDE_CMD" ]; then
    echo "エラー: claudeコマンドが見つかりません"
    exit 1
fi
echo "claude: $CLAUDE_CMD"

# 既存セッションがあれば停止
if tmux has-session -t $SESSION 2>/dev/null; then
    tmux kill-session -t $SESSION
    echo "既存セッションを停止しました"
    sleep 0.5
fi

echo "お嬢様邸を開設しています... (メイド${MAID_COUNT}体)"

# ── Window 0: ojousama（Claude直接起動）──
tmux new-session -d -s $SESSION -n "ojousama" -c "$REPO_DIR" -x 250 -y 50 "$CLAUDE_CMD"

# ── Window 1: staff（家政婦をClaudeで直接起動）──
tmux new-window -t "${SESSION}:" -n "staff" -c "$REPO_DIR" "$CLAUDE_CMD"

# メイド分だけ分割（分割時にClaude直接起動＋都度tiled再適用）
for i in $(seq 1 $MAID_COUNT); do
    tmux split-window -t "${SESSION}:1" -c "$REPO_DIR" "$CLAUDE_CMD"
    tmux select-layout -t "${SESSION}:1" tiled
done

# paneタイトルをセット（window名はClaudeに上書きされるため）
tmux select-pane -t "${SESSION}:0.0" -T "ojousama"
tmux select-pane -t "${SESSION}:1.0" -T "kaseifu"
for i in $(seq 1 $MAID_COUNT); do
    MAID_NAME=$(printf "maid_%02d" $i)
    tmux select-pane -t "${SESSION}:1.$i" -T "$MAID_NAME"
done

echo "起動完了"
tmux select-window -t "${SESSION}:0"

if [ -n "$TMUX" ]; then
    tmux switch-client -t $SESSION
else
    tmux attach-session -t $SESSION
fi
