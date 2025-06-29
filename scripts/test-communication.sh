#!/bin/bash

# 🧪 通信テストスクリプト
# Claude間の通信が正常に動作するかテスト

if [ -z "$TMUX" ]; then
    echo "❌ tmuxセッション内で実行してください"
    exit 1
fi

echo "🧪 Claude Code通信テスト開始"
echo "================================"

# 現在のペイン番号取得
CURRENT_PANE=$(tmux display-message -p '#P')
if [ "$CURRENT_PANE" = "0" ]; then
    TARGET_PANE="1"
    CURRENT_ROLE="QualityManager"
    TARGET_ROLE="Developer"
else
    TARGET_PANE="0"
    CURRENT_ROLE="Developer"
    TARGET_ROLE="QualityManager"
fi

echo "📍 現在の位置: ペイン$CURRENT_PANE ($CURRENT_ROLE)"
echo "📤 送信先: ペイン$TARGET_PANE ($TARGET_ROLE)"
echo ""

# テストメッセージ送信
TEST_MESSAGE="🧪 通信テスト: $(date '+%H:%M:%S') - $CURRENT_ROLE から $TARGET_ROLE への接続確認"

echo "📨 テストメッセージ送信中..."
echo "   内容: $TEST_MESSAGE"

# msg.shを使用してテスト送信
./scripts/msg.sh "$TEST_MESSAGE"

echo ""
echo "✅ 通信テスト完了"
echo ""
echo "📋 確認事項:"
echo "1. 相手ペインにメッセージが表示されているか確認してください"
echo "2. Claudeがメッセージを受信・認識したか確認してください"
echo "3. 返答が返ってくるか確認してください"
echo ""
echo "🔧 問題がある場合:"
echo "- ./scripts/init-agents.sh でエージェント再初期化"
echo "- tail -f logs/direct_message.log でログ確認"