import { TodoManager } from '../src/TodoManager.js';

describe('TodoManager', () => {
  let todoManager;

  beforeEach(() => {
    todoManager = new TodoManager();
  });

  test('新しいタスクを追加できる', () => {
    // Arrange: テストデータ準備
    const taskText = "買い物をする";
    
    // Act: 実行
    const task = todoManager.addTask(taskText);
    
    // Assert: 検証
    expect(task.id).toBeDefined();
    expect(task.text).toBe(taskText);
    expect(task.completed).toBe(false);
    expect(task.createdAt).toBeInstanceOf(Date);
  });

  test('タスクリストを取得できる', () => {
    todoManager.addTask("タスク1");
    todoManager.addTask("タスク2");
    
    const tasks = todoManager.getTasks();
    
    expect(tasks).toHaveLength(2);
    expect(tasks[0].text).toBe("タスク1");
    expect(tasks[1].text).toBe("タスク2");
  });

  test('IDでタスクを取得できる', () => {
    const task = todoManager.addTask("テストタスク");
    
    const foundTask = todoManager.getTask(task.id);
    
    expect(foundTask).toBeDefined();
    expect(foundTask.id).toBe(task.id);
    expect(foundTask.text).toBe("テストタスク");
  });

  test('タスクを削除できる', () => {
    const task = todoManager.addTask("テストタスク");
    
    const result = todoManager.deleteTask(task.id);
    
    expect(result).toBe(true);
    expect(todoManager.getTasks()).toHaveLength(0);
  });

  test('存在しないタスクの削除は失敗する', () => {
    const result = todoManager.deleteTask('nonexistent-id');
    
    expect(result).toBe(false);
  });

  test('タスクの完了状態を切り替えできる', () => {
    const task = todoManager.addTask("テストタスク");
    
    const result = todoManager.toggleTask(task.id);
    
    expect(result).toBe(true);
    expect(todoManager.getTask(task.id).completed).toBe(true);
  });

  test('完了済みタスクを未完了に戻せる', () => {
    const task = todoManager.addTask("テストタスク");
    todoManager.toggleTask(task.id); // 完了にする
    
    todoManager.toggleTask(task.id); // 未完了に戻す
    
    expect(todoManager.getTask(task.id).completed).toBe(false);
  });

  test('存在しないタスクの完了状態切り替えは失敗する', () => {
    const result = todoManager.toggleTask('nonexistent-id');
    
    expect(result).toBe(false);
  });

  test('タスクテキストを編集できる', () => {
    const task = todoManager.addTask("元のテキスト");
    
    const result = todoManager.updateTask(task.id, "新しいテキスト");
    
    expect(result).toBe(true);
    expect(todoManager.getTask(task.id).text).toBe("新しいテキスト");
  });

  test('空のテキストでタスクを追加すると例外が発生する', () => {
    expect(() => {
      todoManager.addTask("");
    }).toThrow("タスクテキストは必須です");
    
    expect(() => {
      todoManager.addTask(null);
    }).toThrow("タスクテキストは必須です");
  });
});