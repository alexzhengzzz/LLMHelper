/**
 * 依赖注入配置
 * 统一管理所有服务的注册和配置
 */

import { DIContainer } from './DIContainer';
import { IAPIManager, IDirectAPIService, IApiService, IAPIKeyManager, IServiceFactory } from './ServiceInterfaces';
import { Logger } from '../utils/Logger';

/**
 * 服务注册配置
 */
export class DIConfig {
  private container: DIContainer;
  private static instance: DIConfig;
  
  private constructor() {
    this.container = new DIContainer();
  }
  
  static getInstance(): DIConfig {
    if (!DIConfig.instance) {
      DIConfig.instance = new DIConfig();
    }
    return DIConfig.instance;
  }
  
  /**
   * 获取容器实例
   */
  getContainer(): DIContainer {
    return this.container;
  }
  
  /**
   * 注册所有服务
   */
  registerServices(): void {
    try {
      Logger.info('DIConfig', '开始注册依赖注入服务');
      
      // 按照依赖顺序注册服务
      
      // 1. 注册基础服务（无依赖的服务）
      this.registerBaseServices();
      
      // 2. 注册中间层服务
      this.registerMiddleServices();
      
      // 3. 注册高层服务
      this.registerHighLevelServices();
      
      Logger.info('DIConfig', '依赖注入服务注册完成');
      
    } catch (error) {
      Logger.error('DIConfig', `服务注册失败: ${(error as Error).message}`);
      throw error;
    }
  }
  
  /**
   * 注册基础服务
   */
  private registerBaseServices(): void {
    // Logger 已经是单例，直接注册实例
    this.container.registerInstance('Logger', Logger);
    
    // 注册 APIKeyManager (懒加载)
    this.container.registerSingleton<IAPIKeyManager>(
      'APIKeyManager',
      () => {
        const { APIKeyManager } = require('../utils/APIKeyManager');
        return new APIKeyManager();
      }
    );
  }
  
  /**
   * 注册中间层服务
   */
  private registerMiddleServices(): void {
    // 注册 DirectAPIService
    this.container.registerSingleton<IDirectAPIService>(
      'DirectAPIService',
      () => {
        const { DirectAPIService } = require('../services/DirectAPIService');
        return new DirectAPIService();
      },
      ['APIKeyManager'] // 依赖
    );
    
    // 注册 ApiService
    this.container.registerSingleton<IApiService>(
      'ApiService',
      () => {
        const { ApiService } = require('../services/ApiService');
        return new ApiService();
      }
    );
  }
  
  /**
   * 注册高层服务
   */
  private registerHighLevelServices(): void {
    // 注册 APIManager
    this.container.registerSingleton<IAPIManager>(
      'APIManager',
      () => {
        const { APIManager } = require('../services/APIManager');
        
        // 从容器获取依赖
        const directApiService = this.container.get<IDirectAPIService>('DirectAPIService');
        const apiService = this.container.get<IApiService>('ApiService');
        const apiKeyManager = this.container.get<IAPIKeyManager>('APIKeyManager');
        
        return new APIManager(directApiService, apiService, apiKeyManager);
      },
      ['DirectAPIService', 'ApiService', 'APIKeyManager'] // 依赖
    );
  }
  
  /**
   * 注册自定义服务工厂
   */
  registerServiceFactory<T>(key: string, factory: IServiceFactory<T>): void {
    this.container.registerSingleton<T>(
      key,
      () => factory.create()
    );
  }
  
  /**
   * 解析服务（带有错误处理）
   */
  resolveService<T>(key: string): T {
    try {
      return this.container.get<T>(key);
    } catch (error) {
      Logger.error('DIConfig', `解析服务 '${key}' 失败: ${(error as Error).message}`);
      throw error;
    }
  }
  
  /**
   * 安全解析服务（不会抛出异常）
   */
  resolveServiceSafe<T>(key: string): T | null {
    try {
      return this.container.get<T>(key);
    } catch (error) {
      Logger.warn('DIConfig', `安全解析服务 '${key}' 失败: ${(error as Error).message}`);
      return null;
    }
  }
  
  /**
   * 检查服务是否可用
   */
  isServiceAvailable(key: string): boolean {
    return this.container.has(key);
  }
  
  /**
   * 获取所有已注册的服务
   */
  getRegisteredServices(): string[] {
    return this.container.getRegisteredServices();
  }
  
  /**
   * 清空容器（主要用于测试）
   */
  clear(): void {
    this.container.clear();
  }
  
  /**
   * 重新注册所有服务
   */
  reinitialize(): void {
    this.clear();
    this.registerServices();
  }
}

/**
 * 便捷的服务解析函数
 */
export function resolveService<T>(key: string): T {
  return DIConfig.getInstance().resolveService<T>(key);
}

/**
 * 安全的服务解析函数
 */
export function resolveServiceSafe<T>(key: string): T | null {
  return DIConfig.getInstance().resolveServiceSafe<T>(key);
}

/**
 * 获取容器实例
 */
export function getContainer(): DIContainer {
  return DIConfig.getInstance().getContainer();
}