import { SpeechManager } from '../src/SpeechManager';

// Mock Web Speech API
const mockSpeechRecognition = {
  continuous: false,
  interimResults: false,
  lang: 'ja-JP',
  start: jest.fn(),
  stop: jest.fn(),
  abort: jest.fn(),
  addEventListener: jest.fn(),
  removeEventListener: jest.fn(),
  onresult: null as any,
  onerror: null as any,
  onstart: null as any,
  onend: null as any
};

const mockMediaDevices = {
  getUserMedia: jest.fn()
};

// Global mocks
(global as any).SpeechRecognition = jest.fn(() => mockSpeechRecognition);
(global as any).webkitSpeechRecognition = jest.fn(() => mockSpeechRecognition);

Object.defineProperty(global, 'navigator', {
  value: {
    mediaDevices: mockMediaDevices
  },
  writable: true
});

describe('SpeechManager', () => {
  let speechManager: SpeechManager;

  beforeEach(() => {
    jest.clearAllMocks();
    speechManager = new SpeechManager();
  });

  describe('initialization', () => {
    test('should initialize speech recognition', () => {
      const result = speechManager.initialize();
      
      expect(result).toBe(true);
      expect(speechManager.isAvailable()).toBe(true);
    });

    test('should handle unavailable speech recognition', () => {
      // Temporarily remove speech recognition
      const originalSpeechRecognition = (global as any).SpeechRecognition;
      const originalWebkitSpeechRecognition = (global as any).webkitSpeechRecognition;
      
      delete (global as any).SpeechRecognition;
      delete (global as any).webkitSpeechRecognition;
      
      const manager = new SpeechManager();
      const result = manager.initialize();
      
      expect(result).toBe(false);
      expect(manager.isAvailable()).toBe(false);
      
      // Restore
      (global as any).SpeechRecognition = originalSpeechRecognition;
      (global as any).webkitSpeechRecognition = originalWebkitSpeechRecognition;
    });
  });

  describe('permission handling', () => {
    test('should request microphone permission', async () => {
      mockMediaDevices.getUserMedia.mockResolvedValue({
        getTracks: () => [{ stop: jest.fn() }]
      });
      
      const granted = await speechManager.requestPermission();
      
      expect(granted).toBe(true);
      expect(mockMediaDevices.getUserMedia).toHaveBeenCalledWith({ audio: true });
    });

    test('should handle permission denied', async () => {
      mockMediaDevices.getUserMedia.mockRejectedValue(new Error('Permission denied'));
      
      const granted = await speechManager.requestPermission();
      
      expect(granted).toBe(false);
    });
  });

  describe('speech recognition control', () => {
    beforeEach(() => {
      speechManager.initialize();
    });

    test('should start listening', () => {
      const onResult = jest.fn();
      
      speechManager.startListening(onResult);
      
      expect(mockSpeechRecognition.start).toHaveBeenCalled();
      expect(speechManager.isListening()).toBe(true);
    });

    test('should stop listening', () => {
      speechManager.startListening(jest.fn());
      speechManager.stopListening();
      
      expect(mockSpeechRecognition.stop).toHaveBeenCalled();
      expect(speechManager.isListening()).toBe(false);
    });

    test('should handle recognition results', () => {
      const onResult = jest.fn();
      speechManager.startListening(onResult);
      
      // Simulate recognition result
      const mockEvent = {
        resultIndex: 0,
        results: [{
          0: { transcript: 'test transcript', confidence: 0.9 },
          isFinal: true,
          length: 1
        }]
      };
      
      mockSpeechRecognition.onresult?.(mockEvent);
      
      expect(onResult).toHaveBeenCalledWith({
        transcript: 'test transcript',
        confidence: 0.9,
        isFinal: true
      });
    });

    test('should handle recognition errors', () => {
      const onError = jest.fn();
      speechManager.setErrorHandler(onError);
      speechManager.startListening(jest.fn());
      
      const mockError = { error: 'network', message: 'Network error' };
      mockSpeechRecognition.onerror?.(mockError);
      
      expect(onError).toHaveBeenCalledWith('network', 'Network error');
    });

    test('should not start if already listening', () => {
      speechManager.startListening(jest.fn());
      speechManager.startListening(jest.fn());
      
      expect(mockSpeechRecognition.start).toHaveBeenCalledTimes(1);
    });
  });

  describe('configuration', () => {
    test('should set language', () => {
      speechManager.initialize();
      speechManager.setLanguage('en-US');
      
      expect(mockSpeechRecognition.lang).toBe('en-US');
    });

    test('should set continuous mode', () => {
      speechManager.initialize();
      speechManager.setContinuous(true);
      
      expect(mockSpeechRecognition.continuous).toBe(true);
    });

    test('should set interim results', () => {
      speechManager.initialize();
      speechManager.setInterimResults(true);
      
      expect(mockSpeechRecognition.interimResults).toBe(true);
    });
  });

  describe('state management', () => {
    test('should track listening state correctly', () => {
      expect(speechManager.isListening()).toBe(false);
      
      speechManager.initialize();
      speechManager.startListening(jest.fn());
      expect(speechManager.isListening()).toBe(true);
      
      speechManager.stopListening();
      expect(speechManager.isListening()).toBe(false);
    });

    test('should handle speech end event', () => {
      speechManager.initialize();
      speechManager.startListening(jest.fn());
      
      // Simulate speech end
      mockSpeechRecognition.onend?.();
      
      expect(speechManager.isListening()).toBe(false);
    });
  });

  describe('cleanup', () => {
    test('should cleanup resources', () => {
      speechManager.initialize();
      speechManager.startListening(jest.fn());
      
      speechManager.cleanup();
      
      expect(mockSpeechRecognition.stop).toHaveBeenCalled();
      expect(speechManager.isListening()).toBe(false);
    });
  });
});