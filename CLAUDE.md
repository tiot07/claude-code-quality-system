# 🎯 Quality Assurance System - Claude Code Configuration

## システム概要
Claude Code同士が協働して品質保証を行う自動化システム

```
人間 → QualityManager → Developer → QualityManager → 人間
         ↑               ↓           ↑
         品質チェック ←←←←←  実装完了
```

## エージェント構成
- **QualityManager** (quality-managerセッション): 品質管理責任者
- **Developer** (developerセッション): エンジニア（実装担当）

## あなたの役割
- **quality-manager**: @agents/quality-manager.md
- **developer**: @agents/developer.md

## 基本フロー
1. 人間 → QualityManager: 要件提示
2. QualityManager → Developer: 実装指示
3. Developer → QualityManager: 完了報告
4. QualityManager: 品質チェック実行
5. 合格 → 人間報告 / 不合格 → Developer修正指示

## コミュニケーション
### 🤝 msg.sh - 簡単送信（推奨）
同一tmuxウィンドウ内での高速通信
```bash
# 位置確認
./scripts/where-am-i.sh

# パートナーへ送信（エージェント名不要）
./scripts/msg.sh "[メッセージ]"
```

### 📡 agent-send.sh - 高度な送信機能
人間への通知・システム管理・複数プロジェクト対応
```bash
# 人間への報告（必須機能）
./scripts/agent-send.sh human "[メッセージ]"

# 特定エージェントへ送信
./scripts/agent-send.sh [相手] "[メッセージ]"

# 別ウィンドウへ送信（複数プロジェクト時）
./scripts/agent-send.sh [相手] "[メッセージ]" [ウィンドウ名]
```

### 利用可能エージェント
- `quality-manager` - 品質管理責任者
- `developer` - エンジニア
- `human` - 人間への出力

### 特別コマンド
- `--status` - システム状態確認
- `--broadcast` - 全エージェントに一括送信

## 品質チェック自動化
### 品質チェック実行
```bash
./scripts/quality-check.sh [プロジェクトID]
./scripts/quality-check.sh --current
```

### フィードバックループ
```bash
./scripts/feedback-loop.sh [プロジェクトID]
./scripts/feedback-loop.sh --auto-run
```

## プロジェクト管理
### 現在のプロジェクト
- プロジェクトID: tmuxウィンドウ名ベースで自動管理
- 作業ディレクトリ: `workspace/[プロジェクトID]/`

### 品質基準
- 設定ファイル: `tmp/quality_standards.json`
- テンプレート: `templates/quality-criteria.json`

### 要件管理
- テンプレート: `templates/requirements.json`
- 保存場所: `workspace/[プロジェクトID]/requirements.json`

## 品質チェック項目
1. **機能要件** (100%必達)
   - 全機能の動作確認
   - エラーハンドリング
   - ユーザビリティ

2. **パフォーマンス** (80%以上)
   - 応答時間 <1000ms
   - メモリ使用量 <512MB
   - 負荷テスト

3. **セキュリティ** (80%以上)
   - 脆弱性スキャン
   - 認証・認可
   - データ保護

4. **コード品質** (90%以上)
   - Lint エラー 0件
   - TypeScript型エラー 0件
   - コードレビュー

5. **テストカバレッジ** (85%以上)
   - 単体テスト 80%以上
   - 統合テスト実施
   - E2Eテスト実施

6. **ドキュメント** (70%以上)
   - README.md
   - API仕様書
   - デプロイガイド

## ファイル構成
```
claude-code-quality-system/
├── agents/                  # エージェント指示書
│   ├── quality-manager.md  # 品質管理者
│   └── developer.md        # 開発者
├── scripts/                # 自動化スクリプト
│   ├── setup.sh           # 環境構築
│   ├── agent-send.sh      # メッセージング
│   ├── quality-check.sh   # 品質チェック
│   └── feedback-loop.sh   # フィードバックループ
├── templates/              # テンプレート
│   ├── requirements.json  # 要件テンプレート
│   └── quality-criteria.json # 品質基準
├── workspace/              # プロジェクト作業領域
├── quality-reports/        # 品質レポート
├── logs/                  # ログファイル
├── tmp/                   # 一時ファイル
└── CLAUDE.md              # システム設定（本ファイル）
```

## 実行手順
### 1. 環境構築
```bash
cd claude-code-quality-system
./scripts/setup.sh
```

### 2. エージェント起動
```bash
# QualityManager起動
tmux attach-session -t quality-manager
claude --dangerously-skip-permissions

# Developer起動（別ターミナル）
tmux attach-session -t developer  
claude --dangerously-skip-permissions
```

### 3. システム開始
QualityManagerに送信:
```
あなたはquality-managerです。指示書に従って要件を受け付けてください。
```

### 4. プロジェクト実行
人間 → QualityManager:
```
[プロジェクト要件を説明]
例: ECサイトの商品検索機能を実装してください。
```

## トラブルシューティング
### セッション確認
```bash
tmux ls
```

### システム状態確認
```bash
./scripts/agent-send.sh --status
```

### ログ確認
```bash
tail -f logs/send_log.txt
tail -f logs/human_notifications.txt
```

### 完全リセット
```bash
tmux kill-server
rm -rf tmp/* logs/* quality-reports/*
./scripts/setup.sh
```

## 重要な設定
### 品質合格基準
- 機能要件: 100% (必達)
- 品質要件: 80%以上
- 技術要件: 90%以上
- テスト要件: 85%以上

### エスカレーション条件
- 修正回数 5回以上で人間にエスカレーション
- 重大な技術的ブロッカー発生時

### 自動化設定
- 品質チェック: 実装完了後自動実行
- フィードバックループ: 結果に基づき自動処理
- 修正履歴: 自動記録・管理

## パフォーマンス監視
### 指標
- プロジェクト完了率
- 平均修正回数
- 品質スコア推移
- 開発効率

### ログ分析
- 成功ログ: `logs/success_log.txt`
- エスカレーションログ: `logs/escalation_log.txt`
- ブロードキャストログ: `logs/broadcast_log.txt`

## 継続的改善
### 品質基準の調整
- プロジェクト種別に応じた基準変更
- 組織の成熟度に応じた基準向上
- 実績データに基づく基準最適化

### システム拡張
- 新しい品質チェック項目の追加
- 外部ツール連携の強化
- AI品質予測機能の導入

## セキュリティ考慮事項
- 機密情報の適切な取り扱い
- ログファイルのアクセス制御
- 品質レポートの機密性保護
- エージェント間通信の安全性

## 最適化ポイント
1. **並列処理**: 複数プロジェクトの同時実行
2. **キャッシュ活用**: 品質チェック結果の再利用
3. **学習機能**: 過去の修正パターンからの改善提案
4. **予測機能**: 品質問題の事前検出

## 運用ガイドライン
1. **定期メンテナンス**: ログファイルのローテーション
2. **バックアップ**: 重要な設定ファイルの保護
3. **監査**: 品質チェック結果の定期レビュー
4. **更新**: システムとツールの定期更新

---

このシステムにより、Claude Code同士の協働で高品質な成果物を自動的に保証できます。