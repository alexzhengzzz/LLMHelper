/**
 * 直连API服务
 * 管理多个AI厂商的直接连接
 */

import { ChatRequest, ChatResponse, AIProvider, ServiceStats } from '../types/APITypes';
import { GLMClient } from '../clients/GLMClient';
import { SiliconFlowClient } from '../clients/SiliconFlowClient';
import { BaseAPIClient } from '../clients/BaseAPIClient';
import { Logger } from '../utils/Logger';
import { APIKeyManager } from '../utils/APIKeyManager';
import { IDirectAPIService } from '../di/ServiceInterfaces';
// import { GeminiClient } from '../clients/GeminiClient'; // 已禁用 - 暂不可用

export class DirectAPIService implements IDirectAPIService {
  private clients: Map<AIProvider, BaseAPIClient>;
  private apiKeyManager: APIKeyManager;
  
  constructor(apiKeys?: Map<AIProvider, string>) {
    this.clients = new Map<AIProvider, BaseAPIClient>();
    this.apiKeyManager = APIKeyManager.getInstance();
    this.initializeClients(apiKeys);
  }
  
  /**
   * 初始化所有厂商客户端
   */
  private initializeClients(apiKeys?: Map<AIProvider, string>): void {
    try {
      const glmApiKey = apiKeys?.get(AIProvider.GLM) || '';
      const siliconFlowApiKey = apiKeys?.get(AIProvider.SILICONFLOW) || '';
      
      this.clients.set(AIProvider.GLM, new GLMClient(glmApiKey));
      this.clients.set(AIProvider.SILICONFLOW, new SiliconFlowClient(siliconFlowApiKey));
      // this.clients.set(AIProvider.GEMINI, new GeminiClient()); // 已禁用 - 暂不可用
      
      Logger.info('DirectAPIService', '直连API服务初始化完成');
    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('DirectAPIService', `初始化客户端失败: ${errorMessage}`);
      throw new Error(errorMessage);
    }
  }
  
  /**
   * 发送聊天请求
   */
  async sendChatRequest(request: ChatRequest, provider: AIProvider): Promise<ChatResponse> {
    try {
      const client = this.clients.get(provider);
      if (!client) {
        const error = new Error(`不支持的厂商: ${provider}`);
        Logger.error('DirectAPIService', `查找客户端失败: ${error.message}`);
        throw error;
      }
      
      Logger.info('DirectAPIService', `=== 开始直连模式聊天请求 ===`);
      Logger.info('DirectAPIService', `使用厂商: ${provider}`);
      Logger.info('DirectAPIService', `请求模型: ${request.model}`);
      Logger.info('DirectAPIService', `消息数量: ${request.messages?.length || 0}`);
      Logger.info('DirectAPIService', `消息内容: ${JSON.stringify(request.messages)}`);
      Logger.info('DirectAPIService', `其他参数 - max_tokens: ${request.max_tokens}, temperature: ${request.temperature}, stream: ${request.stream}`);
      
      const startTime = Date.now();
      const response = await client.sendChatRequest(request);
      const endTime = Date.now();
      
      Logger.info('DirectAPIService', `=== 直连模式聊天请求完成 ===`);
      Logger.info('DirectAPIService', `总耗时: ${endTime - startTime}ms`);
      Logger.info('DirectAPIService', `响应ID: ${response.id}`);
      Logger.info('DirectAPIService', `响应模型: ${response.model}`);
      Logger.info('DirectAPIService', `响应选择数量: ${response.choices?.length || 0}`);
      Logger.info('DirectAPIService', `响应内容: ${response.choices?.[0]?.message?.content || '无内容'}`);
      Logger.info('DirectAPIService', `令牌使用情况: ${JSON.stringify(response.usage)}`);
      
      return response;
      
    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('DirectAPIService', `=== 直连模式聊天请求失败 ===`);
      Logger.error('DirectAPIService', `厂商: ${provider}`);
      Logger.error('DirectAPIService', `错误信息: ${errorMessage}`);
      Logger.error('DirectAPIService', `错误堆栈: ${(error as Error).stack}`);
      throw new Error(errorMessage);
    }
  }
  
  /**
   * 测试指定厂商的连接
   */
  async testConnection(provider: AIProvider): Promise<boolean> {
    try {
      const client = this.clients.get(provider);
      if (!client) {
        Logger.error('DirectAPIService', `不支持的厂商: ${provider}`);
        return false;
      }
      
      Logger.info('DirectAPIService', `测试${provider}厂商连接`);
      return await client.testConnection();
      
    } catch (error) {
      Logger.error('DirectAPIService', `${provider}连接测试失败: ${(error as Error).message}`);
      return false;
    }
  }
  
  /**
   * 测试所有厂商的连接
   */
  async testAllConnections(): Promise<Map<AIProvider, boolean>> {
    const results = new Map<AIProvider, boolean>();
    
    for (const provider of this.getSupportedProviders()) {
      try {
        const success = await this.testConnection(provider);
        results.set(provider, success);
      } catch (error) {
        Logger.error('DirectAPIService', `测试${provider}连接时异常: ${(error as Error).message}`);
        results.set(provider, false);
      }
    }
    
    return results;
  }
  
  /**
   * 获取支持的厂商列表
   */
  getSupportedProviders(): AIProvider[] {
    return Array.from(this.clients.keys());
  }
  
  /**
   * 根据模型名称获取对应的厂商（异步版本）
   */
  async getProviderByModel(modelName: string): Promise<AIProvider | null> {
    Logger.info('DirectAPIService', `根据模型名称查找厂商: ${modelName}`);
    
    const providerIterator = this.clients.keys();
    let providerResult = providerIterator.next();
    
    while (!providerResult.done) {
      const provider = providerResult.value;
      const client = this.clients.get(provider);
      
      if (client) {
        try {
          const supportedModels: string[] = await this.getSupportedModels(provider);
          if (supportedModels.includes(modelName)) {
            Logger.info('DirectAPIService', `找到匹配的厂商: ${provider} 对于模型: ${modelName}`);
            return provider;
          }
        } catch (error) {
          Logger.error('DirectAPIService', `查找厂商 ${provider} 模型时出错: ${(error as Error).message}`);
        }
      }
      
      providerResult = providerIterator.next();
    }
    
    Logger.warn('DirectAPIService', `未找到支持模型 ${modelName} 的厂商`);
    return null;
  }
  
  /**
   * 验证模型与厂商的匹配性（异步版本）
   */
  async validateModelProviderMatch(modelName: string, provider: AIProvider): Promise<boolean> {
    const expectedProvider = await this.getProviderByModel(modelName);
    const isValid = expectedProvider === provider;
    
    Logger.info('DirectAPIService', `模型 ${modelName} 与厂商 ${provider} 匹配性: ${isValid}`);
    if (!isValid) {
      Logger.warn('DirectAPIService', `模型 ${modelName} 应该使用厂商 ${expectedProvider}，但当前使用 ${provider}`);
    }
    
    return isValid;
  }
  
  /**
   * 获取所有支持的模型到厂商的映射（异步版本）
   * 根据配置的API密钥过滤可用的模型
   */
  async getModelProviderMap(): Promise<Map<string, AIProvider>> {
    const modelProviderMap = new Map<string, AIProvider>();
    
    // 确保APIKeyManager已初始化，否则无法获取API密钥配置
    if (!this.apiKeyManager.isInitialized()) {
      Logger.info('DirectAPIService', 'APIKeyManager未初始化，正在初始化...');
      try {
        await this.apiKeyManager.initialize();
        Logger.info('DirectAPIService', 'APIKeyManager初始化完成');
      } catch (error) {
        Logger.error('DirectAPIService', `APIKeyManager初始化失败: ${error}`);
        return modelProviderMap; // 返回空映射
      }
    }
    
    // 获取所有已配置的API密钥
    const allConfigs = this.apiKeyManager.getAllConfigs();
    const providersWithKeys: AIProvider[] = [];
    
    // 检查哪些厂商有有效的API密钥
    allConfigs.forEach((config, provider) => {
      if (config.apiKey && config.apiKey.trim().length > 0 && config.enabled) {
        providersWithKeys.push(provider);
        // 立即同步API密钥到对应的客户端实例
        this.setApiKey(provider, config.apiKey);
        Logger.info('DirectAPIService', `厂商 ${provider} 有有效的API密钥，已同步到客户端`);
      }
    });
    
    Logger.info('DirectAPIService', `找到 ${providersWithKeys.length} 个厂商有有效API密钥`);
    
    if (providersWithKeys.length === 0) {
      Logger.warn('DirectAPIService', '没有配置任何有效的API密钥，返回空模型列表');
      return modelProviderMap;
    }
    
    // 只为有API密钥的厂商获取模型列表
    for (const provider of providersWithKeys) {
      const client = this.clients.get(provider);
      
      if (client) {
        try {
          const supportedModels = await this.getSupportedModels(provider);
          for (let i = 0; i < supportedModels.length; i++) {
            const model = supportedModels[i];
            modelProviderMap.set(model, provider);
          }
          Logger.info('DirectAPIService', `厂商 ${provider} 添加了 ${supportedModels.length} 个模型`);
        } catch (error) {
          Logger.error('DirectAPIService', `获取厂商 ${provider} 模型列表失败: ${(error as Error).message}`);
        }
      }
    }
    
    Logger.info('DirectAPIService', `构建了模型-厂商映射，共 ${modelProviderMap.size} 个模型`);
    return modelProviderMap;
  }
  
  /**
   * 获取指定厂商支持的模型列表（异步版本）
   */
  async getSupportedModels(provider: AIProvider): Promise<string[]> {
    const client = this.clients.get(provider);
    if (!client) {
      Logger.error('DirectAPIService', `不支持的厂商: ${provider}`);
      return [];
    }
    
    try {
      // 通过类型检查获取模型列表
      if (client instanceof GLMClient) {
        return await client.getSupportedModels();
      } else if (client instanceof SiliconFlowClient) {
        return await client.getSupportedModels();
      } /* else if (client instanceof GeminiClient) {
        return await client.getSupportedModels();
      } */ // 已禁用 - 暂不可用
      
      return [];
    } catch (error) {
      Logger.error('DirectAPIService', `获取厂商 ${provider} 支持的模型列表失败: ${(error as Error).message}`);
      return [];
    }
  }
  
  /**
   * 获取厂商显示名称
   */
  getProviderDisplayName(provider: AIProvider): string {
    const client = this.clients.get(provider);
    if (!client) {
      return '未知厂商';
    }
    
    // 通过类型检查获取厂商名称
    if (client instanceof GLMClient) {
      return client.getProviderName();
    } else if (client instanceof SiliconFlowClient) {
      return client.getProviderName();
    } /* else if (client instanceof GeminiClient) {
      return client.getProviderName();
    } */ // 已禁用 - 暂不可用
    
    return '未知厂商';
  }
  
  /**
   * 设置指定厂商的API密钥
   */
  setApiKey(provider: AIProvider, apiKey: string): void {
    const client = this.clients.get(provider);
    if (!client) {
      Logger.error('DirectAPIService', `不支持的厂商: ${provider}`);
      return;
    }
    
    // 通过类型检查设置API密钥
    if (client instanceof GLMClient) {
      client.setApiKey(apiKey);
    } else if (client instanceof SiliconFlowClient) {
      client.setApiKey(apiKey);
    } /* else if (client instanceof GeminiClient) {
      client.setApiKey(apiKey);
    } */ // 已禁用 - 暂不可用
    
    // 不需要回调APIKeyManager，避免循环调用
    // APIKeyManager会调用这个方法来更新客户端
    
    Logger.info('DirectAPIService', `${provider}厂商API密钥已更新`);
  }
  
  /**
   * 批量设置API密钥
   */
  setApiKeys(apiKeys: Map<AIProvider, string>): void {
    apiKeys.forEach((apiKey: string, provider: AIProvider) => {
      this.setApiKey(provider, apiKey);
    });
  }
  
  /**
   * 获取指定厂商的客户端配置信息
   */
  getClientConfig(provider: AIProvider) {
    const client = this.clients.get(provider);
    if (!client) {
      return null;
    }
    
    return client.getConfig();
  }
  
  /**
   * 获取服务统计信息
   */
  getServiceStats(): ServiceStats {
    const stats: ServiceStats = {
      supportedProviders: this.getSupportedProviders().length,
      initializedClients: this.clients.size,
      availableProviders: Array.from(this.clients.keys())
    };
    
    Logger.info('DirectAPIService', `服务统计: ${JSON.stringify(stats)}`);
    return stats;
  }
  
  /**
   * 销毁服务
   */
  destroy(): void {
    this.clients.clear();
    Logger.info('DirectAPIService', '直连API服务已销毁');
  }
}