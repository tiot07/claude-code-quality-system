import { Task, TodoStorage } from './types';
import { LocalStorageManager } from './LocalStorage';

export class TodoManager {
  private tasks: Task[] = [];
  private storage: TodoStorage;

  constructor(storage?: TodoStorage) {
    this.storage = storage || new LocalStorageManager();
    this.loadTasks();
  }

  private loadTasks(): void {
    this.tasks = this.storage.getTasks();
  }

  private saveTasks(): void {
    this.storage.saveTasks(this.tasks);
  }

  private generateId(): string {
    return `task-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  addTask(content: string): Task {
    if (!content.trim()) {
      throw new Error('Task content cannot be empty');
    }

    const task: Task = {
      id: this.generateId(),
      content: content.trim(),
      completed: false,
      createdAt: new Date()
    };
    
    this.tasks.push(task);
    this.saveTasks();
    return task;
  }

  deleteTask(id: string): boolean {
    const index = this.tasks.findIndex(task => task.id === id);
    if (index === -1) {
      return false;
    }
    
    this.tasks.splice(index, 1);
    this.saveTasks();
    return true;
  }

  completeTask(id: string): boolean {
    const task = this.tasks.find(task => task.id === id);
    if (!task) {
      return false;
    }
    
    task.completed = true;
    task.updatedAt = new Date();
    this.saveTasks();
    return true;
  }

  editTask(id: string, newContent: string): boolean {
    if (!newContent.trim()) {
      throw new Error('Task content cannot be empty');
    }

    const task = this.tasks.find(task => task.id === id);
    if (!task) {
      return false;
    }
    
    task.content = newContent.trim();
    task.updatedAt = new Date();
    this.saveTasks();
    return true;
  }

  getTask(id: string): Task | undefined {
    return this.tasks.find(task => task.id === id);
  }

  getTasks(): Task[] {
    return [...this.tasks];
  }

  getCompletedTasks(): Task[] {
    return this.tasks.filter(task => task.completed);
  }

  getPendingTasks(): Task[] {
    return this.tasks.filter(task => !task.completed);
  }

  clearCompleted(): number {
    const completedCount = this.getCompletedTasks().length;
    this.tasks = this.tasks.filter(task => !task.completed);
    this.saveTasks();
    return completedCount;
  }
}