#!/bin/bash

# 通信システム修正スクリプト

echo "🔧 通信システムの修正を開始します..."

# 1. プロジェクトIDの一元管理
get_project_id_for_window() {
    local window_name="$1"
    
    # マッピングファイルから取得
    if [ -f "tmp/project_window_mapping.json" ]; then
        project_id=$(jq -r ".mappings.\"$window_name\".project_id // empty" tmp/project_window_mapping.json)
        if [ -n "$project_id" ]; then
            echo "$project_id"
            return 0
        fi
    fi
    
    # ウィンドウ別IDファイルから取得
    if [ -f "workspace/current_project_id_${window_name}.txt" ]; then
        cat "workspace/current_project_id_${window_name}.txt"
        return 0
    fi
    
    echo ""
    return 1
}

# 2. 通信検証の強化
verify_project_match() {
    local expected_project="$1"
    local received_project="$2"
    
    if [ "$expected_project" != "$received_project" ]; then
        echo "❌ プロジェクトID不一致: 期待=$expected_project, 受信=$received_project"
        return 1
    fi
    
    return 0
}

# 3. ウィンドウ名の正規化
normalize_window_names() {
    echo "📝 ウィンドウ名を正規化中..."
    
    # project-2-M を project-2 に戻す
    if tmux list-windows | grep -q "project-2-M"; then
        tmux rename-window -t claude-qa-system:project-2-M project-2
        echo "✅ project-2-M → project-2 に修正"
    fi
    
    # zsh を project-2 に統合するか確認
    echo "⚠️  zshウィンドウはproject-2の作業を引き継いでいます"
}

# 4. 状態の可視化
show_system_status() {
    echo ""
    echo "=== 現在のシステム状態 ==="
    echo ""
    echo "📁 アクティブなプロジェクト:"
    echo "  project-1: $(get_project_id_for_window project-1)"
    echo "  project-2: $(get_project_id_for_window project-2)"
    echo "  zsh: $(get_project_id_for_window zsh)"
    echo ""
    echo "🪟 tmuxウィンドウ:"
    tmux list-windows -t claude-qa-system | grep -E "(project-|zsh)"
    echo ""
    echo "📂 workspaceフォルダ:"
    ls -la workspace/ | grep -E "^d" | grep -v "^\." | awk '{print "  - " $9}'
}

# 実行
echo "1️⃣ ウィンドウ名の正規化..."
normalize_window_names

echo ""
echo "2️⃣ システム状態の表示..."
show_system_status

echo ""
echo "✅ 修正完了"
echo ""
echo "📌 推奨事項:"
echo "  1. 各エージェントでプロジェクトIDを明示的に設定"
echo "  2. メッセージ受信時にプロジェクトIDを検証"
echo "  3. 定期的にこのスクリプトを実行して状態確認"