import { Logger } from '../utils/Logger';
import { textToSpeech } from '@kit.CoreSpeechKit';
import { systemDateTime } from '@kit.BasicServicesKit';

/**
 * TTS播放状态枚举
 */
export enum TTSState {
  IDLE = 'idle',
  INITIALIZING = 'initializing', 
  PLAYING = 'playing',
  PAUSED = 'paused',
  STOPPED = 'stopped',
  ERROR = 'error'
}

/**
 * TTS配置接口
 */
export interface TTSConfig {
  language?: string;    // 语言
  voice?: string;       // 声音类型
  rate?: number;        // 语速 (0.1 - 3.0)
  pitch?: number;       // 音调 (0.5 - 2.0) 
  volume?: number;      // 音量 (0.0 - 1.0)
}

/**
 * TTS事件回调接口
 */
export interface TTSCallbacks {
  onStart?: () => void;
  onComplete?: () => void;
  onError?: (error: Error) => void;
  onPause?: () => void;
  onResume?: () => void;
  onStop?: () => void;
}

/**
 * TTS服务状态接口
 */
export interface TTSServiceStatus {
  isReady: boolean;
  currentState: TTSState;
  hasActiveRequest: boolean;
  engineVersion?: string;
  config: TTSConfig;
}

/**
 * 文字转语音服务类 - 华为TTS API实现
 */
export class TTSService {
  private static instance: TTSService | null = null;
  private currentState: TTSState = TTSState.IDLE;
  private currentText: string = '';
  private callbacks: TTSCallbacks = {};
  private config: TTSConfig = {
    language: 'zh-CN',
    voice: 'zh-CN-XiaoxiaoNeural',
    rate: 1.0,
    pitch: 1.0,
    volume: 1.0
  };
  private ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  private currentRequestId: string = '';
  private isEngineReady: boolean = false;
  private maxRetries: number = 3;
  private retryDelay: number = 1000;
  private callbacksMap: Map<string, TTSCallbacks> = new Map();
  private requestCounter: number = 0;

  private constructor() {
    Logger.info('TTSService', '创建TTS服务实例');
  }

  /**
   * 获取TTS服务单例
   */
  static getInstance(): TTSService {
    if (TTSService.instance === null) {
      TTSService.instance = new TTSService();
    }
    return TTSService.instance;
  }

  /**
   * 静态方法：过滤文本，移除不适合语音朗读的字符
   * 可以单独使用而不需要创建TTSService实例
   */
  static filterTextForSpeech(text: string): string {
    if (!text) {
      return '';
    }

    return text
      // 移除表情符号
      .replace(/[\u{1F600}-\u{1F64F}]/gu, '')  // 表情符号 😀-🙏
      .replace(/[\u{1F300}-\u{1F5FF}]/gu, '')  // 杂项符号和象形文字 🌀-🗿
      .replace(/[\u{1F680}-\u{1F6FF}]/gu, '')  // 交通和地图符号 🚀-🛿
      .replace(/[\u{1F700}-\u{1F77F}]/gu, '')  // 炼金术符号
      .replace(/[\u{1F780}-\u{1F7FF}]/gu, '')  // 几何形状扩展
      .replace(/[\u{1F800}-\u{1F8FF}]/gu, '')  // 补充箭头-C
      .replace(/[\u{1F900}-\u{1F9FF}]/gu, '')  // 补充符号和象形文字 🤀-🧿
      .replace(/[\u{1FA00}-\u{1FA6F}]/gu, '')  // 扩展A 🨀-🩯
      .replace(/[\u{1FA70}-\u{1FAFF}]/gu, '')  // 扩展B 🩰-🫿
      .replace(/[\u{2600}-\u{26FF}]/gu, '')    // 杂项符号 ☀-⛿
      .replace(/[\u{2700}-\u{27BF}]/gu, '')    // 装饰符号 ✀-➿
      .replace(/[\u{FE00}-\u{FE0F}]/gu, '')    // 变体选择器
      .replace(/[\u{1F1E0}-\u{1F1FF}]/gu, '')  // 旗帜符号

      // 移除 Markdown 格式字符，保留内容
      .replace(/#{1,6}\s*/g, '')             // 移除标题符号 # ## ###
      .replace(/\*{1,3}(.*?)\*{1,3}/g, '$1') // 移除粗体斜体标记，保留内容 *text* **text** ***text***
      .replace(/_{1,3}(.*?)_{1,3}/g, '$1')   // 移除下划线标记，保留内容 _text_ __text__ ___text___
      .replace(/`{1,3}(.*?)`{1,3}/g, '$1')   // 移除代码块标记，保留代码内容 `code` ```code```
      .replace(/\[(.*?)\]\(.*?\)/g, '$1')    // 移除链接格式，保留文字 [text](url)
      .replace(/!\[(.*?)\]\(.*?\)/g, '$1')   // 移除图片格式，保留alt文字 ![alt](url)

      // 移除表格和分割线符号
      .replace(/\|/g, '')                    // 移除表格分隔符 |
      .replace(/[-]{3,}/g, '')               // 移除分割线 ---
      .replace(/[=]{3,}/g, '')               // 移除分割线 ===
      .replace(/>/g, '')                     // 移除引用符号 >
      .replace(/~/g, '')                     // 移除删除线符号 ~

      // 移除编程特殊符号，保留基本标点符号
      .replace(/[@#$%^&+={}\\<>]/g, '')      // 移除编程符号，保留括号()[]、逗号,、句号.、问号?、感叹号!、分号;、冒号:、引号"、星号*
      .replace(/·/g, '')                     // 移除中文间隔号

      // 处理空格和格式
      .replace(/\s+/g, ' ')                  // 多个空格合并为一个
      .replace(/^\s+|\s+$/g, '')             // 去除首尾空格
      .trim();
  }

  /**
   * 初始化TTS引擎
   */
  async initialize(callbacks?: TTSCallbacks): Promise<boolean> {
    const effectiveCallbacks: TTSCallbacks = callbacks || {};
    let requestId: string = '';

    try {
      this.currentState = TTSState.INITIALIZING;
      Logger.info('TTSService', '开始初始化华为TTS引擎');

      // 初始化前清理残留状态
      this.callbacksMap.clear();
      this.currentRequestId = '';
      this.callbacks = {};

      // 创建TTS引擎配置
      const engineConfig: textToSpeech.CreateEngineParams = {
        language: this.config.language || 'zh-CN',
        person: 0, // 0为聆小珊女声音色
        online: 1  // 离线模式，目前仅支持离线1
      };

      // 创建TTS引擎
      this.ttsEngine = await textToSpeech.createEngine(engineConfig);
      
      if (!this.ttsEngine) {
        throw new Error('TTS引擎创建失败');
      }

      // 设置TTS事件监听器
      this.setupTTSListeners();

      this.isEngineReady = true;
      this.currentState = TTSState.IDLE;
      Logger.info('TTSService', '华为TTS引擎初始化成功');
      return true;

    } catch (error) {
      this.currentState = TTSState.ERROR;
      this.isEngineReady = false;
      const err = error as Error;
      Logger.error('TTSService', `华为TTS引擎初始化失败: ${err.message}`);
      return false;
    }
  }

  /**
   * 设置TTS事件监听器
   */
  private setupTTSListeners(): void {
    if (!this.ttsEngine) {
      return;
    }

    this.ttsEngine.setListener({
      // 开始播报回调
      onStart: (requestId: string, response: textToSpeech.StartResponse) => {
        const callbacks = this.callbacksMap.get(requestId);
        const isCurrent = requestId === this.currentRequestId;

        Logger.info('TTSService', `TTS开始播放 requestId: ${requestId}`);

        if (isCurrent) {
          this.currentState = TTSState.PLAYING;
        } else {
          Logger.debug('TTSService', `收到非当前请求的播放开始回调 requestId: ${requestId}, 当前请求: ${this.currentRequestId || '无'}`);
        }

        callbacks?.onStart?.();
      },

      // 合成完成及播报完成回调
      onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
        const callbacks = this.callbacksMap.get(requestId);
        const isCurrent = requestId === this.currentRequestId;

        Logger.info('TTSService', `TTS播放完成 requestId: ${requestId}`);

        if (isCurrent) {
          this.currentState = TTSState.IDLE;
          this.currentText = '';
          this.currentRequestId = '';
          this.callbacks = {};
        } else {
          Logger.debug('TTSService', `播放完成回调来自非当前请求 requestId: ${requestId}, 当前请求: ${this.currentRequestId || '无'}`);
        }

        callbacks?.onComplete?.();
        this.cleanupRequestResources(requestId);
      },

      // 停止播报回调
      onStop: (requestId: string, response: textToSpeech.StopResponse) => {
        const callbacks = this.callbacksMap.get(requestId);
        const isCurrent = requestId === this.currentRequestId;

        Logger.info('TTSService', `TTS播放停止 requestId: ${requestId}`);

        if (isCurrent) {
          this.currentState = TTSState.STOPPED;
          this.currentText = '';
          this.currentRequestId = '';
          this.callbacks = {};
        } else {
          Logger.debug('TTSService', `停止回调来自非当前请求 requestId: ${requestId}, 当前请求: ${this.currentRequestId || '无'}`);
        }

        callbacks?.onStop?.();
        this.cleanupRequestResources(requestId);
      },

      // 返回音频流（可选处理）
      onData: (requestId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse) => {
        Logger.debug('TTSService', `TTS音频数据 requestId: ${requestId} audioSize: ${audio.byteLength}`);
      },

      // 错误回调
      onError: (requestId: string, errorCode: number, errorMessage: string) => {
        const callbacks = this.callbacksMap.get(requestId);
        const isCurrent = requestId === this.currentRequestId;

        Logger.error('TTSService', `TTS播放错误 requestId: ${requestId} code: ${errorCode} message: ${errorMessage}`);

        if (isCurrent) {
          this.currentState = TTSState.ERROR;
          this.currentText = '';
          this.currentRequestId = '';
          this.callbacks = {};
        }

        const error = new Error(`TTS播放错误: ${errorMessage} (Code: ${errorCode})`);
        callbacks?.onError?.(error);
        this.cleanupRequestResources(requestId);
      }
    });
  }

  /**
   * 播放文本（带重试逻辑）
   */
  async speak(text: string, callbacks?: TTSCallbacks): Promise<boolean> {
    return this.speakWithRetry(text, callbacks, 0);
  }

  /**
   * 实例方法：过滤文本，移除不适合语音朗读的字符
   */
  private filterTextForSpeech(text: string): string {
    return TTSService.filterTextForSpeech(text);
  }

  /**
   * 播放文本的内部实现（带重试逻辑）
   */
  private async speakWithRetry(text: string, callbacks?: TTSCallbacks, retryCount: number = 0): Promise<boolean> {
    if (!text || text.trim().length === 0) {
      Logger.warn('TTSService', '播放文本为空');
      return false;
    }

    let speakRequestId: string = '';

    // 过滤文本，移除不适合语音朗读的字符
    const filteredText = this.filterTextForSpeech(text);
    if (!filteredText || filteredText.trim().length === 0) {
      Logger.warn('TTSService', '过滤后的文本为空，跳过朗读');
      return false;
    }

    // 如果引擎未准备就绪，尝试初始化
    if (!this.isEngineReady || !this.ttsEngine) {
      Logger.warn('TTSService', 'TTS引擎未准备就绪，尝试重新初始化');
      const initSuccess = await this.initialize();
      if (!initSuccess && retryCount < this.maxRetries) {
        Logger.info('TTSService', `TTS初始化失败，第 ${retryCount + 1} 次重试`);
        await this.delay(this.retryDelay);
        return this.speakWithRetry(text, callbacks, retryCount + 1);
      } else if (!initSuccess) {
        Logger.error('TTSService', '达到最大重试次数，TTS初始化失败');
        return false;
      }
    }

    // 如果正在播放其他文本，先强制停止
    if (this.isPlaying() || this.isPaused()) {
      Logger.info('TTSService', `检测到正在播放/暂停的音频，执行强制停止操作 (状态: ${this.currentState})`);
      await this.forceStop();
      
      // 等待状态更新，设置较短的超时时间避免用户等待过久
      const stopped = await this.waitForState([TTSState.IDLE, TTSState.STOPPED], 500);
      if (!stopped) {
        Logger.warn('TTSService', '等待音频停止超时，强制重置状态');
        // 强制重置状态
        this.currentState = TTSState.IDLE;
        this.currentText = '';
        this.currentRequestId = '';
      }
    }

    try {
      // 设置回调函数
      this.callbacks = callbacks || {};

      this.currentText = filteredText;
      Logger.info('TTSService', `开始播放过滤后文本: ${filteredText.substring(0, 50)}${filteredText.length > 50 ? '...' : ''} (重试次数: ${retryCount})`);
      Logger.debug('TTSService', `原始文本: ${text.substring(0, 100)}${text.length > 100 ? '...' : ''}`);

      // 生成唯一的请求ID
      speakRequestId = this.generateRequestId();
      this.currentRequestId = speakRequestId;
      this.callbacksMap.set(speakRequestId, callbacks || {});

      // 设置TTS播放参数
      const extraParam: Record<string, Object> = {
        "speed": this.config.rate || 1,      // 语速
        "volume": Math.round((this.config.volume || 1.0) * 2), // 音量 (0-2)
        "pitch": this.config.pitch || 1,     // 音调
        "languageContext": this.config.language || 'zh-CN',
        "audioType": "pcm"
      };

      const speakParams: textToSpeech.SpeakParams = {
        requestId: speakRequestId,
        extraParams: extraParam
      };

      // 调用华为TTS API开始播放过滤后的文本
      if (this.ttsEngine) {
        this.ttsEngine.speak(filteredText, speakParams);
      }
      
      return true;

    } catch (error) {
      const err = error as Error;
      Logger.error('TTSService', `播放失败: ${err.message} (重试次数: ${retryCount})`);

      if (speakRequestId) {
        this.cleanupRequestResources(speakRequestId);

        if (this.currentRequestId === speakRequestId) {
          this.currentRequestId = '';
        }
      }

      this.currentText = '';

      // 如果还有重试机会，进行重试
      if (retryCount < this.maxRetries) {
        Logger.info('TTSService', `播放失败，进行第 ${retryCount + 1} 次重试`);
        await this.delay(this.retryDelay);
        return this.speakWithRetry(text, callbacks, retryCount + 1);
      }
      
      // 达到最大重试次数，设置错误状态
      this.currentState = TTSState.ERROR;
      this.callbacks = {};
      callbacks?.onError?.(err);
      return false;
    }
  }

  /**
   * 停止播放
   */
  async stop(): Promise<boolean> {
    return await this.stopWithMode(false);
  }

  /**
   * 强制停止播放
   */
  async forceStop(): Promise<boolean> {
    return await this.stopWithMode(true);
  }

  /**
   * 带模式的停止方法（普通/强制）
   */
  private async stopWithMode(forceMode: boolean): Promise<boolean> {
    const operation = forceMode ? '强制停止' : '停止';
    Logger.info('TTSService', `${operation}华为TTS播放，当前状态: ${this.currentState}`);

    // 强制模式下不检查状态
    if (!forceMode && !this.isPlaying() && !this.isPaused()) {
      Logger.info('TTSService', '当前不在播放或暂停状态，无需停止');
      return true;
    }

    // 强制模式下不检查引擎状态
    if (!forceMode && (!this.isEngineReady || !this.ttsEngine)) {
      Logger.error('TTSService', 'TTS引擎未准备就绪');
      return false;
    }

    try {
      // 保存当前请求ID用于停止
      const requestToStop = this.currentRequestId;
      let resolvedRequestId = requestToStop;

      // 如果当前请求ID缺失，但仍存在未清理的回调，尝试兜底处理
      if (!resolvedRequestId && this.callbacksMap.size === 1) {
        resolvedRequestId = Array.from(this.callbacksMap.keys())[0];
        Logger.warn('TTSService', `当前请求ID缺失，使用回退请求ID执行停止: ${resolvedRequestId}`);
      } else if (!resolvedRequestId && this.callbacksMap.size > 1) {
        Logger.warn('TTSService', `当前请求ID缺失且存在多个待清理请求，无法唯一映射: ${Array.from(this.callbacksMap.keys()).join(', ')}`);
      }

      const callbacks = resolvedRequestId ? this.callbacksMap.get(resolvedRequestId) : this.callbacks;
      
      // 立即重置状态，防止新的播放请求
      this.currentState = TTSState.STOPPED;
      this.currentText = '';
      this.currentRequestId = '';
      this.callbacks = {};

      // 如果有引擎且有请求ID，尝试调用停止
      if (this.ttsEngine) {
        try {
          Logger.info('TTSService', `调用华为TTS API停止播放${resolvedRequestId ? `，请求ID: ${resolvedRequestId}` : '（无有效请求ID）'}`);
          this.ttsEngine.stop();

          // 等待短暂时间让停止命令生效
          if (!forceMode) {
            await this.delay(100);
          }
          
        } catch (engineError) {
          Logger.error('TTSService', `华为TTS停止命令失败: ${(engineError as Error).message}`);
          
          if (!forceMode) {
            // 非强制模式下，引擎停止失败视为失败
            return false;
          }
          // 强制模式下继续执行
        }
      } else {
        Logger.warn('TTSService', `${operation}时引擎或请求ID无效 - 引擎: ${this.ttsEngine ? '有效' : '无效'}, 请求ID: ${resolvedRequestId || '无'}`);
      }

      // 触发停止回调
      if (callbacks && callbacks.onStop) {
        try {
          callbacks.onStop();
        } catch (callbackError) {
          Logger.error('TTSService', `停止回调执行失败: ${(callbackError as Error).message}`);
        }
      }

      if (resolvedRequestId) {
        this.cleanupRequestResources(resolvedRequestId);
      }

      Logger.info('TTSService', `${operation}播放完成`);
      return true;

    } catch (error) {
      const err = error as Error;
      Logger.error('TTSService', `${operation}播放失败: ${err.message}`);
      
      // 强制模式下即使出错也要重置状态
      if (forceMode) {
        this.currentState = TTSState.STOPPED;
        this.currentText = '';
        this.currentRequestId = '';
        Logger.info('TTSService', '强制模式：即使出现错误也重置状态');
        return true;
      }
      
      return false;
    }
  }

  /**
   * 暂停播放
   * 注意：华为TTS API可能不支持暂停功能，这里使用停止作为替代方案
   */
  async pause(): Promise<boolean> {
    if (!this.isPlaying()) {
      return true;
    }

    try {
      Logger.info('TTSService', '暂停TTS播放（使用停止作为替代）');
      
      // 华为TTS API可能不支持暂停，使用停止替代
      const success = await this.stop();
      if (success) {
        this.currentState = TTSState.PAUSED;
        this.callbacks.onPause?.();
      }
      return success;
    } catch (error) {
      const err = error as Error;
      Logger.error('TTSService', `暂停播放失败: ${err.message}`);
      return false;
    }
  }

  /**
   * 恢复播放
   * 注意：华为TTS API可能不支持恢复功能，这里使用重新播放作为替代方案
   */
  async resume(): Promise<boolean> {
    if (this.currentState !== TTSState.PAUSED) {
      return true;
    }

    try {
      Logger.info('TTSService', '恢复TTS播放（使用重新播放作为替代）');
      
      // 如果有保存的文本，重新播放
      if (this.currentText) {
        const success = await this.speak(this.currentText);
        if (success) {
          this.callbacks.onResume?.();
        }
        return success;
      }
      
      return true;
    } catch (error) {
      const err = error as Error;
      Logger.error('TTSService', `恢复播放失败: ${err.message}`);
      return false;
    }
  }

  /**
   * 更新配置
   */
  updateConfig(config: Partial<TTSConfig>): void {
    const oldConfig: TTSConfig = {
      language: this.config.language,
      voice: this.config.voice,
      rate: this.config.rate,
      pitch: this.config.pitch,
      volume: this.config.volume
    };
    
    if (config.language !== undefined) this.config.language = config.language;
    if (config.voice !== undefined) this.config.voice = config.voice;
    if (config.rate !== undefined) this.config.rate = Math.max(0.1, Math.min(3.0, config.rate));
    if (config.pitch !== undefined) this.config.pitch = Math.max(0.5, Math.min(2.0, config.pitch));
    if (config.volume !== undefined) this.config.volume = Math.max(0.0, Math.min(1.0, config.volume));
    
    Logger.info('TTSService', `更新TTS配置: ${JSON.stringify(this.config)}`);
    
    // 如果语言发生变化，需要重新初始化TTS引擎
    if (oldConfig.language !== this.config.language && this.isEngineReady) {
      Logger.info('TTSService', '语言配置已更改，需要重新初始化TTS引擎');
      this.reinitializeEngine();
    }
  }

  /**
   * 获取当前状态
   */
  getState(): TTSState {
    return this.currentState;
  }

  /**
   * 获取当前播放文本
   */
  getCurrentText(): string {
    return this.currentText;
  }

  /**
   * 检查是否正在播放
   */
  isPlaying(): boolean {
    return this.currentState === TTSState.PLAYING;
  }

  /**
   * 检查是否已暂停
   */
  isPaused(): boolean {
    return this.currentState === TTSState.PAUSED;
  }

  /**
   * 检查是否可以播放
   */
  canPlay(): boolean {
    return this.currentState === TTSState.IDLE || 
           this.currentState === TTSState.STOPPED ||
           this.currentState === TTSState.ERROR;
  }

  /**
   * 等待指定状态
   */
  private async waitForState(targetStates: TTSState[], timeoutMs: number = 5000): Promise<boolean> {
    return new Promise((resolve) => {
      if (targetStates.includes(this.currentState)) {
        resolve(true);
        return;
      }

      const startTime = Date.now();
      const checkInterval = setInterval(() => {
        if (targetStates.includes(this.currentState)) {
          clearInterval(checkInterval);
          resolve(true);
        } else if (Date.now() - startTime > timeoutMs) {
          clearInterval(checkInterval);
          resolve(false);
        }
      }, 100);
    });
  }

  /**
   * 清理指定请求的回调和标记
   */
  private cleanupRequestResources(requestId: string): void {
    if (!requestId) {
      return;
    }

    if (this.callbacksMap.has(requestId)) {
      this.callbacksMap.delete(requestId);
    }

    if (this.callbacksMap.size === 0 && !this.currentRequestId) {
      this.callbacks = {};
    }
  }

  /**
   * 生成唯一请求ID
   */
  private generateRequestId(): string {
    this.requestCounter = (this.requestCounter + 1) % 100000;
    const timestamp = systemDateTime.getTime();
    return `${timestamp}-${this.requestCounter}`;
  }

  /**
   * 重新初始化TTS引擎（当配置更改时）
   */
  private async reinitializeEngine(): Promise<void> {
    try {
      Logger.info('TTSService', '重新初始化TTS引擎');
      
      // 先销毁现有引擎
      if (this.ttsEngine) {
        this.ttsEngine.shutdown();
        this.ttsEngine = null;
      }
      
      this.isEngineReady = false;
      
      // 重新初始化
      await this.initialize();
    } catch (error) {
      const err = error as Error;
      Logger.error('TTSService', `重新初始化TTS引擎失败: ${err.message}`);
    }
  }

  /**
   * 辅助延迟函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 检查TTS引擎健康状态
   */
  async checkEngineHealth(): Promise<boolean> {
    try {
      if (!this.ttsEngine) {
        return false;
      }
      
      // 简单的健康检查：尝试获取引擎状态
      return this.isEngineReady && this.ttsEngine !== null;
    } catch (error) {
      const err = error as Error;
      Logger.error('TTSService', `TTS引擎健康检查失败: ${err.message}`);
      return false;
    }
  }

  /**
   * 获取详细的服务状态信息
   */
  getServiceStatus(): TTSServiceStatus {
    const status: TTSServiceStatus = {
      isReady: this.isEngineReady,
      currentState: this.currentState,
      hasActiveRequest: !!this.currentRequestId,
      config: {
        language: this.config.language,
        voice: this.config.voice,
        rate: this.config.rate,
        pitch: this.config.pitch,
        volume: this.config.volume
      }
    };
    return status;
  }

  /**
   * 设置重试参数
   */
  setRetryConfig(maxRetries: number = 3, retryDelay: number = 1000): void {
    this.maxRetries = Math.max(0, Math.min(10, maxRetries)); // 限制在0-10次之间
    this.retryDelay = Math.max(100, Math.min(5000, retryDelay)); // 限制在100-5000ms之间
    Logger.info('TTSService', `更新重试配置: maxRetries=${this.maxRetries}, retryDelay=${this.retryDelay}`);
  }

  /**
   * 销毁TTS服务
   */
  async destroy(): Promise<void> {
    try {
      // 停止当前播放
      if (this.isPlaying() || this.isPaused()) {
        await this.stop();
      }

      // 销毁TTS引擎
      if (this.ttsEngine) {
        this.ttsEngine.shutdown();
        this.ttsEngine = null;
      }

      // 重置状态
      this.isEngineReady = false;
      this.currentState = TTSState.IDLE;
      this.currentText = '';
      this.currentRequestId = '';
      this.callbacksMap.clear();
      this.callbacks = {};

      // 重新计数请求ID，避免溢出
      this.requestCounter = 0;
      
      Logger.info('TTSService', '华为TTS服务已销毁');
    } catch (error) {
      const err = error as Error;
      Logger.error('TTSService', `销毁TTS服务失败: ${err.message}`);
    }
  }
}
