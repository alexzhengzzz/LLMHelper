/**
 * 混合聊天服务
 * 整合搜索功能和直连AI调用
 */

import { ChatRequest, ChatResponse, AIProvider } from '../types/APITypes';
import { DirectAPIService } from './DirectAPIService';
import { SearchAPIClient, SearchResponse, SearchClientConfig } from '../clients/SearchAPIClient';
import { SearchDecisionEngine, SearchDecision } from './SearchDecisionEngine';
import { MessageEnhancer, EnhancedMessage, SearchInfo } from './MessageEnhancer';
import { Logger } from '../utils/Logger';

/**
 * 混合聊天请求参数
 */
export interface HybridChatRequest {
  message: string;
  model: string;
  provider?: AIProvider;
  enableSearch: boolean;
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
  searchInfo?: SearchInfo;
  searchDecision?: SearchDecision;
  searchTime?: number;
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

export class HybridChatService {
  private static instance: HybridChatService;
  private directAPIService: DirectAPIService;
  private searchAPIClient: SearchAPIClient;
  private searchDecisionEngine: SearchDecisionEngine;
  private messageEnhancer: MessageEnhancer;

  private constructor() {
    this.directAPIService = new DirectAPIService();
    this.searchAPIClient = new SearchAPIClient();
    this.searchDecisionEngine = SearchDecisionEngine.getInstance();
    this.messageEnhancer = MessageEnhancer.getInstance();
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
    Logger.info('HybridChatService', `提供商: ${request.provider || 'auto'}`);

    const startTime = Date.now();
    let searchTime: number | undefined = undefined;
    let searchUsed = false;
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

      // 第四步：构建ChatRequest
      const chatRequest: ChatRequest = {
        messages: [
          {
            role: 'user',
            content: finalMessage
          }
        ],
        model: request.model,
        stream: request.stream || false,
        max_tokens: request.max_tokens,
        temperature: request.temperature
      };

      // 第五步：发送AI请求
      Logger.info('HybridChatService', '=== 执行AI请求 ===');
      Logger.info('HybridChatService', `最终消息长度: ${finalMessage.length}字符`);
      Logger.info('HybridChatService', `是否使用搜索: ${searchUsed}`);
      
      const aiStartTime = Date.now();
      const aiResponse: ChatResponse = await this.sendAIRequest(chatRequest, request.provider);
      const aiTime = Date.now() - aiStartTime;
      
      Logger.info('HybridChatService', `AI请求完成，耗时: ${aiTime}ms`);
      
      const totalTime = Date.now() - startTime;
      
      // 第六步：构建响应
      const hybridResponse: HybridChatResponse = {
        response: aiResponse,
        searchUsed,
        searchInfo,
        searchDecision,
        searchTime,
        totalTime
      };

      Logger.info('HybridChatService', `=== 混合聊天请求完成 ===`);
      Logger.info('HybridChatService', `总耗时: ${totalTime}ms (搜索: ${searchTime || 0}ms, AI: ${aiTime}ms)`);
      Logger.info('HybridChatService', `搜索使用状态: ${searchUsed}`);
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