#!/bin/bash

# 🎯 Quality Assurance System 品質チェック自動実行スクリプト
# 実装結果を多角的に検証し、要件充足度を定量評価

set -e

# 色付きログ関数
log_info() {
    echo -e "\033[1;36m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[PASS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[FAIL]\033[0m $1"
}

# 使用方法表示
show_usage() {
    cat << EOF
🎯 Quality Assurance System 品質チェック

使用方法:
  $0 [プロジェクトID]
  $0 --current        # 現在のプロジェクトをチェック
  $0 --help           # ヘルプ表示

チェック項目:
  1. 機能要件チェック    - 全機能の動作確認
  2. パフォーマンステスト - 応答時間・負荷テスト
  3. セキュリティスキャン - 脆弱性検査
  4. コード品質チェック  - Lint・型チェック
  5. テストカバレッジ    - テスト充足度
  6. ドキュメント確認    - 必要書類の完備

出力:
  - quality-reports/[プロジェクトID]_report.json
  - quality-reports/[プロジェクトID]_summary.txt

例:
  $0 qas_20240101_120000
  $0 --current
EOF
}

# プロジェクトID取得
get_project_id() {
    if [[ "$1" == "--current" ]]; then
        if [[ -f workspace/current_project_id.txt ]]; then
            cat workspace/current_project_id.txt
        else
            echo ""
        fi
    else
        echo "$1"
    fi
}

# プロジェクトディレクトリ確認
check_project_dir() {
    local project_id="$1"
    local project_dir="workspace/$project_id"
    
    if [[ ! -d "$project_dir" ]]; then
        log_error "プロジェクトディレクトリが見つかりません: $project_dir"
        return 1
    fi
    
    return 0
}

# 品質基準読み込み
load_quality_standards() {
    local standards_file="tmp/quality_standards.json"
    
    if [[ ! -f "$standards_file" ]]; then
        log_warning "品質基準ファイルが見つかりません。デフォルト値を使用します。"
        
        # デフォルト品質基準作成
        cat > "$standards_file" << EOF
{
  "functional_requirements": {"minimum_pass_rate": 100},
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
    fi
    
    log_info "品質基準を読み込みました: $standards_file"
}

# 1. 機能要件チェック
check_functional_requirements() {
    local project_dir="$1"
    local report_file="$2"
    
    log_info "🔍 機能要件チェック実行中..."
    
    local start_time=$(date +%s)
    local passed_count=0
    local total_count=0
    local issues=()
    
    # 基本ファイル存在チェック
    local required_files=("package.json" "README.md")
    for file in "${required_files[@]}"; do
        total_count=$((total_count + 1))
        if [[ -f "$project_dir/$file" ]]; then
            passed_count=$((passed_count + 1))
            log_success "必須ファイル存在確認: $file"
        else
            log_error "必須ファイル不足: $file"
            issues+=("必須ファイル不足: $file")
        fi
    done
    
    # アプリケーション起動テスト
    total_count=$((total_count + 1))
    cd "$project_dir"
    if [[ -f "package.json" ]] && npm run start --if-present &>/dev/null & then
        local start_pid=$!
        sleep 5
        if kill -0 $start_pid 2>/dev/null; then
            passed_count=$((passed_count + 1))
            log_success "アプリケーション起動確認"
            kill $start_pid 2>/dev/null || true
        else
            log_error "アプリケーション起動失敗"
            issues+=("アプリケーション起動失敗")
        fi
    else
        log_warning "package.json または start スクリプトが見つかりません"
        issues+=("起動スクリプト不足")
    fi
    cd - > /dev/null
    
    # API エンドポイントテスト（存在する場合）
    if [[ -f "$project_dir/api" ]] || [[ -f "$project_dir/server.js" ]] || [[ -f "$project_dir/app.js" ]]; then
        total_count=$((total_count + 1))
        # 簡単なヘルスチェック
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health 2>/dev/null | grep -q "200"; then
            passed_count=$((passed_count + 1))
            log_success "API ヘルスチェック"
        else
            log_warning "API ヘルスチェック失敗（サーバーが起動していない可能性）"
            issues+=("API ヘルスチェック失敗")
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local pass_rate=$((passed_count * 100 / total_count))
    
    # 結果をJSONに記録
    cat >> "$report_file" << EOF
    "functional_requirements": {
      "passed": $passed_count,
      "total": $total_count,
      "pass_rate": $pass_rate,
      "duration_seconds": $duration,
      "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')]
    },
EOF
    
    log_info "機能要件チェック完了: $passed_count/$total_count ($pass_rate%)"
    return $pass_rate
}

# 2. パフォーマンステスト
check_performance() {
    local project_dir="$1"
    local report_file="$2"
    
    log_info "⚡ パフォーマンステスト実行中..."
    
    local start_time=$(date +%s)
    local performance_score=0
    local response_time=0
    local memory_usage=0
    local issues=()
    
    cd "$project_dir"
    
    # 応答時間測定
    if command -v curl &> /dev/null; then
        # 簡単な応答時間測定
        local test_url="http://localhost:3000"
        if curl -s --max-time 10 -w "@-" -o /dev/null "$test_url" << 'EOF' 2>/dev/null; then
time_total:%{time_total}
EOF
            response_time=$(curl -s --max-time 10 -w "%{time_total}" -o /dev/null "$test_url" 2>/dev/null || echo "999")
            response_time_ms=$(echo "$response_time * 1000" | bc 2>/dev/null || echo "999")
            
            if (( $(echo "$response_time_ms < 1000" | bc -l) )); then
                performance_score=$((performance_score + 40))
                log_success "応答時間: ${response_time_ms}ms"
            else
                log_warning "応答時間: ${response_time_ms}ms (目標: <1000ms)"
                issues+=("応答時間が目標値を超過: ${response_time_ms}ms")
            fi
        else
            log_warning "応答時間測定失敗（サーバー未起動の可能性）"
            issues+=("応答時間測定失敗")
            response_time_ms=999
        fi
    else
        log_warning "curl未インストール - 応答時間測定をスキップ"
        issues+=("curl未インストール")
        response_time_ms=0
    fi
    
    # メモリ使用量チェック
    if command -v ps &> /dev/null; then
        memory_usage=$(ps aux | grep -E "(node|npm)" | grep -v grep | awk '{sum += $6} END {print sum/1024}' 2>/dev/null || echo "0")
        if (( $(echo "$memory_usage < 512" | bc -l) )); then
            performance_score=$((performance_score + 30))
            log_success "メモリ使用量: ${memory_usage}MB"
        else
            log_warning "メモリ使用量: ${memory_usage}MB (目標: <512MB)"
            issues+=("メモリ使用量が目標値を超過: ${memory_usage}MB")
        fi
    else
        memory_usage=0
    fi
    
    # 負荷テスト（軽量版）
    if command -v ab &> /dev/null; then
        log_info "軽量負荷テスト実行中..."
        if ab -n 10 -c 2 -q http://localhost:3000/ > /dev/null 2>&1; then
            performance_score=$((performance_score + 30))
            log_success "負荷テスト完了"
        else
            log_warning "負荷テスト失敗"
            issues+=("負荷テスト失敗")
        fi
    else
        log_warning "Apache Bench未インストール - 負荷テストをスキップ"
        issues+=("Apache Bench未インストール")
    fi
    
    cd - > /dev/null
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 結果をJSONに記録
    cat >> "$report_file" << EOF
    "performance": {
      "score": $performance_score,
      "response_time_ms": $response_time_ms,
      "memory_usage_mb": $memory_usage,
      "duration_seconds": $duration,
      "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')]
    },
EOF
    
    log_info "パフォーマンステスト完了: スコア $performance_score/100"
    return $performance_score
}

# 3. セキュリティスキャン
check_security() {
    local project_dir="$1"
    local report_file="$2"
    
    log_info "🔒 セキュリティスキャン実行中..."
    
    local start_time=$(date +%s)
    local security_score=0
    local vulnerabilities=0
    local issues=()
    
    cd "$project_dir"
    
    # npm audit（Node.jsプロジェクトの場合）
    if [[ -f "package.json" ]]; then
        log_info "npm audit 実行中..."
        if npm audit --audit-level=high --json > audit_result.json 2>/dev/null; then
            vulnerabilities=$(jq '.metadata.vulnerabilities.high + .metadata.vulnerabilities.critical' audit_result.json 2>/dev/null || echo "0")
            if [[ "$vulnerabilities" == "0" ]]; then
                security_score=$((security_score + 50))
                log_success "高・重大レベル脆弱性: 0件"
            else
                log_warning "高・重大レベル脆弱性: ${vulnerabilities}件"
                issues+=("高・重大レベル脆弱性: ${vulnerabilities}件")
            fi
            rm -f audit_result.json
        else
            log_warning "npm audit実行失敗"
            issues+=("npm audit実行失敗")
        fi
    fi
    
    # 危険なパターンの検索
    local dangerous_patterns=("eval(" "innerHTML" "document.write" "setTimeout.*string")
    local pattern_count=0
    for pattern in "${dangerous_patterns[@]}"; do
        if grep -r "$pattern" src/ 2>/dev/null | head -1 > /dev/null; then
            pattern_count=$((pattern_count + 1))
            log_warning "危険なパターン検出: $pattern"
            issues+=("危険なパターン: $pattern")
        fi
    done
    
    if [[ $pattern_count -eq 0 ]]; then
        security_score=$((security_score + 30))
        log_success "危険なコードパターン: 0件"
    fi
    
    # HTTPS設定確認
    if grep -r "https://" . 2>/dev/null > /dev/null || grep -r "secure:" . 2>/dev/null > /dev/null; then
        security_score=$((security_score + 20))
        log_success "HTTPS設定確認"
    else
        log_warning "HTTPS設定が見つかりません"
        issues+=("HTTPS設定なし")
    fi
    
    cd - > /dev/null
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 結果をJSONに記録
    cat >> "$report_file" << EOF
    "security": {
      "score": $security_score,
      "vulnerabilities": $vulnerabilities,
      "dangerous_patterns": $pattern_count,
      "duration_seconds": $duration,
      "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')]
    },
EOF
    
    log_info "セキュリティスキャン完了: スコア $security_score/100"
    return $security_score
}

# 4. コード品質チェック
check_code_quality() {
    local project_dir="$1"
    local report_file="$2"
    
    log_info "📋 コード品質チェック実行中..."
    
    local start_time=$(date +%s)
    local quality_score=0
    local lint_errors=0
    local type_errors=0
    local issues=()
    
    cd "$project_dir"
    
    # ESLint チェック
    if [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]] || command -v eslint &> /dev/null; then
        log_info "ESLint 実行中..."
        lint_output=$(npx eslint src/ --format=json 2>/dev/null || echo '[]')
        lint_errors=$(echo "$lint_output" | jq 'map(.errorCount) | add // 0' 2>/dev/null || echo "0")
        
        if [[ "$lint_errors" == "0" ]]; then
            quality_score=$((quality_score + 40))
            log_success "ESLint エラー: 0件"
        else
            log_warning "ESLint エラー: ${lint_errors}件"
            issues+=("ESLint エラー: ${lint_errors}件")
        fi
    else
        log_warning "ESLint設定が見つかりません"
        issues+=("ESLint未設定")
    fi
    
    # TypeScript チェック
    if [[ -f "tsconfig.json" ]] || command -v tsc &> /dev/null; then
        log_info "TypeScript 型チェック実行中..."
        if npx tsc --noEmit --skipLibCheck 2>/dev/null; then
            quality_score=$((quality_score + 30))
            log_success "TypeScript 型エラー: 0件"
        else
            type_errors=1
            log_warning "TypeScript 型エラーあり"
            issues+=("TypeScript 型エラーあり")
        fi
    else
        log_info "TypeScript設定なし（JavaScript プロジェクト）"
    fi
    
    # コードサイズチェック
    local src_size=$(du -s src/ 2>/dev/null | cut -f1 || echo "0")
    if [[ $src_size -gt 0 ]]; then
        quality_score=$((quality_score + 15))
        log_success "ソースコード存在確認"
    else
        log_warning "ソースコードディレクトリが見つかりません"
        issues+=("ソースコードなし")
    fi
    
    # README品質チェック
    if [[ -f "README.md" ]] && [[ $(wc -l < README.md) -gt 10 ]]; then
        quality_score=$((quality_score + 15))
        log_success "README.md 品質確認"
    else
        log_warning "README.md が不十分です"
        issues+=("README.md 不十分")
    fi
    
    cd - > /dev/null
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 結果をJSONに記録
    cat >> "$report_file" << EOF
    "code_quality": {
      "score": $quality_score,
      "lint_errors": $lint_errors,
      "type_errors": $type_errors,
      "duration_seconds": $duration,
      "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')]
    },
EOF
    
    log_info "コード品質チェック完了: スコア $quality_score/100"
    return $quality_score
}

# 5. テストカバレッジチェック
check_test_coverage() {
    local project_dir="$1"
    local report_file="$2"
    
    log_info "🧪 テストカバレッジチェック実行中..."
    
    local start_time=$(date +%s)
    local coverage_score=0
    local coverage_percent=0
    local test_count=0
    local issues=()
    
    cd "$project_dir"
    
    # テストファイル存在確認
    test_count=$(find . -name "*.test.*" -o -name "*.spec.*" | wc -l)
    if [[ $test_count -gt 0 ]]; then
        log_success "テストファイル: ${test_count}個"
        coverage_score=$((coverage_score + 30))
    else
        log_warning "テストファイルが見つかりません"
        issues+=("テストファイルなし")
    fi
    
    # テスト実行
    if [[ -f "package.json" ]] && grep -q '"test"' package.json; then
        log_info "テスト実行中..."
        if npm test 2>/dev/null; then
            coverage_score=$((coverage_score + 40))
            log_success "テスト実行成功"
        else
            log_warning "テスト実行失敗"
            issues+=("テスト実行失敗")
        fi
    else
        log_warning "テストスクリプトが設定されていません"
        issues+=("テストスクリプト未設定")
    fi
    
    # カバレッジ測定
    if command -v nyc &> /dev/null || npm list nyc &> /dev/null; then
        log_info "カバレッジ測定中..."
        coverage_output=$(npm run test:coverage 2>/dev/null || echo "")
        if [[ -n "$coverage_output" ]]; then
            coverage_percent=$(echo "$coverage_output" | grep -oE '[0-9]+\.[0-9]+%|[0-9]+%' | head -1 | sed 's/%//' || echo "0")
            if (( $(echo "$coverage_percent >= 80" | bc -l) )); then
                coverage_score=$((coverage_score + 30))
                log_success "テストカバレッジ: ${coverage_percent}%"
            else
                log_warning "テストカバレッジ: ${coverage_percent}% (目標: ≥80%)"
                issues+=("カバレッジ不足: ${coverage_percent}%")
            fi
        fi
    else
        log_warning "カバレッジ測定ツールが見つかりません"
        issues+=("カバレッジ測定ツールなし")
    fi
    
    cd - > /dev/null
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 結果をJSONに記録
    cat >> "$report_file" << EOF
    "test_coverage": {
      "score": $coverage_score,
      "coverage_percent": $coverage_percent,
      "test_file_count": $test_count,
      "duration_seconds": $duration,
      "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')]
    },
EOF
    
    log_info "テストカバレッジチェック完了: スコア $coverage_score/100"
    return $coverage_score
}

# 6. ドキュメント確認
check_documentation() {
    local project_dir="$1"
    local report_file="$2"
    
    log_info "📚 ドキュメント確認中..."
    
    local start_time=$(date +%s)
    local doc_score=0
    local missing_docs=()
    local issues=()
    
    cd "$project_dir"
    
    # 必須ドキュメント確認
    local required_docs=("README.md" "package.json")
    for doc in "${required_docs[@]}"; do
        if [[ -f "$doc" ]]; then
            doc_score=$((doc_score + 25))
            log_success "必須ドキュメント: $doc"
        else
            missing_docs+=("$doc")
            log_warning "必須ドキュメント不足: $doc"
            issues+=("ドキュメント不足: $doc")
        fi
    done
    
    # 推奨ドキュメント確認
    local recommended_docs=("docs/" "API.md" ".env.example")
    for doc in "${recommended_docs[@]}"; do
        if [[ -e "$doc" ]]; then
            doc_score=$((doc_score + 16))
            log_success "推奨ドキュメント: $doc"
        else
            log_info "推奨ドキュメント: $doc (任意)"
        fi
    done
    
    # README.md 内容品質チェック
    if [[ -f "README.md" ]]; then
        local readme_sections=("# " "## " "```" "install" "usage")
        local found_sections=0
        for section in "${readme_sections[@]}"; do
            if grep -i "$section" README.md > /dev/null; then
                found_sections=$((found_sections + 1))
            fi
        done
        if [[ $found_sections -ge 4 ]]; then
            doc_score=$((doc_score + 8))
            log_success "README.md 内容品質良好"
        else
            log_warning "README.md 内容が不十分"
            issues+=("README.md 内容不十分")
        fi
    fi
    
    cd - > /dev/null
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 結果をJSONに記録
    cat >> "$report_file" << EOF
    "documentation": {
      "score": $doc_score,
      "missing_required": [$(printf '"%s",' "${missing_docs[@]}" | sed 's/,$//')]",
      "duration_seconds": $duration,
      "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')]
    }
EOF
    
    log_info "ドキュメント確認完了: スコア $doc_score/100"
    return $doc_score
}

# 総合評価とレポート生成
generate_final_report() {
    local project_id="$1"
    local report_file="$2"
    local func_score="$3"
    local perf_score="$4"
    local sec_score="$5"
    local quality_score="$6"
    local test_score="$7"
    local doc_score="$8"
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local total_score=$((func_score + perf_score + sec_score + quality_score + test_score + doc_score))
    local average_score=$((total_score / 6))
    
    # 合格判定（品質基準に基づく）
    local functional_pass=$([[ $func_score -ge 100 ]] && echo "true" || echo "false")
    local quality_pass=$([[ $perf_score -ge 80 && $sec_score -ge 80 ]] && echo "true" || echo "false")
    local technical_pass=$([[ $quality_score -ge 90 && $test_score -ge 85 ]] && echo "true" || echo "false")
    local overall_pass=$([[ "$functional_pass" == "true" && "$quality_pass" == "true" && "$technical_pass" == "true" ]] && echo "true" || echo "false")
    
    # JSONレポート完成
    cat > "$report_file" << EOF
{
  "project_id": "$project_id",
  "timestamp": "$timestamp",
  "summary": {
    "overall_pass": $overall_pass,
    "total_score": $total_score,
    "average_score": $average_score,
    "functional_requirements_pass": $functional_pass,
    "quality_requirements_pass": $quality_pass,
    "technical_requirements_pass": $technical_pass
  },
  "detailed_scores": {
    "functional_requirements": $func_score,
    "performance": $perf_score,
    "security": $sec_score,
    "code_quality": $quality_score,
    "test_coverage": $test_score,
    "documentation": $doc_score
  },
$(cat "$report_file.tmp")
}
EOF
    
    # テキストサマリー生成
    local summary_file="quality-reports/${project_id}_summary.txt"
    cat > "$summary_file" << EOF
=================================================================
🎯 Quality Assurance System 品質チェック結果
=================================================================

プロジェクトID: $project_id
実行時刻: $timestamp
総合判定: $([[ "$overall_pass" == "true" ]] && echo "✅ 合格" || echo "❌ 不合格")

=================================================================
📊 スコア詳細
=================================================================

機能要件:         $func_score/100  $([[ $func_score -eq 100 ]] && echo "✅" || echo "❌")
パフォーマンス:   $perf_score/100  $([[ $perf_score -ge 80 ]] && echo "✅" || echo "⚠️")
セキュリティ:     $sec_score/100   $([[ $sec_score -ge 80 ]] && echo "✅" || echo "⚠️")
コード品質:       $quality_score/100 $([[ $quality_score -ge 90 ]] && echo "✅" || echo "⚠️")
テストカバレッジ: $test_score/100  $([[ $test_score -ge 85 ]] && echo "✅" || echo "⚠️")
ドキュメント:     $doc_score/100   $([[ $doc_score -ge 70 ]] && echo "✅" || echo "⚠️")

総合スコア: $total_score/600 (平均: $average_score/100)

=================================================================
🎯 合格基準
=================================================================

✅ 必須条件:
   - 機能要件: 100% 必達
   - パフォーマンス: 80%以上
   - セキュリティ: 80%以上
   - コード品質: 90%以上
   - テストカバレッジ: 85%以上

⚠️  推奨条件:
   - ドキュメント: 70%以上

=================================================================
📋 次のアクション
=================================================================

$([[ "$overall_pass" == "true" ]] && echo "🎉 品質チェック合格
   - 実装完了として承認可能
   - デプロイメント準備を開始
   - ステークホルダーへの報告準備" || echo "🔧 品質改善が必要
   - 不合格項目の修正が必要
   - 修正後に再度品質チェック実行
   - 詳細な修正指示は QualityManager が提供")

=================================================================
EOF
    
    # 結果表示
    echo ""
    echo "=================================================="
    echo "🎯 品質チェック完了"
    echo "=================================================="
    echo ""
    echo "総合判定: $([[ "$overall_pass" == "true" ]] && echo "✅ 合格" || echo "❌ 不合格")"
    echo "総合スコア: $total_score/600 (平均: $average_score/100)"
    echo ""
    echo "詳細レポート: $report_file"
    echo "サマリー: $summary_file"
    echo ""
    
    return $([[ "$overall_pass" == "true" ]] && echo 0 || echo 1)
}

# メイン処理
main() {
    echo "🎯 Quality Assurance System 品質チェック開始"
    echo "=============================================="
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
    
    # プロジェクトディレクトリ確認
    if ! check_project_dir "$project_id"; then
        exit 1
    fi
    
    # 品質基準読み込み
    load_quality_standards
    
    # レポートファイル準備
    mkdir -p quality-reports
    local report_file="quality-reports/${project_id}_report.json"
    local temp_report="$report_file.tmp"
    
    # レポート初期化
    echo "{" > "$temp_report"
    
    echo ""
    log_info "品質チェック開始: $(date)"
    echo ""
    
    # 各チェック実行
    local project_dir="workspace/$project_id"
    
    check_functional_requirements "$project_dir" "$temp_report"
    local func_score=$?
    
    check_performance "$project_dir" "$temp_report"
    local perf_score=$?
    
    check_security "$project_dir" "$temp_report"
    local sec_score=$?
    
    check_code_quality "$project_dir" "$temp_report"
    local quality_score=$?
    
    check_test_coverage "$project_dir" "$temp_report"
    local test_score=$?
    
    check_documentation "$project_dir" "$temp_report"
    local doc_score=$?
    
    # 最終レポート生成
    generate_final_report "$project_id" "$report_file" \
        "$func_score" "$perf_score" "$sec_score" \
        "$quality_score" "$test_score" "$doc_score"
    local final_result=$?
    
    # 一時ファイル削除
    rm -f "$temp_report"
    
    echo ""
    log_info "品質チェック完了: $(date)"
    
    exit $final_result
}

main "$@"