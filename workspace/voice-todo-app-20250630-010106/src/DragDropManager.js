import Sortable from 'sortablejs';

export class DragDropManager {
  constructor() {
    this.sortableInstance = null;
  }

  /**
   * タスクの順序を変更する
   * @param {Array} tasks - タスクの配列
   * @param {number} fromIndex - 移動元のインデックス
   * @param {number} toIndex - 移動先のインデックス
   * @returns {Array} 並び替え後のタスクの配列
   */
  reorderTasks(tasks, fromIndex, toIndex) {
    if (tasks.length === 0) {
      return [];
    }

    if (fromIndex < 0 || fromIndex >= tasks.length || 
        toIndex < 0 || toIndex >= tasks.length) {
      throw new Error('不正なインデックスです');
    }

    if (fromIndex === toIndex) {
      return [...tasks];
    }

    const result = [...tasks];
    const [movedTask] = result.splice(fromIndex, 1);
    result.splice(toIndex, 0, movedTask);
    
    return result;
  }

  /**
   * SortableJS設定を取得
   * @returns {Object} SortableJS設定オブジェクト
   */
  getSortableConfig() {
    return {
      animation: 150,
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      onEnd: (evt) => {
        // デフォルトの処理（オーバーライド可能）
      }
    };
  }

  /**
   * ドラッグ終了イベントを処理
   * @param {Object} event - ドラッグイベントオブジェクト
   * @param {Array} tasks - 元のタスク配列
   * @param {Function} callback - 並び替え後に呼ばれるコールバック
   */
  handleDragEnd(event, tasks, callback) {
    const { oldIndex, newIndex } = event;
    
    if (oldIndex !== newIndex) {
      const reorderedTasks = this.reorderTasks(tasks, oldIndex, newIndex);
      callback(reorderedTasks);
    }
  }

  /**
   * DOM要素にSortableを初期化
   * @param {HTMLElement} element - ソート対象のDOM要素
   * @param {Array} tasks - タスク配列
   * @param {Function} onReorder - 並び替え時のコールバック
   * @returns {Object} SortableJSインスタンス
   */
  initializeSortable(element, tasks, onReorder) {
    if (this.sortableInstance) {
      this.sortableInstance.destroy();
    }

    const config = {
      ...this.getSortableConfig(),
      onEnd: (evt) => {
        this.handleDragEnd(evt, tasks, onReorder);
      }
    };

    this.sortableInstance = Sortable.create(element, config);
    return this.sortableInstance;
  }

  /**
   * Sortableインスタンスを破棄
   */
  destroy() {
    if (this.sortableInstance) {
      this.sortableInstance.destroy();
      this.sortableInstance = null;
    }
  }
}