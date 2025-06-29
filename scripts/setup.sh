#!/bin/bash

# 🎯 Claude Code 品質保証システム 環境構築
# 品質管理者（QualityManager）と開発者（Developer）の2エージェント構成

set -e  # エラー時に停止

# 色付きログ関数
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;34m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

echo "🎯 Claude Code 品質保証システム 環境構築"
echo "=========================================="
echo ""

# STEP 1: 既存セッションクリーンアップ
log_info "🧹 既存セッション クリーンアップ開始..."

tmux kill-session -t quality-manager 2>/dev/null && log_info "quality-managerセッション削除完了" || log_info "quality-managerセッションは存在しませんでした"
tmux kill-session -t developer 2>/dev/null && log_info "developerセッション削除完了" || log_info "developerセッションは存在しませんでした"

# 作業ファイルクリア
mkdir -p ./tmp
rm -f ./tmp/*.txt 2>/dev/null && log_info "既存の作業ファイルをクリア" || log_info "作業ファイルは存在しませんでした"

# ログディレクトリ準備
mkdir -p ./logs
mkdir -p ./quality-reports

log_success "✅ クリーンアップ完了"
echo ""

# STEP 2: QualityManagerセッション作成
log_info "🎯 QualityManagerセッション作成開始..."

# QualityManagerセッション作成
tmux new-session -d -s quality-manager -n "quality-mgr"

# 作業ディレクトリ設定
tmux send-keys -t quality-manager "cd $(pwd)" C-m

# カラープロンプト設定（緑色）
tmux send-keys -t quality-manager "export PS1='(\[\033[1;32m\]QualityManager\[\033[0m\]) \[\033[1;36m\]\w\[\033[0m\]\$ '" C-m

# ウェルカムメッセージ
tmux send-keys -t quality-manager "echo '=== QualityManager エージェント ==='" C-m
tmux send-keys -t quality-manager "echo '品質管理責任者'" C-m
tmux send-keys -t quality-manager "echo '- 要件分析と品質チェックを担当'" C-m
tmux send-keys -t quality-manager "echo '- 実装結果の品質保証を実施'" C-m
tmux send-keys -t quality-manager "echo '============================'" C-m
tmux send-keys -t quality-manager "echo ''" C-m

log_success "✅ QualityManagerセッション作成完了"
echo ""

# STEP 3: Developerセッション作成
log_info "👨‍💻 Developerセッション作成開始..."

# Developerセッション作成
tmux new-session -d -s developer -n "developer"

# 作業ディレクトリ設定
tmux send-keys -t developer "cd $(pwd)" C-m

# カラープロンプト設定（青色）
tmux send-keys -t developer "export PS1='(\[\033[1;34m\]Developer\[\033[0m\]) \[\033[1;36m\]\w\[\033[0m\]\$ '" C-m

# ウェルカムメッセージ
tmux send-keys -t developer "echo '=== Developer エージェント ==='" C-m
tmux send-keys -t developer "echo 'エンジニア'" C-m
tmux send-keys -t developer "echo '- 高品質な実装を担当'" C-m
tmux send-keys -t developer "echo '- テスト駆動開発を実践'" C-m
tmux send-keys -t developer "echo '========================='" C-m
tmux send-keys -t developer "echo ''" C-m

log_success "✅ Developerセッション作成完了"
echo ""

# STEP 4: 初期化ファイル作成
log_info "📋 初期化ファイル作成中..."

# プロジェクトIDファイル作成
PROJECT_ID="qas_$(date +%Y%m%d_%H%M%S)"
echo "$PROJECT_ID" > workspace/current_project_id.txt

# 品質基準設定ファイル作成
cat > tmp/quality_standards.json << EOF
{
  "functional_requirements": {
    "minimum_pass_rate": 100
  },
  "quality_requirements": {
    "minimum_pass_rate": 80,
    "performance_threshold_ms": 1000,
    "memory_limit_mb": 512
  },
  "technical_requirements": {
    "minimum_pass_rate": 90,
    "test_coverage_minimum": 80
  },
  "test_requirements": {
    "minimum_pass_rate": 85,
    "security_scan_required": true
  }
}
EOF

# 状態管理ファイル初期化
echo "0" > tmp/revision_count.txt
echo "idle" > tmp/quality_manager_status.txt
echo "idle" > tmp/developer_status.txt

log_success "✅ 初期化ファイル作成完了"
echo ""

# STEP 5: 権限設定
log_info "🔐 スクリプト権限設定中..."

# スクリプトファイルに実行権限付与
chmod +x scripts/agent-send.sh 2>/dev/null || log_warning "agent-send.sh が見つかりません（後で作成予定）"
chmod +x scripts/quality-check.sh 2>/dev/null || log_warning "quality-check.sh が見つかりません（後で作成予定）"
chmod +x scripts/feedback-loop.sh 2>/dev/null || log_warning "feedback-loop.sh が見つかりません（後で作成予定）"

log_success "✅ 権限設定完了"
echo ""

# STEP 6: 環境確認・表示
log_info "🔍 環境確認中..."

echo ""
echo "📊 セットアップ結果:"
echo "==================="

# tmuxセッション確認
echo "📺 Tmux Sessions:"
tmux list-sessions | grep -E "(quality-manager|developer)"
echo ""

# ディレクトリ構成表示
echo "📁 ディレクトリ構成:"
echo "  claude-code-quality-system/"
echo "  ├── agents/              # エージェント指示書"
echo "  │   ├── quality-manager.md"
echo "  │   └── developer.md"
echo "  ├── scripts/             # 自動化スクリプト"
echo "  ├── templates/           # テンプレート"
echo "  ├── workspace/           # プロジェクト作業領域"
echo "  ├── quality-reports/     # 品質レポート保存"
echo "  ├── logs/               # ログファイル"
echo "  └── tmp/                # 一時ファイル"
echo ""

# エージェント構成表示
echo "🤖 エージェント構成:"
echo "  quality-manager セッション:"
echo "    - 品質管理責任者"
echo "    - 要件分析と品質チェック担当"
echo ""
echo "  developer セッション:"
echo "    - エンジニア"
echo "    - 実装とテスト担当"
echo ""

echo "📋 プロジェクト設定:"
echo "  - プロジェクトID: $PROJECT_ID"
echo "  - 作業ディレクトリ: workspace/$PROJECT_ID"
echo "  - 品質基準: tmp/quality_standards.json"

echo ""
log_success "🎉 品質保証システム セットアップ完了！"
echo ""

echo "📋 次のステップ:"
echo "================"
echo ""
echo "  1. 🔗 セッション確認:"
echo "     tmux attach-session -t quality-manager  # 品質管理者画面"
echo "     tmux attach-session -t developer        # 開発者画面"
echo ""
echo "  2. 🤖 Claude Code起動:"
echo "     # QualityManager起動"
echo "     tmux send-keys -t quality-manager 'claude --dangerously-skip-permissions' C-m"
echo "     # Developer起動"  
echo "     tmux send-keys -t developer 'claude --dangerously-skip-permissions' C-m"
echo ""
echo "  3. 📜 指示書確認:"
echo "     QualityManager: agents/quality-manager.md"
echo "     Developer: agents/developer.md"
echo "     システム構造: CLAUDE.md（作成予定）"
echo ""
echo "  4. 🚀 システム開始:"
echo "     QualityManagerに以下のメッセージを送信:"
echo "     「あなたはquality-managerです。指示書に従って要件を受け付けてください。」"
echo ""
echo "  5. 📊 状態確認:"
echo "     ./scripts/system-status.sh  # システム状態確認（作成予定）"
echo ""

echo "💡 使用方法:"
echo "==========="
echo "1. QualityManagerに要件を伝える"
echo "2. QualityManagerがDeveloperに実装指示"
echo "3. Developerが実装完了報告"
echo "4. QualityManagerが品質チェック実行"
echo "5. 合格なら完了、不合格なら修正指示"
echo ""

echo "🔧 トラブルシューティング:"
echo "======================"
echo "- セッション確認: tmux ls"
echo "- ログ確認: tail -f logs/send_log.txt"
echo "- リセット: ./scripts/setup.sh（再実行）"
echo ""

echo "🎯 品質保証システムの準備が完了しました！"