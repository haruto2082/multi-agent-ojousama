#!/bin/bash
set -e

SESSION="ojousama"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAID_COUNT=${1:-4}  # デフォルト4体（引数で変更可能: ./setup.sh 8）

# 既存セッションがあれば停止
tmux kill-session -t $SESSION 2>/dev/null && echo "既存セッションを停止しました" || true

echo "お嬢様邸を開設しています... (メイド${MAID_COUNT}体)"

# お嬢様ウィンドウ（最初のウィンドウ）
tmux new-session -d -s $SESSION -n "ojousama" -c "$REPO_DIR"

# 家政婦ウィンドウ
tmux new-window -t $SESSION -n "kaseifu" -c "$REPO_DIR"

# メイドウィンドウ
for i in $(seq -f "%02g" 1 $MAID_COUNT); do
    tmux new-window -t $SESSION -n "maid_$i" -c "$REPO_DIR"
done

# 各ウィンドウでClaudeを起動（2ステップ厳守）
tmux send-keys -t $SESSION:ojousama "claude"
tmux send-keys -t $SESSION:ojousama Enter

sleep 1

tmux send-keys -t $SESSION:kaseifu "claude"
tmux send-keys -t $SESSION:kaseifu Enter

sleep 1

for i in $(seq -f "%02g" 1 $MAID_COUNT); do
    tmux send-keys -t $SESSION:maid_$i "claude"
    tmux send-keys -t $SESSION:maid_$i Enter
    sleep 0.5
done

# お嬢様ウィンドウにフォーカス
tmux select-window -t $SESSION:ojousama
tmux attach-session -t $SESSION
