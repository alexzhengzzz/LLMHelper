/**
 * 混合聊天服务
 * 整合搜索功能和直连AI调用
 */

import { ChatRequest, ChatResponse, AIProvider, Tool } from '../types/APITypes';
import { DirectAPIService } from './DirectAPIService';
import { SearchAPIClient, SearchResponse, SearchClientConfig } from '../clients/SearchAPIClient';
import { SearchDecisionEngine, SearchDecision } from './SearchDecisionEngine';
import { MessageEnhancer, EnhancedMessage, SearchInfo } from './MessageEnhancer';
import { Logger } from '../utils/Logger';
import { LocalToolManager } from './LocalToolManager';
import { MCPTool, ToolCallRequest, ToolCallResult } from '../types/MCPTypes';
import { ToolCall, FunctionCallingChatRequest, FunctionCallingChatResponse, EnhancedMessage as FCEnhancedMessage, ParameterProperty } from '../models/ChatModels';
import { AppContext } from '../utils/AppContext';
import { TextContent, ImageContent } from '../types/MCPTypes';

/**
 * 消息接口，符合ArkTS严格类型要求
 */
interface ChatMessage {
  role: string;
  content: string;
}

/**
 * 混合聊天请求参数
 */
export interface HybridChatRequest {
  message: string;
  model: string;
  provider?: AIProvider;
  enableSearch: boolean;
  enableTools?: boolean;  // 新增：启用工具调用
  systemPrompt?: string;  // 新增：系统提示词
  stream?: boolean;
  max_tokens?: number;
  temperature?: number;
}

/**
 * 混合聊天响应
 */
export interface HybridChatResponse {
  response: ChatResponse;
  searchUsed: boolean;
  toolsUsed: boolean;        // 新增：是否使用了工具
  toolCalls?: ToolCall[];    // 新增：工具调用详情
  toolResults?: ToolCallResult[];  // 新增：工具调用结果
  searchInfo?: SearchInfo;
  searchDecision?: SearchDecision;
  searchTime?: number;
  toolTime?: number;         // 新增：工具调用耗时
  totalTime: number;
}

/**
 * 混合服务测试结果
 */
export interface HybridServiceTestResult {
  directAI: boolean;
  searchService: boolean;
  searchProviders: string[];
  totalTests: number;
  passedTests: number;
}

/**
 * 预处理请求结果
 */
export interface PreprocessRequestResult {
  finalMessage: string;
  searchUsed: boolean;
  searchInfo?: SearchInfo;
  searchDecision?: SearchDecision;
}

/**
 * 服务状态
 */
export interface ServiceStatus {
  initialized: boolean;
  directAPIService: AIProvider[];
  searchAPIClient: SearchClientConfig;
  decisionEngine: boolean;
  messageEnhancer: boolean;
}

/**
 * 工具调用处理结果
 */
interface ToolCallHandleResult {
  finalResponse: ChatResponse;
  executedToolCalls: ToolCall[];
  executedToolResults: ToolCallResult[];
}

/**
 * 工具调用消息类型
 */
interface ToolCallMessage {
  tool_calls?: ToolCall[];
}

/**
 * 工具信息类
 */
class ToolInfo {
  name: string;
  description: string;

  constructor(name: string, description: string) {
    this.name = name;
    this.description = description;
  }
}


export class HybridChatService {
  private static instance: HybridChatService;
  private directAPIService: DirectAPIService;
  private searchAPIClient: SearchAPIClient;
  private searchDecisionEngine: SearchDecisionEngine;
  private messageEnhancer: MessageEnhancer;
  private localToolManager: LocalToolManager | null = null;

  private constructor() {
    this.directAPIService = new DirectAPIService();
    this.searchAPIClient = new SearchAPIClient();
    this.searchDecisionEngine = SearchDecisionEngine.getInstance();
    this.messageEnhancer = MessageEnhancer.getInstance();
    this.initializeToolManager();
  }

  /**
   * 初始化工具管理器
   */
  private initializeToolManager(): void {
    try {
      Logger.info('HybridChatService', '=== 开始初始化工具管理器 ===');
      const context = AppContext.getInstance().getContext();
      Logger.info('HybridChatService', `AppContext: ${context ? '已获取' : '未获取'}`);

      if (context) {
        this.localToolManager = LocalToolManager.getInstance(context);
        Logger.info('HybridChatService', 'LocalToolManager 实例创建成功');

        // 立即检查工具数量
        const toolCount = this.localToolManager.getAvailableTools().length;
        Logger.info('HybridChatService', `LocalToolManager 包含 ${toolCount} 个工具`);

        if (toolCount > 0) {
          const toolNames = this.localToolManager.getAvailableTools().map(t => t.name);
          Logger.info('HybridChatService', `工具列表: ${toolNames.join(', ')}`);
        } else {
          Logger.warn('HybridChatService', 'LocalToolManager 没有可用工具');
        }
      } else {
        Logger.warn('HybridChatService', 'App context not available, tools disabled');
      }
    } catch (error) {
      Logger.error('HybridChatService', 'Failed to initialize LocalToolManager', error);
    }
  }

  static getInstance(): HybridChatService {
    if (!HybridChatService.instance) {
      HybridChatService.instance = new HybridChatService();
    }
    return HybridChatService.instance;
  }

  /**
   * 发送混合聊天请求
   */
  async sendHybridChatRequest(request: HybridChatRequest): Promise<HybridChatResponse> {
    Logger.info('HybridChatService', `=== 开始混合聊天请求 ===`);
    Logger.info('HybridChatService', `原始消息: "${request.message}"`);
    Logger.info('HybridChatService', `模型: ${request.model}`);
    Logger.info('HybridChatService', `搜索开关: ${request.enableSearch}`);
    Logger.info('HybridChatService', `工具开关: ${request.enableTools || false}`);
    Logger.info('HybridChatService', `提供商: ${request.provider || 'auto'}`);

    const startTime = Date.now();
    let searchTime: number | undefined = undefined;
    let toolTime: number | undefined = undefined;
    let searchUsed = false;
    let toolsUsed = false;
    let toolCalls: ToolCall[] | undefined = undefined;
    let toolResults: ToolCallResult[] | undefined = undefined;
    let searchInfo: SearchInfo | undefined = undefined;
    let searchDecision: SearchDecision | undefined = undefined;
    let finalMessage = request.message;

    try {
      // 第一步：搜索决策
      searchDecision = this.searchDecisionEngine.shouldSearch(request.message, request.enableSearch);
      
      if (searchDecision.shouldSearch) {
        Logger.info('HybridChatService', '=== 执行搜索步骤 ===');
        const searchStartTime = Date.now();
        
        // 第二步：执行搜索
        const searchQuery = this.searchDecisionEngine.generateSearchQuery(request.message, searchDecision);
        const searchResponse: SearchResponse = await this.searchAPIClient.search(searchQuery);
        
        searchTime = Date.now() - searchStartTime;
        searchUsed = searchResponse.success;
        
        if (searchResponse.success) {
          Logger.info('HybridChatService', '搜索成功，开始消息增强');
          
          // 第三步：消息增强
          const enhancedMessage: EnhancedMessage = this.messageEnhancer.enhanceMessage(
            request.message,
            searchResponse,
            searchDecision
          );
          
          finalMessage = enhancedMessage.enhancedMessage;
          searchInfo = enhancedMessage.searchInfo;
          
          Logger.info('HybridChatService', `消息增强完成，增强后消息长度: ${finalMessage.length}`);
        } else {
          Logger.warn('HybridChatService', `搜索失败: ${searchResponse.error}`);
          
          // 搜索失败时创建失败消息
          const failureMessage = this.messageEnhancer.createFailureMessage(
            request.message,
            searchResponse.error || '未知错误'
          );
          
          finalMessage = failureMessage.enhancedMessage;
        }
      } else {
        Logger.info('HybridChatService', `搜索决策结果: ${searchDecision.reason}`);
        Logger.info('HybridChatService', '不执行搜索，直接发送原始消息');
      }

      // 第四步：构建ChatRequest（支持Function Calling）
      let chatRequest: ChatRequest;

      // 构建消息数组，包含系统提示词（如果存在）
      const buildMessages = (userMessageText: string, systemPrompt?: string): ChatMessage[] => {
        const messages: ChatMessage[] = [];

        // 如果有系统提示词，添加为第一条消息
        if (systemPrompt && systemPrompt.trim()) {
          const systemMessage: ChatMessage = {
            role: 'system',
            content: systemPrompt.trim()
          };
          messages.push(systemMessage);
          Logger.info('HybridChatService', `添加系统提示词: ${systemPrompt.substring(0, 50)}...`);
        }

        // 添加用户消息
        const userMessage: ChatMessage = {
          role: 'user',
          content: userMessageText
        };
        messages.push(userMessage);

        return messages;
      };

      Logger.info('HybridChatService', `=== 工具启用检查 ===`);
      Logger.info('HybridChatService', `request.enableTools: ${request.enableTools}`);
      Logger.info('HybridChatService', `this.localToolManager: ${this.localToolManager ? '已初始化' : '未初始化'}`);

      if (request.enableTools && this.localToolManager) {
        Logger.info('HybridChatService', `=== 开始获取工具 ===`);

        // 使用Function Calling
        const tools = this.getAvailableTools();

        Logger.info('HybridChatService', `获取到的工具数量: ${tools.length}`);
        Logger.info('HybridChatService', `工具详情: ${JSON.stringify(tools, null, 2)}`);

        const messages = buildMessages(finalMessage, request.systemPrompt);

        const fcRequest: FunctionCallingChatRequest = {
          model: request.model,
          messages: messages,
          tools: tools,
          tool_choice: 'auto',
          enable_web: request.enableSearch
        };

        chatRequest = {
          messages: fcRequest.messages,
          model: fcRequest.model,
          stream: request.stream || false,
          max_tokens: request.max_tokens,
          temperature: request.temperature,
          tools: tools, // 添加工具定义
          tool_choice: 'auto' // 设置工具选择策略
        };

        Logger.info('HybridChatService', `=== 已添加 ${tools.length} 个工具到请求中 ===`);
      } else {
        // 普通聊天请求
        const messages = buildMessages(finalMessage, request.systemPrompt);

        chatRequest = {
          messages: messages,
          model: request.model,
          stream: request.stream || false,
          max_tokens: request.max_tokens,
          temperature: request.temperature
        };
      }

      // 第五步：发送AI请求并处理工具调用
      Logger.info('HybridChatService', '=== 执行AI请求 ===');
      Logger.info('HybridChatService', `最终消息长度: ${finalMessage.length}字符`);
      Logger.info('HybridChatService', `是否使用搜索: ${searchUsed}`);
      Logger.info('HybridChatService', `是否启用工具: ${request.enableTools || false}`);

      const aiStartTime = Date.now();
      let aiResponse: ChatResponse = await this.sendAIRequest(chatRequest, request.provider);

      // 检查是否有工具调用
      const firstChoice = aiResponse.choices?.[0];
      const assistantMessage = firstChoice?.message;

      // 安全检查工具调用
      let hasToolCalls = false;
      let toolCallsData: ToolCall[] = [];

      if (request.enableTools && assistantMessage) {
        try {
          // 检查消息是否包含tool_calls属性
          const messageStr = JSON.stringify(assistantMessage);
          const messageObj: ToolCallMessage = JSON.parse(messageStr) as ToolCallMessage;
          if (messageObj && messageObj.tool_calls) {
            hasToolCalls = true;
            toolCallsData = messageObj.tool_calls;
          }
        } catch (e) {
          Logger.warn('HybridChatService', '检查工具调用时出错', e);
        }
      }

      if (hasToolCalls && toolCallsData.length > 0) {
        Logger.info('HybridChatService', '=== 检测到工具调用 ===');
        const toolStartTime = Date.now();

        const toolResult: ToolCallHandleResult = await this.handleToolCalls(
          aiResponse,
          chatRequest,
          request.provider,
          toolCallsData
        );

        aiResponse = toolResult.finalResponse;
        toolCalls = toolResult.executedToolCalls;
        toolResults = toolResult.executedToolResults;
        toolsUsed = toolResult.executedToolCalls.length > 0;
        toolTime = Date.now() - toolStartTime;

        Logger.info('HybridChatService', `工具调用完成，执行了 ${toolResult.executedToolCalls.length} 个工具，耗时: ${toolTime}ms`);
      }

      const aiTime = Date.now() - aiStartTime;
      Logger.info('HybridChatService', `AI请求完成，耗时: ${aiTime}ms`);

      const totalTime = Date.now() - startTime;
      
      // 第六步：构建响应
      const hybridResponse: HybridChatResponse = {
        response: aiResponse,
        searchUsed,
        toolsUsed,
        toolCalls,
        toolResults,
        searchInfo,
        searchDecision,
        searchTime,
        toolTime,
        totalTime
      };

      Logger.info('HybridChatService', `=== 混合聊天请求完成 ===`);
      Logger.info('HybridChatService', `总耗时: ${totalTime}ms (搜索: ${searchTime || 0}ms, 工具: ${toolTime || 0}ms, AI: ${aiTime}ms)`);
      Logger.info('HybridChatService', `搜索使用状态: ${searchUsed}`);
      Logger.info('HybridChatService', `工具使用状态: ${toolsUsed}`);
      Logger.info('HybridChatService', `执行的工具数量: ${toolCalls?.length || 0}`);
      Logger.info('HybridChatService', `AI响应ID: ${aiResponse.id}`);
      Logger.info('HybridChatService', `AI响应内容长度: ${aiResponse.choices?.[0]?.message?.content?.length || 0}字符`);

      return hybridResponse;

    } catch (error) {
      const totalTime = Date.now() - startTime;
      Logger.error('HybridChatService', `=== 混合聊天请求异常 ===`);
      Logger.error('HybridChatService', `总耗时: ${totalTime}ms`);
      Logger.error('HybridChatService', `错误信息: ${(error as Error).message}`);
      Logger.error('HybridChatService', `错误堆栈: ${(error as Error).stack}`);
      
      throw new Error(`混合聊天失败: ${(error as Error).message}`);
    }
  }

  /**
   * 发送AI请求
   */
  private async sendAIRequest(request: ChatRequest, provider?: AIProvider): Promise<ChatResponse> {
    Logger.info('HybridChatService', `发送AI请求，目标提供商: ${provider || 'auto'}`);
    
    try {
      // 确保DirectAPIService的API密钥已初始化
      await this.directAPIService.getModelProviderMap();
      
      let targetProvider: AIProvider | undefined = provider;
      
      // 如果没有指定提供商，通过模型自动确定
      if (!targetProvider) {
        if (!request.model) {
          throw new Error('聊天请求中未指定模型');
        }
        const providerResult = await this.directAPIService.getProviderByModel(request.model);
        if (providerResult) {
          targetProvider = providerResult;
          Logger.info('HybridChatService', `通过模型自动确定提供商: ${targetProvider.toString()}`);
        } else {
          throw new Error(`无法确定模型 ${request.model} 的提供商`);
        }
      }

      // 确保targetProvider不为undefined
      if (!targetProvider) {
        throw new Error('未找到有效的AI服务提供商');
      }

      // 验证模型与提供商的匹配性
      if (targetProvider && request.model) {
        const isValid = await this.directAPIService.validateModelProviderMatch(request.model, targetProvider);
        if (!isValid) {
          Logger.warn('HybridChatService', `模型 ${request.model} 与提供商 ${targetProvider.toString()} 不匹配`);
        }
      }

      // 确保targetProvider不为undefined（双重检查）
      if (!targetProvider) {
        throw new Error('未找到有效的AI服务提供商');
      }

      return await this.directAPIService.sendChatRequest(request, targetProvider);
      
    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('HybridChatService', `AI请求失败: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }

  /**
   * 测试混合聊天服务
   */
  async testHybridService(): Promise<HybridServiceTestResult> {
    Logger.info('HybridChatService', '=== 测试混合聊天服务 ===');
    
    let directAI = false;
    let searchService = false;
    const searchProviders: string[] = [];
    let passedTests = 0;
    const totalTests = 3;

    // 测试1：直连AI服务
    try {
      Logger.info('HybridChatService', '测试直连AI服务');
      const testRequest: ChatRequest = {
        messages: [
          {
            role: 'user',
            content: '你好，这是一个测试消息'
          }
        ],
        model: 'Qwen/Qwen2.5-7B-Instruct',
        stream: false
      };
      
      const aiResponse = await this.directAPIService.sendChatRequest(
        testRequest,
        AIProvider.SILICONFLOW
      );
      
      if (aiResponse.choices?.length > 0 && aiResponse.choices[0].message.content) {
        directAI = true;
        passedTests++;
        Logger.info('HybridChatService', '✅ 直连AI服务测试通过');
      } else {
        Logger.error('HybridChatService', '❌ 直连AI服务响应为空');
      }
    } catch (error) {
      Logger.error('HybridChatService', `❌ 直连AI服务测试失败: ${error}`);
    }

    // 测试2：搜索服务
    try {
      Logger.info('HybridChatService', '测试搜索服务');
      const searchResponse = await this.searchAPIClient.search('test');
      
      if (searchResponse.success) {
        searchService = true;
        passedTests++;
        Logger.info('HybridChatService', '✅ 搜索服务测试通过');
      } else {
        Logger.error('HybridChatService', `❌ 搜索服务失败: ${searchResponse.error}`);
      }
    } catch (error) {
      Logger.error('HybridChatService', `❌ 搜索服务测试异常: ${error}`);
    }

    // 测试3：获取搜索提供商列表
    try {
      Logger.info('HybridChatService', '测试搜索提供商列表');
      const providers = await this.searchAPIClient.getAvailableProviders();
      
      if (providers.length > 0) {
        searchProviders.push(...providers);
        passedTests++;
        Logger.info('HybridChatService', `✅ 搜索提供商列表测试通过，可用提供商: ${providers.join(', ')}`);
      } else {
        Logger.error('HybridChatService', '❌ 搜索提供商列表为空');
      }
    } catch (error) {
      Logger.error('HybridChatService', `❌ 搜索提供商列表测试异常: ${error}`);
    }

    Logger.info('HybridChatService', `=== 测试完成 ===`);
    Logger.info('HybridChatService', `总测试数: ${totalTests}, 通过: ${passedTests}`);

    const result: HybridServiceTestResult = {
      directAI,
      searchService,
      searchProviders,
      totalTests,
      passedTests
    };
    return result;
  }

  /**
   * 预处理混合聊天请求
   */
  async preprocessRequest(message: string, model: string, enableSearch: boolean): Promise<PreprocessRequestResult> {
    Logger.info('HybridChatService', '预处理混合聊天请求');
    
    // 搜索决策
    const searchDecision = this.searchDecisionEngine.shouldSearch(message, enableSearch);
    let searchUsed = false;
    let searchInfo: SearchInfo | undefined = undefined;
    let finalMessage = message;

    if (searchDecision.shouldSearch) {
      try {
        // 执行搜索
        const searchQuery = this.searchDecisionEngine.generateSearchQuery(message, searchDecision);
        const searchResponse = await this.searchAPIClient.search(searchQuery);
        
        searchUsed = searchResponse.success;
        
        if (searchResponse.success) {
          // 消息增强
          const enhancedMessage = this.messageEnhancer.enhanceMessage(
            message,
            searchResponse,
            searchDecision
          );
          
          finalMessage = enhancedMessage.enhancedMessage;
          searchInfo = enhancedMessage.searchInfo;
        }
      } catch (error) {
        Logger.error('HybridChatService', `预处理搜索失败: ${error}`);
      }
    }

    const result: PreprocessRequestResult = {
      finalMessage,
      searchUsed,
      searchInfo,
      searchDecision
    };
    return result;
  }

  /**
   * 获取可用工具列表
   */
  private getAvailableTools(): Tool[] {
    Logger.info('HybridChatService', `=== getAvailableTools 开始 ===`);

    if (!this.localToolManager) {
      Logger.error('HybridChatService', 'localToolManager 未初始化');
      return [];
    }

    Logger.info('HybridChatService', 'localToolManager 已初始化，开始获取MCP工具');
    const mcpTools = this.localToolManager.getAvailableTools();
    Logger.info('HybridChatService', `从LocalToolManager获取到 ${mcpTools.length} 个MCP工具`);
    const toolInfo: ToolInfo[] = mcpTools.map(t => new ToolInfo(t.name, t.description || '无描述'));
    Logger.info('HybridChatService', `MCP工具列表: ${JSON.stringify(toolInfo, null, 2)}`);

    const tools: Tool[] = [];

    for (const mcpTool of mcpTools) {
      // 转换属性类型
      const properties: Record<string, ParameterProperty> = {};
      const mcpProperties = mcpTool.inputSchema.properties;
      if (mcpProperties) {
        const propKeys = Object.keys(mcpProperties);
        for (const key of propKeys) {
          const mcpProp = mcpProperties[key];
          if (mcpProp && mcpProp.type) {
            const paramProp: ParameterProperty = {
              type: mcpProp.type
            };
            if (mcpProp.description) {
              paramProp.description = mcpProp.description;
            }
            if (mcpProp.enum) {
              paramProp.enum = mcpProp.enum as string[];
            }
            properties[key] = paramProp;
          }
        }
      }

      const tool: Tool = {
        type: 'function',
        function: {
          name: mcpTool.name,
          description: mcpTool.description || 'MCP工具',
          parameters: {
            type: 'object',
            properties: properties,
            required: mcpTool.inputSchema.required || []
          }
        }
      };
      tools.push(tool);
      Logger.info('HybridChatService', `转换工具: ${mcpTool.name} -> ${tool.function.name}`);
    }

    const toolNames: string[] = [];
    for (const tool of tools) {
      if (tool.function.name) {
        toolNames.push(tool.function.name);
      }
    }
    Logger.info('HybridChatService', `=== getAvailableTools 完成 ===`);
    Logger.info('HybridChatService', `获取到 ${tools.length} 个可用工具: ${toolNames.join(', ')}`);
    Logger.info('HybridChatService', `完整工具定义: ${JSON.stringify(tools, null, 2)}`);
    return tools;
  }

  /**
   * 处理工具调用
   */
  private async handleToolCalls(
    aiResponse: ChatResponse,
    originalRequest: ChatRequest,
    provider?: AIProvider,
    toolCalls?: ToolCall[]
  ): Promise<ToolCallHandleResult> {
    if (!this.localToolManager) {
      throw new Error('LocalToolManager not initialized');
    }

    const firstChoice = aiResponse.choices?.[0];
    const assistantMessage = firstChoice?.message;

    // 使用传入的工具调用数据，或从响应中提取
    let finalToolCalls: ToolCall[] = [];
    if (toolCalls && toolCalls.length > 0) {
      finalToolCalls = toolCalls;
    } else if (assistantMessage) {
      try {
        const messageStr = JSON.stringify(assistantMessage);
        const messageObj: ToolCallMessage = JSON.parse(messageStr) as ToolCallMessage;
        if (messageObj && messageObj.tool_calls) {
          finalToolCalls = messageObj.tool_calls;
        }
      } catch (e) {
        Logger.warn('HybridChatService', '提取工具调用数据时出错', e);
      }
    }

    Logger.info('HybridChatService', `开始处理 ${finalToolCalls.length} 个工具调用`);

    const executedToolCalls: ToolCall[] = [];
    const executedToolResults: ToolCallResult[] = [];
    const toolMessages: FCEnhancedMessage[] = [];

    // 添加原始用户消息和助手的工具调用响应
    const conversationMessages: FCEnhancedMessage[] = [];

    // 复制原始消息
    for (const msg of originalRequest.messages) {
      conversationMessages.push({
        role: msg.role,
        content: msg.content
      });
    }

    // 添加助手的工具调用响应
    conversationMessages.push({
      role: 'assistant',
      content: assistantMessage?.content || '',
      tool_calls: finalToolCalls
    });

    // 执行每个工具调用
    for (const toolCall of finalToolCalls) {
      try {
        Logger.info('HybridChatService', `执行工具: ${toolCall.function.name}`, toolCall.function.arguments);

        // 解析参数
        const args: Record<string, string | number | boolean> = {};
        try {
          const argsStr = toolCall.function.arguments;
          const tempObj: Record<string, string | number | boolean> = JSON.parse(argsStr) as Record<string, string | number | boolean>;

          if (typeof tempObj === 'object' && tempObj !== null) {
            const keys = Object.keys(tempObj);
            for (const key of keys) {
              const value = tempObj[key];
              if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
                args[key] = value;
              }
            }
          }
        } catch (parseError) {
          Logger.error('HybridChatService', `解析工具参数失败: ${toolCall.function.name}`, parseError);
          throw new Error(`工具参数格式错误: ${parseError}`);
        }

        // 构建工具调用请求
        const toolRequest: ToolCallRequest = {
          name: toolCall.function.name,
          arguments: args
        };

        // 执行工具
        const toolResult = await this.localToolManager.executeTool(toolRequest);

        executedToolCalls.push(toolCall);
        executedToolResults.push(toolResult);

        // 添加工具结果消息
        const toolResultContent = this.formatToolResult(toolResult);
        toolMessages.push({
          role: 'tool',
          content: toolResultContent,
          tool_call_id: toolCall.id
        });

        Logger.info('HybridChatService', `工具 ${toolCall.function.name} 执行成功`);

      } catch (error) {
        Logger.error('HybridChatService', `工具 ${toolCall.function.name} 执行失败`, error);

        // 创建错误结果
        const errorResult: ToolCallResult = {
          content: [{
            type: 'text',
            text: `工具执行失败: ${error instanceof Error ? error.message : '未知错误'}`
          }],
          isError: true
        };

        executedToolResults.push(errorResult);

        // 添加错误工具结果消息
        toolMessages.push({
          role: 'tool',
          content: `错误: ${error instanceof Error ? error.message : '未知错误'}`,
          tool_call_id: toolCall.id
        });
      }
    }

    // 如果有工具结果，需要再次调用AI生成最终响应
    if (toolMessages.length > 0) {
      Logger.info('HybridChatService', '基于工具结果生成最终响应');

      const finalMessages: FCEnhancedMessage[] = [];
      // 添加对话消息
      for (const msg of conversationMessages) {
        finalMessages.push(msg);
      }
      // 添加工具结果消息
      for (const toolMsg of toolMessages) {
        finalMessages.push(toolMsg);
      }

      const finalRequest: ChatRequest = {
        messages: finalMessages,
        model: originalRequest.model,
        stream: originalRequest.stream,
        max_tokens: originalRequest.max_tokens,
        temperature: originalRequest.temperature
      };

      const finalResponse = await this.sendAIRequest(finalRequest, provider);

      const result: ToolCallHandleResult = {
        finalResponse,
        executedToolCalls,
        executedToolResults
      };
      return result;
    }

    // 如果没有工具结果，返回原始响应
    const result: ToolCallHandleResult = {
      finalResponse: aiResponse,
      executedToolCalls,
      executedToolResults
    };
    return result;
  }

  /**
   * 格式化工具结果
   */
  private formatToolResult(result: ToolCallResult): string {
    if (result.isError) {
      const firstContent = result.content[0];
      if (firstContent && firstContent.type === 'text') {
        const textContent = firstContent as TextContent;
        if (textContent.text) {
          return `错误: ${textContent.text}`;
        }
      }
      return '错误: 未知错误';
    }

    const textContents = result.content.filter(c => c.type === 'text');
    if (textContents.length > 0) {
      const textResults: string[] = [];
      for (const content of textContents) {
        const textContent = content as TextContent;
        if (textContent.text) {
          textResults.push(textContent.text);
        }
      }
      return textResults.join('\n');
    }

    return '工具执行完成，但没有返回内容';
  }

  /**
   * 检查是否支持工具调用
   */
  isToolsSupported(): boolean {
    return this.localToolManager !== null;
  }

  /**
   * 获取可用工具数量
   */
  getAvailableToolsCount(): number {
    if (!this.localToolManager) {
      return 0;
    }
    return this.localToolManager.getAvailableTools().length;
  }

  /**
   * 获取服务状态
   */
  getServiceStatus(): ServiceStatus {
    const status: ServiceStatus = {
      initialized: true,
      directAPIService: this.directAPIService.getSupportedProviders(),
      searchAPIClient: this.searchAPIClient.getConfig(),
      decisionEngine: this.searchDecisionEngine !== null,
      messageEnhancer: this.messageEnhancer !== null
    };
    return status;
  }
}