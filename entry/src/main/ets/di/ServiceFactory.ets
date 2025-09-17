/**
 * 服务工厂 - 负责创建和管理服务实例
 * 提供统一的服务创建接口，支持依赖注入
 */

import { DIContainer } from './DIContainer';
import { IDirectAPIService, IApiService, IAPIKeyManager, IAPIManager, IServiceFactory } from './ServiceInterfaces';
import { Logger } from '../utils/Logger';

/**
 * APIManager 服务工厂
 */
class APIManagerFactory implements IServiceFactory<IAPIManager> {
  private container: DIContainer;
  
  constructor(container: DIContainer) {
    this.container = container;
  }
  
  create(): IAPIManager {
    const directApiService = this.container.get<IDirectAPIService>('DirectAPIService');
    const apiService = this.container.get<IApiService>('ApiService');
    const apiKeyManager = this.container.get<IAPIKeyManager>('APIKeyManager');
    
    // 使用动态导入来避免循环依赖
    const { APIManager } = require('../services/APIManager');
    return new APIManager(directApiService, apiService, apiKeyManager);
  }
  
  getServiceType(): string {
    return 'APIManager';
  }
}

/**
 * DirectAPIService 服务工厂
 */
class DirectAPIServiceFactory implements IServiceFactory<IDirectAPIService> {
  create(): IDirectAPIService {
    const { DirectAPIService } = require('../services/DirectAPIService');
    return new DirectAPIService();
  }
  
  getServiceType(): string {
    return 'DirectAPIService';
  }
}

/**
 * ApiService 服务工厂
 */
class ApiServiceFactory implements IServiceFactory<IApiService> {
  create(): IApiService {
    const { ApiService } = require('../services/ApiService');
    return new ApiService();
  }
  
  getServiceType(): string {
    return 'ApiService';
  }
}

/**
 * APIKeyManager 服务工厂
 */
class APIKeyManagerFactory implements IServiceFactory<IAPIKeyManager> {
  create(): IAPIKeyManager {
    const { APIKeyManager } = require('../utils/APIKeyManager');
    return APIKeyManager.getInstance();
  }
  
  getServiceType(): string {
    return 'APIKeyManager';
  }
}

/**
 * 服务工厂管理器
 */
export class ServiceFactoryManager {
  private container: DIContainer;
  private factories: Map<string, IServiceFactory<any>> = new Map();
  
  constructor(container: DIContainer) {
    this.container = container;
    this.registerFactories();
  }
  
  /**
   * 注册所有服务工厂
   */
  private registerFactories(): void {
    // 注册各个服务的工厂
    this.factories.set('APIManager', new APIManagerFactory(this.container));
    this.factories.set('DirectAPIService', new DirectAPIServiceFactory());
    this.factories.set('ApiService', new ApiServiceFactory());
    this.factories.set('APIKeyManager', new APIKeyManagerFactory());
  }
  
  /**
   * 获取服务工厂
   */
  getFactory<T>(serviceType: string): IServiceFactory<T> | null {
    return this.factories.get(serviceType) || null;
  }
  
  /**
   * 使用工厂创建服务
   */
  createService<T>(serviceType: string): T | null {
    const factory = this.getFactory<T>(serviceType);
    return factory ? factory.create() : null;
  }
  
  /**
   * 注册自定义工厂
   */
  registerFactory<T>(serviceType: string, factory: IServiceFactory<T>): void {
    this.factories.set(serviceType, factory);
    Logger.info('ServiceFactoryManager', `已注册服务工厂: ${serviceType}`);
  }
  
  /**
   * 获取所有已注册的工厂类型
   */
  getRegisteredFactoryTypes(): string[] {
    return Array.from(this.factories.keys());
  }
}

/**
 * 便捷的服务创建函数
 */
export function createServiceWithFactory<T>(serviceType: string, container: DIContainer): T | null {
  const factoryManager = new ServiceFactoryManager(container);
  return factoryManager.createService<T>(serviceType);
}