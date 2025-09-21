import { FontSettings, AppStorage as StorageManager } from './AppStorage';
import { Logger } from './Logger';

/**
 * 字体管理器
 * 负责管理应用的字体设置，包括聊天字体、代码字体和字体家族
 */
export class FontManager {
  private static instance: FontManager | null = null;
  private fontSettings: FontSettings;
  private listeners: Array<(settings: FontSettings) => void> = [];
  private initialized: boolean = false;
  private storageListener: (settings: FontSettings) => void = (settings: FontSettings) => {
    this.onFontSettingsChanged(settings);
  };

  private constructor() {
    this.fontSettings = StorageManager.getDefaultFontSettings();
  }

  static getInstance(): FontManager {
    if (!FontManager.instance) {
      FontManager.instance = new FontManager();
    }
    return FontManager.instance;
  }

  /**
   * 初始化字体管理器
   */
  async initialize(): Promise<void> {
    if (this.initialized) {
      Logger.info('FontManager', `字体管理器已初始化，当前设置: ${JSON.stringify(this.fontSettings)}`);
      return;
    }

    try {
      // 从存储加载字体设置
      this.fontSettings = await StorageManager.getFontSettings();

      // 添加存储监听器
      StorageManager.addFontSettingsListener(this.storageListener);

      this.initialized = true;
      Logger.info('FontManager', `字体管理器初始化完成: ${JSON.stringify(this.fontSettings)}`);

      // 通知所有监听器
      this.notifyListeners();
    } catch (e) {
      Logger.error('FontManager', `字体管理器初始化失败: ${e}`);
      // 使用默认设置
      this.fontSettings = StorageManager.getDefaultFontSettings();
      this.initialized = true;
    }
  }

  /**
   * 获取当前字体设置
   */
  getFontSettings(): FontSettings {
    return {
      chatFontSize: this.fontSettings.chatFontSize,
      codeFontSize: this.fontSettings.codeFontSize,
      fontFamily: this.fontSettings.fontFamily,
      updatedAt: this.fontSettings.updatedAt
    };
  }

  /**
   * 获取聊天字体大小
   */
  getChatFontSize(): number {
    return this.fontSettings.chatFontSize;
  }

  /**
   * 获取代码字体大小
   */
  getCodeFontSize(): number {
    return this.fontSettings.codeFontSize;
  }

  /**
   * 获取字体家族
   */
  getFontFamily(): 'system' | 'serif' | 'monospace' | 'rounded' | 'elegant' | 'playful' | 'modern' | 'classic' {
    return this.fontSettings.fontFamily;
  }

  /**
   * 获取字体家族的CSS值
   */
  getFontFamilyCss(): string {
    switch (this.fontSettings.fontFamily) {
      case 'monospace':
        return 'Monaco, Consolas, "SF Mono", "Courier New", "Droid Sans Mono", monospace';
      case 'serif':
        return 'Georgia, "Times New Roman", "Songti SC", "Noto Serif CJK SC", serif';
      case 'rounded':
        return '"SF Pro Rounded", "PingFang SC", "Helvetica Neue", "Source Han Sans SC", Arial, sans-serif';
      case 'elegant':
        return '"Optima", "Avenir Next", "PingFang SC", "Source Han Sans SC", "Helvetica Neue", sans-serif';
      case 'playful':
        return '"Comic Sans MS", "Marker Felt", "PingFang SC", "Source Han Sans SC", "Helvetica", sans-serif';
      case 'modern':
        return '"SF Pro Display", "Roboto", "Noto Sans CJK SC", "PingFang SC", "Helvetica Neue", sans-serif';
      case 'classic':
        return '"Palatino", "Book Antiqua", "Times New Roman", "Songti SC", "Noto Serif CJK SC", serif';
      case 'system':
      default:
        return 'system-ui, -apple-system, "PingFang SC", "Source Han Sans SC", sans-serif';
    }
  }

  /**
   * 更新聊天字体大小
   */
  async updateChatFontSize(size: number): Promise<void> {
    try {
      const clampedSize = Math.max(12, Math.min(20, size));
      const updatedSettings = await StorageManager.updateFontSettings({
        chatFontSize: clampedSize
      });

      Logger.info('FontManager', `聊天字体大小已更新: ${clampedSize}px`);
      this.fontSettings = updatedSettings;
      this.notifyListeners();
    } catch (e) {
      Logger.error('FontManager', `更新聊天字体大小失败: ${e}`);
      throw new Error(`更新聊天字体大小失败: ${e}`);
    }
  }

  /**
   * 更新代码字体大小
   */
  async updateCodeFontSize(size: number): Promise<void> {
    try {
      const clampedSize = Math.max(10, Math.min(18, size));
      const updatedSettings = await StorageManager.updateFontSettings({
        codeFontSize: clampedSize
      });

      Logger.info('FontManager', `代码字体大小已更新: ${clampedSize}px`);
      this.fontSettings = updatedSettings;
      this.notifyListeners();
    } catch (e) {
      Logger.error('FontManager', `更新代码字体大小失败: ${e}`);
      throw new Error(`更新代码字体大小失败: ${e}`);
    }
  }

  /**
   * 更新字体家族
   */
  async updateFontFamily(family: 'system' | 'serif' | 'monospace' | 'rounded' | 'elegant' | 'playful' | 'modern' | 'classic'): Promise<void> {
    try {
      const updatedSettings = await StorageManager.updateFontSettings({
        fontFamily: family
      });

      Logger.info('FontManager', `字体家族已更新: ${family}`);
      this.fontSettings = updatedSettings;
      this.notifyListeners();
    } catch (e) {
      Logger.error('FontManager', `更新字体家族失败: ${e}`);
      throw new Error(`更新字体家族失败: ${e}`);
    }
  }

  /**
   * 批量更新字体设置
   */
  async updateFontSettings(updates: Partial<FontSettings>): Promise<void> {
    try {
      const updatedSettings = await StorageManager.updateFontSettings(updates);

      Logger.info('FontManager', `字体设置已批量更新: ${JSON.stringify(updates)}`);
      this.fontSettings = updatedSettings;
      this.notifyListeners();
    } catch (e) {
      Logger.error('FontManager', `批量更新字体设置失败: ${e}`);
      throw new Error(`批量更新字体设置失败: ${e}`);
    }
  }

  /**
   * 重置字体设置为默认值
   */
  async resetFontSettings(): Promise<void> {
    try {
      await StorageManager.resetFontSettings();
      this.fontSettings = StorageManager.getDefaultFontSettings();

      Logger.info('FontManager', '字体设置已重置为默认值');
      this.notifyListeners();
    } catch (e) {
      Logger.error('FontManager', `重置字体设置失败: ${e}`);
      throw new Error(`重置字体设置失败: ${e}`);
    }
  }

  /**
   * 添加字体设置变更监听器
   */
  addListener(listener: (settings: FontSettings) => void): void {
    this.listeners.push(listener);
    Logger.debug('FontManager', `添加字体设置监听器，当前监听器数量: ${this.listeners.length}`);
  }

  /**
   * 移除字体设置变更监听器
   */
  removeListener(listener: (settings: FontSettings) => void): void {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
      Logger.debug('FontManager', `移除字体设置监听器，当前监听器数量: ${this.listeners.length}`);
    }
  }

  /**
   * 通知所有监听器
   */
  private notifyListeners(): void {
    Logger.debug('FontManager', `通知 ${this.listeners.length} 个字体设置监听器`);
    this.listeners.forEach(listener => {
      try {
        listener(this.fontSettings);
      } catch (e) {
        Logger.error('FontManager', `字体设置监听器执行失败: ${e}`);
      }
    });
  }

  /**
   * 处理来自存储的字体设置变更
   */
  private onFontSettingsChanged(settings: FontSettings): void {
    Logger.debug('FontManager', `收到存储字体设置变更通知: ${JSON.stringify(settings)}`);
    this.fontSettings = settings;
    this.notifyListeners();
  }

  /**
   * 获取字体设置的显示文本
   */
  static getFontSizeDisplayText(size: number): string {
    return `${size}px`;
  }

  /**
   * 获取字体家族的显示文本
   */
  static getFontFamilyDisplayText(family: 'system' | 'serif' | 'monospace' | 'rounded' | 'elegant' | 'playful' | 'modern' | 'classic'): string {
    switch (family) {
      case 'monospace':
        return '等宽字体';
      case 'serif':
        return '衬线字体';
      case 'rounded':
        return '圆润字体';
      case 'elegant':
        return '优雅字体';
      case 'playful':
        return '活泼字体';
      case 'modern':
        return '现代字体';
      case 'classic':
        return '经典字体';
      case 'system':
      default:
        return '系统默认';
    }
  }

  /**
   * 验证字体大小是否在有效范围内
   */
  static isValidChatFontSize(size: number): boolean {
    return size >= 12 && size <= 20;
  }

  /**
   * 验证代码字体大小是否在有效范围内
   */
  static isValidCodeFontSize(size: number): boolean {
    return size >= 10 && size <= 18;
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    if (this.initialized) {
      StorageManager.removeFontSettingsListener(this.storageListener);
      this.listeners = [];
      this.initialized = false;
      Logger.info('FontManager', '字体管理器资源已清理');
    }
  }
}