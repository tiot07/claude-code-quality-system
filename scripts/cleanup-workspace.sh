#!/bin/bash

# ワークスペース重複プロジェクト整理スクリプト

echo "🧹 ワークスペースの重複プロジェクト整理を開始します..."

# 1. 現在のプロジェクト状況を表示
echo ""
echo "📁 現在のワークスペース状況:"
if [ -d "workspace" ]; then
    find workspace -maxdepth 1 -type d -not -name "workspace" | while read dir; do
        if [ -n "$dir" ]; then
            project_name=$(basename "$dir")
            echo "  - $project_name"
            
            # requirements.jsonの有無を確認
            if [ -f "$dir/requirements.json" ]; then
                echo "    ✅ requirements.json 存在"
            else
                echo "    ❌ requirements.json なし"
            fi
        fi
    done
else
    echo "  workspace ディレクトリが存在しません"
    exit 1
fi

echo ""
echo "🔍 重複プロジェクトの検出と統合..."

# 2. プロジェクトパターンの分析
declare -A project_groups
while IFS= read -r dir; do
    if [ -n "$dir" ] && [ -d "$dir" ]; then
        project_name=$(basename "$dir")
        
        # パターン1: window_YYYYMMDD_HHMMSS
        if [[ "$project_name" =~ ^([^_]+)_[0-9]{8}_[0-9]{6} ]]; then
            window_base="${BASH_REMATCH[1]}"
            project_groups["$window_base"]+="$project_name "
        # パターン2: project-name-数字
        elif [[ "$project_name" =~ ^(project-[0-9]+) ]]; then
            window_base="${BASH_REMATCH[1]}"
            project_groups["$window_base"]+="$project_name "
        # パターン3: その他
        else
            project_groups["other"]+="$project_name "
        fi
    fi
done < <(find workspace -maxdepth 1 -type d -not -name "workspace")

# 3. 重複の解決提案
echo ""
echo "📋 重複解決の提案:"
for group in "${!project_groups[@]}"; do
    projects=(${project_groups[$group]})
    if [ ${#projects[@]} -gt 1 ]; then
        echo ""
        echo "  グループ: $group"
        echo "  重複プロジェクト:"
        
        latest_project=""
        latest_timestamp=0
        
        for project in "${projects[@]}"; do
            echo "    - $project"
            
            # タイムスタンプを抽出して最新を判定
            if [[ "$project" =~ _([0-9]{8}_[0-9]{6}) ]]; then
                timestamp="${BASH_REMATCH[1]}"
                timestamp_num=$(echo "$timestamp" | tr -d '_')
                if [ "$timestamp_num" -gt "$latest_timestamp" ]; then
                    latest_timestamp="$timestamp_num"
                    latest_project="$project"
                fi
            elif [ -z "$latest_project" ]; then
                latest_project="$project"
            fi
        done
        
        echo "  🎯 推奨保持: $latest_project"
        
        # 統合実行の確認
        echo ""
        read -p "  このグループの重複を解決しますか? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy] ]]; then
            echo "  🔄 統合処理を実行中..."
            
            # 最新プロジェクトにデータを統合
            for project in "${projects[@]}"; do
                if [ "$project" != "$latest_project" ]; then
                    echo "    📤 $project のデータを $latest_project に統合中..."
                    
                    # requirements.jsonを統合
                    if [ -f "workspace/$project/requirements.json" ] && [ -f "workspace/$latest_project/requirements.json" ]; then
                        # より詳細な方を保持
                        old_size=$(stat -f%z "workspace/$latest_project/requirements.json" 2>/dev/null || echo "0")
                        new_size=$(stat -f%z "workspace/$project/requirements.json" 2>/dev/null || echo "0")
                        
                        if [ "$new_size" -gt "$old_size" ]; then
                            cp "workspace/$project/requirements.json" "workspace/$latest_project/requirements.json"
                            echo "      ✅ requirements.json を更新"
                        fi
                    elif [ -f "workspace/$project/requirements.json" ]; then
                        cp "workspace/$project/requirements.json" "workspace/$latest_project/requirements.json"
                        echo "      ✅ requirements.json をコピー"
                    fi
                    
                    # その他のファイルをコピー
                    if [ -d "workspace/$project" ]; then
                        rsync -av --exclude="requirements.json" "workspace/$project/" "workspace/$latest_project/"
                        echo "      ✅ その他のファイルを統合"
                    fi
                    
                    # 古いディレクトリを削除
                    rm -rf "workspace/$project"
                    echo "      🗑️  $project を削除"
                fi
            done
            
            echo "  ✅ 統合完了: $latest_project"
        else
            echo "  ⏭️  スキップ"
        fi
    fi
done

# 4. 最終状況表示
echo ""
echo "📁 整理後のワークスペース:"
if [ -d "workspace" ]; then
    find workspace -maxdepth 1 -type d -not -name "workspace" | while read dir; do
        if [ -n "$dir" ]; then
            project_name=$(basename "$dir")
            echo "  - $project_name"
        fi
    done
fi

echo ""
echo "✅ ワークスペース整理完了"
echo ""
echo "💡 推奨事項:"
echo "  1. 今後は tmux ウィンドウ名でプロジェクトを管理してください"
echo "  2. ./scripts/get-project-id.sh でプロジェクトIDを確認できます"
echo "  3. ./scripts/agent-send.sh --set-project [ID] でプロジェクトIDを設定できます"