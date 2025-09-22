/**
 * AI服务状态管理器
 * 统一管理API模式和功能开关状态
 */

import {
  AIServiceMode,
  AIServiceState,
  AIServiceFeatures,
  StateValidationResult,
  StateChangeEvent,
  StateChangeListener,
  StatePresets,
  StateEncoder
} from '../types/AIServiceStateTypes';
import { AppStorage } from './AppStorage';
import { Logger } from './Logger';

// 状态存储键
const AI_SERVICE_STATE_KEY = 'ai_service_state';

/**
 * AI服务状态管理器
 * 单例模式，提供统一的状态管理接口
 */
export class AIServiceStateManager {
  private static instance: AIServiceStateManager;
  private currentState: AIServiceState;
  private listeners: StateChangeListener[] = [];
  private isInitialized: boolean = false;

  private constructor() {
    // 初始化为基础直连模式
    this.currentState = {
      mode: StatePresets.BASIC_DIRECT.mode,
      features: {
        enableWebSearch: StatePresets.BASIC_DIRECT.features.enableWebSearch,
        enableDeepThinking: StatePresets.BASIC_DIRECT.features.enableDeepThinking,
        enableMCPTools: StatePresets.BASIC_DIRECT.features.enableMCPTools
      },
      lastUpdated: Date.now()
    };
  }

  /**
   * 获取单例实例
   */
  static getInstance(): AIServiceStateManager {
    if (!AIServiceStateManager.instance) {
      AIServiceStateManager.instance = new AIServiceStateManager();
    }
    return AIServiceStateManager.instance;
  }

  /**
   * 初始化状态管理器
   */
  async initialize(): Promise<void> {
    try {
      Logger.info('AIServiceStateManager', '正在初始化状态管理器');

      // 从存储中加载状态
      const savedState = await this.loadStateFromStorage();
      if (savedState) {
        // 验证加载的状态
        const validation = this.validateState(savedState);
        if (validation.isValid) {
          this.currentState = savedState;
          Logger.info('AIServiceStateManager', `状态加载成功: ${StateEncoder.getStateString(savedState)}`);
        } else {
          Logger.warn('AIServiceStateManager', `加载的状态无效: ${validation.errorMessage}`);
          // 使用默认状态并保存
          await this.saveStateToStorage();
        }
      } else {
        // 没有保存的状态，使用默认状态并保存
        await this.saveStateToStorage();
        Logger.info('AIServiceStateManager', '使用默认状态并保存');
      }

      this.isInitialized = true;
      Logger.info('AIServiceStateManager', '状态管理器初始化完成');
    } catch (error) {
      Logger.error('AIServiceStateManager', `初始化失败: ${(error as Error).message}`);
      throw new Error(`状态管理器初始化失败: ${(error as Error).message}`);
    }
  }

  /**
   * 获取当前状态
   */
  getCurrentState(): AIServiceState {
    return {
      mode: this.currentState.mode,
      features: {
        enableWebSearch: this.currentState.features.enableWebSearch,
        enableDeepThinking: this.currentState.features.enableDeepThinking,
        enableMCPTools: this.currentState.features.enableMCPTools
      },
      lastUpdated: this.currentState.lastUpdated
    };
  }

  /**
   * 获取当前API模式
   */
  getCurrentMode(): AIServiceMode {
    return this.currentState.mode;
  }

  /**
   * 获取当前功能状态
   */
  getCurrentFeatures(): AIServiceFeatures {
    return {
      enableWebSearch: this.currentState.features.enableWebSearch,
      enableDeepThinking: this.currentState.features.enableDeepThinking,
      enableMCPTools: this.currentState.features.enableMCPTools
    };
  }

  /**
   * 设置新的状态
   */
  async setState(newState: AIServiceState): Promise<StateValidationResult> {
    Logger.info('AIServiceStateManager', `尝试设置新状态: ${StateEncoder.getStateString(newState)}`);

    // 验证新状态
    const validation = this.validateState(newState);
    if (!validation.isValid) {
      Logger.warn('AIServiceStateManager', `状态设置失败: ${validation.errorMessage}`);
      return validation;
    }

    // 保存之前的状态
    const previousState: AIServiceState = {
      mode: this.currentState.mode,
      features: {
        enableWebSearch: this.currentState.features.enableWebSearch,
        enableDeepThinking: this.currentState.features.enableDeepThinking,
        enableMCPTools: this.currentState.features.enableMCPTools
      },
      lastUpdated: this.currentState.lastUpdated
    };

    // 更新状态
    this.currentState = {
      mode: newState.mode,
      features: {
        enableWebSearch: newState.features.enableWebSearch,
        enableDeepThinking: newState.features.enableDeepThinking,
        enableMCPTools: newState.features.enableMCPTools
      },
      lastUpdated: Date.now()
    };

    try {
      // 保存到存储
      await this.saveStateToStorage();

      // 触发状态变更事件
      this.notifyStateChange(previousState, this.currentState);

      Logger.info('AIServiceStateManager', `状态设置成功: ${StateEncoder.getStateString(this.currentState)}`);
      return validation;
    } catch (error) {
      // 回滚状态
      this.currentState = previousState;
      Logger.error('AIServiceStateManager', `状态保存失败，已回滚: ${(error as Error).message}`);
      throw new Error(`状态保存失败: ${(error as Error).message}`);
    }
  }

  /**
   * 设置API模式
   */
  async setMode(mode: AIServiceMode): Promise<StateValidationResult> {
    const newState: AIServiceState = {
      mode,
      features: {
        enableWebSearch: this.currentState.features.enableWebSearch,
        enableDeepThinking: this.currentState.features.enableDeepThinking,
        enableMCPTools: this.currentState.features.enableMCPTools
      },
      lastUpdated: Date.now()
    };

    return await this.setState(newState);
  }

  /**
   * 设置单个功能开关
   */
  async setFeature(featureName: keyof AIServiceFeatures, enabled: boolean): Promise<StateValidationResult> {
    const newFeatures: AIServiceFeatures = {
      enableWebSearch: this.currentState.features.enableWebSearch,
      enableDeepThinking: this.currentState.features.enableDeepThinking,
      enableMCPTools: this.currentState.features.enableMCPTools
    };

    if (featureName === 'enableWebSearch') {
      newFeatures.enableWebSearch = enabled;
    } else if (featureName === 'enableDeepThinking') {
      newFeatures.enableDeepThinking = enabled;
    } else if (featureName === 'enableMCPTools') {
      newFeatures.enableMCPTools = enabled;
    }

    const newState: AIServiceState = {
      mode: this.currentState.mode,
      features: newFeatures,
      lastUpdated: Date.now()
    };

    return await this.setState(newState);
  }

  /**
   * 使用预设状态
   */
  async applyPreset(preset: AIServiceState): Promise<StateValidationResult> {
    const newState: AIServiceState = {
      mode: preset.mode,
      features: {
        enableWebSearch: preset.features.enableWebSearch,
        enableDeepThinking: preset.features.enableDeepThinking,
        enableMCPTools: preset.features.enableMCPTools
      },
      lastUpdated: Date.now()
    };

    return await this.setState(newState);
  }

  /**
   * 验证状态有效性
   */
  validateState(state: AIServiceState): StateValidationResult {
    // 获取当前模式支持的功能
    const supportedFeatures = this.getSupportedFeatures(state.mode);

    // 检查服务器代理模式的限制
    if (state.mode === AIServiceMode.SERVER_PROXY) {
      if (state.features.enableMCPTools) {
        return {
          isValid: false,
          errorMessage: '服务器代理模式不支持MCP工具调用',
          supportedFeatures
        };
      }

      if (state.features.enableDeepThinking) {
        return {
          isValid: false,
          errorMessage: '服务器代理模式不支持深度思考功能',
          supportedFeatures
        };
      }
    }

    return {
      isValid: true,
      errorMessage: null,
      supportedFeatures
    };
  }

  /**
   * 获取指定模式支持的功能
   */
  getSupportedFeatures(mode: AIServiceMode): AIServiceFeatures {
    if (mode === AIServiceMode.DIRECT) {
      // 直连模式支持所有功能
      return {
        enableWebSearch: true,
        enableDeepThinking: true,
        enableMCPTools: true
      };
    } else {
      // 服务器代理模式仅支持联网搜索
      return {
        enableWebSearch: true,
        enableDeepThinking: false,
        enableMCPTools: false
      };
    }
  }

  /**
   * 检查当前状态是否支持指定功能
   */
  isFeatureSupported(featureName: keyof AIServiceFeatures): boolean {
    const supportedFeatures = this.getSupportedFeatures(this.currentState.mode);
    if (featureName === 'enableWebSearch') {
      return supportedFeatures.enableWebSearch;
    } else if (featureName === 'enableDeepThinking') {
      return supportedFeatures.enableDeepThinking;
    } else if (featureName === 'enableMCPTools') {
      return supportedFeatures.enableMCPTools;
    }
    return false;
  }

  /**
   * 获取状态的字符串表示
   */
  getStateString(): string {
    return StateEncoder.getStateString(this.currentState);
  }

  /**
   * 获取状态的数字编码
   */
  getStateCode(): number {
    return StateEncoder.encodeState(this.currentState);
  }

  /**
   * 添加状态变更监听器
   */
  addStateChangeListener(listener: StateChangeListener): void {
    this.listeners.push(listener);
    Logger.debug('AIServiceStateManager', `添加状态监听器，当前监听器数量: ${this.listeners.length}`);
  }

  /**
   * 移除状态变更监听器
   */
  removeStateChangeListener(listener: StateChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
      Logger.debug('AIServiceStateManager', `移除状态监听器，当前监听器数量: ${this.listeners.length}`);
    }
  }

  /**
   * 通知状态变更
   */
  private notifyStateChange(previousState: AIServiceState, newState: AIServiceState): void {
    const event: StateChangeEvent = {
      previousState,
      newState,
      timestamp: Date.now()
    };

    Logger.info('AIServiceStateManager', `通知 ${this.listeners.length} 个状态监听器`);
    this.listeners.forEach((listener, index) => {
      try {
        listener(event);
        Logger.debug('AIServiceStateManager', `状态监听器 ${index} 执行成功`);
      } catch (error) {
        Logger.error('AIServiceStateManager', `状态监听器 ${index} 执行失败: ${(error as Error).message}`);
      }
    });
  }

  /**
   * 从存储加载状态
   */
  private async loadStateFromStorage(): Promise<AIServiceState | null> {
    try {
      const storage = AppStorage.getPreferences();
      const stateStr = await storage.get(AI_SERVICE_STATE_KEY, '') as string;

      if (!stateStr) {
        return null;
      }

      const stateObj = JSON.parse(stateStr) as AIServiceState;
      Logger.debug('AIServiceStateManager', `从存储加载状态: ${stateStr}`);
      return stateObj;
    } catch (error) {
      Logger.error('AIServiceStateManager', `加载状态失败: ${(error as Error).message}`);
      return null;
    }
  }

  /**
   * 保存状态到存储
   */
  private async saveStateToStorage(): Promise<void> {
    try {
      const storage = AppStorage.getPreferences();
      const stateStr = JSON.stringify(this.currentState);
      await storage.put(AI_SERVICE_STATE_KEY, stateStr);
      await storage.flush();
      Logger.debug('AIServiceStateManager', `状态保存到存储: ${stateStr}`);
    } catch (error) {
      Logger.error('AIServiceStateManager', `保存状态失败: ${(error as Error).message}`);
      throw new Error(`保存状态失败: ${(error as Error).message}`);
    }
  }

  /**
   * 检查是否已初始化
   */
  isReady(): boolean {
    return this.isInitialized;
  }

  /**
   * 重置为默认状态
   */
  async reset(): Promise<void> {
    Logger.info('AIServiceStateManager', '重置为默认状态');
    const defaultState: AIServiceState = {
      mode: StatePresets.BASIC_DIRECT.mode,
      features: {
        enableWebSearch: StatePresets.BASIC_DIRECT.features.enableWebSearch,
        enableDeepThinking: StatePresets.BASIC_DIRECT.features.enableDeepThinking,
        enableMCPTools: StatePresets.BASIC_DIRECT.features.enableMCPTools
      },
      lastUpdated: Date.now()
    };
    await this.setState(defaultState);
  }

  /**
   * 销毁状态管理器
   */
  destroy(): void {
    this.listeners = [];
    this.isInitialized = false;
    Logger.info('AIServiceStateManager', '状态管理器已销毁');
  }
}