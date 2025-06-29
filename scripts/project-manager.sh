#!/bin/bash

# プロジェクト管理スクリプト
# 複数プロジェクトの並行実行を適切に管理

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# プロジェクトマッピングファイル
MAPPING_FILE="tmp/project_window_mapping.json"

# 利用可能なウィンドウ
AVAILABLE_WINDOWS=("project-1" "project-2")

# プロジェクト一覧表示
list_projects() {
    echo -e "${BLUE}=== アクティブなプロジェクト ===${NC}"
    echo ""
    
    if [ ! -f "$MAPPING_FILE" ]; then
        echo -e "${YELLOW}マッピングファイルが見つかりません${NC}"
        return 1
    fi
    
    jq -r '.mappings | to_entries[] | "\(.key): \(.value.project_id) - \(.value.description) [\(.value.status)]"' "$MAPPING_FILE" 2>/dev/null || {
        echo -e "${RED}マッピングファイルの読み込みに失敗しました${NC}"
        return 1
    }
    
    echo ""
    echo -e "${BLUE}=== ワークスペース内のプロジェクト ===${NC}"
    if [ -d "workspace" ]; then
        for dir in workspace/*/; do
            if [ -d "$dir" ] && [ "$dir" != "workspace//" ]; then
                project_name=$(basename "$dir")
                if [[ ! "$project_name" =~ current_project_id ]]; then
                    echo "  - $project_name"
                fi
            fi
        done
    fi
}

# プロジェクトをウィンドウに割り当て
assign_project() {
    local project_id="$1"
    local window_name="$2"
    local description="$3"
    
    if [ -z "$project_id" ] || [ -z "$window_name" ]; then
        echo -e "${RED}エラー: プロジェクトIDとウィンドウ名が必要です${NC}"
        return 1
    fi
    
    # マッピングファイルが存在しない場合は作成
    if [ ! -f "$MAPPING_FILE" ]; then
        mkdir -p tmp
        echo '{"mappings": {}, "updated_at": "", "version": "2.0"}' > "$MAPPING_FILE"
    fi
    
    # 既存のマッピングを読み込み
    local temp_file=$(mktemp)
    
    # プロジェクトを追加/更新
    jq --arg window "$window_name" \
       --arg project "$project_id" \
       --arg desc "${description:-プロジェクト}" \
       --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.mappings[$window] = {
           "project_id": $project,
           "description": $desc,
           "quality_manager": "pane_0",
           "developer": "pane_1",
           "status": "active"
       } | .updated_at = $time' "$MAPPING_FILE" > "$temp_file"
    
    mv "$temp_file" "$MAPPING_FILE"
    
    # プロジェクトIDはウィンドウ名から自動生成されるため、ファイル作成は不要
    # echo "$project_id" > "workspace/current_project_id_${window_name}.txt"  # 廃止
    
    echo -e "${GREEN}✅ プロジェクト割り当て完了${NC}"
    echo "  プロジェクト: $project_id"
    echo "  ウィンドウ: $window_name"
    echo "  説明: ${description:-プロジェクト}"
}

# プロジェクトの削除
remove_project() {
    local window_name="$1"
    
    if [ -z "$window_name" ]; then
        echo -e "${RED}エラー: ウィンドウ名が必要です${NC}"
        return 1
    fi
    
    if [ ! -f "$MAPPING_FILE" ]; then
        echo -e "${YELLOW}マッピングファイルが見つかりません${NC}"
        return 1
    fi
    
    # プロジェクトIDを取得
    local project_id=$(jq -r ".mappings.\"$window_name\".project_id // empty" "$MAPPING_FILE")
    
    if [ -z "$project_id" ]; then
        echo -e "${YELLOW}ウィンドウ $window_name にプロジェクトが割り当てられていません${NC}"
        return 1
    fi
    
    # マッピングから削除
    local temp_file=$(mktemp)
    jq --arg window "$window_name" \
       --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       'del(.mappings[$window]) | .updated_at = $time' "$MAPPING_FILE" > "$temp_file"
    
    mv "$temp_file" "$MAPPING_FILE"
    
    # プロジェクトIDファイルの削除は不要（ファイルベース管理を廃止）
    # rm -f "workspace/current_project_id_${window_name}.txt"  # 廃止
    
    echo -e "${GREEN}✅ プロジェクト削除完了${NC}"
    echo "  削除されたプロジェクト: $project_id"
    echo "  ウィンドウ: $window_name"
}

# プロジェクトの状態確認
check_project() {
    local window_name="$1"
    
    if [ -z "$window_name" ]; then
        echo -e "${RED}エラー: ウィンドウ名が必要です${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== プロジェクト状態確認: $window_name ===${NC}"
    echo ""
    
    # マッピング情報
    if [ -f "$MAPPING_FILE" ]; then
        local project_info=$(jq -r ".mappings.\"$window_name\" // empty" "$MAPPING_FILE")
        if [ -n "$project_info" ] && [ "$project_info" != "null" ]; then
            echo "マッピング情報:"
            echo "$project_info" | jq .
        else
            echo -e "${YELLOW}マッピング情報なし${NC}"
        fi
    fi
    
    # プロジェクトID取得（ウィンドウ名ベース）
    source scripts/agent-send.sh
    local auto_project_id=$(get_current_project_id)
    if [ -n "$auto_project_id" ]; then
        echo ""
        echo "自動生成プロジェクトID: $auto_project_id"
        echo "（ウィンドウ名ベース自動管理）"
    else
        echo -e "${YELLOW}プロジェクトID自動生成なし${NC}"
    fi
    
    # ワークスペースディレクトリ
    if [ -n "$project_info" ] && [ "$project_info" != "null" ]; then
        local project_id=$(echo "$project_info" | jq -r '.project_id')
        if [ -d "workspace/$project_id" ]; then
            echo ""
            echo "ワークスペース: workspace/$project_id"
            echo "ファイル数: $(find "workspace/$project_id" -type f | wc -l)"
        fi
    fi
}

# 空いているウィンドウを探す
find_free_window() {
    for window in "${AVAILABLE_WINDOWS[@]}"; do
        if [ ! -f "$MAPPING_FILE" ]; then
            echo "$window"
            return 0
        fi
        
        local assigned=$(jq -r ".mappings.\"$window\" // empty" "$MAPPING_FILE")
        if [ -z "$assigned" ] || [ "$assigned" = "null" ]; then
            echo "$window"
            return 0
        fi
    done
    
    echo ""
    return 1
}

# 使用方法表示
show_usage() {
    cat << EOF
${BLUE}プロジェクト管理ツール${NC}

使用方法:
  $0 list                                    # プロジェクト一覧表示
  $0 assign <project_id> <window> [説明]     # プロジェクトをウィンドウに割り当て
  $0 remove <window>                         # プロジェクトを削除
  $0 check <window>                          # プロジェクトの状態確認
  $0 auto-assign <project_id> [説明]         # 空いているウィンドウに自動割り当て
  $0 cleanup                                 # 不要なファイルをクリーンアップ

例:
  $0 list
  $0 assign game-site-001 project-1 "ゲーム会社サイト"
  $0 auto-assign voice-todo-002 "音声TODOアプリ"
  $0 check project-1
  $0 remove project-2
  $0 cleanup

利用可能なウィンドウ:
  - project-1
  - project-2
EOF
}

# クリーンアップ
cleanup() {
    echo -e "${BLUE}=== クリーンアップ実行 ===${NC}"
    echo ""
    
    # 既存の孤立したプロジェクトIDファイルをクリーンアップ
    for id_file in workspace/current_project_id*.txt; do
        if [ -f "$id_file" ]; then
            echo "削除: $id_file (ファイルベース管理を廃止)"
            rm -f "$id_file"
        fi
    done
    
    # 空のプロジェクトディレクトリを検出
    if [ -d "workspace" ]; then
        for dir in workspace/*/; do
            if [ -d "$dir" ] && [ "$dir" != "workspace//" ]; then
                project_name=$(basename "$dir")
                if [[ ! "$project_name" =~ current_project_id ]]; then
                    # ディレクトリが空かチェック
                    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
                        echo "削除: $dir (空のディレクトリ)"
                        rmdir "$dir"
                    fi
                fi
            fi
        done
    fi
    
    echo ""
    echo -e "${GREEN}✅ クリーンアップ完了${NC}"
}

# メイン処理
case "$1" in
    "list")
        list_projects
        ;;
    "assign")
        assign_project "$2" "$3" "$4"
        ;;
    "remove")
        remove_project "$2"
        ;;
    "check")
        check_project "$2"
        ;;
    "auto-assign")
        free_window=$(find_free_window)
        if [ -n "$free_window" ]; then
            assign_project "$2" "$free_window" "$3"
        else
            echo -e "${RED}エラー: 空いているウィンドウがありません${NC}"
            exit 1
        fi
        ;;
    "cleanup")
        cleanup
        ;;
    *)
        show_usage
        exit 1
        ;;
esac