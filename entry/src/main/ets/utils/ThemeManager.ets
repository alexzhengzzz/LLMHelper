import { window } from '@kit.ArkUI';

/**
 * 主题管理器
 * 负责管理应用的深色/浅色模式，自动跟随系统主题
 */
export class ThemeManager {
  private static instance: ThemeManager | null = null;
  private isDarkMode: boolean = false;
  private listeners: Array<(isDark: boolean) => void> = [];
  private initialized: boolean = false;
  private immersiveMode: boolean = true;
  private immersiveListeners: Array<(isImmersive: boolean) => void> = [];

  private constructor() {}

  static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  /**
   * 初始化主题管理器
   */
  async initialize(): Promise<void> {
    if (this.initialized) {
      console.info(`ThemeManager already initialized with dark mode: ${this.isDarkMode}`);
      return;
    }
    
    try {
      // 应用当前主题
      await this.applyTheme(this.isDarkMode);
      
      this.initialized = true;
      console.info(`ThemeManager initialized with dark mode: ${this.isDarkMode}`);
    } catch (e) {
      console.error('Failed to initialize ThemeManager:', e);
    }
  }

  /**
   * 获取当前是否为深色模式
   */
  getDarkMode(): boolean {
    return this.isDarkMode;
  }

  /**
   * 更新深色模式（由系统配置变化调用）
   */
  async updateDarkMode(isDark: boolean): Promise<void> {
    try {
      this.isDarkMode = isDark;
      
      // 应用主题
      await this.applyTheme(isDark);
      
      // 通知监听器
      this.notifyListeners(isDark);
      
      console.info(`Theme changed to: ${isDark ? 'dark' : 'light'} mode`);
    } catch (e) {
      console.error('Failed to update dark mode:', e);
    }
  }

  /**
   * 应用主题到系统
   */
  private async applyTheme(isDark: boolean): Promise<void> {
    try {
      // 获取主窗口
      const windowClass = await window.getLastWindow(getContext());
      
      // 设置系统栏主题
      if (isDark) {
        await windowClass.setWindowSystemBarProperties({
          statusBarColor: '#1E1E1E',
          navigationBarColor: '#1E1E1E',
          statusBarContentColor: '#FFFFFF',
          navigationBarContentColor: '#FFFFFF'
        });
      } else {
        await windowClass.setWindowSystemBarProperties({
          statusBarColor: '#FFFFFF',
          navigationBarColor: '#FFFFFF', 
          statusBarContentColor: '#000000',
          navigationBarContentColor: '#000000'
        });
      }

      console.info(`Applied ${isDark ? 'dark' : 'light'} theme to system bars`);
    } catch (e) {
      console.error('Failed to apply theme to system:', e);
    }
  }

  /**
   * 添加主题变更监听器
   */
  addThemeListener(listener: (isDark: boolean) => void): void {
    this.listeners.push(listener);
  }

  /**
   * 移除主题变更监听器
   */
  removeThemeListener(listener: (isDark: boolean) => void): void {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  /**
   * 通知所有监听器主题发生了变更
   */
  private notifyListeners(isDark: boolean): void {
    this.listeners.forEach(listener => {
      try {
        listener(isDark);
      } catch (e) {
        console.error('Theme listener error:', e);
      }
    });
  }

  /**
   * 获取当前主题的颜色资源前缀
   */
  getColorResourcePrefix(): string {
    return this.isDarkMode ? 'app.color' : 'app.color';
  }

  /**
   * 获取当前是否为沉浸式模式
   */
  getImmersiveMode(): boolean {
    return this.immersiveMode;
  }

  /**
   * 设置沉浸式模式
   */
  async setImmersiveMode(isImmersive: boolean): Promise<void> {
    try {
      this.immersiveMode = isImmersive;
      
      // 应用沉浸式模式
      await this.applyImmersiveMode(isImmersive);
      
      // 通知监听器
      this.notifyImmersiveListeners(isImmersive);
      
      console.info(`Immersive mode changed to: ${isImmersive ? 'enabled' : 'disabled'}`);
    } catch (e) {
      console.error('Failed to set immersive mode:', e);
    }
  }

  /**
   * 应用沉浸式模式到系统
   */
  private async applyImmersiveMode(isImmersive: boolean): Promise<void> {
    try {
      // 获取主窗口
      const windowClass = await window.getLastWindow(getContext());
      
      if (isImmersive) {
        // 启用沉浸式模式
        await windowClass.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: this.isDarkMode ? '#FFFFFF' : '#000000',
          navigationBarContentColor: this.isDarkMode ? '#FFFFFF' : '#000000'
        });
        // 仅隐藏导航栏，保留状态栏
        await windowClass.setWindowSystemBarEnable(['status']); // 只保留状态栏
      } else {
        // 禁用沉浸式模式
        await windowClass.setWindowSystemBarProperties({
          statusBarColor: this.isDarkMode ? '#1E1E1E' : '#FFFFFF',
          navigationBarColor: this.isDarkMode ? '#1E1E1E' : '#FFFFFF',
          statusBarContentColor: this.isDarkMode ? '#FFFFFF' : '#000000',
          navigationBarContentColor: this.isDarkMode ? '#FFFFFF' : '#000000'
        });
        // 显示系统栏
        await windowClass.setWindowSystemBarEnable(['status', 'navigation']);
      }

      console.info(`Applied immersive mode: ${isImmersive ? 'enabled' : 'disabled'}`);
    } catch (e) {
      console.error('Failed to apply immersive mode:', e);
    }
  }

  /**
   * 添加沉浸式模式变更监听器
   */
  addImmersiveListener(listener: (isImmersive: boolean) => void): void {
    this.immersiveListeners.push(listener);
  }

  /**
   * 移除沉浸式模式变更监听器
   */
  removeImmersiveListener(listener: (isImmersive: boolean) => void): void {
    const index = this.immersiveListeners.indexOf(listener);
    if (index > -1) {
      this.immersiveListeners.splice(index, 1);
    }
  }

  /**
   * 通知所有沉浸式模式监听器
   */
  private notifyImmersiveListeners(isImmersive: boolean): void {
    this.immersiveListeners.forEach(listener => {
      try {
        listener(isImmersive);
      } catch (e) {
        console.error('Immersive mode listener error:', e);
      }
    });
  }

  /**
   * 销毁主题管理器
   */
  destroy(): void {
    this.listeners = [];
    this.immersiveListeners = [];
  }
}