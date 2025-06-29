#!/bin/bash

# 🤖 エージェント初期化スクリプト
# Claude起動後の役割設定を手動で実行

if [ -z "$TMUX" ]; then
    echo "❌ tmuxセッション内で実行してください"
    exit 1
fi

# 現在のペイン番号取得
CURRENT_PANE=$(tmux display-message -p '#P')

# 初期化対象の決定
if [ "$CURRENT_PANE" = "0" ]; then
    # QualityManager初期化
    ROLE="quality-manager"
    MESSAGE="あなたはquality-managerです。agents/quality-manager.mdの指示書に従って要件を受け付けてください。Developerとの通信は \`./scripts/msg.sh \"[メッセージ]\"\` で右ペインに直接送信できます。"
else
    # Developer初期化
    ROLE="developer"
    MESSAGE="あなたはdeveloperです。agents/developer.mdの指示書に従って実装作業を行ってください。QualityManagerとの通信は \`./scripts/msg.sh \"[メッセージ]\"\` で左ペインに直接送信できます。"
fi

echo "🤖 ${ROLE}エージェントを初期化中..."

# 確実な初期化送信
# 1. プロンプトクリア
tmux send-keys C-u
sleep 0.3

# 2. メッセージを段階的に送信
echo "$MESSAGE" | while IFS= read -r line || [ -n "$line" ]; do
    tmux send-keys "$line"
    sleep 0.1
done

# 3. Enter送信
tmux send-keys C-m

# ログ記録
echo "[$(date '+%Y-%m-%d %H:%M:%S')] init-agents.sh: ${ROLE}エージェント初期化完了" >> logs/agent_init.log

echo "✅ ${ROLE}エージェント初期化完了"
echo "   役割: $ROLE"
echo "   ペイン: $CURRENT_PANE"