export interface SpeechConfig {
  language?: string;
  continuous?: boolean;
  interimResults?: boolean;
  maxAlternatives?: number;
}

export interface SpeechResult {
  transcript: string;
  confidence: number;
  isFinal: boolean;
}

export type SpeechResultCallback = (result: SpeechResult) => void;
export type SpeechErrorCallback = (error: string, details?: string) => void;

/**
 * 音声認識を管理するクラス
 * Web Speech APIのラッパーとして機能し、ブラウザ間の互換性とエラーハンドリングを提供
 */
export class SpeechManager {
  private recognition: any = null;
  private isListeningState = false;
  private onErrorHandler: SpeechErrorCallback | null = null;
  private onResultHandler: SpeechResultCallback | null = null;
  private config: Required<SpeechConfig>;

  constructor(config: SpeechConfig = {}) {
    this.config = {
      language: 'ja-JP',
      continuous: false,
      interimResults: false,
      maxAlternatives: 1,
      ...config
    };
  }

  /**
   * 音声認識を初期化します
   * @returns 初期化が成功したかどうか
   */
  initialize(): boolean {
    const SpeechRecognitionConstructor = this.getSpeechRecognitionConstructor();

    if (!SpeechRecognitionConstructor) {
      console.warn('Speech Recognition is not supported in this browser');
      return false;
    }

    try {
      this.recognition = new SpeechRecognitionConstructor();
      this.setupRecognition();
      return true;
    } catch (error) {
      console.error('Failed to initialize speech recognition:', error);
      return false;
    }
  }

  /**
   * 音声認識が利用可能かどうかを確認します
   * @returns 利用可能かどうか
   */
  isAvailable(): boolean {
    return this.recognition !== null;
  }

  /**
   * マイクへのアクセス許可を要求します
   * @returns 許可されたかどうか
   */
  async requestPermission(): Promise<boolean> {
    try {
      if (!navigator.mediaDevices?.getUserMedia) {
        return false;
      }

      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      // 許可確認後、ストリームを停止
      stream.getTracks().forEach(track => track.stop());
      return true;
    } catch (error) {
      console.warn('Microphone permission denied:', error);
      return false;
    }
  }

  /**
   * 音声認識を開始します
   * @param onResult 認識結果のコールバック
   */
  startListening(onResult: SpeechResultCallback): void {
    if (!this.recognition || this.isListeningState) {
      return;
    }

    this.onResultHandler = onResult;
    
    try {
      this.recognition.start();
      this.isListeningState = true;
    } catch (error) {
      console.error('Failed to start listening:', error);
      this.handleError('start-failed', error instanceof Error ? error.message : 'Unknown error');
    }
  }

  /**
   * 音声認識を停止します
   */
  stopListening(): void {
    if (this.recognition && this.isListeningState) {
      try {
        this.recognition.stop();
      } catch (error) {
        console.error('Failed to stop listening:', error);
      }
      this.isListeningState = false;
    }
  }

  /**
   * 現在の音声認識状態を取得します
   * @returns 音声認識中かどうか
   */
  isListening(): boolean {
    return this.isListeningState;
  }

  /**
   * エラーハンドラを設定します
   * @param handler エラーハンドラ
   */
  setErrorHandler(handler: SpeechErrorCallback): void {
    this.onErrorHandler = handler;
  }

  /**
   * 認識言語を設定します
   * @param lang 言語コード (例: 'ja-JP', 'en-US')
   */
  setLanguage(lang: string): void {
    this.config.language = lang;
    if (this.recognition) {
      this.recognition.lang = lang;
    }
  }

  /**
   * 連続認識モードを設定します
   * @param continuous 連続認識するかどうか
   */
  setContinuous(continuous: boolean): void {
    this.config.continuous = continuous;
    if (this.recognition) {
      this.recognition.continuous = continuous;
    }
  }

  /**
   * 中間結果の取得を設定します
   * @param interimResults 中間結果を取得するかどうか
   */
  setInterimResults(interimResults: boolean): void {
    this.config.interimResults = interimResults;
    if (this.recognition) {
      this.recognition.interimResults = interimResults;
    }
  }

  /**
   * 設定を更新します
   * @param newConfig 新しい設定
   */
  updateConfig(newConfig: Partial<SpeechConfig>): void {
    this.config = { ...this.config, ...newConfig };
    if (this.recognition) {
      this.applyConfig();
    }
  }

  /**
   * リソースをクリーンアップします
   */
  cleanup(): void {
    if (this.recognition) {
      if (this.isListeningState) {
        this.recognition.stop();
      }
      this.recognition = null;
      this.isListeningState = false;
      this.onResultHandler = null;
      this.onErrorHandler = null;
    }
  }

  private getSpeechRecognitionConstructor(): any {
    return (window as any).SpeechRecognition || 
           (window as any).webkitSpeechRecognition ||
           null;
  }

  private setupRecognition(): void {
    if (!this.recognition) return;

    this.applyConfig();

    this.recognition.onresult = (event: any) => {
      this.handleRecognitionResult(event);
    };

    this.recognition.onerror = (event: any) => {
      this.handleError(event.error, event.message);
    };

    this.recognition.onend = () => {
      this.isListeningState = false;
    };

    this.recognition.onstart = () => {
      // Optional: handle start event
    };
  }

  private applyConfig(): void {
    if (!this.recognition) return;

    this.recognition.lang = this.config.language;
    this.recognition.continuous = this.config.continuous;
    this.recognition.interimResults = this.config.interimResults;
    this.recognition.maxAlternatives = this.config.maxAlternatives;
  }

  private handleRecognitionResult(event: any): void {
    if (!this.onResultHandler || !event.results) return;

    for (let i = event.resultIndex; i < event.results.length; i++) {
      const result = event.results[i];
      if (result && result.length > 0) {
        const alternative = result[0];
        const speechResult: SpeechResult = {
          transcript: alternative.transcript,
          confidence: alternative.confidence || 0,
          isFinal: result.isFinal
        };
        
        this.onResultHandler(speechResult);
      }
    }
  }

  private handleError(error: string, details?: string): void {
    console.error('Speech recognition error:', error, details);
    
    if (this.onErrorHandler) {
      this.onErrorHandler(error, details);
    }
    
    // 一部のエラーは自動的にリスニング状態をfalseにする
    if (['no-speech', 'audio-capture', 'not-allowed'].includes(error)) {
      this.isListeningState = false;
    }
  }
}