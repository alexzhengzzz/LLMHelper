import { ChatViewModel } from '../viewmodels/ChatViewModel';
import { VoiceRecognitionState } from '../components/VoiceInputComponent';
import { Message } from '../models/ChatModels';
import { AvatarSettings, UserProfile, AppStorage as StorageManager } from './AppStorage';
import { UserProfileManager } from './UserProfileManager';
import { ThemeManager } from './ThemeManager';
import { Logger } from './Logger';

/**
 * ChatPage状态数据结构
 */
export interface ChatPageState {
  // 基础状态
  inputText: string;
  showModelSelector: boolean;
  showQuickCommands: boolean;
  isDarkMode: boolean;
  isImmersiveMode: boolean;
  showSideDrawer: boolean;

  // 功能开关状态
  enableWebSearch: boolean;
  enableDeepThinking: boolean;
  useModernMessageLayout: boolean;

  // 工具箱相关状态
  showToolboxPanel: boolean;
  toolboxPanelOpacity: number;
  toolboxPanelTranslateY: number;

  // 语音识别相关状态
  voiceRecognitionState: VoiceRecognitionState;
  showVoiceInput: boolean;

  // 滑动相关状态
  sideDrawerSwipeProgress: number;
  isSideDrawerSwipeActive: boolean;
  isSwipeDebouncing: boolean;
  lastSwipeTime: number;
  swipeDirection: 'left' | 'right' | 'none';
  isSessionItemSwiping: boolean;

  // 用户相关状态
  userAvatarType: 'default' | 'emoji' | 'image';
  userAvatarValue: string;
  aiAvatarType: 'default' | 'emoji' | 'image';
  aiAvatarValue: string;
  userName: string;
  userSignature: string;

  // 布局相关状态
  inputAreaHeight: number;
  statusBarHeight: number;
  keyboardHeight: number;

  // 动画相关状态
  modelSelectorOpacity: number;
  modelSelectorTranslateY: number;

  // 对话框相关状态
  showSearchDetailsDialog: boolean;
  searchDetailsContent: string;
  showThinkingDialog: boolean;
  thinkingDialogMessage: Message | null;
}

/**
 * ChatPage状态管理器 - 提供状态操作方法
 * 注意：状态本身应该在组件中使用@Local声明，这里只提供操作方法
 */
export class ChatPageStateManager {
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private userProfileManager: UserProfileManager = UserProfileManager.getInstance();

  /**
   * 创建默认状态
   */
  static createDefaultState(): ChatPageState {
    return {
      // 基础状态
      inputText: '',
      showModelSelector: false,
      showQuickCommands: false,
      isDarkMode: false,
      isImmersiveMode: false,
      showSideDrawer: false,

      // 功能开关状态
      enableWebSearch: false,
      enableDeepThinking: false,
      useModernMessageLayout: false,

      // 工具箱相关状态
      showToolboxPanel: false,
      toolboxPanelOpacity: 0.0,
      toolboxPanelTranslateY: 400,

      // 语音识别相关状态
      voiceRecognitionState: VoiceRecognitionState.IDLE,
      showVoiceInput: true,

      // 滑动相关状态
      sideDrawerSwipeProgress: 0,
      isSideDrawerSwipeActive: false,
      isSwipeDebouncing: false,
      lastSwipeTime: 0,
      swipeDirection: 'none',
      isSessionItemSwiping: false,

      // 用户相关状态
      userAvatarType: 'default',
      userAvatarValue: '#4285F4',
      aiAvatarType: 'default',
      aiAvatarValue: '#34A853',
      userName: 'Javis用户',
      userSignature: '让AI成为你的编程伙伴',

      // 布局相关状态
      inputAreaHeight: 48,
      statusBarHeight: 44,
      keyboardHeight: 0,

      // 动画相关状态
      modelSelectorOpacity: 0.0,
      modelSelectorTranslateY: 400,

      // 对话框相关状态
      showSearchDetailsDialog: false,
      searchDetailsContent: '',
      showThinkingDialog: false,
      thinkingDialogMessage: null
    };
  }

  /**
   * 初始化状态（从存储加载）
   */
  async initializeState(state: ChatPageState): Promise<void> {
    Logger.info('ChatPageStateManager', '开始初始化状态');

    try {
      // 初始化主题管理器
      await this.themeManager.initialize();
      state.isDarkMode = this.themeManager.getDarkMode();
      state.isImmersiveMode = this.themeManager.getImmersiveMode();

      // 初始化用户资料
      await this.loadUserProfile(state);

      // 加载头像设置
      await this.loadAvatarSettings(state);

      // 加载消息布局偏好
      await this.loadMessageLayoutPreference(state);

      // 加载深度思考状态
      await this.loadDeepThinkingState(state);

      // 获取状态栏高度
      this.loadStatusBarHeight(state);

      Logger.info('ChatPageStateManager', '状态初始化完成');
    } catch (error) {
      Logger.error('ChatPageStateManager', `初始化失败: ${error}`);
      throw error;
    }
  }

  /**
   * 设置主题监听器
   */
  setupThemeListeners(state: ChatPageState, updateCallback: () => void): void {
    // 添加主题变更监听器
    this.themeManager.addThemeListener((isDark: boolean) => {
      state.isDarkMode = isDark;
      updateCallback();
    });

    // 添加沉浸式模式变更监听器
    this.themeManager.addImmersiveListener((isImmersive: boolean) => {
      state.isImmersiveMode = isImmersive;
      updateCallback();
    });
  }

  /**
   * 设置头像监听器
   */
  setupAvatarListener(state: ChatPageState, updateCallback: () => void): () => void {
    const avatarListener = (settings: AvatarSettings) => {
      state.userAvatarType = settings.userAvatarType;
      state.userAvatarValue = settings.userAvatarValue;
      state.aiAvatarType = settings.aiAvatarType;
      state.aiAvatarValue = settings.aiAvatarValue;
      updateCallback();
      Logger.info('ChatPageStateManager', '头像设置已更新');
    };

    StorageManager.addAvatarListener(avatarListener);
    return () => StorageManager.removeAvatarListener(avatarListener);
  }

  /**
   * 加载用户资料
   */
  private async loadUserProfile(state: ChatPageState): Promise<void> {
    try {
      await this.userProfileManager.initialize();
      const currentProfile = this.userProfileManager.getCurrentProfile();
      if (currentProfile) {
        state.userName = currentProfile.userName;
        state.userSignature = currentProfile.userSignature;
        state.userAvatarType = currentProfile.userAvatarType;
        state.userAvatarValue = currentProfile.userAvatarValue;
        Logger.info('ChatPageStateManager', `用户资料加载成功: ${state.userName}`);
      }
    } catch (error) {
      Logger.error('ChatPageStateManager', `加载用户资料失败: ${error}`);
    }
  }

  /**
   * 加载头像设置
   */
  private async loadAvatarSettings(state: ChatPageState): Promise<void> {
    try {
      const avatarSettings = await StorageManager.getAvatarSettings();
      state.aiAvatarType = avatarSettings.aiAvatarType;
      state.aiAvatarValue = avatarSettings.aiAvatarValue;
      Logger.info('ChatPageStateManager', `AI头像设置加载成功`);
    } catch (error) {
      Logger.error('ChatPageStateManager', `加载AI头像设置失败: ${error}`);
    }
  }

  /**
   * 加载消息布局偏好
   */
  private async loadMessageLayoutPreference(state: ChatPageState): Promise<void> {
    try {
      const initialLayout = state.useModernMessageLayout;
      state.useModernMessageLayout = await StorageManager.getMessageLayoutPreference();
      Logger.info('ChatPageStateManager', `消息布局偏好加载成功: ${state.useModernMessageLayout ? '现代布局' : '传统气泡'}`);

      if (initialLayout !== state.useModernMessageLayout && state.useModernMessageLayout) {
        Logger.info('ChatPageStateManager', `初始化时更新布局状态: ${initialLayout ? '现代' : '传统'} -> ${state.useModernMessageLayout ? '现代' : '传统'}`);
      }
    } catch (error) {
      Logger.error('ChatPageStateManager', `加载消息布局偏好失败: ${error}`);
    }
  }

  /**
   * 加载深度思考状态
   */
  private async loadDeepThinkingState(state: ChatPageState): Promise<void> {
    try {
      state.enableDeepThinking = AppStorage.get('enableDeepThinking') ?? false;
      Logger.info('ChatPageStateManager', `深度思考状态加载成功: ${state.enableDeepThinking ? '已开启' : '已关闭'}`);
    } catch (error) {
      Logger.error('ChatPageStateManager', `加载深度思考状态失败: ${error}`);
    }
  }

  /**
   * 加载状态栏高度
   */
  private loadStatusBarHeight(state: ChatPageState): void {
    const storedHeight = AppStorage.get<number>('statusBarHeight');
    if (storedHeight && storedHeight > 0) {
      state.statusBarHeight = storedHeight;
      Logger.info('ChatPageStateManager', `状态栏高度获取成功: ${state.statusBarHeight}vp`);
    } else {
      Logger.info('ChatPageStateManager', '使用默认状态栏高度44vp');
    }
  }

  // 状态操作方法

  /**
   * 显示模型选择器
   */
  showModelSelector(state: ChatPageState): void {
    state.showModelSelector = true;
  }

  /**
   * 隐藏模型选择器
   */
  hideModelSelector(state: ChatPageState): void {
    state.showModelSelector = false;
  }

  /**
   * 切换工具箱面板显示状态
   */
  toggleToolboxPanel(state: ChatPageState): void {
    state.showToolboxPanel = !state.showToolboxPanel;
  }

  /**
   * 显示搜索详情对话框
   */
  showSearchDetails(state: ChatPageState, content: string): void {
    state.searchDetailsContent = content;
    state.showSearchDetailsDialog = true;
  }

  /**
   * 隐藏搜索详情对话框
   */
  hideSearchDetails(state: ChatPageState): void {
    state.showSearchDetailsDialog = false;
    state.searchDetailsContent = '';
  }

  /**
   * 显示深度思考对话框
   */
  showThinkingDialog(state: ChatPageState, message: Message): void {
    state.thinkingDialogMessage = message;
    state.showThinkingDialog = true;
  }

  /**
   * 隐藏深度思考对话框
   */
  hideThinkingDialog(state: ChatPageState): void {
    state.showThinkingDialog = false;
    state.thinkingDialogMessage = null;
  }

  /**
   * 更新联网搜索状态
   */
  updateWebSearchState(state: ChatPageState, enabled: boolean): void {
    state.enableWebSearch = enabled;
  }

  /**
   * 更新深度思考状态
   */
  updateDeepThinkingState(state: ChatPageState, enabled: boolean): void {
    state.enableDeepThinking = enabled;
    AppStorage.set('enableDeepThinking', enabled);
  }

  /**
   * 更新语音识别状态
   */
  updateVoiceRecognitionState(state: ChatPageState, voiceState: VoiceRecognitionState): void {
    state.voiceRecognitionState = voiceState;
  }

  /**
   * 更新侧边栏滑动进度
   */
  updateSideDrawerSwipeProgress(state: ChatPageState, progress: number): void {
    state.sideDrawerSwipeProgress = progress;
  }

  /**
   * 更新侧边栏滑动激活状态
   */
  updateSideDrawerSwipeActive(state: ChatPageState, active: boolean): void {
    state.isSideDrawerSwipeActive = active;
  }

  /**
   * 更新输入文本
   */
  updateInputText(state: ChatPageState, text: string): void {
    state.inputText = text;
  }

  /**
   * 更新输入区域高度
   */
  updateInputAreaHeight(state: ChatPageState, height: number): void {
    state.inputAreaHeight = height;
  }

  /**
   * 更新键盘高度
   */
  updateKeyboardHeight(state: ChatPageState, height: number): void {
    state.keyboardHeight = height;
  }

  /**
   * 更新滑动方向
   */
  updateSwipeDirection(state: ChatPageState, direction: 'left' | 'right' | 'none'): void {
    state.swipeDirection = direction;
  }

  /**
   * 更新防抖状态
   */
  updateSwipeDebouncing(state: ChatPageState, debouncing: boolean): void {
    state.isSwipeDebouncing = debouncing;
  }

  /**
   * 更新会话项滑动状态
   */
  updateSessionItemSwiping(state: ChatPageState, swiping: boolean): void {
    state.isSessionItemSwiping = swiping;
  }

  /**
   * 显示侧边栏
   */
  showSideDrawer(state: ChatPageState): void {
    state.showSideDrawer = true;
  }

  /**
   * 隐藏侧边栏
   */
  hideSideDrawer(state: ChatPageState): void {
    state.showSideDrawer = false;
  }

  /**
   * 显示快速命令
   */
  showQuickCommands(state: ChatPageState): void {
    state.showQuickCommands = true;
  }

  /**
   * 隐藏快速命令
   */
  hideQuickCommands(state: ChatPageState): void {
    state.showQuickCommands = false;
  }

  /**
   * 切换快速命令显示状态
   */
  toggleQuickCommands(state: ChatPageState): void {
    state.showQuickCommands = !state.showQuickCommands;
  }

  /**
   * 清理状态管理器资源
   */
  destroy(): void {
    Logger.info('ChatPageStateManager', '状态管理器已销毁');
  }
}