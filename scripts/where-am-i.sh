#!/bin/bash

# 📍 Where Am I - 現在の位置確認スクリプト

if [ -z "$TMUX" ]; then
    echo "❌ tmuxセッション外です"
    exit 1
fi

# 現在の位置情報取得
SESSION_NAME=$(tmux display-message -p '#S')
WINDOW_NAME=$(tmux display-message -p '#W')
PANE_INDEX=$(tmux display-message -p '#P')

echo "📍 現在の位置"
echo "=============="
echo "セッション: $SESSION_NAME"
echo "ウィンドウ: $WINDOW_NAME"
echo "ペイン: $PANE_INDEX"

# 役割判定
if [ "$PANE_INDEX" = "0" ]; then
    ROLE="QualityManager (左ペイン)"
    PARTNER="Developer (右ペイン)"
else
    ROLE="Developer (右ペイン)"
    PARTNER="QualityManager (左ペイン)"
fi

echo ""
echo "🎭 あなたの役割: $ROLE"
echo "🤝 通信相手: $PARTNER"

echo ""
echo "💬 メッセージ送信方法:"
echo "  ./scripts/msg.sh \"[メッセージ]\"  # パートナーへ簡単送信"
echo "  ./scripts/agent-send.sh human \"[メッセージ]\"  # 人間へ報告"

# ペイン一覧表示
echo ""
echo "📋 現在のペイン構成:"
tmux list-panes -F "#{pane_index}: #{pane_title} (#{pane_width}x#{pane_height})"