// SortableJSモック
jest.mock('sortablejs', () => {
  return {
    __esModule: true,
    default: {
      create: jest.fn((element, options) => ({
        destroy: jest.fn(),
        el: element,
        options: options
      }))
    }
  };
});

import { DragDropManager } from '../src/DragDropManager.js';

describe('DragDropManager', () => {
  let dragDropManager;
  let mockTasks;

  beforeEach(() => {
    dragDropManager = new DragDropManager();
    mockTasks = [
      { id: 1, text: "タスク1", completed: false },
      { id: 2, text: "タスク2", completed: true },
      { id: 3, text: "タスク3", completed: false }
    ];
  });

  test('タスクの順序を変更できる', () => {
    // 0番目のタスクを2番目に移動
    const reorderedTasks = dragDropManager.reorderTasks(mockTasks, 0, 2);
    
    expect(reorderedTasks[0].id).toBe(2);
    expect(reorderedTasks[1].id).toBe(3);
    expect(reorderedTasks[2].id).toBe(1);
  });

  test('タスクを最初の位置に移動できる', () => {
    // 2番目のタスクを0番目に移動
    const reorderedTasks = dragDropManager.reorderTasks(mockTasks, 2, 0);
    
    expect(reorderedTasks[0].id).toBe(3);
    expect(reorderedTasks[1].id).toBe(1);
    expect(reorderedTasks[2].id).toBe(2);
  });

  test('タスクを最後の位置に移動できる', () => {
    // 0番目のタスクを最後に移動
    const reorderedTasks = dragDropManager.reorderTasks(mockTasks, 0, 2);
    
    expect(reorderedTasks[2].id).toBe(1);
  });

  test('同じ位置への移動は元の配列と同じ', () => {
    const reorderedTasks = dragDropManager.reorderTasks(mockTasks, 1, 1);
    
    expect(reorderedTasks).toEqual(mockTasks);
  });

  test('不正なインデックスでエラーが発生する', () => {
    expect(() => {
      dragDropManager.reorderTasks(mockTasks, -1, 0);
    }).toThrow('不正なインデックスです');

    expect(() => {
      dragDropManager.reorderTasks(mockTasks, 0, 5);
    }).toThrow('不正なインデックスです');
  });

  test('空の配列でも動作する', () => {
    const result = dragDropManager.reorderTasks([], 0, 0);
    expect(result).toEqual([]);
  });

  test('SortableJS設定を取得できる', () => {
    const config = dragDropManager.getSortableConfig();
    
    expect(config).toHaveProperty('animation');
    expect(config).toHaveProperty('ghostClass');
    expect(config).toHaveProperty('onEnd');
    expect(typeof config.onEnd).toBe('function');
  });

  test('ドラッグ開始イベントを処理できる', () => {
    const mockEvent = {
      oldIndex: 0,
      newIndex: 2
    };

    const originalTasks = [...mockTasks];
    const callback = jest.fn();
    
    dragDropManager.handleDragEnd(mockEvent, originalTasks, callback);
    
    expect(callback).toHaveBeenCalledWith(
      expect.arrayContaining([
        expect.objectContaining({ id: 2 }),
        expect.objectContaining({ id: 3 }),
        expect.objectContaining({ id: 1 })
      ])
    );
  });

  test('DOM要素にSortableを適用できる', () => {
    // DOM要素のモック
    document.body.innerHTML = '<ul id="task-list"></ul>';
    const taskList = document.getElementById('task-list');
    
    const sortableInstance = dragDropManager.initializeSortable(
      taskList,
      mockTasks,
      jest.fn()
    );
    
    expect(sortableInstance).toBeDefined();
  });
});