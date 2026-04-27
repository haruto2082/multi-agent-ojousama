#!/bin/bash
# 使い方: ./scripts/notify.sh <window_name> "<message>"
# 例:     ./scripts/notify.sh kaseifu "新しい指示があります"

SESSION="ojousama"
TARGET=$1
MESSAGE=$2

if [ -z "$TARGET" ] || [ -z "$MESSAGE" ]; then
    echo "使い方: notify.sh <window_name> <message>"
    echo "例:     notify.sh kaseifu \"新しい指示があります\""
    exit 1
fi

# フレンドリーファイア防止のため2ステップ送信
tmux send-keys -t $SESSION:$TARGET "$MESSAGE"
sleep 0.3
tmux send-keys -t $SESSION:$TARGET Enter
