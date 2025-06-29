import { DragDropManager } from '../src/DragDropManager';
import { Task } from '../src/types';

describe('DragDropManager', () => {
  let dragDropManager: DragDropManager;
  let mockTasks: Task[];

  beforeEach(() => {
    dragDropManager = new DragDropManager();
    mockTasks = [
      {
        id: '1',
        content: 'Task 1',
        completed: false,
        createdAt: new Date('2023-01-01')
      },
      {
        id: '2',
        content: 'Task 2',
        completed: false,
        createdAt: new Date('2023-01-02')
      },
      {
        id: '3',
        content: 'Task 3',
        completed: false,
        createdAt: new Date('2023-01-03')
      }
    ];
  });

  describe('moveTask', () => {
    test('should move task from first to last position', () => {
      const result = dragDropManager.moveTask(mockTasks, 0, 2);
      
      expect(result[0].id).toBe('2');
      expect(result[1].id).toBe('3');
      expect(result[2].id).toBe('1');
    });

    test('should move task from last to first position', () => {
      const result = dragDropManager.moveTask(mockTasks, 2, 0);
      
      expect(result[0].id).toBe('3');
      expect(result[1].id).toBe('1');
      expect(result[2].id).toBe('2');
    });

    test('should move task to middle position', () => {
      const result = dragDropManager.moveTask(mockTasks, 0, 1);
      
      expect(result[0].id).toBe('2');
      expect(result[1].id).toBe('1');
      expect(result[2].id).toBe('3');
    });

    test('should not change order when moving to same position', () => {
      const result = dragDropManager.moveTask(mockTasks, 1, 1);
      
      expect(result[0].id).toBe('1');
      expect(result[1].id).toBe('2');
      expect(result[2].id).toBe('3');
    });

    test('should handle invalid fromIndex gracefully', () => {
      expect(() => {
        dragDropManager.moveTask(mockTasks, -1, 1);
      }).toThrow('Invalid fromIndex');
      
      expect(() => {
        dragDropManager.moveTask(mockTasks, 5, 1);
      }).toThrow('Invalid fromIndex');
    });

    test('should handle invalid toIndex gracefully', () => {
      expect(() => {
        dragDropManager.moveTask(mockTasks, 0, -1);
      }).toThrow('Invalid toIndex');
      
      expect(() => {
        dragDropManager.moveTask(mockTasks, 0, 5);
      }).toThrow('Invalid toIndex');
    });

    test('should not mutate original array', () => {
      const originalTasks = [...mockTasks];
      const result = dragDropManager.moveTask(mockTasks, 0, 2);
      
      expect(mockTasks).toEqual(originalTasks);
      expect(result).not.toBe(mockTasks);
    });
  });

  describe('getDropPosition', () => {
    test('should calculate correct drop position for mouse coordinates above middle', () => {
      const mockElement = {
        getBoundingClientRect: () => ({
          top: 100,
          height: 60
        })
      } as HTMLElement;

      const position = dragDropManager.getDropPosition(mockElement, 120); // 120 < 130 (middle)
      
      expect(position).toBe(0); // Above middle
    });

    test('should return correct position for bottom half', () => {
      const mockElement = {
        getBoundingClientRect: () => ({
          top: 100,
          height: 60
        })
      } as HTMLElement;

      const position = dragDropManager.getDropPosition(mockElement, 150);
      
      expect(position).toBe(1); // Below middle
    });
  });

  describe('isValidDrop', () => {
    test('should return true for valid drop operation', () => {
      const result = dragDropManager.isValidDrop(0, 2, mockTasks.length);
      
      expect(result).toBe(true);
    });

    test('should return false for same position drop', () => {
      const result = dragDropManager.isValidDrop(1, 1, mockTasks.length);
      
      expect(result).toBe(false);
    });

    test('should return false for invalid indices', () => {
      expect(dragDropManager.isValidDrop(-1, 1, mockTasks.length)).toBe(false);
      expect(dragDropManager.isValidDrop(0, -1, mockTasks.length)).toBe(false);
      expect(dragDropManager.isValidDrop(5, 1, mockTasks.length)).toBe(false);
      expect(dragDropManager.isValidDrop(0, 5, mockTasks.length)).toBe(false);
    });
  });

  describe('getDragPreview', () => {
    test('should generate drag preview element', () => {
      const task = mockTasks[0];
      const preview = dragDropManager.getDragPreview(task);
      
      expect(preview).toBeInstanceOf(HTMLElement);
      expect(preview.textContent).toContain(task.content);
      expect(preview.classList.contains('drag-preview')).toBe(true);
    });

    test('should handle completed tasks differently', () => {
      const completedTask = { ...mockTasks[0], completed: true };
      const preview = dragDropManager.getDragPreview(completedTask);
      
      expect(preview.classList.contains('completed')).toBe(true);
    });
  });
});