import { StorageManager } from '../utils/AppStorage';
import { AppConfigManager } from '../utils/AppConfigManager';
import { ServerConfigManager, ServerEndpoint } from '../utils/ServerConfigManager';
import { ThemeManager } from '../utils/ThemeManager';
import { Logger } from '../utils/Logger';

export interface ThemeSettingsItem {
  title: string;
  subtitle: string;
  type: 'switch' | 'button';
  value?: boolean;
}

export interface ThemeSettings {
  enableNotifications: boolean;
  useModernMessageLayout: boolean;
  currentTheme: string;
  statusBarHeight: number;
  currentServer: ServerEndpoint;
}

/**
 * 主题设置管理器
 */
export class ThemeSettingsSection {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private configManager: AppConfigManager = AppConfigManager.getInstance();
  private serverConfigManager: ServerConfigManager = ServerConfigManager.getInstance();

  private settings: ThemeSettings = {
    enableNotifications: true,
    useModernMessageLayout: false,
    currentTheme: 'light',
    statusBarHeight: 44,
    currentServer: {
      ip: 'localhost',
      port: 8080,
      protocol: 'http',
      wsProtocol: 'ws'
    }
  };

  private serverConfigListener: (config: ServerEndpoint) => void;

  constructor() {
    this.serverConfigListener = (config: ServerEndpoint) => {
      this.updateServerConfig(config);
    };
  }

  /**
   * 初始化主题设置
   */
  async initialize(): Promise<void> {
    Logger.info('ThemeSettingsSection', '初始化主题设置');

    try {
      // 加载消息布局偏好
      this.settings.useModernMessageLayout = await StorageManager.getMessageLayoutPreference();
      Logger.info('ThemeSettingsSection', `消息布局偏好加载成功: ${this.settings.useModernMessageLayout ? '现代布局' : '传统气泡'}`);

      // 加载服务器配置
      await this.serverConfigManager.initialize();
      const serverConfig = this.serverConfigManager.getCurrentServer();
      this.settings.currentServer = serverConfig;
      Logger.info('ThemeSettingsSection', `服务器配置加载成功: ${serverConfig.protocol}://${serverConfig.ip}:${serverConfig.port}`);

      // 加载当前主题
      this.settings.currentTheme = this.themeManager.getCurrentTheme();
      Logger.info('ThemeSettingsSection', `当前主题: ${this.settings.currentTheme}`);

      // 添加服务器配置变更监听器
      this.serverConfigManager.addConfigChangeListener(this.serverConfigListener);

      // 暂时使用固定状态栏高度，后续动态获取
      Logger.info('ThemeSettingsSection', '使用固定状态栏高度44vp');

    } catch (error) {
      Logger.error('ThemeSettingsSection', `初始化主题设置失败: ${error}`);
      throw error;
    }
  }

  /**
   * 获取设置项列表
   */
  getSettingsItems(): ThemeSettingsItem[] {
    return [
      {
        title: '通知',
        subtitle: '接收消息通知',
        type: 'switch',
        value: this.settings.enableNotifications
      },
      {
        title: '消息样式',
        subtitle: this.settings.useModernMessageLayout ? '现代线性布局' : '传统消息气泡',
        type: 'switch',
        value: this.settings.useModernMessageLayout
      },
      {
        title: '清除聊天记录',
        subtitle: '删除所有本地聊天消息',
        type: 'button'
      },
      {
        title: '重置模型选择',
        subtitle: '清除保存的模型选择配置',
        type: 'button'
      }
    ];
  }

  /**
   * 获取服务器设置项
   */
  getServerSettingsItems(): ThemeSettingsItem[] {
    const currentServer = this.serverConfigManager.getCurrentServer();
    return [
      {
        title: '服务器配置',
        subtitle: `${currentServer.ip}:${currentServer.port}`,
        type: 'button'
      }
    ];
  }

  /**
   * 获取关于设置项
   */
  getAboutSettingsItems(): ThemeSettingsItem[] {
    const privacyConfig = this.configManager.getPrivacyConfig();
    const developerInfo = privacyConfig.showDeveloperInfo ? privacyConfig.developerName : '';

    const settings: ThemeSettingsItem[] = [
      {
        title: '关于应用',
        subtitle: 'LLM助手应用介绍',
        type: 'button'
      },
      {
        title: '版本号',
        subtitle: 'v1.0.0',
        type: 'button'
      }
    ];

    if (privacyConfig.showDeveloperInfo) {
      settings.push({
        title: '开发者信息',
        subtitle: developerInfo,
        type: developerInfo ? 'button' : 'button'
      });
    }

    return settings;
  }

  /**
   * 更新服务器配置
   */
  private updateServerConfig(config: ServerEndpoint): void {
    Logger.info('ThemeSettingsSection', `收到服务器配置变更通知: ${config.protocol}://${config.ip}:${config.port}`);

    // 更新本地状态
    this.settings.currentServer.ip = config.ip;
    this.settings.currentServer.port = config.port;
    this.settings.currentServer.protocol = config.protocol;
    this.settings.currentServer.wsProtocol = config.wsProtocol;
    this.settings.currentServer.description = config.description;

    Logger.info('ThemeSettingsSection', `服务器配置已更新为: ${this.settings.currentServer.protocol}://${this.settings.currentServer.ip}:${this.settings.currentServer.port}`);
  }

  /**
   * 处理开关变更
   */
  async handleSwitchChange(title: string, value: boolean): Promise<void> {
    Logger.info('ThemeSettingsSection', `处理开关变更: ${title} = ${value}`);

    switch (title) {
      case '通知':
        this.settings.enableNotifications = value;
        await this.saveNotificationSetting(value);
        break;
      case '消息样式':
        this.settings.useModernMessageLayout = value;
        await this.saveMessageLayoutPreference(value);
        break;
      default:
        Logger.warn('ThemeSettingsSection', `未知的开关变更: ${title}`);
    }
  }

  /**
   * 保存通知设置
   */
  private async saveNotificationSetting(enabled: boolean): Promise<void> {
    try {
      // 保存到存储
      await StorageManager.saveNotificationSetting(enabled);
      Logger.info('ThemeSettingsSection', `通知设置已保存: ${enabled ? '启用' : '禁用'}`);
    } catch (error) {
      Logger.error('ThemeSettingsSection', `保存通知设置失败: ${error}`);
      throw error;
    }
  }

  /**
   * 保存消息布局偏好
   */
  private async saveMessageLayoutPreference(useModern: boolean): Promise<void> {
    try {
      // 异步保存到存储
      await StorageManager.saveMessageLayoutPreference(useModern);
      Logger.info('ThemeSettingsSection', `消息布局样式已保存: ${useModern ? '现代布局' : '传统气泡'}`);
    } catch (error) {
      Logger.error('ThemeSettingsSection', `保存消息布局样式失败: ${error}`);
      throw error;
    }
  }

  /**
   * 处理按钮点击
   */
  handleButtonClick(title: string): void {
    Logger.info('ThemeSettingsSection', `处理按钮点击: ${title}`);

    switch (title) {
      case '服务器配置':
        this.navigateToServerSettings();
        break;
      case '清除聊天记录':
        this.showClearHistoryDialog();
        break;
      case '重置模型选择':
        this.showClearModelConfigDialog();
        break;
      case '关于应用':
        this.showAbout();
        break;
      case '开发者信息':
        this.showDeveloperInfo();
        break;
      default:
        Logger.warn('ThemeSettingsSection', `未知的按钮点击: ${title}`);
    }
  }

  /**
   * 获取开关值
   */
  getSwitchValue(item: ThemeSettingsItem): boolean {
    switch (item.title) {
      case '通知':
        return this.settings.enableNotifications;
      case '消息样式':
        return this.settings.useModernMessageLayout;
      default:
        return item.value || false;
    }
  }

  /**
   * 获取动态副标题
   */
  getDynamicSubtitle(item: ThemeSettingsItem): string {
    switch (item.title) {
      case '消息样式':
        return this.settings.useModernMessageLayout ? '现代线性布局' : '传统消息气泡';
      default:
        return item.subtitle || '';
    }
  }

  /**
   * 重新加载设置状态
   */
  async reloadSettings(): Promise<void> {
    try {
      Logger.info('ThemeSettingsSection', '重新加载主题设置状态');

      // 重新加载消息布局偏好
      const previousLayout = this.settings.useModernMessageLayout;
      this.settings.useModernMessageLayout = await StorageManager.getMessageLayoutPreference();

      if (previousLayout !== this.settings.useModernMessageLayout) {
        Logger.info('ThemeSettingsSection', `消息布局偏好已更新: ${previousLayout ? '现代' : '传统'} -> ${this.settings.useModernMessageLayout ? '现代' : '传统'}`);
      } else {
        Logger.debug('ThemeSettingsSection', `消息布局偏好未变更: ${this.settings.useModernMessageLayout ? '现代' : '传统'}`);
      }

      // 重新加载服务器配置
      const serverConfig = this.serverConfigManager.getCurrentServer();
      this.settings.currentServer = serverConfig;
      Logger.info('ThemeSettingsSection', `重新加载服务器配置完成: ${serverConfig.protocol}://${serverConfig.ip}:${serverConfig.port}`);

    } catch (error) {
      Logger.error('ThemeSettingsSection', `重新加载主题设置失败: ${error}`);
      throw error;
    }
  }

  /**
   * 导航相关方法
   */
  private navigateToServerSettings(): void {
    Logger.info('ThemeSettingsSection', '导航到服务器设置页面');
    // 实际实现在组件中
  }

  private showClearHistoryDialog(): void {
    Logger.info('ThemeSettingsSection', '显示清除历史记录对话框');
    // 实际实现在组件中
  }

  private showClearModelConfigDialog(): void {
    Logger.info('ThemeSettingsSection', '显示清除模型配置对话框');
    // 实际实现在组件中
  }

  private showAbout(): void {
    Logger.info('ThemeSettingsSection', '显示关于信息');
    // 实际实现在组件中
  }

  private showDeveloperInfo(): void {
    Logger.info('ThemeSettingsSection', '显示开发者信息');
    // 实际实现在组件中
  }

  /**
   * 获取当前设置
   */
  getCurrentSettings(): ThemeSettings {
    return { ...this.settings };
  }

  /**
   * 检查是否启用通知
   */
  isNotificationsEnabled(): boolean {
    return this.settings.enableNotifications;
  }

  /**
   * 检查是否使用现代布局
   */
  isModernLayoutEnabled(): boolean {
    return this.settings.useModernMessageLayout;
  }

  /**
   * 获取当前主题
   */
  getCurrentTheme(): string {
    return this.settings.currentTheme;
  }

  /**
   * 获取状态栏高度
   */
  getStatusBarHeight(): number {
    return this.settings.statusBarHeight;
  }

  /**
   * 获取当前服务器配置
   */
  getCurrentServer(): ServerEndpoint {
    return { ...this.settings.currentServer };
  }

  /**
   * 销毁资源
   */
  destroy(): void {
    this.serverConfigManager.removeConfigChangeListener(this.serverConfigListener);
    Logger.info('ThemeSettingsSection', '主题设置管理器已销毁');
  }
}