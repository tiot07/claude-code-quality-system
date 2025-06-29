#!/bin/bash

# 🚀 Quick Message - 超シンプル版
# 同一ウィンドウ内の相手ペインにメッセージ送信

if [ $# -eq 0 ]; then
    echo "使用方法: ./scripts/msg.sh \"[メッセージ]\""
    exit 0
fi

if [ -z "$TMUX" ]; then
    echo "❌ tmuxセッション内で実行してください"
    exit 1
fi

# 現在のペイン番号取得
CURRENT_PANE=$(tmux display-message -p '#P')

# 相手ペイン決定
if [ "$CURRENT_PANE" = "0" ]; then
    TARGET_PANE="1"
else
    TARGET_PANE="0"
fi

# メッセージ送信
tmux send-keys -t "$TARGET_PANE" "$1" C-m

echo "✅ 送信完了"