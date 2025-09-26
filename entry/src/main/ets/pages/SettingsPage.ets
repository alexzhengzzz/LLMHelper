import { router } from '@kit.ArkUI';
import { Constants } from '../utils/Constants';
import { AutoTTSSettings, AvatarSettings, UserProfile, AppStorage as StorageManager } from '../utils/AppStorage';
import { UserProfileManager } from '../utils/UserProfileManager';
import { AutoTTSService } from '../services/AutoTTSService';
import { APIManager, APIMode, AIProvider } from '../services/APIManager';
import { Logger } from '../utils/Logger';
import { AppConfigManager } from '../utils/AppConfigManager';
import { ServerConfigManager, ServerEndpoint } from '../utils/ServerConfigManager';
import { ThemeManager } from '../utils/ThemeManager';
import { FontManager } from '../utils/FontManager';
import { FontSettings } from '../utils/AppStorage';
import { BasicAnimations, AnimationConfigManager } from '../animations';
import { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { MemoryManager } from '../utils/MemoryManager';
import { MemoryStats, MemoryCategoryCounts, MemoryImportanceCounts } from '../types/MemoryTypes';

interface SettingItem {
  title: string;
  subtitle: string;
  type: 'input' | 'switch' | 'info' | 'button' | 'slider' | 'avatar';
  value?: boolean;
  numValue?: number;
  minValue?: number;
  maxValue?: number;
  step?: number;
  avatarValue?: string;
  visible?: boolean;
  avatarType?: 'default' | 'emoji' | 'image';
}

interface AvatarOption {
  text: string;
  value: string;
}

/**
 * 设置页面
 */
@Entry
@ComponentV2
struct SettingsPage {
  @Local serverUrl: string = AppConfigManager.getInstance().getServerConfig().baseUrl;
  @Local enableNotifications: boolean = true;
  @Local autoTTSSettings: AutoTTSSettings = StorageManager.getDefaultAutoTTSSettings();
  @Local userAvatarType: 'default' | 'emoji' | 'image' = 'default';
  @Local userAvatarValue: string = '#4285F4';
  @Local aiAvatarType: 'default' | 'emoji' | 'image' = 'default';
  @Local aiAvatarValue: string = '#34A853';
  @Local userName: string = 'Javis用户';
  @Local userSignature: string = '让AI成为你的编程伙伴';
  @Local avatarSettingsItems: SettingItem[] = [];
  
  // 计算属性：自动生成个人资料设置项数组
  @Computed
  get computedProfileSettingsItems(): SettingItem[] {
    return [
      {
        title: '个人资料',
        subtitle: `${this.userName} • ${this.userSignature}`,
        type: 'button'
      },
      {
        title: 'AI头像', 
        subtitle: this.getAvatarDisplayText(this.aiAvatarType, this.aiAvatarValue),
        type: 'avatar',
        avatarType: this.aiAvatarType,
        avatarValue: this.aiAvatarValue
      }
    ];
  }
  @Local currentAPIMode: APIMode = APIMode.DIRECT_CALL;
  @Local isInitialized: boolean = false; // 标记页面是否已完成初始化
  @Local useModernMessageLayout: boolean = false; // 消息布局偏好
  @Local statusBarHeight: number = 44; // 状态栏高度
  @Local currentServer: ServerEndpoint = {
    ip: 'localhost',
    port: 8080,
    protocol: 'http',
    wsProtocol: 'ws'
  };
  @Local fontSettings: FontSettings = {
    chatFontSize: 16,
    codeFontSize: 14,
    fontFamily: 'system',
    updatedAt: Date.now()
  };
  private readonly PAGE_ENTER_OFFSET: number = 96;
  @Local private pageTranslateX: number = this.PAGE_ENTER_OFFSET;
  @Local private pageOpacity: number = BasicAnimations.HIDDEN_OPACITY;
  private hasPlayedEnterAnimation: boolean = false;
  private animationConfigManager: AnimationConfigManager = AnimationConfigManager.getInstance();
  private autoTTSService: AutoTTSService = AutoTTSService.getInstance();
  private apiManager: APIManager = APIManager.getInstance();
  private userProfileManager: UserProfileManager = UserProfileManager.getInstance();
  private serverConfigManager: ServerConfigManager = ServerConfigManager.getInstance();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private fontManager: FontManager = FontManager.getInstance();
  private memoryManager: MemoryManager = MemoryManager.getInstance();
  @Local private defaultCategoryCounts: MemoryCategoryCounts = {
    personal: 0,
    preference: 0,
    work: 0,
    study: 0,
    hobby: 0,
    family: 0,
    health: 0,
    custom: 0
  };

  @Local private defaultImportanceCounts: MemoryImportanceCounts = {
    low: 0,
    medium: 0,
    high: 0,
    critical: 0
  };

  @Local memoryStats: MemoryStats = {
    totalFragments: 0,
    activeFragments: 0,
    categoryCounts: this.defaultCategoryCounts,
    importanceCounts: this.defaultImportanceCounts,
    lastUpdated: 0,
    totalUsageCount: 0
  };
  private avatarListener: (settings: AvatarSettings) => void = (settings: AvatarSettings) => {
    // 更新本地状态，@Computed会自动处理后续更新
    this.aiAvatarType = settings.aiAvatarType;
    this.aiAvatarValue = settings.aiAvatarValue;
  };
  private userProfileListener: (profile: UserProfile) => void = (profile: UserProfile) => {
    this.userName = profile.userName;
    this.userSignature = profile.userSignature;
    this.userAvatarType = profile.userAvatarType;
    this.userAvatarValue = profile.userAvatarValue;
  };
  private serverConfigListener: (config: ServerEndpoint) => void = (config: ServerEndpoint) => {
    // 更新本地服务器配置状态
    Logger.info('SettingsPage', `收到服务器配置变更通知: ${config.protocol}://${config.ip}:${config.port}`);

    // 更新各个属性以确保响应性
    this.currentServer.ip = config.ip;
    this.currentServer.port = config.port;
    this.currentServer.protocol = config.protocol;
    this.currentServer.wsProtocol = config.wsProtocol;
    this.currentServer.description = config.description;

    Logger.info('SettingsPage', `服务器配置已更新为: ${this.currentServer.protocol}://${this.currentServer.ip}:${this.currentServer.port}`);
  };
  private fontSettingsListener: (settings: FontSettings) => void = (settings: FontSettings) => {
    // 更新本地字体设置状态
    Logger.info('SettingsPage', `收到字体设置变更通知: ${JSON.stringify(settings)}`);
    Logger.info('SettingsPage', `当前字体设置: ${JSON.stringify(this.fontSettings)}`);
    this.fontSettings = settings;
    Logger.info('SettingsPage', `更新后字体设置: ${JSON.stringify(this.fontSettings)}`);
  };

  async aboutToAppear(): Promise<void> {
    Logger.info('SettingsPage', 'aboutToAppear');
    this.resetEnterAnimationState();
    
    // 加载自动播报设置
    try {
      this.autoTTSSettings = await StorageManager.getAutoTTSSettings();
      Logger.info('SettingsPage', `自动播报设置加载成功: ${JSON.stringify(this.autoTTSSettings)}`);
    } catch (error) {
      Logger.error('SettingsPage', `加载自动播报设置失败: ${error}`);
    }

    // 加载记忆统计信息
    try {
      this.memoryStats = await this.memoryManager.getMemoryStats();
      Logger.info('SettingsPage', `记忆统计信息加载成功: 总计${this.memoryStats.totalFragments}个，激活${this.memoryStats.activeFragments}个`);
    } catch (error) {
      Logger.error('SettingsPage', `加载记忆统计信息失败: ${error}`);
    }

    // 初始化用户资料管理器
    try {
      await this.userProfileManager.initialize();
      const currentProfile = this.userProfileManager.getCurrentProfile();
      if (currentProfile) {
        this.userName = currentProfile.userName;
        this.userSignature = currentProfile.userSignature;
        this.userAvatarType = currentProfile.userAvatarType;
        this.userAvatarValue = currentProfile.userAvatarValue;
      }
    } catch (error) {
      Logger.error('SettingsPage', `初始化用户资料管理器失败: ${error}`);
    }

    // 加载AI头像设置
    try {
      const avatarSettings = await StorageManager.getAvatarSettings();
      this.aiAvatarType = avatarSettings.aiAvatarType;
      this.aiAvatarValue = avatarSettings.aiAvatarValue;
    } catch (error) {
      Logger.error('SettingsPage', `加载AI头像设置失败: ${error}`);
    }

    // 加载API调用模式（仅用于显示，不执行任何同步操作）
    try {
      const apiModeStr = await StorageManager.getAPIMode();
      const storedMode = apiModeStr === 'direct_call' ? APIMode.DIRECT_CALL : APIMode.SERVER_PROXY;
      
      // 只更新UI显示状态，不触发任何模式切换或同步操作
      this.currentAPIMode = storedMode;
      Logger.info('SettingsPage', `API调用模式显示状态已加载: ${this.currentAPIMode}，设置页面不执行模式同步`);
    } catch (error) {
      Logger.error('SettingsPage', `加载API调用模式显示状态失败: ${error}`);
    }

    // 加载消息布局偏好
    try {
      this.useModernMessageLayout = await StorageManager.getMessageLayoutPreference();
      Logger.info('SettingsPage', `消息布局偏好加载成功: ${this.useModernMessageLayout ? '现代布局' : '传统气泡'}`);
    } catch (error) {
      Logger.error('SettingsPage', `加载消息布局偏好失败: ${error}`);
    }

    // 加载服务器配置
    try {
      await this.serverConfigManager.initialize();
      const serverConfig = this.serverConfigManager.getCurrentServer();
      
      // 更新各个属性以确保响应性
      this.currentServer.ip = serverConfig.ip;
      this.currentServer.port = serverConfig.port;
      this.currentServer.protocol = serverConfig.protocol;
      this.currentServer.wsProtocol = serverConfig.wsProtocol;
      this.currentServer.description = serverConfig.description;
      
      Logger.info('SettingsPage', `服务器配置加载成功: ${this.currentServer.protocol}://${this.currentServer.ip}:${this.currentServer.port}`);
    } catch (error) {
      Logger.error('SettingsPage', `加载服务器配置失败: ${error}`);
    }
    
    // 添加用户资料监听器
    this.userProfileManager.addProfileListener(this.userProfileListener);
    
    // 添加头像设置监听器（仅用于AI头像）
    StorageManager.addAvatarListener(this.avatarListener);
    
    // 添加服务器配置变更监听器
    this.serverConfigManager.addConfigChangeListener(this.serverConfigListener);

    // 初始化字体管理器
    try {
      await this.fontManager.initialize();
      this.fontSettings = this.fontManager.getFontSettings();
      this.fontManager.addListener(this.fontSettingsListener);
      Logger.info('SettingsPage', `字体设置初始化完成: ${JSON.stringify(this.fontSettings)}`);
    } catch (error) {
      Logger.error('SettingsPage', `初始化字体设置失败: ${error}`);
    }

    // 暂时使用固定状态栏高度，后续动态获取
    Logger.info('SettingsPage', '使用固定状态栏高度44vp');

    // 设置初始化完成标记，避免初始化过程中触发onChange事件
    this.isInitialized = true;
    Logger.info('SettingsPage', '页面初始化完成');
  }

  async onPageShow(): Promise<void> {
    Logger.info('SettingsPage', '页面显示，重新加载设置状态');
    this.playEnterTransition();
    
    // 重新加载消息布局偏好，确保显示最新状态
    try {
      const previousLayout = this.useModernMessageLayout;
      this.useModernMessageLayout = await StorageManager.getMessageLayoutPreference();
      
      if (previousLayout !== this.useModernMessageLayout) {
        Logger.info('SettingsPage', `消息布局偏好已更新: ${previousLayout ? '现代' : '传统'} -> ${this.useModernMessageLayout ? '现代' : '传统'}`);
        
        // 强制UI刷新：通过微小延迟确保状态变化能正确反映到UI
        setTimeout(() => {
          Logger.debug('SettingsPage', `UI刷新完成，当前状态: ${this.useModernMessageLayout ? '现代' : '传统'}`);
        }, 50);
      } else {
        Logger.debug('SettingsPage', `消息布局偏好未变更: ${this.useModernMessageLayout ? '现代' : '传统'}`);
      }
    } catch (error) {
      Logger.error('SettingsPage', `重新加载消息布局偏好失败: ${error}`);
    }

    // 重新加载服务器配置，确保显示最新状态
    try {
      const serverConfig = this.serverConfigManager.getCurrentServer();
      
      // 更新各个属性以确保响应性
      this.currentServer.ip = serverConfig.ip;
      this.currentServer.port = serverConfig.port;
      this.currentServer.protocol = serverConfig.protocol;
      this.currentServer.wsProtocol = serverConfig.wsProtocol;
      this.currentServer.description = serverConfig.description;
      
      Logger.info('SettingsPage', `重新加载服务器配置完成: ${serverConfig.protocol}://${serverConfig.ip}:${serverConfig.port}`);
    } catch (error) {
      Logger.error('SettingsPage', `重新加载服务器配置失败: ${error}`);
    }
  }

  aboutToDisappear(): void {
    // 移除用户资料监听器
    this.userProfileManager.removeProfileListener(this.userProfileListener);

    // 移除头像设置监听器
    StorageManager.removeAvatarListener(this.avatarListener);

    // 移除服务器配置变更监听器
    this.serverConfigManager.removeConfigChangeListener(this.serverConfigListener);

    // 移除字体设置监听器
    this.fontManager.removeListener(this.fontSettingsListener);
  }

  onBackPress(): boolean | void {
    // 直接返回上一页
    router.back();
    return true;
  }

  // 头像设置变化监听器
  onAvatarSettingsChanged(): void {
    // 头像设置变化时自动触发，@Computed属性会自动重新计算
  }

  private resetEnterAnimationState(): void {
    this.pageTranslateX = this.PAGE_ENTER_OFFSET;
    this.pageOpacity = BasicAnimations.HIDDEN_OPACITY;
    this.hasPlayedEnterAnimation = false;
  }

  private playEnterTransition(): void {
    if (this.hasPlayedEnterAnimation) {
      return;
    }

    this.hasPlayedEnterAnimation = true;
    const duration = this.animationConfigManager.getDuration(BasicAnimations.STANDARD_DURATION);
    const curve = this.animationConfigManager.getCurve();

    animateTo({
      duration,
      curve
    }, () => {
      this.pageTranslateX = 0;
      this.pageOpacity = BasicAnimations.STANDARD_OPACITY;
    });
  }

  private getServerSettings(): SettingItem[] {
    // 获取实时的服务器配置
    const currentServer = this.serverConfigManager.getCurrentServer();
    const serverUrl = `${currentServer.protocol}://${currentServer.ip}:${currentServer.port}`;
    return [
      {
        title: '服务器配置',
        subtitle: `${currentServer.ip}:${currentServer.port}`,
        type: 'button'
      }
    ];
  }

  private getAppSettings(): SettingItem[] {
    return [
      {
        title: '通知',
        subtitle: '接收消息通知',
        type: 'switch',
        value: this.enableNotifications
      },
      {
        title: '消息样式',
        subtitle: this.useModernMessageLayout ? '现代线性布局' : '传统消息气泡',
        type: 'switch',
        value: this.useModernMessageLayout
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

  private getAISettings(): SettingItem[] {
    return [
      {
        title: 'API调用模式',
        subtitle: APIManager.getModeDescription(this.currentAPIMode),
        type: 'switch',
        value: this.currentAPIMode === APIMode.DIRECT_CALL
      },
      {
        title: 'API密钥管理',
        subtitle: '直连模式密钥配置',
        type: 'button'
      },
      {
        title: '角色管理',
        subtitle: 'AI助手角色设定',
        type: 'button'
      },
      {
        title: 'MCP设置',
        subtitle: 'Model Context Protocol 服务器和工具配置',
        type: 'button'
      }
    ];
  }

  
  
  
  private getVoiceSettings(): SettingItem[] {
    return [
      {
        title: '收到回复时播放',
        subtitle: this.autoTTSSettings.autoPlayOnReceive ? '收到AI回复时自动播放' : '需要手动点击播放',
        type: 'switch',
        value: this.autoTTSSettings.autoPlayOnReceive
      },
      {
        title: '语音速度',
        subtitle: '', // 将由 getDynamicSubtitle 动态生成
        type: 'slider',
        numValue: this.autoTTSSettings.speed,
        minValue: 0.5,
        maxValue: 2.0,
        step: 0.1
      },
      {
        title: '音量大小',
        subtitle: '', // 将由 getDynamicSubtitle 动态生成
        type: 'slider',
        numValue: this.autoTTSSettings.volume,
        minValue: 0.1,
        maxValue: 1.0,
        step: 0.1
      },
      {
        title: '音调高低',
        subtitle: '', // 将由 getDynamicSubtitle 动态生成
        type: 'slider',
        numValue: this.autoTTSSettings.pitch,
        minValue: 0.5,
        maxValue: 2.0,
        step: 0.1
      }
    ];
  }

  private getFontSettings(): SettingItem[] {
    return [
      {
        title: '聊天字体大小',
        subtitle: '', // 将由 getDynamicSubtitle 动态生成
        type: 'slider',
        numValue: this.fontSettings.chatFontSize,
        minValue: 12,
        maxValue: 20,
        step: 1
      },
      {
        title: '代码字体大小',
        subtitle: '', // 将由 getDynamicSubtitle 动态生成
        type: 'slider',
        numValue: this.fontSettings.codeFontSize,
        minValue: 10,
        maxValue: 18,
        step: 1
      },
      {
        title: '字体家族',
        subtitle: '', // 将由 getDynamicSubtitle 动态生成
        type: 'info'
      }
    ];
  }

  private getMemorySettings(): SettingItem[] {
    return [
      {
        title: '记忆中心',
        subtitle: `${this.memoryStats.totalFragments}个记忆碎片，${this.memoryStats.activeFragments}个已激活`,
        type: 'button'
      }
    ];
  }

  private getAboutSettings(): SettingItem[] {
    const configManager = AppConfigManager.getInstance();
    const privacyConfig = configManager.getPrivacyConfig();
    
    const developerInfo = privacyConfig.showDeveloperInfo ? privacyConfig.developerName : '';
    
    const settings: SettingItem[] = [
      {
        title: '关于应用',
        subtitle: 'LLM助手应用介绍',
        type: 'button'
      },
      {
        title: '版本号',
        subtitle: 'v1.0.0',
        type: 'info'
      }
    ];
    
    if (privacyConfig.showDeveloperInfo) {
      settings.push({
        title: '开发者信息',
        subtitle: developerInfo,
        type: developerInfo ? 'button' : 'info'
      });
    }
    
    return settings;
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏 - 添加状态栏高度避让
        Column() {
          this.buildNavigationBar()
        }
        .margin({ top: this.statusBarHeight })

        // 设置选项列表
        this.buildSettingsList()
      }
      .translate({ x: this.pageTranslateX, y: 0 })
      .opacity(this.pageOpacity)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_color'))

      // 字体家族选择对话框
      if (this.showFontFamilyDialog) {
        this.FontFamilySelectionDialog()
      }

      // 服务器输入对话框
      if (this.showServerInputDialog) {
        this.ServerInputDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Button('返回')
        .fontSize(15)
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.primary_color'))
        .padding({ left: 0, right: 0 })
        .onClick(() => {
          router.back();
        })

      Text('设置')
        .fontSize(18)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank()
        .width(48) // 占位，保持标题居中
    }
    .width('100%')
    .height(52)
    .padding({ left: 20, right: 20 })
    .backgroundColor($r('app.color.surface_color'))
    .shadow({
      radius: 2,
      color: '#0D000000',
      offsetY: 1
    })
  }

  @Builder
  buildSettingsList() {
    Scroll() {
      Column() {
        // 服务器设置
        this.buildSettingsGroup('服务器设置', this.getServerSettings(), 'server')

        // AI设置
        this.buildSettingsGroup('AI设置', this.getAISettings(), 'ai')

        // 个人资料设置
        this.buildSettingsGroup('个人资料', this.computedProfileSettingsItems, 'profile')

        // 记忆管理设置
        this.buildSettingsGroup('记忆管理', this.getMemorySettings(), 'memory')

        // 语音播报设置
        this.buildSettingsGroup('语音播报', this.getVoiceSettings(), 'voice')

        // 字体设置
        this.buildSettingsGroup('字体设置', this.getFontSettings(), 'font')

        // 应用设置
        this.buildSettingsGroup('应用设置', this.getAppSettings(), 'app')

        // 关于信息
        this.buildSettingsGroup('关于', this.getAboutSettings(), 'about')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 32 })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildSettingsGroup(title: string, items: SettingItem[], sectionId: string) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 8 })

      Column() {
        ForEach(items, (item: SettingItem, index: number) => {
          this.buildSettingsItem(item, index === items.length - 1)
        })
      }
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius(12)
      .margin({ bottom: 24 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .id(sectionId)
  }

  @Builder
  buildSettingsItem(item: SettingItem, isLast: boolean) {
    Column() {
      Row() {
        Column() {
          Text(item.title)
            .fontSize(16)
            .fontColor(item.type === 'button' ? $r('app.color.primary_color') : $r('app.color.text_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)

          if (this.getDynamicSubtitle(item)) {
            Text(this.getDynamicSubtitle(item))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 2 })
              .maxLines(2)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 根据类型显示不同的控件
        if (item.type === 'switch') {
          Toggle({ type: ToggleType.Switch, isOn: this.getSwitchValue(item) })
            .onChange(async (isOn: boolean) => {
              Logger.info('SettingsPage', `Toggle onChange触发: ${item.title}, isOn: ${isOn}, isInitialized: ${this.isInitialized}`);
              
              // 只在页面初始化完成后才处理onChange事件，避免初始化过程中的意外触发
              if (!this.isInitialized) {
                Logger.debug('SettingsPage', `跳过初始化阶段的开关变更: ${item.title}`);
                return;
              }
              
              if (item.title === '通知') {
                this.enableNotifications = isOn;
              } else if (item.title === '消息样式') {
                // 直接更新状态
                this.useModernMessageLayout = isOn;
                // 异步保存到存储
                try {
                  await StorageManager.saveMessageLayoutPreference(isOn);
                  Logger.info('SettingsPage', `消息布局样式已保存: ${isOn ? '现代布局' : '传统气泡'}`);
                } catch (error) {
                  Logger.error('SettingsPage', `保存消息布局样式失败: ${error}`);
                }
              } else if (item.title === 'API调用模式') {
                Logger.info('SettingsPage', `用户手动切换API模式: ${isOn ? '直连' : '服务器代理'}`);
                await this.handleAPIModeChange(isOn, true); // true表示手动切换
              } else if (item.title === '收到回复时播放') {
                await this.updateAutoTTSSetting('autoPlayOnReceive', isOn);
              }
            })
        } else if (item.type === 'slider') {
          Column() {
            Slider({
              value: item.numValue || 0,
              min: item.minValue || 0,
              max: item.maxValue || 1,
              step: item.step || 0.1
            })
              .width(120)
              .trackColor($r('app.color.border_color'))
              .selectedColor($r('app.color.primary_color'))
              .blockColor($r('app.color.primary_color'))
              .onChange(async (value: number) => {
                if (item.title === '语音速度') {
                  await this.updateAutoTTSSetting('speed', value);
                } else if (item.title === '音量大小') {
                  await this.updateAutoTTSSetting('volume', value);
                } else if (item.title === '音调高低') {
                  await this.updateAutoTTSSetting('pitch', value);
                } else if (item.title === '聊天字体大小') {
                  await this.updateChatFontSize(value);
                } else if (item.title === '代码字体大小') {
                  await this.updateCodeFontSize(value);
                }
              })
          }
        } else if (item.type === 'avatar') {
          // 根据标题判断是用户头像还是AI头像，直接使用最新的avatarSettings数据
          this.buildAvatarPreview(item.title === '我的头像')
        } else if (item.type === 'input' || item.type === 'button') {
          Text('>')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
        }
      }
      .width('100%')
      .height(64)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        Logger.info('SettingsPage', `设置项被点击: ${item.title}, 类型: ${item.type}`);
        if (item.type === 'input' && item.title === '服务器地址') {
          this.showServerUrlDialog();
        } else if (item.type === 'avatar') {
          this.showAvatarSelectionDialog(item.title);
        } else if (item.type === 'button') {
          this.handleButtonClick(item.title);
        } else if (item.title === '字体家族') {
          this.showFontFamilyDialog = true;
        }
      })

      if (!isLast) {
        Divider()
          .color($r('app.color.border_color'))
          .height(0.5)
          .margin({ left: 0, right: 0 })
      }
    }
    .padding({ left: 16, right: 16 })
  }

  // 服务器地址输入对话框状态
  @Local showServerInputDialog: boolean = false;
  @Local serverInputIp: string = '';
  @Local serverInputPort: string = '';
  @Local serverInputProtocol: 'http' | 'https' = 'http';
  @Local serverInputError: string = '';

  // 字体家族选择对话框状态
  @Local showFontFamilyDialog: boolean = false;
  
  
  private showServerUrlDialog(): void {
    // 初始化输入框的值为当前服务器配置
    this.serverInputIp = this.currentServer.ip;
    this.serverInputPort = this.currentServer.port.toString();
    this.serverInputProtocol = this.currentServer.protocol;
    this.serverInputError = '';
    this.showServerInputDialog = true;
  }

  private async saveServerConfig(): Promise<void> {
    try {
      // 验证输入
      const ip = this.serverInputIp.trim();
      const port = parseInt(this.serverInputPort);
      
      if (!ip) {
        this.serverInputError = 'IP地址不能为空';
        return;
      }
      
      if (!this.serverConfigManager.validateIpFormat(ip)) {
        this.serverInputError = 'IP地址格式不正确';
        return;
      }
      
      if (isNaN(port) || !this.serverConfigManager.validatePort(port)) {
        this.serverInputError = '端口范围: 1-65535';
        return;
      }
      
      // 创建新的服务器配置
      const newEndpoint: ServerEndpoint = {
        ip: ip,
        port: port,
        protocol: this.serverInputProtocol,
        wsProtocol: this.serverInputProtocol === 'https' ? 'wss' : 'ws',
        description: '自定义服务器'
      };
      
      // 更新服务器配置
      await this.serverConfigManager.setCurrentServer(newEndpoint);
      
      // 更新本地状态
      this.currentServer = newEndpoint;
      
      // 同步到AppConfigManager
      const configManager = AppConfigManager.getInstance();
      await configManager.updateServerEndpoint(newEndpoint);
      
      // 关闭对话框
      this.showServerInputDialog = false;
      
      Logger.info('SettingsPage', `服务器配置已更新: ${newEndpoint.protocol}://${newEndpoint.ip}:${newEndpoint.port}`);
      
      // 测试服务器连接
      const testResult = await this.serverConfigManager.validateServer(newEndpoint);
      
      // 显示保存结果
      if (testResult.success) {
        AlertDialog.show({
          title: '配置已保存',
          message: `服务器地址已更新为: ${newEndpoint.protocol}://${newEndpoint.ip}:${newEndpoint.port}\n连接测试成功！响应时间: ${testResult.responseTime}ms`,
          confirm: {
            value: '确定',
            action: () => {}
          }
        });
      } else {
        AlertDialog.show({
          title: '配置已保存',
          message: `服务器地址已更新为: ${newEndpoint.protocol}://${newEndpoint.ip}:${newEndpoint.port}\n⚠️ 连接测试失败: ${testResult.errorMessage}`,
          confirm: {
            value: '确定',
            action: () => {}
          }
        });
      }
      
    } catch (error) {
      Logger.error('SettingsPage', `保存服务器配置失败: ${error}`);
      this.serverInputError = `保存失败: ${(error as Error).message}`;
    }
  }

  private handleButtonClick(title: string): void {
    Logger.info('SettingsPage', `handleButtonClick被调用: ${title}`);
    switch (title) {
      case '服务器配置':
        Logger.info('SettingsPage', '跳转到服务器设置页面');
        this.navigateToServerSettings();
        break;
      case '服务器地址':
        this.showServerUrlDialog();
        break;
      case '个人资料':
        this.navigateToProfileEdit();
        break;
      case '清除聊天记录':
        this.showClearHistoryDialog();
        break;
      case '重置模型选择':
        this.showClearModelConfigDialog();
        break;
      case 'API密钥管理':
        this.navigateToAPIKeyManager();
        break;
      case '角色管理':
        this.navigateToPromptManager();
        break;
      case 'MCP设置':
        this.navigateToMCPSettings();
        break;
      case '记忆中心':
        this.navigateToMemoryManager();
        break;
      case '关于应用':
        this.showAbout();
        break;
      case '开发者信息':
        this.showDeveloperInfo();
        break;
      default:
        Logger.warn('SettingsPage', `未知的按钮点击: ${title}`);
    }
  }

  @Builder
  buildAvatarPreview(isUserAvatar: boolean) {
    if ((isUserAvatar ? this.userAvatarType : this.aiAvatarType) === 'emoji') {
      Text(isUserAvatar ? this.userAvatarValue : this.aiAvatarValue)
        .fontSize(24)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .borderRadius(20)
        .backgroundColor($r('app.color.input_background'))
    } else if ((isUserAvatar ? this.userAvatarType : this.aiAvatarType) === 'image') {
      Image(isUserAvatar ? this.userAvatarValue : this.aiAvatarValue)
        .width(40)
        .height(40)
        .borderRadius(20)
        .objectFit(ImageFit.Cover)
    } else {
      Circle({ width: 40, height: 40 })
        .fill(isUserAvatar ? this.userAvatarValue : this.aiAvatarValue)
    }
  }


  
  private navigateToServerSettings(): void {
    Logger.info('SettingsPage', '导航到服务器设置页面');
    router.pushUrl({ 
      url: 'pages/ServerSettingsPage'
    }).catch((error: Error) => {
      Logger.error('SettingsPage', `跳转失败: ${error.message}`);
    });
  }

  private navigateToPromptManager(): void {
    router.pushUrl({
      url: 'pages/RoleManagerPage',
      params: { fromSettingsPage: true }
    });
  }

  private navigateToMCPSettings(): void {
    router.pushUrl({
      url: 'pages/MCPSettingsPage'
    }).catch((error: Error) => {
      Logger.error('SettingsPage', `跳转到MCP设置页面失败: ${error.message}`);
    });
  }

  private navigateToMemoryManager(): void {
    router.pushUrl({
      url: 'pages/MemoryManagerPage'
    }).catch((error: Error) => {
      Logger.error('SettingsPage', `跳转到记忆中心页面失败: ${error.message}`);
    });
  }

  private navigateToAPIKeyManager(): void {
    router.pushUrl({
      url: 'pages/APIKeyManagerPage'
    });
  }

  private navigateToProfileEdit(): void {
    router.pushUrl({ 
      url: 'pages/UserProfileEditPage'
    });
  }


  private showAbout(): void {
    AlertDialog.show({
      title: '关于应用',
      message: '🤖 Javis - 智能AI编程助手 v1.0.0\n\n一款基于鸿蒙系统的智能AI编程助手应用，通过集成多个大语言模型API，为开发者提供智能编程辅助、代码生成、问题解答等全方位服务。\n\n✨ 核心功能：\n• 智能编程对话：基于多厂商大模型的代码助手\n• 语音交互：华为语音识别 + TTS语音朗读\n• 多模型支持：Claude、Qwen、DeepSeek、Google Gemini\n• 代码执行：Python、JavaScript、Go、Bash在线执行\n• 角色管理：自定义AI助手角色，个性化对话体验\n• 现代化UI：侧边栏导航、主题切换、头像管理\n\n🎯 技术特色：\n• ArkTS V2状态管理，响应式界面设计\n• MVVM + 组件化开发架构\n• 华为语音服务和TTS引擎集成\n• WebSocket实时通信支持\n• 安全的代码执行沙箱环境',
      confirm: {
        value: '确定',
        action: () => {}
      }
    });
  }

  private showDeveloperInfo(): void {
    const configManager = AppConfigManager.getInstance();
    const privacyConfig = configManager.getPrivacyConfig();
    
    if (!privacyConfig.showDeveloperInfo) {
      return;
    }
    
    let message = `开发者：${privacyConfig.developerName}`;
    
    if (privacyConfig.developerContact) {
      message += `\n\n📧 联系方式：\n${privacyConfig.developerContact}`;
    }
    
    if (privacyConfig.githubUrl) {
      message += `\n\n🚀 项目地址：\n${privacyConfig.githubUrl}`;
    }
    
    AlertDialog.show({
      title: '开发者信息',
      message: message,
      confirm: {
        value: '确定',
        action: () => {}
      }
    });
  }

  private showClearHistoryDialog(): void {
    AlertDialog.show({
      title: '确认清除',
      message: '您确定要清除所有聊天记录吗？此操作不可恢复。',
      primaryButton: {
        value: '取消',
        action: () => {
          Logger.debug('SettingsPage', '取消清除聊天记录');
        }
      },
      secondaryButton: {
        value: '确认',
        fontColor: Color.Red,
        action: async () => {
          await this.clearAllChatData();
        }
      }
    });
  }

  private showClearModelConfigDialog(): void {
    AlertDialog.show({
      title: '重置模型选择',
      message: '是否清除保存的模型选择配置？下次启动时将使用默认模型。',
      primaryButton: {
        value: '取消',
        action: () => {
          Logger.debug('SettingsPage', '取消重置模型选择');
        }
      },
      secondaryButton: {
        value: '重置',
        fontColor: $r('app.color.primary_color'),
        action: async () => {
          await this.clearModelConfig();
        }
      }
    });
  }

  /**
   * 清除所有聊天数据
   */
  private async clearAllChatData(): Promise<void> {
    try {
      Logger.info('SettingsPage', '开始清除所有聊天数据...');
      
      // 清除旧的消息存储（兼容性）
      await StorageManager.clearMessages();
      Logger.info('SettingsPage', '旧消息存储已清除');
      
      // 获取所有会话并删除每个会话的消息
      const sessions = await StorageManager.getSessions();
      Logger.info('SettingsPage', `找到 ${sessions.length} 个会话，开始删除消息`);
      
      for (const session of sessions) {
        await StorageManager.deleteSessionMessages(session.id);
        Logger.debug('SettingsPage', `会话 ${session.id} 的消息已删除`);
      }
      
      // 清空所有会话
      await StorageManager.clearSessions();
      Logger.info('SettingsPage', '所有会话已清空');
      
      // 清除当前会话ID
      await StorageManager.setCurrentSessionId('');
      Logger.info('SettingsPage', '当前会话ID已清除');
      
      // 通知所有监听器会话数据已清除
      StorageManager.notifySessionDataClearedListeners();
      Logger.info('SettingsPage', '已通知监听器会话数据已清除');
      
      Logger.info('SettingsPage', '✅ 所有聊天数据清除完成');
      
      // 显示成功提示
      AlertDialog.show({
        title: '清除成功',
        message: '所有聊天记录已成功清除',
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
      
    } catch (error) {
      Logger.error('SettingsPage', `清除聊天数据失败: ${error}`);
      
      // 显示错误提示
      AlertDialog.show({
        title: '清除失败',
        message: `清除聊天记录时发生错误: ${(error as Error).message}`,
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
    }
  }

  /**
   * 清除模型选择配置
   */
  private async clearModelConfig(): Promise<void> {
    try {
      Logger.info('SettingsPage', '开始清除模型选择配置...');
      
      // 清除保存的模型选择配置
      await StorageManager.clearCurrentModel();
      Logger.info('SettingsPage', '模型选择配置已清除');
      
      // 显示成功提示
      AlertDialog.show({
        title: '重置成功',
        message: '模型选择配置已清除，下次启动时将使用默认模型',
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
      
    } catch (error) {
      Logger.error('SettingsPage', `清除模型配置失败: ${error}`);
      
      // 显示错误提示
      AlertDialog.show({
        title: '重置失败',
        message: `清除模型选择配置时发生错误: ${(error as Error).message}`,
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
    }
  }

  /**
   * 更新自动播报设置
   */
  private async updateAutoTTSSetting(key: keyof AutoTTSSettings, value: boolean | number): Promise<void> {
    try {
      const updates: Partial<AutoTTSSettings> = {};
      if (key === 'muted' && typeof value === 'boolean') {
        updates.muted = value;
      } else if (key === 'speed' && typeof value === 'number') {
        updates.speed = value;
      } else if (key === 'volume' && typeof value === 'number') {
        updates.volume = value;
      } else if (key === 'pitch' && typeof value === 'number') {
        updates.pitch = value;
      } else if (key === 'language' && typeof value === 'string') {
        updates.language = value;
      } else if (key === 'autoPlayOnReceive' && typeof value === 'boolean') {
        updates.autoPlayOnReceive = value;
      }
      
      // 同时更新AppStorage和AutoTTSService
      await StorageManager.updateAutoTTSSettings(updates);
      const serviceSettings = await this.autoTTSService.updateSettings(updates);
      
      // 更新本地状态
      this.autoTTSSettings = {
        muted: serviceSettings.muted,
        speed: serviceSettings.speed,
        volume: serviceSettings.volume,
        pitch: serviceSettings.pitch,
        language: serviceSettings.language,
        autoPlayOnReceive: serviceSettings.autoPlayOnReceive
      };
      
      Logger.info('SettingsPage', `自动播报设置已更新: ${key} = ${value}`);
    } catch (error) {
      Logger.error('SettingsPage', `更新自动播报设置失败: ${error}`);
    }
  }

  private getAvatarDisplayText(avatarType: string, avatarValue: string): string {
    switch (avatarType) {
      case 'emoji':
        return `表情符号: ${avatarValue}`;
      case 'image':
        return '自定义图片';
      case 'default':
      default:
        return `默认颜色: ${avatarValue}`;
    }
  }

  private getSwitchValue(item: SettingItem): boolean {
    // 直接使用状态变量，确保实时状态反映到UI
    switch (item.title) {
      case '通知':
        return this.enableNotifications;
      case '消息样式':
        return this.useModernMessageLayout;
      case 'API调用模式':
        return this.currentAPIMode === APIMode.DIRECT_CALL;
      case '收到回复时播放':
        return this.autoTTSSettings.autoPlayOnReceive;
      default:
        return item.value || false;
    }
  }

  private getDynamicSubtitle(item: SettingItem): string {
    if (item.type === 'avatar') {
      if (item.title === '我的头像') {
        return this.getAvatarDisplayText(this.userAvatarType, this.userAvatarValue);
      } else if (item.title === 'AI头像') {
        return this.getAvatarDisplayText(this.aiAvatarType, this.aiAvatarValue);
      }
    } else if (item.type === 'slider') {
      if (item.title === '语音速度') {
        return `当前: ${this.autoTTSSettings.speed.toFixed(1)}x`;
      } else if (item.title === '音量大小') {
        return `当前: ${Math.round(this.autoTTSSettings.volume * 100)}%`;
      } else if (item.title === '音调高低') {
        return `当前: ${this.autoTTSSettings.pitch.toFixed(1)}`;
      } else if (item.title === '聊天字体大小') {
        return `当前: ${this.fontSettings.chatFontSize}px`;
      } else if (item.title === '代码字体大小') {
        return `当前: ${this.fontSettings.codeFontSize}px`;
      } else if (item.title === '字体家族') {
        return `当前: ${FontManager.getFontFamilyDisplayText(this.fontSettings.fontFamily)}`;
      }
    }
    return item.subtitle || '';
  }

  private showAvatarSelectionDialog(title: string): void {
    const isUserAvatar = title === '我的头像';
    const avatarOptions: AvatarOption[] = [
      { text: '默认蓝色', value: 'default:#4285F4' },
      { text: '默认绿色', value: 'default:#34A853' },
      { text: '默认红色', value: 'default:#EA4335' },
      { text: '默认橙色', value: 'default:#FBBC05' },
      { text: '默认紫色', value: 'default:#9C27B0' },
      { text: '😀', value: 'emoji:😀' },
      { text: '🙂', value: 'emoji:🙂' },
      { text: '😊', value: 'emoji:😊' },
      { text: '🤔', value: 'emoji:🤔' },
      { text: '🤖', value: 'emoji:🤖' },
      { text: '👨‍💻', value: 'emoji:👨‍💻' },
      { text: '👩‍💻', value: 'emoji:👩‍💻' },
      { text: '选择图片', value: 'image:select' }
    ];

    // 直接显示选择列表，不显示AlertDialog
    this.showAvatarGridDialog(isUserAvatar, avatarOptions);
  }

  private showAvatarActionDialog(isUserAvatar: boolean): void {
    ActionSheet.show({
      title: '头像选项',
      message: '选择操作',
      sheets: [
        {
          title: '选择本地图片',
          action: () => {
            this.selectImageFromGallery(isUserAvatar);
          }
        },
        {
          title: '重置为默认',
          action: async () => {
            await this.resetAvatar(isUserAvatar);
          }
        }
      ],
      cancel: () => {
        // 取消头像选择
      }
    });
  }

  private showAvatarGridDialog(isUserAvatar: boolean, options: AvatarOption[]): void {
    // 这里使用简化的列表选择
    const optionTexts = options.map((opt: AvatarOption) => opt.text);
    
    TextPickerDialog.show({
      range: optionTexts,
      selected: 0,
      onAccept: async (value: TextPickerResult) => {
        const selectedIndex: number = value.index as number;
        const selectedOption = options[selectedIndex];
        
        if (selectedOption.value === 'image:select') {
          await this.selectImageFromGallery(isUserAvatar);
        } else {
          const parts = selectedOption.value.split(':');
          const type = parts[0] as 'default' | 'emoji';
          const val = parts[1];
          await this.updateAvatarSetting(isUserAvatar, type, val);
        }
      },
      onCancel: () => {
        // 取消头像选择
      }
    });
  }

  private async selectImageFromGallery(isUserAvatar: boolean): Promise<void> {
    try {
      const photoSelectOptions: picker.PhotoSelectOptions = {
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };

      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const photoSelectResult: picker.PhotoSelectResult = await photoPicker.select(photoSelectOptions);

      if (photoSelectResult.photoUris.length > 0) {
        const imageUri: string = photoSelectResult.photoUris[0];
        await this.updateAvatarSetting(isUserAvatar, 'image', imageUri);
        // 头像图片选择成功
      }
    } catch (error) {
      Logger.error('SettingsPage', `选择头像图片失败: ${error}`);
      AlertDialog.show({
        title: '选择失败',
        message: '无法选择图片，请重试',
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
    }
  }

  private async resetAvatar(isUserAvatar: boolean): Promise<void> {
    const defaultColor = isUserAvatar ? '#4285F4' : '#34A853';
    await this.updateAvatarSetting(isUserAvatar, 'default', defaultColor);
    // 头像已重置为默认
  }

  private async updateAvatarSetting(isUserAvatar: boolean, type: 'default' | 'emoji' | 'image', value: string): Promise<void> {
    try {
      // 直接修改本地状态，@Computed会自动处理UI更新
      if (isUserAvatar) {
        this.userAvatarType = type;
        this.userAvatarValue = value;
      } else {
        this.aiAvatarType = type;
        this.aiAvatarValue = value;
      }
      
      // 保存到存储并通知其他组件
      const avatarSettings = new AvatarSettings(
        this.userAvatarType,
        this.userAvatarValue,
        this.aiAvatarType,
        this.aiAvatarValue
      );
      await StorageManager.updateAvatarSettings(avatarSettings.toObject());
    } catch (error) {
      Logger.error('SettingsPage', `更新头像设置失败: ${error}`);
    }
  }

  
  //=================== API模式相关方法 ===================

  /**
   * 处理API模式切换
   * @param isDirectCall 是否为直连模式
   * @param showDialog 是否显示切换提示对话框，默认false（用于区分手动切换和页面加载）
   */
  private async handleAPIModeChange(isDirectCall: boolean, showDialog: boolean = false): Promise<void> {
    try {
      const newMode = isDirectCall ? APIMode.DIRECT_CALL : APIMode.SERVER_PROXY;
      
      // 如果新模式与当前模式相同，不执行任何操作
      if (newMode === this.currentAPIMode) {
        Logger.info('SettingsPage', `API模式未发生变化 (${newMode})，跳过切换操作`);
        return;
      }
      
      Logger.info('SettingsPage', `切换API调用模式: ${this.currentAPIMode} -> ${newMode}`);
      
      // 更新本地状态
      this.currentAPIMode = newMode;
      
      // 设置API管理器模式
      await this.apiManager.setAPIMode(newMode);
      
      Logger.info('SettingsPage', `API调用模式切换完成: ${newMode}`);
      
      // 只在手动切换时显示切换提示
      if (showDialog) {
        AlertDialog.show({
          title: '模式切换成功',
          message: `已切换到${APIManager.getModeDisplayName(newMode)}模式`,
          confirm: {
            value: '确定',
            action: () => {}
          }
        });
      }
      
    } catch (error) {
      Logger.error('SettingsPage', `API模式切换失败: ${error}`);
      
      // 切换失败，恢复原状态
      this.currentAPIMode = this.currentAPIMode === APIMode.DIRECT_CALL ? APIMode.SERVER_PROXY : APIMode.DIRECT_CALL;
      
      AlertDialog.show({
        title: '切换失败',
        message: `无法切换API调用模式: ${(error as Error).message}`,
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
    }
  }

  /**
   * 处理消息布局样式切换
   */

  //=================== 字体设置相关方法 ===================

  /**
   * 更新聊天字体大小
   */
  private async updateChatFontSize(size: number): Promise<void> {
    try {
      await this.fontManager.updateChatFontSize(size);
      Logger.info('SettingsPage', `聊天字体大小已更新: ${size}px`);
    } catch (error) {
      Logger.error('SettingsPage', `更新聊天字体大小失败: ${error}`);
    }
  }

  /**
   * 更新代码字体大小
   */
  private async updateCodeFontSize(size: number): Promise<void> {
    try {
      await this.fontManager.updateCodeFontSize(size);
      Logger.info('SettingsPage', `代码字体大小已更新: ${size}px`);
    } catch (error) {
      Logger.error('SettingsPage', `更新代码字体大小失败: ${error}`);
    }
  }

  /**
   * 更新字体家族
   */
  private async updateFontFamily(family: 'system' | 'serif' | 'monospace' | 'rounded' | 'elegant' | 'playful' | 'modern' | 'classic'): Promise<void> {
    try {
      Logger.info('SettingsPage', `开始更新字体家族: ${family}`);
      Logger.info('SettingsPage', `更新前字体设置: ${JSON.stringify(this.fontSettings)}`);
      await this.fontManager.updateFontFamily(family);
      Logger.info('SettingsPage', `字体家族已更新: ${family}`);
      Logger.info('SettingsPage', `更新后字体设置: ${JSON.stringify(this.fontSettings)}`);
    } catch (error) {
      Logger.error('SettingsPage', `更新字体家族失败: ${error}`);
    }
  }

  // 服务器地址输入对话框
  @Builder
  ServerInputDialog() {
    Column() {
      Text('服务器设置')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 24 })

      // IP地址输入
      Column() {
        Text('服务器地址')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        TextInput({ placeholder: '例如: 192.168.1.100 或 localhost' })
          .width('100%')
          .height(48)
          .borderRadius(8)
          .backgroundColor($r('app.color.input_background'))
          .placeholderColor($r('app.color.text_secondary'))
          .fontColor($r('app.color.text_primary'))
          .focusable(true)
          .onChange((value: string) => {
            this.serverInputIp = value;
            if (this.serverInputError) {
              this.serverInputError = '';
            }
          })

        if (this.serverInputError) {
          Text(this.serverInputError)
            .fontSize(14)
            .fontColor('#F44336')
            .alignSelf(ItemAlign.Start)
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 16 })

      // 端口和协议输入
      Row() {
        Column() {
          Text('端口')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 8 })

          TextInput({ placeholder: '8080' })
            .width('100%')
            .height(48)
            .borderRadius(8)
            .backgroundColor($r('app.color.input_background'))
            .placeholderColor($r('app.color.text_secondary'))
            .fontColor($r('app.color.text_primary'))
            .type(InputType.Number)
            .onChange((value: string) => {
              this.serverInputPort = value;
              if (this.serverInputError) {
                this.serverInputError = '';
              }
            })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text('协议')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 8 })

          Select([
            { value: 'HTTP' },
            { value: 'HTTPS' }
          ])
            .value(this.serverInputProtocol === 'http' ? 'HTTP' : 'HTTPS')
            .width('100%')
            .height(48)
            .borderRadius(8)
            .backgroundColor($r('app.color.input_background'))
            .fontColor($r('app.color.text_primary'))
            .selectedOptionBgColor($r('app.color.primary_color'))
            .selectedOptionFontColor(Color.White)
            .onSelect((index: number) => {
              this.serverInputProtocol = index === 0 ? 'http' : 'https';
            })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
        .width(100)
      }
      .width('100%')
      .margin({ bottom: 24 })

      // 当前配置信息
      Column() {
        Text('当前配置')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        Text(`${this.currentServer.protocol}://${this.currentServer.ip}:${this.currentServer.port}`)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .alignSelf(ItemAlign.Start)
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 24 })

      // 按钮行
      Row() {
        Button('取消')
          .fontSize(16)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.text_secondary'))
          .borderWidth(1)
          .borderColor($r('app.color.text_secondary'))
          .borderRadius(8)
          .layoutWeight(1)
          .height(48)
          .onClick(() => {
            this.showServerInputDialog = false;
            this.serverInputError = '';
          })

        Button('保存')
          .fontSize(16)
          .backgroundColor($r('app.color.primary_color'))
          .fontColor(Color.White)
          .borderRadius(8)
          .layoutWeight(1)
          .height(48)
          .margin({ left: 16 })
          .onClick(() => this.saveServerConfig())
      }
      .width('100%')
    }
    .width('90%')
    .padding(24)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
  }

  // 字体家族选择对话框
  @Builder
  FontFamilySelectionDialog() {
    Column() {
      // 背景遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.showFontFamilyDialog = false;
        })

      // 对话框内容
      Column() {
        Text('选择字体家族')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 20 })

        // 字体选项列表
        Column() {
          this.buildFontFamilyOption('system', '系统默认', 'system-ui, -apple-system, "PingFang SC"')
          Divider().color($r('app.color.border_color')).margin({ top: 1, bottom: 1 })

          this.buildFontFamilyOption('modern', '现代字体', '"SF Pro Display", "Roboto", "Noto Sans CJK SC"')
          Divider().color($r('app.color.border_color')).margin({ top: 1, bottom: 1 })

          this.buildFontFamilyOption('elegant', '优雅字体', '"Optima", "Avenir Next", "PingFang SC"')
          Divider().color($r('app.color.border_color')).margin({ top: 1, bottom: 1 })

          this.buildFontFamilyOption('rounded', '圆润字体', '"SF Pro Rounded", "PingFang SC"')
          Divider().color($r('app.color.border_color')).margin({ top: 1, bottom: 1 })

          this.buildFontFamilyOption('serif', '衬线字体', 'Georgia, "Times New Roman", "Songti SC"')
          Divider().color($r('app.color.border_color')).margin({ top: 1, bottom: 1 })

          this.buildFontFamilyOption('classic', '经典字体', '"Palatino", "Book Antiqua", "Times New Roman"')
          Divider().color($r('app.color.border_color')).margin({ top: 1, bottom: 1 })

          this.buildFontFamilyOption('monospace', '等宽字体', 'Monaco, Consolas, "SF Mono"')
          Divider().color($r('app.color.border_color')).margin({ top: 1, bottom: 1 })

          this.buildFontFamilyOption('playful', '活泼字体', '"Comic Sans MS", "Marker Felt"')
        }
        .backgroundColor($r('app.color.surface_color'))
        .borderRadius(12)
        .padding({ top: 8, bottom: 8 })

        // 取消按钮
        Button('取消')
          .fontSize(16)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.text_secondary'))
          .borderWidth(1)
          .borderColor($r('app.color.border_color'))
          .borderRadius(8)
          .width('100%')
          .height(44)
          .margin({ top: 16 })
          .onClick(() => {
            this.showFontFamilyDialog = false;
          })
      }
      .width('80%')
      .padding(20)
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius(16)
      .position({ x: '50%', y: '50%' })
      .translate({ x: '-50%', y: '-50%' })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildFontFamilyOption(
    family: 'system' | 'serif' | 'monospace' | 'rounded' | 'elegant' | 'playful' | 'modern' | 'classic',
    displayName: string,
    previewText: string
  ) {
    Row() {
      Column({ space: 4 }) {
        Text(displayName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .alignSelf(ItemAlign.Start)

        Text(previewText)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 选中标识
      if (this.fontSettings.fontFamily === family) {
        Text('✓')
          .fontSize(18)
          .fontColor($r('app.color.primary_color'))
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(async () => {
      await this.updateFontFamily(family);
      this.showFontFamilyDialog = false;
    })
  }
}
