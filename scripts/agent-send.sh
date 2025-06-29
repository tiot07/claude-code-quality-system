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

# 現在のペインがmgrかdeveloperかを判定
get_current_agent_role() {
    if [ -n "$TMUX_PANE" ]; then
        local pane_index=$(tmux display-message -p '#P')
        case "$pane_index" in
            "0") echo "quality-manager" ;;
            "1") echo "developer" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

# 相手ペインのエージェントを取得
get_target_agent() {
    local current_role=$(get_current_agent_role)
    case "$current_role" in
        "quality-manager") echo "developer" ;;
        "developer") echo "quality-manager" ;;
        *) echo "" ;;
    esac
}

# プロジェクトIDの取得
get_current_project_id() {
    if [ -f workspace/current_project_id.txt ]; then
        cat workspace/current_project_id.txt | tr -d '\n\r'
    else
        echo ""
    fi
}

# プロジェクト専用ウィンドウマッピング取得
get_project_window_mapping() {
    local project_id=$(get_current_project_id)
    
    if [ -z "$project_id" ]; then
        echo ""
        return 1
    fi
    
    # プロジェクトIDに基づく専用ウィンドウマッピング
    # 規則: プロジェクトIDのハッシュ値で決定的にウィンドウを割り当て
    local hash_suffix=$(echo "$project_id" | tail -c 2)
    case "$hash_suffix" in
        "49"|"58"|*"9"|*"8") echo "project-1" ;;
        *) echo "project-2" ;;
    esac
}

# エージェント→tmuxターゲット マッピング
get_agent_target() {
    local agent="$1"
    local window_name="$2"
    local project_id=$(get_current_project_id)
    
    # ウィンドウ名が指定されていない場合
    if [ -z "$window_name" ]; then
        # プロジェクトIDがある場合は専用ウィンドウマッピングを使用
        if [ -n "$project_id" ]; then
            window_name=$(get_project_window_mapping)
            echo "🔒 プロジェクト分離: ${project_id} → ウィンドウ ${window_name}"
        else
            # プロジェクトIDがない場合は現在のウィンドウを使用
            window_name=$(get_current_window)
            if [ -z "$window_name" ]; then
                echo "❌ エラー: プロジェクトIDまたはウィンドウ名を指定してください。"
                echo "現在のプロジェクトID: $(get_current_project_id)"
                echo "使用例: ./scripts/agent-send.sh $agent \"メッセージ\" project-1"
                echo "利用可能ウィンドウ:"
                if tmux has-session -t claude-qa-system 2>/dev/null; then
                    tmux list-windows -t claude-qa-system -F "  #{window_name}"
                fi
                return 1
            fi
        fi
    fi
    
    # 🚨 プロジェクト混信完全防止: 強制的にプロジェクト専用ウィンドウを使用
    if [ -n "$project_id" ]; then
        local recommended_window=$(get_project_window_mapping)
        if [ "$window_name" != "$recommended_window" ]; then
            echo "🚨 プロジェクト混信防止: 自動修正実行"
            echo "   現在プロジェクト: $project_id"
            echo "   指定ウィンドウ: $window_name → $recommended_window (強制変更)"
            echo "   理由: プロジェクト間混信を根本的に防止"
            
            # 強制的に推奨ウィンドウに変更
            window_name="$recommended_window"
            
            # 修正ログを記録
            mkdir -p logs
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] AUTO_CORRECTION: Project $project_id redirected to $recommended_window" >> logs/auto_correction.log
        fi
    fi
    
    # 特別処理: エージェント名が省略された場合は同一ウィンドウの相手ペインを自動選択
    if [ "$agent" = "auto" ] || [ -z "$agent" ]; then
        agent=$(get_target_agent)
        if [ -z "$agent" ]; then
            echo "❌ エラー: 相手エージェントを自動検出できません。明示的に指定してください。"
            return 1
        fi
        echo "🤖 自動検出: 相手エージェント '$agent' を選択しました"
    fi
    
    # tmuxターゲット構築
    case "$agent" in
        "quality-manager") 
            # 左ペイン（QualityManager）
            echo "claude-qa-system:${window_name}.0"
            ;;
        "developer") 
            # 右ペイン（Developer）
            echo "claude-qa-system:${window_name}.1"
            ;;
        "human") 
            echo "human"  # 特別ターゲット（人間への出力）
            ;;
        *) 
            echo "" 
            ;;
    esac
}

show_usage() {
    cat << EOF
🎯 Quality Assurance System エージェント間メッセージ送信

使用方法:
  $0 [エージェント名] [メッセージ] [ウィンドウ名(オプション)]
  $0 auto [メッセージ]              # 相手ペインに自動送信
  $0 --safe-send [エージェント名] [メッセージ]  # 完全混信防止モード ⭐NEW
  $0 --list
  $0 --status

利用可能エージェント:
  quality-manager - 品質管理責任者（左ペイン）
  developer       - エンジニア（右ペイン）
  human          - 人間（ユーザー）への出力
  auto           - 相手ペインを自動検出

特別コマンド:
  --list          エージェント一覧表示
  --status        システム状態確認
  --broadcast     全エージェントに一括送信
  --check-cross   プロジェクト間混信チェック ⭐NEW
  --safe-send     完全混信防止モード（自動ウィンドウ修正） ⭐NEW

使用例:
  $0 auto "実装完了しました"                            # 同一ウィンドウの相手に自動送信 ⭐NEW
  $0 quality-manager "要件分析を開始してください"        # 現在のウィンドウのmgrに送信
  $0 developer "実装タスクです: ログイン機能を作成"      # 現在のウィンドウのdevに送信
  $0 quality-manager "ECサイト要件" project-1           # 指定ウィンドウのmgrに送信
  $0 developer "API実装完了報告" project-2              # 指定ウィンドウのdevに送信
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
    
    # 現在のプロジェクトとウィンドウ
    local current_window=$(get_current_window)
    local project_id=$(get_current_project_id)
    echo "📁 現在のウィンドウ: $current_window"
    if [ -n "$project_id" ]; then
        echo "📝 設定プロジェクトID: $project_id"
    else
        echo "📝 設定プロジェクトID: なし"
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
    
    # 最近のログ（ウィンドウ別表示）
    local current_window=$(get_current_window)
    echo "📝 最近のメッセージ (直近5件):"
    if [ -n "$current_window" ] && [ -f "logs/send_log_${current_window}.txt" ]; then
        echo "  現在のウィンドウ ($current_window):"
        tail -5 "logs/send_log_${current_window}.txt"
    elif [ -f logs/send_log_all.txt ]; then
        echo "  全ウィンドウ統合ログ:"
        tail -5 logs/send_log_all.txt
    else
        echo "  ログファイルなし"
    fi
}

# ログ記録（ウィンドウ別に分離）
log_send() {
    local agent="$1"
    local message="$2"
    local current_window=$(get_current_window)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p logs
    
    # ウィンドウ別ログファイル
    if [ -n "$current_window" ]; then
        echo "[$timestamp] $agent: SENT - \"$message\"" >> "logs/send_log_${current_window}.txt"
    fi
    
    # 統合ログファイル（全ウィンドウ共通）
    echo "[$timestamp] [$current_window] $agent: SENT - \"$message\"" >> logs/send_log_all.txt
    
    # システム統計更新
    echo $timestamp > tmp/last_message_time.txt
}

# 人間への出力（特別処理）
send_to_human() {
    local message="$1"
    local current_window=$(get_current_window)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo ""
    echo "=================================================="
    echo "📢 Quality Assurance System からのメッセージ"
    echo "ウィンドウ: $current_window"
    echo "時刻: $timestamp"
    echo "=================================================="
    echo ""
    echo "$message"
    echo ""
    echo "=================================================="
    echo ""
    
    # 人間向けログ記録（ウィンドウ別に分離）
    mkdir -p logs
    if [ -n "$current_window" ]; then
        echo "[$timestamp] SYSTEM → HUMAN: $message" >> "logs/human_notifications_${current_window}.txt"
    fi
    echo "[$timestamp] [$current_window] SYSTEM → HUMAN: $message" >> logs/human_notifications_all.txt
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
    
    # ブロードキャストログ記録（ウィンドウ別分離）
    local current_window=$(get_current_window)
    if [ -n "$current_window" ]; then
        echo "[$timestamp] BROADCAST: $message" >> "logs/broadcast_log_${current_window}.txt"
    fi
    echo "[$timestamp] [$current_window] BROADCAST: $message" >> logs/broadcast_log_all.txt
}

# メッセージ送信（プロジェクトID検証ヘッダー付き）
send_message() {
    local target="$1"
    local message="$2"
    local current_window=$(get_current_window)
    local project_id=$(get_current_project_id)
    
    # プロジェクトID検証ヘッダーとガードレール機能を付加
    local enhanced_message=""
    if [ -n "$project_id" ]; then
        enhanced_message="🔒 PROJECT_VERIFY:${project_id}:${current_window} 🔒

【重要】このメッセージを受信した場合は以下を確認してください：
1. 受信したプロジェクトID: ${project_id}
2. あなたの現在のプロジェクトID: workspace/current_project_id.txt を確認
3. 異なる場合は以下のエラーメッセージで応答してください：

\`\`\`
⚠️  プロジェクト混信を検出

受信したメッセージは別プロジェクト（${project_id}）からのものですが、現在私が管理中のプロジェクトは[あなたのプロジェクトID]です。

現在の状況
- 管理中プロジェクト: [あなたのプロジェクトID]  
- 受信メッセージ: ${project_id}

これは別セッション間の混信である可能性があります。

対応方針
現在のプロジェクトの進捗を継続監視し、該当するエージェントからの報告を待機いたします。
[あなたのプロジェクトID]の実装状況について、正しい進捗報告をお待ちしております。
\`\`\`

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**実際のメッセージ内容:**

$message

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        enhanced_message="$message"
    fi
    
    echo "📤 送信中: $target (プロジェクト: $project_id) ← メッセージ"
    
    # Claude Codeのプロンプトを一度クリア
    tmux send-keys -t "$target" C-c
    sleep 0.3
    
    # 検証ヘッダー付きメッセージ送信
    tmux send-keys -t "$target" "$enhanced_message"
    sleep 0.1
    
    # エンター押下
    tmux send-keys -t "$target" C-m
    sleep 0.5
}

# ターゲット存在確認（ウィンドウとペインの両方を検証）
check_target() {
    local target="$1"
    local session_name="${target%%:*}"
    local window_and_pane="${target##*:}"
    local window_name="${window_and_pane%%.*}"
    local pane_number="${window_and_pane##*.}"
    
    # セッション存在確認
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "❌ セッション '$session_name' が見つかりません"
        echo "   ./scripts/setup.sh を実行してセッションを作成してください"
        return 1
    fi
    
    # ウィンドウ存在確認
    if ! tmux list-windows -t "$session_name" -F "#{window_name}" | grep -q "^${window_name}$"; then
        echo "❌ ウィンドウ '$window_name' が見つかりません"
        echo "   利用可能ウィンドウ:"
        tmux list-windows -t "$session_name" -F "    #{window_name}"
        echo "   新しいプロジェクトを追加する場合:"
        echo "   ./scripts/setup.sh --add-project 2 $window_name"
        return 1
    fi
    
    # ペイン存在確認
    if ! tmux list-panes -t "${session_name}:${window_name}" -F "#{pane_index}" | grep -q "^${pane_number}$"; then
        echo "❌ ペイン '${pane_number}' が見つかりません（ウィンドウ: $window_name）"
        echo "   利用可能ペイン:"
        tmux list-panes -t "${session_name}:${window_name}" -F "    #{pane_index}: #{pane_title}"
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

# プロジェクト間混信チェック
check_cross_project_communication() {
    echo "🔍 プロジェクト間混信チェック実行中..."
    echo "========================================"
    
    local current_project=$(get_current_project_id)
    local current_window=$(get_current_window)
    local recommended_window=$(get_project_window_mapping)
    
    echo "📋 現在の設定:"
    echo "   プロジェクトID: $current_project"
    echo "   現在のウィンドウ: $current_window"
    echo "   推奨ウィンドウ: $recommended_window"
    echo ""
    
    # ログファイルから混信パターンを検出
    echo "📝 最近の通信ログ解析:"
    if [ -f logs/send_log_all.txt ]; then
        echo "   === 全ウィンドウ統合ログ (直近10件) ==="
        tail -10 logs/send_log_all.txt | while IFS= read -r line; do
            # プロジェクトID抽出
            project_in_log=$(echo "$line" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')
            if [ "$project_in_log" != "$current_project" ] && [ -n "$project_in_log" ]; then
                echo "   ⚠️  混信検出: $line"
            else
                echo "   ✅ 正常: $line"
            fi
        done
    else
        echo "   ログファイルが見つかりません"
    fi
    echo ""
    
    # 修正提案
    echo "🔧 混信防止推奨アクション:"
    if [ "$current_window" != "$recommended_window" ]; then
        echo "   1. 推奨ウィンドウ '$recommended_window' に移動"
        echo "   2. または明示的にウィンドウ指定: ./scripts/agent-send.sh agent \"msg\" $recommended_window"
    else
        echo "   ✅ 現在の設定は適切です"
    fi
    echo "   3. メッセージ送信時はプロジェクトID検証ヘッダーを確認"
    echo "   4. 受信時は送信元プロジェクトIDを検証"
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
    
    # --check-crossオプション
    if [[ "$1" == "--check-cross" ]]; then
        check_cross_project_communication
        exit 0
    fi
    
    # --safe-sendオプション（完全混信防止モード）
    if [[ "$1" == "--safe-send" ]]; then
        if [[ $# -lt 3 ]]; then
            echo "❌ エラー: --safe-send には エージェント名とメッセージが必要です"
            echo "使用例: $0 --safe-send developer \"実装完了しました\""
            exit 1
        fi
        
        local safe_agent="$2"
        local safe_message="$3"
        local project_id=$(get_current_project_id)
        
        echo "🛡️  完全混信防止モード: 実行中"
        echo "   プロジェクト: $project_id"
        echo "   送信先: $safe_agent"
        
        if [ -z "$project_id" ]; then
            echo "❌ エラー: プロジェクトIDが設定されていません"
            echo "workspace/current_project_id.txt を確認してください"
            exit 1
        fi
        
        # 強制的にプロジェクト専用ウィンドウを使用
        local safe_window=$(get_project_window_mapping)
        echo "   強制ウィンドウ: $safe_window (プロジェクト専用)"
        
        # 通常の送信処理を実行（ウィンドウは強制指定）
        agent_name="$safe_agent"
        message="$safe_message" 
        window_name="$safe_window"
        
        echo "🚨 混信防止: プロジェクト ${project_id} 専用ウィンドウ ${safe_window} に強制送信"
        
        # ここから通常のメイン処理と同じ流れ
    else
        # 通常モードでの引数処理
        if [[ $# -lt 2 ]]; then
            show_usage
            exit 1
        fi
        
        agent_name="$1"
        message="$2"
        window_name="$3"  # オプション
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
            echo "  auto           - 相手ペインを自動検出 ⭐"
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
    local current_window=$(get_current_window)
    echo "✅ 送信完了: $agent_name (ウィンドウ: $actual_window) に送信"
    
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