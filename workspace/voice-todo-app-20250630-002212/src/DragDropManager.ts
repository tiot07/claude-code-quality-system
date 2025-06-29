import { Task } from './types';

export interface DragDropOptions {
  allowCompleted?: boolean;
  dragThreshold?: number;
  animationDuration?: number;
}

export interface DropZoneInfo {
  index: number;
  position: 'before' | 'after';
  element: HTMLElement;
}

export class DragDropManager {
  private options: Required<DragDropOptions>;

  constructor(options: DragDropOptions = {}) {
    this.options = {
      allowCompleted: true,
      dragThreshold: 5,
      animationDuration: 200,
      ...options
    };
  }

  /**
   * 配列内の要素を移動します
   * @param tasks 元の配列
   * @param fromIndex 移動元のインデックス
   * @param toIndex 移動先のインデックス
   * @returns 新しい配列
   */
  moveTask(tasks: Task[], fromIndex: number, toIndex: number): Task[] {
    this.validateIndex(fromIndex, tasks.length, 'fromIndex');
    this.validateIndex(toIndex, tasks.length, 'toIndex');
    
    const result = [...tasks];
    const [movedTask] = result.splice(fromIndex, 1);
    result.splice(toIndex, 0, movedTask);
    
    return result;
  }

  /**
   * マウス座標から要素内での相対位置を計算します
   * @param element 対象要素
   * @param mouseY マウスのY座標
   * @returns 0（上半分）または1（下半分）
   */
  getDropPosition(element: HTMLElement, mouseY: number): number {
    const rect = element.getBoundingClientRect();
    const middle = rect.top + rect.height / 2;
    
    return mouseY < middle ? 0 : 1;
  }

  /**
   * ドロップ可能かどうかを判定します
   * @param fromIndex 移動元インデックス
   * @param toIndex 移動先インデックス  
   * @param arrayLength 配列の長さ
   * @returns ドロップ可能かどうか
   */
  isValidDrop(fromIndex: number, toIndex: number, arrayLength: number): boolean {
    return this.isValidIndex(fromIndex, arrayLength) &&
           this.isValidIndex(toIndex, arrayLength) &&
           fromIndex !== toIndex;
  }

  /**
   * ドラッグ中に表示するプレビュー要素を生成します
   * @param task ドラッグ対象のタスク
   * @returns プレビュー要素
   */
  getDragPreview(task: Task): HTMLElement {
    const preview = document.createElement('div');
    preview.className = 'drag-preview';
    preview.textContent = task.content;
    
    if (task.completed) {
      preview.classList.add('completed');
    }
    
    this.applyPreviewStyles(preview);
    
    return preview;
  }

  /**
   * ドラッグ可能かどうかを判定します
   * @param task 対象タスク
   * @returns ドラッグ可能かどうか
   */
  isDraggable(task: Task): boolean {
    return this.options.allowCompleted || !task.completed;
  }

  /**
   * ドロップゾーンの情報を取得します
   * @param element 要素
   * @param mouseY マウスY座標
   * @param index 要素のインデックス
   * @returns ドロップゾーン情報
   */
  getDropZoneInfo(element: HTMLElement, mouseY: number, index: number): DropZoneInfo {
    const position = this.getDropPosition(element, mouseY);
    return {
      index,
      position: position === 0 ? 'before' : 'after',
      element
    };
  }

  private validateIndex(index: number, arrayLength: number, paramName: string): void {
    if (!this.isValidIndex(index, arrayLength)) {
      throw new Error(`Invalid ${paramName}`);
    }
  }

  private isValidIndex(index: number, arrayLength: number): boolean {
    return index >= 0 && index < arrayLength;
  }

  private applyPreviewStyles(element: HTMLElement): void {
    element.style.cssText = `
      position: fixed;
      pointer-events: none;
      z-index: 1000;
      opacity: 0.8;
      transform: rotate(5deg);
      background: white;
      border: 1px solid #ccc;
      border-radius: 4px;
      padding: 8px;
      box-shadow: 0 4px 8px rgba(0,0,0,0.2);
    `;
  }
}