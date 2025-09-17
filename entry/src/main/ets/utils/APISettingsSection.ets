import { StorageManager } from '../utils/AppStorage';
import { APIManager, APIMode } from '../services/APIManager';
import { Logger } from '../utils/Logger';

export interface APISettingsItem {
  title: string;
  subtitle: string;
  type: 'switch' | 'button';
  value?: boolean;
}

export interface APISettings {
  currentAPIMode: APIMode;
  isInitialized: boolean;
}

/**
 * API设置管理器
 */
export class APISettingsSection {
  private apiManager: APIManager = APIManager.getInstance();
  private settings: APISettings = {
    currentAPIMode: APIMode.DIRECT_CALL,
    isInitialized: false
  };

  /**
   * 初始化API设置
   */
  async initialize(): Promise<void> {
    Logger.info('APISettingsSection', '初始化API设置');

    try {
      // 加载API调用模式（仅用于显示，不执行任何同步操作）
      const apiModeStr = await StorageManager.getAPIMode();
      const storedMode = apiModeStr === 'direct_call' ? APIMode.DIRECT_CALL : APIMode.SERVER_PROXY;

      // 只更新UI显示状态，不触发任何模式切换或同步操作
      this.settings.currentAPIMode = storedMode;
      Logger.info('APISettingsSection', `API调用模式显示状态已加载: ${this.settings.currentAPIMode}，设置页面不执行模式同步`);

      // 设置初始化完成标记
      this.settings.isInitialized = true;
      Logger.info('APISettingsSection', 'API设置初始化完成');
    } catch (error) {
      Logger.error('APISettingsSection', `初始化API设置失败: ${error}`);
      throw error;
    }
  }

  /**
   * 获取设置项列表
   */
  getSettingsItems(): APISettingsItem[] {
    return [
      {
        title: 'API调用模式',
        subtitle: APIManager.getModeDescription(this.settings.currentAPIMode),
        type: 'switch',
        value: this.settings.currentAPIMode === APIMode.DIRECT_CALL
      },
      {
        title: 'API密钥管理',
        subtitle: '直连模式密钥配置',
        type: 'button'
      },
      {
        title: '提示词管理',
        subtitle: '系统提示词模板',
        type: 'button'
      }
    ];
  }

  /**
   * 处理API模式切换
   * @param isDirectCall 是否为直连模式
   * @param showDialog 是否显示切换提示对话框，默认false（用于区分手动切换和页面加载）
   */
  async handleAPIModeChange(isDirectCall: boolean, showDialog: boolean = false): Promise<void> {
    try {
      const newMode = isDirectCall ? APIMode.DIRECT_CALL : APIMode.SERVER_PROXY;

      // 如果新模式与当前模式相同，不执行任何操作
      if (newMode === this.settings.currentAPIMode) {
        Logger.info('APISettingsSection', `API模式未发生变化 (${newMode})，跳过切换操作`);
        return;
      }

      Logger.info('APISettingsSection', `切换API调用模式: ${this.settings.currentAPIMode} -> ${newMode}`);

      // 更新本地状态
      this.settings.currentAPIMode = newMode;

      // 设置API管理器模式
      await this.apiManager.setAPIMode(newMode);

      Logger.info('APISettingsSection', `API调用模式切换完成: ${newMode}`);

      // 只在手动切换时显示切换提示
      if (showDialog) {
        this.showModeChangeDialog(newMode);
      }

    } catch (error) {
      Logger.error('APISettingsSection', `API模式切换失败: ${error}`);

      // 切换失败，恢复原状态
      this.settings.currentAPIMode = this.settings.currentAPIMode === APIMode.DIRECT_CALL ?
        APIMode.SERVER_PROXY : APIMode.DIRECT_CALL;

      this.showErrorDialog(error as Error);
    }
  }

  /**
   * 显示模式切换成功对话框
   */
  private showModeChangeDialog(newMode: APIMode): void {
    // 使用全局AlertDialog显示切换成功提示
    // 注意：这里不直接调用AlertDialog，让调用方处理UI显示
    Logger.info('APISettingsSection', `API模式切换成功: ${newMode}`);
  }

  /**
   * 显示错误对话框
   */
  private showErrorDialog(error: Error): void {
    // 使用全局AlertDialog显示错误提示
    // 注意：这里不直接调用AlertDialog，让调用方处理UI显示
    Logger.error('APISettingsSection', `API模式切换失败: ${error.message}`);
  }

  /**
   * 处理按钮点击
   */
  handleButtonClick(title: string): void {
    Logger.info('APISettingsSection', `处理按钮点击: ${title}`);

    switch (title) {
      case 'API密钥管理':
        this.navigateToAPIKeyManager();
        break;
      case '提示词管理':
        this.navigateToPromptManager();
        break;
      default:
        Logger.warn('APISettingsSection', `未知的按钮点击: ${title}`);
    }
  }

  /**
   * 导航到API密钥管理页面
   */
  private navigateToAPIKeyManager(): void {
    Logger.info('APISettingsSection', '导航到API密钥管理页面');
    // 使用router跳转，实际实现在组件中
  }

  /**
   * 导航到提示词管理页面
   */
  private navigateToPromptManager(): void {
    Logger.info('APISettingsSection', '导航到提示词管理页面');
    // 使用router跳转，实际实现在组件中
  }

  /**
   * 获取当前API模式
   */
  getCurrentAPIMode(): APIMode {
    return this.settings.currentAPIMode;
  }

  /**
   * 检查是否为直连模式
   */
  isDirectMode(): boolean {
    return this.settings.currentAPIMode === APIMode.DIRECT_CALL;
  }

  /**
   * 检查是否为服务器代理模式
   */
  isServerProxyMode(): boolean {
    return this.settings.currentAPIMode === APIMode.SERVER_PROXY;
  }

  /**
   * 获取API模式描述
   */
  getModeDescription(): string {
    return APIManager.getModeDescription(this.settings.currentAPIMode);
  }

  /**
   * 获取API模式显示名称
   */
  getModeDisplayName(): string {
    return APIManager.getModeDisplayName(this.settings.currentAPIMode);
  }

  /**
   * 检查是否已初始化
   */
  isInitialized(): boolean {
    return this.settings.isInitialized;
  }

  /**
   * 设置初始化状态
   */
  setInitialized(initialized: boolean): void {
    this.settings.isInitialized = initialized;
  }

  /**
   * 获取API管理器实例
   */
  getAPIManager(): APIManager {
    return this.apiManager;
  }

  /**
   * 获取设置项的开关值
   */
  getSwitchValue(item: APISettingsItem): boolean {
    switch (item.title) {
      case 'API调用模式':
        return this.settings.currentAPIMode === APIMode.DIRECT_CALL;
      default:
        return item.value || false;
    }
  }

  /**
   * 获取设置项的动态副标题
   */
  getDynamicSubtitle(item: APISettingsItem): string {
    switch (item.title) {
      case 'API调用模式':
        return this.getModeDescription();
      default:
        return item.subtitle || '';
    }
  }

  /**
   * 重新加载设置状态
   */
  async reloadSettings(): Promise<void> {
    try {
      Logger.info('APISettingsSection', '重新加载API设置状态');

      // 重新加载API调用模式
      const apiModeStr = await StorageManager.getAPIMode();
      const storedMode = apiModeStr === 'direct_call' ? APIMode.DIRECT_CALL : APIMode.SERVER_PROXY;

      if (this.settings.currentAPIMode !== storedMode) {
        Logger.info('APISettingsSection', `API模式已变更: ${this.settings.currentAPIMode} -> ${storedMode}`);
        this.settings.currentAPIMode = storedMode;
      } else {
        Logger.debug('APISettingsSection', `API模式未变更: ${this.settings.currentAPIMode}`);
      }
    } catch (error) {
      Logger.error('APISettingsSection', `重新加载API设置失败: ${error}`);
      throw error;
    }
  }

  /**
   * 销毁资源
   */
  destroy(): void {
    // 清理资源
    this.settings.isInitialized = false;
    Logger.info('APISettingsSection', 'API设置管理器已销毁');
  }
}