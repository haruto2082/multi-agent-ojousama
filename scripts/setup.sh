#!/bin/bash
set -e

SESSION="ojousama"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAID_COUNT=${1:-4}

# 既存セッションがあれば停止
if tmux has-session -t $SESSION 2>/dev/null; then
    tmux kill-session -t $SESSION
    echo "既存セッションを停止しました"
    sleep 0.5
fi

echo "お嬢様邸を開設しています... (メイド${MAID_COUNT}体)"

# お嬢様ウィンドウ（index 0）
tmux new-session -d -s $SESSION -n "ojousama" -c "$REPO_DIR"

# 家政婦・メイドウィンドウ（"SESSION:" でindex自動採番）
tmux new-window -t "${SESSION}:" -n "kaseifu" -c "$REPO_DIR"

for i in $(seq 1 $MAID_COUNT); do
    MAID_NAME=$(printf "maid_%02d" $i)
    tmux new-window -t "${SESSION}:" -n "$MAID_NAME" -c "$REPO_DIR"
done

# 各ウィンドウでClaudeを起動（2ステップ厳守）
tmux send-keys -t $SESSION:ojousama "claude"
tmux send-keys -t $SESSION:ojousama Enter

sleep 1

tmux send-keys -t $SESSION:kaseifu "claude"
tmux send-keys -t $SESSION:kaseifu Enter

sleep 1

for i in $(seq 1 $MAID_COUNT); do
    MAID_NAME=$(printf "maid_%02d" $i)
    tmux send-keys -t $SESSION:$MAID_NAME "claude"
    tmux send-keys -t $SESSION:$MAID_NAME Enter
    sleep 0.5
done

# お嬢様ウィンドウにフォーカス
tmux select-window -t $SESSION:ojousama
tmux attach-session -t $SESSION
