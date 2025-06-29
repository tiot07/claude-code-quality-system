import { Task, TodoStorage } from '../src/types';

export class MockStorage implements TodoStorage {
  private tasks: Task[] = [];

  getTasks(): Task[] {
    return [...this.tasks];
  }

  saveTasks(tasks: Task[]): void {
    this.tasks = [...tasks];
  }

  clear(): void {
    this.tasks = [];
  }
}