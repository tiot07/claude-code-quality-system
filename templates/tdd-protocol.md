# 🔴🟢🔵 TDD Protocol (t-wada推奨)

## TDDの3つの法則

### 1. 失敗するテストを書くまでは、プロダクションコードを書いてはならない
### 2. コンパイルが通らない、または失敗するテストを書く以上のテストコードを書いてはならない
### 3. 現在失敗しているテストをパスする以上のプロダクションコードを書いてはならない

## TDDサイクル（Red-Green-Refactor）

### 🔴 Red フェーズ
**失敗するテストを書く**
- 次に実装したい機能の最小単位を決める
- その機能をテストするコードを書く
- テストを実行して、期待通り失敗することを確認する
- コンパイルエラーの場合は、コンパイルが通る最小限のコードを書く

### 🟢 Green フェーズ  
**テストを通す**
- 失敗しているテストをパスさせる最小限のコードを書く
- "どんなに汚いコードでも構わない"
- とにかくテストをパスさせることが目標
- テストを実行して、すべてのテストがパスすることを確認する

### 🔵 Refactor フェーズ
**コードを改善する**
- テストが通っている状態を保ちながらコードを改善する
- 重複を排除する
- 意図を明確にする
- 設計を改善する
- 各改善ステップでテストを実行して安全性を確認する

## t-wada推奨のTDD実践ポイント

### 1. テストファースト
```bash
# ❌ 間違った順序
1. プロダクションコードを書く
2. テストを書く

# ✅ 正しい順序  
1. テストを書く
2. プロダクションコードを書く
```

### 2. 最小限の変更
```javascript
// 🔴 Red: 失敗するテストを書く
test('add関数は2つの数値を足し算する', () => {
  expect(add(1, 2)).toBe(3);
});

// 🟢 Green: 最小限のコードでテストを通す
function add(a, b) {
  return 3; // ベタ書きでもOK
}

// 🔵 Refactor: より汎用的に改善
function add(a, b) {
  return a + b;
}
```

### 3. 仮実装からの段階的実装
```javascript
// Step 1: 仮実装（Fake Implementation）
function factorial(n) {
  return 1; // 仮の値
}

// Step 2: 明白な実装（Obvious Implementation）
function factorial(n) {
  if (n === 0) return 1;
  return n * factorial(n - 1);
}

// Step 3: 三角測量（Triangulation）
// 複数のテストケースで実装を確実にする
```

### 4. テスト駆動による設計
- テストを書くことで、コードの使いやすいインターフェースが自然に決まる
- テスタビリティの高い設計になる
- 疎結合・高凝集な設計が促進される

## Claude Code開発での実践手順

### Phase 1: 要件をテストに変換
```markdown
## 要件
ユーザーがログインできる

## テストケース
1. 正しいメールアドレスとパスワードでログインできる
2. 間違ったパスワードでログインに失敗する
3. 存在しないメールアドレスでログインに失敗する
4. 空のフィールドでログインに失敗する
```

### Phase 2: 🔴 Red - 失敗するテストを書く
```javascript
describe('ユーザーログイン', () => {
  test('正しい認証情報でログインできる', async () => {
    const result = await authService.login('user@example.com', 'password123');
    expect(result.success).toBe(true);
    expect(result.user.email).toBe('user@example.com');
    expect(result.token).toBeDefined();
  });

  test('間違ったパスワードでログインに失敗する', async () => {
    const result = await authService.login('user@example.com', 'wrongpassword');
    expect(result.success).toBe(false);
    expect(result.error).toBe('Invalid credentials');
  });
});
```

### Phase 3: 🟢 Green - 最小限の実装
```javascript
class AuthService {
  async login(email, password) {
    // 仮実装: テストを通すための最小限のコード
    if (email === 'user@example.com' && password === 'password123') {
      return {
        success: true,
        user: { email: 'user@example.com' },
        token: 'fake-token'
      };
    }
    return {
      success: false,
      error: 'Invalid credentials'
    };
  }
}
```

### Phase 4: 🔵 Refactor - 実装を改善
```javascript
class AuthService {
  constructor(userRepository, tokenService) {
    this.userRepository = userRepository;
    this.tokenService = tokenService;
  }

  async login(email, password) {
    const user = await this.userRepository.findByEmail(email);
    if (!user) {
      return { success: false, error: 'Invalid credentials' };
    }

    const isValidPassword = await this.verifyPassword(password, user.hashedPassword);
    if (!isValidPassword) {
      return { success: false, error: 'Invalid credentials' };
    }

    const token = this.tokenService.generate(user.id);
    return {
      success: true,
      user: { email: user.email },
      token
    };
  }
}
```

## TDD品質チェックポイント

### ✅ テスト品質
- [ ] テストが要件を正しく表現している
- [ ] テストケースに漏れがない
- [ ] テストが独立している（他のテストに依存しない）
- [ ] テストが高速に実行できる
- [ ] テストが読みやすい

### ✅ コード品質
- [ ] すべてのテストがパスしている
- [ ] プロダクションコードに不要な複雑さがない
- [ ] 重複コードが排除されている
- [ ] メソッド・クラスの責任が明確
- [ ] 命名が意図を表している

### ✅ 設計品質
- [ ] 疎結合な設計になっている
- [ ] 依存関係が適切に管理されている
- [ ] 拡張しやすい構造になっている
- [ ] テスタビリティが高い

## TDDツールと環境

### JavaScript/TypeScript
```bash
# テストフレームワーク
npm install --save-dev jest
npm install --save-dev @testing-library/react  # React用

# 実行コマンド
npm test
npm run test:watch
npm run test:coverage
```

### Python
```bash
# テストフレームワーク
pip install pytest
pip install pytest-cov  # カバレッジ測定

# 実行コマンド
pytest
pytest --cov=src
pytest --watch
```

### その他の言語
```bash
# Java
mvn test

# C#
dotnet test

# Go  
go test ./...

# Ruby
rspec
```

## TDD成功のコツ

### 1. 小さなステップで進む
- 一度に1つの機能だけを実装する
- テストケースを細分化する
- 早めにフィードバックを得る

### 2. レッド・グリーン・リファクターを厳密に守る
- レッドフェーズでは絶対にプロダクションコードを書かない
- グリーンフェーズでは汚いコードでも構わない
- リファクターフェーズで必ず設計を改善する

### 3. テストの質を重視する
- テスト自体もレビューの対象にする
- テストコードも保守しやすく書く
- 適切なアサーションを使う

### 4. 継続的にリファクタリングする
- 設計の改善を後回しにしない
- 小さなリファクタリングを積み重ねる
- テストがあることでリファクタリングが安全になる

## アンチパターンを避ける

### ❌ テスト後書き
```javascript
// 実装を先に書いて、後からテストを書く
function add(a, b) {
  return a + b;
}

// 後から書かれたテスト（価値が低い）
test('add', () => {
  expect(add(1, 2)).toBe(3);
});
```

### ❌ 大きすぎるステップ
```javascript
// 一度に多くの機能を実装しようとする
test('完全なユーザー管理システム', () => {
  // 登録、ログイン、プロフィール更新、削除を一度にテスト
});
```

### ❌ リファクタリングを怠る
```javascript
// テストは通るが、改善されない汚いコード
function complexFunction(data) {
  // 100行の複雑なロジック
  if (data && data.user && data.user.profile && data.user.profile.settings) {
    // ...
  }
}
```

## まとめ

TDDは単なるテスト手法ではなく、**設計手法**です。テストファーストで開発することにより：

1. **より良い設計** - テスタブルで疎結合な設計
2. **高い品質** - バグが少なく、仕様を満たすコード  
3. **保守性** - 変更に強く、リファクタリングしやすいコード
4. **開発速度** - 長期的には開発速度が向上
5. **安心感** - 変更への恐怖がなくなる

**TDDは習慣です。** 毎日実践することで、自然に品質の高いコードが書けるようになります。