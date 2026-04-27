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

# ウィンドウ作成
tmux new-session -d -s $SESSION -n "ojousama" -c "$REPO_DIR"
tmux new-window -t "${SESSION}:" -n "kaseifu" -c "$REPO_DIR"

for i in $(seq 1 $MAID_COUNT); do
    MAID_NAME=$(printf "maid_%02d" $i)
    tmux new-window -t "${SESSION}:" -n "$MAID_NAME" -c "$REPO_DIR"
done

sleep 0.5

# 各ウィンドウでClaude起動（2ステップ厳守）
tmux send-keys -t $SESSION:ojousama "$CLAUDE_CMD"
tmux send-keys -t $SESSION:ojousama Enter
sleep 1

tmux send-keys -t $SESSION:kaseifu "$CLAUDE_CMD"
tmux send-keys -t $SESSION:kaseifu Enter
sleep 1

for i in $(seq 1 $MAID_COUNT); do
    MAID_NAME=$(printf "maid_%02d" $i)
    tmux send-keys -t $SESSION:$MAID_NAME "$CLAUDE_CMD"
    tmux send-keys -t $SESSION:$MAID_NAME Enter
    sleep 0.5
done

# tmux内から実行している場合はswitch、外からはattach
tmux select-window -t $SESSION:ojousama
if [ -n "$TMUX" ]; then
    tmux switch-client -t $SESSION
else
    tmux attach-session -t $SESSION
fi
