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

# 新しいプロジェクト追加機能（命名規則統一）
create_new_project_window() {
    local project_num=$1
    local custom_name=$2
    
    # プロジェクト名の決定ロジック
    local project_name
    if [ -n "$custom_name" ]; then
        # カスタム名が指定された場合はそれをウィンドウ名に使用
        project_name="${custom_name}"
        log_info "📁 新しいプロジェクトウィンドウ作成: ${project_name}..."
    else
        # カスタム名がない場合は project-N 形式
        project_name="project-${project_num}"
        log_info "📁 新しいプロジェクトウィンドウ作成: ${project_name}..."
    fi
    
    # 新しいウィンドウを作成（カスタム名または project-N 形式）
    tmux new-window -t claude-qa-system -n "${project_name}"
    
    # 左右に分割（QualityManager | Developer）
    tmux split-window -h -t claude-qa-system:${project_name}
    
    # 左ペイン（QualityManager）設定
    tmux send-keys -t claude-qa-system:${project_name}.0 "cd $(pwd)" C-m
    tmux send-keys -t claude-qa-system:${project_name}.0 "export PS1='(QualityManager) \w\$ '" C-m
    tmux send-keys -t claude-qa-system:${project_name}.0 "clear" C-m
    # Claude起動（自動初期化なし）
    tmux send-keys -t claude-qa-system:${project_name}.0 "claude --dangerously-skip-permissions" C-m
    sleep 1
    # 初期化メッセージは手動で送信されるまで待機
    
    # 右ペイン（Developer）設定
    tmux send-keys -t claude-qa-system:${project_name}.1 "cd $(pwd)" C-m
    tmux send-keys -t claude-qa-system:${project_name}.1 "export PS1='(Developer) \w\$ '" C-m
    tmux send-keys -t claude-qa-system:${project_name}.1 "clear" C-m
    # Claude起動（自動初期化なし）
    sleep 2
    tmux send-keys -t claude-qa-system:${project_name}.1 "claude --dangerously-skip-permissions" C-m
    sleep 1
    # 初期化メッセージは手動で送信されるまで待機
    
    # プロジェクトID設定（新規ウィンドウ用）
    local window_session="claude-qa-system:${project_name}"
    local new_project_id="${project_name}_$(date +%Y%m%d_%H%M%S)"
    tmux set-environment -t "$window_session" PROJECT_ID "$new_project_id"
    
    # プロジェクトディレクトリ作成
    mkdir -p "workspace/$new_project_id"
    
    # デフォルトではQualityManagerペインを選択
    tmux select-pane -t claude-qa-system:${project_name}.0
    
    log_success "✅ プロジェクトウィンドウ作成完了: ${project_name} (ID: $new_project_id)"
}

echo "🎯 Claude Code 品質保証システム 環境構築"
echo "=========================================="
echo ""

# STEP 0: 引数チェック（最優先）
if [ "$1" = "--add-project" ] && [ -n "$2" ]; then
    # 新しいプロジェクト追加のみ実行
    log_info "📁 新しいプロジェクト追加モード: $3"
    
    # セッション存在確認
    if ! tmux has-session -t claude-qa-system 2>/dev/null; then
        echo "❌ エラー: claude-qa-systemセッションが存在しません"
        echo "まず基本セットアップを実行してください: ./scripts/setup.sh"
        exit 1
    fi
    
    create_new_project_window "$2" "$3"
    exit 0
fi

# STEP 1: 既存セッションクリーンアップ（新規作成時のみ）
log_info "🧹 既存セッション クリーンアップ開始..."

tmux kill-session -t claude-qa-system 2>/dev/null && log_info "claude-qa-systemセッション削除完了" || log_info "claude-qa-systemセッションは存在しませんでした"

# 作業ファイルクリア
mkdir -p ./tmp
rm -f ./tmp/*.txt 2>/dev/null && log_info "既存の作業ファイルをクリア" || log_info "作業ファイルは存在しませんでした"

# ログディレクトリ準備
mkdir -p ./logs
mkdir -p ./quality-reports

log_success "✅ クリーンアップ完了"
echo ""

# STEP 2: メインセッション作成（プロジェクト1）
log_info "🎯 メインセッション作成開始（プロジェクト1）..."

# メインセッション作成 - ウィンドウ名を統一（project-1形式）
tmux new-session -d -s claude-qa-system -n "project-1"

# 左右に分割（QualityManager | Developer）
tmux split-window -h -t claude-qa-system:project-1

# 左ペイン（QualityManager）設定
tmux send-keys -t claude-qa-system:project-1.0 "cd $(pwd)" C-m
tmux send-keys -t claude-qa-system:project-1.0 "export PS1='(QualityManager) \w\$ '" C-m
tmux send-keys -t claude-qa-system:project-1.0 "clear" C-m
# Claude起動（自動初期化なし）
tmux send-keys -t claude-qa-system:project-1.0 "claude --dangerously-skip-permissions" C-m
sleep 1
# 初期化メッセージは手動で送信されるまで待機

# 右ペイン（Developer）設定
tmux send-keys -t claude-qa-system:project-1.1 "cd $(pwd)" C-m
tmux send-keys -t claude-qa-system:project-1.1 "export PS1='(Developer) \w\$ '" C-m
tmux send-keys -t claude-qa-system:project-1.1 "clear" C-m
# Claude起動（自動初期化なし）
sleep 2
tmux send-keys -t claude-qa-system:project-1.1 "claude --dangerously-skip-permissions" C-m
sleep 1
# 初期化メッセージは手動で送信されるまで待機

# デフォルトではQualityManagerペインを選択
tmux select-pane -t claude-qa-system:project-1.0

log_success "✅ メインセッション作成完了（project-1）"
echo ""

# STEP 3: この部分は既に上部で処理済み（重複削除）

# STEP 4: 初期化ファイル作成
log_info "📋 初期化ファイル作成中..."

# プロジェクトID設定（tmux環境変数ベース）
WINDOW_NAME=$(tmux display-message -p '#W')
WINDOW_SESSION=$(tmux display-message -p '#S:#I')
PROJECT_ID="${WINDOW_NAME}_$(date +%Y%m%d_%H%M%S)"

# tmux環境変数に設定（ウィンドウ別・競合なし）
tmux set-environment -t "$WINDOW_SESSION" PROJECT_ID "$PROJECT_ID"

# プロジェクトディレクトリ作成
mkdir -p "workspace/$PROJECT_ID"

log_info "プロジェクトID設定: $PROJECT_ID (ウィンドウ: $WINDOW_NAME)"

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
echo "📺 Tmux Session:"
tmux list-sessions | grep claude-qa-system
echo ""
echo "📺 Tmux Windows:"
tmux list-windows -t claude-qa-system
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
echo "  claude-qa-system セッション:"
echo "    ┌─────────────────┬─────────────────┐"
echo "    │ QualityManager  │ Developer       │"
echo "    │ (左ペイン)      │ (右ペイン)      │"
echo "    │ 品質管理責任者  │ エンジニア      │"
echo "    └─────────────────┴─────────────────┘"
echo ""
echo "  操作方法:"
echo "    Ctrl+B → O     : ペイン切り替え"
echo "    Ctrl+B → N     : 次のウィンドウ"
echo "    Ctrl+B → P     : 前のウィンドウ"
echo "    Ctrl+B → 数字  : 指定ウィンドウへ移動"
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
echo "  1. 🔗 セッション接続:"
echo "     tmux attach-session -t claude-qa-system"
echo ""
echo "  2. 🤖 エージェント初期化（重要）"
echo "     Claude Code起動後、各ペインで以下を実行してください："
echo "     ./scripts/init-agents.sh"
echo ""
echo "  3. 📁 追加プロジェクト作成:"
echo "     ./scripts/setup.sh --add-project 2 webapp       # ウィンドウ名: webapp"
echo "     ./scripts/setup.sh --add-project 3 api-service  # ウィンドウ名: api-service"
echo "     ./scripts/setup.sh --add-project 4              # ウィンドウ名: project-4"
echo ""
echo "  3. 📜 指示書確認:"
echo "     QualityManager: agents/quality-manager.md"
echo "     Developer: agents/developer.md"
echo "     システム構造: CLAUDE.md（作成予定）"
echo ""
echo "  4. 🚀 システム開始:"
echo "     エージェント初期化完了後、以下でプロジェクトを開始："
echo "     - QualityManagerペイン: 要件を直接入力"
echo "     - または ./scripts/msg.sh \"[要件]\" で相手ペインに送信"
echo ""
echo "  5. 📊 状態確認:"
echo "     ./scripts/system-status.sh  # システム状態確認（作成予定）"
echo ""

echo "💡 使用方法:"
echo "==========="
echo "1. 各ペインでエージェント初期化: ./scripts/init-agents.sh"
echo "2. QualityManagerに要件を伝える"
echo "3. Manager-Developer間で直接通信: ./scripts/msg.sh \"[メッセージ]\""
echo "4. Developerが実装完了報告"
echo "5. QualityManagerが品質チェック実行"
echo "6. 合格なら完了、不合格なら修正指示"
echo ""
echo "🤝 新機能: 直接通信"
echo "  - 位置確認: ./scripts/where-am-i.sh"
echo "  - 簡単送信: ./scripts/msg.sh \"[メッセージ]\""
echo "  - 詳細送信: ./scripts/send-to-partner.sh \"[メッセージ]\""
echo ""

echo "🔧 トラブルシューティング:"
echo "======================"
echo "- セッション確認: tmux ls"
echo "- ウィンドウ確認: tmux list-windows -t claude-qa-system"  
echo "- ペイン確認: tmux list-panes -t claude-qa-system"
echo "- ログ確認: tail -f logs/send_log.txt"
echo "- リセット: ./scripts/setup.sh（再実行）"
echo ""
echo "🚀 tmux操作ガイド:"
echo "=================="
echo "- セッション接続: tmux attach -t claude-qa-system"
echo "- ペイン切り替え: Ctrl+B → O"
echo "- ウィンドウ切り替え: Ctrl+B → N (次) / P (前)"
echo "- ウィンドウ番号移動: Ctrl+B → 0,1,2..."
echo "- セッション終了: Ctrl+B → D (デタッチ)"
echo ""

echo "🎯 品質保証システムの準備が完了しました！"