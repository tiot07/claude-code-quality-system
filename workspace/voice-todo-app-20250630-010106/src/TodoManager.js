/**
 * TODOタスクの管理を行うクラス
 * CRUD操作（作成・取得・更新・削除）を提供
 */
export class TodoManager {
  constructor() {
    this.tasks = [];
    this.nextId = 1;
  }

  /**
   * 新しいタスクを追加
   * @param {string} text - タスクのテキスト
   * @returns {Object} 作成されたタスクオブジェクト
   * @throws {Error} テキストが空の場合
   */
  addTask(text) {
    this._validateTaskText(text);

    const task = this._createTask(text.trim());
    this.tasks.push(task);
    return task;
  }

  /**
   * 全タスクのコピーを取得
   * @returns {Array} タスクの配列
   */
  getTasks() {
    return [...this.tasks];
  }

  /**
   * IDでタスクを取得
   * @param {number} id - タスクID
   * @returns {Object|undefined} 該当するタスクまたはundefined
   */
  getTask(id) {
    return this.tasks.find(task => task.id === id);
  }

  /**
   * タスクを削除
   * @param {number} id - 削除するタスクのID
   * @returns {boolean} 削除成功時true、失敗時false
   */
  deleteTask(id) {
    const index = this._findTaskIndex(id);
    if (index === -1) {
      return false;
    }
    this.tasks.splice(index, 1);
    return true;
  }

  /**
   * タスクの完了状態を切り替え
   * @param {number} id - タスクID
   * @returns {boolean} 切り替え成功時true、失敗時false
   */
  toggleTask(id) {
    const task = this.getTask(id);
    if (!task) {
      return false;
    }
    task.completed = !task.completed;
    return true;
  }

  /**
   * タスクテキストを更新
   * @param {number} id - タスクID
   * @param {string} newText - 新しいテキスト
   * @returns {boolean} 更新成功時true、失敗時false
   */
  updateTask(id, newText) {
    const task = this.getTask(id);
    if (!task) {
      return false;
    }
    task.text = newText;
    return true;
  }

  // Private methods
  _validateTaskText(text) {
    if (!text || text.trim() === '') {
      throw new Error('タスクテキストは必須です');
    }
  }

  _createTask(text) {
    return {
      id: this.nextId++,
      text,
      completed: false,
      createdAt: new Date()
    };
  }

  _findTaskIndex(id) {
    return this.tasks.findIndex(task => task.id === id);
  }
}