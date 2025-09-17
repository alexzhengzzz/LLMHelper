import { common } from '@kit.AbilityKit';

/**
 * 应用上下文管理器
 */
export class AppContext {
  private static instance: AppContext;
  private context?: common.UIAbilityContext;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): AppContext {
    if (!AppContext.instance) {
      AppContext.instance = new AppContext();
    }
    return AppContext.instance;
  }

  /**
   * 设置应用上下文
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 获取应用上下文
   */
  getContext(): common.UIAbilityContext | undefined {
    return this.context;
  }

  /**
   * 检查上下文是否已设置
   */
  hasContext(): boolean {
    return this.context !== undefined;
  }
}