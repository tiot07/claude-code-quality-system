#!/bin/bash

# 🤝 Manager-Developer 直接通信スクリプト
# 同一tmuxウィンドウ内の左右ペイン間でメッセージを送信

set -e

# 使用方法表示
show_usage() {
    echo "🤝 Manager-Developer 直接通信"
    echo "================================"
    echo ""
    echo "使用方法:"
    echo "  ./scripts/send-to-partner.sh \"[メッセージ]\"" 
    echo ""
    echo "動作:"
    echo "  - 左ペイン(QualityManager) → 右ペイン(Developer)"
    echo "  - 右ペイン(Developer) → 左ペイン(QualityManager)"
    echo ""
    echo "例:"
    echo "  ./scripts/send-to-partner.sh \"実装を開始してください\""
    echo ""
}

# 引数チェック
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

MESSAGE="$1"

# tmux環境チェック
if [ -z "$TMUX" ]; then
    echo "❌ エラー: tmuxセッション内で実行してください"
    exit 1
fi

# 現在のペイン情報取得
CURRENT_PANE=$(tmux display-message -p '#P')
WINDOW_NAME=$(tmux display-message -p '#W')
SESSION_NAME=$(tmux display-message -p '#S')

echo "📍 現在の位置: ${SESSION_NAME}:${WINDOW_NAME}.${CURRENT_PANE}"

# 相手ペインの決定
if [ "$CURRENT_PANE" = "0" ]; then
    TARGET_PANE="1"
    SENDER="QualityManager"
    RECEIVER="Developer"
else
    TARGET_PANE="0"
    SENDER="Developer" 
    RECEIVER="QualityManager"
fi

echo "📤 送信: ${SENDER} → ${RECEIVER}"

# ペイン存在確認
if ! tmux list-panes -F "#{pane_index}" | grep -q "^${TARGET_PANE}$"; then
    echo "❌ エラー: 相手ペイン(${TARGET_PANE})が見つかりません"
    echo "現在のペイン構成:"
    tmux list-panes -F "#{pane_index}: #{pane_title}"
    exit 1
fi

# メッセージ送信
echo "💬 メッセージ: $MESSAGE"
tmux send-keys -t "$TARGET_PANE" "$MESSAGE" C-m

echo "✅ 送信完了: ${SENDER} → ${RECEIVER}"

# ログ記録
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/partner_communication.log"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] ${SESSION_NAME}:${WINDOW_NAME} | ${SENDER} → ${RECEIVER} | $MESSAGE" >> "$LOG_FILE"

echo "📝 ログ記録: $LOG_FILE"