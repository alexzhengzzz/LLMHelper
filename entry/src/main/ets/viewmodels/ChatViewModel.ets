import { Message, MessageRole, ChatRequest, Provider, SimpleMessage, SystemPrompt, Session, ThinkingStatus, ThinkingStep, ToolCall } from '../models/ChatModels';
import { ApiService } from '../services/ApiService';
import { APIManager, APIMode, AIProvider } from '../services/APIManager';
import { ChatRequest as APIChatRequest, ChatMessage as APIChatMessage } from '../types/APITypes';
import { AppStorage, ModelConfig } from '../utils/AppStorage';
import { TTSService, TTSState, TTSCallbacks } from '../services/TTSService';
import { AutoTTSService } from '../services/AutoTTSService';
import { SessionManager } from '../utils/SessionManager';
import { HybridChatService, HybridChatRequest, HybridChatResponse } from '../services/HybridChatService';
import { MessageEnhancer, SearchInfo } from '../services/MessageEnhancer';
import { DeepThinkingService, DeepThinkingResult, DeepThinkingCallbacks } from '../services/DeepThinkingService';
import { Logger, LogContext } from '../utils/Logger';
import { ErrorManager } from '../utils/ErrorManager';
import { ErrorType, ErrorCode, ErrorLevel, ErrorContext } from '../types/ErrorTypes';
import { ServerConfigManager, ServerEndpoint } from '../utils/ServerConfigManager';
import { ToolCallResult } from '../types/MCPTypes';

// 用于描述从存储中反序列化的消息对象
interface StoredMessage {
  id?: string;
  __ob_id?: string;
  role?: string;
  __ob_role?: string;
  content?: string;
  __ob_content?: string;
  timestamp?: number;
  __ob_timestamp?: number;
  isLoading?: boolean;
  __ob_isLoading?: boolean;
  webUsed?: boolean;
  __ob_webUsed?: boolean;
  searchInfo?: string;
  __ob_searchInfo?: string;
}

// 自动播报状态接口
interface AutoTTSStatus {
  isEnabled: boolean;
  isPlaying: boolean;
  queueLength: number;
}

// 会话统计信息视图接口
interface SessionStatsView {
  totalSessions: number;
  maxSessions: number;
  currentSessionName: string | null;
}

// 音频播放状态信息接口
interface AudioStateInfo {
  messagePlaying: boolean;
  ttsPlaying: boolean;
  currentMessage: string | null;
  audioLock: boolean;
}

// 工具调用状态接口
interface ToolCallState {
  isToolsEnabled: boolean;
  toolsSupported: boolean;
  availableToolsCount: number;
  executingTools: boolean;
  lastToolCalls?: ToolCall[];
  lastToolResults?: ToolCallResult[];
}

/**
 * 聊天功能ViewModel - 处理聊天相关的业务逻辑
 */
@ObservedV2
export class ChatViewModel {
  @Trace messages: Message[] = [];
  @Trace isLoading: boolean = false;
  @Trace currentProvider: string = '';
  @Trace currentModel: string = '';
  @Trace providers: Provider[] = [];
  @Trace systemPrompts: SystemPrompt[] = [];
  // @Trace selectedSystemPrompt: SystemPrompt | null = null; // 已移除：不再使用全局状态，改用会话绑定

  // 会话管理相关属性
  @Trace currentSession: Session | null = null;
  @Trace sessions: Session[] = [];

  private apiService: ApiService;
  public apiManager: APIManager;
  private ttsService: TTSService;
  private autoTTSService: AutoTTSService;
  private sessionManager: SessionManager;
  private hybridChatService: HybridChatService;
  private deepThinkingService: DeepThinkingService;
  private audioPlaybackStateManager: AudioPlaybackStateManager;
  private serverConfigManager: ServerConfigManager;
  
  // 音频播放锁，防止并发播放
  private audioPlaybackLock: boolean = false;
  
  // 跟踪TTS回调状态，防止华为TTS重复回调
  private ttsCallbackStates: Map<string, boolean> = new Map<string, boolean>();
  
  // 深度思考相关
  @Trace currentThinkingMessageId: string = '';

  // 工具调用相关
  @Trace isToolsEnabled: boolean = false;
  @Trace executingTools: boolean = false;

  constructor() {
    this.apiService = new ApiService();
    this.apiManager = APIManager.getInstance();
    this.ttsService = TTSService.getInstance();
    this.autoTTSService = AutoTTSService.getInstance();
    this.sessionManager = SessionManager.getInstance();
    this.hybridChatService = HybridChatService.getInstance();
    this.deepThinkingService = DeepThinkingService.getInstance();
    this.audioPlaybackStateManager = new AudioPlaybackStateManager();
    this.serverConfigManager = ServerConfigManager.getInstance();
    
    // 添加会话数据清除监听器
    AppStorage.addSessionDataClearedListener(() => this.onSessionDataCleared());
    
    // 添加服务器配置变更监听器
    this.serverConfigManager.addConfigChangeListener((config: ServerEndpoint) => {
      this.onServerConfigChanged(config);
    });
    
    // 添加API模式变更监听器
    this.apiManager.addModeChangeListener((mode: APIMode) => {
      this.onAPIModeChanged(mode);
    });
  }

  async loadInitialData(): Promise<void> {
    try {
      // 初始化会话管理
      await this.initializeSessions();
      
      // 加载当前会话的消息
      await this.loadMessages();
      await this.loadProviders();
      await this.loadSystemPrompts();
      
      
      // 初始化自动播报服务
      await this.initializeAutoTTS();
    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'ChatViewModel';
      errorContext.function = 'loadInitialData';
      errorContext.additionalInfo = JSON.stringify({
        errorType: 'InitializationFailed'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        errorManager.handleError(
          errorManager.createError(
            ErrorType.SYSTEM,
            ErrorCode.SYSTEM_INITIALIZATION_FAILED,
            `加载初始数据失败: ${error.message}`,
            errorContext,
            ErrorLevel.ERROR,
            error
          )
        );
      }
    }
  }

  /**
   * 初始化会话管理
   */
  private async initializeSessions(): Promise<void> {
    try {
      Logger.info('ChatViewModel', '初始化会话管理');
      
      // 确保有默认会话
      await this.sessionManager.ensureDefaultSession();
      
      // 加载所有会话
      await this.loadSessions();
      
      // 加载当前会话
      await this.loadCurrentSession();
      
      Logger.info('ChatViewModel', '会话管理初始化完成');
    } catch (error) {
      Logger.error('ChatViewModel', `初始化会话管理失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 加载所有会话列表
   */
  async loadSessions(): Promise<void> {
    try {
      this.sessions = await this.sessionManager.getSessions();
      Logger.info('ChatViewModel', `加载了 ${this.sessions.length} 个会话`);
    } catch (error) {
      Logger.error('ChatViewModel', `加载会话列表失败: ${error}`);
      this.sessions = [];
    }
  }

  /**
   * 加载当前会话
   */
  async loadCurrentSession(): Promise<void> {
    try {
      const currentSessionId = await this.sessionManager.getCurrentSessionId();
      if (currentSessionId) {
        this.currentSession = this.sessions.find(s => s.id === currentSessionId) || null;
        Logger.info('ChatViewModel', `当前会话: ${this.currentSession?.name || 'null'}`);
      } else {
        Logger.warn('ChatViewModel', '没有找到当前会话ID');
      }
    } catch (error) {
      Logger.error('ChatViewModel', `加载当前会话失败: ${error}`);
    }
  }

  /**
   * 处理深度思考消息
   */
  private async handleDeepThinking(
    content: string,
    assistantMessage: Message,
    enableWebSearch: boolean
  ): Promise<void> {
    Logger.info('ChatViewModel', '开始深度思考处理');
    
    // 设置当前思考消息ID
    this.currentThinkingMessageId = assistantMessage.id;
    
    // 获取当前会话绑定的系统提示词
    const sessionPrompt = this.getCurrentSessionSystemPrompt();
    const filteredMessages = this.messages
      .filter(msg => !msg.isLoading && msg.role !== MessageRole.SYSTEM)
      .map(msg => ({
        role: msg.role === MessageRole.USER ? 'user' : 'assistant',
        content: msg.content
      } as SimpleMessage));

    // 添加系统提示词
    const finalMessages = [...filteredMessages];
    if (sessionPrompt) {
      finalMessages.unshift({
        role: 'system',
        content: sessionPrompt.content
      });
    }

    // 定义深度思考回调
    const callbacks: DeepThinkingCallbacks = {
      onStepStart: (step) => {
        Logger.info('ChatViewModel', `步骤开始: ${step.title}`);
        assistantMessage.thinkingStatus = this.mapThinkingStatus(step.id);
        assistantMessage.thinkingSteps = [...assistantMessage.thinkingSteps || []];
        // 找到并更新步骤状态
        const stepIndex = assistantMessage.thinkingSteps.findIndex(s => s.id === step.id);
        if (stepIndex >= 0) {
          assistantMessage.thinkingSteps[stepIndex] = step;
        } else {
          assistantMessage.thinkingSteps.push(step);
        }
      },
      onStepComplete: (step) => {
        Logger.info('ChatViewModel', `步骤完成: ${step.title}, 耗时: ${step.duration}ms`);
        assistantMessage.thinkingStatus = this.mapThinkingStatus(step.id);
        assistantMessage.thinkingSteps = [...assistantMessage.thinkingSteps || []];
        // 更新步骤状态
        const stepIndex = assistantMessage.thinkingSteps.findIndex(s => s.id === step.id);
        if (stepIndex >= 0) {
          assistantMessage.thinkingSteps[stepIndex] = step;
        } else {
          assistantMessage.thinkingSteps.push(step);
        }
      },
      onStepError: (step, error) => {
        Logger.error('ChatViewModel', `步骤失败: ${step.title}, 错误: ${error}`);
        assistantMessage.thinkingSteps = [...assistantMessage.thinkingSteps || []];
        const stepIndex = assistantMessage.thinkingSteps.findIndex(s => s.id === step.id);
        if (stepIndex >= 0) {
          assistantMessage.thinkingSteps[stepIndex] = step;
        } else {
          assistantMessage.thinkingSteps.push(step);
        }
      },
      onComplete: (result) => {
        Logger.info('ChatViewModel', `深度思考完成，总耗时: ${result.totalTime}ms，降级: ${result.fallbackUsed}`);
        assistantMessage.thinkingStatus = ThinkingStatus.COMPLETED;
        assistantMessage.thinkingSteps = result.steps;
      },
      onError: (error) => {
        Logger.error('ChatViewModel', `深度思考失败: ${error}`);
        assistantMessage.thinkingStatus = ThinkingStatus.FAILED;
      }
    };

    // 启动深度思考过程
    const thinkingResult = await this.deepThinkingService.startDeepThinking(
      content,
      this.currentModel,
      finalMessages,
      callbacks,
      {
        enableWebSearch: false,
        preferFastResponse: content.length <= 80,
        maxSteps: 6
      }
    );

    // 处理结果
    if (thinkingResult.success) {
      assistantMessage.content = thinkingResult.finalAnswer;
      assistantMessage.thinkingStatus = ThinkingStatus.COMPLETED;
      assistantMessage.thinkingSteps = thinkingResult.steps;
      Logger.info('ChatViewModel', '深度思考成功完成');
    } else {
      // 深度思考失败，回退到简单模式
      Logger.warn('ChatViewModel', `深度思考失败，回退到简单模式: ${thinkingResult.error}`);
      await this.handleSimpleMessage(content, assistantMessage, enableWebSearch);
      assistantMessage.thinkingStatus = ThinkingStatus.FAILED;
    }
    
    // 清除当前思考消息ID
    this.currentThinkingMessageId = '';
  }

  /**
   * 处理普通消息（简单模式）
   */
  private async handleSimpleMessage(
    content: string,
    assistantMessage: Message,
    enableWebSearch: boolean
  ): Promise<void> {
    const currentMode = this.apiManager.getCurrentMode();
    
    if (currentMode === APIMode.DIRECT_CALL && enableWebSearch) {
      // 直连模式 + 联网搜索：使用混合聊天服务
      const hybridRequest: HybridChatRequest = {
        message: content,
        model: this.currentModel,
        provider: this.getAIProviderByName(this.currentProvider),
        enableSearch: enableWebSearch,
        enableTools: true, // 启用工具调用
        stream: false,
        max_tokens: 1000,
        temperature: 0.7
      };
  
      const hybridResponse = await this.hybridChatService.sendHybridChatRequest(hybridRequest);

      assistantMessage.content = hybridResponse.response.choices[0]?.message?.content || '未收到有效响应';

      // 同步工具调用状态
      if (hybridResponse.response.tool_status) {
        assistantMessage.toolStatus = hybridResponse.response.tool_status;
      }

      if (hybridResponse.searchUsed && hybridResponse.searchInfo) {
        assistantMessage.webUsed = true;
        assistantMessage.searchInfo = this.formatSearchInfoSimple(hybridResponse.searchInfo);
        assistantMessage.searchDetails = this.formatSearchInfoDetailed(hybridResponse.searchInfo);
      }
    } else {
      // 服务端模式或直连模式无搜索：使用原有逻辑
      const filteredMessages = this.messages
        .filter(msg => !msg.isLoading)
        .map(msg => ({
          role: msg.role === MessageRole.USER ? 'user' : 'assistant',
          content: msg.content
        } as SimpleMessage));

      const finalMessages = [...filteredMessages];
      const sessionPrompt = this.getCurrentSessionSystemPrompt();
      
      if (sessionPrompt) {
        finalMessages.unshift({
          role: 'system',
          content: sessionPrompt.content
        });
      }

      const apiRequest: APIChatRequest = {
        messages: finalMessages.map(msg => {
          const apiMsg: APIChatMessage = {
            role: msg.role,
            content: msg.content
          };
          return apiMsg;
        }),
        model: this.currentModel,
        max_tokens: 1000,
        temperature: 0.7,
        enable_web: enableWebSearch
      };

      const apiResponse = await this.apiManager.sendChatRequest(apiRequest);
      assistantMessage.content = apiResponse.choices[0]?.message?.content || '未收到有效响应';

      // 同步工具调用状态
      if (apiResponse.tool_status) {
        assistantMessage.toolStatus = apiResponse.tool_status;
      }

      if (apiResponse.web_used) {
        assistantMessage.webUsed = true;
        assistantMessage.searchInfo = apiResponse.search_info || '🌐 已使用网络搜索';
        assistantMessage.searchDetails = apiResponse.search_info || '🌐 已使用网络搜索';
      }
    }
  }

  /**
   * 处理智能消息 - 基于统一状态管理
   */
  private async handleSmartMessage(
    content: string,
    assistantMessage: Message
  ): Promise<void> {
    try {
      // 使用APIManager的智能聊天功能
      const response = await this.apiManager.sendSmartChatRequest(
        content,
        this.currentModel
      );

      // 更新助手消息内容
      assistantMessage.content = response.response.choices[0]?.message.content || '无回复内容';
      assistantMessage.isLoading = false;

      // 更新搜索和工具使用信息
      if (response.searchUsed && response.searchInfo) {
        assistantMessage.webUsed = true;
        assistantMessage.searchInfo = response.searchInfo.query || '🌐 已使用网络搜索';
        assistantMessage.searchDetails = response.searchInfo.query || '🌐 已使用网络搜索';
      }

      if (response.toolsUsed && response.toolCalls) {
        // 工具调用信息已包含在response中
        Logger.info('ChatViewModel', `使用了 ${response.toolCalls.length} 个工具`);
      }

      Logger.info('ChatViewModel', `智能聊天完成，总耗时: ${response.totalTime}ms`);
    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('ChatViewModel', `智能聊天失败: ${errorMessage}`);

      assistantMessage.content = `抱歉，处理消息时出现错误：${errorMessage}`;
      assistantMessage.isLoading = false;
      throw new Error(errorMessage);
    }
  }

  /**
   * 将步骤ID映射到思考状态
   */
  private mapThinkingStatus(stepId: string): ThinkingStatus {
    switch (stepId) {
      case 'plan': return ThinkingStatus.PLANNING;
      case 'analyze': return ThinkingStatus.ANALYZING;
      case 'research': return ThinkingStatus.RESEARCHING;
      case 'think': return ThinkingStatus.THINKING;
      case 'verify': return ThinkingStatus.VERIFYING;
      case 'integrate': return ThinkingStatus.INTEGRATING;
      case 'review': return ThinkingStatus.REFINING;
      default: return ThinkingStatus.IDLE;
    }
  }

  /**
   * 加载当前会话的聊天记录
   */
  async loadMessages(): Promise<void> {
    try {
      if (!this.currentSession) {
        Logger.warn('ChatViewModel', '没有当前会话，清空消息列表');
        this.messages = [];
        return;
      }

      // 在重新加载前，保存当前播放状态到状态管理器
      const currentPlayingMessageId = this.getCurrentPlayingMessage()?.id;
      const currentTtsState = this.ttsService.getState();
      
      // 使用状态管理器保存播放状态
      this.audioPlaybackStateManager.saveTTSState(currentTtsState);
      if (currentPlayingMessageId) {
        this.audioPlaybackStateManager.savePlayingState(currentPlayingMessageId, currentTtsState === TTSState.PLAYING);
      }
      
      Logger.info('ChatViewModel', `保存播放状态 - 播放消息ID: ${currentPlayingMessageId || '无'}, TTS状态: ${currentTtsState}`);

      const storedMessages = await this.sessionManager.getSessionMessages(this.currentSession.id);
      Logger.info('ChatViewModel', `加载会话 ${this.currentSession.id} 的 ${storedMessages.length} 条消息`);
      
      if (storedMessages.length > 0) {
        // 清空现有消息数组
        this.messages.length = 0;
        
        // 逐条添加消息以确保状态更新
        (storedMessages as StoredMessage[]).forEach((msgData: StoredMessage) => {
          console.info(`原始消息数据:`, JSON.stringify(msgData));
          
          // 处理ObservedV2装饰器产生的__ob_前缀字段
          const id: string = msgData.id || msgData.__ob_id || '';
          const role: string = msgData.role || msgData.__ob_role || 'user';
          const content: string = msgData.content || msgData.__ob_content || '';
          const timestamp: number = msgData.timestamp || msgData.__ob_timestamp || Date.now();
          
          console.info(`解析字段: id=${id}, role=${role}, content=${content.substring(0, 30)}...`);
          
          // 确保role是正确的枚举值
          let messageRole: MessageRole;
          if (role === 'user' || role === MessageRole.USER) {
            messageRole = MessageRole.USER;
          } else if (role === 'assistant' || role === MessageRole.ASSISTANT) {
            messageRole = MessageRole.ASSISTANT;
          } else if (role === 'system' || role === MessageRole.SYSTEM) {
            messageRole = MessageRole.SYSTEM;
          } else {
            messageRole = MessageRole.USER; // 默认值
          }
          
          const message = new Message(messageRole, content, id);
          message.timestamp = timestamp;
          message.isLoading = false;
          
          // 恢复播放状态：使用状态管理器恢复播放状态
          if (this.audioPlaybackStateManager.isMessagePlaying(id)) {
            message.isPlaying = true;
            Logger.info('ChatViewModel', `恢复消息 ${id} 的播放状态`);
          }
          
          // 处理网络搜索相关字段（如果存在）
          if (msgData.__ob_webUsed !== undefined) {
            message.webUsed = msgData.__ob_webUsed;
          }
          if (msgData.__ob_searchInfo !== undefined) {
            message.searchInfo = msgData.__ob_searchInfo;
          }
          
          this.messages.push(message);
          
          console.info(`添加消息成功: role=${messageRole}, content长度=${content.length}`);
        });
        
        console.info(`UI消息数组长度: ${this.messages.length}`);
        
        // 如果TTS仍在播放状态但没有找到对应消息，记录警告
        if (this.audioPlaybackStateManager.hasAnyPlayingMessage()) {
          const playingMessageIds = this.audioPlaybackStateManager.getPlayingMessageIds();
          for (const messageId of playingMessageIds) {
            const restoredMessage = this.messages.find(msg => msg.id === messageId);
            if (!restoredMessage) {
              Logger.warn('ChatViewModel', `TTS仍在播放但找不到对应消息 ${messageId}，强制停止TTS`);
              await this.ttsService.forceStop();
              this.audioPlaybackStateManager.clearAllStates();
              break;
            }
          }
        }
      } else {
        this.messages = [];
      }
    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'ChatViewModel';
      errorContext.function = 'loadMessages';
      errorContext.additionalInfo = JSON.stringify({
        errorType: 'MessageLoadFailed'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        errorManager.handleError(
          errorManager.createError(
            ErrorType.STORAGE,
            ErrorCode.STORAGE_READ_FAILED,
            `加载消息失败: ${error.message}`,
            errorContext,
            ErrorLevel.WARNING,
            error
          )
        );
      }
      
      this.messages = [];
    }
  }

  /**
   * 加载厂商和模型列表
   */
  async loadProviders(): Promise<void> {
    try {
      this.isLoading = true;
      
      const currentMode = this.apiManager.getCurrentMode();
      console.info(`当前API模式: ${currentMode}，开始加载providers`);
      
      if (currentMode === APIMode.DIRECT_CALL) {
        // 直连模式：从DirectAPIService获取模型列表
        await this.loadProvidersDirectMode();
      } else {
        // 服务端模式：从ApiService获取
        await this.loadProvidersServerMode();
      }

      console.info(`加载了 ${this.providers.length} 个厂商:`);
      this.providers.forEach(provider => {
        console.info(`- ${provider.name}: ${provider.models.length} 个模型`);
      });

      // 尝试恢复保存的模型选择，如果没有或无效则使用默认选择
      await this.restoreOrSetDefaultModel();
    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'ChatViewModel';
      errorContext.function = 'loadProviders';
      errorContext.additionalInfo = JSON.stringify({
        errorType: 'ProviderLoadFailed',
        apiMode: 'unknown'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        errorManager.handleError(
          errorManager.createError(
            ErrorType.API,
            ErrorCode.API_SERVICE_UNAVAILABLE,
            `加载厂商列表失败: ${error.message}`,
            errorContext,
            ErrorLevel.ERROR,
            error
          )
        );
      }
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 服务端模式加载providers
   */
  private async loadProvidersServerMode(): Promise<void> {
    try {
      const response = await this.apiService.getProviders();
      console.info('收到服务端providers响应:', JSON.stringify(response));

      this.providers = Object.entries(response.providers).map(
        (entry: [string, string[]]) => new Provider(entry[0], entry[1])
      );
    } catch (error) {
      console.error('服务端模式加载providers失败:', (error as Error).message);
      throw new Error(`服务端模式加载providers失败: ${(error as Error).message}`);
    }
  }

  /**
   * 直连模式加载providers（支持网络查询和本地降级）
   */
  private async loadProvidersDirectMode(): Promise<void> {
    try {
      Logger.info('ChatViewModel', '=== 开始直连模式加载providers ===');
      Logger.info('ChatViewModel', '正在从网络获取模型列表...');
      
      // 获取模型厂商映射（包含网络查询和本地降级）
      const startTime = Date.now();
      const modelProviderMap = await this.apiManager.getModelProviderMap();
      const endTime = Date.now();
      
      Logger.info('ChatViewModel', `模型列表获取完成，耗时: ${endTime - startTime}ms`);
      Logger.info('ChatViewModel', `收到直连模式模型厂商映射: ${modelProviderMap.size} 个模型`);
      
      if (modelProviderMap.size === 0) {
        Logger.warn('ChatViewModel', '未获取到任何模型，可能是未配置API密钥或网络问题');
        // 不抛出错误，而是设置空的providers列表
        // 这样用户可以看到空状态提示，而不是应用崩溃
        this.providers = [];
        Logger.info('ChatViewModel', '设置空的providers列表，将显示空状态');
        return;
      }
      
      // 将Map<string, AIProvider>转换为Provider[]
      this.providers = [];
      
      // 按厂商分组模型
      const providerModels = new Map<string, string[]>();
      
      modelProviderMap.forEach((provider, model) => {
        const providerName = this.getProviderServerName(provider);
        if (!providerModels.has(providerName)) {
          providerModels.set(providerName, []);
        }
        providerModels.get(providerName)!.push(model);
      });
      
      // 创建Provider对象
      providerModels.forEach((models, providerName) => {
        this.providers.push(new Provider(providerName, models));
        Logger.info('ChatViewModel', `厂商 ${providerName}: ${models.length} 个模型`);
      });
      
      Logger.info('ChatViewModel', `=== 直连模式providers加载完成 ===`);
      Logger.info('ChatViewModel', `总共加载了 ${this.providers.length} 个厂商`);
      
    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('ChatViewModel', `=== 直连模式加载providers失败 ===`);
      Logger.error('ChatViewModel', `错误信息: ${errorMessage}`);
      
      // 如果网络获取失败，使用空的providers列表，但不抛出错误
      // 这样可以避免整个应用崩溃
      this.providers = [];
      Logger.warn('ChatViewModel', '直连模式providers加载失败，将继续尝试使用默认配置');
    }
  }

  /**
   * 获取厂商在服务端模式下的名称
   */
  private getProviderServerName(provider: AIProvider): string {
    switch (provider) {
      case AIProvider.GLM:
        return 'zhipu';
      case AIProvider.SILICONFLOW:
        return 'siliconflow';
      case AIProvider.GEMINI:
        return 'google';
      default:
        return 'unknown';
    }
  }

  /**
   * 恢复保存的模型选择，如果没有或无效则使用默认选择
   */
  private async restoreOrSetDefaultModel(): Promise<void> {
    try {
      Logger.info('ChatViewModel', '开始恢复模型选择配置');
      
      // 首先检查是否有可用的providers
      if (this.providers.length === 0) {
        this.currentProvider = '';
        this.currentModel = '';
        Logger.warn('ChatViewModel', '没有可用的providers，清空当前模型选择');
        return;
      }

      // 尝试从存储中恢复保存的模型选择
      const savedConfig = await AppStorage.getCurrentModelConfig();
      
      if (savedConfig) {
        Logger.info('ChatViewModel', `尝试恢复保存的模型选择: ${savedConfig.provider}.${savedConfig.model}`);
        
        // 验证保存的选择在当前providers中是否仍然有效
        const provider = this.providers.find(p => p.name === savedConfig.provider);
        if (provider && provider.models.includes(savedConfig.model)) {
          // 保存的选择仍然有效，恢复它
          this.currentProvider = savedConfig.provider;
          this.currentModel = savedConfig.model;
          Logger.info('ChatViewModel', `成功恢复保存的模型选择: ${this.currentProvider}.${this.currentModel}`);
          return;
        } else {
          Logger.warn('ChatViewModel', '保存的模型选择已失效，将使用默认选择并清除保存的配置');
          // 清除无效的保存配置
          await AppStorage.clearCurrentModel();
        }
      } else {
        Logger.info('ChatViewModel', '没有找到保存的模型选择，使用默认选择');
      }

      // 没有保存的选择或选择无效，使用默认选择逻辑
      this.setDefaultModel();
      
    } catch (error) {
      Logger.error('ChatViewModel', `恢复模型选择失败: ${error}，使用默认选择`);
      this.setDefaultModel();
    }
  }

  /**
   * 设置默认模型选择
   */
  private setDefaultModel(): void {
    if (this.providers.length === 0) {
      this.currentProvider = '';
      this.currentModel = '';
      Logger.warn('ChatViewModel', '没有可用的providers，无法设置默认模型');
      return;
    }

    // 优先选择siliconflow厂商
    const preferredProvider = this.providers.find(p => p.name === 'siliconflow') || this.providers[0];
    
    if (preferredProvider) {
      this.currentProvider = preferredProvider.name;
      
      if (preferredProvider.models.length > 0) {
        // 优先选择包含glm的模型
        const glmModel = preferredProvider.models.find(model => model.includes('glm'));
        this.currentModel = glmModel || preferredProvider.models[0];
      } else {
        this.currentModel = '';
      }
      
      Logger.info('ChatViewModel', `设置默认模型选择: ${this.currentProvider}.${this.currentModel}`);
    }
  }

  /**
   * 发送消息 - 使用状态管理器自动确定功能配置
   */
  async sendMessage(content: string, isVoiceMessage: boolean = false): Promise<void> {
    if (!content.trim() || this.isLoading) {
      return;
    }

    // 添加用户消息（保持原始内容）
    const userMessage = new Message(MessageRole.USER, content);
    this.messages.push(userMessage);
    
    // 如果是第一条消息，生成包含系统提示词关键词的会话名称
    if (this.currentSession && this.currentSession.messageCount === 0) {
      const sessionName = Session.generateSessionName(content, this.getCurrentSessionSystemPrompt() || undefined); // 传入系统提示词
      await this.sessionManager.renameSession(this.currentSession.id, sessionName);
      this.currentSession.name = sessionName;
    }
    
    await this.saveMessages();

    // 获取当前功能状态
    const currentFeatures = this.apiManager.getCurrentFeatures();

    // 添加加载中的助手消息
    const assistantMessage = new Message(MessageRole.ASSISTANT, '');
    assistantMessage.isLoading = true;
    assistantMessage.isDeepThinking = currentFeatures.enableDeepThinking;
    assistantMessage.thinkingStatus = currentFeatures.enableDeepThinking ? ThinkingStatus.ANALYZING : ThinkingStatus.IDLE;
    this.messages.push(assistantMessage);

    this.isLoading = true;

    try {
      // 根据是否启用深度思考选择不同的处理方式
      if (currentFeatures.enableDeepThinking) {
        Logger.info('ChatViewModel', '启用深度思考模式');
        await this.handleDeepThinking(content, assistantMessage, currentFeatures.enableWebSearch);
      } else {
        Logger.info('ChatViewModel', '使用智能聊天模式');
        await this.handleSmartMessage(content, assistantMessage);
      }
    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'ChatViewModel';
      errorContext.function = 'sendMessage';
      errorContext.additionalInfo = JSON.stringify({
        isVoiceMessage: isVoiceMessage,
        enableWebSearch: currentFeatures.enableWebSearch,
        enableDeepThinking: currentFeatures.enableDeepThinking,
        enableMCPTools: currentFeatures.enableMCPTools,
        messageLength: content.length,
        currentProvider: this.currentProvider,
        currentModel: this.currentModel
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        const appError = errorManager.createError(
          ErrorType.BUSINESS,
          ErrorCode.UNKNOWN_ERROR,
          `发送消息失败: ${error.message}`,
          errorContext,
          ErrorLevel.ERROR,
          error
        );
        
        errorManager.handleError(appError);
      }
  
      const errorMessage = (error as Error).message || '未知错误';
      assistantMessage.content = `发送消息失败: ${errorMessage}`;
    } finally {
      assistantMessage.isLoading = false;
      this.isLoading = false;
      await this.saveMessages();
      
      // 如果助手消息不为空且没有错误，则触发自动播报
      if (assistantMessage.content && 
          !assistantMessage.content.startsWith('错误:') && 
          !assistantMessage.content.startsWith('发送消息失败:')) {
        await this.handleAutoPlayback(assistantMessage);
      }
    }
  }

  /**
   * 保存聊天记录到本地存储
   */
  async saveMessages(): Promise<void> {
    if (!this.currentSession) {
      Logger.warn('ChatViewModel', '没有当前会话，无法保存消息');
      return;
    }
    
    const messagesToSave = this.messages.filter(msg => !msg.isLoading);
    await this.sessionManager.saveSessionMessages(this.currentSession.id, messagesToSave);
    
    // 仅更新当前会话的信息，而不是重新加载整个会话列表
    await this.updateCurrentSessionInfo();
  }

  /**
   * 切换模型
   */
  async switchModel(provider: string, model: string): Promise<void> {
    Logger.info('ChatViewModel', `切换模型: ${provider} -> ${model}，先停止语音播放`);
    
    // 切换模型前先停止所有语音播放并清空队列
    await this.stopAllAudio();
    
    // 直接使用用户的选择，不进行验证（用户已经从模型选择器中明确选择）
    this.currentProvider = provider;
    this.currentModel = model;
    
    // 保存模型选择到存储中，以便下次启动时恢复
    try {
      await AppStorage.saveCurrentModel(provider, model);
      Logger.info('ChatViewModel', '模型选择已保存到存储');
    } catch (error) {
      Logger.warn('ChatViewModel', `保存模型选择失败: ${error}，但不影响当前使用`);
    }
    
    Logger.info('ChatViewModel', `模型切换完成: ${this.currentProvider}.${this.currentModel}`);
  }

  /**
   * 清空当前会话的聊天记录
   */
  async clearMessages(): Promise<void> {
    Logger.info('ChatViewModel', '开始清空当前会话消息，先停止所有语音播放');
    
    // 在清空消息前先停止所有语音播放并清空队列
    await this.stopAllAudio();
    
    if (!this.currentSession) {
      Logger.warn('ChatViewModel', '没有当前会话，无法清空消息');
      return;
    }
    
    // 清空消息列表
    this.messages = [];
    await this.sessionManager.saveSessionMessages(this.currentSession.id, []);
    
    // 仅更新当前会话信息，避免重新加载整个会话列表
    await this.updateCurrentSessionInfo();
    
    Logger.info('ChatViewModel', '当前会话消息清空完成');
  }

  /**
   * 压缩对话上下文 - 保留最近的关键对话
   */
  async compactMessages(): Promise<void> {
    if (this.messages.length <= 6) {
      // 消息数量少于6条时不需要压缩
      return;
    }

    Logger.info('ChatViewModel', '开始压缩消息，先停止所有语音播放');
    
    // 在压缩消息前先停止所有语音播放并清空队列
    await this.stopAllAudio();

    const compactedMessages: Message[] = [];
    const recentMessages = this.messages.slice(-6); // 保留最近6条消息

    // 遍历最近的消息，保留完整的对话对
    for (let i = 0; i < recentMessages.length; i++) {
      const message = recentMessages[i];
      
      // 压缩过长的消息内容
      if (message.content.length > 200) {
        const compactedContent = message.content.substring(0, 150) + 
          '\n...[内容已压缩]...\n' + 
          message.content.substring(message.content.length - 50);
        
        const compactedMessage = new Message(message.role, compactedContent, message.id);
        compactedMessage.timestamp = message.timestamp;
        compactedMessages.push(compactedMessage);
      } else {
        compactedMessages.push(message);
      }
    }

    this.messages = compactedMessages;
    await this.saveMessages();
  }

  /**
   * 获取当前选中的厂商信息
   */
  getCurrentProvider(): Provider | undefined {
    return this.providers.find(p => p.name === this.currentProvider);
  }

  /**
   * 获取当前会话的系统提示词
   */
  getCurrentSessionSystemPrompt(): SystemPrompt | null {
    if (!this.currentSession?.systemPromptId) {
      return null;
    }
    return this.systemPrompts.find(p => p.id === this.currentSession!.systemPromptId) || null;
  }

  /**
   * 加载系统提示词
   */
  async loadSystemPrompts(): Promise<void> {
    try {
      console.info('=== ChatViewModel.loadSystemPrompts 开始 ===');
      console.info('当前时间:', new Date().toISOString());
      
      // 初始化默认提示词
      console.info('正在初始化默认提示词...');
      await AppStorage.initializeDefaultPrompts();
      console.info('默认提示词初始化完成');
      
      // 加载所有提示词
      console.info('正在加载所有提示词...');
      this.systemPrompts = await AppStorage.getSystemPrompts();
      console.info(`ChatViewModel 加载了 ${this.systemPrompts.length} 条系统提示词`);
      
      // 详细打印每条提示词
      this.systemPrompts.forEach((prompt, index) => {
        console.info(`ChatViewModel 提示词[${index}]:`);
        console.info(`  ID: ${prompt.id}`);
        console.info(`  名称: ${prompt.name}`);
        console.info(`  内容: ${prompt.content.substring(0, 50)}...`);
        });
      
      // 不再加载全局选中的提示词，改为从会话获取
      // await this.loadSelectedSystemPrompt(); // 已移除
      
      console.info('=== ChatViewModel.loadSystemPrompts 完成 ===');
    } catch (error) {
      console.error('❌ ChatViewModel 加载系统提示词失败:', (error as Error).message);
      console.error('错误堆栈:', (error as Error).stack);
    }
  }

  // loadSelectedSystemPrompt方法已移除，不再使用全局选中状态

  // selectSystemPrompt方法已移除，不再支持全局选择系统提示词
  // 系统提示词现在与会话绑定，在创建会话时选择

  /**
   * 添加系统提示词
   */
  async addSystemPrompt(name: string, content: string): Promise<void> {
    try {
      const prompt = new SystemPrompt(name, content);
      await AppStorage.addSystemPrompt(prompt);
      await this.loadSystemPrompts(); // 重新加载
      console.info('添加系统提示词成功');
    } catch (error) {
      console.error('添加系统提示词失败:', (error as Error).message);
    }
  }

  /**
   * 更新系统提示词
   */
  async updateSystemPrompt(prompt: SystemPrompt): Promise<void> {
    try {
      await AppStorage.updateSystemPrompt(prompt);
      await this.loadSystemPrompts(); // 重新加载
      
      // 不再需要更新全局选中状态，系统提示词现在与会话绑定
      
      console.info('更新系统提示词成功');
    } catch (error) {
      console.error('更新系统提示词失败:', (error as Error).message);
    }
  }

  /**
   * 删除系统提示词
   */
  async deleteSystemPrompt(promptId: string): Promise<void> {
    try {
      await AppStorage.deleteSystemPrompt(promptId);
      await this.loadSystemPrompts(); // 重新加载
      
      // 不再需要清除全局选中状态，系统提示词现在与会话绑定
      
      console.info('删除系统提示词成功');
    } catch (error) {
      console.error('删除系统提示词失败:', (error as Error).message);
    }
  }

  /**
   * 通过厂商名称获取AIProvider枚举值
   */
  private getAIProviderByName(providerName: string): AIProvider | undefined {
    switch (providerName) {
      case 'siliconflow':
        return AIProvider.SILICONFLOW;
      case 'zhipu':
        return AIProvider.GLM;
      case 'google':
        return AIProvider.GEMINI;
      default:
        return undefined;
    }
  }

  /**
   * 格式化搜索信息为简化字符串（用于主消息显示）
   */
  private formatSearchInfoSimple(searchInfo: SearchInfo): string {
    const parts: string[] = [];
    parts.push('🔍 网络搜索');
    
    if (searchInfo.searchTime) {
      parts.push(`⏱️ ${searchInfo.searchTime}ms`);
    }
    
    if (searchInfo.resultCount > 0) {
      parts.push(`📊 ${searchInfo.resultCount}个结果`);
    }
    
    return parts.join(' | ');
  }

  /**
   * 格式化搜索信息为详细字符串（用于气泡显示）
   */
  private formatSearchInfoDetailed(searchInfo: SearchInfo): string {
    const messageEnhancer = MessageEnhancer.getInstance();
    return messageEnhancer.buildUserSearchDetails(searchInfo);
  }

  /**
   * 获取搜索类别显示名称
   */
  private getSearchCategoryDisplayName(category: string): string {
    const categoryMap: Record<string, string> = {
      'real_time': '实时信息',
      'technical': '技术查询',
      'news': '新闻事件',
      'current_affairs': '时事信息',
      'factual': '事实查询',
      'none': '无'
    };
    return categoryMap[category] || '未知';
  }

  /**
   * 获取默认系统提示词
   */
  getDefaultSystemPrompts(): SystemPrompt[] {
    return AppStorage.getDefaultSystemPrompts();
  }

  // 防抖动：记录上次播放时间，防止快速重复点击
  private lastPlayTime: Record<string, number> = {};
  private readonly PLAY_DEBOUNCE_TIME = 1000; // 1秒防抖动

  /**
   * 播放指定消息的语音
   */
  async playMessageAudio(messageId: string): Promise<boolean> {
    try {
      // 防抖动检查：防止快速重复点击同一个消息
      const now = Date.now();
      const lastPlay = this.lastPlayTime[messageId];
      if (lastPlay && now - lastPlay < this.PLAY_DEBOUNCE_TIME) {
        Logger.warn('ChatViewModel', `防抖动: 消息 ${messageId} 在 ${now - lastPlay}ms 内重复点击，忽略`);
        return false;
      }
      this.lastPlayTime[messageId] = now;

      // 查找消息
      const message = this.messages.find(msg => msg.id === messageId);
      if (!message || !message.canPlayAudio || message.isLoading) {
        Logger.warn('ChatViewModel', `无法播放消息语音: 消息不存在或不可播放 (id: ${messageId})`);
        return false;
      }

      // 记录初始状态
      const currentPlayingMsg = this.getCurrentPlayingMessage();
      const isAnyPlaying = this.isAnyMessagePlaying();
      const ttsState = this.ttsService.getState();
      
      Logger.info('ChatViewModel', `=== 开始手动播放消息语音: ${messageId} ===`);
      Logger.info('ChatViewModel', `初始状态 - 当前播放消息: ${currentPlayingMsg?.id || '无'}, 任意播放: ${isAnyPlaying}, TTS状态: ${ttsState}, 音频锁: ${this.audioPlaybackLock}`);

      // 检查音频播放锁
      if (this.audioPlaybackLock) {
        Logger.warn('ChatViewModel', '音频播放锁已被占用，等待释放');
        // 等待锁释放
        await this.waitForAudioLock(3000);
      }
      
      // 获取音频播放锁
      this.audioPlaybackLock = true;
      Logger.info('ChatViewModel', `已获取音频播放锁: ${messageId}`);
      
      try {
        // 检查是否为AA场景（同一个消息）
        if (message.isPlaying) {
          Logger.info('ChatViewModel', `🔴 AA场景检测：点击正在播放的消息 ${messageId}，当前状态: playing=${message.isPlaying}`);
          Logger.info('ChatViewModel', 'AA场景：停止当前消息播放');
          message.isPlaying = false; // 立即更新状态
          Logger.info('ChatViewModel', `AA场景：已设置消息状态为 false`);
          await this.ttsService.stop();
          Logger.info('ChatViewModel', `AA场景：TTS.stop() 调用完成`);
          await this.delay(200);
          Logger.info('ChatViewModel', `AA场景：延迟完成，状态检查 - playing=${message.isPlaying}, TTS状态=${this.ttsService.getState()}`);
        } 
        // ABA场景：停止其他消息的播放
        else if (this.isAnyMessagePlaying()) {
          // 在ABA场景前先同步状态
          await this.syncAudioStates();
          const otherPlayingMsg = this.getCurrentPlayingMessage();
          Logger.info('ChatViewModel', `🔵 ABA场景检测：当前播放消息 ${otherPlayingMsg?.id}，请求播放 ${messageId}`);
          Logger.info('ChatViewModel', 'ABA场景：停止其他消息播放');
          Logger.info('ChatViewModel', `ABA场景：停止前状态 - 任意播放: ${this.isAnyMessagePlaying()}, TTS状态: ${this.ttsService.getState()}`);
          
          await this.forceStopAllAudio();
          Logger.info('ChatViewModel', `ABA场景：forceStopAllAudio() 完成`);
          await this.delay(300);
          
          // 确保完全停止
          const stillPlaying = this.isAnyMessagePlaying();
          const afterTtsState = this.ttsService.getState();
          Logger.info('ChatViewModel', `ABA场景：停止后状态 - 任意播放: ${stillPlaying}, TTS状态: ${afterTtsState}`);
          
          if (stillPlaying) {
            Logger.warn('ChatViewModel', '强制停止后仍有音频在播放，执行额外清理');
            await this.emergencyStop();
          }
        } else {
          Logger.info('ChatViewModel', `🟢 正常场景：没有其他音频在播放，直接播放 ${messageId}`);
        }
      } catch (error) {
        // 发生错误时释放锁
        this.audioPlaybackLock = false;
        
        const errorContext = new ErrorContext();
        errorContext.module = 'ChatViewModel';
        errorContext.function = 'playMessageAudio';
        errorContext.additionalInfo = JSON.stringify({
          messageId: messageId,
          errorType: 'AudioPlaybackFailed'
        });
        
        const errorManager = ErrorManager.getInstance();
        if (error instanceof Error) {
          errorManager.handleError(
            errorManager.createError(
              ErrorType.AUDIO,
              ErrorCode.AUDIO_PLAYBACK_FAILED,
              `播放音频失败: ${error.message}`,
              errorContext,
              ErrorLevel.ERROR,
              error
            )
          );
        }
        
        throw new Error(`播放音频失败: ${(error as Error).message}`);
      }

      // 立即设置当前消息为播放状态，确保UI即时响应
      Logger.info('ChatViewModel', `设置消息 ${messageId} 播放状态为 true`);
      message.isPlaying = true;
      
      // 使用状态管理器保存播放状态
      this.audioPlaybackStateManager.savePlayingState(messageId, true);

      // 初始化TTS服务
      Logger.info('ChatViewModel', '初始化TTS服务...');
      const initialized = await this.ttsService.initialize();
      if (!initialized) {
        Logger.error('ChatViewModel', 'TTS服务初始化失败');
        message.isPlaying = false;
        this.audioPlaybackStateManager.savePlayingState(messageId, false);
        return false;
      }
      Logger.info('ChatViewModel', 'TTS服务初始化成功');

      // 创建TTS回调
      Logger.info('ChatViewModel', `创建TTS回调，消息: ${messageId}`);
      const callbacks: TTSCallbacks = {
        onStart: () => {
          Logger.info('ChatViewModel', `🎵 TTS播放开始: ${messageId}，当前状态: playing=${message.isPlaying}`);
        },
        onComplete: () => {
          Logger.info('ChatViewModel', `✅ TTS播放完成: ${messageId}，当前状态: playing=${message.isPlaying}`);
          // 播放完成时更新消息状态 - 使用双重确保机制
          message.isPlaying = false;
          
          // 使用状态管理器清理播放状态
          this.audioPlaybackStateManager.savePlayingState(messageId, false);
          
          // 额外安全措施：通过消息ID再次查找并更新状态
          const msgToUpdate = this.messages.find(msg => msg.id === messageId);
          if (msgToUpdate) {
            msgToUpdate.isPlaying = false;
            Logger.info('ChatViewModel', `✅ 通过ID查找更新消息 ${messageId} 状态为 false`);
          } else {
            Logger.warn('ChatViewModel', `⚠️ 播放完成时找不到消息 ${messageId}，强制清理所有播放状态`);
            // 找不到消息时，强制清理所有播放状态
            this.messages.forEach(msg => {
              if (msg.isPlaying) {
                msg.isPlaying = false;
                Logger.info('ChatViewModel', `✅ 强制清理消息 ${msg.id} 的播放状态`);
              }
            });
          }
          
          Logger.info('ChatViewModel', `✅ 播放完成状态已更新: playing=${message.isPlaying}`);
        },
        onError: (error) => {
          Logger.error('ChatViewModel', `❌ TTS播放错误: ${messageId}, ${error.message}，当前状态: playing=${message.isPlaying}`);
          // 播放错误时更新消息状态 - 使用双重确保机制
          message.isPlaying = false;
          
          // 使用状态管理器清理播放状态
          this.audioPlaybackStateManager.savePlayingState(messageId, false);
          
          // 额外安全措施：通过消息ID再次查找并更新状态
          const msgToUpdate = this.messages.find(msg => msg.id === messageId);
          if (msgToUpdate) {
            msgToUpdate.isPlaying = false;
            Logger.info('ChatViewModel', `❌ 通过ID查找更新消息 ${messageId} 状态为 false`);
          } else {
            Logger.warn('ChatViewModel', `⚠️ 播放错误时找不到消息 ${messageId}，强制清理所有播放状态`);
            // 找不到消息时，强制清理所有播放状态
            this.messages.forEach(msg => {
              if (msg.isPlaying) {
                msg.isPlaying = false;
                Logger.info('ChatViewModel', `❌ 强制清理消息 ${msg.id} 的播放状态`);
              }
            });
          }
          
          Logger.info('ChatViewModel', `❌ 播放错误状态已更新: playing=${message.isPlaying}`);
        },
        onStop: () => {
          Logger.info('ChatViewModel', `⏹️ TTS播放停止: ${messageId}，当前状态: playing=${message.isPlaying}`);
          // 播放停止时更新消息状态 - 使用双重确保机制
          message.isPlaying = false;
          
          // 使用状态管理器清理播放状态
          this.audioPlaybackStateManager.savePlayingState(messageId, false);
          
          // 额外安全措施：通过消息ID再次查找并更新状态
          const msgToUpdate = this.messages.find(msg => msg.id === messageId);
          if (msgToUpdate) {
            msgToUpdate.isPlaying = false;
            Logger.info('ChatViewModel', `⏹️ 通过ID查找更新消息 ${messageId} 状态为 false`);
          } else {
            Logger.warn('ChatViewModel', `⚠️ 播放停止时找不到消息 ${messageId}，强制清理所有播放状态`);
            // 找不到消息时，强制清理所有播放状态
            this.messages.forEach(msg => {
              if (msg.isPlaying) {
                msg.isPlaying = false;
                Logger.info('ChatViewModel', `⏹️ 强制清理消息 ${msg.id} 的播放状态`);
              }
            });
          }
          
          Logger.info('ChatViewModel', `⏹️ 播放停止状态已更新: playing=${message.isPlaying}`);
        }
      };

      // 直接使用TTSService播放，绕过AutoTTSService的队列系统
      Logger.info('ChatViewModel', `调用TTS服务开始播放: ${messageId}`);
      
      // 为防止华为TTS重复回调，添加回调状态跟踪
      this.ttsCallbackStates.set(messageId, false);
      const originalCallbacks = callbacks;
      const protectedCallbacks: TTSCallbacks = {
        onStart: originalCallbacks.onStart,
        onComplete: () => {
          Logger.info('ChatViewModel', `🎵 TTS播放完成回调: ${messageId}，当前状态: playing=${message.isPlaying}`);
          
          // 检查是否已经处理过完成回调
          const hasCompleted = this.ttsCallbackStates.get(messageId) || false;
          
          if (!hasCompleted && message.isPlaying) {
            // 第一次回调：标记为已完成，但不立即处理状态
            this.ttsCallbackStates.set(messageId, true);
            Logger.info('ChatViewModel', `⏳ TTS合成完成，等待真正的播放完成: ${messageId}`);
          } else if (hasCompleted || !message.isPlaying) {
            // 第二次回调或消息已不在播放状态：真正处理完成
            Logger.info('ChatViewModel', `✅ TTS真正播放完成: ${messageId}`);
            originalCallbacks.onComplete?.();
            // 清理状态
            this.ttsCallbackStates.delete(messageId);
          } else {
            Logger.warn('ChatViewModel', `⚠️ 意外的回调状态: messageId=${messageId}, hasCompleted=${hasCompleted}, isPlaying=${message.isPlaying}`);
          }
        },
        onError: (error) => {
          // 错误时立即处理并清理状态
          originalCallbacks.onError?.(error);
          this.ttsCallbackStates.delete(messageId);
        },
        onStop: () => {
          // 停止时立即处理并清理状态
          originalCallbacks.onStop?.();
          this.ttsCallbackStates.delete(messageId);
        },
        onPause: originalCallbacks.onPause,
        onResume: originalCallbacks.onResume
      };
      
      const success = await this.ttsService.speak(message.content, protectedCallbacks);
      if (!success) {
        message.isPlaying = false;
        Logger.error('ChatViewModel', `❌ 启动语音播放失败: ${messageId}`);
        return false;
      }

      Logger.info('ChatViewModel', `✅ 消息语音播放启动成功: ${messageId}`);
      Logger.info('ChatViewModel', `=== TTS调用完成，等待实际播放完成 - 消息状态: ${message.isPlaying}, TTS状态: ${this.ttsService.getState()} ===`);
      return true;

    } catch (error) {
      Logger.error('ChatViewModel', `播放消息语音异常: ${(error as Error).message}`);
      // 恢复消息状态
      const message = this.messages.find(msg => msg.id === messageId);
      if (message) {
        message.isPlaying = false;
      }
      return false;
    } finally {
      // 释放音频播放锁
      this.audioPlaybackLock = false;
      Logger.debug('ChatViewModel', '音频播放锁已释放');
    }
  }

  /**
   * 停止指定消息的语音播放
   */
  async stopMessageAudio(messageId: string): Promise<boolean> {
    try {
      const message = this.messages.find(msg => msg.id === messageId);
      if (!message) {
        Logger.warn('ChatViewModel', `要停止的消息不存在: ${messageId}`);
        return false;
      }

      if (!message.isPlaying) {
        Logger.info('ChatViewModel', `消息未在播放，无需停止: ${messageId}`);
        return true;
      }

      // 停止TTS播放
      const success = await this.ttsService.stop();
      
      // 更新消息状态
      message.isPlaying = false;
      this.audioPlaybackStateManager.savePlayingState(messageId, false);
      
      Logger.info('ChatViewModel', `消息语音播放已停止: ${messageId}`);
      return success;

    } catch (error) {
      Logger.error('ChatViewModel', `停止消息语音播放异常: ${(error as Error).message}`);
      return false;
    }
  }
  
  /**
   * 停止深度思考过程
   */
  async stopDeepThinking(messageId: string): Promise<boolean> {
    try {
      // 检查是否是当前正在思考的消息
      if (this.currentThinkingMessageId !== messageId) {
        Logger.info('ChatViewModel', `消息 ${messageId} 不是当前正在深度思考的消息`);
        return false;
      }
      
      // 检查是否有深度思考服务在运行
      if (!this.deepThinkingService.isRunning()) {
        Logger.info('ChatViewModel', '当前没有深度思考过程在运行');
        return true;
      }
      
      Logger.info('ChatViewModel', `正在取消深度思考过程: ${messageId}`);
      
      // 取消深度思考服务
      const cancelled = this.deepThinkingService.cancel();
      
      if (cancelled) {
        // 更新消息状态
        const message = this.messages.find(msg => msg.id === messageId);
        if (message) {
          message.thinkingStatus = ThinkingStatus.CANCELLED;
          message.isLoading = false;
        }
        
        // 清除当前思考消息ID
        this.currentThinkingMessageId = '';
        
        Logger.info('ChatViewModel', `深度思考过程已取消: ${messageId}`);
      } else {
        Logger.warn('ChatViewModel', '取消深度思考过程失败');
      }
      
      return cancelled;
    } catch (error) {
      Logger.error('ChatViewModel', `取消深度思考过程异常: ${(error as Error).message}`);
      return false;
    }
  }

  /**
   * 停止所有消息的语音播放
   */
  private async stopAllAudio(): Promise<void> {
    try {
      Logger.info('ChatViewModel', '开始停止所有语音播放并清空队列');

      // 首先停止TTS服务，确保音频停止
      await this.ttsService.stop();

      // 停止自动播报服务并清空队列
      await this.autoTTSService.stopPlayback();
      this.autoTTSService.clearQueue();

      // 等待一小段时间确保服务停止
      await this.delay(200);

      // 重置所有消息的播放状态
      let resetCount = 0;
      this.messages.forEach(message => {
        if (message.isPlaying) {
          message.isPlaying = false;
          resetCount++;
        }
      });

      // 再次检查并确保TTS服务完全停止
      if (this.ttsService.isPlaying()) {
        Logger.warn('ChatViewModel', 'TTS服务仍在播放状态，尝试再次停止');
        await this.ttsService.stop();
        await this.delay(100);
      }

      Logger.info('ChatViewModel', `已停止所有语音播放并清空播放队列，重置了 ${resetCount} 个消息状态`);
    } catch (error) {
      Logger.error('ChatViewModel', `停止所有语音播放异常: ${(error as Error).message}`);
      // 即使出错，也要确保重置所有播放状态
      this.messages.forEach(message => {
        if (message.isPlaying) {
          message.isPlaying = false;
        }
      });
    }
  }

  /**
   * 检查是否有消息正在播放语音
   */
  isAnyMessagePlaying(): boolean {
    // 同时检查消息状态和TTS服务状态，确保状态同步
    const messagePlaying = this.messages.some(message => message.isPlaying);
    const ttsPlaying = this.ttsService.isPlaying();
    
    if (messagePlaying !== ttsPlaying) {
      Logger.warn('ChatViewModel', `状态不同步：消息状态=${messagePlaying}, TTS状态=${ttsPlaying}`);
    }
    
    // 优先使用消息状态，但如果有冲突，以TTS状态为准
    return ttsPlaying || messagePlaying;
  }

  /**
   * 获取当前播放语音的消息
   */
  getCurrentPlayingMessage(): Message | null {
    const playingMessage = this.messages.find(message => message.isPlaying);
    Logger.info('ChatViewModel', `getCurrentPlayingMessage: 消息总数=${this.messages.length}, 找到播放消息=${playingMessage?.id || '无'}`);
    
    // 调试：打印所有消息的播放状态
    this.messages.forEach(msg => {
      Logger.info('ChatViewModel', `消息 ${msg.id} 播放状态: ${msg.isPlaying}`);
    });
    
    return playingMessage || null;
  }

  /**
   * 获取详细的音频播放状态信息
   */
  getAudioStateInfo(): AudioStateInfo {
    const messagePlaying = this.messages.some(message => message.isPlaying);
    const ttsPlaying = this.ttsService.isPlaying();
    const currentMessage = this.getCurrentPlayingMessage();
    
    return {
      messagePlaying,
      ttsPlaying,
      currentMessage: currentMessage?.id || null,
      audioLock: this.audioPlaybackLock
    };
  }

  /**
   * 等待音频停止
   */
  private async waitForAudioStop(timeoutMs: number = 2000): Promise<void> {
    return new Promise((resolve) => {
      const startTime = Date.now();
      
      const checkInterval = setInterval(() => {
        if (!this.isAnyMessagePlaying()) {
          clearInterval(checkInterval);
          Logger.info('ChatViewModel', '所有音频已停止');
          resolve();
          return;
        }
        
        // 检查超时
        if (Date.now() - startTime > timeoutMs) {
          clearInterval(checkInterval);
          Logger.warn('ChatViewModel', `等待音频停止超时 (${timeoutMs}ms)，强制继续`);
          resolve();
        }
      }, 100);
    });
  }

  /**
   * 等待音频播放锁释放
   */
  private async waitForAudioLock(timeoutMs: number = 3000): Promise<void> {
    return new Promise((resolve) => {
      const startTime = Date.now();
      
      const checkInterval = setInterval(() => {
        if (!this.audioPlaybackLock) {
          clearInterval(checkInterval);
          Logger.info('ChatViewModel', '音频播放锁已释放');
          resolve();
          return;
        }
        
        // 检查超时
        if (Date.now() - startTime > timeoutMs) {
          clearInterval(checkInterval);
          Logger.warn('ChatViewModel', `等待音频播放锁超时 (${timeoutMs}ms)，强制继续`);
          // 强制释放锁
          this.audioPlaybackLock = false;
          resolve();
        }
      }, 50);
    });
  }

  /**
   * 延迟函数
   */
  private async delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 强制停止所有音频
   */
  private async forceStopAllAudio(): Promise<void> {
    try {
      const beforeState = this.getAudioStateInfo();
      Logger.info('ChatViewModel', `🔄 开始强制停止所有音频 - 前状态: 消息=${beforeState.messagePlaying}, TTS=${beforeState.ttsPlaying}, 当前消息=${beforeState.currentMessage}, 锁=${beforeState.audioLock}`);
      
      // 立即重置所有消息状态（不依赖TTS服务状态）
      let resetCount = 0;
      this.messages.forEach(msg => {
        if (msg.isPlaying) {
          Logger.info('ChatViewModel', `重置消息状态: ${msg.id} (从 ${msg.isPlaying} 变为 false)`);
          msg.isPlaying = false;
          
          // 同时更新状态管理器
          this.audioPlaybackStateManager.savePlayingState(msg.id, false);
          resetCount++;
        }
      });
      
      // 尝试停止TTS服务（但不依赖其结果）
      try {
        Logger.info('ChatViewModel', '调用TTS.stop()...');
        await this.ttsService.stop();
        Logger.info('ChatViewModel', 'TTS.stop() 完成');
      } catch (error) {
        Logger.warn('ChatViewModel', `停止TTS服务失败: ${(error as Error).message}`);
      }
      
      // 停止自动播报服务
      try {
        await this.autoTTSService.stopPlayback();
        this.autoTTSService.clearQueue();
      } catch (error) {
        Logger.warn('ChatViewModel', `停止自动播报服务失败: ${(error as Error).message}`);
      }
      
      // 等待一小段时间确保状态同步
      await this.delay(100);
      
      const afterState = this.getAudioStateInfo();
      Logger.info('ChatViewModel', `✅ 强制停止完成 - 重置了${resetCount}个消息状态`);
      Logger.info('ChatViewModel', `🔄 后状态: 消息=${afterState.messagePlaying}, TTS=${afterState.ttsPlaying}, 当前消息=${afterState.currentMessage}, 锁=${afterState.audioLock}`);
      
    } catch (error) {
      Logger.error('ChatViewModel', `❌ 强制停止失败: ${(error as Error).message}`);
      // 即使失败也要重置所有状态
      this.messages.forEach(msg => {
        if (msg.isPlaying) {
          msg.isPlaying = false;
          this.audioPlaybackStateManager.savePlayingState(msg.id, false);
        }
      });
    }
  }

  /**
   * 紧急停止（最后的保障）
   */
  private async emergencyStop(): Promise<void> {
    try {
      const beforeState = this.getAudioStateInfo();
      Logger.warn('ChatViewModel', `🚨 执行紧急停止操作 - 前状态: 消息=${beforeState.messagePlaying}, TTS=${beforeState.ttsPlaying}, 当前消息=${beforeState.currentMessage}`);
      
      // 重置所有消息状态（最重要的一步）
      let emergencyResetCount = 0;
      this.messages.forEach(msg => {
        if (msg.isPlaying) {
          Logger.warn('ChatViewModel', `🚨 紧急重置消息状态: ${msg.id}`);
          msg.isPlaying = false;
          
          // 同时更新状态管理器
          this.audioPlaybackStateManager.savePlayingState(msg.id, false);
          emergencyResetCount++;
        }
      });
      
      // 清空自动播报队列
      this.autoTTSService.clearQueue();
      
      // 尝试停止TTS服务（多次尝试）
      for (let i = 0; i < 3; i++) {
        try {
          Logger.warn('ChatViewModel', `🚨 紧急停止TTS尝试 ${i + 1}/3`);
          await this.ttsService.stop();
          Logger.warn('ChatViewModel', '🚨 TTS紧急停止成功');
          break; // 如果成功就退出循环
        } catch (error) {
          if (i === 2) {
            Logger.error('ChatViewModel', '🚨 TTS服务紧急停止失败（已重试3次）');
          }
          await this.delay(100);
        }
      }
      
      // 等待状态同步
      await this.delay(150);
      
      const afterState = this.getAudioStateInfo();
      Logger.warn('ChatViewModel', `🚨 紧急停止操作完成 - 重置了${emergencyResetCount}个消息`);
      Logger.warn('ChatViewModel', `🚨 紧急停止后状态: 消息=${afterState.messagePlaying}, TTS=${afterState.ttsPlaying}, 当前消息=${afterState.currentMessage}`);
      
    } catch (error) {
      Logger.error('ChatViewModel', `🚨 紧急停止失败: ${(error as Error).message}`);
      // 确保状态重置
      this.messages.forEach(msg => {
        if (msg.isPlaying) {
          msg.isPlaying = false;
          this.audioPlaybackStateManager.savePlayingState(msg.id, false);
        }
      });
    }
  }

  /**
   * 同步消息状态与TTS状态
   */
  private async syncAudioStates(): Promise<void> {
    try {
      const messagePlaying = this.messages.some(message => message.isPlaying);
      const ttsPlaying = this.ttsService.isPlaying();
      
      if (messagePlaying !== ttsPlaying) {
        Logger.warn('ChatViewModel', `🔄 检测到状态不同步，开始同步: 消息状态=${messagePlaying}, TTS状态=${ttsPlaying}`);
        
        if (ttsPlaying && !messagePlaying) {
          // TTS在播放但没有消息标记为播放，可能是状态丢失
          Logger.warn('ChatViewModel', '🔄 TTS在播放但消息状态丢失，尝试恢复');
          // 如果有当前播放的消息，恢复其状态
          const currentMsg = this.getCurrentPlayingMessage();
          if (currentMsg) {
            currentMsg.isPlaying = true;
            Logger.info('ChatViewModel', `🔄 已恢复消息 ${currentMsg.id} 的播放状态`);
          }
        } else if (!ttsPlaying && messagePlaying) {
          // 消息标记为播放但TTS已停止，需要清理
          Logger.warn('ChatViewModel', '🔄 TTS已停止但消息状态未清理，开始清理');
          this.messages.forEach(msg => {
            if (msg.isPlaying) {
              Logger.info('ChatViewModel', `🔄 清理消息 ${msg.id} 的播放状态`);
              msg.isPlaying = false;
            }
          });
        }
        
        await this.delay(50); // 等待状态同步完成
        
        const afterSyncState = this.getAudioStateInfo();
        Logger.info('ChatViewModel', `🔄 状态同步完成: 消息=${afterSyncState.messagePlaying}, TTS=${afterSyncState.ttsPlaying}`);
      }
    } catch (error) {
      Logger.error('ChatViewModel', `🔄 状态同步失败: ${(error as Error).message}`);
    }
  }

  /**
   * 初始化自动播报服务
   */
  private async initializeAutoTTS(): Promise<void> {
    try {
      Logger.info('ChatViewModel', '初始化自动播报服务');
      const initialized = await this.autoTTSService.initialize();
      if (initialized) {
        // 额外调用reloadSettings确保状态同步
        await this.autoTTSService.reloadSettings();
        const settings = this.autoTTSService.getSettings();
        Logger.info('ChatViewModel', `自动播报服务初始化成功，当前设置: muted=${settings.muted}, autoPlay=${settings.autoPlayOnReceive}`);
      } else {
        Logger.error('ChatViewModel', '自动播报服务初始化失败');
      }
    } catch (error) {
      Logger.error('ChatViewModel', `初始化自动播报服务异常: ${(error as Error).message}`);
    }
  }

  /**
   * 处理自动播报逻辑
   */
  private async handleAutoPlayback(message: Message): Promise<void> {
    try {
      if (!this.autoTTSService.isAutoPlayEnabled()) {
        Logger.debug('ChatViewModel', '自动播报已禁用，跳过播报');
        return;
      }

      Logger.info('ChatViewModel', `触发自动播报: ${message.id}`);
      await this.autoTTSService.addPlaybackTask(message.content, message.id, 1);
      
    } catch (error) {
      Logger.error('ChatViewModel', `自动播报处理失败: ${(error as Error).message}`);
    }
  }

  /**
   * 手动播报指定消息
   */
  async playMessageViaAutoTTS(messageId: string): Promise<boolean> {
    try {
      // 防抖动检查：防止快速重复点击同一个消息
      const now = Date.now();
      const lastPlay = this.lastPlayTime[messageId];
      if (lastPlay && now - lastPlay < this.PLAY_DEBOUNCE_TIME) {
        Logger.warn('ChatViewModel', `防抖动: AutoTTS消息 ${messageId} 在 ${now - lastPlay}ms 内重复点击，忽略`);
        return false;
      }
      this.lastPlayTime[messageId] = now;

      const message = this.messages.find(msg => msg.id === messageId);
      if (!message) {
        Logger.warn('ChatViewModel', `要播报的消息不存在: ${messageId}`);
        return false;
      }

      if (message.role !== MessageRole.ASSISTANT) {
        Logger.warn('ChatViewModel', '只能播报助手消息');
        return false;
      }

      Logger.info('ChatViewModel', `手动播报消息: ${messageId}`);
      
      // 使用自动播报服务进行播报
      await this.autoTTSService.playMessage(message.content, message.id);
      
      // 设置消息播放状态
      message.isPlaying = true;
      
      return true;

    } catch (error) {
      Logger.error('ChatViewModel', `手动播报消息失败: ${(error as Error).message}`);
      return false;
    }
  }

  /**
   * 停止自动播报服务
   */
  async stopAutoPlayback(): Promise<void> {
    try {
      await this.autoTTSService.stopPlayback();
      
      // 重置所有消息的播放状态
      this.messages.forEach(message => {
        if (message.isPlaying) {
          message.isPlaying = false;
        }
      });
      
      Logger.info('ChatViewModel', '自动播报已停止');
    } catch (error) {
      Logger.error('ChatViewModel', `停止自动播报失败: ${(error as Error).message}`);
    }
  }

  /**
   * 获取自动播报服务状态
   */
  getAutoTTSStatus(): AutoTTSStatus {
    const status: AutoTTSStatus = {
      isEnabled: this.autoTTSService.isAutoPlayEnabled(),
      isPlaying: this.autoTTSService.isPlaying(),
      queueLength: this.autoTTSService.getQueueLength()
    };
    return status;
  }

  //=================== 会话管理相关方法 ===================

  /**
   * 创建新会话（兼容旧接口，不绑定系统提示词）
   */
  async createNewSession(): Promise<Session | null> {
    return await this.createNewSessionWithPrompt(null);
  }

  /**
   * 创建新会话（绑定系统提示词）
   */
  async createNewSessionWithPrompt(selectedPrompt: SystemPrompt | null): Promise<Session | null> {
    try {
      Logger.info('ChatViewModel', `创建新会话，系统提示词: ${selectedPrompt?.name || '无'}`);
      
      // 先保存当前会话的消息
      if (this.currentSession) {
        await this.saveMessages();
      }
      
      // 停止所有音频播放
      await this.stopAllAudio();
      
      // 创建新会话（传入系统提示词ID）
      const newSession = await this.sessionManager.createNewSessionWithPrompt(selectedPrompt?.id || null);
      
      // 更新当前会话
      this.currentSession = newSession;
      
      // 清空消息列表（新会话开始）
      this.messages = [];
      
      // 更新会话列表
      await this.loadSessions();
      
      Logger.info('ChatViewModel', `新会话创建成功: ${newSession.id}, 提示词: ${selectedPrompt?.name || '无'}`);
      return newSession;
      
    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'ChatViewModel';
      errorContext.function = 'createNewSession';
      errorContext.additionalInfo = JSON.stringify({
        promptName: selectedPrompt?.name || 'none',
        errorType: 'SessionCreationFailed'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        errorManager.handleError(
          errorManager.createError(
            ErrorType.BUSINESS,
            ErrorCode.UNKNOWN_ERROR,
            `创建新会话失败: ${error}`,
            errorContext,
            ErrorLevel.ERROR,
            error
          )
        );
      }
      
      return null;
    }
  }

  /**
   * 更换当前会话的系统提示词
   */
  async changeCurrentSessionPrompt(selectedPrompt: SystemPrompt | null): Promise<boolean> {
    try {
      if (!this.currentSession) {
        Logger.warn('ChatViewModel', '没有当前会话，无法更换系统提示词');
        return false;
      }
      
      Logger.info('ChatViewModel', `更换当前会话系统提示词: ${selectedPrompt?.name || '移除提示词'}`);
      
      // 更新会话的systemPromptId
      this.currentSession.systemPromptId = selectedPrompt?.id || null;
      
      // 保存会话更新
      await this.sessionManager.updateSessionPrompt(this.currentSession.id, selectedPrompt?.id || null);
      
      // 更新会话列表
      await this.loadSessions();
      
      Logger.info('ChatViewModel', `当前会话系统提示词更换成功: ${this.currentSession.name}`);
      return true;
      
    } catch (error) {
      Logger.error('ChatViewModel', `更换会话系统提示词失败: ${error}`);
      return false;
    }
  }

  /**
   * 切换到指定会话
   */
  async switchToSession(sessionId: string): Promise<boolean> {
    try {
      Logger.info('ChatViewModel', `切换到会话: ${sessionId}`);
      
      if (this.currentSession && this.currentSession.id === sessionId) {
        Logger.info('ChatViewModel', '已经是当前会话，无需切换');
        return true;
      }
      
      // 保存当前会话的消息
      if (this.currentSession) {
        await this.saveMessages();
      }
      
      // 停止所有音频播放
      await this.stopAllAudio();
      
      // 切换会话
      const targetSession = await this.sessionManager.switchToSession(sessionId);
      
      if (!targetSession) {
        Logger.error('ChatViewModel', `切换会话失败: 会话不存在 ${sessionId}`);
        return false;
      }
      
      // 更新当前会话
      this.currentSession = targetSession;
      
      // 加载新会话的消息
      await this.loadMessages();
      
      Logger.info('ChatViewModel', `会话切换成功: ${targetSession.name}`);
      return true;
      
    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'ChatViewModel';
      errorContext.function = 'switchToSession';
      errorContext.additionalInfo = JSON.stringify({
        sessionId: sessionId,
        errorType: 'SessionSwitchFailed'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        errorManager.handleError(
          errorManager.createError(
            ErrorType.BUSINESS,
            ErrorCode.UNKNOWN_ERROR,
            `切换会话失败: ${error}`,
            errorContext,
            ErrorLevel.ERROR,
            error
          )
        );
      }
      
      return false;
    }
  }

  /**
   * 更新当前会话信息（增量更新，避免重新加载整个会话列表）
   */
  private async updateCurrentSessionInfo(): Promise<void> {
    if (!this.currentSession) {
      return;
    }
    
    try {
      // 从存储中获取最新的会话信息
      const sessions = await this.sessionManager.getSessions();
      const updatedSession = sessions.find(s => s.id === this.currentSession!.id);
      
      if (updatedSession) {
        // 更新当前会话的引用，保持会话对象不变，只更新属性
        this.currentSession!.name = updatedSession.name;
        this.currentSession!.messageCount = updatedSession.messageCount;
        this.currentSession!.updatedAt = updatedSession.updatedAt;
        this.currentSession!.systemPromptId = updatedSession.systemPromptId;
        
        // 同时更新会话列表中的对应会话
        const sessionIndex = this.sessions.findIndex(s => s.id === this.currentSession!.id);
        if (sessionIndex !== -1) {
          this.sessions[sessionIndex].name = updatedSession.name;
          this.sessions[sessionIndex].messageCount = updatedSession.messageCount;
          this.sessions[sessionIndex].updatedAt = updatedSession.updatedAt;
          this.sessions[sessionIndex].systemPromptId = updatedSession.systemPromptId;
        }
        
        Logger.debug('ChatViewModel', `当前会话信息已更新: ${this.currentSession.name}`);
      }
    } catch (error) {
      Logger.error('ChatViewModel', `更新当前会话信息失败: ${error}`);
    }
  }

  /**
   * 删除会话
   */
  async deleteSession(sessionId: string): Promise<boolean> {
    try {
      Logger.info('ChatViewModel', `删除会话: ${sessionId}`);
      
      // 停止所有音频播放
      await this.stopAllAudio();
      
      // 删除会话
      await this.sessionManager.deleteSession(sessionId);
      
      // 如果删除的是当前会话，需要切换到其他会话
      if (this.currentSession && this.currentSession.id === sessionId) {
        // 重新加载当前会话
        await this.loadCurrentSession();
        await this.loadMessages();
      }
      
      // 更新会话列表
      await this.loadSessions();
      
      Logger.info('ChatViewModel', `会话删除成功: ${sessionId}`);
      return true;
      
    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'ChatViewModel';
      errorContext.function = 'deleteSession';
      errorContext.additionalInfo = JSON.stringify({
        sessionId: sessionId,
        errorType: 'SessionDeletionFailed'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        errorManager.handleError(
          errorManager.createError(
            ErrorType.BUSINESS,
            ErrorCode.UNKNOWN_ERROR,
            `删除会话失败: ${error}`,
            errorContext,
            ErrorLevel.ERROR,
            error
          )
        );
      }
      
      return false;
    }
  }

  /**
   * 重命名会话
   */
  async renameSession(sessionId: string, newName: string): Promise<boolean> {
    try {
      Logger.info('ChatViewModel', `重命名会话: ${sessionId} -> ${newName}`);
      
      await this.sessionManager.renameSession(sessionId, newName);
      
      // 如果是当前会话，更新当前会话信息
      if (this.currentSession && this.currentSession.id === sessionId) {
        this.currentSession.name = newName;
      }
      
      // 更新会话列表
      await this.loadSessions();
      
      Logger.info('ChatViewModel', `会话重命名成功: ${sessionId}`);
      return true;
      
    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'ChatViewModel';
      errorContext.function = 'renameSession';
      errorContext.additionalInfo = JSON.stringify({
        sessionId: sessionId,
        newName: newName,
        errorType: 'SessionRenameFailed'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        errorManager.handleError(
          errorManager.createError(
            ErrorType.BUSINESS,
            ErrorCode.UNKNOWN_ERROR,
            `重命名会话失败: ${error}`,
            errorContext,
            ErrorLevel.ERROR,
            error
          )
        );
      }
      
      return false;
    }
  }

  /**
   * 获取会话统计信息
   */
  getSessionStats(): SessionStatsView {
    const stats: SessionStatsView = {
      totalSessions: this.sessions.length,
      maxSessions: 10, // 从SessionManager获取
      currentSessionName: this.currentSession?.name || null
    };
    return stats;
  }

  /**
   * 处理会话数据清除事件
   */
  private onSessionDataCleared(): void {
    Logger.info('ChatViewModel', '收到会话数据清除通知，开始重置状态');
    
    // 清空消息列表
    this.messages = [];
    
    // 清空会话列表
    this.sessions = [];
    
    // 清除当前会话
    this.currentSession = null;
    
    // 清除loading状态
    this.isLoading = false;
    
    Logger.info('ChatViewModel', '会话数据状态已重置');
  }

  /**
   * 处理服务器配置变更事件
   */
  private async onServerConfigChanged(config: ServerEndpoint): Promise<void> {
    Logger.info('ChatViewModel', `收到服务器配置变更通知: ${config.protocol}://${config.ip}:${config.port}`);
    
    try {
      // 重新初始化API管理器以应用新的服务器配置
      await this.apiManager.initialize();
      
      // 重新加载providers以获取最新的模型列表
      await this.loadProviders();
      
      Logger.info('ChatViewModel', '服务器配置变更处理完成，模型列表已更新');
    } catch (error) {
      Logger.error('ChatViewModel', `处理服务器配置变更失败: ${error}`);
    }
  }
  
  /**
   * 处理API模式变更事件
   */
  private async onAPIModeChanged(mode: APIMode): Promise<void> {
    Logger.info('ChatViewModel', `收到API模式变更通知: ${mode}`);
    
    try {
      // 重新加载providers以获取新模式下的模型列表
      await this.loadProviders();
      
      Logger.info('ChatViewModel', 'API模式变更处理完成，模型列表已更新');
    } catch (error) {
      Logger.error('ChatViewModel', `处理API模式变更失败: ${error}`);
    }
  }

  /**
   * 销毁ViewModel
   */
  async destroy(): Promise<void> {
    try {
      // 保存当前会话的消息
      if (this.currentSession) {
        await this.saveMessages();
      }
      
      // 停止所有音频播放
      await this.stopAllAudio();
      
      // 销毁TTS服务
      await this.ttsService.destroy();
      
      // 销毁自动播报服务
      await this.autoTTSService.destroy();
      
      // 销毁深度思考服务
      this.deepThinkingService.destroy();
      
      // 清理音频播放状态
      this.audioPlaybackStateManager.clearAllStates();
      
      // 销毁API服务
      this.apiService.destroy();
      this.apiManager.destroy();
      
      // 移除会话数据清除监听器
      // 注意：由于使用了箭头函数，这里移除监听器需要保存引用
      // 在当前实现中，监听器会在页面销毁时自动清理
      
      Logger.info('ChatViewModel', 'ViewModel已销毁');
    } catch (error) {
      Logger.error('ChatViewModel', `销毁ViewModel失败: ${(error as Error).message}`);
    }
  }
}

/**
 * 音频播放状态管理器
 * 专门负责管理音频播放状态，确保状态在消息重载等操作中得到保持
 */
class AudioPlaybackStateManager {
  private playingStates: Map<string, boolean> = new Map<string, boolean>();
  private ttsState: TTSState = TTSState.IDLE;
  
  /**
   * 保存消息播放状态
   * @param messageId 消息ID
   * @param isPlaying 是否正在播放
   */
  savePlayingState(messageId: string, isPlaying: boolean): void {
    if (isPlaying) {
      this.playingStates.set(messageId, true);
      Logger.info('AudioPlaybackStateManager', `保存消息播放状态: ${messageId} = ${isPlaying}`);
    } else {
      this.playingStates.delete(messageId);
      Logger.info('AudioPlaybackStateManager', `清除消息播放状态: ${messageId}`);
    }
  }
  
  /**
   * 保存TTS引擎状态
   * @param state TTS状态
   */
  saveTTSState(state: TTSState): void {
    this.ttsState = state;
    Logger.info('AudioPlaybackStateManager', `保存TTS状态: ${state}`);
  }
  
  /**
   * 检查消息是否正在播放
   * @param messageId 消息ID
   * @returns 是否正在播放
   */
  isMessagePlaying(messageId: string): boolean {
    return this.playingStates.has(messageId);
  }
  
  /**
   * 获取当前TTS状态
   * @returns TTS状态
   */
  getTTSState(): TTSState {
    return this.ttsState;
  }
  
  /**
   * 清除所有播放状态
   */
  clearAllStates(): void {
    this.playingStates.clear();
    this.ttsState = TTSState.IDLE;
    Logger.info('AudioPlaybackStateManager', '清除所有播放状态');
  }
  
  /**
   * 获取正在播放的消息ID列表
   * @returns 正在播放的消息ID列表
   */
  getPlayingMessageIds(): string[] {
    return Array.from(this.playingStates.keys());
  }
  
  /**
   * 检查是否有任何消息正在播放
   * @returns 是否有任何消息正在播放
   */
  hasAnyPlayingMessage(): boolean {
    return this.playingStates.size > 0;
  }
}
