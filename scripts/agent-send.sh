#!/bin/bash

# 🚀 Quality Assurance System エージェント間メッセージ送信スクリプト
# QualityManager ↔ Developer 間の通信を管理

# 現在のウィンドウを自動検出
get_current_window() {
    # tmux環境変数から現在のウィンドウを取得
    if [ -n "$TMUX_PANE" ]; then
        local current_window=$(tmux display-message -p '#W')
        echo "$current_window"
    else
        # tmux外から実行された場合はアクティブウィンドウを使用
        if tmux has-session -t claude-qa-system 2>/dev/null; then
            local active_window=$(tmux list-windows -t claude-qa-system -F "#{?window_active,#{window_name},}" | grep -v '^$')
            echo "$active_window"
        else
            echo ""
        fi
    fi
}

# エージェント→tmuxターゲット マッピング
get_agent_target() {
    local agent="$1"
    local window_name="$2"
    
    # ウィンドウ名が指定されていない場合は現在のウィンドウを自動検出
    if [ -z "$window_name" ]; then
        window_name=$(get_current_window)
        if [ -z "$window_name" ]; then
            echo "❌ エラー: 現在のウィンドウを検出できません。ウィンドウ名を指定してください。"
            echo "使用例: ./scripts/agent-send.sh $agent \"メッセージ\" webapp"
            echo "利用可能ウィンドウ:"
            if tmux has-session -t claude-qa-system 2>/dev/null; then
                tmux list-windows -t claude-qa-system -F "  #{window_name}"
            fi
            return 1
        fi
    fi
    
    case "$agent" in
        "quality-manager") echo "claude-qa-system:${window_name}.0" ;;  # 左ペイン
        "developer") echo "claude-qa-system:${window_name}.1" ;;        # 右ペイン
        "human") echo "human" ;;  # 特別ターゲット（人間への出力）
        *) echo "" ;;
    esac
}

show_usage() {
    cat << EOF
🎯 Quality Assurance System エージェント間メッセージ送信

使用方法:
  $0 [エージェント名] [メッセージ] [ウィンドウ名(オプション)]
  $0 --list
  $0 --status

利用可能エージェント:
  quality-manager - 品質管理責任者（左ペイン）
  developer       - エンジニア（右ペイン）
  human          - 人間（ユーザー）への出力

特別コマンド:
  --list          エージェント一覧表示
  --status        システム状態確認
  --broadcast     全エージェントに一括送信

使用例:
  $0 quality-manager "要件分析を開始してください"        # 現在のウィンドウに送信
  $0 developer "実装タスクです: ログイン機能を作成"      # 現在のウィンドウに送信
  $0 quality-manager "ECサイト要件" webapp              # 指定ウィンドウに送信
  $0 developer "API実装完了報告" api-service            # 指定ウィンドウに送信
  $0 human "プロジェクトが完了しました"                  # 人間への出力
  $0 --broadcast "システム更新のお知らせ"                # 全エージェントに送信

品質保証フロー:
  human → quality-manager → developer → quality-manager → human
EOF
}

# エージェント一覧表示
show_agents() {
    echo "📋 利用可能なエージェント:"
    echo "=========================="
    echo "  quality-manager → claude-qa-system:[window].0  (品質管理責任者・左ペイン)"
    echo "  developer       → claude-qa-system:[window].1  (エンジニア・右ペイン)"
    echo "  human          → console output               (人間への出力)"
    echo ""
    echo "🪟 利用可能なウィンドウ:"
    if tmux has-session -t claude-qa-system 2>/dev/null; then
        tmux list-windows -t claude-qa-system -F "  #{window_name} (#{window_index})"
    else
        echo "  セッションが見つかりません"
    fi
    echo ""
    echo "🔄 品質保証フロー:"
    echo "  1. human → quality-manager (要件提示)"
    echo "  2. quality-manager → developer (実装指示)"  
    echo "  3. developer → quality-manager (完了報告)"
    echo "  4. quality-manager → human (品質確認結果)"
}

# システム状態確認
show_status() {
    echo "📊 Quality Assurance System 状態"
    echo "================================"
    echo ""
    
    # tmuxセッション確認
    echo "🖥️  tmuxセッション:"
    if tmux has-session -t claude-qa-system 2>/dev/null; then
        echo "  ✅ claude-qa-system: 起動中"
        echo "     ウィンドウ一覧:"
        tmux list-windows -t claude-qa-system -F "       #{window_index}: #{window_name} (#{window_panes} panes)"
    else
        echo "  ❌ claude-qa-system: 停止中"
        echo "     ./scripts/setup.sh を実行してセッションを作成してください"
    fi
    echo ""
    
    # 現在のプロジェクト
    if [ -f workspace/current_project_id.txt ]; then
        PROJECT_ID=$(cat workspace/current_project_id.txt)
        echo "📁 現在のプロジェクト: $PROJECT_ID"
    else
        echo "📁 現在のプロジェクト: なし"
    fi
    echo ""
    
    # エージェント状態
    echo "🤖 エージェント状態:"
    if [ -f tmp/quality_manager_status.txt ]; then
        QM_STATUS=$(cat tmp/quality_manager_status.txt)
        echo "  品質管理者: $QM_STATUS"
    else
        echo "  品質管理者: 不明"
    fi
    
    if [ -f tmp/developer_status.txt ]; then
        DEV_STATUS=$(cat tmp/developer_status.txt)
        echo "  開発者: $DEV_STATUS"
    else
        echo "  開発者: 不明"
    fi
    echo ""
    
    # 最近のログ
    echo "📝 最近のメッセージ (直近5件):"
    if [ -f logs/send_log.txt ]; then
        tail -5 logs/send_log.txt
    else
        echo "  ログファイルなし"
    fi
}

# ログ記録
log_send() {
    local agent="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p logs
    echo "[$timestamp] $agent: SENT - \"$message\"" >> logs/send_log.txt
    
    # システム統計更新
    echo $timestamp > tmp/last_message_time.txt
}

# 人間への出力（特別処理）
send_to_human() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo ""
    echo "=================================================="
    echo "📢 Quality Assurance System からのメッセージ"
    echo "時刻: $timestamp"
    echo "=================================================="
    echo ""
    echo "$message"
    echo ""
    echo "=================================================="
    echo ""
    
    # 人間向けログ記録
    mkdir -p logs
    echo "[$timestamp] SYSTEM → HUMAN: $message" >> logs/human_notifications.txt
}

# 全エージェントに一括送信
broadcast_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "📢 全エージェントに一括送信中: '$message'"
    
    # 全ウィンドウのQuality Managerに送信
    if tmux has-session -t claude-qa-system 2>/dev/null; then
        local windows=$(tmux list-windows -t claude-qa-system -F "#{window_name}")
        while IFS= read -r window; do
            if [ -n "$window" ]; then
                local qm_target=$(get_agent_target "quality-manager" "$window")
                send_message "$qm_target" "$message"
                echo "  ✅ quality-manager ($window) に送信完了"
            fi
        done <<< "$windows"
    else
        echo "  ❌ claude-qa-system セッションが見つかりません"
    fi
    
    # 全ウィンドウのDeveloperに送信
    if tmux has-session -t claude-qa-system 2>/dev/null; then
        local windows=$(tmux list-windows -t claude-qa-system -F "#{window_name}")
        while IFS= read -r window; do
            if [ -n "$window" ]; then
                local dev_target=$(get_agent_target "developer" "$window")
                send_message "$dev_target" "$message"
                echo "  ✅ developer ($window) に送信完了"
            fi
        done <<< "$windows"
    else
        echo "  ❌ claude-qa-system セッションが見つかりません"
    fi
    
    # 人間にも通知
    send_to_human "システム一括送信: $message"
    
    # ブロードキャストログ記録
    echo "[$timestamp] BROADCAST: $message" >> logs/broadcast_log.txt
}

# メッセージ送信
send_message() {
    local target="$1"
    local message="$2"
    
    echo "📤 送信中: $target ← '$message'"
    
    # Claude Codeのプロンプトを一度クリア
    tmux send-keys -t "$target" C-c
    sleep 0.3
    
    # メッセージ送信
    tmux send-keys -t "$target" "$message"
    sleep 0.1
    
    # エンター押下
    tmux send-keys -t "$target" C-m
    sleep 0.5
}

# ターゲット存在確認
check_target() {
    local target="$1"
    local session_name="${target%%:*}"
    
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "❌ セッション '$session_name' が見つかりません"
        echo "   ./scripts/setup.sh を実行してセッションを作成してください"
        return 1
    fi
    
    return 0
}

# エージェント状態更新
update_agent_status() {
    local agent="$1"
    local status="active"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$agent" in
        "quality-manager")
            echo "$status" > tmp/quality_manager_status.txt
            echo "$timestamp" > tmp/quality_manager_last_active.txt
            ;;
        "developer") 
            echo "$status" > tmp/developer_status.txt
            echo "$timestamp" > tmp/developer_last_active.txt
            ;;
    esac
}

# メイン処理
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    # --listオプション
    if [[ "$1" == "--list" ]]; then
        show_agents
        exit 0
    fi
    
    # --statusオプション
    if [[ "$1" == "--status" ]]; then
        show_status
        exit 0
    fi
    
    # --broadcastオプション
    if [[ "$1" == "--broadcast" ]]; then
        if [[ $# -lt 2 ]]; then
            echo "❌ エラー: ブロードキャストメッセージが指定されていません"
            echo "使用例: $0 --broadcast 'システム更新のお知らせ'"
            exit 1
        fi
        broadcast_message "$2"
        exit 0
    fi
    
    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi
    
    local agent_name="$1"
    local message="$2"
    local window_name="$3"  # オプション: 指定されたウィンドウのみ
    
    # 人間への出力（特別処理）
    if [[ "$agent_name" == "human" ]]; then
        send_to_human "$message"
        log_send "$agent_name" "$message"
        exit 0
    fi
    
    # エージェントターゲット取得
    local target
    target=$(get_agent_target "$agent_name" "$window_name")
    local get_target_result=$?
    
    if [[ $get_target_result -ne 0 ]] || [[ -z "$target" ]]; then
        if [[ $get_target_result -ne 0 ]]; then
            # get_agent_target内でエラーメッセージが既に表示されている
            exit 1
        else
            echo "❌ エラー: 不明なエージェント '$agent_name'"
            echo ""
            echo "利用可能エージェント:"
            echo "  quality-manager - 品質管理責任者（左ペイン）"
            echo "  developer       - エンジニア（右ペイン）"
            echo "  human          - 人間への出力"
            echo ""
            echo "一覧表示: $0 --list"
            exit 1
        fi
    fi
    
    # ターゲット確認
    if ! check_target "$target"; then
        exit 1
    fi
    
    # メッセージ送信
    send_message "$target" "$message"
    
    # ログ記録
    log_send "$agent_name" "$message"
    
    # エージェント状態更新
    update_agent_status "$agent_name"
    
    # 実際に使用されたウィンドウ名を取得
    local actual_window=$(echo "$target" | cut -d':' -f2 | cut -d'.' -f1)
    echo "✅ 送信完了: $agent_name ($actual_window) に '$message'"
    
    # 品質保証フロー情報
    case "$agent_name" in
        "quality-manager")
            echo "💡 次のステップ: quality-manager が要件分析または品質チェックを実行します"
            ;;
        "developer")
            echo "💡 次のステップ: developer が実装作業を開始します"
            ;;
    esac
    
    return 0
}

main "$@"