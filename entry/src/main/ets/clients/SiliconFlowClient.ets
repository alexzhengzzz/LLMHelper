/**
 * 硅基流动API客户端
 * 支持Qwen、DeepSeek等模型
 */

import { BaseAPIClient } from './BaseAPIClient';
import { 
  ChatRequest, ChatResponse, AIProvider, APIConfig, RequestConfig, SiliconFlowRequestBody, 
  SiliconFlowResponse, ResponseParser, TokenUsage, ChatChoice, ErrorExtractResult
} from '../types/APITypes';
import { Logger, LogContext } from '../utils/Logger';
import { ErrorManager } from '../utils/ErrorManager';
import { ErrorType, ErrorCode, ErrorLevel, ErrorContext } from '../types/ErrorTypes';

/**
 * SiliconFlow响应解析器
 */
class SiliconFlowResponseParser implements ResponseParser<SiliconFlowResponse> {
  private static readonly DEFAULT_MODEL = 'Qwen/Qwen2.5-7B-Instruct';
  private static readonly BASE_URL = 'https://api.siliconflow.cn';
  private static readonly API_ENDPOINT = '/v1/chat/completions';
  private static readonly MODELS_ENDPOINT = '/v1/models';
  
  parse(responseData: string): ChatResponse {
    const jsonResponse = JSON.parse(responseData) as SiliconFlowResponse;
    
    return {
      id: jsonResponse.id,
      object: jsonResponse.object,
      created: jsonResponse.created,
      model: jsonResponse.model,
      choices: jsonResponse.choices.map((choice): ChatChoice => ({
        index: choice.index,
        message: choice.message,
        finish_reason: choice.finish_reason
      } as ChatChoice)),
      usage: {
        prompt_tokens: jsonResponse.usage.prompt_tokens,
        completion_tokens: jsonResponse.usage.completion_tokens,
        total_tokens: jsonResponse.usage.total_tokens
      }
    };
  }
  
  getProviderName(): string {
    return '硅基流动';
  }
  
  getModelEndpoint(): string {
    return SiliconFlowResponseParser.API_ENDPOINT;
  }
  
  getModelsEndpoint(): string {
    return SiliconFlowResponseParser.MODELS_ENDPOINT;
  }
  
  getLocalFallbackModels(): string[] {
    return [
      'Qwen/Qwen2.5-7B-Instruct',
      'Qwen/Qwen2.5-14B-Instruct',
      'Qwen/Qwen2.5-32B-Instruct',
      'Qwen/Qwen2.5-72B-Instruct',
      'Qwen/Qwen2.5-Coder-7B-Instruct',
      'deepseek-ai/DeepSeek-V2.5',
      'deepseek-ai/deepseek-llm-7b-chat',
      'deepseek-ai/deepseek-coder-6.7b-instruct',
      'meta-llama/Llama-3.1-8B-Instruct',
      'meta-llama/Llama-3.1-70B-Instruct',
      'meta-llama/Llama-3.1-405B-Instruct',
      'mistralai/Mistral-7B-Instruct-v0.3',
      'google/gemma-2-9b-it',
      'google/gemma-2-27b-it',
      'internlm/internlm2_5-7b-chat',
      'internlm/internlm2_5-20b-chat',
      '01-ai/Yi-1.5-9B-Chat-16K',
      '01-ai/Yi-1.5-34B-Chat-16K',
      'THUDM/glm-4-9b-chat',
      'alibaba/Qwen2-VL-7B-Instruct'
    ];
  }
  
  validateResponse(response: SiliconFlowResponse): boolean {
    return !!(response.id && response.model && response.choices && response.choices.length > 0);
  }
  
  extractError(response: SiliconFlowResponse): ErrorExtractResult | null {
    if (response.error) {
      return {
        message: response.error.message,
        code: response.error.code || 'SILICONFLOW_ERROR'
      } as ErrorExtractResult;
    }
    return null;
  }
}

export class SiliconFlowClient extends BaseAPIClient {
  private static readonly DEFAULT_MODEL = 'Qwen/Qwen2.5-7B-Instruct';
  private static readonly BASE_URL = 'https://api.siliconflow.cn';
  private responseParser: SiliconFlowResponseParser;
  
  constructor(apiKey: string = '') {
    const config: APIConfig = {
      provider: AIProvider.SILICONFLOW,
      model: SiliconFlowClient.DEFAULT_MODEL,
      apiKey: apiKey, // 保留默认密钥作为fallback
      baseUrl: SiliconFlowClient.BASE_URL
    };
    super(config);
    this.responseParser = new SiliconFlowResponseParser();
  }
  
  async sendChatRequest(request: ChatRequest): Promise<ChatResponse> {
    const perfId = this.startPerfMonitoring('sendChatRequest', request.model);
    
    try {
      this.validateRequest(request);
      
      const requestBody = this.formatRequestBody(request);
      const requestConfig: RequestConfig = {
        url: `${this.config.baseUrl}${this.responseParser.getModelEndpoint()}`,
        method: 'POST',
        headers: this.getHeaders(),
        body: requestBody,
        timeout: request.timeout || this.timeout
      };
      
      const responseData = await this.sendHttpRequest(requestConfig);
      const parsedResponse = this.parseResponseGeneric(responseData, this.responseParser);
      
      this.endPerfMonitoring(perfId, `success:true,model:${parsedResponse.model}`);
      return parsedResponse;
      
    } catch (error) {
      this.endPerfMonitoring(perfId, `success:false,error:${(error as Error).message}`);
      
      const errorContext = new ErrorContext();
      errorContext.module = 'SiliconFlowClient';
      errorContext.function = 'sendChatRequest';
      errorContext.additionalInfo = JSON.stringify({
        model: request.model,
        provider: 'siliconflow',
        errorType: 'ChatRequest'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        await errorManager.handleAPIError(error, errorContext);
      }
      
      throw new Error(`硅基流动聊天请求失败: ${(error as Error).message}`);
    }
  }
  
  async testConnection(): Promise<boolean> {
    const perfId = this.startPerfMonitoring('testConnection');
    
    try {
      const testUrl = `${this.config.baseUrl}/v1/models`;
      
      Logger.info('SiliconFlowClient', `=== 开始硅基流动连接测试 ===`);
      Logger.info('SiliconFlowClient', `测试URL: ${testUrl}`);
      Logger.info('SiliconFlowClient', `当前API密钥前缀: ${this.config.apiKey?.substring(0, 10)}...`);
      
      const result = await this.testConnectionGeneric(testUrl);
      
      this.endPerfMonitoring(perfId, `success:${result}`);
      Logger.info('SiliconFlowClient', `=== 硅基流动连接测试完成 ===`);
      Logger.info('SiliconFlowClient', `测试结果: ${result ? '成功' : '失败'}`);
      
      return result;
    } catch (error) {
      this.endPerfMonitoring(perfId, `success:false,error:${(error as Error).message}`);
      
      const errorContext = new ErrorContext();
      errorContext.module = 'SiliconFlowClient';
      errorContext.function = 'testConnection';
      errorContext.additionalInfo = JSON.stringify({
        provider: 'siliconflow',
        errorType: 'ConnectionTest'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        await errorManager.handleNetworkError(error, errorContext);
      }
      
      return false;
    }
  }
  
  protected getHeaders(): Map<string, string> {
    const headers = new Map<string, string>();
    headers.set('Content-Type', 'application/json');
    headers.set('Authorization', `Bearer ${this.config.apiKey}`);
    return headers;
  }
  
  protected formatRequestBody(request: ChatRequest): string {
    const siliconFlowRequest: SiliconFlowRequestBody = {
      model: request.model || this.config.model,
      messages: request.messages,
      max_tokens: request.max_tokens || 1000,
      temperature: request.temperature || 0.7,
      stream: request.stream || false
    };
    
    return JSON.stringify(siliconFlowRequest);
  }
  
  

  /**
   * 获取支持的模型列表（使用基类的缓存机制）
   */
  async getSupportedModels(): Promise<string[]> {
    return this.getSupportedModelsWithCache(this.responseParser);
  }
  
  /**
   * 设置API密钥
   */
  setApiKey(apiKey: string): void {
    this.config.apiKey = apiKey;
  }
  
  /**
   * 获取厂商名称
   */
  getProviderName(): string {
    return this.responseParser.getProviderName();
  }
  
  /**
   * 解析响应数据 - 实现抽象方法
   */
  protected parseResponse(responseData: string): ChatResponse {
    return this.parseResponseGeneric(responseData, this.responseParser);
  }
}