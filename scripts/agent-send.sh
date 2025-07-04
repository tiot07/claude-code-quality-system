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

# 現在のtmuxペインIDを取得
get_current_pane_id() {
    if [ -n "$TMUX_PANE" ]; then
        # tmux内から実行された場合、ペインIDを取得
        echo "$TMUX_PANE"
    else
        # tmux外から実行された場合は空文字を返す（共有ファイル使用）
        echo ""
    fi
}

# ウィンドウ名からプロジェクトIDを直接生成（ファイル不要）
get_project_id_from_window() {
    local current_window=$(get_current_window)
    
    if [ -z "$current_window" ]; then
        echo ""
        return 1
    fi
    
    # ウィンドウ名をベースにタイムスタンプ付きプロジェクトIDを生成
    echo "${current_window}_$(date +%Y%m%d_%H%M%S)"
}

# プロジェクトIDの取得（get-project-id.shを使用）
get_current_project_id() {
    # スクリプトディレクトリを取得
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # get-project-id.shスクリプトを実行
    if [ -f "$script_dir/get-project-id.sh" ]; then
        local project_id=$("$script_dir/get-project-id.sh" 2>/dev/null)
        if [ -n "$project_id" ]; then
            echo "$project_id"
            return 0
        fi
    fi
    
    # フォールバック: 現在のウィンドウ名を使用
    local current_window=$(get_current_window)
    if [ -z "$current_window" ]; then
        echo ""
        return 1
    fi
    
    # 既存プロジェクトディレクトリから検出を試行
    local existing_project=$(auto_detect_project_from_workspace "$current_window")
    if [ -n "$existing_project" ]; then
        echo "$existing_project"
        return 0
    fi
    
    echo ""
    return 1
}

# プロジェクトディレクトリの確保（ファイル管理なし）
ensure_project_directory() {
    local project_id="$1"
    
    if [ -z "$project_id" ]; then
        echo "❌ エラー: プロジェクトIDが指定されていません" >&2
        return 1
    fi
    
    mkdir -p workspace
    mkdir -p "workspace/$project_id"
    
    echo "✅ プロジェクトディレクトリ確保: $project_id" >&2
}

# 既存のプロジェクトディレクトリから自動検出（ウィンドウ名を考慮）
auto_detect_project_from_workspace() {
    local window_name="$1"
    
    if [ -d "workspace" ]; then
        # 指定されたウィンドウ名で始まるプロジェクトディレクトリを検索
        if [ -n "$window_name" ]; then
            local detected=$(find workspace -maxdepth 1 -type d -name "${window_name}_20*_*" | head -1)
            if [ -n "$detected" ]; then
                basename "$detected"
                return 0
            fi
            
            # ウィンドウ名完全一致でのプロジェクトディレクトリ検索
            local detected=$(find workspace -maxdepth 1 -type d -name "${window_name}" | head -1)
            if [ -n "$detected" ]; then
                basename "$detected"
                return 0
            fi
        fi
        
        # 既存の一意プロジェクトが1つだけの場合はそれを使用
        local existing_projects=$(find workspace -maxdepth 1 -type d -name "*_20*_*" | wc -l)
        if [ "$existing_projects" -eq 1 ]; then
            local detected=$(find workspace -maxdepth 1 -type d -name "*_20*_*" | head -1)
            if [ -n "$detected" ]; then
                basename "$detected"
                return 0
            fi
        fi
    fi
    
    echo ""
    return 1
}

# プロジェクト専用ウィンドウマッピング取得（シンプル化）
get_project_window_mapping() {
    # 現在のウィンドウをそのまま返す（ウィンドウ=プロジェクトの1:1対応）
    get_current_window
}

# エージェント→tmuxターゲット マッピング
get_agent_target() {
    local agent="$1"
    local window_name="$2"
    local project_id=$(get_current_project_id)
    
    # ウィンドウ名が指定されていない場合
    if [ -z "$window_name" ]; then
        # 現在のウィンドウを使用（シンプル化）
        window_name=$(get_current_window)
        if [ -z "$window_name" ]; then
            echo "❌ エラー: ウィンドウ名を取得できません。" >&2
            echo "使用例: ./scripts/agent-send.sh $agent \"メッセージ\" project-1" >&2
            echo "利用可能ウィンドウ:" >&2
            if tmux has-session -t claude-qa-system 2>/dev/null; then
                tmux list-windows -t claude-qa-system -F "  #{window_name}" >&2
            fi
            return 1
        fi
    fi
    
    # プロジェクトディレクトリの確保
    if [ -n "$project_id" ]; then
        ensure_project_directory "$project_id"
    fi
    
    # 特別処理: エージェント名が省略された場合は同一ウィンドウの相手ペインを自動選択
    if [ "$agent" = "auto" ] || [ -z "$agent" ]; then
        agent=$(get_target_agent)
        if [ -z "$agent" ]; then
            echo "❌ エラー: 相手エージェントを自動検出できません。明示的に指定してください。" >&2
            return 1
        fi
        echo "🤖 自動検出: 相手エージェント '$agent' を選択しました" >&2
    fi
    
    # 現在と同じウィンドウに送信するように修正
    # 同一ウィンドウ内での送信の場合、現在のペインから相手ペインを算出
    if [ -n "$TMUX_PANE" ] && [ "$window_name" = "$(get_current_window)" ]; then
        local current_pane_index=$(tmux display-message -p '#P')
        
        case "$agent" in
            "quality-manager")
                # 左ペイン（0）に送信
                echo "claude-qa-system:${window_name}.0"
                ;;
            "developer")
                # 右ペイン（1）に送信
                echo "claude-qa-system:${window_name}.1"
                ;;
            "human")
                echo "human"  # 特別ターゲット（人間への出力）
                ;;
            *)
                echo "" 
                ;;
        esac
    else
        # 別ウィンドウへの送信の場合は従来通り
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
    fi
}

show_usage() {
    cat << EOF
🎯 Quality Assurance System エージェント間メッセージ送信

使用方法:
  $0 [エージェント名] [メッセージ] [ウィンドウ名(オプション)]
  $0 auto [メッセージ]              # 相手ペインに自動送信
  $0 --safe-send [エージェント名] [メッセージ]  # 完全混信防止モード ⭐NEW
  $0 --set-project [プロジェクトID]  # 現在ペインのプロジェクトID設定 ⭐NEW
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
  --set-project   現在ペインのプロジェクトID設定 ⭐NEW

使用例:
  $0 --set-project "game_corp_site_20250629_182527"     # 現在ペインのプロジェクト設定 ⭐NEW
  $0 auto "実装完了しました"                            # 同一ウィンドウの相手に自動送信 ⭐NEW
  $0 quality-manager "要件分析を開始してください"        # 現在のウィンドウのmgrに送信
  $0 developer "実装タスクです: ログイン機能を作成"      # 現在のウィンドウのdevに送信
  $0 quality-manager "ECサイト要件" project-1           # 指定ウィンドウのmgrに送信
  $0 developer "API実装完了報告" project-2              # 指定ウィンドウのdevに送信
  $0 human "プロジェクトが完了しました"                  # 人間への出力
  $0 --broadcast "システム更新のお知らせ"                # 全エージェントに送信

同時作業モード:
  各tmuxペインで個別のプロジェクトIDを設定可能 ⭐NEW
  project-1.0 (mgr) ← todo_app_project
  project-1.1 (dev) ← todo_app_project  
  project-2.0 (mgr) ← game_site_project
  project-2.1 (dev) ← game_site_project

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
    
    # 現在の状況（シンプル化）
    local current_window=$(get_current_window)
    local current_pane=$(get_current_pane_id)
    local project_id=$(get_current_project_id)
    
    echo "📁 現在のウィンドウ: $current_window"
    echo "🖥️  現在のペイン: $current_pane"
    if [ -n "$project_id" ]; then
        echo "📝 プロジェクトID: $project_id"
        if [ -d "workspace/$project_id" ]; then
            echo "📂 作業ディレクトリ: workspace/$project_id ✅"
        else
            echo "📂 作業ディレクトリ: workspace/$project_id ❌ (未作成)"
        fi
    else
        echo "📝 プロジェクトID: なし"
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

# ログ記録（ウィンドウ別に分離・ファイルロック付き）
log_send() {
    local agent="$1"
    local message="$2"
    local current_window=$(get_current_window)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p logs
    
    # ファイルロックを使用した安全な書き込み
    write_log_safely() {
        local log_file="$1"
        local log_content="$2"
        
        if command -v flock &> /dev/null; then
            # flockが利用可能な場合（Linux）
            (
                flock -x 200
                echo "$log_content" >> "$log_file"
            ) 200>"${log_file}.lock"
        else
            # flockが利用できない場合（macOS等）
            # 簡易的なロック機構
            local lock_file="${log_file}.lock"
            local max_wait=5
            local waited=0
            
            # ロック取得を試みる
            while [ -f "$lock_file" ] && [ $waited -lt $max_wait ]; do
                sleep 0.1
                waited=$((waited + 1))
            done
            
            # ロック作成
            echo $$ > "$lock_file"
            echo "$log_content" >> "$log_file"
            rm -f "$lock_file"
        fi
    }
    
    # ウィンドウ別ログファイル
    if [ -n "$current_window" ]; then
        write_log_safely "logs/send_log_${current_window}.txt" "[$timestamp] $agent: SENT - \"$message\""
    fi
    
    # 統合ログファイル（全ウィンドウ共通）
    write_log_safely "logs/send_log_all.txt" "[$timestamp] [$current_window] $agent: SENT - \"$message\""
    
    # システム統計更新（アトミックな操作）
    mkdir -p tmp
    echo "$timestamp" > "tmp/last_message_time.$$.tmp"
    mv -f "tmp/last_message_time.$$.tmp" "tmp/last_message_time.txt"
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

# メッセージ送信（プロジェクトID検証ヘッダー付き・排他制御）
send_message() {
    local target="$1"
    local message="$2"
    local current_window=$(get_current_window)
    local project_id=$(get_current_project_id)
    
    # tmuxペインのロックファイル（ターゲット別）
    local pane_lock="tmp/tmux_pane_$(echo "$target" | tr ':.' '_').lock"
    mkdir -p tmp
    
    # 排他制御：同じペインへの同時送信を防ぐ
    acquire_tmux_lock() {
        local lock_file="$1"
        local max_wait=10  # 最大10秒待機
        local waited=0
        
        while [ -f "$lock_file" ]; do
            # 古いロックファイルをチェック（10秒以上前なら削除）
            if [ -f "$lock_file" ]; then
                local current_time=$(date +%s)
                local lock_time
                
                # macOS vs Linux の stat コマンドの違いに対応
                if stat -f%m "$lock_file" &>/dev/null; then
                    # macOS
                    lock_time=$(stat -f%m "$lock_file" 2>/dev/null || echo 0)
                elif stat -c%Y "$lock_file" &>/dev/null; then
                    # Linux
                    lock_time=$(stat -c%Y "$lock_file" 2>/dev/null || echo 0)
                else
                    # statが利用できない場合のフォールバック
                    lock_time=0
                fi
                
                local lock_age=$((current_time - lock_time))
                if [ $lock_age -gt 10 ]; then
                    echo "⚠️  古いロックファイルを削除: $lock_file" >&2
                    rm -f "$lock_file"
                    break
                fi
            fi
            
            if [ $waited -ge $max_wait ]; then
                echo "❌ タイムアウト: tmuxペインのロック取得に失敗"
                return 1
            fi
            
            echo "⏳ 他のプロセスの送信完了を待機中... ($waited秒)" >&2
            sleep 1
            waited=$((waited + 1))
        done
        
        # ロック取得
        echo $$ > "$lock_file"
        return 0
    }
    
    # ロック取得を試みる
    if ! acquire_tmux_lock "$pane_lock"; then
        echo "❌ メッセージ送信をキャンセルしました"
        return 1
    fi
    
    # プロジェクトID検証ヘッダーとガードレール機能を付加
    local enhanced_message=""
    if [ -n "$project_id" ]; then
        enhanced_message="🔒 PROJECT_VERIFY:${project_id}:${current_window} 🔒

【重要】このメッセージを受信した場合は以下を確認してください：
1. 受信したプロジェクトID: ${project_id}
2. あなたの現在のプロジェクトID: tmuxウィンドウから自動検出されます
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
    
    # エラーハンドリングを強化したtmux送信
    {
        # Claude Codeのプロンプトを一度クリア
        tmux send-keys -t "$target" C-c 2>/dev/null || {
            echo "❌ エラー: tmuxペインにアクセスできません: $target"
            rm -f "$pane_lock"
            return 1
        }
        sleep 0.3
        
        # 検証ヘッダー付きメッセージ送信
        tmux send-keys -t "$target" "$enhanced_message" 2>/dev/null || {
            echo "❌ エラー: メッセージ送信に失敗しました"
            rm -f "$pane_lock"
            return 1
        }
        sleep 0.1
        
        # エンター押下
        tmux send-keys -t "$target" C-m 2>/dev/null || {
            echo "❌ エラー: エンター送信に失敗しました"
            rm -f "$pane_lock"
            return 1
        }
        sleep 0.5
    }
    
    # ロック解放
    rm -f "$pane_lock"
    
    return 0
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
    
    # --set-projectオプション（廃止予定 - 警告のみ）
    if [[ "$1" == "--set-project" ]]; then
        echo "⚠️  --set-project オプションは廃止されました"
        echo "プロジェクトIDはウィンドウ名から自動生成されます"
        echo ""
        echo "現在のウィンドウ: $(get_current_window)"
        echo "自動生成されるプロジェクトID: $(get_current_project_id)"
        echo ""
        echo "プロジェクトディレクトリを作成したい場合:"
        echo "  mkdir -p workspace/\$(get_current_project_id)"
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
            echo "プロジェクトIDはウィンドウ名から自動検出されます"
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