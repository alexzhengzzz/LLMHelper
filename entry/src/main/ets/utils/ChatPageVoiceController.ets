import { ChatPageState, ChatPageStateManager } from './ChatPageStateManager';
import { ChatPageAnimationController } from './ChatPageAnimationController';
import { VoiceRecognitionState } from '../components/VoiceInputComponent';
import { ChatViewModel } from '../viewmodels/ChatViewModel';
import { SpeechRecognitionService } from '../services/SpeechRecognitionService';
import { AutoTTSService } from '../services/AutoTTSService';
import { Logger } from './Logger';

/**
 * ChatPage语音控制器 - 统一管理语音相关功能
 */
export class ChatPageVoiceController {
  private stateManager: ChatPageStateManager;
  private animationController: ChatPageAnimationController;
  private chatViewModel: ChatViewModel;
  private speechService: SpeechRecognitionService;
  private autoTTSService: AutoTTSService;

  // 语音识别回调
  private voiceCallbacks = {
    onStart: () => {
      Logger.debug('ChatPageVoiceController', '语音识别开始');
    },
    onResult: (text: string, isFinal: boolean) => {
      Logger.debug('ChatPageVoiceController', `语音识别结果: ${text}, 最终结果: ${isFinal}`);
    },
    onError: (error: string) => {
      Logger.error('ChatPageVoiceController', `语音识别错误: ${error}`);
    },
    onEnd: () => {
      Logger.debug('ChatPageVoiceController', '语音识别结束');
    }
  };

  constructor(
    stateManager: ChatPageStateManager,
    animationController: ChatPageAnimationController,
    chatViewModel: ChatViewModel
  ) {
    this.stateManager = stateManager;
    this.animationController = animationController;
    this.chatViewModel = chatViewModel;
    this.speechService = SpeechRecognitionService.getInstance();
    this.autoTTSService = AutoTTSService.getInstance();
  }

  /**
   * 初始化语音控制器
   */
  async initialize(): Promise<void> {
    try {
      // 初始化语音识别服务
      await this.speechService.initialize();

      // 初始化自动TTS服务
      await this.autoTTSService.initialize();

      Logger.info('ChatPageVoiceController', '语音控制器初始化完成');
    } catch (error) {
      Logger.error('ChatPageVoiceController', `语音控制器初始化失败: ${error}`);
      throw error;
    }
  }

  /**
   * 开始语音识别
   */
  async startVoiceRecognition(state: ChatPageState): Promise<void> {
    try {
      if (state.voiceRecognitionState !== VoiceRecognitionState.IDLE) {
        Logger.warn('ChatPageVoiceController', '语音识别已在进行中，忽略重复请求');
        return;
      }

      // 更新状态为启动中
      this.stateManager.updateVoiceRecognitionState(state, VoiceRecognitionState.STARTING);

      // 触发语音动画
      this.animationController.animateVoiceStateChange();

      // 设置语音识别回调
      const callbacks = {
        onStart: () => {
          this.stateManager.updateVoiceRecognitionState(state, VoiceRecognitionState.LISTENING);
          this.voiceCallbacks.onStart();
        },
        onResult: (text: string, isFinal: boolean) => {
          if (isFinal) {
            // 最终结果，更新输入文本
            this.stateManager.updateInputText(state, text);
            this.stateManager.updateVoiceRecognitionState(state, VoiceRecognitionState.IDLE);

            // 自动发送消息（如果文本不为空）
            if (text.trim()) {
              this.sendVoiceMessage(state, text);
            }
          } else {
            // 临时结果，更新输入文本但不发送
            this.stateManager.updateInputText(state, text);
          }
          this.voiceCallbacks.onResult(text, isFinal);
        },
        onError: (error: string) => {
          this.stateManager.updateVoiceRecognitionState(state, VoiceRecognitionState.IDLE);
          this.stateManager.updateInputText(state, '');
          this.voiceCallbacks.onError(error);
        },
        onEnd: () => {
          if (state.voiceRecognitionState !== VoiceRecognitionState.IDLE) {
            this.stateManager.updateVoiceRecognitionState(state, VoiceRecognitionState.IDLE);
          }
          this.voiceCallbacks.onEnd();
        }
      };

      // 开始语音识别
      await this.speechService.startRecognition(callbacks);

      Logger.info('ChatPageVoiceController', '语音识别启动成功');
    } catch (error) {
      Logger.error('ChatPageVoiceController', `启动语音识别失败: ${error}`);
      this.stateManager.updateVoiceRecognitionState(state, VoiceRecognitionState.IDLE);
      this.stateManager.updateInputText(state, '');
      throw error;
    }
  }

  /**
   * 停止语音识别
   */
  async stopVoiceRecognition(state: ChatPageState): Promise<void> {
    try {
      if (state.voiceRecognitionState === VoiceRecognitionState.IDLE) {
        Logger.warn('ChatPageVoiceController', '语音识别未在进行中，忽略停止请求');
        return;
      }

      // 停止语音识别
      await this.speechService.stopRecognition();

      // 更新状态
      this.stateManager.updateVoiceRecognitionState(state, VoiceRecognitionState.IDLE);

      Logger.info('ChatPageVoiceController', '语音识别已停止');
    } catch (error) {
      Logger.error('ChatPageVoiceController', `停止语音识别失败: ${error}`);
      // 强制重置状态
      this.stateManager.updateVoiceRecognitionState(state, VoiceRecognitionState.IDLE);
      throw error;
    }
  }

  /**
   * 切换语音识别状态
   */
  async toggleVoiceRecognition(state: ChatPageState): Promise<void> {
    if (state.voiceRecognitionState === VoiceRecognitionState.IDLE) {
      await this.startVoiceRecognition(state);
    } else {
      await this.stopVoiceRecognition(state);
    }
  }

  /**
   * 发送语音消息
   */
  private async sendVoiceMessage(state: ChatPageState, text: string): Promise<void> {
    try {
      Logger.info('ChatPageVoiceController', `发送语音消息: ${text}`);

      // 调用ChatViewModel发送消息
      await this.chatViewModel.sendMessage(text);

      // 清空输入文本
      this.stateManager.updateInputText(state, '');

    } catch (error) {
      Logger.error('ChatPageVoiceController', `发送语音消息失败: ${error}`);
    }
  }

  /**
   * 播放文本语音
   */
  async playTextToSpeech(text: string): Promise<void> {
    try {
      await this.autoTTSService.playText(text);
      Logger.debug('ChatPageVoiceController', `TTS播放开始: ${text.substring(0, 50)}...`);
    } catch (error) {
      Logger.error('ChatPageVoiceController', `TTS播放失败: ${error}`);
    }
  }

  /**
   * 停止TTS播放
   */
  async stopTextToSpeech(): Promise<void> {
    try {
      await this.autoTTSService.stop();
      Logger.debug('ChatPageVoiceController', 'TTS播放已停止');
    } catch (error) {
      Logger.error('ChatPageVoiceController', `停止TTS播放失败: ${error}`);
    }
  }

  /**
   * 检查语音权限
   */
  async checkVoicePermissions(): Promise<boolean> {
    try {
      const hasPermission = await this.speechService.checkPermissions();
      Logger.debug('ChatPageVoiceController', `语音权限检查结果: ${hasPermission}`);
      return hasPermission;
    } catch (error) {
      Logger.error('ChatPageVoiceController', `检查语音权限失败: ${error}`);
      return false;
    }
  }

  /**
   * 请求语音权限
   */
  async requestVoicePermissions(): Promise<boolean> {
    try {
      const granted = await this.speechService.requestPermissions();
      Logger.info('ChatPageVoiceController', `语音权限请求结果: ${granted}`);
      return granted;
    } catch (error) {
      Logger.error('ChatPageVoiceController', `请求语音权限失败: ${error}`);
      return false;
    }
  }

  /**
   * 获取语音识别可用性
   */
  isVoiceRecognitionAvailable(): boolean {
    return this.speechService.isAvailable();
  }

  /**
   * 获取TTS可用性
   */
  isTextToSpeechAvailable(): boolean {
    return this.autoTTSService.isAvailable();
  }

  /**
   * 设置语音识别语言
   */
  async setRecognitionLanguage(language: string): Promise<void> {
    try {
      await this.speechService.setLanguage(language);
      Logger.info('ChatPageVoiceController', `语音识别语言已设置为: ${language}`);
    } catch (error) {
      Logger.error('ChatPageVoiceController', `设置语音识别语言失败: ${error}`);
    }
  }

  /**
   * 设置TTS语言
   */
  async setTTSLanguage(language: string): Promise<void> {
    try {
      await this.autoTTSService.setLanguage(language);
      Logger.info('ChatPageVoiceController', `TTS语言已设置为: ${language}`);
    } catch (error) {
      Logger.error('ChatPageVoiceController', `设置TTS语言失败: ${error}`);
    }
  }

  /**
   * 更新语音输入显示状态
   */
  updateVoiceInputVisibility(state: ChatPageState, visible: boolean): void {
    state.showVoiceInput = visible;
    Logger.debug('ChatPageVoiceController', `语音输入显示状态: ${visible}`);
  }

  /**
   * 获取当前语音状态信息
   */
  getVoiceState(state: ChatPageState): {
    recognitionState: VoiceRecognitionState;
    showVoiceInput: boolean;
    isRecognitionAvailable: boolean;
    isTTSAvailable: boolean;
  } {
    return {
      recognitionState: state.voiceRecognitionState,
      showVoiceInput: state.showVoiceInput,
      isRecognitionAvailable: this.isVoiceRecognitionAvailable(),
      isTTSAvailable: this.isTextToSpeechAvailable()
    };
  }

  /**
   * 处理语音识别错误
   */
  private handleVoiceError(state: ChatPageState, error: string): void {
    Logger.error('ChatPageVoiceController', `语音识别错误: ${error}`);

    // 重置语音状态
    this.stateManager.updateVoiceRecognitionState(state, VoiceRecognitionState.IDLE);

    // 可以在这里添加错误提示逻辑
  }

  /**
   * 清理语音控制器
   */
  async destroy(): Promise<void> {
    try {
      // 停止所有语音活动
      await this.speechService.stopRecognition();
      await this.autoTTSService.stop();

      Logger.info('ChatPageVoiceController', '语音控制器已销毁');
    } catch (error) {
      Logger.error('ChatPageVoiceController', `销毁语音控制器失败: ${error}`);
    }
  }
}