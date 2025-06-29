# TDD Test Plan

## 🔴 Red Phase: 失敗するテストケース

### テストケース1: 基本TODO機能
```typescript
describe('TodoManager', () => {
  test('should add new task', () => {
    // Arrange: テストデータ準備
    const todoManager = new TodoManager();
    const taskContent = 'Test task';
    
    // Act: 実行
    const result = todoManager.addTask(taskContent);
    
    // Assert: 検証
    expect(result.id).toBeDefined();
    expect(result.content).toBe(taskContent);
    expect(result.completed).toBe(false);
  });

  test('should delete task', () => {
    const todoManager = new TodoManager();
    const task = todoManager.addTask('Test task');
    
    const result = todoManager.deleteTask(task.id);
    
    expect(result).toBe(true);
    expect(todoManager.getTasks()).toHaveLength(0);
  });

  test('should complete task', () => {
    const todoManager = new TodoManager();
    const task = todoManager.addTask('Test task');
    
    todoManager.completeTask(task.id);
    
    expect(todoManager.getTask(task.id).completed).toBe(true);
  });
});
```

### テストケース2: ドラッグ&ドロップ機能
```typescript
describe('DragDropManager', () => {
  test('should reorder tasks on drag and drop', () => {
    const dragDropManager = new DragDropManager();
    const tasks = [
      { id: '1', content: 'Task 1' },
      { id: '2', content: 'Task 2' },
      { id: '3', content: 'Task 3' }
    ];
    
    const result = dragDropManager.moveTask(tasks, 0, 2);
    
    expect(result[0].id).toBe('2');
    expect(result[1].id).toBe('3');
    expect(result[2].id).toBe('1');
  });
});
```

### テストケース3: 音声認識基盤
```typescript
describe('SpeechRecognition', () => {
  test('should initialize speech recognition', () => {
    const speechManager = new SpeechManager();
    
    const result = speechManager.initialize();
    
    expect(result).toBe(true);
    expect(speechManager.isAvailable()).toBe(true);
  });

  test('should handle microphone permission', () => {
    const speechManager = new SpeechManager();
    
    speechManager.requestPermission().then(granted => {
      expect(granted).toBe(true);
    });
  });
});
```

### テストケース4: 音声コマンド処理
```typescript
describe('VoiceCommandProcessor', () => {
  test('should parse add task command', () => {
    const processor = new VoiceCommandProcessor();
    const speechText = '新しいタスクを追加';
    
    const result = processor.parseCommand(speechText);
    
    expect(result.action).toBe('add');
    expect(result.isValid).toBe(true);
  });

  test('should process delete command', () => {
    const processor = new VoiceCommandProcessor();
    const speechText = 'タスクを削除';
    
    const result = processor.parseCommand(speechText);
    
    expect(result.action).toBe('delete');
    expect(result.isValid).toBe(true);
  });
});
```

### テストケース5: 音声ファイルテスト
```typescript
describe('Audio File Tests', () => {
  test('should process add task audio file', async () => {
    const audioProcessor = new AudioProcessor();
    const audioFile = 'test-assets/add_task_test.wav';
    
    const result = await audioProcessor.processAudioFile(audioFile);
    
    expect(result.transcription).toContain('追加');
    expect(result.command).toBe('add');
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