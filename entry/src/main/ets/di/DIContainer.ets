/**
 * 依赖注入容器 - 简化版
 * 提供轻量级的依赖注入功能，支持单例和工厂模式
 */

export interface ServiceDescriptor<T> {
  instance?: T;
  factory: () => T;
  isSingleton: boolean;
  dependencies?: string[];
}

export class DIContainer {
  private services: Map<string, ServiceDescriptor<any>> = new Map();
  private resolving: Set<string> = new Set();
  
  /**
   * 注册服务（工厂函数）
   */
  register<T>(key: string, factory: () => T, isSingleton: boolean = false, dependencies?: string[]): void {
    this.services.set(key, {
      factory,
      isSingleton,
      dependencies
    });
  }
  
  /**
   * 注册单例服务
   */
  registerSingleton<T>(key: string, factory: () => T, dependencies?: string[]): void {
    this.register(key, factory, true, dependencies);
  }
  
  /**
   * 注册实例
   */
  registerInstance<T>(key: string, instance: T): void {
    this.services.set(key, {
      instance,
      factory: () => instance,
      isSingleton: true
    });
  }
  
  /**
   * 获取服务实例
   */
  get<T>(key: string): T {
    const descriptor = this.services.get(key);
    if (!descriptor) {
      throw new Error(`服务 '${key}' 未注册`);
    }
    
    // 如果是单例且已创建，直接返回
    if (descriptor.isSingleton && descriptor.instance) {
      return descriptor.instance;
    }
    
    // 检查循环依赖
    if (this.resolving.has(key)) {
      throw new Error(`检测到循环依赖: ${Array.from(this.resolving).join(' -> ')} -> ${key}`);
    }
    
    this.resolving.add(key);
    
    try {
      // 创建新实例
      const instance = descriptor.factory();
      
      // 如果是单例，缓存实例
      if (descriptor.isSingleton) {
        descriptor.instance = instance;
      }
      
      return instance;
    } finally {
      this.resolving.delete(key);
    }
  }
  
  /**
   * 检查服务是否已注册
   */
  has(key: string): boolean {
    return this.services.has(key);
  }
  
  /**
   * 移除服务
   */
  remove(key: string): void {
    this.services.delete(key);
  }
  
  /**
   * 清空容器
   */
  clear(): void {
    this.services.clear();
    this.resolving.clear();
  }
  
  /**
   * 获取所有已注册的服务名称
   */
  getRegisteredServices(): string[] {
    return Array.from(this.services.keys());
  }
  
  /**
   * 创建子容器（可选功能）
   */
  createChildContainer(): DIContainer {
    const child = new DIContainer();
    // 子容器可以继承父容器的服务（如果需要的话）
    return child;
  }
}