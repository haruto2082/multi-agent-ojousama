#!/bin/bash
SESSION="ojousama"
tmux kill-session -t $SESSION 2>/dev/null \
    && echo "お嬢様邸を閉鎖しました。" \
    || echo "セッション '$SESSION' が見つかりません。"
