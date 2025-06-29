#!/bin/bash

# 🎯 プロジェクトID取得（ウィンドウ別・競合なし）
# tmux環境変数ベースでプロジェクトIDを管理

get_project_id() {
    if [ -z "$TMUX" ]; then
        echo "❌ tmuxセッション内で実行してください" >&2
        exit 1
    fi
    
    local window_session=$(tmux display-message -p '#S:#I')
    local window_name=$(tmux display-message -p '#W')
    
    # 既存の環境変数をチェック
    local existing_id=$(tmux show-environment -t "$window_session" PROJECT_ID 2>/dev/null | cut -d= -f2)
    
    if [ -n "$existing_id" ] && [ "$existing_id" != "PROJECT_ID" ]; then
        echo "$existing_id"
        return 0
    fi
    
    # 新規プロジェクトIDを生成
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local project_id="${window_name}_${timestamp}"
    
    # tmux環境変数に保存（ウィンドウ別）
    tmux set-environment -t "$window_session" PROJECT_ID "$project_id"
    
    # プロジェクトディレクトリ作成
    mkdir -p "workspace/$project_id"
    
    echo "$project_id"
}

# 直接実行された場合
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    get_project_id
fi