/**
 * 依赖注入使用示例
 * 展示如何在应用中使用新的依赖注入系统
 */

import { AppDI, getAPIManager, getDirectAPIService, getApiService, getAPIKeyManager } from '../di/AppDI';
import { IAPIManager, IDirectAPIService, IApiService, IAPIKeyManager } from '../di/ServiceInterfaces';
import { AIProvider, ChatRequest } from '../types/APITypes';
import { Logger } from '../utils/Logger';

/**
 * 应用启动时初始化依赖注入
 */
export async function initializeAppWithDI(): Promise<void> {
  try {
    Logger.info('DIExample', '开始初始化应用依赖注入');
    
    // 初始化依赖注入容器
    const appDI = AppDI.getInstance();
    await appDI.initialize();
    
    Logger.info('DIExample', '应用依赖注入初始化完成');
    
  } catch (error) {
    Logger.error('DIExample', `应用依赖注入初始化失败: ${(error as Error).message}`);
    throw error;
  }
}

/**
 * 使用依赖注入的服务示例
 */
export class ChatServiceExample {
  private apiManager: IAPIManager;
  private directApiService: IDirectAPIService;
  private apiService: IApiService;
  private apiKeyManager: IAPIKeyManager;
  
  constructor() {
    // 使用便捷函数获取服务实例
    this.apiManager = getAPIManager();
    this.directApiService = getDirectAPIService();
    this.apiService = getApiService();
    this.apiKeyManager = getAPIKeyManager();
  }
  
  /**
   * 发送聊天消息的示例
   */
  async sendChatExample(): Promise<void> {
    try {
      const request: ChatRequest = {
        model: 'Qwen/Qwen2.5-7B-Instruct',
        messages: [
          { role: 'user', content: '你好，请介绍一下依赖注入' }
        ]
      };
      
      // 使用 APIManager 发送请求（会自动选择直连或代理模式）
      const response = await this.apiManager.sendChatRequest(request);
      
      Logger.info('ChatServiceExample', `收到回复: ${response.choices[0].message.content}`);
      
    } catch (error) {
      Logger.error('ChatServiceExample', `聊天请求失败: ${(error as Error).message}`);
    }
  }
  
  /**
   * 测试连接的示例
   */
  async testConnectionsExample(): Promise<void> {
    try {
      // 测试直连模式连接
      const directResult = await this.directApiService.testConnection(AIProvider.SILICONFLOW);
      Logger.info('ChatServiceExample', `直连模式测试结果: ${directResult ? '成功' : '失败'}`);
      
      // 测试代理模式连接
      const proxyResult = await this.apiService.testConnection();
      Logger.info('ChatServiceExample', `代理模式测试结果: ${proxyResult ? '成功' : '失败'}`);
      
      // 使用 APIManager 测试连接（会根据当前模式自动选择）
      const managerResult = await this.apiManager.testConnection();
      Logger.info('ChatServiceExample', `APIManager 测试结果: ${managerResult.success ? '成功' : '失败'}`);
      
    } catch (error) {
      Logger.error('ChatServiceExample', `连接测试失败: ${(error as Error).message}`);
    }
  }
  
  /**
   * 管理 API 密钥的示例
   */
  async manageApiKeysExample(): Promise<void> {
    try {
      // 获取支持的厂商
      const providers = this.apiKeyManager.getSupportedProviders();
      Logger.info('ChatServiceExample', `支持的厂商: ${providers.map(p => p.name).join(', ')}`);
      
      // 验证 API 密钥格式
      const validation = this.apiKeyManager.validateApiKey(AIProvider.SILICONFLOW, 'sk-test-key');
      Logger.info('ChatServiceExample', `API 密钥验证结果: ${validation.isValid ? '有效' : '无效'}`);
      
      // 测试所有连接
      const results = await this.apiKeyManager.testAllConnections();
      Logger.info('ChatServiceExample', `连接测试完成，共测试 ${results.length} 个厂商`);
      
    } catch (error) {
      Logger.error('ChatServiceExample', `API 密钥管理失败: ${(error as Error).message}`);
    }
  }
}

/**
 * 使用 AppDI 的详细示例
 */
export class AdvancedDIExample {
  private appDI: AppDI;
  
  constructor() {
    this.appDI = AppDI.getInstance();
  }
  
  /**
   * 动态获取服务的示例
   */
  async dynamicServiceExample(): Promise<void> {
    try {
      // 检查服务是否可用
      if (this.appDI.isServiceAvailable('APIManager')) {
        // 动态获取服务
        const apiManager = this.appDI.getService<IAPIManager>('APIManager');
        
        // 使用服务
        const state = apiManager.getState();
        Logger.info('AdvancedDIExample', `APIManager 状态: ${JSON.stringify(state)}`);
      }
      
      // 安全获取服务（不会抛出异常）
      const someService = this.appDI.getServiceSafe<IApiService>('SomeService');
      if (someService) {
        Logger.info('AdvancedDIExample', '获取到了服务实例');
      } else {
        Logger.warn('AdvancedDIExample', '服务不存在');
      }
      
    } catch (error) {
      Logger.error('AdvancedDIExample', `动态服务获取失败: ${(error as Error).message}`);
    }
  }
  
  /**
   * 服务生命周期管理示例
   */
  async lifecycleExample(): Promise<void> {
    try {
      // 获取所有已注册的服务
      const services = this.appDI.getRegisteredServices();
      Logger.info('AdvancedDIExample', `已注册的服务: ${services.join(', ')}`);
      
      // 重置依赖注入容器（主要用于测试或重新初始化）
      await this.appDI.reset();
      Logger.info('AdvancedDIExample', '依赖注入容器已重置');
      
      // 重新初始化
      await this.appDI.initialize();
      Logger.info('AdvancedDIExample', '依赖注入容器已重新初始化');
      
    } catch (error) {
      Logger.error('AdvancedDIExample', `生命周期管理失败: ${(error as Error).message}`);
    }
  }
}

/**
 * 在实际应用中的使用示例
 */
export class RealWorldExample {
  
  /**
   * 在应用启动时调用
   */
  async onAppStart(): Promise<void> {
    // 1. 初始化依赖注入
    await initializeAppWithDI();
    
    // 2. 创建服务实例
    const chatService = new ChatServiceExample();
    
    // 3. 测试连接
    await chatService.testConnectionsExample();
    
    // 4. 管理API密钥
    await chatService.manageApiKeysExample();
    
    Logger.info('RealWorldExample', '应用启动完成');
  }
  
  /**
   * 在页面中使用依赖注入
   */
  async useInPage(): Promise<void> {
    // 获取 APIManager 实例
    const apiManager = getAPIManager();
    
    // 获取当前状态
    const state = apiManager.getState();
    Logger.info('RealWorldExample', `当前模式: ${state.currentMode}`);
    
    // 发送聊天请求
    const request: ChatRequest = {
      model: 'Qwen/Qwen2.5-7B-Instruct',
      messages: [{ role: 'user', content: '你好' }]
    };
    
    const response = await apiManager.sendChatRequest(request);
    Logger.info('RealWorldExample', `回复: ${response.choices[0].message.content}`);
  }
}