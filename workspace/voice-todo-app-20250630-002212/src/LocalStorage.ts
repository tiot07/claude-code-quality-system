import { Task, TodoStorage } from './types';

export class LocalStorageManager implements TodoStorage {
  private readonly storageKey = 'voice-todo-app-tasks';

  getTasks(): Task[] {
    try {
      const tasksJson = localStorage.getItem(this.storageKey);
      if (!tasksJson) {
        return [];
      }
      
      const tasks = JSON.parse(tasksJson);
      return tasks.map((task: any) => ({
        ...task,
        createdAt: new Date(task.createdAt),
        updatedAt: task.updatedAt ? new Date(task.updatedAt) : undefined
      }));
    } catch (error) {
      console.error('Failed to load tasks from localStorage:', error);
      return [];
    }
  }

  saveTasks(tasks: Task[]): void {
    try {
      localStorage.setItem(this.storageKey, JSON.stringify(tasks));
    } catch (error) {
      console.error('Failed to save tasks to localStorage:', error);
    }
  }
}