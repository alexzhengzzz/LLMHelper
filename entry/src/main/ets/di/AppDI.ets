/**
 * 应用依赖注入初始化
 * 提供统一的应用启动依赖注入配置
 */

import { DIConfig } from './DIConfig';
import { ServiceFactoryManager } from './ServiceFactory';
import { Logger } from '../utils/Logger';
import { IAPIManager, IDirectAPIService, IApiService, IAPIKeyManager } from './ServiceInterfaces';

/**
 * 应用依赖注入管理器
 */
export class AppDI {
  private static instance: AppDI;
  private diConfig: DIConfig;
  private factoryManager: ServiceFactoryManager;
  private isInitialized: boolean = false;
  
  private constructor() {
    this.diConfig = DIConfig.getInstance();
    this.factoryManager = new ServiceFactoryManager(this.diConfig.getContainer());
  }
  
  static getInstance(): AppDI {
    if (!AppDI.instance) {
      AppDI.instance = new AppDI();
    }
    return AppDI.instance;
  }
  
  /**
   * 初始化依赖注入容器
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      Logger.warn('AppDI', '依赖注入容器已经初始化');
      return;
    }
    
    try {
      Logger.info('AppDI', '开始初始化依赖注入容器');
      
      // 注册所有服务
      this.diConfig.registerServices();
      
      // 初始化核心服务
      await this.initializeCoreServices();
      
      this.isInitialized = true;
      Logger.info('AppDI', '依赖注入容器初始化完成');
      
    } catch (error) {
      Logger.error('AppDI', `依赖注入容器初始化失败: ${(error as Error).message}`);
      throw error;
    }
  }
  
  /**
   * 初始化核心服务
   */
  private async initializeCoreServices(): Promise<void> {
    try {
      // 初始化 APIKeyManager
      const apiKeyManager = this.getAPIKeyManager();
      if (!apiKeyManager.isInitialized()) {
        await apiKeyManager.initialize();
      }
      
      // 初始化 APIManager
      const apiManager = this.getAPIManager();
      await apiManager.initialize();
      
      Logger.info('AppDI', '核心服务初始化完成');
      
    } catch (error) {
      Logger.error('AppDI', `核心服务初始化失败: ${(error as Error).message}`);
      throw error;
    }
  }
  
  /**
   * 获取 APIManager 实例
   */
  getAPIManager(): IAPIManager {
    return this.diConfig.resolveService<IAPIManager>('APIManager');
  }
  
  /**
   * 获取 DirectAPIService 实例
   */
  getDirectAPIService(): IDirectAPIService {
    return this.diConfig.resolveService<IDirectAPIService>('DirectAPIService');
  }
  
  /**
   * 获取 ApiService 实例
   */
  getApiService(): IApiService {
    return this.diConfig.resolveService<IApiService>('ApiService');
  }
  
  /**
   * 获取 APIKeyManager 实例
   */
  getAPIKeyManager(): IAPIKeyManager {
    return this.diConfig.resolveService<IAPIKeyManager>('APIKeyManager');
  }
  
  /**
   * 获取任意服务实例
   */
  getService<T>(serviceName: string): T {
    return this.diConfig.resolveService<T>(serviceName);
  }
  
  /**
   * 安全获取服务实例
   */
  getServiceSafe<T>(serviceName: string): T | null {
    return this.diConfig.resolveServiceSafe<T>(serviceName);
  }
  
  /**
   * 检查服务是否可用
   */
  isServiceAvailable(serviceName: string): boolean {
    return this.diConfig.isServiceAvailable(serviceName);
  }
  
  /**
   * 获取所有已注册的服务
   */
  getRegisteredServices(): string[] {
    return this.diConfig.getRegisteredServices();
  }
  
  /**
   * 重置依赖注入容器
   */
  async reset(): Promise<void> {
    try {
      Logger.info('AppDI', '重置依赖注入容器');
      
      // 销毁现有服务
      await this.destroyServices();
      
      // 重新初始化
      this.diConfig.reinitialize();
      this.isInitialized = false;
      
      Logger.info('AppDI', '依赖注入容器重置完成');
      
    } catch (error) {
      Logger.error('AppDI', `重置依赖注入容器失败: ${(error as Error).message}`);
      throw error;
    }
  }
  
  /**
   * 销毁所有服务
   */
  private async destroyServices(): Promise<void> {
    try {
      const services = this.getRegisteredServices();
      
      // 销毁服务实例
      services.forEach(serviceName => {
        const service = this.getServiceSafe(serviceName);
        if (service && typeof (service as any).destroy === 'function') {
          try {
            (service as any).destroy();
          } catch (error) {
            Logger.warn('AppDI', `销毁服务 ${serviceName} 失败: ${(error as Error).message}`);
          }
        }
      });
      
      Logger.info('AppDI', '所有服务已销毁');
      
    } catch (error) {
      Logger.error('AppDI', `销毁服务失败: ${(error as Error).message}`);
      throw error;
    }
  }
  
  /**
   * 检查是否已初始化
   */
  isInitialized(): boolean {
    return this.isInitialized;
  }
}

/**
 * 便捷的应用依赖注入访问函数
 */
export function getAppDI(): AppDI {
  return AppDI.getInstance();
}

/**
 * 获取 APIManager 的便捷函数
 */
export function getAPIManager(): IAPIManager {
  return AppDI.getInstance().getAPIManager();
}

/**
 * 获取 DirectAPIService 的便捷函数
 */
export function getDirectAPIService(): IDirectAPIService {
  return AppDI.getInstance().getDirectAPIService();
}

/**
 * 获取 ApiService 的便捷函数
 */
export function getApiService(): IApiService {
  return AppDI.getInstance().getApiService();
}

/**
 * 获取 APIKeyManager 的便捷函数
 */
export function getAPIKeyManager(): IAPIKeyManager {
  return AppDI.getInstance().getAPIKeyManager();
}