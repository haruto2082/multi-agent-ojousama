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

# ── Window 0: ojousama（1画面）──
tmux new-session -d -s $SESSION -n "ojousama" -c "$REPO_DIR"

# ── Window 1: staff（家政婦＋メイド全員タイル）──
tmux new-window -t "${SESSION}:" -n "staff" -c "$REPO_DIR"

# 最初のペイン（家政婦）のIDを取得
PANE_KASEIFU=$(tmux display-message -t "${SESSION}:staff" -p "#{pane_id}")

# メイド分だけ分割
PANE_MAIDS=()
for i in $(seq 1 $MAID_COUNT); do
    PANE_ID=$(tmux split-window -t "${SESSION}:staff" -c "$REPO_DIR" -P -F "#{pane_id}")
    PANE_MAIDS+=($PANE_ID)
done

# タイルレイアウト適用
tmux select-layout -t "${SESSION}:staff" tiled

sleep 0.5

# ── Claude起動 ──

# ojousama
tmux send-keys -t $SESSION:ojousama "$CLAUDE_CMD"
tmux send-keys -t $SESSION:ojousama Enter
sleep 1

# 家政婦
tmux send-keys -t $PANE_KASEIFU "$CLAUDE_CMD"
tmux send-keys -t $PANE_KASEIFU Enter
sleep 1

# メイド
for PANE_ID in "${PANE_MAIDS[@]}"; do
    tmux send-keys -t $PANE_ID "$CLAUDE_CMD"
    tmux send-keys -t $PANE_ID Enter
    sleep 0.5
done

# フォーカスをojousamaに
tmux select-window -t $SESSION:ojousama

if [ -n "$TMUX" ]; then
    tmux switch-client -t $SESSION
else
    tmux attach-session -t $SESSION
fi
