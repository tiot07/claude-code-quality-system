# TDD Test Plan - GameCorp Website + Games

## 🔴 Red Phase: 失敗するテストケース

### テストケース1: コーポレートサイト基盤
```typescript
describe('Header Component', () => {
  test('ナビゲーションメニューが正しく表示される', () => {
    // Arrange: テストデータ準備
    const { getByRole, getByText } = render(<Header />);
    
    // Act & Assert: 実行と検証
    expect(getByRole('navigation')).toBeInTheDocument();
    expect(getByText('GameCorp')).toBeInTheDocument();
    expect(getByText('About')).toBeInTheDocument();
    expect(getByText('Games')).toBeInTheDocument();
    expect(getByText('Team')).toBeInTheDocument();
  });

  test('モバイルメニューが切り替えできる', () => {
    const { getByRole } = render(<Header />);
    const mobileMenuButton = getByRole('button', { name: /menu/i });
    
    fireEvent.click(mobileMenuButton);
    
    expect(getByRole('menu')).toBeVisible();
  });
});

describe('Hero Section', () => {
  test('ヒーローセクションが適切に表示される', () => {
    const { getByText, getByRole } = render(<Hero />);
    
    expect(getByText(/GameCorp/i)).toBeInTheDocument();
    expect(getByText(/革新的ゲーム体験/i)).toBeInTheDocument();
    expect(getByRole('button', { name: /ゲームを試す/i })).toBeInTheDocument();
  });
});
```

### テストケース2: リバーシゲーム機能
```typescript
describe('Reversi Game Logic', () => {
  test('ゲーム盤面が正しく初期化される', () => {
    // Arrange & Act
    const game = new ReversiGame();
    const board = game.initializeBoard();
    
    // Assert
    expect(board).toHaveLength(8);
    expect(board[0]).toHaveLength(8);
    expect(board[3][3]).toBe('white');
    expect(board[3][4]).toBe('black');
    expect(board[4][3]).toBe('black');
    expect(board[4][4]).toBe('white');
  });

  test('有効な手を判定できる', () => {
    const game = new ReversiGame();
    const board = game.initializeBoard();
    
    const validMoves = game.getValidMoves(board, 'black');
    
    expect(validMoves).toContain([2, 3]);
    expect(validMoves).toContain([3, 2]);
    expect(validMoves).toContain([4, 5]);
    expect(validMoves).toContain([5, 4]);
  });

  test('石を置いて挟んだ石をひっくり返せる', () => {
    const game = new ReversiGame();
    const board = game.initializeBoard();
    
    const newBoard = game.makeMove(board, 2, 3, 'black');
    
    expect(newBoard[2][3]).toBe('black');
    expect(newBoard[3][3]).toBe('black');
  });
});

describe('Minimax AI', () => {
  test('AIが最適な手を選択する', () => {
    const ai = new MinimaxAI(5); // depth 5
    const game = new ReversiGame();
    const board = game.initializeBoard();
    
    const aiMove = ai.getBestMove(board, 'white');
    
    expect(aiMove).toBeDefined();
    expect(typeof aiMove.row).toBe('number');
    expect(typeof aiMove.col).toBe('number');
  });

  test('AIが人間に必ず勝利する強さを持つ', () => {
    const ai = new MinimaxAI(6);
    const game = new ReversiGame();
    
    // シミュレーションテスト（AIが常に最適手を選ぶことを確認）
    const result = game.simulateGameVsAI(ai);
    
    expect(result.winner).toBe('white'); // AI (white) が勝利
    expect(result.aiScore).toBeGreaterThan(result.humanScore);
  });
});
```

### テストケース3: テトリスゲーム機能
```typescript
describe('Tetris Game Logic', () => {
  test('7種類のテトリミノが正しく定義される', () => {
    const tetriminos = TetrisGame.getTetriminos();
    
    expect(tetriminos).toHaveLength(7);
    expect(tetriminos[0].type).toBe('I');
    expect(tetriminos[1].type).toBe('O');
    expect(tetriminos[2].type).toBe('T');
    expect(tetriminos[3].type).toBe('S');
    expect(tetriminos[4].type).toBe('Z');
    expect(tetriminos[5].type).toBe('J');
    expect(tetriminos[6].type).toBe('L');
  });

  test('テトリミノが回転できる', () => {
    const tetrimino = new Tetrimino('T');
    const originalShape = tetrimino.getShape();
    
    tetrimino.rotate();
    const rotatedShape = tetrimino.getShape();
    
    expect(rotatedShape).not.toEqual(originalShape);
  });

  test('ラインが完成したら消去される', () => {
    const game = new TetrisGame();
    // 下から2行目を埋める
    for (let col = 0; col < 10; col++) {
      game.board[19][col] = 1;
    }
    
    const clearedLines = game.clearCompletedLines();
    
    expect(clearedLines).toBe(1);
    expect(game.board[19].every(cell => cell === 0)).toBe(true);
  });

  test('ゲームが60FPS で滑らかに動作する', () => {
    const game = new TetrisGame();
    const startTime = performance.now();
    
    // 1秒間のフレーム数をカウント
    let frameCount = 0;
    const frameCounter = () => {
      frameCount++;
      if (performance.now() - startTime < 1000) {
        requestAnimationFrame(frameCounter);
      }
    };
    
    requestAnimationFrame(frameCounter);
    
    setTimeout(() => {
      expect(frameCount).toBeGreaterThanOrEqual(58); // 60FPS ±2フレーム
    }, 1000);
  });
});
```

### テストケース4: ゲーム統合UI
```typescript
describe('Game Score Manager', () => {
  test('スコアが正しく記録される', () => {
    const scoreManager = new GameScoreManager();
    
    scoreManager.saveScore('reversi', 1250);
    scoreManager.saveScore('tetris', 3500);
    
    const reversiScores = scoreManager.getScores('reversi');
    const tetrisScores = scoreManager.getScores('tetris');
    
    expect(reversiScores).toContain(1250);
    expect(tetrisScores).toContain(3500);
  });

  test('ハイスコアが正しく取得される', () => {
    const scoreManager = new GameScoreManager();
    scoreManager.saveScore('tetris', 1000);
    scoreManager.saveScore('tetris', 3000);
    scoreManager.saveScore('tetris', 2000);
    
    const highScore = scoreManager.getHighScore('tetris');
    
    expect(highScore).toBe(3000);
  });
});

describe('Game Navigation', () => {
  test('ゲーム間を切り替えできる', () => {
    const { getByText, getByTestId } = render(<GameSection />);
    
    fireEvent.click(getByText('リバーシ'));
    expect(getByTestId('reversi-game')).toBeVisible();
    
    fireEvent.click(getByText('テトリス'));
    expect(getByTestId('tetris-game')).toBeVisible();
  });
});
```

### テストケース5: レスポンシブデザイン
```typescript
describe('Responsive Design', () => {
  test('モバイル画面でレイアウトが適切に調整される', () => {
    Object.defineProperty(window, 'innerWidth', {
      writable: true,
      configurable: true,
      value: 375, // iPhone SE サイズ
    });
    
    const { container } = render(<App />);
    
    expect(container.querySelector('.mobile-layout')).toBeInTheDocument();
    expect(container.querySelector('.desktop-layout')).not.toBeInTheDocument();
  });

  test('タブレット画面で中間レイアウトが表示される', () => {
    Object.defineProperty(window, 'innerWidth', {
      writable: true,
      configurable: true,
      value: 768, // iPad サイズ
    });
    
    const { container } = render(<App />);
    
    expect(container.querySelector('.tablet-layout')).toBeInTheDocument();
  });
});
```

## 🟢 Green Phase: 最小実装計画
1. 仮実装（ハードコーディング）
2. 明白な実装
3. 三角測量（複数テストケース）

## 🔵 Refactor Phase: 改善計画
1. 重複コード排除
2. 意図明確化
3. パフォーマンス最適化
4. 設計改善