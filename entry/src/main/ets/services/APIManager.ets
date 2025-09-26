/**
 * API管理器 - 统一接口层
 * 集成AIServiceStateManager实现统一状态管理
 */

import { APIMode, AIProvider, ChatRequest, ChatResponse, ConnectionTestResult, APIManagerState, ModeConfig } from '../types/APITypes';
import { ChatRequest as LegacyChatRequest, SimpleMessage, ChatResponse as LegacyChatResponse } from '../models/ChatModels';
import { ApiService } from './ApiService';
import { DirectAPIService } from './DirectAPIService';
import { AppContext } from '../utils/AppContext';
import { AppStorage } from '../utils/AppStorage';
import { Logger } from '../utils/Logger';
import { APIKeyManager } from '../utils/APIKeyManager';
import { IDirectAPIService, IApiService, IAPIKeyManager } from '../di/ServiceInterfaces';
import { APIKeyConfig } from '../types/APIKeyTypes';
import { ServerEndpoint } from '../utils/ServerConfigManager';
import { HybridChatService, HybridChatRequest, HybridChatResponse } from './HybridChatService';
import { AIServiceStateManager } from '../utils/AIServiceStateManager';
import {
  AIServiceMode,
  AIServiceState,
  AIServiceFeatures,
  StateChangeEvent,
  StateValidationResult
} from '../types/AIServiceStateTypes';

/**
 * 简化的聊天选项接口
 */
interface SimpleChatOptions {
  stream?: boolean;
  max_tokens?: number;
  temperature?: number;
}

export class APIManager {
  private static instance: APIManager;
  private apiService: IApiService;
  private directAPIService: IDirectAPIService;
  private apiKeyManager: IAPIKeyManager;
  private hybridChatService: HybridChatService;
  private stateManager: AIServiceStateManager;
  private state: APIManagerState;
  private modeChangeListeners: Array<(mode: APIMode) => void> = [];

  // 支持依赖注入的构造函数
  constructor(
    directApiService?: IDirectAPIService,
    apiService?: IApiService,
    apiKeyManager?: IAPIKeyManager
  ) {
    this.apiService = apiService || new ApiService();
    this.directAPIService = directApiService || new DirectAPIService();
    this.apiKeyManager = apiKeyManager || APIKeyManager.getInstance();
    this.hybridChatService = HybridChatService.getInstance();
    this.stateManager = AIServiceStateManager.getInstance();
    this.state = {
      currentMode: APIMode.DIRECT_CALL,
      currentProvider: AIProvider.SILICONFLOW,
      isInitialized: false
    };

    // 监听状态变更
    this.stateManager.addStateChangeListener((event: StateChangeEvent) => {
      this.onStateChange(event);
    });
  }
  
  static getInstance(): APIManager {
    if (!APIManager.instance) {
      APIManager.instance = new APIManager();
    }
    return APIManager.instance;
  }
  
  /**
   * 使用依赖注入创建实例
   */
  static createWithDI(
    directApiService: IDirectAPIService,
    apiService: IApiService,
    apiKeyManager: IAPIKeyManager
  ): APIManager {
    if (!APIManager.instance) {
      APIManager.instance = new APIManager(directApiService, apiService, apiKeyManager);
    }
    return APIManager.instance;
  }
  
  /**
   * 初始化API管理器
   */
  async initialize(): Promise<void> {
    try {
      Logger.info('APIManager', '开始初始化API管理器');

      // 首先初始化状态管理器
      await this.stateManager.initialize();

      // 获取当前状态并同步到APIManager
      const currentState = this.stateManager.getCurrentState();
      this.syncStateFromManager(currentState);

      // 初始化APIKeyManager并加载API密钥到DirectAPIService
      await this.initializeAPIKeys();

      // 初始化DirectAPIService的LocalToolManager
      await this.initializeToolManager();

      this.state.isInitialized = true;
      Logger.info('APIManager', `初始化完成，模式: ${this.getAPIMode()}, 厂商: ${this.state.currentProvider}`);
    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('APIManager', `初始化失败: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }
  
  /**
   * 检查服务器配置是否可用
   */
  private async checkServerConfig(): Promise<boolean> {
    try {
      const appConfigModule = await import('../utils/ServerConfigManager');
      const serverConfigManager = appConfigModule.ServerConfigManager.getInstance();
      const currentServer = serverConfigManager.getCurrentServer();
      
      // 检查IP和端口是否有效，localhost 和 127.0.0.1 都是有效配置
      if (!currentServer.ip || 
          currentServer.ip.trim() === '' ||
          currentServer.ip === 'YOUR_SERVER_IP' ||
          !currentServer.port) {
        Logger.info('APIManager', '检测到服务器配置为空或为占位符');
        return false;
      }
      
      return true;
    } catch (error) {
      Logger.error('APIManager', `检查服务器配置失败: ${(error as Error).message}`);
      return false;
    }
  }
  
  /**
   * 确保服务器配置可用，如果不可用则自动配置为 localhost:8080
   */
  private async ensureServerConfig(): Promise<void> {
    try {
      const appConfigModule = await import('../utils/ServerConfigManager');
      const serverConfigManager = appConfigModule.ServerConfigManager.getInstance();
      const currentServer = serverConfigManager.getCurrentServer();
      
      // 检查当前服务器配置是否为空或占位符
      if (!currentServer.ip || 
          currentServer.ip.trim() === '' ||
          currentServer.ip === 'YOUR_SERVER_IP') {
        
        Logger.info('APIManager', '自动配置服务器地址为 localhost:8080');
        
        // 创建默认的服务器端点
        const defaultServerEndpoint: ServerEndpoint = {
          ip: 'localhost',
          port: 8080,
          protocol: 'http',
          wsProtocol: 'ws',
          description: '本地开发服务器'
        };
        
        // 设置服务器配置
        await serverConfigManager.setCurrentServer(defaultServerEndpoint);
        
        Logger.info('APIManager', '服务器地址已自动配置为: http://localhost:8080');
      } else {
        Logger.info('APIManager', `服务器地址已配置为: ${currentServer.protocol}://${currentServer.ip}:${currentServer.port}`);
      }
    } catch (error) {
      Logger.error('APIManager', `自动配置服务器地址失败: ${(error as Error).message}`);
      throw new Error(`自动配置服务器地址失败: ${(error as Error).message}`);
    }
  }
  
  /**
   * 初始化API密钥
   */
  private async initializeAPIKeys(): Promise<void> {
    try {
      Logger.info('APIManager', '开始初始化API密钥');
      
      // 使用注入的 APIKeyManager 实例
      if (!this.apiKeyManager.isInitialized()) {
        await this.apiKeyManager.initialize();
      }
      
      // 获取所有配置好的API密钥
      const allConfigs = this.apiKeyManager.getAllConfigs();
      const apiKeys = new Map<AIProvider, string>();
      
      allConfigs.forEach((config, provider) => {
        if (config.apiKey && config.apiKey.trim().length > 0 && config.enabled) {
          apiKeys.set(provider, config.apiKey);
          Logger.info('APIManager', `加载${provider}厂商API密钥: ${config.apiKey.substring(0, 10)}...`);
        }
      });
      
      // 将API密钥设置到DirectAPIService
      if (apiKeys.size > 0) {
        this.directAPIService.setApiKeys(apiKeys);
        Logger.info('APIManager', `成功加载${apiKeys.size}个厂商的API密钥`);
      } else {
        Logger.warn('APIManager', '没有找到有效的API密钥配置');
      }
      
    } catch (error) {
      Logger.error('APIManager', `初始化API密钥失败: ${(error as Error).message}`);
      throw new Error(error);
    }
  }

  /**
   * 初始化工具管理器
   */
  private async initializeToolManager(): Promise<void> {
    try {
      // 从AppContext获取context（如果可用）
      const appContext = AppContext.getInstance();
      const context = appContext.getContext();

      if (context && this.directAPIService instanceof DirectAPIService) {
        (this.directAPIService as DirectAPIService).initializeLocalToolManager(context);
        Logger.info('APIManager', 'DirectAPIService工具管理器初始化完成');
      } else {
        Logger.warn('APIManager', '无法初始化工具管理器：context不可用或DirectAPIService类型不匹配');
      }
    } catch (error) {
      Logger.warn('APIManager', `工具管理器初始化失败: ${error}, 工具调用功能将不可用`);
    }
  }

  /**
   * 发送聊天请求 - 基于统一状态管理
   */
  async sendChatRequest(request: ChatRequest): Promise<ChatResponse> {
    if (!this.state.isInitialized) {
      await this.initialize();
    }

    // 验证请求参数
    if (!request.model) {
      throw new Error('模型不能为空');
    }

    // 获取当前状态
    const currentState = this.stateManager.getCurrentState();

    try {
      if (currentState.mode === AIServiceMode.DIRECT) {
        // 在直连模式下，根据模型确定正确的厂商
        const modelProvider = await this.getProviderByModel(request.model);
        if (modelProvider) {
          // 使用带工具支持的聊天请求
          if (this.directAPIService instanceof DirectAPIService) {
            const response = await (this.directAPIService as DirectAPIService).sendChatRequestWithTools(request, modelProvider, true);
            // 处理工具调用，并将结果返回给大模型生成最终回答
            return await (this.directAPIService as DirectAPIService).processToolCallsInResponse(response, modelProvider, request);
          } else {
            // 回退到普通聊天请求
            return await this.directAPIService.sendChatRequest(request, modelProvider);
          }
        } else {
          throw new Error(`找不到支持模型 ${request.model} 的厂商`);
        }
      } else {
        // 转换为 ApiService 需要的 ChatRequest 格式
        const messages: SimpleMessage[] = request.messages.map(msg => {
          const simpleMsg: SimpleMessage = { role: msg.role, content: msg.content };
          return simpleMsg;
        });
        
        // 在服务器代理模式下，根据模型确定正确的厂商
        const modelProvider = await this.getProviderByModel(request.model);
        const serverProvider = modelProvider === AIProvider.GLM ? 'zhipu' : 'siliconflow';
        // modelProvider === AIProvider.GEMINI ? 'google' : // 已禁用 - 暂不可用
        
        const chatRequest: LegacyChatRequest = {
          provider: serverProvider,
          model: request.model,
          messages: messages,
          enable_web: request.enable_web || false
        };
        
        const chatResponse = await this.apiService.sendChatMessage(chatRequest);
        
        // 转换为标准 ChatResponse 格式
        const response: ChatResponse = {
          id: 'chatcmpl-' + Date.now(),
          object: 'chat.completion',
          created: Math.floor(Date.now() / 1000),
          model: request.model || 'Qwen/Qwen2.5-7B-Instruct',
          choices: [{
            index: 0,
            message: {
              role: 'assistant',
              content: chatResponse.content || '无回复内容'
            },
            finish_reason: 'stop'
          }],
          usage: {
            prompt_tokens: 0,
            completion_tokens: 0,
            total_tokens: 0
          }
        };
        
        return response;
      }
    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('APIManager', `聊天请求失败: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }

  /**
   * 智能聊天请求 - 基于当前状态自动选择功能
   */
  async sendSmartChatRequest(
    message: string,
    model: string,
    systemPrompt?: string,
    options?: SimpleChatOptions
  ): Promise<HybridChatResponse> {
    if (!this.state.isInitialized) {
      await this.initialize();
    }

    // 验证请求参数
    if (!message || !model) {
      throw new Error('消息和模型不能为空');
    }

    // 获取当前状态
    const currentState = this.stateManager.getCurrentState();

    // 验证当前状态是否有效
    const validation = this.stateManager.validateState(currentState);
    if (!validation.isValid) {
      throw new Error(validation.errorMessage || '当前状态无效');
    }

    try {
      // 根据模型确定提供商
      const modelProvider = await this.getProviderByModel(model);
      if (!modelProvider) {
        throw new Error(`找不到支持模型 ${model} 的厂商`);
      }

      // 构建混合聊天请求，基于当前状态自动设置功能
      const hybridRequest: HybridChatRequest = {
        message: message,
        model: model,
        provider: modelProvider,
        enableSearch: currentState.features.enableWebSearch,
        enableTools: currentState.features.enableMCPTools,
        systemPrompt: systemPrompt,
        stream: options?.stream || false,
        max_tokens: options?.max_tokens,
        temperature: options?.temperature
      };

      Logger.info('APIManager', `发送智能聊天请求: ${message.substring(0, 50)}...`);
      Logger.info('APIManager', `当前状态: ${this.stateManager.getStateString()}`);
      Logger.info('APIManager', `功能配置: 搜索=${hybridRequest.enableSearch}, 工具=${hybridRequest.enableTools}`);

      // 发送混合聊天请求
      const response = await this.hybridChatService.sendHybridChatRequest(hybridRequest);

      Logger.info('APIManager', `智能聊天请求完成，总耗时: ${response.totalTime}ms`);
      return response;

    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('APIManager', `智能聊天请求失败: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }

  /**
   * 发送混合聊天请求（支持工具调用和搜索）
   * @deprecated 请使用 sendSmartChatRequest 方法
   */
  async sendHybridChatRequest(
    message: string,
    model: string,
    systemPrompt?: string,
    options?: SimpleChatOptions
  ): Promise<HybridChatResponse> {
    if (!this.state.isInitialized) {
      await this.initialize();
    }

    // 验证请求参数
    if (!message || !model) {
      throw new Error('消息和模型不能为空');
    }

    try {
      // 根据模型确定提供商
      const modelProvider = await this.getProviderByModel(model);
      if (!modelProvider) {
        throw new Error(`找不到支持模型 ${model} 的厂商`);
      }

      // 构建混合聊天请求（使用默认配置）
      const hybridRequest: HybridChatRequest = {
        message: message,
        model: model,
        provider: modelProvider,
        enableSearch: false,
        enableTools: true,
        systemPrompt: systemPrompt,
        stream: options?.stream || false,
        max_tokens: options?.max_tokens,
        temperature: options?.temperature
      };

      Logger.info('APIManager', `发送混合聊天请求: ${message.substring(0, 50)}...`);
      Logger.info('APIManager', `模型: ${model}, 提供商: ${modelProvider}`);
      Logger.info('APIManager', `启用搜索: ${hybridRequest.enableSearch}, 启用工具: ${hybridRequest.enableTools}`);

      // 发送混合聊天请求
      const response = await this.hybridChatService.sendHybridChatRequest(hybridRequest);

      Logger.info('APIManager', `混合聊天请求完成，总耗时: ${response.totalTime}ms`);
      Logger.info('APIManager', `搜索使用: ${response.searchUsed}, 工具使用: ${response.toolsUsed}`);

      return response;

    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('APIManager', `混合聊天请求失败: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }

  /**
   * 检查是否支持工具调用
   */
  isToolsSupported(): boolean {
    return this.hybridChatService.isToolsSupported();
  }

  /**
   * 获取可用工具数量
   */
  getAvailableToolsCount(): number {
    return this.hybridChatService.getAvailableToolsCount();
  }

  /**
   * 设置API调用模式
   * @deprecated 此方法已重构，现在通过状态管理器处理
   */
  private async setAPIModeOld(mode: APIMode): Promise<void> {
    // 此方法已被新的setAPIMode方法替代
    // 新方法在文件末尾，使用统一状态管理器
    throw new Error('请使用新的setAPIMode方法');
  }
  
  /**
   * 获取当前API模式
   * @deprecated 请使用 getAPIMode() 方法
   */
  getCurrentMode(): APIMode {
    return this.getAPIMode();
  }
  
  /**
   * 检查服务器配置是否可用
   */
  async isServerConfigAvailable(): Promise<boolean> {
    return await this.checkServerConfig();
  }
  
  /**
   * 设置当前厂商
   */
  async setCurrentProvider(provider: AIProvider): Promise<void> {
    try {
      this.state.currentProvider = provider;
      await this.saveCurrentProvider(provider);
      Logger.info('APIManager', `当前厂商已切换到: ${provider}`);
    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('APIManager', `设置厂商失败: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }
  
  /**
   * 获取当前厂商
   */
  getCurrentProvider(): AIProvider {
    return this.state.currentProvider;
  }
  
  /**
   * 测试API连接
   */
  async testConnection(): Promise<ConnectionTestResult> {
    try {
      const startTime = Date.now();
      
      if (this.state.currentMode === APIMode.DIRECT_CALL) {
        const success = await this.directAPIService.testConnection(this.state.currentProvider);
        const latency = Date.now() - startTime;
        
        const result: ConnectionTestResult = {
          success: success,
          mode: this.state.currentMode,
          provider: this.state.currentProvider,
          message: success ? `${this.state.currentProvider} 连接正常` : `${this.state.currentProvider} 连接失败`,
          latency: latency
        };
        
        this.state.lastTestResult = result;
        return result;
        
      } else {
        const success = await this.apiService.testConnection();
        const latency = Date.now() - startTime;
        
        const result: ConnectionTestResult = {
          success: success,
          mode: this.state.currentMode,
          message: success ? '服务器代理连接正常' : '服务器代理连接失败',
          latency: latency
        };
        
        this.state.lastTestResult = result;
        return result;
      }
      
    } catch (error) {
      const result: ConnectionTestResult = {
        success: false,
        mode: this.state.currentMode,
        provider: this.state.currentProvider,
        message: `连接测试异常: ${(error as Error).message}`
      };
      
      this.state.lastTestResult = result;
      return result;
    }
  }
  
  /**
   * 获取模式描述
   */
  static getModeDescription(mode: APIMode): string {
    const configs = new Map<APIMode, string>();
    configs.set(APIMode.SERVER_PROXY, '通过服务器代理调用AI接口');
    configs.set(APIMode.DIRECT_CALL, '客户端直接调用AI厂商接口');
    return configs.get(mode) || '未知模式';
  }
  
  /**
   * 获取模式显示名称
   */
  static getModeDisplayName(mode: APIMode): string {
    const names = new Map<APIMode, string>();
    names.set(APIMode.SERVER_PROXY, '服务器代理');
    names.set(APIMode.DIRECT_CALL, '直接调用');
    return names.get(mode) || '未知';
  }
  
  /**
   * 获取厂商显示名称
   */
  static getProviderDisplayName(provider: AIProvider): string {
    const names = new Map<AIProvider, string>();
    names.set(AIProvider.GLM, 'GLM智谱');
    names.set(AIProvider.SILICONFLOW, '硅基流动');
    names.set(AIProvider.GEMINI, 'Google Gemini');
    return names.get(provider) || '未知厂商';
  }
  
  /**
   * 获取可用厂商列表
   */
  getAvailableProviders(): AIProvider[] {
    return [AIProvider.GLM, AIProvider.SILICONFLOW]; // AIProvider.GEMINI 已禁用 - 暂不可用
  }
  
  /**
   * 获取管理器状态
   */
  getState(): APIManagerState {
    return {
      currentMode: this.state.currentMode,
      currentProvider: this.state.currentProvider,
      isInitialized: this.state.isInitialized,
      lastTestResult: this.state.lastTestResult
    };
  }
  
  /**
   * 销毁管理器
   */
  destroy(): void {
    Logger.info('APIManager', 'API管理器已销毁');
  }
  
  /**
   * 根据模型名称获取对应的厂商
   */
  async getProviderByModel(modelName: string): Promise<AIProvider | null> {
    try {
      // 在直连模式下，使用DirectAPIService的匹配逻辑
      return this.directAPIService.getProviderByModel(modelName);
    } catch (error) {
      Logger.error('APIManager', `获取模型厂商失败: ${(error as Error).message}`);
      return null;
    }
  }
  
  /**
   * 验证模型与厂商的匹配性
   */
  async validateModelProviderMatch(modelName: string, provider: AIProvider): Promise<boolean> {
    try {
      return this.directAPIService.validateModelProviderMatch(modelName, provider);
    } catch (error) {
      Logger.error('APIManager', `验证模型厂商匹配性失败: ${(error as Error).message}`);
      return false;
    }
  }
  
  /**
   * 获取所有支持的模型到厂商的映射
   */
  async getModelProviderMap(): Promise<Map<string, AIProvider>> {
    try {
      return this.directAPIService.getModelProviderMap();
    } catch (error) {
      Logger.error('APIManager', `获取模型厂商映射失败: ${(error as Error).message}`);
      return new Map();
    }
  }
  
  /**
   * 加载保存的厂商配置
   */
  private async loadSavedProvider(): Promise<AIProvider> {
    try {
      // 这里可以从AppStorage中加载保存的厂商配置
      // 暂时返回默认值
      return AIProvider.SILICONFLOW;
    } catch (error) {
      Logger.error('APIManager', `加载厂商配置失败: ${(error as Error).message}`);
      return AIProvider.SILICONFLOW;
    }
  }
  
  /**
   * 保存当前厂商配置
   */
  private async saveCurrentProvider(provider: AIProvider): Promise<void> {
    try {
      // 这里可以将厂商配置保存到AppStorage
      // 暂时只记录日志
      Logger.info('APIManager', `厂商配置已保存: ${provider}`);
    } catch (error) {
      Logger.error('APIManager', `保存厂商配置失败: ${(error as Error).message}`);
    }
  }
  
  /**
   * 添加模式变更监听器
   */
  addModeChangeListener(listener: (mode: APIMode) => void): void {
    this.modeChangeListeners.push(listener);
  }
  
  /**
   * 移除模式变更监听器
   */
  removeModeChangeListener(listener: (mode: APIMode) => void): void {
    const index = this.modeChangeListeners.indexOf(listener);
    if (index > -1) {
      this.modeChangeListeners.splice(index, 1);
    }
  }
  
  /**
   * 通知所有模式变更监听器
   */
  private notifyModeChangeListeners(mode: APIMode): void {
    this.modeChangeListeners.forEach(listener => {
      try {
        listener(mode);
      } catch (error) {
        Logger.error('APIManager', `模式变更监听器执行失败: ${(error as Error).message}`);
      }
    });
  }

  /**
   * 状态变更回调
   */
  private onStateChange(event: StateChangeEvent): void {
    Logger.info('APIManager', '收到状态变更事件');
    this.syncStateFromManager(event.newState);

    // 通知传统的模式监听器
    const newAPIMode = this.convertToAPIMode(event.newState.mode);
    const oldAPIMode = this.convertToAPIMode(event.previousState.mode);

    if (newAPIMode !== oldAPIMode) {
      this.notifyModeChangeListeners(newAPIMode);
    }
  }

  /**
   * 从状态管理器同步状态到APIManager
   */
  private syncStateFromManager(state: AIServiceState): void {
    const apiMode = this.convertToAPIMode(state.mode);
    this.state.currentMode = apiMode;

    Logger.debug('APIManager', `状态已同步: 模式=${apiMode}, 功能=${JSON.stringify(state.features)}`);
  }

  /**
   * 转换AIServiceMode到APIMode
   */
  private convertToAPIMode(serviceMode: AIServiceMode): APIMode {
    return serviceMode === AIServiceMode.DIRECT ? APIMode.DIRECT_CALL : APIMode.SERVER_PROXY;
  }

  /**
   * 转换APIMode到AIServiceMode
   */
  private convertToServiceMode(apiMode: APIMode): AIServiceMode {
    return apiMode === APIMode.DIRECT_CALL ? AIServiceMode.DIRECT : AIServiceMode.SERVER_PROXY;
  }

  /**
   * 获取当前API模式
   */
  getAPIMode(): APIMode {
    return this.convertToAPIMode(this.stateManager.getCurrentMode());
  }

  /**
   * 设置API模式 - 使用状态管理器
   */
  async setAPIMode(mode: APIMode): Promise<string | null> {
    const serviceMode = this.convertToServiceMode(mode);
    const result = await this.stateManager.setMode(serviceMode);

    if (!result.isValid) {
      return result.errorMessage;
    }

    return null;
  }

  /**
   * 获取当前功能状态
   */
  getCurrentFeatures(): AIServiceFeatures {
    return this.stateManager.getCurrentFeatures();
  }

  /**
   * 设置功能开关
   */
  async setFeature(featureName: 'enableWebSearch' | 'enableDeepThinking' | 'enableMCPTools', enabled: boolean): Promise<string | null> {
    const result = await this.stateManager.setFeature(featureName, enabled);

    if (!result.isValid) {
      return result.errorMessage;
    }

    return null;
  }

  /**
   * 检查功能是否支持
   */
  isFeatureSupported(featureName: 'enableWebSearch' | 'enableDeepThinking' | 'enableMCPTools'): boolean {
    return this.stateManager.isFeatureSupported(featureName);
  }

  /**
   * 获取状态字符串表示
   */
  getStateString(): string {
    return this.stateManager.getStateString();
  }

  /**
   * 验证当前状态
   */
  validateCurrentState(): StateValidationResult {
    return this.stateManager.validateState(this.stateManager.getCurrentState());
  }
}

export { APIMode, AIProvider };