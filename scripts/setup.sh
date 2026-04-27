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

# ── Window 0: ojousama ──
tmux new-session -d -s $SESSION -n "ojousama" -c "$REPO_DIR" -x 250 -y 50

# ── Window 1: staff（家政婦＋メイド全員タイル）──
tmux new-window -t "${SESSION}:" -n "staff" -c "$REPO_DIR"

# 分割のたびにtiled再適用してスペースを確保
for i in $(seq 1 $MAID_COUNT); do
    tmux split-window -t "${SESSION}:1" -c "$REPO_DIR"
    tmux select-layout -t "${SESSION}:1" tiled
done

# 最終レイアウト確認
ACTUAL_PANES=$(tmux list-panes -t "${SESSION}:1" | wc -l | tr -d ' ')
echo "作成されたpane数: $ACTUAL_PANES（必要: $((MAID_COUNT + 1))）"

sleep 0.5

# ── Claude起動 ──

# ojousama（window 0）
tmux send-keys -t "${SESSION}:0.0" "$CLAUDE_CMD"
tmux send-keys -t "${SESSION}:0.0" Enter
sleep 1

# staffウィンドウの全paneにClaudeを起動
for i in $(seq 0 $MAID_COUNT); do
    tmux send-keys -t "${SESSION}:1.$i" "$CLAUDE_CMD" 2>/dev/null
    tmux send-keys -t "${SESSION}:1.$i" Enter 2>/dev/null
    sleep 0.5
done

echo "起動完了"
tmux select-window -t "${SESSION}:0"

if [ -n "$TMUX" ]; then
    tmux switch-client -t $SESSION
else
    tmux attach-session -t $SESSION
fi
