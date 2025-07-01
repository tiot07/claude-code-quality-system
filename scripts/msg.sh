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

# 現在のペイン番号とウィンドウ名取得
CURRENT_PANE=$(tmux display-message -p '#P')
CURRENT_WINDOW=$(tmux display-message -p '#W')

# 相手ペイン決定
if [ "$CURRENT_PANE" = "0" ]; then
    TARGET_PANE="1"
    TARGET_AGENT="developer"
else
    TARGET_PANE="0"
    TARGET_AGENT="quality-manager"
fi

# フルターゲット指定（より確実）
TARGET="claude-qa-system:${CURRENT_WINDOW}.${TARGET_PANE}"

# Claudeが確実に入力を認識するように改善されたメッセージ送信
# 1. 現在の入力をクリア（C-cの方が確実）
tmux send-keys -t "$TARGET" C-c

# 2. 短い待機（処理安定化）
sleep 0.3

# 3. メッセージ全体を一度に送信
tmux send-keys -t "$TARGET" "$1"

# 4. 短い待機
sleep 0.1

# 5. Enterを送信
tmux send-keys -t "$TARGET" C-m

# ログ記録
mkdir -p logs
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$CURRENT_WINDOW] msg.sh: ペイン$CURRENT_PANE → $TARGET_AGENT: $1" >> logs/direct_message.log

echo "📤 メッセージ送信完了"
echo "   送信先: $TARGET_AGENT (ペイン $TARGET_PANE)"
echo "   ウィンドウ: $CURRENT_WINDOW"