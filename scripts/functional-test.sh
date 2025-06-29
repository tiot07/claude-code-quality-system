#!/bin/bash

# 🧪 Functional Test Script - 実動作確認テスト
# QualityManagerが実際のアプリケーション動作を自動的に検証するスクリプト

set -e

# 色付きログ関数
log_info() {
    echo -e "\033[1;36m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# プロジェクトID取得
if [ -f workspace/current_project_id.txt ]; then
    PROJECT_ID=$(cat workspace/current_project_id.txt)
else
    log_error "プロジェクトIDが見つかりません"
    exit 1
fi

PROJECT_DIR="workspace/$PROJECT_ID"

log_info "🧪 実動作確認テスト開始: $PROJECT_ID"
echo "=========================================="

# プロジェクトディレクトリ確認
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "プロジェクトディレクトリが見つかりません: $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"

# テスト結果記録ファイル
TEST_REPORT="functional_test_report.md"
echo "# 実動作確認テスト結果" > "$TEST_REPORT"
echo "日時: $(date '+%Y/%m/%d %H:%M:%S')" >> "$TEST_REPORT"
echo "プロジェクト: $PROJECT_ID" >> "$TEST_REPORT"
echo "" >> "$TEST_REPORT"

# テスト結果カウンタ
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# テスト実行関数
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "テスト実行: $test_name"
    
    if eval "$test_command"; then
        log_success "✅ $test_name"
        echo "- ✅ $test_name" >> "$TEST_REPORT"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        log_error "❌ $test_name"
        echo "- ❌ $test_name" >> "$TEST_REPORT"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# 1. プロジェクト構造確認
log_info "📁 プロジェクト構造確認"
echo "## プロジェクト構造確認" >> "$TEST_REPORT"

run_test "package.json存在確認" "[ -f package.json ]"

if [ -f package.json ]; then
    run_test "package.jsonの構文確認" "node -e 'JSON.parse(require(\"fs\").readFileSync(\"package.json\", \"utf8\"))'"
    
    # scripts設定確認
    if grep -q '"dev"' package.json; then
        run_test "npm run devスクリプト存在確認" "grep -q '\"dev\"' package.json"
    else
        log_warning "npm run devスクリプトが見つかりません"
        echo "- ⚠️ npm run devスクリプトが見つかりません" >> "$TEST_REPORT"
    fi
fi

# 2. 依存関係確認
log_info "📦 依存関係確認"
echo "## 依存関係確認" >> "$TEST_REPORT"

if [ -f package.json ]; then
    run_test "npm install実行" "npm install --silent"
    
    # 主要依存関係確認
    if [ -d node_modules ]; then
        run_test "node_modules存在確認" "[ -d node_modules ]"
        
        # React/Vue/Angularなど主要フレームワーク確認
        if grep -q '"react"' package.json; then
            run_test "React依存関係確認" "[ -d node_modules/react ]"
        fi
        
        if grep -q '"vue"' package.json; then
            run_test "Vue依存関係確認" "[ -d node_modules/vue ]"
        fi
        
        if grep -q '"@angular/core"' package.json; then
            run_test "Angular依存関係確認" "[ -d node_modules/@angular/core ]"
        fi
    fi
fi

# 3. ビルド/コンパイル確認
log_info "🔨 ビルド/コンパイル確認"
echo "## ビルド/コンパイル確認" >> "$TEST_REPORT"

if [ -f package.json ] && grep -q '"build"' package.json; then
    # タイムアウト付きビルドテスト
    run_test "ビルド実行テスト" "timeout 120s npm run build"
fi

# 4. 開発サーバー起動テスト
log_info "🚀 開発サーバー起動テスト"
echo "## 開発サーバー起動テスト" >> "$TEST_REPORT"

if [ -f package.json ] && grep -q '"dev"' package.json; then
    # 既存プロセス終了
    pkill -f "npm run dev" 2>/dev/null || true
    pkill -f "node.*dev" 2>/dev/null || true
    sleep 2
    
    # 開発サーバー起動
    log_info "開発サーバー起動中..."
    npm run dev > dev_server.log 2>&1 &
    DEV_PID=$!
    
    # 起動待機
    log_info "起動待機中... (最大30秒)"
    sleep 15
    
    # ポート確認
    SERVER_STARTED=false
    for port in 3000 3001 4000 5000 8000 8080; do
        if lsof -i :$port > /dev/null 2>&1; then
            log_success "サーバー起動確認 (ポート: $port)"
            SERVER_PORT=$port
            SERVER_STARTED=true
            break
        fi
    done
    
    if [ "$SERVER_STARTED" = true ]; then
        run_test "開発サーバー起動確認" "true"
        
        # 5. HTTP応答テスト
        log_info "🌐 HTTP応答テスト"
        echo "## HTTP応答テスト" >> "$TEST_REPORT"
        
        # 基本HTTP応答確認
        sleep 5  # 追加待機
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SERVER_PORT" 2>/dev/null || echo "000")
        
        if [ "$HTTP_STATUS" = "200" ]; then
            run_test "HTTP応答正常 (200)" "true"
            
            # HTMLコンテンツ確認
            CONTENT=$(curl -s "http://localhost:$SERVER_PORT" 2>/dev/null)
            
            if [ -n "$CONTENT" ]; then
                run_test "HTMLコンテンツ取得" "true"
                
                # HTML構造確認
                if echo "$CONTENT" | grep -qi "<html\|<!doctype"; then
                    run_test "HTML構造確認" "true"
                else
                    run_test "HTML構造確認" "false"
                fi
                
                # JavaScript読み込み確認
                if echo "$CONTENT" | grep -qi "<script\|javascript"; then
                    run_test "JavaScript読み込み確認" "true"
                else
                    log_warning "JavaScriptファイルが見つかりません"
                    echo "- ⚠️ JavaScriptファイルが見つかりません" >> "$TEST_REPORT"
                fi
                
                # CSS読み込み確認
                if echo "$CONTENT" | grep -qi "<link.*css\|<style"; then
                    run_test "CSS読み込み確認" "true"
                else
                    log_warning "CSSファイルが見つかりません"
                    echo "- ⚠️ CSSファイルが見つかりません" >> "$TEST_REPORT"
                fi
                
            else
                run_test "HTMLコンテンツ取得" "false"
            fi
        else
            run_test "HTTP応答正常 (200)" "false"
            echo "実際のステータス: $HTTP_STATUS" >> "$TEST_REPORT"
        fi
        
        # 6. JavaScript エラーチェック（簡易版）
        log_info "⚡ JavaScript エラーチェック"
        echo "## JavaScript エラーチェック" >> "$TEST_REPORT"
        
        # コンソールエラーの間接的チェック（レスポンス内容確認）
        if echo "$CONTENT" | grep -qi "error\|exception\|undefined.*function"; then
            run_test "JavaScript エラーなし" "false"
            echo "  - HTMLにエラー関連の文字列が含まれています" >> "$TEST_REPORT"
        else
            run_test "JavaScript エラーなし" "true"
        fi
        
        # 7. 基本的なAPIエンドポイントテスト
        log_info "🔌 APIエンドポイントテスト"
        echo "## APIエンドポイントテスト" >> "$TEST_REPORT"
        
        # 一般的なAPIエンドポイントをテスト
        for endpoint in "/api" "/api/health" "/health" "/status"; do
            API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SERVER_PORT$endpoint" 2>/dev/null || echo "000")
            if [ "$API_STATUS" != "000" ] && [ "$API_STATUS" != "404" ]; then
                run_test "API エンドポイント ($endpoint): $API_STATUS" "true"
                break
            fi
        done
        
    else
        run_test "開発サーバー起動確認" "false"
        log_error "開発サーバーの起動に失敗しました"
        
        # エラーログ確認
        if [ -f dev_server.log ]; then
            log_info "開発サーバーログ:"
            tail -10 dev_server.log
            echo "## 開発サーバーエラーログ" >> "$TEST_REPORT"
            echo "\`\`\`" >> "$TEST_REPORT"
            tail -10 dev_server.log >> "$TEST_REPORT"
            echo "\`\`\`" >> "$TEST_REPORT"
        fi
    fi
    
    # 開発サーバー停止
    if [ -n "$DEV_PID" ]; then
        kill $DEV_PID 2>/dev/null || true
    fi
    pkill -f "npm run dev" 2>/dev/null || true
    sleep 2
fi

# 8. テスト実行確認
log_info "🧪 テスト実行確認"
echo "## テスト実行確認" >> "$TEST_REPORT"

if [ -f package.json ] && grep -q '"test"' package.json; then
    run_test "ユニットテスト実行" "timeout 60s npm test -- --watchAll=false"
fi

# 9. Lint/型チェック
log_info "🔍 Lint/型チェック"
echo "## Lint/型チェック" >> "$TEST_REPORT"

if [ -f package.json ]; then
    if grep -q '"lint"' package.json; then
        run_test "Lint実行" "npm run lint"
    fi
    
    # TypeScript型チェック
    if [ -f tsconfig.json ]; then
        run_test "TypeScript型チェック" "npx tsc --noEmit"
    fi
fi

# テスト結果サマリー
echo "" >> "$TEST_REPORT"
echo "## テスト結果サマリー" >> "$TEST_REPORT"
echo "- 総テスト数: $TOTAL_TESTS" >> "$TEST_REPORT"
echo "- 成功: $PASSED_TESTS" >> "$TEST_REPORT"
echo "- 失敗: $FAILED_TESTS" >> "$TEST_REPORT"
echo "- 成功率: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%" >> "$TEST_REPORT"

log_info "=========================================="
log_info "🏁 実動作確認テスト完了"
log_info "総テスト数: $TOTAL_TESTS"
log_success "成功: $PASSED_TESTS"
if [ $FAILED_TESTS -gt 0 ]; then
    log_error "失敗: $FAILED_TESTS"
else
    log_success "失敗: $FAILED_TESTS"
fi
log_info "成功率: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
log_info "詳細レポート: $PROJECT_DIR/$TEST_REPORT"

# 結果判定
if [ $FAILED_TESTS -eq 0 ]; then
    log_success "🎉 全テスト成功！アプリケーションは正常に動作しています"
    exit 0
else
    log_error "💥 失敗したテストがあります。修正が必要です"
    exit 1
fi