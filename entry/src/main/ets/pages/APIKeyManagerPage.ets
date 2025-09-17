/**
 * API密钥管理页面
 * 管理直连模式的API密钥配置
 */

import { router } from '@kit.ArkUI';
import { APIKeyManager } from '../utils/APIKeyManager';
import { 
  APIKeyConfig, 
  ConnectionStatus, 
  ProviderInfo, 
  SUPPORTED_PROVIDERS,
  APIKeyManagerEvent
} from '../types/APIKeyTypes';
import { AIProvider } from '../types/APITypes';
import { Logger } from '../utils/Logger';
import { ThemeManager } from '../utils/ThemeManager';

/**
 * 厂商配置卡片参数接口
 */
interface ProviderConfigCardParams {
  config: APIKeyConfig;
  status: ConnectionStatus;
  providerInfo: ProviderInfo | undefined;
  isTesting: boolean;
  onEdit: () => void;
  onTest: () => void;
  onToggleEnabled: (enabled: boolean) => void;
  getConnectionStatusIcon: (s: ConnectionStatus) => string;
  getConnectionStatusText: (s: ConnectionStatus) => string;
  getConnectionStatusColor: (s: ConnectionStatus) => string;
}

@Entry
@ComponentV2
struct APIKeyManagerPage {
  @Local apiKeyManager: APIKeyManager = APIKeyManager.getInstance();
  @Local configs: Map<AIProvider, APIKeyConfig> = new Map();
  @Local isLoading: boolean = true;
  @Local testingProvider: AIProvider | null = null;
  @Local showDialog: boolean = false;
  @Local editingProvider: AIProvider | null = null;
  @Local editingApiKey: string = '';
  @Local showApiKey: boolean = false;
  @Local connectionStatuses: Map<AIProvider, ConnectionStatus> = new Map();
  @Local themeManager: ThemeManager = ThemeManager.getInstance();
  @Local isDarkMode: boolean = false;
  @Local statusBarHeight: number = 44; // 状态栏高度
  
  private listenerId: string = 'APIKeyManagerPage';

  async aboutToAppear(): Promise<void> {
    Logger.info('APIKeyManagerPage', '页面初始化');
    
    // 初始化主题管理器
    await this.themeManager.initialize();
    this.isDarkMode = this.themeManager.getDarkMode();
    
    // 添加主题变更监听器
    this.themeManager.addThemeListener((isDark: boolean) => {
      this.isDarkMode = isDark;
    });
    
    try {
      // 初始化API密钥管理器
      await this.apiKeyManager.initialize();
      
      // 添加事件监听器
      this.apiKeyManager.addListener(this.listenerId, (event: APIKeyManagerEvent) => this.handleAPIKeyEvent(event));
      
      // 加载配置
      await this.loadConfigs();
      
      this.isLoading = false;
      Logger.info('APIKeyManagerPage', '页面初始化完成');
    } catch (error) {
      Logger.error('APIKeyManagerPage', `页面初始化失败: ${error}`);
      this.isLoading = false;
    }
  }

  aboutToDisappear(): void {
    Logger.info('APIKeyManagerPage', '页面销毁');
    
    // 移除事件监听器
    this.apiKeyManager.removeListener(this.listenerId);
    
    // 移除主题监听器
    this.themeManager.removeThemeListener((isDark: boolean) => {
      this.isDarkMode = isDark;
    });
  }

  /**
   * 处理API密钥管理器事件
   */
  private handleAPIKeyEvent(event: APIKeyManagerEvent): void {
    Logger.info('APIKeyManagerPage', `收到事件: ${JSON.stringify(event)}`);
    
    switch (event.type) {
      case 'config_updated':
      case 'connection_tested':
      case 'provider_enabled':
      case 'provider_disabled':
      case 'all_configs_loaded':
        this.loadConfigs();
        break;
    }
  }

  /**
   * 加载配置
   */
  private async loadConfigs(): Promise<void> {
    try {
      this.configs = this.apiKeyManager.getAllConfigs();
      
      // 更新连接状态
      this.configs.forEach((config, provider) => {
        this.connectionStatuses.set(provider, this.apiKeyManager.getConnectionStatus(provider));
      });
      
      Logger.info('APIKeyManagerPage', `加载了 ${this.configs.size} 个厂商配置`);
    } catch (error) {
      Logger.error('APIKeyManagerPage', `加载配置失败: ${error}`);
    }
  }

  /**
   * 返回上一页
   */
  onBackPress(): boolean | void {
    router.back();
    return true;
  }

  /**
   * 显示API密钥编辑对话框
   */
  private showEditDialog(provider: AIProvider): void {
    const config = this.configs.get(provider);
    if (config) {
      this.editingProvider = provider;
      this.editingApiKey = config.apiKey;
      this.showApiKey = false;
      this.showDialog = true;
    }
  }

  /**
   * 隐藏编辑对话框
   */
  private hideEditDialog(): void {
    this.showDialog = false;
    this.editingProvider = null;
    this.editingApiKey = '';
    this.showApiKey = false;
  }

  /**
   * 保存API密钥
   */
  private async saveApiKey(): Promise<void> {
    if (!this.editingProvider) {
      return;
    }

    try {
      await this.apiKeyManager.updateApiKey(this.editingProvider, this.editingApiKey);
      this.hideEditDialog();
      
      // 如果密钥不为空，自动测试连接
      if (this.editingApiKey.trim().length > 0) {
        await this.testConnection(this.editingProvider);
      }
    } catch (error) {
      Logger.error('APIKeyManagerPage', `保存API密钥失败: ${error}`);
      // 可以在这里显示错误提示
    }
  }

  /**
   * 测试连接
   */
  private async testConnection(provider: AIProvider): Promise<void> {
    try {
      this.testingProvider = provider;
      await this.apiKeyManager.testConnection(provider);
    } catch (error) {
      Logger.error('APIKeyManagerPage', `测试连接失败: ${error}`);
    } finally {
      this.testingProvider = null;
    }
  }

  /**
   * 测试所有连接
   */
  private async testAllConnections(): Promise<void> {
    try {
      await this.apiKeyManager.testAllConnections();
    } catch (error) {
      Logger.error('APIKeyManagerPage', `测试所有连接失败: ${error}`);
    }
  }

  /**
   * 启用/禁用厂商
   */
  private async toggleProviderEnabled(provider: AIProvider, enabled: boolean): Promise<void> {
    try {
      await this.apiKeyManager.setProviderEnabled(provider, enabled);
    } catch (error) {
      Logger.error('APIKeyManagerPage', `切换厂商状态失败: ${error}`);
    }
  }

  /**
   * 获取连接状态图标
   */
  private getConnectionStatusIcon(status: ConnectionStatus): string {
    switch (status) {
      case ConnectionStatus.CONNECTED:
        return '✅';
      case ConnectionStatus.DISCONNECTED:
        return '⚪';
      case ConnectionStatus.ERROR:
        return '❌';
      case ConnectionStatus.TESTING:
        return '⏳';
      default:
        return '❓';
    }
  }

  /**
   * 获取连接状态文本
   */
  private getConnectionStatusText(status: ConnectionStatus): string {
    switch (status) {
      case ConnectionStatus.CONNECTED:
        return '已连接';
      case ConnectionStatus.DISCONNECTED:
        return '未配置';
      case ConnectionStatus.ERROR:
        return '连接失败';
      case ConnectionStatus.TESTING:
        return '测试中...';
      default:
        return '未知状态';
    }
  }

  /**
   * 获取连接状态颜色
   */
  private getConnectionStatusColor(status: ConnectionStatus): string {
    switch (status) {
      case ConnectionStatus.CONNECTED:
        return '#4CAF50';
      case ConnectionStatus.DISCONNECTED:
        return '#9E9E9E';
      case ConnectionStatus.ERROR:
        return '#F44336';
      case ConnectionStatus.TESTING:
        return '#FF9800';
      default:
        return '#9E9E9E';
    }
  }

  /**
   * 获取厂商名称
   */
  private getProviderName(provider: AIProvider): string {
    const providerInfo = SUPPORTED_PROVIDERS.find(p => p.provider === provider);
    return providerInfo ? providerInfo.name : '未知厂商';
  }

  /**
   * 获取厂商描述
   */
  private getProviderDescription(provider: AIProvider): string {
    const providerInfo = SUPPORTED_PROVIDERS.find(p => p.provider === provider);
    return providerInfo ? providerInfo.description : '暂无描述';
  }

  /**
   * 获取厂商密钥格式
   */
  private getProviderKeyFormat(provider: AIProvider): string {
    const providerInfo = SUPPORTED_PROVIDERS.find(p => p.provider === provider);
    return providerInfo ? providerInfo.keyFormat : '未知格式';
  }

  /**
   * 获取厂商图标
   */
  private getProviderIcon(provider: AIProvider): string {
    switch (provider) {
      case AIProvider.SILICONFLOW:
        return '🤖';
      case AIProvider.GEMINI:
        return '🌍';
      case AIProvider.GLM:
        return '✨';
      default:
        return '🗿';
    }
  }

  /**
   * 获取厂商主题色
   */
  private getProviderColor(provider: AIProvider): string {
    switch (provider) {
      case AIProvider.SILICONFLOW:
        return '#667eea';
      case AIProvider.GEMINI:
        return '#4285F4';
      case AIProvider.GLM:
        return '#7C4DFF';
      default:
        return '#9E9E9E';
    }
  }

  /**
   * 现代化导航栏
   */
  @Builder
  buildNavigationBar() {
    Row() {
      // 现代化返回按钮
      Button() {
        Row() {
          Text('←')
            .fontSize(18)
            .fontColor($r('app.color.text_primary'))
            .margin({ right: 4 })
          Text('返回')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(VerticalAlign.Center)
      }
      .height(40)
      .padding({ left: 8, right: 12 })
      .backgroundColor(Color.Transparent)
      .borderRadius(20)
      .onClick(() => {
        this.onBackPress();
      })

      Blank()

      Text('API密钥管理')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Blank()

      // 占位按钮保持居中对齐
      Button()
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .visibility(Visibility.Hidden)
    }
    .width('100%')
    .height(64)
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.surface_color'))
    .border({
      width: { bottom: 1 },
      color: $r('app.color.border_color')
    })
  }

  /**
   * 加载状态
   */
  @Builder
  buildLoadingState() {
    Column() {
      LoadingProgress()
        .width(60)
        .height(60)
        .color($r('app.color.primary_color'))
        .margin({ bottom: 24 })

      Text('正在加载配置...')
        .fontSize(18)
        .fontWeight(500)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })
      
      Text('请稍候，正在初始化API配置')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
    .margin({ top: 60 })
  }

  /**
   * 主要内容区域
   */
  @Builder
  buildContent() {
    Scroll() {
      Column() {
        // 页面标题和描述
        Column() {
          Text('配置AI服务')
            .fontSize(24)
            .fontWeight(700)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: 8 })
            .textAlign(TextAlign.Start)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ top: 8, bottom: 24 })

        // 厂商配置列表
        ForEach(Array.from(this.configs.entries()), (item: [AIProvider, APIKeyConfig]) => {
          this.ProviderConfigCard({
            config: item[1],
            status: this.connectionStatuses.get(item[0]) || ConnectionStatus.UNKNOWN,
            providerInfo: SUPPORTED_PROVIDERS.find(p => p.provider === item[0]),
            isTesting: this.testingProvider === item[0],
            onEdit: () => this.showEditDialog(item[0]),
            onTest: () => this.testConnection(item[0]),
            onToggleEnabled: (enabled: boolean) => this.toggleProviderEnabled(item[0], enabled),
            getConnectionStatusIcon: (s: ConnectionStatus) => this.getConnectionStatusIcon(s),
            getConnectionStatusText: (s: ConnectionStatus) => this.getConnectionStatusText(s),
            getConnectionStatusColor: (s: ConnectionStatus) => this.getConnectionStatusColor(s)
          });
        });

        // 测试所有连接按钮
        Button() {
          Row() {
            if (this.apiKeyManager.isTesting()) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color(Color.White)
                .margin({ right: 8 })
            }
            
            Text(this.apiKeyManager.isTesting() ? '测试中...' : '测试所有连接')
              .fontSize(16)
              .fontWeight(500)
              .fontColor(Color.White)
          }
        }
        .width('100%')
        .height(52)
        .borderRadius(26)
        .margin({ top: 32, bottom: 24 })
        .enabled(!this.apiKeyManager.isTesting())
        .backgroundColor(this.apiKeyManager.isTesting() ? $r('app.color.text_secondary') : $r('app.color.primary_color'))
        .shadow({
          radius: 12,
          color: this.apiKeyManager.isTesting() ? 'rgba(0, 0, 0, 0.1)' : $r('app.color.primary_color_20'),
          offsetY: 4
        })
        .onClick(() => this.testAllConnections())

        // 帮助信息
        this.HelpSection()
      }
      .padding({ left: 20, right: 20, top: 0, bottom: 20 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏 - 添加状态栏高度避让
        Column() {
          this.buildNavigationBar()
        }
        .margin({ top: this.statusBarHeight })

        // 主要内容区域
        if (this.isLoading) {
          this.buildLoadingState()
        } else {
          this.buildContent()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_color'))

      // 蒙版层
      if (this.showDialog) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeManager.getDarkMode() ? 'rgba(0, 0, 0, 0.7)' : 'rgba(0, 0, 0, 0.5)')
          .onClick(() => this.hideEditDialog())
      }

      // 编辑对话框
      if (this.showDialog) {
        this.APIKeyEditDialog()
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 厂商配置卡片组件
   */
  @Builder
  ProviderConfigCard(params: ProviderConfigCardParams) {
    Column() {
      // 厂商信息
      Row() {
        Column() {
          Text(params.config.displayName)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .alignSelf(ItemAlign.Start)

          Text(params.config.description)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
            .alignSelf(ItemAlign.Start)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 状态指示器
        Row() {
          Text(params.getConnectionStatusIcon(params.status))
            .fontSize(16)
            .margin({ right: 4 })
          
          Text(params.getConnectionStatusText(params.status))
            .fontSize(12)
            .fontColor(params.getConnectionStatusColor(params.status))
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(params.getConnectionStatusColor(params.status) + '20')
        .borderRadius(12)
      }
      .width('100%')
      .margin({ bottom: 12 })

      // API密钥显示
      Row() {
        Text('API密钥:')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width(80)

        if (params.config.apiKey) {
          Text(params.config.apiKey.substring(0, 8) + '...' + params.config.apiKey.substring(params.config.apiKey.length - 4))
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        } else {
          Text('未设置')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
        }

        Button('编辑')
          .fontSize(12)
          .fontColor($r('app.color.primary_color'))
          .backgroundColor(Color.Transparent)
          .onClick(params.onEdit)
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 操作按钮
      Row() {
        Button(params.isTesting ? '测试中...' : '测试连接')
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(params.isTesting ? $r('app.color.text_secondary') : $r('app.color.success_color'))
          .layoutWeight(1)
          .borderRadius(8)
          .enabled(!params.isTesting && !!params.config.apiKey)
          .onClick(params.onTest)

        Blank()

        Toggle({ type: ToggleType.Switch, isOn: params.config.enabled })
          .onChange(params.onToggleEnabled)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .margin({ bottom: 12 })
    .shadow({
      radius: 4,
      color: this.isDarkMode ? 'rgba(0, 0, 0, 0.3)' : 'rgba(0, 0, 0, 0.1)',
      offsetY: 2
    })
  }

  /**
   * 帮助信息组件
   */
  @Builder
  HelpSection() {
    Column() {
      Text('使用说明')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 12 })

      Column() {
        Text('• 点击"编辑"按钮设置API密钥')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        Text('• 点击"测试连接"验证密钥有效性')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        Text('• 开启开关启用厂商，关闭开关禁用厂商')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        Text('• API密钥仅存储在本地，不会上传到服务器')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.primary_color_10'))
    .borderRadius(12)
    .margin({ bottom: 24 })
  }

  /**
   * 厂商信息显示组件
   */
  @Builder
  ProviderInfoDisplay(provider: AIProvider) {
    Row() {
      // 厂商图标
      Text(this.getProviderIcon(provider))
        .fontSize(32)
        .width(64)
        .height(64)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.getProviderColor(provider) + '20')
        .borderRadius(32)
        .margin({ right: 16 })
      
      Column() {
        Text(this.getProviderName(provider))
          .fontSize(20)
          .fontWeight(600)
          .fontColor($r('app.color.text_primary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        Text(this.getProviderDescription(provider))
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })
          .lineHeight(22)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(20)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .margin({ bottom: 24 })
    .border({
      width: 1,
      color: $r('app.color.border_color')
    })
  }

  /**
   * API密钥编辑对话框
   */
  @Builder
  APIKeyEditDialog() {
    Stack() {
      // 对话框内容
      Column() {
        // 厂商信息
        if (this.editingProvider) {
          this.ProviderInfoDisplay(this.editingProvider)
        }

        // API密钥输入区域
        Column() {
          Text('API密钥')
            .fontSize(16)
            .fontWeight(500)
            .fontColor($r('app.color.text_primary'))
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 12 })

          Row() {
            TextInput({ placeholder: '请输入您的API密钥', text: this.editingApiKey })
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.input_background'))
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .borderRadius(12)
              .layoutWeight(1)
              .type(this.showApiKey ? InputType.Normal : InputType.Password)
              .border({
                width: 1,
                color: $r('app.color.border_color')
              })
              .onChange((value: string) => {
                this.editingApiKey = value;
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 12 })

          Row() {
            Text('🛡️')
              .fontSize(14)
              .margin({ right: 8 })
            
            Text('密钥仅存储在本地设备，不会上传到服务器')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)
              .lineHeight(18)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .margin({ bottom: 32 })

        // 操作按钮
        Row() {
          Button('取消')
            .fontSize(16)
            .fontWeight(500)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.primary_color_10'))
            .height(48)
            .borderRadius(24)
            .layoutWeight(1)
            .margin({ right: 12 })
            .onClick(() => this.hideEditDialog())

          Button('保存密钥')
            .fontSize(16)
            .fontWeight(500)
            .fontColor(Color.White)
            .height(48)
            .borderRadius(24)
            .layoutWeight(1)
            .margin({ left: 12 })
            .backgroundColor($r('app.color.primary_color'))
            .shadow({
              radius: 8,
              color: $r('app.color.primary_color_20'),
              offsetY: 2
            })
            .onClick(() => this.saveApiKey())
        }
        .width('100%')
      }
      .width('92%')
      .constraintSize({ maxWidth: 480 })
      .padding(28)
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius(24)
      .shadow({
        radius: 24,
        color: this.isDarkMode ? 'rgba(0, 0, 0, 0.5)' : 'rgba(0, 0, 0, 0.15)',
        offsetY: 8
      })
      .border({
        width: 1,
        color: $r('app.color.border_color')
      })
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }
}