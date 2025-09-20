import { speechRecognizer } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { VoiceRecognitionState } from '../components/VoiceInputComponent';
import { hilog } from '@kit.PerformanceAnalysisKit';
import AudioCapturer from './AudioCapturer';
import { Logger } from '../utils/Logger';

const TAG = "SpeechRecognitionService"

interface EngineExtraParams {
  locate: string;
  recognizerMode: string;
}

interface StartExtraParams {
  vadBegin: number;
  vadEnd: number;
  maxAudioDuration: number;
}

// 语音识别初始化参数，通过集中定义便于统一调优
const ENGINE_EXTRA_PARAMS: EngineExtraParams = {
  locate: 'CN',
  // 长语音模式对持续发言的容错率更高，能降低截断导致的识别偏差
  recognizerMode: 'long'
};

// VAD配置：缩短起止门限，加快响应速度，同时给出充足的发言窗口
const START_EXTRA_PARAMS: StartExtraParams = {
  vadBegin: 1200,
  vadEnd: 1800,
  maxAudioDuration: 45000
};
/**
 * 语音识别服务
 */
export class SpeechRecognitionService {
  private engine?: speechRecognizer.SpeechRecognitionEngine;
  onResult?: (text: string) => void;
  onError?: (error: string) => void;
  onStateChange?: (state: VoiceRecognitionState) => void;
  private context?: common.UIAbilityContext;
  private currentSessionId?: string;
  private currentState: VoiceRecognitionState = VoiceRecognitionState.IDLE;
  private lastStateChangeTime: number = 0;
  private sessionStartTime: number = 0;
  private stateChangeCount: number = 0;
  private sessionTimeoutTimer?: number;
  private mAudioCapturer: AudioCapturer = new AudioCapturer();
  private isAudioCapturerReleased: boolean = true; // 音频捕获器是否已释放
  private engineStartResolve?: (value: boolean) => void; // 引擎启动确认回调
  private isFirstRun: boolean = true; // 是否第一次运行
  private lastRecognitionResult: string = '';

  /**
   * 初始化语音识别器
   */
  async init(context?: common.UIAbilityContext): Promise<boolean> {
    const initStartTime = Date.now();
    hilog.info(0x0000, 'SpeechRecognitionService', '开始初始化语音识别服务');
    
    try {
      // 保存上下文
      this.context = context;
      hilog.info(0x0000, 'SpeechRecognitionService', '上下文已设置: %{public}s', context ? '有效' : '无效');

      const createEngineParams: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: {
          locate: ENGINE_EXTRA_PARAMS.locate,
          recognizerMode: ENGINE_EXTRA_PARAMS.recognizerMode
        }
      };
      
      hilog.info(0x0000, 'SpeechRecognitionService', '创建引擎参数: %{public}s', JSON.stringify(createEngineParams));

      const engineStartTime = Date.now();
      hilog.info(0x0000, 'SpeechRecognitionService', '开始创建语音识别引擎');
      
      this.engine = await new Promise<speechRecognizer.SpeechRecognitionEngine>((resolve, reject) => {
        speechRecognizer.createEngine(createEngineParams, (error: BusinessError, engine: speechRecognizer.SpeechRecognitionEngine) => {
          if (error) {
            hilog.error(0x0000, 'SpeechRecognitionService', '引擎创建失败: %{public}s, 错误码: %{public}d, 错误消息: %{public}s', 
              JSON.stringify(error), error.code, error.message);
            reject(error);
          } else {
            const engineCreateTime = Date.now() - engineStartTime;
            hilog.info(0x0000, 'SpeechRecognitionService', '引擎创建成功, 耗时: %{public}dms', engineCreateTime);
            resolve(engine);
          }
        });
      });

      hilog.info(0x0000, 'SpeechRecognitionService', '引擎对象创建完成: %{public}s', this.engine ? '有效' : '无效');

      // 创建回调对象
      const self = this;
      let setListener: speechRecognizer.RecognitionListener = {
        // 开始识别成功回调
        onStart(sessionId: string, eventMessage: string) {
          hilog.info(0x0000, 'SpeechRecognitionService', 'onStart回调触发 - sessionId: %{public}s, eventMessage: %{public}s', sessionId, eventMessage);
          self.updateStateWithLogging(VoiceRecognitionState.RECORDING, 'onStart回调');
          // 确认引擎启动成功
          if (self.engineStartResolve) {
            self.engineStartResolve(true);
            self.engineStartResolve = undefined;
          }
        },
        // 事件回调
        onEvent(sessionId: string, eventCode: number, eventMessage: string) {
          hilog.info(0x0000, 'SpeechRecognitionService', 'onEvent回调触发 - sessionId: %{public}s, eventCode: %{public}d, eventMessage: %{public}s', sessionId, eventCode, eventMessage);
          
          switch (eventCode) {
            case 1: // 音频开始
              self.updateStateWithLogging(VoiceRecognitionState.RECORDING, 'onEvent事件码1-音频开始');
              break;
            case 3: // 音频结束
              self.updateStateWithLogging(VoiceRecognitionState.PROCESSING, 'onEvent事件码3-音频结束');
              break;
            default:
              hilog.info(0x0000, 'SpeechRecognitionService', '未处理的onEvent事件码: %{public}d', eventCode);
              break;
          }
        },
        // 识别结果回调，包括中间结果和最终结果
        onResult(sessionId: string, result: speechRecognizer.SpeechRecognitionResult) {
          hilog.info(0x0000, 'SpeechRecognitionService', 'onResult回调触发 - sessionId: %{public}s, result: %{public}s', sessionId, JSON.stringify(result));
          
          if (result && result.result && result.result.trim()) {
            const trimmed = result.result.trim();
            hilog.info(0x0000, 'SpeechRecognitionService', '收到识别结果: %{public}s', trimmed);
            self.lastRecognitionResult = trimmed;
          }
        },
        // 识别完成回调
        onComplete(sessionId: string, eventMessage: string) {
          hilog.info(0x0000, 'SpeechRecognitionService', 'onComplete回调触发 - sessionId: %{public}s, eventMessage: %{public}s', sessionId, eventMessage);
          self.handleRecognitionComplete();
        },
        // 错误回调
        onError(sessionId: string, errorCode: number, errorMessage: string) {
          hilog.error(0x0000, 'SpeechRecognitionService', 'onError回调触发 - sessionId: %{public}s, errorCode: %{public}d, errorMessage: %{public}s', sessionId, errorCode, errorMessage);
          // 将错误信息记录到日志，但不传递给UI
          Logger.error('SpeechRecognitionService', `语音识别错误: ${errorCode} - ${errorMessage}`);
          // 不调用onError回调，避免在UI上显示错误
          // 直接转为空闲状态
          self.lastRecognitionResult = '';
          self.updateStateWithLogging(VoiceRecognitionState.IDLE, `错误后自动重置: ${errorMessage}`);
        }
      };

      // 设置识别监听器
      this.engine?.setListener(setListener);
      
      const initEndTime = Date.now();
      hilog.info(0x0000, 'SpeechRecognitionService', '语音识别服务初始化完成，耗时: %{public}d ms', initEndTime - initStartTime);
      
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, 'SpeechRecognitionService', '初始化语音识别器失败: %{public}s', JSON.stringify(err));
      Logger.error(TAG, `初始化语音识别器失败: ${err.message}`);
      // 不调用onError，静默处理初始化失败
      return false;
    }
  }

  /**
   * 开始语音识别
   */
  async startRecognition(sessionId?: string): Promise<boolean> {
    const startTime = Date.now();
    hilog.info(0x0000, 'SpeechRecognitionService', '开始语音识别');
    
    try {
      // 检查引擎状态
      if (!this.engine) {
        hilog.error(0x0000, 'SpeechRecognitionService', '引擎未初始化');
        Logger.error('SpeechRecognitionService', '语音识别引擎未初始化');
        // 不调用onError，静默失败
        return false;
      }

      // 更新会话ID
      this.currentSessionId = sessionId || this.generateSessionId();
      this.sessionStartTime = startTime;
      this.lastRecognitionResult = '';
      
      hilog.info(0x0000, 'SpeechRecognitionService', '会话ID: %{public}s', this.currentSessionId);

      // 更新状态
      this.updateState(VoiceRecognitionState.PROCESSING);
      
      // 重置音频捕获器状态
      this.isAudioCapturerReleased = false;

      const audioParam: speechRecognizer.AudioInfo = {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      };
      const recognizerParams: speechRecognizer.StartParams = {
        sessionId: this.currentSessionId,
        audioInfo: audioParam,
        extraParams: {
          vadBegin: START_EXTRA_PARAMS.vadBegin,
          vadEnd: START_EXTRA_PARAMS.vadEnd,
          maxAudioDuration: START_EXTRA_PARAMS.maxAudioDuration
        }
      };

      hilog.info(0x0000, 'SpeechRecognitionService', '开始识别参数: %{public}s', JSON.stringify(recognizerParams));
      
      // 先初始化音频捕获器（但不启动）
      await this.mAudioCapturer.init((dataBuffer: ArrayBuffer) => {
        if (!this.currentSessionId) {
          hilog.warn(0x0000, 'SpeechRecognitionService', '会话已结束，跳过音频写入');
          return;
        }
        
        // 验证音频数据缓冲区
        if (!dataBuffer || dataBuffer.byteLength === 0) {
          hilog.warn(0x0000, 'SpeechRecognitionService', '收到空音频缓冲区，跳过写入');
          return;
        }
        
        hilog.info(0x0000, 'SpeechRecognitionService', '收到音频数据，大小: %{public}d bytes', dataBuffer.byteLength);
        
        try {
          // 直接使用原始缓冲区，AudioCapturer现在已经控制读取节奏
          const uint8Array: Uint8Array = new Uint8Array(dataBuffer);
          
          // 写入音频流
          this.engine?.writeAudio(this.currentSessionId, uint8Array);
          hilog.info(0x0000, 'SpeechRecognitionService', '成功写入音频数据: %{public}d bytes', uint8Array.length);
        } catch (writeError) {
          hilog.error(0x0000, 'SpeechRecognitionService', '写入音频数据失败: %{public}s', JSON.stringify(writeError));
        }
      });

      // 启动识别引擎
      await this.engine.startListening(recognizerParams);
      hilog.info(0x0000, 'SpeechRecognitionService', '语音识别引擎启动成功');

      // 启动音频捕获
      await this.mAudioCapturer.start();

      hilog.info(0x0000, 'SpeechRecognitionService', '音频捕获启动成功');
      
      const endTime = Date.now();
      hilog.info(0x0000, 'SpeechRecognitionService', '语音识别启动完成，耗时: %{public}d ms', endTime - startTime);
      
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, 'SpeechRecognitionService', '启动语音识别失败: %{public}s', JSON.stringify(err));
      Logger.error(TAG, `启动语音识别失败: ${err.message}`);
      this.onError?.(`启动失败: ${err.message}`);
      this.updateState(VoiceRecognitionState.ERROR);
      return false;
    }
  }

  /**
   * 停止语音识别
   */
  async stopRecognition(): Promise<boolean> {
    const startTime = Date.now();
    hilog.info(0x0000, 'SpeechRecognitionService', '停止语音识别');
    
    try {
      // 停止音频捕获
      if (!this.isAudioCapturerReleased) {
        await this.mAudioCapturer.stop();
        this.isAudioCapturerReleased = true;
        hilog.info(0x0000, 'SpeechRecognitionService', '音频捕获已停止');
      }

      // 停止识别引擎
      if (this.engine && this.currentSessionId) {
        await this.engine.finish(this.currentSessionId);
        hilog.info(0x0000, 'SpeechRecognitionService', '语音识别引擎已停止');
      }

      const endTime = Date.now();
      hilog.info(0x0000, 'SpeechRecognitionService', '语音识别停止完成，耗时: %{public}d ms', endTime - startTime);
      
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, 'SpeechRecognitionService', '停止语音识别失败: %{public}s', JSON.stringify(err));
      Logger.error(TAG, `停止语音识别失败: ${err.message}`);
      this.onError?.(`停止失败: ${err.message}`);
      return false;
    }
  }

  /**
   * 取消语音识别
   */
  async cancelRecognition(): Promise<boolean> {
    const startTime = Date.now();
    hilog.info(0x0000, 'SpeechRecognitionService', '取消语音识别');
    
    try {
      // 停止音频捕获
      if (!this.isAudioCapturerReleased) {
        await this.mAudioCapturer.stop();
        this.isAudioCapturerReleased = true;
        hilog.info(0x0000, 'SpeechRecognitionService', '音频捕获已停止');
      }

      // 取消识别引擎
      if (this.engine && this.currentSessionId) {
        await this.engine.cancel(this.currentSessionId);
        hilog.info(0x0000, 'SpeechRecognitionService', '语音识别引擎已取消');
      }

      // 重置状态
      this.updateState(VoiceRecognitionState.IDLE);
      this.lastRecognitionResult = '';

      const endTime = Date.now();
      hilog.info(0x0000, 'SpeechRecognitionService', '语音识别取消完成，耗时: %{public}d ms', endTime - startTime);
      
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, 'SpeechRecognitionService', '取消语音识别失败: %{public}s', JSON.stringify(err));
      Logger.error(TAG, `取消语音识别失败: ${err.message}`);
      this.onError?.(`取消失败: ${err.message}`);
      return false;
    }
  }

  /**
   * 处理识别完成
   */
  private async handleRecognitionComplete(): Promise<void> {
    hilog.info(0x0000, 'SpeechRecognitionService', '处理识别完成');
    
    try {
      // 停止音频捕获
      if (!this.isAudioCapturerReleased) {
        await this.mAudioCapturer.stop();
        this.isAudioCapturerReleased = true;
        hilog.info(0x0000, 'SpeechRecognitionService', '音频捕获已停止');
      }

      // 更新状态
      this.updateState(VoiceRecognitionState.IDLE);
      
      if (this.lastRecognitionResult.trim()) {
        const finalResult = this.lastRecognitionResult.trim();
        hilog.info(0x0000, 'SpeechRecognitionService', '输出最终识别结果: %{public}s', finalResult);
        this.onResult?.(finalResult);
      }
      this.lastRecognitionResult = '';
      
      hilog.info(0x0000, 'SpeechRecognitionService', '识别完成处理结束');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, 'SpeechRecognitionService', '处理识别完成失败: %{public}s', JSON.stringify(err));
      Logger.error(TAG, `处理识别完成失败: ${err.message}`);
    }
  }

  /**
   * 更新识别状态（带日志记录）
   */
  private updateStateWithLogging(newState: VoiceRecognitionState, reason: string): void {
    const now = Date.now();
    
    // 防止状态频繁变化
    if (this.currentState === newState) {
      return;
    }

    // 记录状态变化
    hilog.info(0x0000, 'SpeechRecognitionService', '状态变化[%{public}s]: %{public}s -> %{public}s', 
      reason, this.currentState, newState);
    
    this.currentState = newState;
    this.lastStateChangeTime = now;
    this.stateChangeCount++;
    
    // 通知状态变化
    this.onStateChange?.(newState);
  }

  /**
   * 更新识别状态
   */
  private updateState(newState: VoiceRecognitionState): void {
    this.updateStateWithLogging(newState, '内部状态更新');
  }

  /**
   * 生成会话ID
   */
  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 获取错误信息
   */
  private getErrorMessage(code: number): string {
    switch (code) {
      case 20001:
        return '音频输入设备不可用';
      case 20002:
        return '音频录制权限被拒绝';
      case 20003:
        return '音频格式不支持';
      case 20004:
        return '网络连接失败';
      case 20005:
        return '语音识别服务不可用';
      case 20006:
        return '识别超时';
      case 20007:
        return '音频数据无效';
      case 20008:
        return '引擎内部错误';
      default:
        return `语音识别错误 (${code})`;
    }
  }

  /**
   * 销毁语音识别器
   */
  async destroy(): Promise<void> {
    hilog.info(0x0000, 'SpeechRecognitionService', '销毁语音识别器');
    
    try {
      // 停止音频捕获
      if (!this.isAudioCapturerReleased) {
        await this.mAudioCapturer.stop();
        this.isAudioCapturerReleased = true;
      }

      // 销毁音频捕获器
      await this.mAudioCapturer.destroy();

      // 销毁识别引擎
      if (this.engine) {
        await this.engine.shutdown();
        this.engine = undefined;
      }

      // 清除定时器
      if (this.sessionTimeoutTimer) {
        clearTimeout(this.sessionTimeoutTimer);
        this.sessionTimeoutTimer = undefined;
      }

      // 重置状态
      this.updateState(VoiceRecognitionState.IDLE);
      this.lastRecognitionResult = '';
      
      hilog.info(0x0000, 'SpeechRecognitionService', '语音识别器销毁完成');
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, 'SpeechRecognitionService', '销毁语音识别器失败: %{public}s', JSON.stringify(err));
      Logger.error(TAG, `销毁语音识别器失败: ${err.message}`);
    }
  }

  /**
   * 获取当前状态
   */
  getCurrentState(): VoiceRecognitionState {
    return this.currentState;
  }

  /**
   * 检查是否正在录音
   */
  isRecording(): boolean {
    return this.currentState === VoiceRecognitionState.RECORDING;
  }

  /**
   * 检查是否正在处理
   */
  isProcessing(): boolean {
    return this.currentState === VoiceRecognitionState.PROCESSING;
  }

  /**
   * 获取当前会话ID
   */
  getCurrentSessionId(): string | undefined {
    return this.currentSessionId;
  }

  /**
   * 设置结果回调
   */
  setOnResult(callback: (text: string) => void): void {
    this.onResult = callback;
  }

  /**
   * 设置错误回调
   */
  setOnError(callback: (error: string) => void): void {
    this.onError = callback;
  }

  /**
   * 设置状态变化回调
   */
  setOnStateChange(callback: (state: VoiceRecognitionState) => void): void {
    this.onStateChange = callback;
  }
}
