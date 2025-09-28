import { Message, MessageRole, ChatRequest, Provider, SimpleMessage, SystemPrompt, Session, MultiRoleSession, isMultiRoleSession, SessionParticipant, ThinkingStatus, ThinkingStep, ToolCall, DebateSession, DebateStatus, DebateParticipantStats } from '../models/ChatModels';
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
import { LocalToolManager } from '../services/LocalToolManager';
import { MemoryManager } from '../utils/MemoryManager';

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
  private memoryManager: MemoryManager;
  
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
    this.memoryManager = MemoryManager.getInstance();
    
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
    
    // 获取包含记忆注入的系统提示词
    const systemPromptWithMemory = await this.getSystemPromptWithMemory();
    Logger.info('ChatViewModel', `深度思考模式 - 系统提示词长度: ${systemPromptWithMemory.length} 字符`);

    const filteredMessages = this.messages
      .filter(msg => !msg.isLoading && msg.role !== MessageRole.SYSTEM)
      .map(msg => ({
        role: msg.role === MessageRole.USER ? 'user' : 'assistant',
        content: msg.content
      } as SimpleMessage));

    // 添加系统提示词
    const finalMessages = [...filteredMessages];
    if (systemPromptWithMemory) {
      finalMessages.unshift({
        role: 'system',
        content: systemPromptWithMemory
      });
      Logger.info('ChatViewModel', '深度思考模式 - 已添加系统提示词到消息列表');
    } else {
      Logger.warn('ChatViewModel', '深度思考模式 - 未获取到系统提示词');
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

        // 处理工具调用结果
        if (result.toolsUsed && result.toolCalls && result.toolCalls.length > 0) {
          assistantMessage.toolType = 'mcp';
          assistantMessage.toolStatus = 'completed';

          // 获取实际执行的工具名称
          const executedToolNames: string[] = result.toolCalls.map((toolCall: ToolCall) => toolCall.function.name);
          assistantMessage.mcpToolNames = executedToolNames;

          // 更新工具名称显示，为了向后兼容也设置toolName
          if (executedToolNames.length === 1) {
            assistantMessage.toolName = executedToolNames[0];
          } else if (executedToolNames.length > 1) {
            assistantMessage.toolName = `${executedToolNames.length}个MCP工具`;
          }

          Logger.info('ChatViewModel', `深度思考使用了 ${result.toolCalls.length} 个工具: ${executedToolNames.join(', ')}`);
        }
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

      // 处理工具调用结果
      if (thinkingResult.toolsUsed && thinkingResult.toolCalls && thinkingResult.toolCalls.length > 0) {
        assistantMessage.toolType = 'mcp';
        assistantMessage.toolStatus = 'completed';

        // 获取实际执行的工具名称
        const executedToolNames: string[] = thinkingResult.toolCalls.map((toolCall: ToolCall) => toolCall.function.name);
        assistantMessage.mcpToolNames = executedToolNames;

        // 更新工具名称显示，为了向后兼容也设置toolName
        if (executedToolNames.length === 1) {
          assistantMessage.toolName = executedToolNames[0];
        } else if (executedToolNames.length > 1) {
          assistantMessage.toolName = `${executedToolNames.length}个MCP工具`;
        }

        Logger.info('ChatViewModel', `深度思考成功完成，使用了 ${thinkingResult.toolCalls.length} 个工具: ${executedToolNames.join(', ')}`);
      } else {
        Logger.info('ChatViewModel', '深度思考成功完成');
      }
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
      // 获取包含记忆注入的系统提示词
      const systemPromptWithMemory = await this.getSystemPromptWithMemory();
      Logger.info('ChatViewModel', `混合聊天模式 - 系统提示词长度: ${systemPromptWithMemory.length} 字符`);

      const hybridRequest: HybridChatRequest = {
        message: content,
        model: this.currentModel,
        provider: this.getAIProviderByName(this.currentProvider),
        enableSearch: enableWebSearch,
        enableTools: true, // 启用工具调用
        systemPrompt: systemPromptWithMemory,
        stream: false,
        max_tokens: 1500,
        temperature: 0.7
      };
  
      const hybridResponse = await this.hybridChatService.sendHybridChatRequest(hybridRequest);

      assistantMessage.content = hybridResponse.response.choices[0]?.message?.content || '未收到有效响应';

      // 同步工具调用状态
      if (hybridResponse.response.tool_status) {
        assistantMessage.toolStatus = hybridResponse.response.tool_status;
      }

      // 处理搜索结果
      if (hybridResponse.searchUsed && hybridResponse.searchInfo) {
        assistantMessage.webUsed = true;
        assistantMessage.toolType = 'search';
        assistantMessage.toolName = '网络搜索';
        assistantMessage.searchInfo = this.formatSearchInfoSimple(hybridResponse.searchInfo);
        assistantMessage.searchDetails = this.formatSearchInfoDetailed(hybridResponse.searchInfo);
      }

      // 处理MCP工具调用结果
      if (hybridResponse.toolsUsed && hybridResponse.toolCalls && hybridResponse.toolCalls.length > 0) {
        assistantMessage.toolType = 'mcp';
        assistantMessage.toolStatus = 'completed';
        // 获取实际执行的工具名称
        const executedToolNames = hybridResponse.toolCalls.map(toolCall => toolCall.function.name);
        assistantMessage.mcpToolNames = executedToolNames;

        // 更新工具名称显示，为了向后兼容也设置toolName
        if (executedToolNames.length === 1) {
          assistantMessage.toolName = executedToolNames[0];
        } else if (executedToolNames.length > 1) {
          assistantMessage.toolName = `${executedToolNames.length}个MCP工具`;
        }

        Logger.info('ChatViewModel', `MCP工具执行完成: ${executedToolNames.join(', ')}`);
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
      const systemPromptWithMemory = await this.getSystemPromptWithMemory();
      Logger.info('ChatViewModel', `服务端模式 - 系统提示词长度: ${systemPromptWithMemory.length} 字符`);

      if (systemPromptWithMemory) {
        finalMessages.unshift({
          role: 'system',
          content: systemPromptWithMemory
        });
        Logger.info('ChatViewModel', '服务端模式 - 已添加系统提示词到消息列表');
      } else {
        Logger.warn('ChatViewModel', '服务端模式 - 未获取到系统提示词');
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
        max_tokens: 1500,
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
        assistantMessage.toolType = 'search';
        assistantMessage.toolName = '网络搜索';
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
      // 获取包含记忆注入的系统提示词
      const systemPromptWithMemory = await this.getSystemPromptWithMemory();
      Logger.info('ChatViewModel', `智能消息模式 - 系统提示词长度: ${systemPromptWithMemory.length} 字符`);

      // 使用APIManager的智能聊天功能
      const response = await this.apiManager.sendSmartChatRequest(
        content,
        this.currentModel,
        systemPromptWithMemory
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

      if (response.toolsUsed && response.toolCalls && response.toolCalls.length > 0) {
        // 工具调用信息已包含在response中，更新消息状态
        assistantMessage.toolType = 'mcp';
        assistantMessage.toolStatus = 'completed';

        // 获取实际执行的工具名称
        const executedToolNames = response.toolCalls.map(toolCall => toolCall.function.name);
        assistantMessage.mcpToolNames = executedToolNames;

        // 更新工具名称显示，为了向后兼容也设置toolName
        if (executedToolNames.length === 1) {
          assistantMessage.toolName = executedToolNames[0];
        } else if (executedToolNames.length > 1) {
          assistantMessage.toolName = `${executedToolNames.length}个MCP工具`;
        }

        Logger.info('ChatViewModel', `使用了 ${response.toolCalls.length} 个工具: ${executedToolNames.join(', ')}`);
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
   * 处理多人会话多轮讨论
   */
  private async handleMultiRoleDiscussion(
    content: string,
    assistantMessage: Message,
    enableWebSearch: boolean
  ): Promise<void> {
    if (!this.currentSession || !isMultiRoleSession(this.currentSession)) {
      Logger.error('ChatViewModel', '多人会话讨论失败：当前会话不是多人会话');
      assistantMessage.content = '抱歉，多人会话处理失败';
      assistantMessage.isLoading = false;
      return;
    }

    const multiRoleSession = this.currentSession as MultiRoleSession;
    const participants = multiRoleSession.participants;
    const discussionRounds = multiRoleSession.discussionRounds || 3;

    Logger.info('ChatViewModel', `开始多人讨论：${participants.length}个参与者，${discussionRounds}轮讨论`);

    try {
      // 构建讨论结果
      let discussionResult = `🎯 **多人讨论结果**（${discussionRounds}轮）\n\n`;

      // 为每轮讨论收集参与者的回应
      for (let round = 1; round <= discussionRounds; round++) {
        discussionResult += `### 第${round}轮讨论\n\n`;

        // 让每个参与者参与讨论
        for (const participant of participants) {
          try {
            // 构建当前参与者的系统提示词
            const participantSystemPrompt = this.getParticipantSystemPrompt(participant, round, discussionRounds);

            // 构建消息历史
            const messages = this.buildDiscussionMessages(content, participantSystemPrompt, round, participants);

            // 发送API请求获取参与者回应
            const response = await this.getParticipantResponse(messages, participant);

            // 添加到讨论结果
            discussionResult += `**${participant.displayName}**：${response}\n\n`;

            // 添加小延迟避免API限流
            await this.delay(500);

          } catch (error) {
            Logger.error('ChatViewModel', `参与者${participant.displayName}第${round}轮讨论失败: ${(error as Error).message}`);
            discussionResult += `**${participant.displayName}**：[讨论失败]\n\n`;
          }
        }

        discussionResult += `---\n\n`;
      }

      // 生成总结
      discussionResult += `### 📝 讨论总结\n\n`;
      const summary = await this.generateDiscussionSummary(content, discussionResult, participants);
      discussionResult += summary;

      // 设置最终结果
      assistantMessage.content = discussionResult;
      assistantMessage.isLoading = false;

      Logger.info('ChatViewModel', `多人讨论完成，共${discussionRounds}轮`);

    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('ChatViewModel', `多人讨论失败: ${errorMessage}`);
      assistantMessage.content = `抱歉，多人讨论过程中出现错误：${errorMessage}`;
      assistantMessage.isLoading = false;
      throw new Error(errorMessage);
    }
  }

  /**
   * 获取参与者的系统提示词
   */
  private getParticipantSystemPrompt(participant: SessionParticipant, currentRound: number, totalRounds: number): string {
    const basePrompt = `你是一个专业的AI助手，名为${participant.displayName}。

当前是多人讨论的第${currentRound}轮（共${totalRounds}轮）。

你的角色特点：
- 专业的知识和见解
- 建设性的讨论态度
- 尊重其他参与者的观点
- 提供有价值的补充信息

讨论规则：
1. 基于用户的原始问题提供你的专业观点
2. 可以参考前面轮次的讨论（如果有）
3. 保持简洁明了，1-2句话即可
4. 避免重复其他参与者已经提到的观点
5. 专注于你的专业领域`;

    return basePrompt;
  }

  /**
   * 构建讨论消息历史
   */
  private buildDiscussionMessages(
    userContent: string,
    systemPrompt: string,
    currentRound: number,
    participants: SessionParticipant[]
  ): SimpleMessage[] {
    const messages: SimpleMessage[] = [];

    // 添加系统提示词
    messages.push({
      role: 'system',
      content: systemPrompt
    });

    // 添加用户原始消息
    messages.push({
      role: 'user',
      content: `用户问题：${userContent}

请注意：这是多人讨论的第${currentRound}轮，共有${participants.length}个参与者参与讨论。请提供你的专业观点。`
    });

    return messages;
  }

  /**
   * 获取参与者的回应
   */
  private async getParticipantResponse(messages: SimpleMessage[], participant: SessionParticipant): Promise<string> {
    try {
      // 使用参与者指定的模型或默认模型
      const model = participant.model || this.currentModel;

      // 检查messages是否已经包含系统提示词
      const hasSystemPrompt = messages.some(msg => msg.role === 'system');

      let chatMessages: SimpleMessage[];

      if (!hasSystemPrompt && participant.systemPrompt && participant.systemPrompt.trim()) {
        // 如果没有系统提示词且参与者有系统提示词，添加到消息开头
        chatMessages = [
          {
            role: 'system',
            content: participant.systemPrompt.trim()
          },
          ...messages
        ];
      } else {
        // 否则直接使用传入的消息（应该已经包含系统提示词）
        chatMessages = messages;
      }

      const apiRequest: APIChatRequest = {
        messages: chatMessages,
        model: model,
        max_tokens: 1500, // 增加回复长度限制，支持更完整的表达
        temperature: 0.7,
        enable_web: false // 讨论中不启用网络搜索
      };

      const apiResponse = await this.apiManager.sendChatRequest(apiRequest);
      const response = apiResponse.choices[0]?.message?.content || '无回应';

      // 清理回复，去除多余的格式
      return response.trim().replace(/^#+\s*/, '').replace(/\n{3,}/g, '\n\n');

    } catch (error) {
      Logger.error('ChatViewModel', `获取参与者${participant.displayName}回应失败: ${(error as Error).message}`);
      return '回应失败';
    }
  }

  /**
   * 生成讨论总结
   */
  private async generateDiscussionSummary(userQuestion: string, discussionContent: string, participants: SessionParticipant[]): Promise<string> {
    try {
      const summaryPrompt = `请根据以下多人讨论内容，生成一个简洁的总结（200字以内）：

用户问题：${userQuestion}

讨论内容：
${discussionContent}

总结要求：
1. 概括主要观点和共识
2. 指出不同意见（如果有）
3. 给出最终的建议或答案
4. 保持客观中立的态度`;

      const summaryMessages: SimpleMessage[] = [
        { role: 'system', content: '你是一个专业的讨论总结助手，擅长提炼多人讨论的核心观点。' },
        { role: 'user', content: summaryPrompt }
      ];

      const apiRequest: APIChatRequest = {
        messages: summaryMessages,
        model: this.currentModel,
        max_tokens: 1500,
        temperature: 0.5,
        enable_web: false
      };

      const apiResponse = await this.apiManager.sendChatRequest(apiRequest);
      return apiResponse.choices[0]?.message?.content || '讨论总结生成失败';

    } catch (error) {
      Logger.error('ChatViewModel', `生成讨论总结失败: ${(error as Error).message}`);
      return '无法生成讨论总结';
    }
  }

  //=================== 辩论系统相关方法 ===================

  /**
   * 从用户第一句话提取辩论主题
   */
  private extractDebateTopic(userMessage: string): string {
    // 清理用户消息，移除多余空白字符
    const cleanMessage = userMessage.trim();

    // 如果消息较短（小于50字符），直接作为主题
    if (cleanMessage.length <= 50) {
      return cleanMessage;
    }

    // 使用正则表达式提取主题
    // 匹配问句、陈述句或观点表达
    const topicPatterns = [
      /^(.+？)/, // 中文问句
      /^(.+?\?)/, // 英文问句
      /^(.+?[。！？!?])/, // 以句号、感叹号或问号结尾的句子
      /^(.{10,50}?[，,、])/, // 10-50字符的短语（以逗号或顿号结尾）
      /^(.{20,60}?)/ // 20-60字符的短语
    ];

    for (const pattern of topicPatterns) {
      const match = cleanMessage.match(pattern);
      if (match && match[1]) {
        return match[1].trim();
      }
    }

    // 如果没有匹配到合适的模式，取前40个字符
    return cleanMessage.substring(0, 40) + (cleanMessage.length > 40 ? '...' : '');
  }

  /**
   * 分析讨论激烈程度
   */
  private analyzeDiscussionIntensity(messages: Message[]): number {
    if (messages.length === 0) return 0;

    let intensityScore = 0;
    const recentMessages = messages.slice(-10); // 分析最近10条消息

    for (const message of recentMessages) {
      if (message.role === MessageRole.ASSISTANT && message.content) {
        const content = message.content.toLowerCase();

        // 检测激烈讨论的关键词
        const intenseKeywords = [
          '强烈', '坚决', '完全不同意', '绝对', '必须', '错误', '反对', '批评',
          'strongly', 'absolutely', 'completely disagree', 'must', 'wrong', 'oppose', 'criticize'
        ];

        // 检测温和讨论的关键词
        const mildKeywords = [
          '建议', '或许', '可能', '也许', '个人观点', '仅供参考', '温和',
          'suggest', 'perhaps', 'maybe', 'personal opinion', 'reference only', 'mild'
        ];

        // 计算强度分数
        for (const keyword of intenseKeywords) {
          if (content.includes(keyword)) {
            intensityScore += 2;
          }
        }

        for (const keyword of mildKeywords) {
          if (content.includes(keyword)) {
            intensityScore += 0.5;
          }
        }

        // 检测感叹号和问号数量
        const punctuationCount = (content.match(/[!？?]/g) || []).length;
        intensityScore += punctuationCount * 0.5;

        // 检测消息长度（较长的回复可能表示更深入的讨论）
        if (content.length > 200) {
          intensityScore += 1;
        }
      }
    }

    // 将强度分数归一化到0-10的范围
    const maxPossibleIntensity = recentMessages.length * 5;
    const normalizedIntensity = maxPossibleIntensity > 0 ? (intensityScore / maxPossibleIntensity) * 10 : 0;

    return Math.min(10, Math.max(0, normalizedIntensity));
  }

  /**
   * 生成带上下文的辩论提示词
   */
  private generateContextualDebatePrompt(
    participant: SessionParticipant,
    debateTopic: string,
    currentRound: number,
    totalRounds: number,
    discussionIntensity: number,
    previousMessages: Message[]
  ): string {
    // 首先使用角色的原始系统提示词（如果存在）
    const rolePrompt = participant.systemPrompt || `你是一个专业的辩论参与者，名为${participant.displayName}。

**你的角色定位**：
- 基于${participant.displayName}的专业背景和观点
- 提供有深度和见解的论点
- 保持建设性的辩论态度`;

    const basePrompt = `${rolePrompt}

---

**辩论主题**：${debateTopic}

**当前阶段**：第${currentRound}轮（共${totalRounds}轮）

**讨论激烈程度**：${discussionIntensity.toFixed(1)}/10`;

    let contextualPrompt = basePrompt;

    // 根据讨论激烈程度调整提示词
    if (discussionIntensity >= 7) {
      contextualPrompt += `

**高强度讨论提示**：
- 前面的讨论已经相当激烈，请提供更有力的论据来支持你的观点
- 可以适当反驳前面的不同意见，但保持专业和尊重
- 避免情绪化的表达，用事实和逻辑来说服对方`;
    } else if (discussionIntensity >= 4) {
      contextualPrompt += `

**中等强度讨论提示**：
- 讨论正在升温，请提供更有深度的观点
- 可以对前面的观点进行补充或提出不同见解
- 保持客观中立的态度，用理性分析来支持你的论点`;
    } else {
      contextualPrompt += `

**初始讨论提示**：
- 这是辩论的早期阶段，请清晰地陈述你的核心观点
- 为辩论设定基调，提供有价值的见解
- 保持开放和建设性的态度`;
    }

    // 根据辩论轮次调整策略
    if (currentRound === 1) {
      contextualPrompt += `

**首轮策略**：
- 清晰陈述你的核心立场和主要论点
- 为后续辩论奠定基础
- 避免过早地反驳他人（这是开场陈述阶段）`;
    } else if (currentRound < totalRounds) {
      contextualPrompt += `

**中期辩论策略**：
- 针对前面参与者的观点进行回应
- 强化你的论点，适当反驳不同意见
- 提供新的证据或角度来支持你的立场`;
    } else {
      contextualPrompt += `

**总结阶段策略**：
- 总结你的核心论点和对整个辩论的贡献
- 回应最重要的反驳意见
- 提供最终的观点和结论性陈述`;
    }

    // 如果有前面的讨论内容，添加上下文
    if (previousMessages.length > 0) {
      contextualPrompt += `

**前面的讨论要点**：
${this.extractDiscussionKeyPoints(previousMessages)}

请针对以上讨论内容，提供你的回应：`;
    }

    return contextualPrompt;
  }

  /**
   * 提取讨论的关键要点
   */
  private extractDiscussionKeyPoints(messages: Message[]): string {
    const keyPoints: string[] = [];
    const assistantMessages = messages.filter(m => m.role === MessageRole.ASSISTANT);

    // 只取最近5条消息的要点
    const recentMessages = assistantMessages.slice(-5);

    for (const message of recentMessages) {
      if (message.content && message.senderName) {
        // 简化内容，提取要点
        const content = message.content
          .replace(/\*\*([^*]+)\*\*/g, '$1') // 移除加粗标记
          .replace(/\*([^*]+)\*/g, '$1')     // 移除斜体标记
          .replace(/#{1,6}\s*/g, '')          // 移除标题标记
          .trim();

        if (content.length > 20) {
          // 取内容的前100个字符作为要点
          const point = content.length > 100 ? content.substring(0, 100) + '...' : content;
          keyPoints.push(`- ${message.senderName}: ${point}`);
        }
      }
    }

    return keyPoints.length > 0 ? keyPoints.join('\n') : '暂无前面的讨论内容';
  }

  /**
   * 生成辩论总结
   */
  private async generateDebateSummary(
    debateTopic: string,
    debateMessages: Message[],
    participantStats: DebateParticipantStats[]
  ): Promise<string> {
    try {
      // 提取各参与者的关键论点
      const participantArguments = participantStats.map(stat => {
        const participant = this.getParticipantFromStats(stat.roleId);
        return `**${participant?.displayName || '未知参与者'}**：
- 发言次数：${stat.responseCount}次
- 平均强度：${stat.averageIntensity.toFixed(1)}/10
- 主要论点：${stat.keyPoints.slice(0, 3).join('；')}`;
      }).join('\n\n');

      const summaryPrompt = `请根据以下辩论内容，生成一个专业的辩论总结：

**辩论主题**：${debateTopic}

**参与者表现**：
${participantArguments}

**完整辩论内容**：
${debateMessages.map(m => `${m.senderName || '参与者'}: ${m.content}`).join('\n')}

总结要求：
1. **辩论概述**：简要总结辩论的主要过程和焦点
2. **各方观点**：概括每个参与者的核心立场和主要论点
3. **共识与分歧**：指出参与者之间的共识点和主要分歧
4. **胜负评估**：基于论证质量和说服力，评估哪方的观点更有说服力
5. **最终结论**：给出对辩论主题的最终见解或建议

请生成一个结构化、客观的辩论总结（300-400字）：`;

      const summaryMessages: SimpleMessage[] = [
        { role: 'system', content: '你是一个专业的辩论评委和分析专家，擅长分析和总结多角度的辩论内容。' },
        { role: 'user', content: summaryPrompt }
      ];

      const apiRequest: APIChatRequest = {
        messages: summaryMessages,
        model: this.currentModel,
        max_tokens: 1500,
        temperature: 0.3,
        enable_web: false
      };

      const apiResponse = await this.apiManager.sendChatRequest(apiRequest);
      return apiResponse.choices[0]?.message?.content || '辩论总结生成失败';

    } catch (error) {
      Logger.error('ChatViewModel', `生成辩论总结失败: ${(error as Error).message}`);
      return '无法生成辩论总结';
    }
  }

  /**
   * 从统计数据获取参与者信息
   */
  private getParticipantFromStats(roleId: string): SessionParticipant | undefined {
    if (!this.currentSession || !isMultiRoleSession(this.currentSession)) {
      return undefined;
    }

    const multiRoleSession = this.currentSession as MultiRoleSession;
    return multiRoleSession.participants.find(p => p.roleId === roleId);
  }

  /**
   * 处理辩论式多人讨论
   */
  private async handleDebateDiscussion(
    content: string,
    assistantMessage: Message,
    enableWebSearch: boolean
  ): Promise<void> {
    if (!this.currentSession || !isMultiRoleSession(this.currentSession)) {
      Logger.error('ChatViewModel', '辩论讨论失败：当前会话不是多人会话');
      assistantMessage.content = '抱歉，辩论处理失败';
      assistantMessage.isLoading = false;
      return;
    }

    const multiRoleSession = this.currentSession as MultiRoleSession;
    const participants = multiRoleSession.participants;
    const discussionRounds = multiRoleSession.discussionRounds || 3;

    Logger.info('ChatViewModel', `开始辩论讨论：${participants.length}个参与者，${discussionRounds}轮辩论`);

    try {
      // 移除初始的assistant消息，我们将实时添加每个参与者的消息
      this.removeMessage(assistantMessage);

      // 第一步：提取辩论主题
      const debateTopic = this.extractDebateTopic(content);
      Logger.info('ChatViewModel', `提取辩论主题：${debateTopic}`);

      // 添加辩论开始的提示消息
      const introMessage = new Message(
        MessageRole.ASSISTANT,
        `🎯 **辩论主题**：${debateTopic}\n\n👥 **参与者**：${participants.map(p => p.displayName).join('、')}\n\n💬 **讨论轮数**：${discussionRounds}轮\n\n---\n\n🚀 辩论即将开始，每位参与者将根据自己的角色观点进行讨论...`,
        this.generateMessageId()
      );
      this.addMessage(introMessage);
      await this.scrollToBottom();

      // 初始化辩论状态
      let debateStatus = DebateStatus.OPENING_STATEMENT;
      let currentRound = 0;
      const allMessages: Message[] = [];
      const participantStats: DebateParticipantStats[] = participants.map(p => {
        const stats: DebateParticipantStats = {
          roleId: p.roleId,
          responseCount: 0,
          averageIntensity: 0,
          keyPoints: [],
          effectivenessScore: 0
        };
        return stats;
      });

      // 进行多轮辩论
      for (let round = 1; round <= discussionRounds; round++) {
        currentRound = round;

        // 更新辩论状态
        if (round === 1) {
          debateStatus = DebateStatus.OPENING_STATEMENT;
        } else if (round < discussionRounds) {
          debateStatus = DebateStatus.REBUTTAL;
        } else {
          debateStatus = DebateStatus.CLOSING_STATEMENT;
        }

        // 添加轮次分隔消息
        const roundMessage = new Message(
          MessageRole.ASSISTANT,
          `🔹 **第${round}轮${this.getDebateStageName(debateStatus)}**`,
          this.generateMessageId()
        );
        this.addMessage(roundMessage);
        await this.scrollToBottom();

        // 每个参与者依次发言
        for (const participant of participants) {
          try {
            // 添加"思考中"状态消息
            const thinkingMessage = new Message(
              MessageRole.ASSISTANT,
              `正在思考中...`,
              this.generateMessageId()
            );
            thinkingMessage.senderName = participant.displayName;
            thinkingMessage.senderRoleId = participant.roleId;
            thinkingMessage.senderAvatar = participant.avatar;
            thinkingMessage.isLoading = true;
            this.addMessage(thinkingMessage);
            await this.scrollToBottom();

            // 分析当前讨论激烈程度
            const currentIntensity = this.analyzeDiscussionIntensity(allMessages);

            // 生成带上下文的提示词
            const contextualPrompt = this.generateContextualDebatePrompt(
              participant,
              debateTopic,
              round,
              discussionRounds,
              currentIntensity,
              allMessages
            );

            // 构建消息历史
            const messages = this.buildDebateMessages(content, contextualPrompt, debateTopic, round, allMessages);

            // 获取参与者的回应
            const response = await this.getParticipantResponse(messages, participant);

            // 移除"思考中"消息
            this.removeMessage(thinkingMessage);

            // 创建参与者的实际发言消息
            const participantMessage = new Message(
              MessageRole.ASSISTANT,
              response,
              this.generateMessageId()
            );
            participantMessage.senderName = participant.displayName;
            participantMessage.senderRoleId = participant.roleId;
            participantMessage.senderAvatar = participant.avatar;

            // 实时添加消息到界面
            this.addMessage(participantMessage);
            allMessages.push(participantMessage);
            await this.scrollToBottom();

            // 更新参与者统计
            const stats = participantStats.find(s => s.roleId === participant.roleId);
            if (stats) {
              stats.responseCount++;
              stats.averageIntensity = (stats.averageIntensity * (stats.responseCount - 1) + currentIntensity) / stats.responseCount;

              // 提取关键论点
              const keyPoints = this.extractKeyPointsFromResponse(response);
              stats.keyPoints.push(...keyPoints);
              stats.effectivenessScore = stats.averageIntensity * stats.responseCount;
            }

            // 添加小延迟避免API限流
            await this.delay(800);

          } catch (error) {
            Logger.error('ChatViewModel', `参与者${participant.displayName}第${round}轮辩论失败: ${(error as Error).message}`);

            // 移除可能存在的"思考中"消息
            const thinkingMessages = this.messages.filter(m =>
              m.senderRoleId === participant.roleId && m.isLoading
            );
            thinkingMessages.forEach(m => this.removeMessage(m));

            // 添加错误消息
            const errorMessage = new Message(
              MessageRole.ASSISTANT,
              `抱歉，我暂时无法参与讨论。`,
              this.generateMessageId()
            );
            errorMessage.senderName = participant.displayName;
            errorMessage.senderRoleId = participant.roleId;
            errorMessage.senderAvatar = participant.avatar;
            this.addMessage(errorMessage);
            await this.scrollToBottom();
          }
        }
      }

      // 生成辩论总结
      debateStatus = DebateStatus.SUMMARY;
      const summaryLoadingMessage = new Message(
        MessageRole.ASSISTANT,
        `🏆 正在分析辩论内容并生成总结...`,
        this.generateMessageId()
      );
      summaryLoadingMessage.isLoading = true;
      this.addMessage(summaryLoadingMessage);
      await this.scrollToBottom();

      const summary = await this.generateDebateSummary(debateTopic, allMessages, participantStats);

      // 移除总结加载消息
      this.removeMessage(summaryLoadingMessage);

      // 添加最终总结消息
      const summaryMessage = new Message(
        MessageRole.ASSISTANT,
        `🏆 **辩论总结**\n\n${summary}`,
        this.generateMessageId()
      );
      this.addMessage(summaryMessage);
      await this.scrollToBottom();

      Logger.info('ChatViewModel', `辩论讨论完成，共${discussionRounds}轮`);

    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('ChatViewModel', `辩论讨论失败: ${errorMessage}`);

      // 添加错误消息
      const errorMsg = new Message(
        MessageRole.ASSISTANT,
        `❌ 抱歉，辩论过程中出现错误：${errorMessage}`,
        this.generateMessageId()
      );
      this.addMessage(errorMsg);
      await this.scrollToBottom();
      throw new Error(errorMessage);
    }
  }

  /**
   * 获取辩论阶段名称
   */
  private getDebateStageName(status: DebateStatus): string {
    switch (status) {
      case DebateStatus.OPENING_STATEMENT:
        return '（开场陈述）';
      case DebateStatus.REBUTTAL:
        return '（反驳辩论）';
      case DebateStatus.CLOSING_STATEMENT:
        return '（总结陈述）';
      default:
        return '';
    }
  }

  /**
   * 构建辩论消息历史
   */
  private buildDebateMessages(
    userContent: string,
    systemPrompt: string,
    debateTopic: string,
    currentRound: number,
    previousMessages: Message[]
  ): SimpleMessage[] {
    const messages: SimpleMessage[] = [];

    // 添加系统提示词（这里包含了角色原始提示词和辩论上下文）
    messages.push({
      role: 'system',
      content: systemPrompt
    });

    // 添加用户原始问题和辩论主题
    messages.push({
      role: 'user',
      content: `**用户问题**：${userContent}

**辩论主题**：${debateTopic}

**当前轮次**：第${currentRound}轮

请基于你的角色定位和前面的讨论内容，提供有针对性的辩论观点。`
    });

    return messages;
  }

  /**
   * 从回应中提取关键论点
   */
  private extractKeyPointsFromResponse(response: string): string[] {
    const keyPoints: string[] = [];

    // 按句子分割
    const sentences = response.split(/[。！？!?.]/).filter(s => s.trim().length > 10);

    // 提取包含论点标志的句子
    const argumentKeywords = ['认为', '观点', '立场', '理由', '因为', '所以', '首先', '其次', '最后', 'believe', 'think', 'argue', 'because', 'therefore', 'first', 'second', 'finally'];

    for (const sentence of sentences) {
      const cleanSentence = sentence.trim();
      if (cleanSentence.length > 15 && cleanSentence.length < 100) {
        // 检查是否包含论点关键词
        const hasArgumentKeyword = argumentKeywords.some(keyword =>
          cleanSentence.toLowerCase().includes(keyword.toLowerCase())
        );

        if (hasArgumentKeyword || cleanSentence.includes('：') || cleanSentence.includes(':')) {
          keyPoints.push(cleanSentence);
        }
      }
    }

    // 如果没有找到明确的论点，取前两个有意义的句子
    if (keyPoints.length === 0 && sentences.length > 0) {
      keyPoints.push(...sentences.slice(0, 2).map(s => s.trim()));
    }

    return keyPoints.slice(0, 3); // 最多返回3个关键论点
  }

  /**
   * 生成消息ID
   */
  private generateMessageId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  }

  /**
   * 延迟函数
   */
  private async delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
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

    // 初始化工具调用状态
    if (currentFeatures.enableWebSearch || currentFeatures.enableMCPTools) {
      assistantMessage.toolStatus = 'calling';
      if (currentFeatures.enableWebSearch) {
        assistantMessage.toolType = 'search';
        assistantMessage.toolName = '网络搜索';
      } else if (currentFeatures.enableMCPTools) {
        assistantMessage.toolType = 'mcp';
        assistantMessage.toolName = 'MCP工具';
        // 初始化为空数组，等待实际执行的工具结果
        assistantMessage.mcpToolNames = [];
      }
    }

    this.messages.push(assistantMessage);

    this.isLoading = true;

    try {
      // 检查是否为多人会话，优先处理多人会话逻辑
      if (this.currentSession && isMultiRoleSession(this.currentSession)) {
        Logger.info('ChatViewModel', '检测到多人会话，启动辩论式讨论');
        await this.handleDebateDiscussion(content, assistantMessage, currentFeatures.enableWebSearch);
      } else if (currentFeatures.enableDeepThinking) {
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

      // 错误情况下设置工具调用失败状态
      if (assistantMessage.toolStatus === 'calling') {
        assistantMessage.toolStatus = 'failed';
      }
    } finally {
      assistantMessage.isLoading = false;
      this.isLoading = false;

      // 确保工具调用状态正确结束
      if (assistantMessage.toolStatus === 'calling') {
        assistantMessage.toolStatus = 'completed';
      }

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
   * 获取会话管理器实例
   */
  getSessionManager(): SessionManager {
    return this.sessionManager;
  }

  /**
   * 获取当前会话的系统提示词 - 增强版本支持多轮角色对话
   */
  getCurrentSessionSystemPrompt(): SystemPrompt | null {
    if (!this.currentSession) {
      Logger.debug('ChatViewModel', '当前没有会话');
      return null;
    }

    // 优先使用活跃角色ID，如果没有则使用绑定的系统提示词ID
    const activeRoleId = this.currentSession.getActiveRoleId?.() || this.currentSession.activeRoleId;
    const targetPromptId = activeRoleId || this.currentSession.systemPromptId;

    if (!targetPromptId) {
      Logger.debug('ChatViewModel', '当前会话未绑定系统提示词');
      return null;
    }

    const prompt = this.systemPrompts.find(p => p.id === targetPromptId);
    if (prompt) {
      Logger.info('ChatViewModel', `获取到系统提示词: ${prompt.name} (ID: ${prompt.id})`);
      if (prompt.isRole) {
        Logger.info('ChatViewModel', `当前为角色模式: ${prompt.roleCategory} - ${prompt.roleDescription}`);
      }

      // 如果活跃角色与绑定角色不同，记录状态
      if (activeRoleId && activeRoleId !== this.currentSession.systemPromptId) {
        Logger.info('ChatViewModel', `使用临时活跃角色: ${activeRoleId}`);
      }
    } else {
      Logger.warn('ChatViewModel', `未找到系统提示词: ${targetPromptId}`);
    }

    return prompt || null;
  }

  /**
   * 获取当前会话系统提示词内容 - 增强版本支持多轮角色对话
   * 记忆功能现在通过search_memories工具动态获取，不再预先注入
   */
  async getSystemPromptWithMemory(): Promise<string> {
    try {
      // 获取原始系统提示词
      const originalPrompt = this.getCurrentSessionSystemPrompt();
      const systemPromptContent = originalPrompt?.content || '';

      if (originalPrompt) {
        Logger.info('ChatViewModel', `应用系统提示词: ${originalPrompt.name} (${originalPrompt.isRole ? '角色模式' : '普通模式'})`);
        Logger.debug('ChatViewModel', `提示词内容长度: ${systemPromptContent.length} 字符`);

        if (originalPrompt.isRole) {
          Logger.info('ChatViewModel', `角色信息: ${originalPrompt.roleCategory} - ${originalPrompt.roleDescription}`);
        }
      } else {
        Logger.warn('ChatViewModel', '当前会话未绑定系统提示词，将使用默认行为');
      }

      return systemPromptContent;
    } catch (error) {
      Logger.error('ChatViewModel', `获取系统提示词失败: ${error}`);
      // 出错时返回空字符串
      return '';
    }
  }

  /**
   * 切换当前会话的活跃角色
   */
  async switchActiveRole(roleId: string): Promise<void> {
    try {
      if (!this.currentSession) {
        Logger.warn('ChatViewModel', '没有当前会话，无法切换活跃角色');
        return;
      }

      // 验证角色是否存在
      const role = this.systemPrompts.find(p => p.id === roleId && p.isRole);
      if (!role) {
        Logger.warn('ChatViewModel', `角色不存在: ${roleId}`);
        return;
      }

      // 设置活跃角色
      this.currentSession.setActiveRole(roleId);

      // 保存会话更新（只更新时间，不改变其他信息）
      await this.sessionManager.updateSessionInfo(this.currentSession.id, undefined, {});

      Logger.info('ChatViewModel', `已切换活跃角色: ${role.name} (${roleId})`);

      // 立即重新加载提示词以确保下次消息使用新角色
      await this.loadSystemPrompts();
    } catch (error) {
      Logger.error('ChatViewModel', `切换活跃角色失败: ${error}`);
    }
  }

  /**
   * 清除当前会话的活跃角色（回到默认绑定角色）
   */
  async clearActiveRole(): Promise<void> {
    try {
      if (!this.currentSession) {
        Logger.warn('ChatViewModel', '没有当前会话，无法清除活跃角色');
        return;
      }

      this.currentSession.clearActiveRole();

      // 保存会话更新（只更新时间，不改变其他信息）
      await this.sessionManager.updateSessionInfo(this.currentSession.id, undefined, {});

      Logger.info('ChatViewModel', '已清除活跃角色，回到默认绑定角色');

      // 立即重新加载提示词
      await this.loadSystemPrompts();
    } catch (error) {
      Logger.error('ChatViewModel', `清除活跃角色失败: ${error}`);
    }
  }

  /**
   * 获取当前活跃角色信息
   */
  getCurrentActiveRole(): SystemPrompt | null {
    if (!this.currentSession) {
      return null;
    }

    const activeRoleId = this.currentSession.getActiveRoleId?.() || this.currentSession.activeRoleId;
    if (!activeRoleId) {
      return null;
    }

    return this.systemPrompts.find(p => p.id === activeRoleId && p.isRole) || null;
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
   * 创建多人会话
   */
  async createNewMultiRoleSession(participantPrompts: SystemPrompt[]): Promise<Session | null> {
    return await this.createNewMultiRoleSessionWithRounds(participantPrompts, 3); // 默认3轮讨论
  }

  /**
   * 创建多人会话（带讨论轮数）
   */
  async createNewMultiRoleSessionWithRounds(participantPrompts: SystemPrompt[], discussionRounds: number = 3): Promise<Session | null> {
    if (!participantPrompts || participantPrompts.length === 0) {
      Logger.warn('ChatViewModel', '多人会话创建请求缺少参与者');
      return null;
    }

    try {
      Logger.info('ChatViewModel', `创建多人会话，参与者数量: ${participantPrompts.length}, 讨论轮数: ${discussionRounds}`);

      if (this.currentSession) {
        await this.saveMessages();
      }

      await this.stopAllAudio();

      const newSession = await this.sessionManager.createMultiRoleSession(participantPrompts, discussionRounds);

      this.currentSession = newSession;
      this.messages = [];
      await this.loadSessions();

      const participantNames = participantPrompts.map(participant => participant.name).join(', ');
      Logger.info('ChatViewModel', `多人会话创建成功: ${newSession.id}, 参与者: ${participantNames}, 讨论轮数: ${discussionRounds}`);
      return newSession;

    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'ChatViewModel';
      errorContext.function = 'createNewMultiRoleSessionWithRounds';
      errorContext.additionalInfo = JSON.stringify({
        participantCount: participantPrompts.length,
        participantIds: participantPrompts.map(participant => participant.id),
        discussionRounds: discussionRounds
      });

      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        errorManager.handleError(
          errorManager.createError(
            ErrorType.BUSINESS,
            ErrorCode.UNKNOWN_ERROR,
            `创建多人会话失败: ${error}`,
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

  //=================== 辩论相关辅助方法 ===================

  /**
   * 添加消息到消息列表
   */
  private addMessage(message: Message): void {
    this.messages.push(message);
    Logger.debug('ChatViewModel', `添加消息: ${message.senderName || 'System'} - ${message.content.substring(0, 50)}...`);
  }

  /**
   * 从消息列表中移除指定消息
   */
  private removeMessage(message: Message): void {
    const index = this.messages.findIndex(m => m.id === message.id);
    if (index !== -1) {
      this.messages.splice(index, 1);
      Logger.debug('ChatViewModel', `移除消息: ${message.senderName || 'System'} - ${message.content.substring(0, 50)}...`);
    }
  }

  /**
   * 滚动到消息列表底部
   */
  private async scrollToBottom(): Promise<void> {
    // 使用延迟确保UI更新完成后再滚动
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        // 由于这是ViewModel，具体的滚动需要通过回调或事件通知UI层
        // 这里使用简单的延迟模拟，实际使用中页面会自动检测新消息并滚动
        Logger.debug('ChatViewModel', '请求滚动到底部');
        resolve();
      }, 200); // 增加延迟确保UI完全更新
    });
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
