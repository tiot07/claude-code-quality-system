import { TodoManager } from '../src/TodoManager';
import { Task, TodoStorage } from '../src/types';
import { MockStorage } from './MockStorage';

describe('TodoManager', () => {
  let todoManager: TodoManager;
  let mockStorage: MockStorage;

  beforeEach(() => {
    mockStorage = new MockStorage();
    todoManager = new TodoManager(mockStorage);
  });

  describe('addTask', () => {
    test('should add new task', () => {
      // Arrange: テストデータ準備
      const taskContent = 'Test task';
      
      // Act: 実行
      const result = todoManager.addTask(taskContent);
      
      // Assert: 検証
      expect(result.id).toBeDefined();
      expect(result.content).toBe(taskContent);
      expect(result.completed).toBe(false);
      expect(result.createdAt).toBeInstanceOf(Date);
    });

    test('should increment task count', () => {
      todoManager.addTask('Task 1');
      todoManager.addTask('Task 2');
      
      expect(todoManager.getTasks()).toHaveLength(2);
    });

    test('should generate unique IDs', () => {
      const task1 = todoManager.addTask('Task 1');
      const task2 = todoManager.addTask('Task 2');
      
      expect(task1.id).not.toBe(task2.id);
    });
  });

  describe('deleteTask', () => {
    test('should delete task', () => {
      const task = todoManager.addTask('Test task');
      
      const result = todoManager.deleteTask(task.id);
      
      expect(result).toBe(true);
      expect(todoManager.getTasks()).toHaveLength(0);
    });

    test('should return false for non-existent task', () => {
      const result = todoManager.deleteTask('non-existent-id');
      
      expect(result).toBe(false);
    });
  });

  describe('completeTask', () => {
    test('should complete task', () => {
      const task = todoManager.addTask('Test task');
      
      const result = todoManager.completeTask(task.id);
      
      expect(result).toBe(true);
      expect(todoManager.getTask(task.id)?.completed).toBe(true);
    });

    test('should return false for non-existent task', () => {
      const result = todoManager.completeTask('non-existent-id');
      
      expect(result).toBe(false);
    });
  });

  describe('getTask', () => {
    test('should return task by ID', () => {
      const task = todoManager.addTask('Test task');
      
      const result = todoManager.getTask(task.id);
      
      expect(result).toBeDefined();
      expect(result?.id).toBe(task.id);
    });

    test('should return undefined for non-existent task', () => {
      const result = todoManager.getTask('non-existent-id');
      
      expect(result).toBeUndefined();
    });
  });

  describe('getTasks', () => {
    test('should return empty array initially', () => {
      const result = todoManager.getTasks();
      
      expect(result).toEqual([]);
    });

    test('should return all tasks', () => {
      todoManager.addTask('Task 1');
      todoManager.addTask('Task 2');
      
      const result = todoManager.getTasks();
      
      expect(result).toHaveLength(2);
    });
  });
});