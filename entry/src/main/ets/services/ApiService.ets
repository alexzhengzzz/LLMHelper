import { http } from '@kit.NetworkKit';
import { ChatRequest, ChatResponse, ExecuteRequest, ExecuteResponse, ProvidersResponse } from '../models/ChatModels';
import { Logger } from '../utils/Logger';
import { AppConfigManager } from '../utils/AppConfigManager';
import { IApiService } from '../di/ServiceInterfaces';
import { NetworkRequestOptimizer, OptimizedRequestConfig } from '../utils/NetworkRequestOptimizer';
import { RequestType } from '../utils/AdaptiveTimeoutManager';
import { VectorEmbeddingResponse } from '../types/APITypes';

/**
 * API服务类 - 处理与服务器的HTTP通信
 *
 * 该服务类负责与应用后端服务器进行HTTP通信，提供聊天、代码执行、
 * 厂商列表查询等功能。集成了网络请求优化系统，提供连接复用、
 * 自适应超时、请求去重等性能优化功能。
 *
 * @implements IApiService API服务接口
 */
export class ApiService implements IApiService {
  private httpRequest: http.HttpRequest;
  private configManager: AppConfigManager;
  private networkOptimizer: NetworkRequestOptimizer;

  /**
   * 构造函数 - 初始化API服务
   *
   * 创建配置管理器、HTTP请求对象和网络优化器实例。
   * 网络优化器提供连接复用、自适应超时、请求去重等功能。
   */
  constructor() {
    this.configManager = AppConfigManager.getInstance();
    this.httpRequest = http.createHttp();
    this.networkOptimizer = NetworkRequestOptimizer.getInstance();
  }
  
  /**
   * 动态获取当前baseUrl
   *
   * 从配置管理器中获取服务器配置，返回当前环境的API基础URL。
   * 支持开发环境、测试环境和生产环境的动态切换。
   *
   * @returns {string} 当前环境的API基础URL
   * @private
   */
  private getBaseUrl(): string {
    return this.configManager.getServerConfig().baseUrl;
  }

  /**
   * 获取厂商和模型列表 - 使用优化的网络请求系统
   *
   * 向服务器发送GET请求获取所有可用的AI模型厂商和模型列表。
   * 使用网络优化系统提供连接复用、自适应超时、请求去重等功能。
   *
   * @returns {Promise<ProvidersResponse>} 厂商和模型列表响应数据
   * @throws {Error} 当网络请求失败或服务器返回错误状态码时抛出异常
   *
   * @example
   * const apiService = new ApiService();
   * const providers = await apiService.getProviders();
   * console.log('可用厂商:', providers.providers);
   */
  async getProviders(): Promise<ProvidersResponse> {
    try {
      const url = `${this.getBaseUrl()}/providers`;

      const optimizedConfig: OptimizedRequestConfig = {
        url: url,
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        },
        requestType: RequestType.MODEL_LIST,
        enableDeduplication: true,
        enableAdaptiveTimeout: true,
        retryAttempts: 2
      };

      Logger.info('ApiService', `优化获取厂商列表: ${url}`);
      const response = await this.networkOptimizer.sendOptimizedRequest(optimizedConfig);

      if (response.statusCode === 200) {
        const result = JSON.parse(response.body) as ProvidersResponse;
        Logger.debug('ApiService', `厂商列表获取成功，优化统计: ${JSON.stringify(response.optimizationStats)}`);
        return result;
      } else {
        throw new Error(`请求失败,状态码: ${response.statusCode}, 信息: ${response.body}`);
      }
    } catch (error) {
      const errorMessage = (error as Error).message || '未知网络错误';
      Logger.error('ApiService', `获取厂商列表失败: ${errorMessage}`);
      throw new Error(`获取厂商列表失败: ${errorMessage}`);
    }
  }

  /**
   * 发送聊天请求 - 使用优化的网络请求系统
   *
   * 向服务器发送聊天请求，与AI模型进行对话交互。支持多轮对话、
   * 系统提示词、温度设置等功能。使用网络优化系统提供高性能的
   * 连接复用和自适应超时处理。
   *
   * @param {ChatRequest} request 聊天请求对象，包含消息列表、模型参数等
   * @returns {Promise<ChatResponse>} AI模型的回复响应
   * @throws {Error} 当网络请求失败或服务器返回错误状态码时抛出异常
   *
   * @example
   * const request: ChatRequest = {
   *   model: 'siliconflow.Qwen/Qwen2.5-7B-Instruct',
   *   messages: [
   *     { role: 'user', content: 'Hello, how are you?' }
   *   ],
   *   temperature: 0.7,
   *   max_tokens: 1000
   * };
   * const response = await apiService.sendChatMessage(request);
   * console.log('AI回复:', response.choices[0].message.content);
   */
  async sendChatMessage(request: ChatRequest): Promise<ChatResponse> {
    try {
      const url = `${this.getBaseUrl()}/chat`;
      const requestBody = JSON.stringify(request);

      // 详细记录请求内容
      Logger.info('ApiService', '=== 发送优化聊天请求 ===');
      Logger.info('ApiService', `请求URL: ${url}`);
      Logger.info('ApiService', '请求方法: POST');
      Logger.info('ApiService', '请求头: Content-Type: application/json');
      Logger.info('ApiService', `请求体: ${requestBody}`);

      // 检查消息内容
      Logger.info('ApiService', `消息数量: ${request.messages.length}`);
      request.messages.forEach((msg, index) => {
        Logger.info('ApiService', `消息[${index}]: role=${msg.role}, content长度=${msg.content.length}`);
        if (msg.role === 'system') {
          Logger.info('ApiService', `系统消息[${index}]内容: ${msg.content}`);
        }
      });
      Logger.info('ApiService', '===============================');

      const optimizedConfig: OptimizedRequestConfig = {
        url: url,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: requestBody,
        requestType: RequestType.CHAT,
        enableDeduplication: false, // 聊天请求通常不应去重
        enableAdaptiveTimeout: true,
        retryAttempts: 1,
        retryDelay: 2000
      };

      const response = await this.networkOptimizer.sendOptimizedRequest(optimizedConfig);

      if (response.statusCode === 200) {
        const result = JSON.parse(response.body) as ChatResponse;
        Logger.info('ApiService', `聊天请求成功，优化统计: ${JSON.stringify(response.optimizationStats)}`);
        Logger.info('ApiService', `连接复用: ${response.connectionReused}, 实际超时: ${response.actualTimeout}ms`);
        return result;
      } else {
        throw new Error(`聊天请求失败,状态码: ${response.statusCode}, 信息: ${response.body}`);
      }
    } catch (error) {
      const errorMessage = (error as Error).message || '未知网络错误';
      Logger.error('ApiService', `发送聊天消息失败: ${errorMessage}`);
      throw new Error(`发送聊天消息失败: ${errorMessage}`);
    }
  }

  /**
   * 执行代码 - 使用优化的网络请求系统
   *
   * 向服务器发送代码执行请求，在安全的沙箱环境中执行指定语言的代码。
   * 支持Python、JavaScript、Go、Bash等多种编程语言的在线执行。
   * 使用网络优化系统确保代码执行请求的高效处理。
   *
   * @param {ExecuteRequest} request 代码执行请求对象，包含代码内容、语言类型、超时设置等
   * @returns {Promise<ExecuteResponse>} 代码执行结果，包含输出内容、执行时间、错误信息等
   * @throws {Error} 当网络请求失败、服务器错误或代码执行异常时抛出异常
   *
   * @example
   * const request: ExecuteRequest = {
   *   language: 'python',
   *   code: 'print("Hello, World!")\nprint(2 + 2)',
   *   timeout: 30
   * };
   * const response = await apiService.executeCode(request);
   * console.log('执行结果:', response.output);
   * console.log('执行时间:', response.execution_time + 'ms');
   */
  async executeCode(request: ExecuteRequest): Promise<ExecuteResponse> {
    try {
      const url = `${this.getBaseUrl()}/execute`;
      const requestBody = JSON.stringify(request);

      const optimizedConfig: OptimizedRequestConfig = {
        url: url,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: requestBody,
        requestType: RequestType.CODE_EXECUTION,
        enableDeduplication: false, // 代码执行请求不应去重
        enableAdaptiveTimeout: true,
        retryAttempts: 1,
        retryDelay: 3000
      };

      Logger.info('ApiService', `优化代码执行请求: ${url}`);
      const response = await this.networkOptimizer.sendOptimizedRequest(optimizedConfig);

      if (response.statusCode === 200) {
        const result = JSON.parse(response.body) as ExecuteResponse;
        Logger.debug('ApiService', `代码执行成功，优化统计: ${JSON.stringify(response.optimizationStats)}`);
        return result;
      } else {
        throw new Error(`代码执行失败,状态码: ${response.statusCode}, 信息: ${response.body}`);
      }
    } catch (error) {
      const errorMessage = (error as Error).message || '未知网络错误';
      Logger.error('ApiService', `代码执行失败: ${errorMessage}`);
      throw new Error(`代码执行失败: ${errorMessage}`);
    }
  }

  /**
   * 生成文本向量嵌入 - 使用优化的网络请求系统
   *
   * 向服务器发送文本内容，获取对应的向量嵌入表示。
   * 支持语义搜索和相似度计算功能。使用网络优化系统提供
   * 高性能的向量计算服务。
   *
   * @param {string} text 需要生成向量的文本内容
   * @returns {Promise<number[]>} 文本的向量嵌入表示（512维）
   * @throws {Error} 当网络请求失败或服务器返回错误状态码时抛出异常
   *
   * @example
   * const vector = await apiService.generateEmbedding('我喜欢喝咖啡');
   * console.log('向量维度:', vector.length);
   */
  async generateEmbedding(text: string): Promise<number[]> {
    try {
      const url = `${this.getBaseUrl()}/embed`;
      const requestBody = JSON.stringify({ text });

      const optimizedConfig: OptimizedRequestConfig = {
        url: url,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: requestBody,
        requestType: RequestType.EMBEDDING,
        enableDeduplication: true, // 相同文本的嵌入请求可以缓存
        enableAdaptiveTimeout: true,
        retryAttempts: 2,
        retryDelay: 2000
      };

      Logger.debug('ApiService', `生成向量嵌入: ${text.substring(0, 50)}${text.length > 50 ? '...' : ''}`);
      const response = await this.networkOptimizer.sendOptimizedRequest(optimizedConfig);

      if (response.statusCode === 200) {
        const result = JSON.parse(response.body) as VectorEmbeddingResponse;
        Logger.debug('ApiService', `向量嵌入生成成功，维度: ${result.vector.length}`);
        return result.vector;
      } else {
        throw new Error(`向量嵌入生成失败,状态码: ${response.statusCode}, 信息: ${response.body}`);
      }
    } catch (error) {
      const errorMessage = (error as Error).message || '未知网络错误';
      Logger.error('ApiService', `生成向量嵌入失败: ${errorMessage}`);
      throw new Error(`生成向量嵌入失败: ${errorMessage}`);
    }
  }

  /**
   * 测试API连接 - 使用优化的网络请求系统
   *
   * 测试与后端服务器的网络连接状态，通过发送简单的GET请求来验证
   * 服务器是否可达且正常响应。使用网络优化系统提供快速、可靠的
   * 连接测试功能。
   *
   * @returns {Promise<boolean>} 连接测试结果，true表示连接成功，false表示连接失败
   *
   * @example
   * const isConnected = await apiService.testConnection();
   * if (isConnected) {
   *   console.log('服务器连接正常');
   * } else {
   *   console.log('服务器连接失败，请检查网络配置');
   * }
   */
  async testConnection(): Promise<boolean> {
    try {
      const url = `${this.getBaseUrl()}/providers`;

      const optimizedConfig: OptimizedRequestConfig = {
        url: url,
        method: 'GET',
        headers: {},
        requestType: RequestType.CONNECTION_TEST,
        enableDeduplication: false,
        enableAdaptiveTimeout: true,
        customTimeout: 10000,
        retryAttempts: 1,
        retryDelay: 1000
      };

      Logger.info('ApiService', `优化测试服务器连接: ${url}`);
      const response = await this.networkOptimizer.sendOptimizedRequest(optimizedConfig);

      const success = response.statusCode === 200;
      Logger.info('ApiService', `连接测试结果: ${success}，优化统计: ${JSON.stringify(response.optimizationStats)}`);
      return success;

    } catch (error) {
      Logger.error('ApiService', `连接测试失败: ${(error as Error).message}`);
      return false;
    }
  }

  /**
   * 获取网络优化统计信息
   *
   * 返回网络优化器的统计信息，包括请求总数、优化命中率、
   * 连接复用率、平均响应时间等性能指标。
   *
   * @returns {OptimizationStats} 网络优化统计数据
   *
   * @example
   * const stats = apiService.getOptimizationStats();
   * console.log('连接复用率:', stats.connectionReuseRate);
   * console.log('平均响应时间:', stats.averageResponseTime + 'ms');
   */
  getOptimizationStats() {
    return this.networkOptimizer.getOptimizationStats();
  }

  /**
   * 获取详细的性能报告
   *
   * 返回详细的性能分析报告，包含各种请求类型的性能数据、
   * 错误统计、优化效果分析等信息，用于性能监控和优化。
   *
   * @returns {DetailedPerformanceReport} 详细性能报告
   *
   * @example
   * const report = apiService.getDetailedPerformanceReport();
   * console.log('聊天请求性能:', report.chatPerformance);
   * console.log('优化效果:', report.optimizationSummary);
   */
  getDetailedPerformanceReport() {
    return this.networkOptimizer.getDetailedPerformanceReport();
  }

  /**
   * 获取优化器健康状态
   *
   * 返回网络优化器的健康状态信息，包括连接池状态、
   * 内存使用情况、错误率等健康指标。
   *
   * @returns {HealthStatus} 优化器健康状态
   *
   * @example
   * const health = apiService.getOptimizerHealthStatus();
   * if (health.isHealthy) {
   *   console.log('优化器运行正常');
   * } else {
   *   console.log('优化器异常:', health.issues);
   * }
   */
  getOptimizerHealthStatus() {
    return this.networkOptimizer.getHealthStatus();
  }

  /**
   * 预热网络优化器
   *
   * 通过预发送常用API请求来预热网络连接池，建立初始连接，
   * 提升首次请求的响应速度。预热过程在后台异步执行。
   *
   * @returns {Promise<void>} 预热完成的Promise
   *
   * @example
   * await apiService.warmupOptimizer();
   * console.log('网络优化器预热完成');
   */
  async warmupOptimizer() {
    const baseUrl = this.getBaseUrl();
    const urls = [
      `${baseUrl}/providers`,
      `${baseUrl}/chat`,
      `${baseUrl}/execute`
    ];

    try {
      await this.networkOptimizer.warmup(urls);
      Logger.info('ApiService', 'API服务网络优化器预热完成');
    } catch (error) {
      Logger.warn('ApiService', `API服务网络优化器预热失败: ${(error as Error).message}`);
    }
  }

  /**
   * 销毁HTTP请求对象
   *
   * 清理HTTP请求对象和相关资源，释放网络连接。
   * 注意：网络优化器是全局单例，不在该方法中清理。
   *
   * @example
   * // 应用退出时调用
   * apiService.destroy();
   */
  destroy() {
    if (this.httpRequest) {
      this.httpRequest.destroy();
    }
    // 优化器在全局单例管理，不在这里清理
  }
}