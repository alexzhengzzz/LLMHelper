/**
 * GLM智谱AI客户端
 * 支持GLM-4系列模型
 */

import { BaseAPIClient } from './BaseAPIClient';
import { 
  ChatRequest, ChatResponse, AIProvider, APIConfig, RequestConfig, GLMRequestBody, 
  GLMResponse, ResponseParser, ErrorExtractResult, ChatChoice
} from '../types/APITypes';
import { Logger, LogContext } from '../utils/Logger';
import { ErrorManager } from '../utils/ErrorManager';
import { ErrorType, ErrorCode, ErrorLevel, ErrorContext } from '../types/ErrorTypes';

/**
 * GLM响应解析器
 */
class GLMResponseParser implements ResponseParser<GLMResponse> {
  private static readonly DEFAULT_MODEL = 'glm-4.5';
  private static readonly BASE_URL = 'https://open.bigmodel.cn';
  private static readonly API_ENDPOINT = '/api/paas/v4/chat/completions';
  private static readonly MODELS_ENDPOINT = '/api/paas/v4/models';
  
  parse(responseData: string): ChatResponse {
    Logger.info('GLMResponseParser', `=== GLM响应解析 ===`);
    Logger.info('GLMResponseParser', `原始响应数据: ${responseData}`);

    const jsonResponse = JSON.parse(responseData) as GLMResponse;

    Logger.info('GLMResponseParser', `解析后的响应: ${JSON.stringify(jsonResponse, null, 2)}`);
    Logger.info('GLMResponseParser', `选择数量: ${jsonResponse.choices?.length || 0}`);

    if (jsonResponse.choices && jsonResponse.choices.length > 0) {
      const firstChoice = jsonResponse.choices[0];
      Logger.info('GLMResponseParser', `第一个选择的消息: ${JSON.stringify(firstChoice.message, null, 2)}`);

      if (firstChoice.message.tool_calls) {
        Logger.info('GLMResponseParser', `=== 发现工具调用 ===`);
        Logger.info('GLMResponseParser', `工具调用数量: ${firstChoice.message.tool_calls.length}`);
        Logger.info('GLMResponseParser', `工具调用详情: ${JSON.stringify(firstChoice.message.tool_calls, null, 2)}`);
      } else {
        Logger.info('GLMResponseParser', `=== 无工具调用 ===`);
        Logger.info('GLMResponseParser', `消息内容: ${firstChoice.message.content}`);
      }
    }

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
    return 'GLM智谱AI';
  }
  
  getModelEndpoint(): string {
    return GLMResponseParser.API_ENDPOINT;
  }
  
  getModelsEndpoint(): string {
    return GLMResponseParser.MODELS_ENDPOINT;
  }
  
  getLocalFallbackModels(): string[] {
    return [
      'glm-4.5',
      'glm-4.5-air'
    ];
  }
  
  validateResponse(response: GLMResponse): boolean {
    return !!(response.id && response.model && response.choices && response.choices.length > 0);
  }
  
  extractError(response: GLMResponse): ErrorExtractResult | null {
    if (response.error) {
      return {
        message: response.error.message,
        code: response.error.code || 'GLM_ERROR'
      } as ErrorExtractResult;
    }
    return null;
  }
}

export class GLMClient extends BaseAPIClient {
  private static readonly DEFAULT_MODEL = 'glm-4.5';
  private static readonly BASE_URL = 'https://open.bigmodel.cn';
  private responseParser: GLMResponseParser;
  
  constructor(apiKey: string = '') {
    const config: APIConfig = {
      provider: AIProvider.GLM,
      model: GLMClient.DEFAULT_MODEL,
      apiKey: apiKey, // 保留默认密钥作为fallback
      baseUrl: GLMClient.BASE_URL
    };
    super(config);
    this.responseParser = new GLMResponseParser();
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
      errorContext.module = 'GLMClient';
      errorContext.function = 'sendChatRequest';
      errorContext.additionalInfo = JSON.stringify({
        model: request.model,
        provider: 'glm',
        errorType: 'ChatRequest'
      });
      
      const errorManager = ErrorManager.getInstance();
      if (error instanceof Error) {
        await errorManager.handleAPIError(error, errorContext);
      }
      
      throw new Error(`GLM聊天请求失败: ${(error as Error).message}`);
    }
  }
  
  async testConnection(): Promise<boolean> {
    const perfId = this.startPerfMonitoring('testConnection');
    
    try {
      Logger.info('GLMClient', `=== 开始GLM智谱AI连接测试 ===`);
      Logger.info('GLMClient', `当前API密钥前缀: ${this.config.apiKey?.substring(0, 10)}...`);
      
      // 使用聊天API进行连接测试
      const testRequest: ChatRequest = {
        model: this.config.model,
        messages: [
          {
            role: 'user',
            content: '测试连接'
          }
        ],
        max_tokens: 5,
        temperature: 0.1
      };
      
      try {
        await this.sendChatRequest(testRequest);
        this.endPerfMonitoring(perfId, 'success:true');
        Logger.info('GLMClient', `=== GLM智谱AI连接测试完成 ===`);
        Logger.info('GLMClient', `测试结果: 成功`);
        return true;
      } catch (error) {
        // 检查是否是权限问题（401）还是其他网络问题
        const errorMsg = (error as Error).message;
        const errorContext = new ErrorContext();
        errorContext.module = 'GLMClient';
        errorContext.function = 'testConnection';
        errorContext.additionalInfo = JSON.stringify({
          provider: 'glm',
          errorType: 'ConnectionTest',
          errorMessage: errorMsg
        });
        
        const errorManager = ErrorManager.getInstance();
        
        if (errorMsg.includes('401') || errorMsg.includes('API错误')) {
          errorManager.handleError(
            errorManager.createError(
              ErrorType.API,
              ErrorCode.API_UNAUTHORIZED,
              '连接测试失败：API密钥无效或权限不足',
              errorContext,
              ErrorLevel.WARNING
            )
          );
          this.endPerfMonitoring(perfId, 'success:false,reason:unauthorized');
          return false;
        } else {
          // 其他错误可能是网络问题，但密钥可能是有效的
          if (error instanceof Error) {
            await errorManager.handleNetworkError(error, errorContext);
          }
          this.endPerfMonitoring(perfId, 'success:false,reason:network');
          return false;
        }
      }
      
    } catch (error) {
      this.endPerfMonitoring(perfId, `success:false,error:${(error as Error).message}`);
      
      const errorContext = new ErrorContext();
      errorContext.module = 'GLMClient';
      errorContext.function = 'testConnection';
      errorContext.additionalInfo = JSON.stringify({
        provider: 'glm',
        errorType: 'ConnectionTestException'
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
    const glmRequest: GLMRequestBody = {
      model: request.model || this.config.model,
      messages: request.messages,
      max_tokens: request.max_tokens || 1500,
      temperature: request.temperature || 0.7,
      stream: request.stream || false
    };

    // 添加工具支持
    if (request.tools && request.tools.length > 0) {
      glmRequest.tools = request.tools;
      glmRequest.tool_choice = request.tool_choice || 'auto';
      Logger.info('GLMClient', `=== 工具发送详情 ===`);
      Logger.info('GLMClient', `工具数量: ${request.tools.length}`);
      Logger.info('GLMClient', `工具列表: ${JSON.stringify(request.tools, null, 2)}`);
      Logger.info('GLMClient', `工具选择策略: ${glmRequest.tool_choice}`);
    } else {
      Logger.info('GLMClient', '=== 无工具发送 ===');
      Logger.info('GLMClient', `request.tools: ${request.tools}`);
      Logger.info('GLMClient', `tools length: ${request.tools?.length || 0}`);
    }

    const requestBodyStr = JSON.stringify(glmRequest);
    Logger.info('GLMClient', `=== 完整请求体 ===`);
    Logger.info('GLMClient', `请求体大小: ${requestBodyStr.length} 字符`);
    Logger.info('GLMClient', `请求体内容: ${requestBodyStr}`);

    return requestBodyStr;
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