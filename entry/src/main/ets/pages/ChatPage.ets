import { router, promptAction, curves, display } from '@kit.ArkUI';
import { ChatViewModel } from '../viewmodels/ChatViewModel';
import { Message, MessageRole, SystemPrompt, ThinkingStep, ThinkingStatus } from '../models/ChatModels';
import { inputMethod } from '@kit.IMEKit';
import { ModelSelectorComponent } from '../components/ModelSelectorComponent';
import { SystemPromptComponent } from '../components/SystemPromptComponent';
import { QuickCommandsComponent, QuickCommand } from '../components/QuickCommandsComponent';
import { SideDrawerComponent } from '../components/SideDrawerComponent';
import { ToolboxComponent } from '../components/ToolboxComponent';
import { VoiceInputComponent, VoiceRecognitionState, InputMode, VoiceOverlayHint } from '../components/VoiceInputComponent';
import { SmartTextRenderer } from '../components/SmartTextRenderer';
import { DeepThinkingDialog } from '../components/DeepThinkingDialog';
import { SearchDetailsDialog } from '../components/SearchDetailsDialog';
import { DeepThinkingStatusCard } from '../components/DeepThinkingStatusCard';
import { ToolCallStatusComponent } from '../components/ToolCallStatusComponent';
import { ToolType } from '../types/ToolboxTypes';
import { pasteboard } from '@kit.BasicServicesKit';
import { ThemeManager } from '../utils/ThemeManager';
import { FontManager } from '../utils/FontManager';
import { FontSettings } from '../utils/AppStorage';
import { AvatarSettings, UserProfile, AppStorage as StorageManager } from '../utils/AppStorage';
import { UserProfileManager } from '../utils/UserProfileManager';
import { AppConfigManager } from '../utils/AppConfigManager';
import { AutoTTSService } from '../services/AutoTTSService';
import { Logger } from '../utils/Logger';
import { Constants } from '../utils/Constants';
import { BusinessError } from '@kit.BasicServicesKit';

// 导入基础动画系统
import { 
  BasicAnimations, 
  AnimationConfigManager
} from '../animations';

/**
 * 工具箱项目接口
 */
interface ToolboxItem {
  id: string;
  title: string;
  description: string;
  icon: string;
  color: string;
  backgroundColor: string;
  enabled: boolean;
  action: () => void | Promise<void>;
}

/**
 * 导航图标选项接口
 */
interface NavigationIconOptions {
  active?: boolean;
  activeColor?: Resource | string;
  inactiveColor?: Resource | string;
  activeBorderColor?: Resource | string;
  inactiveBorderColor?: Resource | string;
}

/**
 * 位置坐标接口
 */
interface Position {
  x: number;
  y: number;
}

/**
 * 聊天主页面 - 使用状态管理V2和MVVM模式
 */
@Entry
@ComponentV2
struct ChatPage {
  @Local chatViewModel: ChatViewModel = new ChatViewModel();
  @Local inputText: string = '';
  @Local showModelSelector: boolean = false;
  // @Local showPromptSelector: boolean = false; // 已注释：不再使用顶部选择器
  @Local showQuickCommands: boolean = false;

  // 消息变化检测相关状态
  @Local messages: Message[] = [];
  @Local lastMessageCount: number = 0;
  @Local lastAssistantMessageContent: string = '';

  // 消息变化检测定时器
  private messageChangeTimer: number = -1;
  @Local isDarkMode: boolean = false;
  @Local isImmersiveMode: boolean = false;
  @Local showSideDrawer: boolean = false;
  @Local enableWebSearch: boolean = false; // 联网搜索开关状态
  @Local enableDeepThinking: boolean = false; // 深度思考开关状态
  @Local showToolboxPanel: boolean = false; // 工具箱面板显示状态
  @Local toolboxPanelOpacity: number = 0.0; // 工具箱面板透明度
  @Local toolboxPanelTranslateY: number = 400; // 工具箱面板Y轴位移
  @Local isMuted: boolean = false; // 自动播报静音状态
  
  // 语音识别相关状态
  @Local voiceRecognitionState: VoiceRecognitionState = VoiceRecognitionState.IDLE;
  @Local voiceInputMode: InputMode = InputMode.TEXT;
  @Local showVoiceInput: boolean = true; // 是否显示语音输入按钮
  @Local voiceOverlayHint: VoiceOverlayHint | null = null; // 语音提示覆盖层
  @Local sideDrawerSwipeProgress: number = 0; // 侧边栏滑动进度 (0-1)
  @Local isSideDrawerSwipeActive: boolean = false; // 是否正在滑动侧边栏
  @Local isSwipeDebouncing: boolean = false; // 滑动防抖状态
  @Local lastSwipeTime: number = 0; // 上次滑动时间
  @Local swipeDirection: 'left' | 'right' | 'none' = 'none'; // 当前滑动方向
  @Local isSessionItemSwiping: boolean = false; // 会话项是否正在滑动
  @Local useModernMessageLayout: boolean = false; // 现代消息布局开关
  @Local fontSettings: FontSettings = {
    chatFontSize: 16,
    codeFontSize: 14,
    fontFamily: 'playful',
    updatedAt: Date.now()
  };
  @Local userAvatarType: 'default' | 'emoji' | 'image' = 'default';
  @Local userAvatarValue: string = '#4285F4';
  @Local aiAvatarType: 'default' | 'emoji' | 'image' = 'default';
  @Local aiAvatarValue: string = '#34A853';
  @Local userName: string = 'Javis用户';
  @Local userSignature: string = '让AI成为你的编程伙伴';
  @Local inputAreaHeight: number = 48; // 输入区域动态高度
  @Local statusBarHeight: number = 44; // 状态栏高度，默认44，实际由系统API获取
  @Local keyboardHeight: number = 0; // 键盘高度，用于判断输入法是否显示
  @Local modelSelectorOpacity: number = 0.0; // 模型选择器透明度
  @Local modelSelectorTranslateY: number = 400; // 模型选择器Y轴偏移
  
    
  // 搜索详情弹框相关状态
  @Local showSearchDetailsDialog: boolean = false; // 搜索详情弹框显示状态
  @Local searchDetailsContent: string = ''; // 搜索详情弹框内容
  
  // 深度思考对话框相关状态
  @Local showThinkingDialog: boolean = false; // 深度思考对话框显示状态
  @Local thinkingDialogMessage: Message | null = null; // 深度思考对话框的消息
  
  private shouldCloseInputMethod: boolean = true;
  private targetSessionId: string = ''; // 目标会话ID（从路由参数获取）
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private fontManager: FontManager = FontManager.getInstance();
  private userProfileManager: UserProfileManager = UserProfileManager.getInstance();
  private autoTTSService: AutoTTSService = AutoTTSService.getInstance();
  private listScroller: ListScroller = new ListScroller();
  private lastProvidersReloadTime: number = 0; // 防抖：记录上次providers加载时间
  private forceReloadProviders: boolean = false; // 强制刷新模型列表标记
  private lastServerConfig: string = ''; // 上次服务器配置，用于检测变更
  private readonly SIDE_DRAWER_SWIPE_THRESHOLD = 80; // 侧边栏滑动阈值
  private readonly SIDE_DRAWER_PROGRESS_THRESHOLD = 0.3; // 侧边栏进度阈值 (30%)
  private readonly SIDE_DRAWER_EDGE_WIDTH = 20; // 侧边栏边缘检测宽度
  private readonly SWIPE_DEBOUNCE_TIME = 150; // 滑动防抖时间(ms)
  private readonly DIRECTION_CHANGE_THRESHOLD = 100; // 方向变化阈值(ms)
  private avatarListener: (settings: AvatarSettings) => void = (settings: AvatarSettings) => {
    this.userAvatarType = settings.userAvatarType;
    this.userAvatarValue = settings.userAvatarValue;
    this.aiAvatarType = settings.aiAvatarType;
    this.aiAvatarValue = settings.aiAvatarValue;
    Logger.info('ChatPage', '头像设置已更新');
  };
  private fontSettingsListener: (settings: FontSettings) => void = (settings: FontSettings) => {
    Logger.info('ChatPage', `收到FontManager字体设置变更通知: ${JSON.stringify(settings)}`);
    Logger.info('ChatPage', `更新前本地字体设置: ${JSON.stringify(this.fontSettings)}`);
    this.fontSettings = settings;
    Logger.info('ChatPage', `更新后本地字体设置: ${JSON.stringify(this.fontSettings)}`);
  };
  
  private readonly handleVoiceComponentResult = (text: string): void => {
    void this.handleVoiceResult(text);
  };

  private readonly handleVoiceComponentStateChange = (state: VoiceRecognitionState): void => {
    this.voiceRecognitionState = state;
  };

  private readonly handleVoiceComponentModeChange = (mode: InputMode): void => {
    if (this.voiceInputMode === mode) {
      return;
    }

    this.voiceInputMode = mode;

    if (mode === InputMode.VOICE) {
      try {
        inputMethod.getController().stopInputSession();
      } catch (error) {
        Logger.warn('ChatPage', `停止输入法会话失败: ${JSON.stringify(error)}`);
      }
      this.keyboardHeight = 0;
    }
  };

  private readonly handleVoiceComponentSmartPrompt = (prompt: string): void => {
    this.handleSmartPrompt(prompt);
  };

  private readonly handleVoiceComponentHintChange = (hint: VoiceOverlayHint | null): void => {
    this.voiceOverlayHint = hint;
  };

  async aboutToAppear(): Promise<void> {
    Logger.info('ChatPage', 'aboutToAppear 开始');
    
    // 处理路由参数，检查是否需要切换到特定会话
    try {
      const params = router.getParams();
      if (params && (params as Record<string, Object>).sessionId) {
        const sessionId = (params as Record<string, Object>).sessionId as string;
        Logger.info('ChatPage', `检测到路由参数sessionId: ${sessionId}，准备切换会话`);
        
        // 设置目标会话ID，稍后在loadInitialData之后切换
        this.targetSessionId = sessionId;
      }
    } catch (error) {
      Logger.warn('ChatPage', `获取路由参数失败: ${error}`);
    }
    
    // 初始化动画系统
    AnimationConfigManager.getInstance().initialize();
    
    // 初始化主题管理器
    await this.themeManager.initialize();
    this.isDarkMode = this.themeManager.getDarkMode();
    this.isImmersiveMode = this.themeManager.getImmersiveMode();
    
    // 添加主题变更监听器
    this.themeManager.addThemeListener((isDark: boolean) => {
      this.isDarkMode = isDark;
    });
    
    // 添加沉浸式模式变更监听器
    this.themeManager.addImmersiveListener((isImmersive: boolean) => {
      this.isImmersiveMode = isImmersive;
    });
    
    await this.chatViewModel.loadInitialData();

    try {
      const autoTTSSettings = this.autoTTSService.getSettings();
      this.isMuted = autoTTSSettings.muted;
    } catch (error) {
      Logger.warn('ChatPage', `获取自动播报静音状态失败: ${error}`);
    }

    this.autoTTSService.setCallbacks({
      onSettingsChanged: (settings) => {
        this.isMuted = settings.muted;
      }
    });

    // 记录providers加载时间，避免onPageShow时重复加载
    this.lastProvidersReloadTime = Date.now();
    Logger.info('ChatPage', `初始化完成，providers加载时间已记录: ${this.lastProvidersReloadTime}`);
    
    // 如果有目标会话ID，切换到指定会话
    if (this.targetSessionId) {
      Logger.info('ChatPage', `准备切换到目标会话: ${this.targetSessionId}`);
      try {
        const success = await this.chatViewModel.switchToSession(this.targetSessionId);
        if (success) {
          Logger.info('ChatPage', `成功切换到会话: ${this.targetSessionId}`);
        } else {
          Logger.warn('ChatPage', `切换会话失败: ${this.targetSessionId}`);
        }
      } catch (error) {
        Logger.error('ChatPage', `切换会话异常: ${error}`);
      }
      // 清除目标会话ID
      this.targetSessionId = '';
    }
    
    // 初始加载完成后滚动到最新消息
    this.scrollToBottom();

    // 同步消息列表到本地副本，用于监听变化
    this.messages = [...this.chatViewModel.messages];

    // 初始化用户资料管理器
    try {
      await this.userProfileManager.initialize();
      const currentProfile = this.userProfileManager.getCurrentProfile();
      if (currentProfile) {
        this.userName = currentProfile.userName;
        this.userSignature = currentProfile.userSignature;
        this.userAvatarType = currentProfile.userAvatarType;
        this.userAvatarValue = currentProfile.userAvatarValue;
        Logger.info('ChatPage', `用户资料加载成功: ${this.userName}`);
      }
    } catch (error) {
      Logger.error('ChatPage', `初始化用户资料管理器失败: ${error}`);
    }

    // 加载AI头像设置
    try {
      const avatarSettings = await StorageManager.getAvatarSettings();
      this.aiAvatarType = avatarSettings.aiAvatarType;
      this.aiAvatarValue = avatarSettings.aiAvatarValue;
      Logger.info('ChatPage', `AI头像设置加载成功: ${JSON.stringify(avatarSettings)}`);
    } catch (error) {
      Logger.error('ChatPage', `加载AI头像设置失败: ${error}`);
    }

    // 加载消息布局偏好
    try {
      const initialLayout = this.useModernMessageLayout; // 记录初始值(通常为false)
      this.useModernMessageLayout = await StorageManager.getMessageLayoutPreference();
      Logger.info('ChatPage', `消息布局偏好加载成功: ${this.useModernMessageLayout ? '现代布局' : '传统气泡'}`);
      
      // 如果初始状态与存储不一致，记录信息（通常初始值为false，所以只在存储为true时记录）
      if (initialLayout !== this.useModernMessageLayout && this.useModernMessageLayout) {
        Logger.info('ChatPage', `初始化时更新布局状态: ${initialLayout ? '现代' : '传统'} -> ${this.useModernMessageLayout ? '现代' : '传统'}`);
      }
    } catch (error) {
      Logger.error('ChatPage', `加载消息布局偏好失败: ${error}`);
    }

    // 初始化字体管理器并加载字体设置
    try {
      await this.fontManager.initialize();
      this.fontSettings = this.fontManager.getFontSettings();
      Logger.info('ChatPage', `字体设置加载成功: ${JSON.stringify(this.fontSettings)}`);
    } catch (error) {
      Logger.error('ChatPage', `初始化字体管理器失败: ${error}`);
    }

    // 获取动态状态栏高度
    const storedHeight = AppStorage.get<number>('statusBarHeight');
    if (storedHeight && storedHeight > 0) {
      this.statusBarHeight = storedHeight;
      Logger.info('ChatPage', `状态栏高度获取成功: ${this.statusBarHeight}vp`);
    } else {
      Logger.info('ChatPage', '使用默认状态栏高度44vp');
    }
    
    // 从APIManager同步功能状态
    try {
      const currentFeatures = this.chatViewModel.apiManager.getCurrentFeatures();
      this.enableWebSearch = currentFeatures.enableWebSearch;
      this.enableDeepThinking = currentFeatures.enableDeepThinking;
      Logger.info('ChatPage', `功能状态同步完成: 联网搜索=${this.enableWebSearch}, 深度思考=${this.enableDeepThinking}, MCP工具=${currentFeatures.enableMCPTools}`);
    } catch (error) {
      Logger.error('ChatPage', `同步功能状态失败: ${error}`);
      // 使用默认状态
      this.enableWebSearch = false;
      this.enableDeepThinking = false;
    }
    
    // 添加头像设置监听器
    StorageManager.addAvatarListener(this.avatarListener);

    // 添加字体设置监听器
    this.fontManager.addListener(this.fontSettingsListener);

    // 添加输入法状态监听器
    this.setupInputMethodListener();
    
    // 初始化服务器配置记录
    this.lastServerConfig = this.getCurrentServerConfigString();
    
    Logger.info('ChatPage', `加载完成 - 消息: ${this.chatViewModel.messages.length}, 提示词: ${this.chatViewModel.systemPrompts.length}, 深色: ${this.isDarkMode}`);
    
    if (this.chatViewModel.systemPrompts.length > 0) {
      // 系统提示词列表详情仅在调试时输出
    }

    // 初始化消息变化检测状态
    this.lastMessageCount = this.chatViewModel.messages.length;
    this.messages = [...this.chatViewModel.messages];

    // 初始化最后一条助手消息内容
    if (this.chatViewModel.messages.length > 0) {
      const lastMessage = this.chatViewModel.messages[this.chatViewModel.messages.length - 1];
      if (lastMessage.role === MessageRole.ASSISTANT) {
        this.lastAssistantMessageContent = lastMessage.content;
      }
    }

    // 启动消息变化检测定时器
    this.startMessageChangeTimer();
  }

  async onPageShow(): Promise<void> {
    // 页面显示时重新加载系统提示词，确保从管理页面返回后数据是最新的
    Logger.info('ChatPage', '页面显示，重新加载系统提示词');
    await this.chatViewModel.loadSystemPrompts();
    Logger.info('ChatPage', `系统提示词已更新，当前有 ${this.chatViewModel.systemPrompts.length} 条`);
    
    // 页面显示时重新加载会话列表，确保数据同步
    Logger.info('ChatPage', '页面显示，重新加载会话列表');
    await this.chatViewModel.loadSessions();
    Logger.info('ChatPage', `会话列表已更新，当前有 ${this.chatViewModel.sessions.length} 个会话`);
    
    // 重新加载当前会话，确保系统提示词等信息是最新的（必须在loadSessions之后）
    Logger.info('ChatPage', '页面显示，重新加载当前会话');
    await this.chatViewModel.loadCurrentSession();
    Logger.info('ChatPage', `当前会话已更新: ${this.chatViewModel.currentSession?.name || 'null'}`);
    
    
    // 页面显示时重新加载消息布局偏好，确保从设置页面返回后布局设置生效
    try {
      const previousLayout = this.useModernMessageLayout;
      const storedLayout = await StorageManager.getMessageLayoutPreference();
      
      // 检查状态一致性：如果当前状态与存储不一致，记录警告并以存储为准
      if (previousLayout !== storedLayout) {
        Logger.warn('ChatPage', `检测到状态不一致 - UI状态: ${previousLayout ? '现代' : '传统'}, 存储状态: ${storedLayout ? '现代' : '传统'}，以存储状态为准`);
      }
      
      this.useModernMessageLayout = storedLayout;
      
      if (previousLayout !== this.useModernMessageLayout) {
        Logger.info('ChatPage', `消息布局偏好已更新: ${previousLayout ? '现代' : '传统'} -> ${this.useModernMessageLayout ? '现代' : '传统'}`);
      } else {
        Logger.debug('ChatPage', `消息布局偏好未变更: ${this.useModernMessageLayout ? '现代' : '传统'}`);
      }
    } catch (error) {
      Logger.error('ChatPage', `重新加载消息布局偏好失败: ${error}`);
    }

    // 重新加载头像设置，确保从设置页面返回后头像是最新的
    try {
      Logger.info('ChatPage', '页面显示，重新加载头像设置');
      const avatarSettings = await StorageManager.getAvatarSettings();
      this.aiAvatarType = avatarSettings.aiAvatarType;
      this.aiAvatarValue = avatarSettings.aiAvatarValue;
      Logger.info('ChatPage', `AI头像设置已更新: ${JSON.stringify(avatarSettings)}`);
      
      // 重新加载用户头像设置
      const currentProfile = this.userProfileManager.getCurrentProfile();
      if (currentProfile) {
        this.userAvatarType = currentProfile.userAvatarType;
        this.userAvatarValue = currentProfile.userAvatarValue;
        Logger.info('ChatPage', `用户头像设置已更新: ${currentProfile.userAvatarType}, ${currentProfile.userAvatarValue}`);
      }
    } catch (error) {
      Logger.error('ChatPage', `重新加载头像设置失败: ${error}`);
    }

    // 重新加载字体设置，确保从设置页面返回后字体设置是最新的
    try {
      Logger.info('ChatPage', '页面显示，重新加载字体设置');
      const previousFontSettings = this.fontSettings;

      // 直接从AppStorage获取最新字体设置，避免FontManager异步通知延迟问题
      const latestFontSettings = await StorageManager.getFontSettings();

      Logger.info('ChatPage', `当前本地字体设置: ${JSON.stringify(previousFontSettings)}`);
      Logger.info('ChatPage', `AppStorage最新字体设置: ${JSON.stringify(latestFontSettings)}`);

      this.fontSettings = latestFontSettings;

      // 检查字体设置是否有变化
      if (previousFontSettings.chatFontSize !== this.fontSettings.chatFontSize ||
          previousFontSettings.codeFontSize !== this.fontSettings.codeFontSize ||
          previousFontSettings.fontFamily !== this.fontSettings.fontFamily) {
        Logger.info('ChatPage', `字体设置已更新: ${JSON.stringify(this.fontSettings)}`);
      } else {
        Logger.info('ChatPage', '字体设置未变更');
      }
    } catch (error) {
      Logger.error('ChatPage', `重新加载字体设置失败: ${error}`);
    }

    // 页面显示时检查模型配置是否过期，清理过期配置
    try {
      const isExpired = await StorageManager.isModelConfigExpired();
      if (isExpired) {
        Logger.info('ChatPage', '检测到模型配置已过期并已清理，将重新加载providers以应用默认选择');
      }
    } catch (error) {
      Logger.warn('ChatPage', `检查模型配置过期失败: ${error}`);
    }

    // 页面显示时检查是否需要重新加载providers（只在明确需要时才重新加载）
    // 检查服务器配置是否变更
    const currentServerConfig = this.getCurrentServerConfigString();
    const serverConfigChanged = this.lastServerConfig && this.lastServerConfig !== currentServerConfig;
    
    // 只在以下情况才重新加载providers：
    // 1. 强制刷新标记被设置（用户主动触发）
    // 2. 服务器配置确实发生了变更
    const shouldReload = this.forceReloadProviders || serverConfigChanged;
    
    if (shouldReload) {
      const reason = this.forceReloadProviders ? '用户主动刷新' :
                    serverConfigChanged ? '服务器配置变更' : '未知原因';
      
      Logger.info('ChatPage', `页面显示，重新加载providers (原因: ${reason})`);
      await this.chatViewModel.loadProviders();
      Logger.info('ChatPage', `Providers已更新，当前有 ${this.chatViewModel.providers.length} 个厂商`);
      
      this.lastProvidersReloadTime = Date.now();
      this.forceReloadProviders = false; // 重置强制刷新标记
      this.lastServerConfig = currentServerConfig; // 更新服务器配置记录
    } else {
      Logger.debug('ChatPage', 'providers无需重新加载，配置未变更');
      // 仍然更新配置记录，确保下次比较的准确性
      this.lastServerConfig = currentServerConfig;
    }
    
    // 页面显示时滚动到最新消息
    this.scrollToBottom();
  }

  aboutToDisappear(): void {
    this.chatViewModel.destroy();
    
    // 移除主题监听器
    this.themeManager.removeThemeListener((isDark: boolean) => {
      this.isDarkMode = isDark;
    });
    // 移除沉浸式模式监听器
    this.themeManager.removeImmersiveListener((isImmersive: boolean) => {
      this.isImmersiveMode = isImmersive;
    });
    // 移除头像设置监听器
    StorageManager.removeAvatarListener(this.avatarListener);
    // 移除字体设置监听器
    this.fontManager.removeListener(this.fontSettingsListener);
    // 清空自动播报回调，避免重复注册
    this.autoTTSService.setCallbacks({});
    
    // 移除输入法状态监听器
    this.cleanupInputMethodListener();

    // 停止消息变化检测定时器
    this.stopMessageChangeTimer();
  }

  onBackPress(): boolean | void {
    // 处理返回键，防止直接退出应用
    return this.handleBackPress();
  }

  build() {
    Stack() {
      // 主页面内容
      Column() {
        // 顶部导航栏 - 添加状态栏高度避让
        Column() {
          this.buildNavigationBar()
        }
        .margin({ top: this.statusBarHeight })

        // 加载指示器
        if (this.chatViewModel.isLoading && this.chatViewModel.messages.length === 0) {
          this.buildLoadingIndicator()
        } else {
          // 聊天消息列表
          this.buildMessageList()
        }

        // 底部输入区域
        this.buildInputArea()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_color'))
      .onTouch((event) => {
        // 如果快速指令面板正在显示，不处理这里的触摸事件，避免干扰
        if (this.showQuickCommands) {
          Logger.info('ChatPage', 'showQuickCommands=true，跳过主页面触摸处理');
          return;
        }
        
        // 如果正在滑动侧边栏，不处理触摸事件
        if (this.isSideDrawerSwipeActive) {
          return;
        }
        
        // 点击空白区域关闭输入法，但避免干扰输入框操作
        if (event.type === TouchType.Up && this.shouldCloseInputMethod) {
          try {
            inputMethod.getController().stopInputSession();
          } catch (error) {
            Logger.error('ChatPage', `关闭输入法失败: ${error}`);
          }
        }
        // 空白区域被点击后，重置标记为允许关闭输入法
        if (event.type === TouchType.Down) {
          this.shouldCloseInputMethod = true;
        }
      })

      if (this.voiceOverlayHint) {
        this.buildVoiceOverlayHint(this.voiceOverlayHint)
      }

      // 模型选择组件
      if (this.showModelSelector) {
        Column() {
          // 透明遮罩层
          Column() {}
          .layoutWeight(1)
          .width('100%')
          .backgroundColor('rgba(0, 0, 0, 0.0)')
          .opacity(this.modelSelectorOpacity)
          .onClick(() => {
            this.hideModelSelector();
          })

          // 半模态组件
          ModelSelectorComponent({
            providers: this.chatViewModel.providers,
            currentProvider: this.chatViewModel.currentProvider,
            currentModel: this.chatViewModel.currentModel,
            onModelSelected: async (provider: string, model: string) => {
              await this.chatViewModel.switchModel(provider, model);
              this.hideModelSelector();
            },
            onClose: () => {
              this.hideModelSelector();
            },
            onConfigureAPIKeys: () => {
              router.pushUrl({ url: 'pages/APIKeyManagerPage' });
            },
            onReloadProviders: async () => {
              Logger.info('ChatPage', '用户请求重新加载模型列表');
              try {
                await this.chatViewModel.loadProviders();
                Logger.info('ChatPage', `重新加载完成，当前有 ${this.chatViewModel.providers.length} 个厂商`);
              } catch (error) {
                Logger.error('ChatPage', `重新加载模型列表失败: ${error}`);
              }
            }
          })
            .borderRadius({ topLeft: 32, topRight: 32 })
            .translate({ y: this.modelSelectorTranslateY })
            .animation({
              duration: 400,
              curve: curves.springMotion(0.6, 0.8)
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .borderRadius({ topLeft: 32, topRight: 32 })
      }


      
      // 快捷指令组件 - 确保在工具箱面板之上
      if (this.showQuickCommands) {
        QuickCommandsComponent({
          commands: this.getQuickCommands(),
          phrases: [],
          onClose: () => {
            this.showQuickCommands = false;
          },
          onPromptSelected: (prompt: string) => {
            this.handlePromptSelected(prompt);
          }
        })
      }

      // 侧滑抽屉组件 - 移到最后确保在最顶层
      if (this.showSideDrawer) {
        SideDrawerComponent({
          onClose: () => {
            this.showSideDrawer = false;
            // 平滑重置滑动进度，使用更平滑的动画参数减少抖动
            animateTo({
              duration: 250,
              curve: Curve.EaseOut
            }, () => {
              this.sideDrawerSwipeProgress = 0;
            });
          },
          onSessionSwitched: () => {
            // 会话切换成功后滚动到最新消息
            this.scrollToBottom();
          },
          chatViewModel: this.chatViewModel,
          sessions: this.chatViewModel.sessions, // 单独传递sessions数组确保响应式更新
          systemPrompts: this.chatViewModel.systemPrompts, // 传递系统提示词列表用于显示
          swipeProgress: this.sideDrawerSwipeProgress,
          isSwipeActive: this.isSideDrawerSwipeActive,
          onSessionSwipeStateChange: (isSwiping: boolean) => {
            this.handleSessionSwipeStateChange(isSwiping);
          }
        })
      }

      // 左侧滑动提示条（只在未显示侧边栏时显示）
      if (!this.showSideDrawer && !this.isSideDrawerSwipeActive) {
        Column()
          .width(4)
          .height(60)
          .backgroundColor($r('app.color.primary_color'))
          .position({ x: 0, y: '50%' })
          .translate({ y: -30 })
          .borderRadius({ topRight: 2, bottomRight: 2 })
          .opacity(0.3)
      }
      
            
      // 搜索详情弹框 - 支持内容选中复制
      SearchDetailsDialog({
        isVisible: this.showSearchDetailsDialog,
        content: this.searchDetailsContent,
        onClose: () => {
          this.hideSearchDetailsDialog();
        }
      })
            
      // 深度思考对话框 - 在最顶层显示
      DeepThinkingDialog({
        isShowing: this.showThinkingDialog,
        message: this.thinkingDialogMessage,
        onClose: () => {
          this.hideDeepThinkingDialog();
        },
        onShowDetails: (step) => {
          this.handleThinkingStepTap(step);
        }
      })
    }
    .width('100%')
    .height('100%')
    .onTouch((event) => {
      // 如果快速指令面板正在显示，不处理这里的触摸事件，避免干扰
      if (this.showQuickCommands) {
        return;
      }
      
      // 如果正在滑动侧边栏，不处理触摸事件
      if (this.isSideDrawerSwipeActive) {
        return;
      }
      
      // 如果工具箱面板正在显示，点击空白区域关闭面板
      if (this.showToolboxPanel && event.type === TouchType.Up) {
        this.hideToolboxPanel();
        return;
      }
      
      // 点击空白区域关闭输入法，但避免干扰输入框操作
      if (event.type === TouchType.Up && this.shouldCloseInputMethod) {
        try {
          inputMethod.getController().stopInputSession();
        } catch (error) {
          Logger.error('ChatPage', `关闭输入法失败: ${error}`);
        }
      }
      // 空白区域被点击后，重置标记为允许关闭输入法
      if (event.type === TouchType.Down) {
        this.shouldCloseInputMethod = true;
      }
    })
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 5 })
        .onActionStart((event: GestureEvent) => {
          if (this.showQuickCommands) {
            return;
          }
          this.handleSideDrawerSwipeStart(event);
        })
        .onActionUpdate((event: GestureEvent) => {
          if (this.showQuickCommands) {
            return;
          }
          this.handleSideDrawerSwipeUpdate(event);
        })
        .onActionEnd((event: GestureEvent) => {
          if (this.showQuickCommands) {
            return;
          }
          this.handleSideDrawerSwipeEnd(event);
        })
    )
    // .bindSheet($$this.showPromptSelector, this.systemPromptSheetBuilder(), { // 已注释：不再使用系统提示词选择器
    //   height: '70%',
    //   dragBar: true,
    //   backgroundColor: $r('app.color.surface_color')
    // })
  }

  @Builder
  buildModelSelectorButton() {
    Row({ space: 6 }) {
      // 厂商图标
      Circle({ width: 20, height: 20 })
        .fill(this.getProviderColor())
      
      // 模型信息
      Column({ space: 1 }) {
        Text(this.getShortModelName())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        
        Text(this.getProviderDisplayName())
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: 60 })
      
      // 下拉箭头
      Text('▼')
        .fontSize(10)
        .fontColor($r('app.color.text_secondary'))
    }
    .height(36)
    .padding({ left: 6, right: 6 })
    .backgroundColor($r('app.color.input_background'))
    .borderRadius(18)
    .border({
      width: 1,
      color: $r('app.color.border_color')
    })
    .onClick(() => {
      this.showModelSelectorMethod();
    })
  }

  @Builder
  private buildNavigationIcon(
    symbol: string,
    onClick: () => void,
    options: NavigationIconOptions = {}
  ) {
    Button() {
      Text(symbol)
        .fontSize(14)
        .fontColor((options.active ?? false) ?
          (options.activeColor ?? $r('app.color.primary_color')) :
          (options.inactiveColor ?? $r('app.color.text_secondary')))
    }
    .width(32)
    .height(32)
    .backgroundColor(Color.Transparent)
    .borderWidth(1)
    .borderColor((options.active ?? false) ?
      (options.activeBorderColor ?? (options.activeColor ?? $r('app.color.primary_color'))) :
      (options.inactiveBorderColor ?? $r('app.color.border_color')))
    .borderRadius(16)
    .onClick(onClick)
  }

  @Builder
  buildPromptSelectorButton() {
    Row({ space: 6 }) {
      // 提示词图标
      Text('🎯')
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
      
      // 提示词信息
      Column({ space: 1 }) {
        Text('系统提示词')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        
        Text('系统提示词')
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: 80 })
      
      // 下拉箭头
      Text('▼')
        .fontSize(10)
        .fontColor($r('app.color.text_secondary'))
    }
    .height(36)
    .padding({ left: 8, right: 8 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(18)
    .margin({ left: 8 })
  }


  @Builder
  private buildVoiceOverlayHint(hint: VoiceOverlayHint) {
    Column() {
      Text(hint.text)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getVoiceOverlayTextColor(hint))
        .textAlign(TextAlign.Center)
        .padding({ left: 20, right: 20, top: 12, bottom: 12 })
        .backgroundColor(this.getVoiceOverlayBackgroundColor(hint))
        .borderRadius(18)
        .opacity(0.94)
        .shadow({
          radius: 8,
          color: 'rgba(0, 0, 0, 0.25)',
          offsetY: 4
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(2)
  }

  private getVoiceOverlayBackgroundColor(hint: VoiceOverlayHint): string {
    switch (hint.tone) {
      case 'warning':
        return 'rgba(255, 77, 79, 0.92)';
      case 'processing':
        return this.isDarkMode ? 'rgba(116, 185, 255, 0.9)' : 'rgba(52, 152, 219, 0.9)';
      default:
        return this.isDarkMode ? 'rgba(0, 0, 0, 0.85)' : 'rgba(0, 0, 0, 0.72)';
    }
  }

  private getVoiceOverlayTextColor(_: VoiceOverlayHint): string {
    return '#FFFFFF';
  }

  @Builder
  buildLoadingIndicator() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .margin({ bottom: 16 })
      Text('正在加载模型...')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .layoutWeight(1)
  }

  @Builder
  buildNavigationBar() {
    Row({ space: 12 }) {
      // 左侧：会话抽屉入口
      Button() {
        Text('☰')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width(32)
      .height(32)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.showSideDrawer = true;
      })

      Blank()

      // 右侧：功能按钮组
      Row({ space: 8 }) {
        this.buildNavigationIcon(this.isMuted ? '🤫' : '🗣️', () => {
          void this.toggleMute();
        }, {
          active: this.isMuted,
          activeColor: $r('app.color.error_color'),
          inactiveColor: $r('app.color.text_primary')
        })

        this.buildNavigationIcon('⚡', () => {
          if (this.showToolboxPanel) {
            this.hideToolboxPanel();
          }
          this.showQuickCommands = true;
        }, {
          active: this.showQuickCommands,
          activeColor: $r('app.color.primary_color'),
          inactiveColor: $r('app.color.primary_color'),
          inactiveBorderColor: $r('app.color.primary_color')
        })

        Row() {
          this.buildModelSelectorButton()
        }
        .alignItems(VerticalAlign.Center)

        this.buildNavigationIcon('⋮', () => {
          router.pushUrl({ url: 'pages/SettingsPage' });
        })
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.surface_color'))
    .alignItems(VerticalAlign.Center)
    .shadow({
      radius: 4,
      color: '#1F000000',
      offsetY: 2
    })
  }

  @Builder
  buildMessageList() {
    List({ space: 8, scroller: this.listScroller }) {
      ForEach(this.chatViewModel.messages, (message: Message, index: number) => {
        ListItem() {
          this.buildMessageItem(message)
        }
        .width('100%')
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY.animation({
            duration: BasicAnimations.STANDARD_DURATION,
            curve: Curve.EaseInOut
          }).combine(TransitionEffect.translate({ x: message.role === MessageRole.USER ? 50 : -50, y: 0 })),
          TransitionEffect.OPACITY.animation({
            duration: BasicAnimations.QUICK_DURATION,
            curve: Curve.EaseInOut
          }).combine(TransitionEffect.translate({ x: message.role === MessageRole.USER ? -50 : 50, y: 0 }))
        ))
      }, (message: Message) => message.id)
    }
    .width('100%')
    .layoutWeight(1)
    .padding(16)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  buildMessageItem(message: Message) {
    if (this.useModernMessageLayout) {
      this.buildModernMessageItem(message);
    } else {
      this.buildTraditionalMessageItem(message);
    }
  }

  @Builder
  buildTraditionalMessageItem(message: Message) {
    Row() {
      if (message.role === MessageRole.USER) {
        Blank()
        
        Column() {
          Text(message.content.trim())
            .fontSize(this.fontSettings.chatFontSize)
            .fontColor(Color.White)
            .textAlign(TextAlign.Start)
            .maxLines(100)
            .copyOption(CopyOptions.InApp)
        }
        .backgroundColor($r('app.color.primary_color'))
        .borderRadius(12)
        .padding(12)
        .constraintSize({ maxWidth: '70%' })
        
        Column() {
          this.buildUserAvatar()
        }
        .margin({ left: 8 })
      } else {
        // AI助手消息 - 传统布局：头像在左侧，消息在右侧
        Row() {
          // 左侧头像
          Column() {
            this.buildAIAvatar()
          }
          .margin({ right: 8 })
          .width(36)
          .height(36)
          
          // 右侧消息内容区域
          Column() {
            // 消息头部：角色标签和音频按钮
            Row() {
              Text(`${message.isDeepThinking ? '🧠 ' : ''}${this.chatViewModel.getCurrentSessionSystemPrompt()?.name || 'AI助手'}`)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.modern_role_label'))
              
              // 语音播报按钮 - 只有assistant消息且不在加载中才显示
              if (message.canPlayAudio && !message.isLoading) {
                Button() {
                  Text(message.isPlaying ? '🔇' : '🔊')
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                }
                .width(32)
                .height(32)
                .backgroundColor(message.isPlaying ? $r('app.color.error_color') : $r('app.color.surface_color'))
                .borderRadius(16)
                .border({
                  width: 1,
                  color: message.isPlaying ? $r('app.color.error_color') : $r('app.color.border_color')
                })
                .margin({ left: 8 })
                .onClick(() => {
                  this.toggleMessageAudio(message);
                })
              }
            }
            .width('100%')
            .margin({ bottom: 4 })
            
            this.buildDeepThinkingInlineStatus(message, '70%')
            
            // 消息内容气泡
          Column() {
            if (message.isLoading) {
              this.buildLoadingStatus(this.enableDeepThinking ? '🧠 AI正在深度分析，请稍候...' : 'AI正在思考...')
            } else if (message.toolStatus === 'calling') {
              this.buildLoadingStatus('🔍 正在搜索网络信息...', true)
            } else {
              Column() {
                  // 消息内容
                  Text(message.content.trim())
                    .fontSize(this.fontSettings.chatFontSize)
                    .fontColor($r('app.color.text_primary'))
                    .textAlign(TextAlign.Start)
                    .maxLines(100)
                    .copyOption(CopyOptions.InApp)

                  // 网络搜索标识
                  if (message.webUsed && message.searchInfo) {
                    Row() {
                      Row() {
                        Text('🔍')
                          .fontSize(12)
                          .animation({
                            duration: message.toolStatus === 'calling' ? 1000 : 0,
                            curve: Curve.EaseInOut,
                            iterations: message.toolStatus === 'calling' ? -1 : 1,
                            playMode: PlayMode.Alternate
                          })
                        Text('网络搜索')
                          .fontSize(12)
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.primary_color'))
                      }
                      .padding({ right: 8 })

                      // 截断显示搜索信息
                      Text(this.truncateSearchInfo(message.searchInfo ?? ""))
                        .fontSize(12)
                        .fontColor($r('app.color.text_secondary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .margin({ top: 8 })
                    .padding({ top: 6, bottom: 6, left: 12, right: 12 })
                    .backgroundColor($r('app.color.card_background'))
                    .borderRadius(16)
                    .border({
                      width: 1,
                      color: $r('app.color.primary_color')
                    })
                    .shadow({
                      radius: 2,
                      color: '#1A000000',
                      offsetY: 1
                    })
                    .onClick((event) => {
                      // 点击搜索标识显示详细信息气泡
                      Logger.info('ChatPage', `搜索标识被点击，searchDetails存在: ${!!message.searchDetails}, 长度: ${message.searchDetails?.length || 0}`);
                      Logger.info('ChatPage', `点击位置: (${event.displayX}, ${event.displayY})`);
                      
                      if (message.searchDetails) {
                        Logger.info('ChatPage', '准备显示搜索详情气泡');
                        this.showSearchInfoBubble(message.searchDetails);
                      } else {
                        Logger.info('ChatPage', 'searchDetails为空，不显示气泡');
                      }
                    })
                  }
                }
              }
            }
            .backgroundColor($r('app.color.card_background'))
            .borderRadius(12)
            .padding(12)
            .constraintSize({ maxWidth: '70%' })
            .shadow({
              radius: 2,
              color: '#1A000000',
              offsetY: 1
            })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .alignItems(VerticalAlign.Top)
        
        Blank()
      }
    }
    .width('100%')
    .margin({ bottom: 8 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildDeepThinkingInlineStatus(message: Message, maxWidth: string) {
    if (!message.isDeepThinking) {
      Blank();
    } else {
      DeepThinkingStatusCard({
        message: message,
        onShowDetails: () => {
          this.showDeepThinkingDialog(message);
        },
        onStop: () => {
          this.chatViewModel.stopDeepThinking(message.id);
        }
      })
        .constraintSize({ maxWidth: maxWidth })
        .width(maxWidth)
        .margin({ bottom: 8 })
    }
  }

  @Builder
  buildModernMessageItem(message: Message) {
    Column() {
      // 消息头部：角色 + 头像
      Row() {
        if (message.role === MessageRole.USER) {
          Blank()
          
          Text('Javis')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.modern_role_label'))
            .margin({ right: 8 })
          
          this.buildUserAvatar()
        } else {
          Row() {
            this.buildAIAvatar()
            
            Text(`${message.isDeepThinking ? '🧠 ' : ''}${this.chatViewModel.getCurrentSessionSystemPrompt()?.name || 'AI助手'}`)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.modern_role_label'))
              .margin({ left: 8 })
            
            // 语音播报按钮 - 只有assistant消息且不在加载中才显示
            if (message.canPlayAudio && !message.isLoading) {
              Button() {
                Text(message.isPlaying ? '🔇' : '🔊')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
              }
              .width(32)
              .height(32)
              .backgroundColor(message.isPlaying ? $r('app.color.error_color') : $r('app.color.surface_color'))
              .borderRadius(16)
              .border({
                width: 1,
                color: message.isPlaying ? $r('app.color.error_color') : $r('app.color.border_color')
              })
              .margin({ left: 8 })
              .onClick(() => {
                this.toggleMessageAudio(message);
              })
            }
            
            Blank()
          }
        }
      }
      .width('100%')
      .margin({ bottom: 6 })
      
      // 消息内容区域
      Column() {
        if (message.role === MessageRole.USER) {
          // 用户消息内容 - 右对齐
          Row() {
            Blank()
            
            Text(message.content.trim())
              .fontSize(this.fontSettings.chatFontSize)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Start)
              .maxLines(100)
              .copyOption(CopyOptions.InApp)
              .padding(14)
              .backgroundColor($r('app.color.modern_user_background'))
              .borderRadius(12)
              .border({
                width: 1,
                color: $r('app.color.border_color')
              })
              .constraintSize({ maxWidth: '82%' })
              .shadow({
                radius: 2,
                color: 'rgba(0, 0, 0, 0.06)',
                offsetY: 1
              })
          }
          .width('100%')
        } else {
          // AI消息内容
          Row() {
            Column() {
              this.buildDeepThinkingInlineStatus(message, '80%')
              if (message.isLoading) {
                this.buildLoadingStatus(this.enableDeepThinking ? '🧠 AI正在深度分析，请稍候...' : 'AI正在思考...')
              } else if (message.toolStatus === 'calling') {
                this.buildLoadingStatus('🔍 正在搜索网络信息...', true)
              } else {
                Column() {
                  // 工具调用状态展示
                  ToolCallStatusComponent({
                    message: message,
                    onSearchDetailsClick: (searchDetails: string) => {
                      this.showSearchInfoBubble(searchDetails);
                    }
                  })

                  // 智能渲染的消息内容
                  SmartTextRenderer({
                    content: message.content.trim(),
                    fontSettings: this.fontSettings
                  })
                }
              }
            }
            .padding(14)
            .backgroundColor($r('app.color.modern_ai_background'))
            .borderRadius(12)
            .border({
              width: 1,
              color: $r('app.color.border_color')
            })
            .constraintSize({ maxWidth: '82%' })
            .shadow({
              radius: 3,
              color: 'rgba(0, 0, 0, 0.08)',
              offsetY: 1
            })
            
            Blank()
          }
          .width('100%')
        }
      }
      .width('100%')
      
      // 分隔线
      Divider()
        .strokeWidth(1)
        .color($r('app.color.modern_separator'))
        .opacity(0.6)
        .margin({ top: 16, bottom: 4 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 8 })
  }

  @Builder
  buildInputArea() {
    Column() {
      // 功能按钮行（深度思考和联网搜索）
      Row({ space: 8 }) {
        // 深度思考按钮
        Button() {
          Row({ space: 4 }) {
            Text('🧠')
              .fontSize(16)
            Circle()
              .width(8)
              .height(8)
              .fill(this.enableDeepThinking ? '#FF6B35' : '#666666')
              .opacity(this.enableDeepThinking ? 1.0 : 0.5)
          }
        }
        .width(44)
        .height(32)
        .backgroundColor(this.enableDeepThinking ? 'rgba(255, 107, 53, 0.15)' : $r('app.color.input_background'))
        .borderRadius(16)
        .border({
          width: 1,
          color: this.enableDeepThinking ? '#FF6B35' : $r('app.color.border_color')
        })
        .stateStyles({
          normal: {
            .scale({ x: 1.0, y: 1.0 })
          },
          pressed: {
            .scale({ x: 0.95, y: 0.95 })
          }
        })
        .animation({
          duration: 150,
          curve: Curve.EaseInOut
        })
        .onClick(() => {
          this.toggleDeepThinking();
        })

        // 联网搜索按钮
        Button() {
          Row({ space: 4 }) {
            Text('🌐')
              .fontSize(16)
            Circle()
              .width(8)
              .height(8)
              .fill(this.enableWebSearch ? '#27AE60' : '#666666')
              .opacity(this.enableWebSearch ? 1.0 : 0.5)
          }
        }
        .width(44)
        .height(32)
        .backgroundColor(this.enableWebSearch ? 'rgba(39, 174, 96, 0.15)' : $r('app.color.input_background'))
        .borderRadius(16)
        .border({
          width: 1,
          color: this.enableWebSearch ? '#27AE60' : $r('app.color.border_color')
        })
        .stateStyles({
          normal: {
            .scale({ x: 1.0, y: 1.0 })
          },
          pressed: {
            .scale({ x: 0.95, y: 0.95 })
          }
        })
        .animation({
          duration: 150,
          curve: Curve.EaseInOut
        })
        .onClick(() => {
          this.toggleWebSearch();
        })

        Blank()
          .layoutWeight(1)

        // 工具箱入口按钮
        Button() {
          Row({ space: 6 }) {
            Text('🧰')
              .fontSize(14)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .height(32)
        .padding({ left: 14, right: 14 })
        .backgroundColor('rgba(116, 185, 255, 0.18)')
        .borderRadius(16)
        .border({
          width: 1,
          color: '#74B9FF'
        })
        .stateStyles({
          normal: {
            .scale({ x: 1.0, y: 1.0 })
          },
          pressed: {
            .scale({ x: 0.95, y: 0.95 })
          }
        })
        .animation({
          duration: 150,
          curve: Curve.EaseInOut
        })
        .onClick(() => {
          this.showToolboxPanelMethod();
        })
      }
      .width('95%')
      .margin({ left: 16, right: 16, bottom: 4 })

      // 当前会话绑定的系统提示词展示区域（只读）
      // Column() {
      //   this.buildCurrentSessionPromptDisplay()
      // }
      // .width('95%')
      // .margin({ left: 16, right: 16, bottom: 4 })
      
      // 主要输入区域容器 - 整体移动
      Column() {
        // 主输入行 - 包含输入框和按钮
        Row() {
          if (this.voiceInputMode === InputMode.TEXT) {
            TextArea({ 
              placeholder: this.getInputPlaceholder(), 
              text: this.inputText 
            })
              .layoutWeight(1)
              .height(this.inputAreaHeight)
              .backgroundColor($r('app.color.input_background'))
              .borderRadius(18)
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .border({
                width: 1,
                color: this.voiceRecognitionState === VoiceRecognitionState.RECORDING 
                  ? $r('app.color.primary_color') 
                  : $r('app.color.border_color')
              })
              .wordBreak(WordBreak.BREAK_WORD)
              .copyOption(CopyOptions.InApp)
              .onChange((value: string) => {
                this.inputText = value;
                // 动态计算并更新高度
                const newHeight = this.calculateInputHeight(value);
                if (this.inputAreaHeight !== newHeight) {
                  this.inputAreaHeight = newHeight;
                }
              })
              .onTouch((event: TouchEvent) => {
                // 输入框被触摸时，阻止全局关闭输入法
                this.shouldCloseInputMethod = false;
              })
              .onFocus(() => {
                // 输入框获得焦点时，设置键盘高度模拟值
                this.keyboardHeight = 300; // 模拟键盘高度
                Logger.debug('ChatPage', '输入框获得焦点，设置键盘显示状态');
              })
              .onBlur(() => {
                // 输入框失去焦点时，重置键盘高度
                this.keyboardHeight = 0;
                Logger.debug('ChatPage', '输入框失去焦点，清除键盘显示状态');
              })
          }

          // 语音输入按钮
          if (this.showVoiceInput) {
            VoiceInputComponent({
              onVoiceResult: this.handleVoiceComponentResult,
              onStateChange: this.handleVoiceComponentStateChange,
              onSmartPromptTriggered: this.handleVoiceComponentSmartPrompt,
              onInputModeChange: this.handleVoiceComponentModeChange,
              onHintChange: this.handleVoiceComponentHintChange
            })
              .margin({ left: this.voiceInputMode === InputMode.TEXT ? 6 : 0 })
              .width(this.voiceInputMode === InputMode.VOICE ? '100%' : 40)
              .layoutWeight(this.voiceInputMode === InputMode.VOICE ? 1 : 0)
          }

          Button() {
            Image($r('app.media.ic_send'))
              .width(18)
              .height(18)
              .fillColor(Color.White)
          }
          .width(38)
          .height(36)
          .backgroundColor(
            this.voiceInputMode === InputMode.TEXT && this.inputText.trim()
              ? $r('app.color.primary_color')
              : $r('app.color.border_color')
          )
          .borderRadius(18)
          .margin({ left: 6 })
          .enabled(
            this.voiceInputMode === InputMode.TEXT &&
            this.inputText.trim().length > 0 &&
            !this.chatViewModel.isLoading
          )
          .animation({
            duration: BasicAnimations.QUICK_DURATION,
            curve: Curve.EaseInOut
          })
          .onClick(() => {
            this.sendMessage();
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 6 })
        .onTouch((event) => {
          // 整个输入区域都不应该触发全局的输入法关闭
          this.shouldCloseInputMethod = false;
          
          // 如果在输入区域内开始滑动，停止侧边栏滑动检测
          if (event.type === TouchType.Down && this.isSideDrawerSwipeActive) {
            this.isSideDrawerSwipeActive = false;
            this.sideDrawerSwipeProgress = 0;
          }
        })
        
        // 工具箱面板 - 紧贴在输入区域下方
        if (this.showToolboxPanel) {
          Column() {
            // 拖拽指示器
            Row() {
              Column()
                .width(36)
                .height(4)
                .backgroundColor(this.isDarkMode ? '#555555' : '#E0E0E0')
                .borderRadius(2)
            }
            .width('100%')
            .height(20)
            .justifyContent(FlexAlign.Center)
            
            // 工具列表
            Column({ space: 0 }) {
              ForEach(this.getToolboxItems(), (item: ToolboxItem) => {
                this.buildToolboxItem(item);
              }, (item: ToolboxItem) => item.id);
            }
            .width('100%')
            .padding({ bottom: 8 })
          }
          .width('100%')
          .backgroundColor(this.isDarkMode ? '#2C2C2C' : '#FFFFFF')
          .borderRadius({
            topLeft: 20,
            topRight: 20
          })
          .shadow({
            radius: 12,
            color: 'rgba(0, 0, 0, 0.15)',
            offsetX: 0,
            offsetY: -4
          })
          .margin({ top: 4 })
          .opacity(this.toolboxPanelOpacity)
          .translate({ y: this.toolboxPanelTranslateY })
        }
      }
      .width('100%')
    }
    .backgroundColor($r('app.color.surface_color'))
    .constraintSize({ minHeight: 100, maxHeight: this.showToolboxPanel ? 450 : 300 })
    .padding({ top: 2, bottom: this.showToolboxPanel ? 6 : 12 })
  }

  /**
   * 处理侧边栏滑动开始
   */
  private handleSideDrawerSwipeStart(event: GestureEvent): void {
    // 如果有其他弹窗打开，不响应滑动
    if (this.showModelSelector || this.showQuickCommands) {
      return;
    }
    
    // 如果键盘正在显示（键盘高度大于0），不处理侧边栏滑动手势
    if (this.keyboardHeight > 0) {
      Logger.debug('ChatPage', `键盘正在显示(高度:${this.keyboardHeight})，不处理侧边栏滑动手势`);
      return;
    }
    
    // 如果会话项正在滑动，不处理侧边栏滑动手势
    if (this.isSessionItemSwiping) {
      Logger.debug('ChatPage', '会话项正在滑动，不处理侧边栏滑动手势');
      return;
    }
    
    // 如果滑动开始位置在侧边栏中央区域（遮罩层点击区域），不处理滑动
    const startX = event.fingerList[0]?.globalX || 0;
    const startY = event.fingerList[0]?.globalY || 0;
    const screenWidth = 360; // 大概的屏幕宽度，实际应该动态获取
    if (this.showSideDrawer && startX > 280) {
      // 点击在遮罩区域，不处理为滑动手势
      Logger.debug('ChatPage', '点击在遮罩区域，不处理滑动手势');
      return;
    }
    
    // 防抖检查：如果正在防抖中，忽略此次滑动
    const currentTime = Date.now();
    if (this.isSwipeDebouncing && (currentTime - this.lastSwipeTime) < this.SWIPE_DEBOUNCE_TIME) {
      Logger.debug('ChatPage', '滑动防抖中，忽略此次滑动开始');
      return;
    }
    
    Logger.info('ChatPage', '侧边栏滑动开始');
    this.isSideDrawerSwipeActive = true;
    this.sideDrawerSwipeProgress = this.showSideDrawer ? 1 : 0; // 根据当前状态设置初始进度
    this.swipeDirection = 'none';
    this.lastSwipeTime = currentTime;
    this.isSwipeDebouncing = false;
  }

  /**
   * 处理侧边栏滑动更新
   */
  private handleSideDrawerSwipeUpdate(event: GestureEvent): void {
    if (!this.isSideDrawerSwipeActive) {
      return;
    }

    const deltaX = event.offsetX;
    const currentTime = Date.now();
    
    // 检测滑动方向
    const currentDirection = deltaX > 5 ? 'right' : deltaX < -5 ? 'left' : 'none';
    
    // 方向变化防抖：如果方向变化过快，忽略此次更新
    if (this.swipeDirection !== 'none' && 
        currentDirection !== 'none' && 
        this.swipeDirection !== currentDirection &&
        (currentTime - this.lastSwipeTime) < this.DIRECTION_CHANGE_THRESHOLD) {
      Logger.debug('ChatPage', `方向变化过快，从 ${this.swipeDirection} 到 ${currentDirection}，忽略此次更新`);
      return;
    }
    
    // 更新滑动方向
    if (currentDirection !== 'none') {
      this.swipeDirection = currentDirection;
      this.lastSwipeTime = currentTime;
    }

    const maxSwipeDistance = this.SIDE_DRAWER_SWIPE_THRESHOLD * 1.5;
    let progress: number;
    
    // 统一的进度计算逻辑
    if (this.showSideDrawer) {
      // 侧边栏已打开：只响应向左滑动关闭
      if (deltaX >= 0) {
        // 向右滑动或静止，保持完全打开状态
        progress = 1;
      } else {
        // 向左滑动关闭，计算关闭进度
        progress = Math.max(0, 1 + deltaX / maxSwipeDistance);
      }
    } else {
      // 侧边栏已关闭：只响应向右滑动打开
      if (deltaX <= 0) {
        // 向左滑动或静止，保持完全关闭状态
        progress = 0;
      } else {
        // 向右滑动打开，计算打开进度
        progress = Math.min(deltaX / maxSwipeDistance, 1);
      }
    }
    
    this.sideDrawerSwipeProgress = progress;
    
    // 动态显示侧边栏（只在需要时显示，不在滑动过程中隐藏）
    if (progress > 0.05 && !this.showSideDrawer) {
      this.showSideDrawer = true;
      Logger.debug('ChatPage', '滑动进度超过阈值，显示侧边栏');
    }
    // 滑动过程中不隐藏侧边栏，避免闪烁，只在滑动结束时决定最终状态
  }

  /**
   * 处理侧边栏滑动结束
   */
  private handleSideDrawerSwipeEnd(event: GestureEvent): void {
    if (!this.isSideDrawerSwipeActive) {
      return;
    }

    const progress = this.sideDrawerSwipeProgress;
    const deltaX = event.offsetX;
    const currentTime = Date.now();
    
    Logger.info('ChatPage', `侧边栏滑动结束，滑动进度: ${progress.toFixed(2)}, 滑动距离: ${deltaX}, 方向: ${this.swipeDirection}`);
    
    // 启动防抖，防止快速连续操作
    this.isSwipeDebouncing = true;
    
    // 基于进度阈值和滑动速度综合判断
    const PROGRESS_THRESHOLD = this.SIDE_DRAWER_PROGRESS_THRESHOLD; // 30%的进度阈值
    const velocity = Math.abs(deltaX) / 200; // 简单速度计算
    
    let shouldOpen = false;
    
    if (this.swipeDirection === 'right') {
      // 向右滑动，意图是打开侧边栏，考虑速度因素
      shouldOpen = progress >= PROGRESS_THRESHOLD || velocity > 0.5;
    } else if (this.swipeDirection === 'left') {
      // 向左滑动，意图是关闭侧边栏，考虑速度因素
      shouldOpen = progress > (1 - PROGRESS_THRESHOLD) && velocity < 0.5;
    } else {
      // 无明确方向，基于当前进度判断
      shouldOpen = progress >= 0.5;
    }
    
    // 应用最终状态
    if (shouldOpen && !this.showSideDrawer) {
      this.showSideDrawer = true;
      Logger.info('ChatPage', '滑动结束，打开侧边栏');
    } else if (!shouldOpen && this.showSideDrawer) {
      this.showSideDrawer = false;
      Logger.info('ChatPage', '滑动结束，关闭侧边栏');
    } else {
      Logger.info('ChatPage', `滑动结束，保持当前状态: ${this.showSideDrawer ? '打开' : '关闭'}`);
    }
    
    // 重置滑动状态，但保持最终进度状态
    this.isSideDrawerSwipeActive = false;
    this.swipeDirection = 'none';
    
    // 使用更平滑的过渡动画
    animateTo({
      duration: 250,
      curve: Curve.EaseOut
    }, () => {
      this.sideDrawerSwipeProgress = this.showSideDrawer ? 1 : 0;
    });
    
    // 延迟重置防抖状态
    setTimeout(() => {
      this.isSwipeDebouncing = false;
      Logger.debug('ChatPage', '滑动防抖结束');
    }, this.SWIPE_DEBOUNCE_TIME);
  }

  private async sendMessage(isVoiceMessage: boolean = false): Promise<void> {
    if (!this.inputText.trim() || this.chatViewModel.isLoading) {
      return;
    }

    const message = this.inputText.trim();
    this.inputText = '';

    // 发送消息后关闭输入法，提升用户体验
    try {
      inputMethod.getController().stopInputSession();
    } catch (error) {
      Logger.error('ChatPage', `关闭输入法失败: ${error}`);
    }

    const sendPromise = this.chatViewModel.sendMessage(
      message,
      isVoiceMessage
    );

    // 先滚动让新消息立即可见，再等待处理完成
    this.scrollToBottom();

    try {
      await sendPromise;
    } finally {
      // 助手回复完成后再次确保停留在底部
      this.scrollToBottom();
    }
  }

  private async sendRecognizedVoiceText(message: string): Promise<void> {
    const trimmed = message.trim();
    if (!trimmed) {
      return;
    }

    if (this.chatViewModel.isLoading) {
      Logger.warn('ChatPage', '助手正在处理中，暂不发送新的语音消息');
      return;
    }

    const sendPromise = this.chatViewModel.sendMessage(
      trimmed,
      true
    );

    this.scrollToBottom();

    try {
      await sendPromise;
    } finally {
      this.scrollToBottom();
    }
  }

  /**
   * 处理语音识别结果
   */
  private async handleVoiceResult(text: string): Promise<void> {
    Logger.info('ChatPage', `收到语音识别结果: ${text}`);
    
    if (!text.trim()) {
      Logger.warn('ChatPage', '语音识别结果为空，忽略');
      return;
    }

    const trimmedResult = text.trim();

    if (!this.isMeaningfulVoiceResult(trimmedResult)) {
      Logger.warn('ChatPage', `语音识别结果仅包含标点，忽略: ${trimmedResult}`);
      promptAction.showToast({
        message: '没听清内容，请再说一遍~',
        duration: 2000
      });
      return;
    }

    if (this.voiceInputMode === InputMode.VOICE) {
      Logger.info('ChatPage', '语音模式下自动发送识别文本');
      await this.sendRecognizedVoiceText(trimmedResult);
      return;
    }

    this.inputText = trimmedResult;
    this.scrollToBottom();
    Logger.info('ChatPage', '语音识别结果已填入输入框，并滚动到底部');
  }

  private isMeaningfulVoiceResult(text: string): boolean {
    const sanitized = text.replace(/[\s\u3000]/g, '');
    if (!sanitized) {
      return false;
    }

    // 至少包含一个中文、英文字母或数字才认为是有效语句
    return /[\u4e00-\u9fa5A-Za-z0-9]/.test(sanitized);
  }

  /**
   * 处理智能prompt触发
   */
  private async handleSmartPrompt(prompt: string): Promise<void> {
    Logger.info('ChatPage', `收到智能prompt: ${prompt}`);
    
    if (!prompt.trim()) {
      Logger.warn('ChatPage', '智能prompt为空，忽略');
      return;
    }

    // 将智能prompt填入输入框
    this.inputText = prompt.trim();
    
    // 可以选择自动发送
    // await this.sendMessage();
    
    Logger.info('ChatPage', '智能prompt已填入输入框');
  }

  
  /**
   * 切换消息语音播报状态
   */
  private async toggleMessageAudio(message: Message): Promise<void> {
    if (!message.canPlayAudio) {
      Logger.warn('ChatPage', '消息不支持音频播放');
      return;
    }

    try {
      if (message.isPlaying) {
        Logger.info('ChatPage', `停止播放消息音频: ${message.id}`);
        // 如果正在播放，则停止
        await this.chatViewModel.stopMessageAudio(message.id);
        promptAction.showToast({
          message: '🔇 已停止播放',
          duration: 1000
        });
      } else {
        Logger.info('ChatPage', `开始播放消息音频: ${message.id}`);
        // 检查是否有其他消息正在播放，提供用户反馈
        if (this.chatViewModel.isAnyMessagePlaying()) {
          const currentPlaying = this.chatViewModel.getCurrentPlayingMessage();
          if (currentPlaying) {
            Logger.info('ChatPage', `检测到其他消息正在播放，将自动切换: ${currentPlaying.id}`);
          }
        }
        
        // 如果未在播放，则开始播放
        const success = await this.chatViewModel.playMessageAudio(message.id);
        if (success) {
          promptAction.showToast({
            message: '🔊 开始播放',
            duration: 1000
          });
        } else {
          promptAction.showToast({
            message: '播放失败',
            duration: 1500
          });
        }
      }
    } catch (error) {
      Logger.error('ChatPage', `切换语音播报失败: ${error}`);
      promptAction.showToast({
        message: '语音播报操作失败',
        duration: 1500
      });
    }
  }

  private getShortModelName(): string {
    const modelName = this.chatViewModel.currentModel;
    if (!modelName) return '选择模型';
    
    // 提取模型名称的主要部分
    if (modelName.includes('Qwen')) return 'Qwen';
    if (modelName.includes('Claude')) return 'Claude';  
    if (modelName.includes('DeepSeek')) return 'DeepSeek';
    if (modelName.includes('GPT')) return 'GPT';
    if (modelName.includes('gemma')) return 'Gemma';
    if (modelName.includes('ChatGLM')) return 'ChatGLM';
    
    // 如果包含'/'，取后面的部分
    if (modelName.includes('/')) {
      const parts = modelName.split('/');
      const lastPart = parts[parts.length - 1];
      return lastPart.length > 10 ? lastPart.substring(0, 10) + '...' : lastPart;
    }
    
    return modelName.length > 10 ? modelName.substring(0, 10) + '...' : modelName;
  }

  private getProviderDisplayName(): string {
    const provider = this.chatViewModel.currentProvider;
    switch (provider) {
      case 'siliconflow': return '硅基流动';
      case 'anthropic': return 'Anthropic';
      case 'openai': return 'OpenAI';
      case 'zhipu': return '智谱AI';
      default: return provider || '未知';
    }
  }

  private getProviderColor(): string {
    const provider = this.chatViewModel.currentProvider;
    switch (provider) {
      case 'siliconflow': return '#4285F4';
      case 'anthropic': return '#FF6B35';
      case 'openai': return '#00A67E';
      case 'zhipu': return '#5856D6';
      default: return '#666666';
    }
  }

  /**
   * 设置输入法状态监听器
   */
  private setupInputMethodListener(): void {
    Logger.info('ChatPage', '键盘状态监听通过输入框焦点状态检测');
  }

  /**
   * 清理输入法状态监听器
   */
  private cleanupInputMethodListener(): void {
    Logger.info('ChatPage', '键盘状态监听已清理');
  }

  // getSelectedPromptName方法已移除，不再使用全局选中状态

  private getQuickCommands(): QuickCommand[] {
    return [
      {
        id: 'clear',
        title: '清空对话',
        subtitle: '删除所有聊天记录，开始新的对话',
        icon: '🗑️',
        color: '#FF4757',
        backgroundColor: '#FFE8E8',
        action: () => {
          this.clearMessages();
        }
      },
      {
        id: 'compact',
        title: '压缩上下文',
        subtitle: '保留最近消息，压缩历史记录节省空间',
        icon: '📦',
        color: '#3742FA',
        backgroundColor: '#E8EAFF',
        action: () => {
          this.compactMessages();
        }
      },
      {
        id: 'network',
        title: this.enableWebSearch ? '关闭联网搜索' : '开启联网搜索',
        subtitle: this.enableWebSearch ? '直连模式联网搜索已启用，智能获取最新信息' : '开启联网搜索后，AI将获取最新网络信息',
        icon: '🌐',
        color: this.enableWebSearch ? '#FF4757' : '#27AE60',
        backgroundColor: this.enableWebSearch ? '#FFE8E8' : '#E8F8F5',
        action: () => {
          this.toggleWebSearch();
        }
      },
      {
        id: 'prompts',
        title: '提示词管理',
        subtitle: '管理和编辑系统提示词模板',
        icon: '🎯',
        color: '#8E44AD',
        backgroundColor: '#F3E8FF',
        action: () => {
          router.pushUrl({ 
            url: 'pages/SystemPromptManagerPage',
            params: { 
              fromChatPage: true,
              currentSessionId: this.chatViewModel.currentSession?.id || null
            }
          });
        }
      },
    ];
  }

  private async clearMessages(): Promise<void> {
    await this.chatViewModel.clearMessages();
  }

  private async toggleWebSearch(): Promise<void> {
    try {
      const currentState = !this.enableWebSearch;
      const result = await this.chatViewModel.apiManager.setFeature('enableWebSearch', currentState);

      if (result) {
        // 功能不支持
        promptAction.showToast({
          message: `❗ ${result}`,
          duration: 2000
        });
        return;
      }

      // 更新成功，同步本地状态
      this.enableWebSearch = currentState;
      Logger.info('ChatPage', `联网搜索状态切换: ${this.enableWebSearch}`);

      // 显示状态切换提示
      promptAction.showToast({
        message: this.enableWebSearch ? '🌐 联网搜索已开启' : '📱 已切换到离线模式',
        duration: 1500
      });
    } catch (error) {
      Logger.error('ChatPage', `切换联网搜索失败: ${error}`);
      promptAction.showToast({
        message: '❗ 联网搜索切换失败，请稍后重试',
        duration: 1500
      });
    }
  }

  private async toggleMute(): Promise<void> {
    try {
      const updatedSettings = await this.autoTTSService.toggleMuteState();
      this.isMuted = updatedSettings.muted;
      promptAction.showToast({
        message: this.isMuted ? '🤫 自动播报已静音' : '🗣️ 自动播报已恢复',
        duration: 1500
      });
    } catch (error) {
      Logger.error('ChatPage', `切换静音失败: ${error}`);
      promptAction.showToast({
        message: '❗ 静音切换失败，请稍后重试',
        duration: 1500
      });
    }
  }

  private async toggleDeepThinking(): Promise<void> {
    try {
      const currentState = !this.enableDeepThinking;
      const result = await this.chatViewModel.apiManager.setFeature('enableDeepThinking', currentState);

      if (result) {
        // 功能不支持
        promptAction.showToast({
          message: `❗ ${result}`,
          duration: 2000
        });
        return;
      }

      // 更新成功，同步本地状态
      this.enableDeepThinking = currentState;
      Logger.info('ChatPage', `深度思考状态切换: ${this.enableDeepThinking}`);

      // 显示状态切换提示
      promptAction.showToast({
        message: this.enableDeepThinking ? '🧠 深度思考模式已开启' : '💭 切换到普通模式',
        duration: 1500
      });
    } catch (error) {
      Logger.error('ChatPage', `切换深度思考失败: ${error}`);
      promptAction.showToast({
        message: '❗ 深度思考切换失败，请稍后重试',
        duration: 1500
      });
    }
  }

  private async toggleMessageLayout(): Promise<void> {
    const previousLayout = this.useModernMessageLayout;
    this.useModernMessageLayout = !this.useModernMessageLayout;
    
    Logger.info('ChatPage', `消息布局样式切换: ${previousLayout ? '现代' : '传统'} -> ${this.useModernMessageLayout ? '现代' : '传统'}`);
    
    // 保存到持久化存储
    await StorageManager.saveMessageLayoutPreference(this.useModernMessageLayout);
    
    // 显示状态切换提示
    promptAction.showToast({
      message: this.useModernMessageLayout ? '📱 已切换到现代线性布局' : '💬 已切换到传统消息气泡',
      duration: 1500
    });
  }

  private async compactMessages(): Promise<void> {
    const currentCount = this.chatViewModel.messages.length;
    if (currentCount <= 6) {
      AlertDialog.show({
        title: '无需压缩',
        message: `当前仅有 ${currentCount} 条消息，无需压缩。`,
        primaryButton: {
          value: '确定',
          action: () => {}
        }
      });
      return;
    }

    AlertDialog.show({
      title: '确认压缩',
      message: `当前有 ${currentCount} 条消息，压缩后将保留最近6条消息并压缩长消息内容。此操作不可撤销。`,
      primaryButton: {
        value: '确定',
        action: async () => {
          await this.chatViewModel.compactMessages();
          const newCount = this.chatViewModel.messages.length;
          // 显示压缩结果
          setTimeout(() => {
            AlertDialog.show({
              title: '压缩完成',
              message: `已压缩 ${currentCount - newCount} 条消息，当前保留 ${newCount} 条消息。`,
              primaryButton: {
                value: '确定',
                action: () => {}
              }
            });
          }, 500);
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  private copyToClipboard(text: string): void {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteData);
      
      // 显示复制成功提示
      promptAction.showToast({
        message: '已复制到剪贴板',
        duration: 1500
      });
    } catch (error) {
      Logger.error('ChatPage', `复制失败: ${error}`);
      promptAction.showToast({
        message: '复制失败',
        duration: 1500
      });
    }
  }

  /**
   * 启动消息变化检测定时器
   */
  private startMessageChangeTimer(): void {
    // 清除现有定时器
    this.stopMessageChangeTimer();

    // 每500ms检查一次消息变化
    this.messageChangeTimer = setInterval(() => {
      this.checkMessageChangesAndScroll();
    }, 500);

    Logger.info('ChatPage', '消息变化检测定时器已启动');
  }

  /**
   * 停止消息变化检测定时器
   */
  private stopMessageChangeTimer(): void {
    if (this.messageChangeTimer !== -1) {
      clearInterval(this.messageChangeTimer);
      this.messageChangeTimer = -1;
      Logger.info('ChatPage', '消息变化检测定时器已停止');
    }
  }

  /**
   * 检查消息变化并自动滚动
   */
  private checkMessageChangesAndScroll(): void {
    try {
      const currentMessages = this.chatViewModel.messages;

      // 检查消息数量是否增加
      if (currentMessages.length > this.lastMessageCount) {
        this.lastMessageCount = currentMessages.length;
        this.messages = [...currentMessages];

        // 新消息添加，滚动到底部
        setTimeout(() => {
          this.scrollToBottom();
        }, 100);
        return;
      }

      // 检查最后一条助手消息内容是否有更新
      if (currentMessages.length > 0) {
        const lastMessage = currentMessages[currentMessages.length - 1];

        if (lastMessage.role === MessageRole.ASSISTANT &&
            lastMessage.content !== this.lastAssistantMessageContent &&
            lastMessage.content.trim().length > 0) {

          this.lastAssistantMessageContent = lastMessage.content;
          this.messages = [...currentMessages];

          // 助手消息内容更新，滚动到底部
          setTimeout(() => {
            this.scrollToBottom();
          }, 100);
        }
      }
    } catch (error) {
      Logger.error('ChatPage', `检测消息变化失败: ${error}`);
    }
  }

  /**
   * 滚动到消息列表底部（最新消息）
   */
  private scrollToBottom(): void {
    try {
      const messageCount = this.chatViewModel.messages.length;
      if (messageCount > 0) {
        // 延迟执行滚动，确保UI渲染完成
        setTimeout(() => {
          this.performScrollToBottom(messageCount - 1, 0);
        }, 200);
      } else {
        // 没有消息时也尝试滚动到底部，确保输入框可见
        setTimeout(() => {
          this.performScrollToBottom(0, 0);
        }, 200);
      }
    } catch (error) {
      Logger.error('ChatPage', `滚动到底部失败: ${error}`);
    }
  }

  /**
   * 执行滚动操作，带重试机制
   */
  private performScrollToBottom(targetIndex: number, retryCount: number): void {
    const maxRetries = 3;
    try {
      this.listScroller.scrollToIndex(targetIndex, true, ScrollAlign.END);
      Logger.info('ChatPage', `自动滚动到索引 ${targetIndex}，重试次数: ${retryCount}`);
    } catch (scrollError) {
      Logger.warn('ChatPage', `滚动执行失败: ${scrollError}，重试次数: ${retryCount}`);

      // 如果滚动失败且还有重试次数，则重试
      if (retryCount < maxRetries) {
        setTimeout(() => {
          this.performScrollToBottom(targetIndex, retryCount + 1);
        }, 100 * (retryCount + 1)); // 递增延迟时间
      } else {
        Logger.error('ChatPage', `滚动重试失败，已达到最大重试次数: ${maxRetries}`);
      }
    }
  }

  /**
   * 处理返回键
   */
  private handleBackPress(): boolean {
    // 如果有弹窗打开，先关闭弹窗
    if (this.showToolboxPanel) {
      this.hideToolboxPanel();
      return true; // 阻止默认返回行为
    }
    
    if (this.showModelSelector) {
      this.hideModelSelector();
      return true; // 阻止默认返回行为
    }
    
    // if (this.showPromptSelector) {
    //   this.showPromptSelector = false;
    //   return true;
    // }
    
    if (this.showQuickCommands) {
      this.showQuickCommands = false;
      return true;
    }
    
    if (this.showSideDrawer) {
      this.showSideDrawer = false;
      // 重置滑动状态和防抖状态
      this.resetSideDrawerState();
      return true;
    }
    
    // 如果正在滑动侧边栏，也阻止返回行为
    if (this.isSideDrawerSwipeActive) {
      this.resetSideDrawerState();
      return true;
    }
    
    // 允许默认返回行为（退出应用）
    return false;
  }

  /**
   * 构建加载状态组件
   */
  @Builder
  private buildLoadingStatus(text: string, showAnimation: boolean = false) {
    Row() {
      LoadingProgress()
        .width(20)
        .height(20)
        .margin({ right: 8 })
      
      Text(text)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .animation(showAnimation ? {
      duration: 800,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    } : undefined)
  }

  /**
   * 重置侧边栏滑动相关状态
   */
  private resetSideDrawerState(): void {
    this.isSideDrawerSwipeActive = false;
    this.isSwipeDebouncing = false;
    this.swipeDirection = 'none';
    this.lastSwipeTime = 0;
    
    // 平滑重置进度到对应状态，使用更长的持续时间减少抖动
    animateTo({
      duration: 200,
      curve: Curve.EaseOut
    }, () => {
      this.sideDrawerSwipeProgress = this.showSideDrawer ? 1 : 0;
    });
    
    Logger.debug('ChatPage', '侧边栏滑动状态已重置');
  }

  /**
   * 处理会话项滑动状态变化
   */
  private handleSessionSwipeStateChange(isSwiping: boolean): void {
    this.isSessionItemSwiping = isSwiping;
    Logger.debug('ChatPage', `会话项滑动状态变化: ${isSwiping}`);
  }

  @Builder
  buildUserAvatar() {
    if (this.userAvatarType === 'emoji') {
      Text(this.userAvatarValue)
        .fontSize(20)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .borderRadius(18)
        .backgroundColor($r('app.color.input_background'))
        .onClick(() => {
          this.navigateToProfileEdit();
        })
    } else if (this.userAvatarType === 'image') {
      Image(this.userAvatarValue)
        .width(36)
        .height(36)
        .borderRadius(18)
        .objectFit(ImageFit.Cover)
        .onError(() => {
          // 图片加载失败时显示默认头像
          Logger.warn('ChatPage', '用户头像图片加载失败，显示默认头像');
        })
        .onClick(() => {
          this.navigateToProfileEdit();
        })
    } else {
      Circle({ width: 36, height: 36 })
        .fill(this.userAvatarValue)
        .onClick(() => {
          this.navigateToProfileEdit();
        })
    }
  }

  @Builder
  buildAIAvatar() {
    if (this.aiAvatarType === 'emoji') {
      Text(this.aiAvatarValue)
        .fontSize(20)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .borderRadius(18)
        .backgroundColor($r('app.color.input_background'))
    } else if (this.aiAvatarType === 'image') {
      Image(this.aiAvatarValue)
        .width(36)
        .height(36)
        .borderRadius(18)
        .objectFit(ImageFit.Cover)
        .onError(() => {
          // 图片加载失败时显示默认头像
          Logger.warn('ChatPage', 'AI头像图片加载失败，显示默认头像');
        })
    } else {
      Circle({ width: 36, height: 36 })
        .fill(this.aiAvatarValue)
    }
  }

  // systemPromptSheetBuilder已注释，不再使用顶部选择器
  // @Builder
  // systemPromptSheetBuilder() {
  //   SystemPromptComponent({
  //     prompts: this.chatViewModel.systemPrompts || [],
  //     selectedPrompt: this.chatViewModel.selectedSystemPrompt,
  //     onPromptSelected: (prompt: SystemPrompt | null) => {
  //       this.chatViewModel.selectSystemPrompt(prompt);
  //       this.showPromptSelector = false;
  //     },
  //     onClose: () => {
  //       this.showPromptSelector = false;
  //     }
  //   })
  // }

  /**
   * 当前会话系统提示词只读展示
   */
  @Builder
  buildCurrentSessionPromptDisplay() {
    Row({ space: 8 }) {
      // 使用图标+状态点简化展示
      Text('🎭')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))

      Circle()
        .width(8)
        .height(8)
        .fill(this.chatViewModel.getCurrentSessionSystemPrompt() ? '#74B9FF' : '#BDBDBD')
        .opacity(this.chatViewModel.getCurrentSessionSystemPrompt() ? 1.0 : 0.6)

      Blank()
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 4, bottom: 2 })
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .clip(true)
  }


  /**
   * 处理Prompt模板选择
   */
  private handlePromptSelected(prompt: string): void {
    Logger.info('ChatPage', `选择Prompt模板: ${prompt}`);
    
    // 将Prompt内容添加到输入框
    const currentText = this.inputText.trim();
    const promptContent = prompt.trim();
    
    if (currentText) {
      // 如果输入框有内容，在后面添加空格和prompt内容
      this.inputText = currentText + ' ' + promptContent;
    } else {
      // 如果输入框为空，直接设置prompt内容
      this.inputText = promptContent;
    }
    
    // 更新输入区域高度
    this.inputAreaHeight = this.calculateInputHeight(this.inputText);
    
    Logger.info('ChatPage', `Prompt已插入输入框，当前内容: ${this.inputText}`);
    
    // 显示成功提示
    promptAction.showToast({
      message: '智能模板已插入',
      duration: 1000
    });
  }

  /**
   * 处理工具箱工具选择
   */
  private handleToolSelected(tool: ToolType): void {
    Logger.info('ChatPage', `工具箱工具被选择: ${tool}`);
    
    switch (tool) {
      case ToolType.CLEAR_SESSION:
        this.clearMessages();
        break;
      case ToolType.COMPACT_CONTEXT:
        this.compactMessages();
        break;
      default:
        Logger.warn('ChatPage', `未知的工具类型: ${tool}`);
        break;
    }
  }

  
  
  /**
   * 构建工具箱项目
   */
  @Builder
  buildToolboxItem(item: ToolboxItem) {
    Row() {
      // 工具图标
      Text(item.icon)
        .fontSize(22)
        .fontColor(item.color)
        .width(40)
        .height(40)
        .backgroundColor(item.backgroundColor)
        .borderRadius(20)
        .textAlign(TextAlign.Center)
        .margin({ right: 16 })
      
      // 工具信息
      Column({ space: 6 }) {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDarkMode ? '#FFFFFF' : '#1A1A1A')
          .textAlign(TextAlign.Start)
        
        Text(item.description)
          .fontSize(13)
          .fontColor(this.isDarkMode ? '#CCCCCC' : '#666666')
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      
    }
    .width('100%')
    .height(64)
    .padding({ left: 20, right: 20 })
    .backgroundColor(Color.Transparent)
    .borderRadius(12)
    .stateStyles({
      normal: {
        .backgroundColor(Color.Transparent)
      },
      pressed: {
        .backgroundColor(this.isDarkMode ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)')
      }
    })
    .animation({
      duration: 150,
      curve: Curve.EaseInOut
    })
    .onClick(() => {
      Logger.info('ChatPage', `工具项被点击: ${item.title}`);
      this.handleToolboxItemClick(item);
    })
    .hitTestBehavior(1)
  }

  /**
   * 显示工具箱面板
   */
  private showToolboxPanelMethod(): void {
    Logger.info('ChatPage', '显示工具箱面板');
    // 显示工具箱面板前先关闭快速指令面板
    if (this.showQuickCommands) {
      this.showQuickCommands = false;
    }
    this.showToolboxPanel = true;
    
    // 动画显示面板 - 渐入+上滑效果
    animateTo({
      duration: 350,
      curve: curves.springMotion(0.6, 0.8)
    }, () => {
      this.toolboxPanelOpacity = 1.0;
      this.toolboxPanelTranslateY = 0; // 滑到正确位置
    });
  }

  /**
   * 隐藏工具箱面板
   */
  private hideToolboxPanel(): void {
    Logger.info('ChatPage', '隐藏工具箱面板');
    
    // 动画隐藏面板 - 渐出+下移效果
    animateTo({
      duration: 300,
      curve: curves.springMotion(0.6, 0.8)
    }, () => {
      this.toolboxPanelOpacity = 0.0;
      this.toolboxPanelTranslateY = 400; // 向下滑出屏幕
    });
    
    // 延迟重置显示状态
    setTimeout(() => {
      this.showToolboxPanel = false;
    }, 250);
  }

  /**
   * 获取工具箱项目列表
   */
  private getToolboxItems(): ToolboxItem[] {
    return [
      {
        id: 'clear_session',
        title: '清空会话',
        description: '删除所有聊天记录，开始新的对话',
        icon: '🗑️',
        color: '#FF4757',
        backgroundColor: 'rgba(255, 71, 87, 0.1)',
        enabled: true,
        action: async () => {
          Logger.info('ChatPage', '执行清空会话操作');
          await this.clearMessages();
        }
      },
      {
        id: 'toggle_style',
        title: this.useModernMessageLayout ? '切换到传统样式' : '切换到现代样式',
        description: this.useModernMessageLayout ? '当前为现代线性布局，可切换回传统消息气泡' : '当前为传统消息气泡，可切换到现代线性布局',
        icon: this.useModernMessageLayout ? '💬' : '📱',
        color: this.useModernMessageLayout ? '#3742FA' : '#8E44AD',
        backgroundColor: this.useModernMessageLayout ? 'rgba(55, 66, 250, 0.1)' : 'rgba(142, 68, 173, 0.1)',
        enabled: true,
        action: () => {
          Logger.info('ChatPage', '执行样式切换操作');
          this.toggleMessageLayout();
        }
      },
      {
        id: 'compact_context',
        title: '压缩上下文',
        description: '保留最近消息，压缩历史记录节省空间',
        icon: '📦',
        color: '#3742FA',
        backgroundColor: 'rgba(55, 66, 250, 0.1)',
        enabled: true,
        action: async () => {
          Logger.info('ChatPage', '执行压缩上下文操作');
          await this.compactMessages();
        }
      },
      {
        id: 'system_prompt_manager',
        title: '管理提示词',
        description: '调整系统提示词与角色设定',
        icon: '✏️',
        color: '#0984E3',
        backgroundColor: 'rgba(9, 132, 227, 0.1)',
        enabled: true,
        action: () => {
          Logger.info('ChatPage', '跳转到系统提示词管理页面');
          router.pushUrl({
            url: 'pages/SystemPromptManagerPage',
            params: {
              fromChatPage: true,
              currentSessionId: this.chatViewModel.currentSession?.id || null
            }
          });
        }
      },
      {
        id: 'settings',
        title: '设置',
        description: '应用设置和个性化配置',
        icon: '⚙️',
        color: '#95A5A6',
        backgroundColor: 'rgba(149, 165, 166, 0.1)',
        enabled: true,
        action: () => {
          Logger.info('ChatPage', '跳转到设置页面');
          router.pushUrl({ url: 'pages/SettingsPage' });
        }
      }
    ];
  }

  /**
   * 跳转到用户资料编辑页面
   */
  private navigateToProfileEdit(): void {
    Logger.info('ChatPage', '跳转到用户资料编辑页面');
    router.pushUrl({ url: 'pages/UserProfileEditPage' });
  }

  /**
   * 截断搜索信息显示
   */
  private truncateSearchInfo(searchInfo: string): string {
    if (!searchInfo) return '';
    
    // 如果信息长度超过30个字符，进行截断
    const maxLength = 30;
    if (searchInfo.length <= maxLength) {
      return searchInfo;
    }
    
    return searchInfo.substring(0, maxLength) + '...';
  }

  /**
   * 显示搜索信息弹框
   */
  private showSearchInfoBubble(content: string): void {
    Logger.info('ChatPage', `showSearchInfoBubble被调用，content长度: ${content.length}`);
    Logger.info('ChatPage', `内容预览: ${content.substring(0, 100)}...`);
    
    // 使用自定义弹框显示搜索信息，支持选中复制
    this.searchDetailsContent = content;
    this.showSearchDetailsDialog = true;
    
    Logger.info('ChatPage', '搜索信息弹框已显示');
  }

  /**
   * 隐藏搜索信息弹框
   */
  private hideSearchDetailsDialog(): void {
    this.showSearchDetailsDialog = false;
    this.searchDetailsContent = '';
    Logger.info('ChatPage', '搜索信息弹框已隐藏');
  }

  
  /**
   * 处理工具箱项目点击
   */
  private handleToolboxItemClick(item: ToolboxItem): void {
    Logger.info('ChatPage', `工具箱工具被点击: ${item.title}`);
    
    // 先隐藏面板
    this.hideToolboxPanel();
    
    // 延迟执行工具动作，确保关闭动画完成
    setTimeout(async () => {
      try {
        Logger.info('ChatPage', `执行工具动作: ${item.id}`);
        const result = item.action();
        if (result instanceof Promise) {
          await result;
        }
        Logger.info('ChatPage', `工具动作执行完成: ${item.id}`);
        
        // 执行成功后显示提示（跳转类按钮除外）
        if (item.id !== 'settings' && item.id !== 'system_prompt_manager') {
          promptAction.showToast({
            message: `${item.title}操作成功`,
            duration: 1500
          });
        }
      } catch (error) {
        Logger.error('ChatPage', `工具执行异常: ${item.id}, 错误: ${error}`);
        // 设置按钮除外，显示错误提示
        if (item.id !== 'settings' && item.id !== 'system_prompt_manager') {
          promptAction.showToast({
            message: `${item.title}操作失败`,
            duration: 1500
          });
        }
      }
    }, 200);
  }


  /**
   * 输入区域提示文案
   */
  private getInputPlaceholder(): string {
    switch (this.voiceRecognitionState) {
      case VoiceRecognitionState.RECORDING:
        return '正在语音输入，上滑取消即可...';
      case VoiceRecognitionState.PROCESSING:
        return '语音识别中，请稍候...';
      case VoiceRecognitionState.ERROR:
        return '语音识别暂不可用，请改用文字输入';
      default:
        return '输入文字或按住语音键说话...';
    }
  }

  /**
   * 计算输入区域动态高度
   */
  private calculateInputHeight(text: string): number {
    const minHeight = 48; // 最小高度 (一行高度: 24px行高 + 24px内边距)
    const maxHeight = 280; // 最大高度，配合输入区域最大高度350px
    const lineHeight = 24; // 每行高度
    const padding = 24; // 上下内边距
    
    if (!text || text.trim() === '') {
      return minHeight;
    }
    
    // 计算明确的换行符行数
    const lineBreaks = (text.match(/\n/g) || []).length;
    const explicitLines = lineBreaks + 1;
    
    // 根据字符长度和实际宽度估算自动换行行数
    // 考虑中文字符宽度约为英文字符的2倍，输入框有效宽度约可容纳30-35个英文字符
    const charsPerLine = 30;
    let totalChars = 0;
    
    // 更准确地计算字符宽度（中文按2个字符计算）
    for (let i = 0; i < text.length; i++) {
      const char = text.charAt(i);
      // 判断是否为中文字符
      if (/[\u4e00-\u9fa5]/.test(char)) {
        totalChars += 2;
      } else {
        totalChars += 1;
      }
    }
    
    const estimatedLinesByWidth = Math.ceil(totalChars / charsPerLine);
    
    // 综合考虑换行符和字符宽度
    const totalLines = Math.max(explicitLines, estimatedLinesByWidth);
    
    // 计算动态高度，确保有足够空间显示所有文本
    const calculatedHeight = Math.min(maxHeight, Math.max(minHeight, totalLines * lineHeight + padding));
    
    return calculatedHeight;
  }

  /**
   * 显示模型选择器 - 带弹簧动画
   */
  private showModelSelectorMethod(): void {
    Logger.info('ChatPage', '显示模型选择器');
    this.showModelSelector = true;
    this.modelSelectorOpacity = 1.0;
    // 弹簧动画显示面板
    animateTo({
      duration: 450,
      curve: curves.springMotion(0.6, 0.8)
    }, () => {
      this.modelSelectorTranslateY = 0; // 滑到屏幕底部正确位置
    });
  }

  /**
   * 隐藏模型选择器 - 带弹簧动画
   */
  private hideModelSelector(): void {
    Logger.info('ChatPage', '隐藏模型选择器');
    
    // 弹簧动画隐藏面板
    animateTo({
      duration: 350,
      curve: curves.springMotion(0.8, 0.8)
    }, () => {
      this.modelSelectorTranslateY = 600; // 向下滑出屏幕
    });
    
    // 延迟重置显示状态
    setTimeout(() => {
      this.showModelSelector = false;
    }, 350);
  }

  
  /**
   * 显示深度思考对话框
   */
  private showDeepThinkingDialog(message: Message): void {
    Logger.info('ChatPage', `显示深度思考对话框: ${message.id}`);
    this.thinkingDialogMessage = message;
    this.showThinkingDialog = true;
  }

  /**
   * 隐藏深度思考对话框
   */
  private hideDeepThinkingDialog(): void {
    Logger.info('ChatPage', '隐藏深度思考对话框');
    this.showThinkingDialog = false;
    this.thinkingDialogMessage = null;
  }

  /**
   * 处理思考步骤点击
   */
  private handleThinkingStepTap(step: ThinkingStep): void {
    Logger.info('ChatPage', `思考步骤被点击: ${step.title}`);
    // 可以在这里实现步骤详情的进一步处理
  }

  /**
   * 获取当前服务器配置字符串，用于检测配置变更
   */
  private getCurrentServerConfigString(): string {
    try {
      // 从AppConfigManager获取当前服务器配置
      const appConfigManager = AppConfigManager.getInstance();
      const config = appConfigManager.getServerConfig();
      return `${config.baseUrl}|${config.wsUrl}`;
    } catch (error) {
      Logger.warn('ChatPage', `获取服务器配置失败: ${error}`);
      return '';
    }
  }

  /**
   * 请求强制刷新模型列表
   */
  private requestForceReloadProviders(): void {
    Logger.info('ChatPage', '请求强制刷新模型列表');
    this.forceReloadProviders = true;
  }

}
