/**
 * API密钥管理器
 * 管理多个AI厂商的API密钥配置和连接状态
 */

import { AIProvider, ConnectionTestResult as APIConnectionTestResult, APIMode,
  ConnectionTestResult } from '../types/APITypes';
import { 
  APIKeyConfig, 
  APIKeyManagerState, 
  APIKeyValidationResult,
  ProviderInfo,
  SUPPORTED_PROVIDERS,
  ConnectionStatus,
  APIKeyManagerEvent,
  ConnectionTestResult as KeyConnectionTestResult
} from '../types/APIKeyTypes';
import { AppStorage } from '../utils/AppStorage';
import { DirectAPIService } from '../services/DirectAPIService';
import { Logger } from '../utils/Logger';
import { IAPIKeyManager } from '../di/ServiceInterfaces';

/**
 * API密钥管理器类
 */
export class APIKeyManager implements IAPIKeyManager {
  private static instance: APIKeyManager;
  private state: APIKeyManagerState;
  private directApiService: DirectAPIService | null = null;
  private listeners: Map<string, (event: APIKeyManagerEvent) => void> = new Map();

  private constructor() {
    this.state = {
      configs: new Map<AIProvider, APIKeyConfig>(),
      isInitialized: false,
      testingProvider: null
    };
    // Don't initialize DirectAPIService in constructor to avoid circular dependency
  }

  /**
   * 获取单例实例
   */
  static getInstance(): APIKeyManager {
    if (!APIKeyManager.instance) {
      APIKeyManager.instance = new APIKeyManager();
    }
    return APIKeyManager.instance;
  }

  /**
   * 获取DirectAPIService实例（懒加载）
   */
  private getDirectApiService(): DirectAPIService {
    if (!this.directApiService) {
      this.directApiService = new DirectAPIService();
      
      // 同步所有已保存的API密钥到DirectAPIService
      this.syncApiKeysToDirectService();
    }
    return this.directApiService;
  }

  /**
   * 同步API密钥到DirectAPIService
   */
  private syncApiKeysToDirectService(): void {
    if (!this.directApiService) {
      Logger.warn('APIKeyManager', 'DirectAPIService未创建，无法同步API密钥');
      return;
    }

    Logger.info('APIKeyManager', `开始同步API密钥，共有${this.state.configs.size}个厂商配置`);
    let syncCount = 0;
    
    this.state.configs.forEach((config, provider) => {
      if (config.apiKey && config.apiKey.trim().length > 0) {
        this.directApiService!.setApiKey(provider, config.apiKey);
        Logger.info('APIKeyManager', `同步${provider}的API密钥到DirectAPIService，密钥前缀: ${config.apiKey.substring(0, 10)}...`);
        syncCount++;
      } else {
        Logger.warn('APIKeyManager', `${provider}的API密钥为空，跳过同步`);
      }
    });
    
    Logger.info('APIKeyManager', `API密钥同步完成，成功同步${syncCount}个厂商`);
  }

  /**
   * 检查是否已初始化
   */
  isInitialized(): boolean {
    return this.state.isInitialized;
  }

  /**
   * 初始化管理器
   */
  async initialize(): Promise<void> {
    if (this.state.isInitialized) {
      return;
    }

    try {
      await this.loadConfigs();
      this.state.isInitialized = true;
      Logger.info('APIKeyManager', 'API密钥管理器初始化完成');
      this.emit({ type: 'all_configs_loaded' });
    } catch (error) {
      Logger.error('APIKeyManager', `初始化失败: ${error}`);
      throw new Error(`初始化失败: ${error}`);
    }
  }

  /**
   * 加载配置
   */
  private async loadConfigs(): Promise<void> {
    try {
      const storageData = await AppStorage.getAPIKeys() as Record<string, APIKeyConfig>;
      this.state.configs.clear();

      // 为每个支持的厂商创建默认配置
      for (const providerInfo of SUPPORTED_PROVIDERS) {
        const savedConfig = storageData[providerInfo.provider];
        if (savedConfig) {
          this.state.configs.set(providerInfo.provider, savedConfig);
        } else {
          // 创建默认配置
          const defaultConfig: APIKeyConfig = {
            provider: providerInfo.provider,
            displayName: providerInfo.name,
            description: providerInfo.description,
            apiKey: '',
            baseUrl: this.getDefaultBaseUrl(providerInfo.provider),
            enabled: false
          };
          this.state.configs.set(providerInfo.provider, defaultConfig);
        }
      }

      // 如果DirectAPIService已经创建，同步API密钥
      if (this.directApiService) {
        this.syncApiKeysToDirectService();
      }

      Logger.info('APIKeyManager', `加载了 ${this.state.configs.size} 个厂商配置`);
    } catch (error) {
      Logger.error('APIKeyManager', `加载配置失败: ${error}`);
      throw new Error(`加载配置失败: ${error}`);
    }
  }

  /**
   * 保存配置
   */
  private async saveConfigs(): Promise<void> {
    try {
      const storageData: Record<string, APIKeyConfig> = {};
      this.state.configs.forEach((config, provider) => {
        storageData[provider] = config;
      });

      await AppStorage.saveAPIKeys(storageData);
      Logger.info('APIKeyManager', '配置保存成功');
    } catch (error) {
      Logger.error('APIKeyManager', `保存配置失败: ${error}`);
      throw new Error(`保存配置失败: ${error}`);
    }
  }

  /**
   * 获取默认BaseUrl
   */
  private getDefaultBaseUrl(provider: AIProvider): string {
    switch (provider) {
      case AIProvider.GLM:
        return 'https://open.bigmodel.cn';
      case AIProvider.SILICONFLOW:
        return 'https://api.siliconflow.cn';
      default:
        return '';
    }
  }

  /**
   * 获取所有配置
   */
  getAllConfigs(): Map<AIProvider, APIKeyConfig> {
    return new Map(this.state.configs);
  }

  /**
   * 获取指定厂商的配置
   */
  getConfig(provider: AIProvider): APIKeyConfig | null {
    return this.state.configs.get(provider) || null;
  }

  /**
   * 更新API密钥
   */
  async updateApiKey(provider: AIProvider, apiKey: string): Promise<void> {
    const config = this.state.configs.get(provider);
    if (!config) {
      throw new Error(`不支持的厂商: ${provider}`);
    }

    const validation = this.validateApiKey(provider, apiKey);
    if (!validation.isValid) {
      throw new Error(validation.error || 'API密钥格式不正确');
    }

    config.apiKey = apiKey;
    config.enabled = apiKey.length > 0;
    
    // 更新DirectAPIService中的密钥
    this.getDirectApiService().setApiKey(provider, apiKey);
    
    await this.saveConfigs();
    this.emit({ type: 'config_updated', provider });
    
    Logger.info('APIKeyManager', `${provider} API密钥已更新`);
  }

  /**
   * 验证API密钥格式
   */
  validateApiKey(provider: AIProvider, apiKey: string): APIKeyValidationResult {
    if (!apiKey || apiKey.trim().length === 0) {
      return { isValid: false, error: 'API密钥不能为空' };
    }

    const providerInfo = SUPPORTED_PROVIDERS.find(p => p.provider === provider);
    if (!providerInfo) {
      return { isValid: false, error: '不支持的厂商' };
    }

    // 根据厂商验证密钥格式
    switch (provider) {
      case AIProvider.GLM:
        // GLM密钥格式：64位字符串，包含小数点
        if (!apiKey.includes('.') || apiKey.length < 20) {
          return { 
            isValid: false, 
            error: 'GLM API密钥格式不正确',
            suggestions: [
              '密钥应该包含小数点',
              '密钥长度应该至少20位',
              '请检查是否复制完整'
            ]
          };
        }
        break;
      
      case AIProvider.SILICONFLOW:
        // 硅基流动密钥格式：以sk-开头
        if (!apiKey.startsWith('sk-') || apiKey.length < 20) {
          return { 
            isValid: false, 
            error: '硅基流动API密钥格式不正确',
            suggestions: [
              '密钥应该以sk-开头',
              '密钥长度应该至少20位',
              '请检查是否复制完整'
            ]
          };
        }
        break;
    }

    return { isValid: true };
  }

  /**
   * 测试连接
   */
  async testConnection(provider: AIProvider): Promise<APIConnectionTestResult> {
    const config = this.state.configs.get(provider);
    if (!config || !config.apiKey) {
      return {
        success: false,
        mode: APIMode.DIRECT_CALL,
        provider,
        message: 'API密钥未配置'
      };
    }

    this.state.testingProvider = provider;
    
    try {
      const startTime = Date.now();
      const success = await this.getDirectApiService().testConnection(provider);
      const responseTime = Date.now() - startTime;

      const result: ConnectionTestResult = {
        success,
        mode: APIMode.DIRECT_CALL,
        provider,
        message: success ? `${provider} 连接正常` : `${provider} 连接失败`,
        latency: responseTime
      };

      // 更新配置中的测试结果
      config.lastTestTime = Date.now();
      config.lastTestResult = success;
      if (!success) {
        config.testError = '连接测试失败';
      } else {
        config.testError = undefined;
      }

      await this.saveConfigs();
      
      // 转换为 KeyConnectionTestResult 类型用于 emit 事件
      const keyResult: KeyConnectionTestResult = {
        provider,
        success: result.success,
        responseTime: result.latency,
        error: result.success ? undefined : result.message
      };
      this.emit({ type: 'connection_tested', provider, result: keyResult });

      Logger.info('APIKeyManager', `${provider} 连接测试: ${success ? '成功' : '失败'}, 耗时: ${responseTime}ms`);
      return result;

    } catch (error) {
      const result: APIConnectionTestResult = {
        success: false,
        mode: APIMode.DIRECT_CALL,
        provider,
        message: `连接测试异常: ${(error as Error).message}`
      };

      config.lastTestTime = Date.now();
      config.lastTestResult = false;
      config.testError = (error as Error).message;

      await this.saveConfigs();
      
      // 转换为 KeyConnectionTestResult 类型用于 emit 事件
      const keyResult: KeyConnectionTestResult = {
        provider,
        success: false,
        error: (error as Error).message
      };
      this.emit({ type: 'connection_tested', provider, result: keyResult });

      Logger.error('APIKeyManager', `${provider} 连接测试失败: ${error}`);
      return result;

    } finally {
      this.state.testingProvider = null;
    }
  }

  /**
   * 测试所有连接
   */
  async testAllConnections(): Promise<APIConnectionTestResult[]> {
    const results: APIConnectionTestResult[] = [];
    
    for (const provider of this.state.configs.keys()) {
      const config = this.state.configs.get(provider);
      if (config && config.apiKey) {
        const result = await this.testConnection(provider);
        results.push(result);
      }
    }

    return results;
  }

  /**
   * 启用/禁用厂商
   */
  async setProviderEnabled(provider: AIProvider, enabled: boolean): Promise<void> {
    const config = this.state.configs.get(provider);
    if (!config) {
      throw new Error(`不支持的厂商: ${provider}`);
    }

    if (enabled && !config.apiKey) {
      throw new Error('请先配置API密钥');
    }

    config.enabled = enabled;
    await this.saveConfigs();

    if (enabled) {
      this.emit({ type: 'provider_enabled', provider });
    } else {
      this.emit({ type: 'provider_disabled', provider });
    }

    Logger.info('APIKeyManager', `${provider} 已${enabled ? '启用' : '禁用'}`);
  }

  /**
   * 获取连接状态
   */
  getConnectionStatus(provider: AIProvider): ConnectionStatus {
    const config = this.state.configs.get(provider);
    if (!config) {
      return ConnectionStatus.UNKNOWN;
    }

    if (this.state.testingProvider === provider) {
      return ConnectionStatus.TESTING;
    }

    if (!config.apiKey) {
      return ConnectionStatus.DISCONNECTED;
    }

    if (config.lastTestResult === true) {
      return ConnectionStatus.CONNECTED;
    }

    if (config.lastTestResult === false) {
      return ConnectionStatus.ERROR;
    }

    return ConnectionStatus.UNKNOWN;
  }

  /**
   * 获取支持的厂商信息
   */
  getSupportedProviders(): ProviderInfo[] {
    return [...SUPPORTED_PROVIDERS];
  }

  /**
   * 检查是否正在测试
   */
  isTesting(): boolean {
    return this.state.testingProvider !== null;
  }

  /**
   * 添加事件监听器
   */
  addListener(id: string, callback: (event: APIKeyManagerEvent) => void): void {
    this.listeners.set(id, callback);
  }

  /**
   * 移除事件监听器
   */
  removeListener(id: string): void {
    this.listeners.delete(id);
  }

  /**
   * 发送事件
   */
  private emit(event: APIKeyManagerEvent): void {
    this.listeners.forEach(callback => {
      try {
        callback(event);
      } catch (error) {
        Logger.error('APIKeyManager', `事件监听器执行失败: ${error}`);
      }
    });
  }

  /**
   * 销毁管理器
   */
  destroy(): void {
    this.listeners.clear();
    this.state.configs.clear();
    this.state.isInitialized = false;
    Logger.info('APIKeyManager', 'API密钥管理器已销毁');
  }
}