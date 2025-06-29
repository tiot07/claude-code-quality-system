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