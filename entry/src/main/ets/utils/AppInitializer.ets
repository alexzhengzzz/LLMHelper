import { Logger } from './Logger';
import { AppStorage } from './AppStorage';

/**
 * 应用初始化管理器
 * 负责在应用启动时进行必要的初始化工作
 */
export class AppInitializer {
  private static initialized: boolean = false;
  private static initializationPromise: Promise<void> | null = null;

  /**
   * 初始化应用
   */
  static async initialize(): Promise<void> {
    if (AppInitializer.initialized) {
      Logger.debug('AppInitializer', '应用已经初始化');
      return;
    }

    if (AppInitializer.initializationPromise) {
      Logger.debug('AppInitializer', '应用正在初始化中，等待完成');
      return AppInitializer.initializationPromise;
    }

    AppInitializer.initializationPromise = AppInitializer.performInitialization();
    return AppInitializer.initializationPromise;
  }

  /**
   * 执行初始化操作
   */
  private static async performInitialization(): Promise<void> {
    try {
      Logger.info('AppInitializer', '=== 开始初始化应用 ===');

      // 1. 初始化存储系统
      await AppInitializer.initializeStorage();

      // 2. 初始化默认系统提示词
      await AppInitializer.initializeDefaultPrompts();

      // 3. 检查和清理过期配置
      await AppInitializer.cleanupExpiredConfigs();

      AppInitializer.initialized = true;
      Logger.info('AppInitializer', '✅ 应用初始化完成');
    } catch (e) {
      Logger.error('AppInitializer', `❌ 应用初始化失败: ${e}`);
      AppInitializer.initializationPromise = null;
      throw new Error(e)
    }
  }

  /**
   * 初始化存储系统
   */
  private static async initializeStorage(): Promise<void> {
    try {
      Logger.info('AppInitializer', '初始化存储系统');
      await AppStorage.getStorageAsync();
      Logger.info('AppInitializer', '存储系统初始化成功');
    } catch (e) {
      Logger.error('AppInitializer', `存储系统初始化失败: ${e}`);
      throw new Error(`Storage initialization failed: ${e}`);
    }
  }

  /**
   * 初始化默认系统提示词
   */
  private static async initializeDefaultPrompts(): Promise<void> {
    try {
      Logger.info('AppInitializer', '初始化默认系统提示词');
      await AppStorage.initializeDefaultPrompts();
      Logger.info('AppInitializer', '默认系统提示词初始化成功');
    } catch (e) {
      Logger.error('AppInitializer', `默认系统提示词初始化失败: ${e}`);
      // 这个不是致命错误，可以继续
    }
  }

  /**
   * 清理过期配置
   */
  private static async cleanupExpiredConfigs(): Promise<void> {
    try {
      Logger.info('AppInitializer', '检查过期配置');

      // 检查模型配置是否过期
      await AppStorage.isModelConfigExpired();

      Logger.info('AppInitializer', '过期配置检查完成');
    } catch (e) {
      Logger.error('AppInitializer', `过期配置检查失败: ${e}`);
      // 这个不是致命错误，可以继续
    }
  }

  /**
   * 检查应用是否已初始化
   */
  static isInitialized(): boolean {
    return AppInitializer.initialized;
  }

  /**
   * 重置初始化状态（用于测试）
   */
  static resetInitialization(): void {
    AppInitializer.initialized = false;
    AppInitializer.initializationPromise = null;
    Logger.debug('AppInitializer', '初始化状态已重置');
  }

  /**
   * 安全执行存储操作
   * 如果应用未初始化，会先进行初始化
   */
  static async safeStorageOperation<T>(operation: () => Promise<T>): Promise<T> {
    try {
      if (!AppInitializer.initialized) {
        Logger.debug('AppInitializer', '检测到未初始化，先进行初始化');
        await AppInitializer.initialize();
      }
      return await operation();
    } catch (e) {
      Logger.error('AppInitializer', `存储操作失败: ${e}`);
      throw new Error(e)
    }
  }
}