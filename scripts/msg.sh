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

# Claudeが確実に入力を認識するように改善されたメッセージ送信
# 1. 現在のプロンプトをクリア
tmux send-keys -t "$TARGET_PANE" C-u

# 2. 短い待機（処理安定化）
sleep 0.2

# 3. メッセージを段階的に送信
echo "$1" | while IFS= read -r line || [ -n "$line" ]; do
    tmux send-keys -t "$TARGET_PANE" "$line"
    sleep 0.1
done

# 4. Enterを送信
tmux send-keys -t "$TARGET_PANE" C-m

# 5. フォーカスを確実にする
tmux select-pane -t "$TARGET_PANE"
sleep 0.1
tmux select-pane -t "$CURRENT_PANE"

# ログ記録
echo "[$(date '+%Y-%m-%d %H:%M:%S')] msg.sh: ペイン$CURRENT_PANE → ペイン$TARGET_PANE: $1" >> logs/direct_message.log

echo "📤 メッセージ送信完了"
echo "   送信先: ペイン $TARGET_PANE"
echo "   内容: $1"