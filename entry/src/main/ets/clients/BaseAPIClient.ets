/**
 * API客户端抽象基类
 *
 * 提供通用的HTTP请求处理和统一错误管理的抽象基类。
 * 所有具体的API客户端（如SiliconFlowClient、GeminiClient等）都应继承此类。
 *
 * 主要功能：
 * - 统一的HTTP请求处理和错误管理
 * - 网络请求优化和连接复用
 * - 模型缓存和性能优化
 * - 标准化的响应解析和错误处理
 * - 可重试机制和超时控制
 *
 * @abstract
 */

import { http } from '@kit.NetworkKit';
import {
  ChatRequest, ChatResponse, APIConfig, RequestConfig, ResponseParser,
  ModelCacheConfig, BaseProviderResponse, BaseProviderChoice, BaseProviderUsage,
  StandardProviderResponse, BaseProviderError, TokenUsage, ErrorExtractResult, ChatChoice
} from '../types/APITypes';
import { Logger, LogContext } from '../utils/Logger';
import { ErrorManager } from '../utils/ErrorManager';
import { ErrorType, ErrorCode, ErrorLevel, ErrorContext } from '../types/ErrorTypes';
import { NetworkRequestOptimizer, OptimizedRequestConfig } from '../utils/NetworkRequestOptimizer';
import { RequestType } from '../utils/AdaptiveTimeoutManager';

/**
 * API客户端抽象基类
 *
 * 为所有AI模型API客户端提供统一的基础设施和通用功能。
 * 子类需要实现特定的API调用逻辑和厂商特定的处理。
 */
export abstract class BaseAPIClient {
  protected config: APIConfig;
  protected timeout: number = 30000; // 30秒超时
  protected errorManager: ErrorManager;
  protected networkOptimizer: NetworkRequestOptimizer;

  // 模型缓存相关
  protected cachedModels: string[] | null = null;
  protected cacheTimestamp: number = 0;
  protected readonly cacheConfig: ModelCacheConfig = {
    duration: 5 * 60 * 1000, // 5分钟缓存
    enabled: true
  };

  /**
   * 构造函数 - 初始化API客户端
   *
   * @param {APIConfig} config API配置对象，包含基础URL、API密钥等配置信息
   *
   * @example
   * const config: APIConfig = {
   *   baseUrl: 'https://api.example.com',
   *   apiKey: 'your-api-key',
   *   timeout: 30000
   * };
   * const client = new SomeAPIClient(config);
   */
  constructor(config: APIConfig) {
    this.config = config;
    this.errorManager = ErrorManager.getInstance();
    this.networkOptimizer = NetworkRequestOptimizer.getInstance();
  }
  
  /**
   * 发送聊天请求 - 子类必须实现
   *
   * 发送聊天请求到AI模型提供商，获取模型回复。
   * 每个子类需要根据具体厂商的API规范实现此方法。
   *
   * @param {ChatRequest} request 聊天请求对象，包含消息列表、模型参数等
   * @returns {Promise<ChatResponse>} AI模型的回复响应
   * @abstract
   */
  abstract sendChatRequest(request: ChatRequest): Promise<ChatResponse>;

  /**
   * 测试连接 - 子类必须实现
   *
   * 测试与AI模型提供商的连接状态，验证API密钥和网络连接。
   *
   * @returns {Promise<boolean>} 连接测试结果，true表示连接成功
   * @abstract
   */
  abstract testConnection(): Promise<boolean>;

  /**
   * 获取厂商特定的请求头 - 子类必须实现
   *
   * 获取特定厂商API所需的HTTP请求头，包括认证信息、
   * 内容类型等。每个厂商可能有不同的认证方式。
   *
   * @returns {Record<string, string>} 请求头键值对对象
   * @abstract
   */
  protected abstract getHeaders(): Map<string, string>;
  
  /**
   * 格式化请求体 - 子类必须实现
   *
   * 将标准的聊天请求对象格式化为特定厂商API所需的请求体格式。
   * 每个厂商的API可能有不同的请求格式和参数要求。
   *
   * @param {ChatRequest} request 标准化的聊天请求对象
   * @returns {string} 格式化后的请求体字符串（通常是JSON格式）
   * @abstract
   */
  protected abstract formatRequestBody(request: ChatRequest): string;

  /**
   * 解析响应数据 - 子类必须实现
   *
   * 将厂商API返回的响应数据解析为标准的ChatResponse格式。
   * 处理不同厂商的响应格式差异，统一输出格式。
   *
   * @param {string} responseData 原始响应数据字符串
   * @returns {ChatResponse} 标准化的聊天响应对象
   * @abstract
   */
  protected abstract parseResponse(responseData: string): ChatResponse;

  /**
   * 获取支持的模型列表 - 子类必须实现
   *
   * 获取该AI模型提供商支持的所有模型列表。
   * 可能涉及API调用或本地缓存的处理。
   *
   * @returns {Promise<string[]>} 支持的模型ID数组
   * @abstract
   */
  abstract getSupportedModels(): Promise<string[]>;

  /**
   * 获取厂商名称 - 子类必须实现
   *
   * 获取AI模型提供商的名称，用于日志、错误处理和用户界面显示。
   *
   * @returns {string} 厂商名称（如：'SiliconFlow', 'Google Gemini', '智谱GLM'）
   * @abstract
   */
  abstract getProviderName(): string;

  /**
   * 通用HTTP请求方法 - 使用优化的网络请求系统
   *
   * 发送HTTP请求到指定的URL，使用网络优化系统提供连接复用、
   * 自适应超时、请求去重等性能优化功能。
   *
   * @param {RequestConfig} requestConfig HTTP请求配置对象
   * @returns {Promise<string>} 响应数据字符串
   * @throws {Error} 当网络请求失败或服务器返回错误状态码时抛出异常
   * @protected
   */
  protected async sendHttpRequest(requestConfig: RequestConfig): Promise<string> {
    const context = new LogContext();
    context.module = 'BaseAPIClient';
    context.functionName = 'sendHttpRequest';
    context.additionalInfo = `URL:${requestConfig.url},Method:${requestConfig.method}`;

    const perfId = Logger.startPerformanceMonitoring('BaseAPIClient', 'sendHttpRequest', requestConfig.url);

    try {
      // 设置请求头
      const headers: Record<string, string> = {};
      requestConfig.headers.forEach((value: string, key: string) => {
        headers[key] = value;
      });

      // 确定请求类型
      const requestType = this.determineRequestType(requestConfig.url, requestConfig.method);

      // 创建优化的请求配置
      const optimizedConfig: OptimizedRequestConfig = {
        url: requestConfig.url,
        method: requestConfig.method,
        headers: headers,
        body: requestConfig.body,
        requestType: requestType,
        enableDeduplication: true,
        enableAdaptiveTimeout: true,
        customTimeout: requestConfig.timeout,
        retryAttempts: 2,
        retryDelay: 1000
      };

      Logger.info('BaseAPIClient', `发送优化HTTP请求到: ${requestConfig.url}`, undefined, context);
      Logger.debug('BaseAPIClient', `请求详情: ${JSON.stringify({
        method: requestConfig.method,
        headers: headers,
        requestType: requestType,
        timeout: requestConfig.timeout || 'adaptive',
        bodyLength: requestConfig.body?.length || 0
      })}`, undefined, context);

      // 使用网络优化器发送请求
      const response = await this.networkOptimizer.sendOptimizedRequest(optimizedConfig);

      Logger.info('BaseAPIClient', `收到优化HTTP响应 - 状态码: ${response.statusCode}`, undefined, context);
      Logger.debug('BaseAPIClient', `优化统计: ${JSON.stringify(response.optimizationStats)}`, undefined, context);

      if (response.statusCode === 200) {
        Logger.endPerformanceMonitoring(perfId, `success:true,length:${response.body.length},optimized:true`);
        Logger.debug('BaseAPIClient', `请求成功，响应长度: ${response.body.length}, 连接复用: ${response.connectionReused}`, undefined, context);
        return response.body;
      } else {
        // 使用错误管理器处理HTTP错误
        const errorMsg = `HTTP请求失败: ${response.statusCode}`;
        const errorContext = new ErrorContext();
        errorContext.module = 'BaseAPIClient';
        errorContext.function = 'sendHttpRequest';
        errorContext.additionalInfo = JSON.stringify({
          url: requestConfig.url,
          method: requestConfig.method,
          statusCode: response.statusCode.toString(),
          response: response.body,
          optimizationStats: response.optimizationStats
        });

        const appError = this.errorManager.createError(
          ErrorType.API,
          this.mapStatusCodeToErrorCode(response.statusCode),
          errorMsg,
          errorContext,
          ErrorLevel.ERROR,
          new Error(errorMsg)
        );

        Logger.endPerformanceMonitoring(perfId, `success:false,statusCode:${response.statusCode}`);
        await this.errorManager.handleError(appError);
        throw new Error(errorMsg);
      }

    } catch (error) {
      Logger.endPerformanceMonitoring(perfId, `success:false,error:${(error as Error).message}`);

      // 如果是网络相关错误，使用错误管理器处理
      if (error instanceof Error) {
        const errorContext = new ErrorContext();
        errorContext.module = 'BaseAPIClient';
        errorContext.function = 'sendHttpRequest';
        errorContext.additionalInfo = JSON.stringify({
          url: requestConfig.url,
          method: requestConfig.method,
          errorType: 'OptimizedNetworkError'
        });

        await this.errorManager.handleNetworkError(error, errorContext);
      }

      throw new Error((error as Error).message);
    }
  }

  /**
   * 确定请求类型用于优化策略选择
   */
  protected determineRequestType(url: string, method: string): RequestType {
    const urlLower = url.toLowerCase();

    // 聊天完成接口
    if (urlLower.includes('/chat/completions') || urlLower.includes('/v1/chat')) {
      return RequestType.CHAT;
    }

    // 模型列表接口
    if (urlLower.includes('/models') || urlLower.includes('/model')) {
      return RequestType.MODEL_LIST;
    }

    // 代码执行接口
    if (urlLower.includes('/execute') || urlLower.includes('/run')) {
      return RequestType.CODE_EXECUTION;
    }

    // 搜索接口
    if (urlLower.includes('/search')) {
      return RequestType.SEARCH;
    }

    // 文件操作接口
    if (urlLower.includes('/file') || urlLower.includes('/upload') || urlLower.includes('/download')) {
      return RequestType.FILE_OPERATION;
    }

    // WebSocket相关
    if (urlLower.includes('/ws') || urlLower.includes('/websocket')) {
      return RequestType.WEBSOCKET;
    }

    // 连接测试请求
    if (method === 'GET' || method === 'HEAD') {
      return RequestType.CONNECTION_TEST;
    }

    // 默认其他类型
    return RequestType.OTHER;
  }

  /**
   * 发送GET请求用于连接测试 - 使用优化的网络请求系统
   */
  protected async sendTestRequest(testUrl: string): Promise<boolean> {
    const context = new LogContext();
    context.module = 'BaseAPIClient';
    context.functionName = 'sendTestRequest';
    context.additionalInfo = `TestURL:${testUrl}`;

    const perfId = Logger.startPerformanceMonitoring('BaseAPIClient', 'sendTestRequest', testUrl);

    try {
      // 设置请求头
      const headers: Record<string, string> = {};
      this.getHeaders().forEach((value: string, key: string) => {
        headers[key] = value;
      });

      // 创建优化的连接测试请求配置
      const optimizedConfig: OptimizedRequestConfig = {
        url: testUrl,
        method: 'GET',
        headers: headers,
        requestType: RequestType.CONNECTION_TEST,
        enableDeduplication: false, // 连接测试不需要去重
        enableAdaptiveTimeout: true,
        customTimeout: 10000, // 连接测试使用较短超时
        retryAttempts: 1,
        retryDelay: 500
      };

      Logger.info('BaseAPIClient', `优化连接测试到: ${testUrl}`, undefined, context);

      // 使用网络优化器发送测试请求
      const response = await this.networkOptimizer.sendOptimizedRequest(optimizedConfig);

      const success = response.statusCode === 200 || response.statusCode === 404; // 404也算连接成功
      Logger.info('BaseAPIClient', `连接测试结果: ${success}, 状态码: ${response.statusCode}`, undefined, context);
      Logger.debug('BaseAPIClient', `测试优化统计: ${JSON.stringify(response.optimizationStats)}`, undefined, context);
      Logger.endPerformanceMonitoring(perfId, `success:${success},statusCode:${response.statusCode},optimized:true`);

      return success;

    } catch (error) {
      Logger.endPerformanceMonitoring(perfId, `success:false,error:${(error as Error).message}`);

      // 连接测试失败不抛出异常，只返回false
      const errorContext = new ErrorContext();
      errorContext.module = 'BaseAPIClient';
      errorContext.function = 'sendTestRequest';
      errorContext.additionalInfo = JSON.stringify({
        testUrl: testUrl,
        errorType: 'OptimizedConnectionTest'
      });

      if (error instanceof Error) {
        await this.errorManager.handleNetworkError(error, errorContext);
      }

      return false;
    }
  }
  
  /**
   * 验证请求参数 - 应用统一错误处理
   */
  protected validateRequest(request: ChatRequest): void {
    const context = new LogContext();
    context.module = 'BaseAPIClient';
    context.functionName = 'validateRequest';
    
    if (!request.messages || request.messages.length === 0) {
      const errorContext = new ErrorContext();
      errorContext.module = 'BaseAPIClient';
      errorContext.function = 'validateRequest';
      errorContext.additionalInfo = JSON.stringify({
        validationType: 'EmptyMessages'
      });
      
      const appError = this.errorManager.createError(
        ErrorType.VALIDATION,
        ErrorCode.VALIDATION_REQUIRED_FIELD,
        '消息列表不能为空',
        errorContext,
        ErrorLevel.WARNING
      );
      
      Logger.warn('BaseAPIClient', '验证失败：消息列表为空', undefined, context);
      throw new Error('消息列表不能为空');
    }
    
    for (let i = 0; i < request.messages.length; i++) {
      const message = request.messages[i];
      if (!message.role || !message.content) {
        const errorContext = new ErrorContext();
        errorContext.module = 'BaseAPIClient';
        errorContext.function = 'validateRequest';
        errorContext.additionalInfo = JSON.stringify({
          validationType: 'InvalidMessageFormat',
          messageIndex: i.toString()
        });
        
        const appError = this.errorManager.createError(
          ErrorType.VALIDATION,
          ErrorCode.VALIDATION_INVALID_FORMAT,
          `第${i + 1}条消息格式不正确：role和content字段必填`,
          errorContext,
          ErrorLevel.WARNING
        );
        
        Logger.warn('BaseAPIClient', `验证失败：消息${i + 1}格式不正确`, undefined, context);
        throw new Error(`第${i + 1}条消息格式不正确：role和content字段必填`);
      }
    }
    
    Logger.debug('BaseAPIClient', `请求验证通过，消息数量: ${request.messages.length}`, undefined, context);
  }
  
  /**
   * 映射HTTP状态码到错误代码
   */
  protected mapStatusCodeToErrorCode(statusCode: number): ErrorCode {
    switch (statusCode) {
      case 400:
        return ErrorCode.API_INVALID_REQUEST;
      case 401:
        return ErrorCode.API_UNAUTHORIZED;
      case 403:
        return ErrorCode.API_UNAUTHORIZED;
      case 404:
        return ErrorCode.API_MODEL_NOT_FOUND;
      case 429:
        return ErrorCode.API_RATE_LIMITED;
      case 500:
      case 502:
      case 503:
        return ErrorCode.API_SERVER_ERROR;
      case 504:
        return ErrorCode.NETWORK_TIMEOUT;
      default:
        return ErrorCode.API_SERVER_ERROR;
    }
  }
  
  /**
   * 处理API错误 - 已被统一错误管理器替代
   * @deprecated 使用 ErrorManager.handleAPIError 替代
   */
  protected handleAPIError(error: Error, context: string): Error {
    Logger.warn('BaseAPIClient', `使用了已弃用的handleAPIError方法: ${context}`);
    return new Error(`${context}失败: ${error.message}`);
  }
  
  /**
   * 获取配置信息
   */
  getConfig(): APIConfig {
    return {
      provider: this.config.provider,
      model: this.config.model,
      apiKey: this.config.apiKey,
      baseUrl: this.config.baseUrl
    };
  }
  
  /**
   * 更新配置
   */
  updateConfig(updates: Partial<APIConfig>): void {
    if (updates.provider !== undefined) this.config.provider = updates.provider;
    if (updates.model !== undefined) this.config.model = updates.model;
    if (updates.apiKey !== undefined) this.config.apiKey = updates.apiKey;
    if (updates.baseUrl !== undefined) this.config.baseUrl = updates.baseUrl;
  }
  
  /**
   * 泛型响应解析方法
   */
  protected parseResponseGeneric<T extends StandardProviderResponse>(
    responseData: string, 
    parser: ResponseParser<T>
  ): ChatResponse {
    const context = new LogContext();
    context.module = 'BaseAPIClient';
    context.functionName = 'parseResponseGeneric';
    context.additionalInfo = `provider:${parser.getProviderName()}`;
    
    try {
      Logger.info('BaseAPIClient', `=== 开始解析${parser.getProviderName()}响应 ===`, undefined, context);
      Logger.debug('BaseAPIClient', `原始响应数据: ${responseData}`, undefined, context);
      
      const jsonResponse = JSON.parse(responseData) as T;
      
      Logger.info('BaseAPIClient', `JSON解析成功`, undefined, context);
      Logger.info('BaseAPIClient', `响应ID: ${jsonResponse.id}`, undefined, context);
      Logger.info('BaseAPIClient', `使用模型: ${jsonResponse.model}`, undefined, context);
      
      // 可选的响应验证
      if (parser.validateResponse && !parser.validateResponse(jsonResponse)) {
        throw new Error('响应验证失败');
      }
      
      // 错误检查
      if (jsonResponse.error) {
        const errorInfo: ErrorExtractResult | null = parser.extractError ? parser.extractError(jsonResponse) : {
          message: jsonResponse.error.message,
          code: jsonResponse.error.code || 'UNKNOWN_ERROR'
        } as ErrorExtractResult;
        
        if (errorInfo) {
          const errorContext = new ErrorContext();
          errorContext.module = 'BaseAPIClient';
          errorContext.function = 'parseResponseGeneric';
          errorContext.additionalInfo = JSON.stringify({
            provider: parser.getProviderName(),
            errorType: 'APIError',
            apiError: jsonResponse.error
          });
          
          const appError = this.errorManager.createError(
            ErrorType.API,
            ErrorCode.API_SERVER_ERROR,
            `${parser.getProviderName()} API错误: ${errorInfo.message}`,
            errorContext,
            ErrorLevel.ERROR
          );
          
          this.errorManager.handleError(appError);
          throw new Error(`${parser.getProviderName()} API错误: ${errorInfo.message}`);
        }
      }
      
      // 转换为标准格式
      const choices: ChatChoice[] = jsonResponse.choices.map(choice => ({
        index: choice.index,
        message: choice.message,
        finish_reason: choice.finish_reason
      } as ChatChoice));
      
      const usage: TokenUsage = {
        prompt_tokens: jsonResponse.usage.prompt_tokens,
        completion_tokens: jsonResponse.usage.completion_tokens,
        total_tokens: jsonResponse.usage.total_tokens
      };
      
      Logger.info('BaseAPIClient', `令牌使用情况 - 输入: ${usage.prompt_tokens}, 输出: ${usage.completion_tokens}, 总计: ${usage.total_tokens}`, undefined, context);
      
      const parsedResponse: ChatResponse = {
        id: jsonResponse.id,
        object: jsonResponse.object,
        created: jsonResponse.created,
        model: jsonResponse.model,
        choices: choices,
        usage: usage
      };
      
      Logger.info('BaseAPIClient', `=== ${parser.getProviderName()}响应解析完成 ===`, undefined, context);
      return parsedResponse;
      
    } catch (error) {
      const errorContext = new ErrorContext();
      errorContext.module = 'BaseAPIClient';
      errorContext.function = 'parseResponseGeneric';
      errorContext.additionalInfo = JSON.stringify({
        provider: parser.getProviderName(),
        errorType: 'ResponseParsing',
        responseLength: responseData.length
      });
      
      if (error instanceof Error) {
        this.errorManager.handleError(
          this.errorManager.createError(
            ErrorType.API,
            ErrorCode.API_SERVER_ERROR,
            `解析${parser.getProviderName()}响应失败: ${error.message}`,
            errorContext,
            ErrorLevel.ERROR,
            error
          )
        );
      }
      
      throw new Error(`解析${parser.getProviderName()}响应失败: ${(error as Error).message}`);
    }
  }
  
  /**
   * 统一的模型缓存获取方法
   */
  protected async getSupportedModelsWithCache<T extends StandardProviderResponse>(parser: ResponseParser<T>): Promise<string[]> {
    const context = new LogContext();
    context.module = 'BaseAPIClient';
    context.functionName = 'getSupportedModelsWithCache';
    context.additionalInfo = `provider:${parser.getProviderName()}`;
    
    try {
      // 检查缓存是否有效
      const now = Date.now();
      if (this.cacheConfig.enabled && 
          this.cachedModels && 
          (now - this.cacheTimestamp) < this.cacheConfig.duration &&
          !this.cacheConfig.forceRefresh) {
        Logger.info('BaseAPIClient', `使用缓存的${parser.getProviderName()}模型列表`, undefined, context);
        return this.cachedModels;
      }

      // 尝试从网络获取
      Logger.info('BaseAPIClient', `尝试从网络获取${parser.getProviderName()}模型列表`, undefined, context);
      return await this.fetchModelsFromNetwork(parser);
      
    } catch (error) {
      Logger.warn('BaseAPIClient', `网络获取${parser.getProviderName()}模型失败，使用本地备用模型: ${(error as Error).message}`, undefined, context);
      return parser.getLocalFallbackModels();
    }
  }
  
  /**
   * 从网络获取模型列表
   */
  private async fetchModelsFromNetwork<T extends StandardProviderResponse>(parser: ResponseParser<T>): Promise<string[]> {
    const context = new LogContext();
    context.module = 'BaseAPIClient';
    context.functionName = 'fetchModelsFromNetwork';
    context.additionalInfo = `provider:${parser.getProviderName()},url:${parser.getModelsEndpoint()}`;
    
    const perfId = Logger.startPerformanceMonitoring('BaseAPIClient', 'fetchModelsFromNetwork', parser.getProviderName());
    
    try {
      Logger.info('BaseAPIClient', `=== 开始从网络获取${parser.getProviderName()}模型列表 ===`, undefined, context);
      
      const requestConfig: RequestConfig = {
        url: `${this.config.baseUrl}${parser.getModelsEndpoint()}`,
        method: 'GET',
        headers: this.getHeaders(),
        timeout: 10000 // 10秒超时
      };
      
      const startTime = Date.now();
      const responseData = await this.sendHttpRequest(requestConfig);
      const endTime = Date.now();
      
      Logger.info('BaseAPIClient', `网络请求完成，耗时: ${endTime - startTime}ms`, undefined, context);
      
      const jsonResponse = JSON.parse(responseData) as Record<string, Object>;
      if (jsonResponse.data && Array.isArray(jsonResponse.data)) {
        const models: string[] = [];
        const dataArray = jsonResponse.data as Array<Object>;
        for (let i = 0; i < dataArray.length; i++) {
          const model = dataArray[i] as Record<string, Object>;
          if (model && model.id && typeof model.id === 'string') {
            models.push(model.id);
          }
        }
        
        Logger.info('BaseAPIClient', `=== 网络获取${parser.getProviderName()}模型列表成功 ===`, undefined, context);
        Logger.info('BaseAPIClient', `获取到 ${models.length} 个模型`, undefined, context);
        Logger.debug('BaseAPIClient', `模型列表: ${JSON.stringify(models)}`, undefined, context);
        
        // 缓存结果
        this.cachedModels = models;
        this.cacheTimestamp = Date.now();
        
        Logger.endPerformanceMonitoring(perfId, `success:true,modelCount:${models.length}`);
        return models;
      } else {
        throw new Error('响应格式不正确，缺少data字段或data不是数组');
      }
      
    } catch (error) {
      Logger.endPerformanceMonitoring(perfId, `success:false,error:${(error as Error).message}`);
      
      const errorContext = new ErrorContext();
      errorContext.module = 'BaseAPIClient';
      errorContext.function = 'fetchModelsFromNetwork';
      errorContext.additionalInfo = JSON.stringify({
        provider: parser.getProviderName(),
        errorType: 'ModelsFetch'
      });
      
      if (error instanceof Error) {
        await this.errorManager.handleAPIError(error, errorContext);
      }
      
      throw new Error(`网络获取${parser.getProviderName()}模型列表失败: ${(error as Error).message}`);
    }
  }
  
  /**
   * 统一的连接测试方法
   */
  protected async testConnectionGeneric(testUrl?: string): Promise<boolean> {
    const context = new LogContext();
    context.module = 'BaseAPIClient';
    context.functionName = 'testConnectionGeneric';
    context.additionalInfo = `provider:${this.config.provider}`;
    
    const perfId = Logger.startPerformanceMonitoring('BaseAPIClient', 'testConnectionGeneric', this.config.provider);
    
    try {
      // 如果没有提供测试URL，使用/models端点
      const urlToTest = testUrl || `${this.config.baseUrl}/models`;
      context.additionalInfo += `,testUrl:${urlToTest}`;
      
      Logger.info('BaseAPIClient', `=== 开始${this.config.provider}连接测试 ===`, undefined, context);
      Logger.info('BaseAPIClient', `测试URL: ${urlToTest}`, undefined, context);
      
      const result = await this.sendTestRequest(urlToTest);
      
      Logger.endPerformanceMonitoring(perfId, `success:${result}`);
      Logger.info('BaseAPIClient', `=== ${this.config.provider}连接测试完成 ===`, undefined, context);
      Logger.info('BaseAPIClient', `测试结果: ${result ? '成功' : '失败'}`, undefined, context);
      
      return result;
      
    } catch (error) {
      Logger.endPerformanceMonitoring(perfId, `success:false,error:${(error as Error).message}`);
      
      const errorContext = new ErrorContext();
      errorContext.module = 'BaseAPIClient';
      errorContext.function = 'testConnectionGeneric';
      errorContext.additionalInfo = JSON.stringify({
        provider: this.config.provider,
        errorType: 'ConnectionTest'
      });
      
      if (error instanceof Error) {
        await this.errorManager.handleNetworkError(error, errorContext);
      }
      
      return false;
    }
  }
  
  /**
   * 统一的性能监控开始方法
   */
  protected startPerfMonitoring(operation: string, detail: string = ''): string {
    return Logger.startPerformanceMonitoring(this.constructor.name, operation, detail);
  }
  
  /**
   * 统一的性能监控结束方法
   */
  protected endPerfMonitoring(perfId: string, result: string = ''): void {
    Logger.endPerformanceMonitoring(perfId, result);
  }
  
  /**
   * 清除模型缓存
   */
  protected clearModelCache(): void {
    this.cachedModels = null;
    this.cacheTimestamp = 0;
    Logger.info('BaseAPIClient', '模型缓存已清除');
  }
  
  /**
   * 强制刷新模型缓存
   */
  protected forceRefreshCache(): void {
    this.cacheConfig.forceRefresh = true;
    this.clearModelCache();
  }
}