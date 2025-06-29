#!/bin/bash

# 🔄 Quality Assurance System フィードバックループ自動化スクリプト
# 品質チェック結果に基づいて適切なフィードバックを自動生成

set -e

# 色付きログ関数
log_info() {
    echo -e "\033[1;36m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# 使用方法表示
show_usage() {
    cat << EOF
🔄 Quality Assurance System フィードバックループ

使用方法:
  $0 [プロジェクトID]
  $0 --current        # 現在のプロジェクトを処理
  $0 --auto-run       # 品質チェック実行後に自動処理
  $0 --help           # ヘルプ表示

機能:
  1. 品質チェック結果の解析
  2. 合格時の完了処理とhuman通知
  3. 不合格時の修正指示生成とdeveloper通知
  4. 修正履歴の管理

処理フロー:
  品質チェック → 結果解析 → 合格判定
     ↓合格                    ↓不合格
  完了処理                   修正指示生成
     ↓                       ↓
  human通知              developer通知

例:
  $0 qas_20240101_120000
  $0 --current
  $0 --auto-run
EOF
}

# プロジェクトID取得（統一された方式）
get_project_id() {
    if [[ "$1" == "--current" ]] || [[ "$1" == "--auto-run" ]]; then
        ./scripts/get-project-id.sh
    else
        echo "$1"
    fi
}

# 品質チェック結果の読み込み
load_quality_report() {
    local project_id="$1"
    local report_file="quality-reports/${project_id}_report.json"
    
    if [[ ! -f "$report_file" ]]; then
        log_error "品質レポートが見つかりません: $report_file"
        echo "先に品質チェックを実行してください: ./scripts/quality-check.sh $project_id"
        return 1
    fi
    
    # JSON読み込み（jqが利用可能な場合）
    if command -v jq &> /dev/null; then
        export OVERALL_PASS=$(jq -r '.summary.overall_pass' "$report_file")
        export FUNC_SCORE=$(jq -r '.detailed_scores.functional_requirements' "$report_file")
        export PERF_SCORE=$(jq -r '.detailed_scores.performance' "$report_file")
        export SEC_SCORE=$(jq -r '.detailed_scores.security' "$report_file")
        export QUALITY_SCORE=$(jq -r '.detailed_scores.code_quality' "$report_file")
        export TEST_SCORE=$(jq -r '.detailed_scores.test_coverage' "$report_file")
        export DOC_SCORE=$(jq -r '.detailed_scores.documentation' "$report_file")
        export TOTAL_SCORE=$(jq -r '.summary.total_score' "$report_file")
        export AVERAGE_SCORE=$(jq -r '.summary.average_score' "$report_file")
    else
        # jqが無い場合の代替処理
        log_warning "jq未インストール - 簡易解析を使用"
        export OVERALL_PASS=$(grep '"overall_pass"' "$report_file" | grep -o 'true\|false')
        export TOTAL_SCORE=$(grep '"total_score"' "$report_file" | grep -o '[0-9]\+')
        export AVERAGE_SCORE=$(grep '"average_score"' "$report_file" | grep -o '[0-9]\+')
    fi
    
    log_info "品質レポート読み込み完了: $report_file"
    return 0
}

# 修正回数の管理
manage_revision_count() {
    local project_id="$1"
    local action="$2"  # increment または get
    local revision_file="workspace/${project_id}/revision_count.txt"
    
    mkdir -p "workspace/${project_id}"
    
    case "$action" in
        "increment")
            local current_count=$(cat "$revision_file" 2>/dev/null || echo "0")
            local new_count=$((current_count + 1))
            echo "$new_count" > "$revision_file"
            echo "$new_count"
            ;;
        "get")
            cat "$revision_file" 2>/dev/null || echo "0"
            ;;
        *)
            echo "0"
            ;;
    esac
}

# 修正履歴の記録
record_revision_history() {
    local project_id="$1"
    local revision_count="$2"
    local result="$3"  # success または failed
    local issues="$4"
    
    local history_file="quality-reports/${project_id}_history.log"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat >> "$history_file" << EOF
[$timestamp] Revision $revision_count - Result: $result
Total Score: $TOTAL_SCORE/600 (Average: $AVERAGE_SCORE/100)
Issues: $issues
---
EOF
    
    log_info "修正履歴記録: Revision $revision_count ($result)"
}

# 完了処理（合格時）
process_success() {
    local project_id="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local revision_count
    revision_count=$(manage_revision_count "$project_id" "get")
    
    log_success "品質チェック合格 - 完了処理開始"
    
    # 修正履歴記録
    record_revision_history "$project_id" "$revision_count" "success" "なし"
    
    # 完了メッセージ生成
    local completion_message
    completion_message=$(cat << EOF
【プロジェクト完了】✅

## プロジェクト概要
- プロジェクトID: $project_id
- 完了時刻: $timestamp
- 修正回数: $revision_count回
- 最終品質スコア: $TOTAL_SCORE/600 (平均: $AVERAGE_SCORE/100)

## 品質チェック結果
✅ 機能要件: $FUNC_SCORE/100 (目標: 100)
✅ パフォーマンス: $PERF_SCORE/100 (目標: 80以上)
✅ セキュリティ: $SEC_SCORE/100 (目標: 80以上)
✅ コード品質: $QUALITY_SCORE/100 (目標: 90以上)
✅ テストカバレッジ: $TEST_SCORE/100 (目標: 85以上)
✅ ドキュメント: $DOC_SCORE/100 (目標: 70以上)

## 成果物
- ソースコード: workspace/$project_id/
- 品質レポート: quality-reports/${project_id}_report.json
- 実行手順: workspace/$project_id/README.md

## プロジェクト統計
- 開発期間: [開始からの経過時間]
- 修正サイクル: $revision_count回
- 最終品質達成率: $AVERAGE_SCORE%

## 次のステップ
1. ステークホルダーへの報告
2. 本番環境へのデプロイ準備
3. 運用ドキュメントの確認
4. モニタリング設定の実施

要件を100%満たす高品質な成果物が完成しました。
EOF
    )
    
    # 人間への通知
    ./scripts/agent-send.sh human "$completion_message"
    
    # プロジェクト状態更新
    echo "completed" > "tmp/project_status_${project_id}.txt"
    echo "$timestamp" > "tmp/completion_time_${project_id}.txt"
    
    # 成功ログ記録
    echo "[$timestamp] PROJECT COMPLETED: $project_id (Revisions: $revision_count, Score: $TOTAL_SCORE/600)" >> logs/success_log.txt
    
    log_success "完了処理完了 - 人間への通知送信済み"
    return 0
}

# 修正指示生成（不合格時）
process_failure() {
    local project_id="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local revision_count
    revision_count=$(manage_revision_count "$project_id" "increment")
    
    log_warning "品質チェック不合格 - 修正指示生成開始"
    
    # 品質レポートから問題点を抽出
    local report_file="quality-reports/${project_id}_report.json"
    local critical_issues=()
    local important_issues=()
    local minor_issues=()
    
    # 各カテゴリの問題点を分析
    if [[ $FUNC_SCORE -lt 100 ]]; then
        critical_issues+=("機能要件未達成 (現状: ${FUNC_SCORE}/100, 目標: 100)")
    fi
    
    if [[ $PERF_SCORE -lt 80 ]]; then
        important_issues+=("パフォーマンス不足 (現状: ${PERF_SCORE}/100, 目標: 80以上)")
    fi
    
    if [[ $SEC_SCORE -lt 80 ]]; then
        important_issues+=("セキュリティ要件不足 (現状: ${SEC_SCORE}/100, 目標: 80以上)")
    fi
    
    if [[ $QUALITY_SCORE -lt 90 ]]; then
        important_issues+=("コード品質不足 (現状: ${QUALITY_SCORE}/100, 目標: 90以上)")
    fi
    
    if [[ $TEST_SCORE -lt 85 ]]; then
        important_issues+=("テストカバレッジ不足 (現状: ${TEST_SCORE}/100, 目標: 85以上)")
    fi
    
    if [[ $DOC_SCORE -lt 70 ]]; then
        minor_issues+=("ドキュメント不足 (現状: ${DOC_SCORE}/100, 目標: 70以上)")
    fi
    
    # 修正指示メッセージ生成
    local revision_message
    revision_message=$(cat << EOF
【修正指示】🔧 (修正回数: ${revision_count}回目)

## 品質チェック結果
❌ 総合評価: 不合格 (スコア: $TOTAL_SCORE/600, 平均: $AVERAGE_SCORE/100)

### 修正が必要な項目

$(if [[ ${#critical_issues[@]} -gt 0 ]]; then
    echo "#### 🚨 緊急修正 (必須 - プロジェクト成功の前提条件)"
    for issue in "${critical_issues[@]}"; do
        echo "- $issue"
    done
    echo ""
fi)

$(if [[ ${#important_issues[@]} -gt 0 ]]; then
    echo "#### ⚠️  重要修正 (必須 - 品質基準達成のため)"
    for issue in "${important_issues[@]}"; do
        echo "- $issue"
    done
    echo ""
fi)

$(if [[ ${#minor_issues[@]} -gt 0 ]]; then
    echo "#### 📝 軽微修正 (推奨 - 完成度向上のため)"
    for issue in "${minor_issues[@]}"; do
        echo "- $issue"
    done
    echo ""
fi)

## 具体的修正指示

### 1. 機能要件 ($FUNC_SCORE/100)
$(if [[ $FUNC_SCORE -lt 100 ]]; then
    echo "- 全機能の動作確認を実施"
    echo "- エラーハンドリングの実装確認"
    echo "- ユーザビリティの改善"
else
    echo "✅ 合格基準達成済み"
fi)

### 2. パフォーマンス ($PERF_SCORE/100)
$(if [[ $PERF_SCORE -lt 80 ]]; then
    echo "- 応答時間の最適化 (目標: <1000ms)"
    echo "- メモリ使用量の削減 (目標: <512MB)"
    echo "- データベースクエリの最適化"
else
    echo "✅ 合格基準達成済み"
fi)

### 3. セキュリティ ($SEC_SCORE/100)
$(if [[ $SEC_SCORE -lt 80 ]]; then
    echo "- 脆弱性の修正 (npm audit実行)"
    echo "- 入力値検証の強化"
    echo "- HTTPS設定の確認"
else
    echo "✅ 合格基準達成済み"
fi)

### 4. コード品質 ($QUALITY_SCORE/100)
$(if [[ $QUALITY_SCORE -lt 90 ]]; then
    echo "- ESLintエラーの修正"
    echo "- TypeScript型エラーの解決"
    echo "- コードレビューの実施"
else
    echo "✅ 合格基準達成済み"
fi)

### 5. テストカバレッジ ($TEST_SCORE/100)
$(if [[ $TEST_SCORE -lt 85 ]]; then
    echo "- テストケースの追加 (目標: 80%以上)"
    echo "- 失敗テストの修正"
    echo "- E2Eテストの実装"
else
    echo "✅ 合格基準達成済み"
fi)

## 修正期限
修正完了期限: $(date -d '+2 hours' '+%Y/%m/%d %H:%M')

## 修正完了時の報告フォーマット
修正完了時は以下フォーマットで報告してください：

---
【修正完了報告】

## 修正項目
- [修正した項目1]: [修正内容]
- [修正した項目2]: [修正内容]

## テスト結果
- 修正後テスト: [結果]
- 回帰テスト: [既存機能への影響なし]

## 品質改善
- 改善されたスコア: [予想スコア]
- 対策済み課題: [解決した問題]
---

$(if [[ $revision_count -ge 3 ]]; then
    echo ""
    echo "⚠️  注意: 修正回数が ${revision_count}回に達しています。"
    echo "根本的な問題の見直しが必要な可能性があります。"
    echo "必要に応じてアーキテクチャや要件の再検討を検討してください。"
fi)

修正後、再度品質チェックを実行します。
頑張ってください！🚀
EOF
    )
    
    # 問題点をまとめた文字列を作成（履歴記録用）
    local issues_summary
    issues_summary=$(printf "%s; " "${critical_issues[@]}" "${important_issues[@]}" "${minor_issues[@]}" | sed 's/; $//')
    
    # 修正履歴記録
    record_revision_history "$project_id" "$revision_count" "failed" "$issues_summary"
    
    # Developerへの修正指示送信
    ./scripts/agent-send.sh developer "$revision_message"
    
    # プロジェクト状態更新
    echo "revision_$revision_count" > "tmp/project_status_${project_id}.txt"
    echo "$timestamp" > "tmp/last_revision_time_${project_id}.txt"
    
    # エスカレーション判定
    if [[ $revision_count -ge 5 ]]; then
        escalate_to_human "$project_id" "$revision_count"
    fi
    
    log_warning "修正指示送信完了 - Developer修正作業開始"
    return 1
}

# エスカレーション処理
escalate_to_human() {
    local project_id="$1"
    local revision_count="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    log_error "エスカレーション発生 - 修正回数上限到達"
    
    local escalation_message
    escalation_message=$(cat << EOF
【エスカレーション】🚨

## 状況
プロジェクト「$project_id」で品質問題が継続しています。

- 修正回数: ${revision_count}回
- 現在のスコア: $TOTAL_SCORE/600 (平均: $AVERAGE_SCORE/100)
- 経過時間: [開始からの時間]

## 主要な課題
- 機能要件: $FUNC_SCORE/100 (目標: 100)
- パフォーマンス: $PERF_SCORE/100 (目標: 80+)
- セキュリティ: $SEC_SCORE/100 (目標: 80+)
- コード品質: $QUALITY_SCORE/100 (目標: 90+)
- テストカバレッジ: $TEST_SCORE/100 (目標: 85+)

## 推奨対策
1. **要件の見直し**: スコープの縮小や優先度の再整理
2. **技術選定の変更**: より適切な技術スタックの採用
3. **アーキテクチャの再設計**: 根本的な設計の見直し
4. **段階的リリース**: MVPでの先行リリース検討
5. **追加リソース**: 専門知識を持つメンバーの投入

## 次のアクション
対策の指示をお願いします。このまま修正を続けるか、
上記推奨対策のいずれかを実施するかの判断が必要です。

プロジェクトの方向性について指示をお願いします。
EOF
    )
    
    # 人間へのエスカレーション通知
    ./scripts/agent-send.sh human "$escalation_message"
    
    # エスカレーションログ記録
    echo "[$timestamp] ESCALATION: $project_id (Revisions: $revision_count, Score: $TOTAL_SCORE/600)" >> logs/escalation_log.txt
    
    log_error "エスカレーション通知送信完了"
}

# 自動実行モード（品質チェック後の自動フィードバック）
auto_run_mode() {
    local project_id="$1"
    
    log_info "自動実行モード - 品質チェック実行後の自動フィードバック"
    
    # 品質チェック実行
    log_info "品質チェック実行中..."
    if ./scripts/quality-check.sh "$project_id"; then
        log_success "品質チェック合格 - 完了処理実行"
        load_quality_report "$project_id"
        process_success "$project_id"
    else
        log_warning "品質チェック不合格 - 修正指示実行"
        load_quality_report "$project_id"
        process_failure "$project_id"
    fi
}

# メイン処理
main() {
    echo "🔄 Quality Assurance System フィードバックループ"
    echo "================================================"
    echo ""
    
    # 引数チェック
    if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # プロジェクトID取得
    local project_id
    project_id=$(get_project_id "$1")
    
    if [[ -z "$project_id" ]]; then
        log_error "プロジェクトIDが指定されていません"
        echo "現在のプロジェクト確認: $0 --current"
        echo "手動指定: $0 [プロジェクトID]"
        exit 1
    fi
    
    log_info "対象プロジェクト: $project_id"
    
    # 自動実行モードの処理
    if [[ "$1" == "--auto-run" ]]; then
        auto_run_mode "$project_id"
        exit $?
    fi
    
    # 品質レポート読み込み
    if ! load_quality_report "$project_id"; then
        exit 1
    fi
    
    echo ""
    log_info "品質チェック結果: 総合判定 = $OVERALL_PASS (スコア: $TOTAL_SCORE/600)"
    echo ""
    
    # 合格/不合格に応じた処理
    if [[ "$OVERALL_PASS" == "true" ]]; then
        process_success "$project_id"
        exit 0
    else
        process_failure "$project_id"
        exit 1
    fi
}

main "$@"