import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Message, MessageRole, ThinkingStatus, SystemPrompt, SystemPromptData, Session, SessionData } from '../models/ChatModels';
import { Logger } from './Logger';
import { DefaultPrompts } from '../data/DefaultPrompts';

const MESSAGES_KEY = 'chat_messages';
const SYSTEM_PROMPTS_KEY = 'system_prompts';
const AUTO_TTS_SETTINGS_KEY = 'auto_tts_settings';
const AVATAR_SETTINGS_KEY = 'avatar_settings';
const USER_PROFILE_KEY = 'user_profile'; // 用户基本资料
const API_MODE_KEY = 'api_mode';
const SELECTED_SYSTEM_PROMPT_KEY = 'selected_system_prompt_id';
const MESSAGE_LAYOUT_KEY = 'message_layout_preference';
const API_KEYS_KEY = 'api_keys_config';
const CURRENT_MODEL_KEY = 'current_model_config'; // 当前选择的模型配置
const FONT_SETTINGS_KEY = 'font_settings'; // 字体设置
const MCP_CONFIGURATION_KEY = 'mcp_configuration'; // MCP配置
const MCP_TOOLS_CONFIG_KEY = 'mcp_tools_config'; // MCP工具开关配置
const APPLIED_ROLES_KEY = 'applied_roles'; // 已应用到侧边栏的角色ID列表

// 会话管理相关存储键
const SESSIONS_KEY = 'chat_sessions';
const CURRENT_SESSION_KEY = 'current_session_id';

/**
 * 语音播报设置接口
 */
export interface AutoTTSSettings {
  muted: boolean;        // 是否静音（立刻停止播放并暂时禁用）
  speed: number;         // 语速 (0.1 - 3.0)
  volume: number;        // 音量 (0.0 - 1.0)
  pitch: number;         // 音调 (0.5 - 2.0)
  language: string;      // 语言
  autoPlayOnReceive: boolean; // 收到回复时自动播放
}

/**
 * 模型选择配置接口
 */
export interface ModelConfig {
  provider: string;      // 厂商名称
  model: string;         // 模型名称
  savedAt: number;       // 保存时间戳
}

/**
 * 字体设置接口
 */
export interface FontSettings {
  chatFontSize: number;      // 聊天字体大小 (12-20px)
  codeFontSize: number;      // 代码字体大小 (10-18px)
  fontFamily: 'system' | 'serif' | 'monospace' | 'rounded' | 'elegant' | 'playful' | 'modern' | 'classic'; // 字体家族
  updatedAt: number;         // 最后更新时间
}

/**
 * MCP配置接口
 */
export interface MCPConfiguration {
  servers: Array<MCPServerConfigData>;
  lastModified: number;
}

/**
 * MCP工具配置接口
 */
export interface MCPToolsConfig {
  enabledTools: Record<string, boolean>; // 工具名称 -> 是否启用
  globalEnabled: boolean;                // 全局MCP开关
  lastModified: number;                  // 最后修改时间
  toolUsageStats: Record<string, number>; // 工具使用统计
}

export interface MCPServerConfigData {
  name: string;
  description?: string;
  transportType: 'stdio' | 'http_sse';
  command?: string;
  args?: Array<string>;
  env?: Record<string, string>;
  url?: string;
  timeout?: number;
  retryAttempts?: number;
}

/**
 * 用户基本资料接口
 */
export interface UserProfileData {
  userName: string;          // 用户名字
  userSignature: string;     // 个性签名
  userAvatarType: 'default' | 'emoji' | 'image';
  userAvatarValue: string;
  updatedAt: number;         // 最后更新时间
}

/**
 * 头像设置类 - 支持ArkTS V2嵌套观察
 */
export interface AvatarSettingsData {
  userAvatarType: 'default' | 'emoji' | 'image';
  userAvatarValue: string;
  aiAvatarType: 'default' | 'emoji' | 'image';
  aiAvatarValue: string;
}

@ObservedV2
export class AvatarSettings {
  @Trace userAvatarType: 'default' | 'emoji' | 'image' = 'default';  // 用户头像类型
  @Trace userAvatarValue: string = '#4285F4';                        // 头像值（表情符号或图片路径）
  @Trace aiAvatarType: 'default' | 'emoji' | 'image' = 'default';   // AI头像类型
  @Trace aiAvatarValue: string = '#34A853';                          // 头像值（表情符号或图片路径）
  
  constructor(userAvatarType: 'default' | 'emoji' | 'image' = 'default',
              userAvatarValue: string = '#4285F4',
              aiAvatarType: 'default' | 'emoji' | 'image' = 'default',
              aiAvatarValue: string = '#34A853') {
    this.userAvatarType = userAvatarType;
    this.userAvatarValue = userAvatarValue;
    this.aiAvatarType = aiAvatarType;
    this.aiAvatarValue = aiAvatarValue;
  }
  
  // 创建副本的方法，用于深度更新
  clone(): AvatarSettings {
    return new AvatarSettings(
      this.userAvatarType,
      this.userAvatarValue,
      this.aiAvatarType,
      this.aiAvatarValue
    );
  }
  
  // 转换为普通对象的方法，用于序列化
  toObject(): AvatarSettingsData {
    return {
      userAvatarType: this.userAvatarType,
      userAvatarValue: this.userAvatarValue,
      aiAvatarType: this.aiAvatarType,
      aiAvatarValue: this.aiAvatarValue
    };
  }
}

/**
 * 用户基本资料类 - 支持ArkTS V2嵌套观察
 */
@ObservedV2
export class UserProfile {
  @Trace userName: string = 'Javis用户';          // 用户名字，默认值
  @Trace userSignature: string = '让AI成为你的编程伙伴'; // 个性签名，默认值
  @Trace userAvatarType: 'default' | 'emoji' | 'image' = 'default';
  @Trace userAvatarValue: string = '#4285F4';
  @Trace updatedAt: number = Date.now();          // 最后更新时间
  
  constructor(userName: string = 'Javis用户',
              userSignature: string = '让AI成为你的编程伙伴',
              userAvatarType: 'default' | 'emoji' | 'image' = 'default',
              userAvatarValue: string = '#4285F4',
              updatedAt: number = Date.now()) {
    this.userName = userName;
    this.userSignature = userSignature;
    this.userAvatarType = userAvatarType;
    this.userAvatarValue = userAvatarValue;
    this.updatedAt = updatedAt;
  }
  
  /**
   * 验证用户名字格式
   */
  static validateUserName(name: string): boolean {
    return name.length >= 1 && name.length <= 20 && name.trim().length > 0;
  }
  
  /**
   * 验证个性签名格式
   */
  static validateUserSignature(signature: string): boolean {
    return signature.length <= 50;
  }
  
  /**
   * 创建副本的方法，用于深度更新
   */
  clone(): UserProfile {
    return new UserProfile(
      this.userName,
      this.userSignature,
      this.userAvatarType,
      this.userAvatarValue,
      this.updatedAt
    );
  }
  
  /**
   * 转换为普通对象的方法，用于序列化
   */
  toObject(): UserProfileData {
    return {
      userName: this.userName,
      userSignature: this.userSignature,
      userAvatarType: this.userAvatarType,
      userAvatarValue: this.userAvatarValue,
      updatedAt: this.updatedAt
    };
  }
}

export class AppStorage {
  private static storage: preferences.Preferences | null = null;
  private static avatarListeners: ((settings: AvatarSettings) => void)[] = [];
  private static userProfileListeners: ((profile: UserProfile) => void)[] = [];
  private static sessionDataClearedListeners: (() => void)[] = [];
  private static initializationPromise: Promise<preferences.Preferences> | null = null;
  private static initializationRetryCount: number = 0;
  private static readonly MAX_RETRY_COUNT: number = 3;
  private static readonly RETRY_DELAY: number = 1000; // 1秒

  private static async delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  private static async initializeStorage(): Promise<preferences.Preferences> {
    if (AppStorage.storage) {
      return AppStorage.storage;
    }

    if (AppStorage.initializationPromise) {
      return AppStorage.initializationPromise;
    }

    AppStorage.initializationPromise = new Promise(async (resolve, reject) => {
      let lastError: Error | null = null;

      for (let attempt = 1; attempt <= AppStorage.MAX_RETRY_COUNT; attempt++) {
        try {
          Logger.debug('AppStorage', `正在初始化存储，尝试 ${attempt}/${AppStorage.MAX_RETRY_COUNT}`);

          const context = getContext() as common.UIAbilityContext;
          if (!context) {
            throw new Error('Context is not available');
          }

          Logger.debug('AppStorage', `Context获取成功: ${!!context}`);
          AppStorage.storage = preferences.getPreferencesSync(context, { name: 'chat_storage' });
          Logger.info('AppStorage', '存储初始化成功');

          AppStorage.initializationRetryCount = 0;
          resolve(AppStorage.storage);
          return;
        } catch (e) {
          lastError = e as Error;
          Logger.warn('AppStorage', `存储初始化失败，尝试 ${attempt}/${AppStorage.MAX_RETRY_COUNT}: ${e}`);

          if (attempt < AppStorage.MAX_RETRY_COUNT) {
            Logger.debug('AppStorage', `等待 ${AppStorage.RETRY_DELAY}ms 后重试`);
            await AppStorage.delay(AppStorage.RETRY_DELAY);
          }
        }
      }

      AppStorage.initializationRetryCount++;
      Logger.error('AppStorage', `存储初始化彻底失败，重试次数: ${AppStorage.initializationRetryCount}`);
      AppStorage.initializationPromise = null;
      reject(new Error(`Storage initialization failed after ${AppStorage.MAX_RETRY_COUNT} attempts: ${lastError?.message}`));
    });

    return AppStorage.initializationPromise;
  }

  private static getStorage(): preferences.Preferences {
    if (!AppStorage.storage) {
      throw new Error('Storage not initialized. Please call initializeStorage() first.');
    }
    return AppStorage.storage;
  }

  static async getStorageAsync(): Promise<preferences.Preferences> {
    try {
      return await AppStorage.initializeStorage();
    } catch (e) {
      Logger.error('AppStorage', `Failed to get storage: ${e}`);
      throw new Error();;
    }
  }

  /**
   * 安全存储操作包装器 - 自动处理初始化
   */
  static async safeStorageOperation<T>(operation: (storage: preferences.Preferences) => Promise<T>): Promise<T> {
    try {
      const storage = await AppStorage.getStorageAsync();
      return await operation(storage);
    } catch (e) {
      Logger.error('AppStorage', `Safe storage operation failed: ${e}`);
      throw new Error(e);
    }
  }

  /**
   * 安全同步存储操作包装器
   */
  static safeSyncStorageOperation<T>(operation: (storage: preferences.Preferences) => T): T | null {
    try {
      if (!AppStorage.storage) {
        Logger.warn('AppStorage', 'Storage not initialized for sync operation');
        return null;
      }
      return operation(AppStorage.storage);
    } catch (e) {
      Logger.error('AppStorage', `Safe sync storage operation failed: ${e}`);
      return null;
    }
  }

  static getPreferences(): preferences.Preferences {
    return AppStorage.getStorage();
  }

  static async saveMessages(messages: Message[]): Promise<void> {
    try {
      Logger.info('AppStorage', `正在保存 ${messages.length} 条消息`);
      const storage = await AppStorage.getStorageAsync();
      const jsonStr = JSON.stringify(messages);
      Logger.debug('AppStorage', `消息JSON长度: ${jsonStr.length}`);
      await storage.put(MESSAGES_KEY, jsonStr);
      await storage.flush();
      Logger.info('AppStorage', '消息保存成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to save messages: ${e}`);
      throw new Error(e)
    }
  }

  static async getMessages(): Promise<Message[]> {
    try {
      Logger.info('AppStorage', '正在读取历史消息');
      const storage = await AppStorage.getStorageAsync();
      const messagesStr = await storage.get(MESSAGES_KEY, '[]');
      Logger.debug('AppStorage', `读取到的JSON长度: ${(messagesStr as string).length}`);
      const messages: Message[] = JSON.parse(messagesStr as string);
      Logger.info('AppStorage', `解析后消息数量: ${messages.length}`);
      if (messages.length > 0) {
        Logger.debug('AppStorage', `第一条消息样例: ${JSON.stringify(messages[0])}`);
      }
      return messages;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get messages: ${e}`);
      return [];
    }
  }

  static async clearMessages(): Promise<void> {
    try {
      const storage = await AppStorage.getStorageAsync();
      await storage.delete(MESSAGES_KEY);
      await storage.flush();
      Logger.info('AppStorage', '消息已清空');
    } catch (e) {
      Logger.error('AppStorage', `Failed to clear messages: ${e}`);
      throw new Error(e)
    }
  }

  // System prompt management methods
  static async saveSystemPrompts(prompts: SystemPrompt[]): Promise<void> {
    try {
      Logger.info('AppStorage', '=== 开始保存系统提示词 ===');
      Logger.info('AppStorage', `正在保存 ${prompts.length} 条系统提示词`);

      // 详细打印每条提示词
      prompts.forEach((prompt, index) => {
        Logger.debug('AppStorage', `保存提示词[${index}]: ID=${prompt.id}, 名称=${prompt.name}`);
      });

      // 转换为可序列化对象
      const serializablePrompts: SystemPromptData[] = prompts.map(prompt => prompt.toObject());

      const storage = await AppStorage.getStorageAsync();
      const jsonStr = JSON.stringify(serializablePrompts);
      Logger.debug('AppStorage', `系统提示词JSON长度: ${jsonStr.length}`);

      await storage.put(SYSTEM_PROMPTS_KEY, jsonStr);
      await storage.flush();

      Logger.info('AppStorage', '✅ 系统提示词保存成功');
    } catch (e) {
      Logger.error('AppStorage', `❌ Failed to save system prompts: ${e}`);
      if (e instanceof Error) {
        Logger.error('AppStorage', `错误堆栈: ${e.stack}`);
      }
      throw new Error(e)
    }
  }

  static async getSystemPrompts(): Promise<SystemPrompt[]> {
    try {
      Logger.info('AppStorage', '=== 开始读取系统提示词 ===');

      const storage = await AppStorage.getStorageAsync();
      const promptsStr = await storage.get(SYSTEM_PROMPTS_KEY, '[]');
      Logger.debug('AppStorage', `读取到的字符串长度: ${(promptsStr as string).length}`);

      if (!promptsStr || promptsStr === '[]') {
        Logger.info('AppStorage', '⚠️ 没有找到系统提示词，返回空数组');
        return [];
      }

      const parsedObjects: SystemPromptData[] = JSON.parse(promptsStr as string);
      const prompts: SystemPrompt[] = parsedObjects.map((obj: SystemPromptData) => SystemPrompt.fromObject(obj));
      Logger.info('AppStorage', `解析后系统提示词数量: ${prompts.length}`);

      // 详细打印每条提示词
      prompts.forEach((prompt, index) => {
        Logger.debug('AppStorage', `读取提示词[${index}]: ID=${prompt.id}, 名称=${prompt.name}`);
      });

      Logger.info('AppStorage', '✅ 系统提示词读取成功');
      return prompts;
    } catch (e) {
      Logger.error('AppStorage', `❌ Failed to get system prompts: ${e}`);
      if (e instanceof Error) {
        Logger.error('AppStorage', `错误详情: ${e.stack}`);
      }
      return [];
    }
  }

  static async addSystemPrompt(prompt: SystemPrompt): Promise<void> {
    try {
      Logger.info('AppStorage', `添加系统提示词: ${prompt.name}`);
      const prompts = await AppStorage.getSystemPrompts();
      prompts.push(prompt);
      await AppStorage.saveSystemPrompts(prompts);
      Logger.info('AppStorage', '系统提示词添加成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to add system prompt: ${e}`);
      throw new Error(e)
    }
  }

  static async updateSystemPrompt(prompt: SystemPrompt): Promise<void> {
    try {
      const prompts = await AppStorage.getSystemPrompts();
      const index = prompts.findIndex(p => p.id === prompt.id);
      if (index !== -1) {
        prompts[index] = prompt;
        await AppStorage.saveSystemPrompts(prompts);
      }
    } catch (e) {
      console.error('Failed to update system prompt.', e);
    }
  }

  static async deleteSystemPrompt(promptId: string): Promise<void> {
    try {
      const prompts = await AppStorage.getSystemPrompts();
      const filteredPrompts = prompts.filter(p => p.id !== promptId);
      await AppStorage.saveSystemPrompts(filteredPrompts);
    } catch (e) {
      Logger.error('AppStorage', 'Failed to delete system prompt.', e);
    }
  }

  static async clearSystemPrompts(): Promise<void> {
    try {
      const storage = AppStorage.getStorage();
      await storage.delete(SYSTEM_PROMPTS_KEY);
      await storage.flush();
    } catch (e) {
      console.error('Failed to clear system prompts.', e);
    }
  }

  // 获取默认系统提示词
  static getDefaultSystemPrompts(): SystemPrompt[] {
    return DefaultPrompts.getAllPrompts();
  }

  // 初始化默认系统提示词
  static async initializeDefaultPrompts(): Promise<void> {
    try {
      const existingPrompts = await AppStorage.getSystemPrompts();
      if (existingPrompts.length === 0) {
        const defaultPrompts = AppStorage.getDefaultSystemPrompts();
        await AppStorage.saveSystemPrompts(defaultPrompts);
        console.info('已初始化默认系统提示词');
      }
    } catch (e) {
      console.error('Failed to initialize default prompts.', e);
    }
  }


  // 自动语音播报设置管理方法
  
  /**
   * 获取默认语音播报设置
   */
  static getDefaultAutoTTSSettings(): AutoTTSSettings {
    return {
      muted: false,            // 默认不静音
      speed: 1.0,              // 正常语速
      volume: 0.8,             // 80%音量
      pitch: 1.0,              // 正常音调
      language: 'zh-CN',       // 中文
      autoPlayOnReceive: true  // 收到回复时自动播放
    };
  }

  /**
   * 保存自动播报设置
   */
  static async saveAutoTTSSettings(settings: AutoTTSSettings): Promise<void> {
    try {
      console.info('正在保存自动播报设置:', JSON.stringify(settings));
      const storage = AppStorage.getStorage();
      const jsonStr = JSON.stringify(settings);
      await storage.put(AUTO_TTS_SETTINGS_KEY, jsonStr);
      await storage.flush();
      console.info('自动播报设置保存成功');
    } catch (e) {
      console.error('Failed to save auto TTS settings.', e);
    }
  }

  /**
   * 获取自动播报设置
   */
  static async getAutoTTSSettings(): Promise<AutoTTSSettings> {
    try {
      console.info('正在读取自动播报设置');
      const storage = AppStorage.getStorage();
      const settingsStr = await storage.get(AUTO_TTS_SETTINGS_KEY, '');
      
      if (!settingsStr) {
        console.info('没有找到自动播报设置，使用默认设置');
        const defaultSettings = AppStorage.getDefaultAutoTTSSettings();
        await AppStorage.saveAutoTTSSettings(defaultSettings);
        return defaultSettings;
      }
      
      const settings: AutoTTSSettings = JSON.parse(settingsStr as string);
      console.info('自动播报设置读取成功:', JSON.stringify(settings));
      return settings;
    } catch (e) {
      console.error('Failed to get auto TTS settings.', e);
      return AppStorage.getDefaultAutoTTSSettings();
    }
  }

  /**
   * 更新自动播报设置
   */
  static async updateAutoTTSSettings(updates: Partial<AutoTTSSettings>): Promise<void> {
    try {
      const currentSettings = await AppStorage.getAutoTTSSettings();
      const newSettings: AutoTTSSettings = {
        muted: updates.muted !== undefined ? updates.muted : currentSettings.muted,
        speed: updates.speed !== undefined ? updates.speed : currentSettings.speed,
        volume: updates.volume !== undefined ? updates.volume : currentSettings.volume,
        pitch: updates.pitch !== undefined ? updates.pitch : currentSettings.pitch,
        language: updates.language !== undefined ? updates.language : currentSettings.language,
        autoPlayOnReceive: updates.autoPlayOnReceive !== undefined ? updates.autoPlayOnReceive : currentSettings.autoPlayOnReceive
      };
      await AppStorage.saveAutoTTSSettings(newSettings);
      console.info('自动播报设置更新成功');
    } catch (e) {
      console.error('Failed to update auto TTS settings.', e);
    }
  }

  /**
   * 重置自动播报设置为默认值
   */
  static async resetAutoTTSSettings(): Promise<void> {
    try {
      const defaultSettings = AppStorage.getDefaultAutoTTSSettings();
      await AppStorage.saveAutoTTSSettings(defaultSettings);
      console.info('自动播报设置已重置为默认值');
    } catch (e) {
      console.error('Failed to reset auto TTS settings.', e);
    }
  }

  // 头像设置管理方法

  /**
   * 获取默认头像设置
   */
  static getDefaultAvatarSettings(): AvatarSettings {
    return new AvatarSettings('default', '#4285F4', 'default', '#34A853');
  }

  /**
   * 保存头像设置
   */
  static async saveAvatarSettings(settings: AvatarSettings): Promise<void> {
    try {
      Logger.info('AppStorage', `正在保存头像设置: ${JSON.stringify(settings.toObject())}`);
      const storage = await AppStorage.getStorageAsync();
      const jsonStr = JSON.stringify(settings.toObject());
      await storage.put(AVATAR_SETTINGS_KEY, jsonStr);
      await storage.flush();
      Logger.info('AppStorage', '头像设置保存成功');

      // 通知所有监听器
      AppStorage.notifyAvatarListeners(settings.clone());
    } catch (e) {
      Logger.error('AppStorage', `Failed to save avatar settings: ${e}`);
      throw new Error(e)
    }
  }

  /**
   * 获取头像设置
   */
  static async getAvatarSettings(): Promise<AvatarSettings> {
    try {
      Logger.info('AppStorage', '正在读取头像设置');
      const storage = await AppStorage.getStorageAsync();
      const settingsStr = await storage.get(AVATAR_SETTINGS_KEY, '');

      if (!settingsStr) {
        Logger.info('AppStorage', '没有找到头像设置，使用默认设置');
        const defaultSettings = AppStorage.getDefaultAvatarSettings();
        await AppStorage.saveAvatarSettings(defaultSettings);
        return defaultSettings;
      }

      const settingsObj: AvatarSettingsData = JSON.parse(settingsStr as string);
      const settings = new AvatarSettings(
        settingsObj.userAvatarType,
        settingsObj.userAvatarValue,
        settingsObj.aiAvatarType,
        settingsObj.aiAvatarValue
      );
      Logger.info('AppStorage', `头像设置读取成功: ${JSON.stringify(settings.toObject())}`);
      return settings;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get avatar settings: ${e}`);
      return AppStorage.getDefaultAvatarSettings();
    }
  }

  /**
   * 更新头像设置
   */
  static async updateAvatarSettings(updates: Partial<AvatarSettings>): Promise<void> {
    try {
      const currentSettings = await AppStorage.getAvatarSettings();
      const newSettings = new AvatarSettings(
        updates.userAvatarType !== undefined ? updates.userAvatarType : currentSettings.userAvatarType,
        updates.userAvatarValue !== undefined ? updates.userAvatarValue : currentSettings.userAvatarValue,
        updates.aiAvatarType !== undefined ? updates.aiAvatarType : currentSettings.aiAvatarType,
        updates.aiAvatarValue !== undefined ? updates.aiAvatarValue : currentSettings.aiAvatarValue
      );
      await AppStorage.saveAvatarSettings(newSettings);
      Logger.info('AppStorage', '头像设置更新成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to update avatar settings: ${e}`);
    }
  }

  /**
   * 添加头像设置监听器
   */
  static addAvatarListener(listener: (settings: AvatarSettings) => void): void {
    AppStorage.avatarListeners.push(listener);
    Logger.info('AppStorage', `添加头像监听器，当前监听器数量: ${AppStorage.avatarListeners.length}`);
  }

  /**
   * 移除头像设置监听器
   */
  static removeAvatarListener(listener: (settings: AvatarSettings) => void): void {
    const index = AppStorage.avatarListeners.indexOf(listener);
    if (index > -1) {
      AppStorage.avatarListeners.splice(index, 1);
      Logger.info('AppStorage', `移除头像监听器，当前监听器数量: ${AppStorage.avatarListeners.length}`);
    }
  }

  /**
   * 通知所有头像设置监听器
   */
  private static notifyAvatarListeners(settings: AvatarSettings): void {
    Logger.info('AppStorage', `通知 ${AppStorage.avatarListeners.length} 个头像监听器`);
    AppStorage.avatarListeners.forEach((listener, index) => {
      try {
        listener(settings);
        Logger.debug('AppStorage', `头像监听器 ${index} 通知成功`);
      } catch (error) {
        Logger.error('AppStorage', `头像监听器 ${index} 通知失败: ${error}`);
      }
    });
  }

  //=================== 会话数据清除通知方法 ===================

  /**
   * 添加会话数据清除监听器
   */
  static addSessionDataClearedListener(listener: () => void): void {
    AppStorage.sessionDataClearedListeners.push(listener);
    Logger.info('AppStorage', `添加会话数据清除监听器，当前监听器数量: ${AppStorage.sessionDataClearedListeners.length}`);
  }

  /**
   * 移除会话数据清除监听器
   */
  static removeSessionDataClearedListener(listener: () => void): void {
    const index = AppStorage.sessionDataClearedListeners.indexOf(listener);
    if (index > -1) {
      AppStorage.sessionDataClearedListeners.splice(index, 1);
      Logger.info('AppStorage', `移除会话数据清除监听器，当前监听器数量: ${AppStorage.sessionDataClearedListeners.length}`);
    }
  }

  /**
   * 通知所有会话数据清除监听器
   */
  static notifySessionDataClearedListeners(): void {
    Logger.info('AppStorage', `通知 ${AppStorage.sessionDataClearedListeners.length} 个会话数据清除监听器`);
    AppStorage.sessionDataClearedListeners.forEach((listener, index) => {
      try {
        listener();
        Logger.debug('AppStorage', `会话数据清除监听器 ${index} 通知成功`);
      } catch (error) {
        Logger.error('AppStorage', `会话数据清除监听器 ${index} 通知失败: ${error}`);
      }
    });
  }

  /**
   * 重置头像设置为默认值
   */
  static async resetAvatarSettings(): Promise<void> {
    try {
      const defaultSettings = AppStorage.getDefaultAvatarSettings();
      await AppStorage.saveAvatarSettings(defaultSettings);
      Logger.info('AppStorage', '头像设置已重置为默认值');
    } catch (e) {
      Logger.error('AppStorage', `Failed to reset avatar settings: ${e}`);
    }
  }

  //=================== 用户资料管理存储方法 ===================

  /**
   * 获取默认用户资料
   */
  static getDefaultUserProfile(): UserProfile {
    return new UserProfile();
  }

  /**
   * 保存用户资料
   */
  static async saveUserProfile(profile: UserProfile): Promise<void> {
    try {
      Logger.info('AppStorage', `保存用户资料: ${profile.userName} - ${profile.userSignature}`);
      const storage = AppStorage.getStorage();
      const jsonStr = JSON.stringify(profile.toObject());
      await storage.put(USER_PROFILE_KEY, jsonStr);
      await storage.flush();
      
      // 通知监听器
      AppStorage.notifyUserProfileListeners(profile.clone());
      Logger.info('AppStorage', '用户资料保存成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to save user profile: ${e}`);
    }
  }

  /**
   * 获取用户资料
   */
  static async getUserProfile(): Promise<UserProfile> {
    try {
      Logger.info('AppStorage', '正在读取用户资料');
      const storage = AppStorage.getStorage();
      const profileStr = await storage.get(USER_PROFILE_KEY, '');
      
      if (!profileStr) {
        Logger.info('AppStorage', '没有找到用户资料，使用默认资料');
        const defaultProfile = AppStorage.getDefaultUserProfile();
        await AppStorage.saveUserProfile(defaultProfile);
        return defaultProfile;
      }
      
      const profileObj: UserProfileData = JSON.parse(profileStr as string);
      const profile = new UserProfile(
        profileObj.userName,
        profileObj.userSignature,
        profileObj.userAvatarType,
        profileObj.userAvatarValue,
        profileObj.updatedAt
      );
      Logger.info('AppStorage', `用户资料读取成功: ${JSON.stringify(profile.toObject())}`);
      return profile;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get user profile: ${e}`);
      return AppStorage.getDefaultUserProfile();
    }
  }

  /**
   * 更新用户资料
   */
  static async updateUserProfile(updates: Partial<UserProfileData>): Promise<void> {
    try {
      const currentProfile = await AppStorage.getUserProfile();
      const newProfile = new UserProfile(
        updates.userName !== undefined ? updates.userName : currentProfile.userName,
        updates.userSignature !== undefined ? updates.userSignature : currentProfile.userSignature,
        updates.userAvatarType !== undefined ? updates.userAvatarType : currentProfile.userAvatarType,
        updates.userAvatarValue !== undefined ? updates.userAvatarValue : currentProfile.userAvatarValue,
        Date.now() // 更新时间戳
      );
      await AppStorage.saveUserProfile(newProfile);
      Logger.info('AppStorage', '用户资料更新成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to update user profile: ${e}`);
    }
  }

  /**
   * 添加用户资料监听器
   */
  static addUserProfileListener(listener: (profile: UserProfile) => void): void {
    AppStorage.userProfileListeners.push(listener);
    Logger.info('AppStorage', `添加用户资料监听器，当前监听器数量: ${AppStorage.userProfileListeners.length}`);
  }

  /**
   * 移除用户资料监听器
   */
  static removeUserProfileListener(listener: (profile: UserProfile) => void): void {
    const index = AppStorage.userProfileListeners.indexOf(listener);
    if (index > -1) {
      AppStorage.userProfileListeners.splice(index, 1);
      Logger.info('AppStorage', `移除用户资料监听器，当前监听器数量: ${AppStorage.userProfileListeners.length}`);
    }
  }

  /**
   * 通知所有用户资料监听器
   */
  private static notifyUserProfileListeners(profile: UserProfile): void {
    Logger.info('AppStorage', `通知 ${AppStorage.userProfileListeners.length} 个用户资料监听器`);
    AppStorage.userProfileListeners.forEach((listener, index) => {
      try {
        listener(profile);
        Logger.debug('AppStorage', `用户资料监听器 ${index} 通知成功`);
      } catch (error) {
        Logger.error('AppStorage', `用户资料监听器 ${index} 通知失败: ${error}`);
      }
    });
  }

  /**
   * 重置用户资料为默认值
   */
  static async resetUserProfile(): Promise<void> {
    try {
      const defaultProfile = AppStorage.getDefaultUserProfile();
      await AppStorage.saveUserProfile(defaultProfile);
      Logger.info('AppStorage', '用户资料已重置为默认值');
    } catch (e) {
      Logger.error('AppStorage', `Failed to reset user profile: ${e}`);
    }
  }

  //=================== 会话管理存储方法 ===================

  /**
   * 保存会话信息
   */
  static async saveSession(session: Session): Promise<void> {
    try {
      Logger.info('AppStorage', `保存会话: ${session.id} - ${session.name}`);
      
      // 获取现有会话列表
      const sessions = await AppStorage.getSessions();
      
      // 查找是否存在相同ID的会话
      const existingIndex = sessions.findIndex(s => s.id === session.id);
      
      if (existingIndex >= 0) {
        // 更新现有会话
        sessions[existingIndex] = session;
        Logger.info('AppStorage', `更新现有会话: ${session.id}`);
      } else {
        // 添加新会话
        sessions.push(session);
        Logger.info('AppStorage', `添加新会话: ${session.id}`);
      }
      
      // 保存会话列表
      const storage = AppStorage.getStorage();
      const serializableSessions: SessionData[] = sessions.map(s => s.toObject());
      const jsonStr = JSON.stringify(serializableSessions);
      
      await storage.put(SESSIONS_KEY, jsonStr);
      await storage.flush();
      
      Logger.info('AppStorage', `会话保存成功，当前会话数: ${sessions.length}`);
    } catch (e) {
      Logger.error('AppStorage', `Failed to save session: ${e}`);
    }
  }

  /**
   * 获取所有会话
   */
  static async getSessions(): Promise<Session[]> {
    try {
      Logger.debug('AppStorage', '读取会话列表');
      const storage = await AppStorage.getStorageAsync();
      const sessionsStr = await storage.get(SESSIONS_KEY, '[]');

      if (!sessionsStr || sessionsStr === '[]') {
        Logger.debug('AppStorage', '没有找到会话，返回空数组');
        return [];
      }

      const parsedObjects: SessionData[] = JSON.parse(sessionsStr as string);
      const sessions: Session[] = parsedObjects.map((obj: SessionData) => Session.fromObject(obj));

      Logger.debug('AppStorage', `读取到 ${sessions.length} 个会话`);
      return sessions;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get sessions: ${e}`);
      return [];
    }
  }

  /**
   * 删除会话
   */
  static async deleteSession(sessionId: string): Promise<void> {
    try {
      Logger.info('AppStorage', `删除会话: ${sessionId}`);
      
      // 获取现有会话列表
      const sessions = await AppStorage.getSessions();
      
      // 过滤掉要删除的会话
      const filteredSessions = sessions.filter(s => s.id !== sessionId);
      
      if (filteredSessions.length === sessions.length) {
        Logger.warn('AppStorage', `会话不存在: ${sessionId}`);
        return;
      }
      
      // 保存更新后的会话列表
      const storage = AppStorage.getStorage();
      const serializableSessions: SessionData[] = filteredSessions.map(s => s.toObject());
      const jsonStr = JSON.stringify(serializableSessions);
      
      await storage.put(SESSIONS_KEY, jsonStr);
      await storage.flush();
      
      Logger.info('AppStorage', `会话删除成功: ${sessionId}`);
    } catch (e) {
      Logger.error('AppStorage', `Failed to delete session: ${e}`);
    }
  }

  /**
   * 清空所有会话
   */
  static async clearSessions(): Promise<void> {
    try {
      const storage = AppStorage.getStorage();
      await storage.delete(SESSIONS_KEY);
      await storage.flush();
      Logger.info('AppStorage', '所有会话已清空');
    } catch (e) {
      Logger.error('AppStorage', `Failed to clear sessions: ${e}`);
    }
  }

  /**
   * 设置当前激活的会话ID
   */
  static async setCurrentSessionId(sessionId: string): Promise<void> {
    try {
      Logger.debug('AppStorage', `设置当前会话ID: ${sessionId}`);
      const storage = AppStorage.getStorage();
      await storage.put(CURRENT_SESSION_KEY, sessionId);
      await storage.flush();
    } catch (e) {
      Logger.error('AppStorage', `Failed to set current session ID: ${e}`);
    }
  }

  /**
   * 获取当前激活的会话ID
   */
  static async getCurrentSessionId(): Promise<string | null> {
    try {
      const storage = AppStorage.getStorage();
      const sessionId = await storage.get(CURRENT_SESSION_KEY, '');
      Logger.debug('AppStorage', `获取当前会话ID: ${sessionId || 'null'}`);
      return sessionId ? sessionId as string : null;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get current session ID: ${e}`);
      return null;
    }
  }

  /**
   * 获取指定会话的消息列表
   */
  static async getSessionMessages(sessionId: string): Promise<Message[]> {
    try {
      Logger.debug('AppStorage', `读取会话消息: ${sessionId}`);
      const storage = AppStorage.getStorage();
      const messageKey = `session_${sessionId}_messages`;
      const messagesStr = await storage.get(messageKey, '[]');

      if (!messagesStr || messagesStr === '[]') {
        Logger.debug('AppStorage', `会话没有消息: ${sessionId}`);
        return [];
      }

      interface RawMessage {
        id?: string;
        role?: string;
        content?: string | null | undefined;
        timestamp?: number;
        isPlaying?: boolean;
        canPlayAudio?: boolean;
        toolStatus?: string;
        toolType?: string;
        toolName?: string;
        mcpToolNames?: string[];
        webUsed?: boolean;
        searchInfo?: string;
        searchDetails?: string;
        isDeepThinking?: boolean;
        thinkingSteps?: object[];
        thinkingStatus?: string;
      }

      const rawMessages: RawMessage[] = JSON.parse(messagesStr as string);
      Logger.debug('AppStorage', `会话 ${sessionId} 读取到 ${rawMessages.length} 条原始消息`);

      // 验证和修复消息数据
      const validMessages: Message[] = [];
      let repairedCount = 0;
      let validCount = 0;

      rawMessages.forEach((rawMsg: RawMessage, index: number) => {
        try {
          // 创建 Message 实例并确保数据完整性
          let content: string = rawMsg.content as string;

          // 修复空的或无效的content
          if (content === null || content === undefined) {
            content = '';
            repairedCount++;
            Logger.warn('AppStorage', `修复消息 ${index} 的空content: ${rawMsg.id}`);
          }

          // 确保content是字符串类型
          if (typeof content !== 'string') {
            content = String(content);
            repairedCount++;
            Logger.warn('AppStorage', `修复消息 ${index} 的content类型: ${typeof rawMsg.content} -> string`);
          }

          // 创建完整的消息对象
          const messageRole = (rawMsg.role === 'user' || rawMsg.role === 'assistant' || rawMsg.role === 'system')
            ? rawMsg.role as MessageRole
            : MessageRole.USER;

          const message = new Message(
            messageRole,
            content,
            rawMsg.id
          );

          // 恢复其他属性
          message.timestamp = rawMsg.timestamp || Date.now();
          message.isLoading = false; // 已保存的消息不应处于加载状态
          message.isPlaying = rawMsg.isPlaying || false;
          message.canPlayAudio = rawMsg.canPlayAudio || (rawMsg.role === 'assistant');
          message.toolStatus = rawMsg.toolStatus || 'idle';
          message.toolType = rawMsg.toolType || '';
          message.toolName = rawMsg.toolName || '';
          message.mcpToolNames = rawMsg.mcpToolNames || [];
          message.webUsed = rawMsg.webUsed || false;
          message.searchInfo = rawMsg.searchInfo || '';
          message.searchDetails = rawMsg.searchDetails || '';
          message.isDeepThinking = rawMsg.isDeepThinking || false;
          message.thinkingSteps = []; // 初始化为空数组，避免类型冲突
          message.thinkingStatus = ThinkingStatus.IDLE; // 使用枚举值

          validMessages.push(message);
          validCount++;

        } catch (msgError) {
          Logger.error('AppStorage', `跳过无效消息 ${index}: ${msgError}`);
        }
      });

      Logger.info('AppStorage', `消息读取完成 - 有效消息: ${validCount}, 修复消息: ${repairedCount}`);

      // 如果有修复的消息，重新保存以确保数据一致性
      if (repairedCount > 0) {
        Logger.info('AppStorage', `检测到 ${repairedCount} 条消息需要修复，重新保存会话数据`);
        await AppStorage.saveSessionMessages(sessionId, validMessages);
      }

      return validMessages;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get session messages: ${e}`);
      return [];
    }
  }

  /**
   * 保存指定会话的消息列表
   */
  static async saveSessionMessages(sessionId: string, messages: Message[]): Promise<void> {
    try {
      Logger.debug('AppStorage', `保存会话消息: ${sessionId}, 数量: ${messages.length}`);
      const storage = AppStorage.getStorage();
      const messageKey = `session_${sessionId}_messages`;

      interface StorableMessage {
        id: string;
        role: string;
        content: string;
        timestamp: number;
        isLoading: boolean;
        isPlaying: boolean;
        canPlayAudio: boolean;
        toolStatus: string;
        toolType: string;
        toolName: string;
        mcpToolNames: string[];
        webUsed: boolean;
        searchInfo: string;
        searchDetails: string;
        isDeepThinking: boolean;
        thinkingSteps: object[];
        thinkingStatus: string;
      }

      // 过滤掉正在加载的消息，并确保数据完整性
      const validMessages: StorableMessage[] = messages
        .filter(msg => !msg.isLoading)
        .map(msg => {
          // 确保每个消息都有有效的content字段
          if (!msg.content && msg.content !== '') {
            Logger.warn('AppStorage', `消息 ${msg.id} 的content为空，设置为空字符串`);
            msg.content = '';
          }

          // 创建一个干净的消息对象，确保所有必要字段都存在
          const storableMessage: StorableMessage = {
            id: msg.id || '',
            role: msg.role || 'user',
            content: msg.content || '',
            timestamp: msg.timestamp || Date.now(),
            isLoading: false,
            isPlaying: msg.isPlaying || false,
            canPlayAudio: msg.canPlayAudio || false,
            toolStatus: msg.toolStatus || 'idle',
            toolType: msg.toolType || '',
            toolName: msg.toolName || '',
            mcpToolNames: msg.mcpToolNames || [],
            webUsed: msg.webUsed || false,
            searchInfo: msg.searchInfo || '',
            searchDetails: msg.searchDetails || '',
            isDeepThinking: msg.isDeepThinking || false,
            thinkingSteps: msg.thinkingSteps || [],
            thinkingStatus: msg.thinkingStatus || 'idle'
          };
          return storableMessage;
        });

      // 验证消息数据完整性
      let validCount = 0;
      let contentNullCount = 0;
      validMessages.forEach((msg, index) => {
        if (msg.content && typeof msg.content === 'string') {
          validCount++;
        } else {
          contentNullCount++;
          Logger.warn('AppStorage', `消息 ${index} content无效: ${typeof msg.content}, 值: ${msg.content}`);
        }
      });

      Logger.info('AppStorage', `消息验证结果 - 有效消息: ${validCount}, content为空的消息: ${contentNullCount}`);

      const jsonStr = JSON.stringify(validMessages);
      Logger.debug('AppStorage', `序列化JSON长度: ${jsonStr.length}`);

      await storage.put(messageKey, jsonStr);
      await storage.flush();

      Logger.debug('AppStorage', `会话消息保存成功: ${sessionId}`);
    } catch (e) {
      Logger.error('AppStorage', `Failed to save session messages: ${e}`);
    }
  }

  /**
   * 删除指定会话的消息
   */
  static async deleteSessionMessages(sessionId: string): Promise<void> {
    try {
      Logger.info('AppStorage', `删除会话消息: ${sessionId}`);
      const storage = AppStorage.getStorage();
      const messageKey = `session_${sessionId}_messages`;
      await storage.delete(messageKey);
      await storage.flush();
      Logger.info('AppStorage', `会话消息删除成功: ${sessionId}`);
    } catch (e) {
      Logger.error('AppStorage', `Failed to delete session messages: ${e}`);
    }
  }

  //=================== API模式配置方法 ===================

  /**
   * 获取API调用模式
   */
  static async getAPIMode(): Promise<string> {
    try {
      Logger.debug('AppStorage', '读取API调用模式');
      const storage = AppStorage.getStorage();
      const mode = await storage.get(API_MODE_KEY, 'direct_call');
      Logger.debug('AppStorage', `当前API模式: ${mode}`);
      return mode as string;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get API mode: ${e}`);
      return 'direct_call'; // 默认使用直连模式
    }
  }

  /**
   * 设置API调用模式
   */
  static async setAPIMode(mode: string): Promise<void> {
    try {
      Logger.info('AppStorage', `设置API调用模式: ${mode}`);
      const storage = AppStorage.getStorage();
      await storage.put(API_MODE_KEY, mode);
      await storage.flush();
      Logger.info('AppStorage', 'API调用模式设置成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to set API mode: ${e}`);
    }
  }

  /**
   * 重置API模式为默认值（直连模式）
   */
  static async resetAPIMode(): Promise<void> {
    try {
      await AppStorage.setAPIMode('direct_call');
      Logger.info('AppStorage', 'API调用模式已重置为直连模式');
    } catch (e) {
      Logger.error('AppStorage', `Failed to reset API mode: ${e}`);
    }
  }

  //=================== 选中系统提示词管理方法 ===================

  /**
   * 保存选中的系统提示词ID
   */
  static async saveSelectedSystemPromptId(promptId: string): Promise<void> {
    try {
      Logger.info('AppStorage', `保存选中的提示词ID: ${promptId}`);
      const storage = AppStorage.getStorage();
      await storage.put(SELECTED_SYSTEM_PROMPT_KEY, promptId);
      await storage.flush();
      Logger.info('AppStorage', '选中提示词ID保存成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to save selected system prompt ID: ${e}`);
    }
  }

  /**
   * 获取选中的系统提示词ID
   */
  static async getSelectedSystemPromptId(): Promise<string | null> {
    try {
      Logger.debug('AppStorage', '读取选中的提示词ID');
      const storage = AppStorage.getStorage();
      const promptId = await storage.get(SELECTED_SYSTEM_PROMPT_KEY, '');
      Logger.debug('AppStorage', `选中的提示词ID: ${promptId || 'null'}`);
      return promptId ? promptId as string : null;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get selected system prompt ID: ${e}`);
      return null;
    }
  }

  /**
   * 清除选中的系统提示词ID
   */
  static async clearSelectedSystemPromptId(): Promise<void> {
    try {
      Logger.info('AppStorage', '清除选中的提示词ID');
      const storage = AppStorage.getStorage();
      await storage.delete(SELECTED_SYSTEM_PROMPT_KEY);
      await storage.flush();
      Logger.info('AppStorage', '选中提示词ID已清除');
    } catch (e) {
      Logger.error('AppStorage', `Failed to clear selected system prompt ID: ${e}`);
    }
  }

  //=================== 消息布局偏好设置 ===================

  /**
   * 保存消息布局偏好设置
   */
  static async saveMessageLayoutPreference(useModernLayout: boolean): Promise<void> {
    try {
      Logger.info('AppStorage', `保存消息布局偏好: ${useModernLayout ? '现代布局' : '传统气泡'}`);
      const storage = AppStorage.getStorage();
      await storage.put(MESSAGE_LAYOUT_KEY, useModernLayout);
      await storage.flush();
      Logger.info('AppStorage', '消息布局偏好保存成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to save message layout preference: ${e}`);
    }
  }

  /**
   * 获取消息布局偏好设置
   */
  static async getMessageLayoutPreference(): Promise<boolean> {
    try {
      Logger.debug('AppStorage', '读取消息布局偏好');
      const storage = AppStorage.getStorage();
      const useModernLayout = await storage.get(MESSAGE_LAYOUT_KEY, false);
      Logger.debug('AppStorage', `消息布局偏好: ${useModernLayout ? '现代布局' : '传统气泡'}`);
      return useModernLayout as boolean;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get message layout preference: ${e}`);
      return false; // 默认使用传统气泡布局
    }
  }

  /**
   * 重置消息布局偏好为默认值
   */
  static async resetMessageLayoutPreference(): Promise<void> {
    try {
      Logger.info('AppStorage', '重置消息布局偏好为默认值');
      const storage = AppStorage.getStorage();
      await storage.delete(MESSAGE_LAYOUT_KEY);
      await storage.flush();
      Logger.info('AppStorage', '消息布局偏好已重置为默认值（传统气泡）');
    } catch (e) {
      Logger.error('AppStorage', `Failed to reset message layout preference: ${e}`);
    }
  }

  //=================== API密钥管理设置 ===================

  /**
   * 保存API密钥配置
   */
  static async saveAPIKeys(config: object): Promise<void> {
    try {
      Logger.info('AppStorage', '保存API密钥配置');
      const storage = AppStorage.getStorage();
      await storage.put(API_KEYS_KEY, config);
      await storage.flush();
      Logger.info('AppStorage', 'API密钥配置保存成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to save API keys: ${e}`);
      throw new Error(`Failed to save API keys: ${e}`);
    }
  }

  /**
   * 获取API密钥配置
   */
  static async getAPIKeys(): Promise<Record<string, object>> {
    try {
      Logger.debug('AppStorage', '读取API密钥配置');
      const storage = AppStorage.getStorage();
      const config = await storage.get(API_KEYS_KEY, {});
      Logger.debug('AppStorage', `API密钥配置加载完成，包含 ${Object.keys(config).length} 个厂商`);
      return config as Record<string, object>;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get API keys: ${e}`);
      return {};
    }
  }

  /**
   * 清除API密钥配置
   */
  static async clearAPIKeys(): Promise<void> {
    try {
      Logger.info('AppStorage', '清除API密钥配置');
      const storage = AppStorage.getStorage();
      await storage.delete(API_KEYS_KEY);
      await storage.flush();
      Logger.info('AppStorage', 'API密钥配置已清除');
    } catch (e) {
      Logger.error('AppStorage', `Failed to clear API keys: ${e}`);
      throw new Error(`Failed to clear API keys: ${e}`);
    }
  }

  // ===================== 模型选择配置管理 =====================

  /**
   * 保存当前选择的模型配置
   */
  static async saveCurrentModel(provider: string, model: string): Promise<void> {
    try {
      Logger.info('AppStorage', `保存模型选择: ${provider}.${model}`);
      const storage = AppStorage.getStorage();
      
      const config: ModelConfig = {
        provider: provider,
        model: model,
        savedAt: Date.now()
      };
      
      await storage.put(CURRENT_MODEL_KEY, JSON.stringify(config));
      await storage.flush();
      Logger.info('AppStorage', '模型选择已保存');
    } catch (e) {
      Logger.error('AppStorage', `Failed to save current model: ${e}`);
      throw new Error(`Failed to save current model: ${e}`);
    }
  }

  /**
   * 获取当前选择的模型配置
   */
  static async getCurrentModelConfig(): Promise<ModelConfig | null> {
    try {
      Logger.debug('AppStorage', '读取模型选择配置');
      const storage = AppStorage.getStorage();
      const configStr = await storage.get(CURRENT_MODEL_KEY, '') as string;
      
      if (!configStr) {
        Logger.debug('AppStorage', '没有找到保存的模型选择');
        return null;
      }
      
      const config = JSON.parse(configStr) as ModelConfig;
      Logger.debug('AppStorage', `找到保存的模型选择: ${config.provider}.${config.model}`);
      return config;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get current model config: ${e}`);
      return null;
    }
  }

  /**
   * 清除保存的模型选择配置
   */
  static async clearCurrentModel(): Promise<void> {
    try {
      Logger.info('AppStorage', '清除模型选择配置');
      const storage = AppStorage.getStorage();
      await storage.delete(CURRENT_MODEL_KEY);
      await storage.flush();
      Logger.info('AppStorage', '模型选择配置已清除');
    } catch (e) {
      Logger.error('AppStorage', `Failed to clear current model: ${e}`);
      throw new Error(`Failed to clear current model: ${e}`);
    }
  }

  /**
   * 检查保存的模型配置是否过期（超过30天自动清理）
   */
  static async isModelConfigExpired(): Promise<boolean> {
    try {
      const config = await AppStorage.getCurrentModelConfig();
      if (!config) {
        return false; // 没有配置，不算过期
      }
      
      const thirtyDays = 30 * 24 * 60 * 60 * 1000; // 30天的毫秒数
      const isExpired = (Date.now() - config.savedAt) > thirtyDays;
      
      if (isExpired) {
        Logger.info('AppStorage', '模型选择配置已过期，将清除');
        await AppStorage.clearCurrentModel();
      }
      
      return isExpired;
    } catch (e) {
      Logger.error('AppStorage', `Failed to check model config expiration: ${e}`);
      return false;
    }
  }

  //=================== 字体设置相关方法 ===================

  /**
   * 获取字体设置
   */
  static async getFontSettings(): Promise<FontSettings> {
    try {
      const storage = AppStorage.getStorage();
      const fontSettingsStr = await storage.get(FONT_SETTINGS_KEY, '');

      if (fontSettingsStr && typeof fontSettingsStr === 'string') {
        const settings = JSON.parse(fontSettingsStr) as FontSettings;
        Logger.debug('AppStorage', `字体设置加载成功: ${JSON.stringify(settings)}`);
        return settings;
      } else {
        Logger.info('AppStorage', '未找到字体设置，返回默认值');
        return AppStorage.getDefaultFontSettings();
      }
    } catch (e) {
      Logger.error('AppStorage', `Failed to get font settings: ${e}`);
      return AppStorage.getDefaultFontSettings();
    }
  }

  /**
   * 保存字体设置
   */
  static async saveFontSettings(settings: FontSettings): Promise<void> {
    try {
      // 验证设置值的有效性
      const validatedSettings = AppStorage.validateFontSettings(settings);

      const storage = AppStorage.getStorage();
      await storage.put(FONT_SETTINGS_KEY, JSON.stringify(validatedSettings));
      await storage.flush();

      Logger.info('AppStorage', `字体设置已保存: ${JSON.stringify(validatedSettings)}`);

      // 通知监听器
      AppStorage.notifyFontSettingsListeners(validatedSettings);
    } catch (e) {
      Logger.error('AppStorage', `Failed to save font settings: ${e}`);
      throw new Error(`Failed to save font settings: ${e}`);
    }
  }

  /**
   * 更新字体设置（部分更新）
   */
  static async updateFontSettings(updates: Partial<FontSettings>): Promise<FontSettings> {
    try {
      const currentSettings = await AppStorage.getFontSettings();
      const newSettings: FontSettings = {
        chatFontSize: updates.chatFontSize !== undefined ? updates.chatFontSize : currentSettings.chatFontSize,
        codeFontSize: updates.codeFontSize !== undefined ? updates.codeFontSize : currentSettings.codeFontSize,
        fontFamily: updates.fontFamily !== undefined ? updates.fontFamily : currentSettings.fontFamily,
        updatedAt: Date.now()
      };

      await AppStorage.saveFontSettings(newSettings);
      return newSettings;
    } catch (e) {
      Logger.error('AppStorage', `Failed to update font settings: ${e}`);
      throw new Error(`Failed to update font settings: ${e}`);
    }
  }

  /**
   * 获取默认字体设置
   */
  static getDefaultFontSettings(): FontSettings {
    return {
      chatFontSize: 16,        // 默认聊天字体大小
      codeFontSize: 14,        // 默认代码字体大小
      fontFamily: 'system',    // 默认系统字体
      updatedAt: Date.now()
    };
  }

  /**
   * 验证字体设置的有效性
   */
  private static validateFontSettings(settings: FontSettings): FontSettings {
    const validFontFamilies: Array<'system' | 'serif' | 'monospace' | 'rounded' | 'elegant' | 'playful' | 'modern' | 'classic'> = ['system', 'serif', 'monospace', 'rounded', 'elegant', 'playful', 'modern', 'classic'];
    const fontFamily = validFontFamilies.includes(settings.fontFamily) ? settings.fontFamily : 'system';

    return {
      chatFontSize: Math.max(12, Math.min(20, settings.chatFontSize || 16)),
      codeFontSize: Math.max(10, Math.min(18, settings.codeFontSize || 14)),
      fontFamily: fontFamily,
      updatedAt: settings.updatedAt || Date.now()
    };
  }

  /**
   * 重置字体设置为默认值
   */
  static async resetFontSettings(): Promise<void> {
    try {
      const defaultSettings = AppStorage.getDefaultFontSettings();
      await AppStorage.saveFontSettings(defaultSettings);
      Logger.info('AppStorage', '字体设置已重置为默认值');
    } catch (e) {
      Logger.error('AppStorage', `Failed to reset font settings: ${e}`);
      throw new Error(`Failed to reset font settings: ${e}`);
    }
  }

  //=================== 字体设置监听器相关方法 ===================

  private static fontSettingsListeners: ((settings: FontSettings) => void)[] = [];

  /**
   * 添加字体设置变更监听器
   */
  static addFontSettingsListener(listener: (settings: FontSettings) => void): void {
    AppStorage.fontSettingsListeners.push(listener);
    Logger.debug('AppStorage', `添加字体设置监听器，当前监听器数量: ${AppStorage.fontSettingsListeners.length}`);
  }

  /**
   * 移除字体设置变更监听器
   */
  static removeFontSettingsListener(listener: (settings: FontSettings) => void): void {
    const index = AppStorage.fontSettingsListeners.indexOf(listener);
    if (index > -1) {
      AppStorage.fontSettingsListeners.splice(index, 1);
      Logger.debug('AppStorage', `移除字体设置监听器，当前监听器数量: ${AppStorage.fontSettingsListeners.length}`);
    }
  }

  /**
   * 通知所有字体设置监听器
   */
  private static notifyFontSettingsListeners(settings: FontSettings): void {
    Logger.debug('AppStorage', `通知 ${AppStorage.fontSettingsListeners.length} 个字体设置监听器`);
    AppStorage.fontSettingsListeners.forEach(listener => {
      try {
        listener(settings);
      } catch (e) {
        Logger.error('AppStorage', `字体设置监听器执行失败: ${e}`);
      }
    });
  }

  //=================== MCP配置相关方法 ===================

  /**
   * 获取MCP配置
   */
  static async getMCPConfiguration(): Promise<MCPConfiguration | null> {
    try {
      const storage = AppStorage.getStorage();
      const configStr = await storage.get(MCP_CONFIGURATION_KEY, '');

      if (configStr && typeof configStr === 'string') {
        const config = JSON.parse(configStr) as MCPConfiguration;
        Logger.debug('AppStorage', `MCP配置加载成功: ${config.servers.length} 个服务器`);
        return config;
      } else {
        Logger.info('AppStorage', '未找到MCP配置');
        return null;
      }
    } catch (e) {
      Logger.error('AppStorage', `Failed to get MCP configuration: ${e}`);
      return null;
    }
  }

  /**
   * 保存MCP配置
   */
  static async saveMCPConfiguration(config: MCPConfiguration): Promise<void> {
    try {
      // 验证配置的有效性
      const validatedConfig = AppStorage.validateMCPConfiguration(config);

      const storage = AppStorage.getStorage();
      await storage.put(MCP_CONFIGURATION_KEY, JSON.stringify(validatedConfig));
      await storage.flush();

      Logger.info('AppStorage', `MCP配置已保存: ${validatedConfig.servers.length} 个服务器`);

      // 通知监听器
      AppStorage.notifyMCPConfigurationListeners(validatedConfig);
    } catch (e) {
      Logger.error('AppStorage', `Failed to save MCP configuration: ${e}`);
      throw new Error(`Failed to save MCP configuration: ${e}`);
    }
  }

  /**
   * 添加MCP服务器配置
   */
  static async addMCPServer(serverConfig: MCPServerConfigData): Promise<void> {
    try {
      const config = await AppStorage.getMCPConfiguration() || {
        servers: [],
        lastModified: Date.now()
      };

      // 检查服务器名称是否已存在
      const existingIndex = config.servers.findIndex(server => server.name === serverConfig.name);
      if (existingIndex >= 0) {
        // 更新现有服务器
        config.servers[existingIndex] = serverConfig;
        Logger.info('AppStorage', `MCP服务器配置已更新: ${serverConfig.name}`);
      } else {
        // 添加新服务器
        config.servers.push(serverConfig);
        Logger.info('AppStorage', `MCP服务器配置已添加: ${serverConfig.name}`);
      }

      config.lastModified = Date.now();
      await AppStorage.saveMCPConfiguration(config);
    } catch (e) {
      Logger.error('AppStorage', `Failed to add MCP server: ${e}`);
      throw new Error(`Failed to add MCP server: ${e}`);
    }
  }

  /**
   * 移除MCP服务器配置
   */
  static async removeMCPServer(serverName: string): Promise<void> {
    try {
      const config = await AppStorage.getMCPConfiguration();
      if (!config) {
        Logger.warn('AppStorage', 'No MCP configuration found');
        return;
      }

      const initialLength = config.servers.length;
      config.servers = config.servers.filter(server => server.name !== serverName);

      if (config.servers.length < initialLength) {
        config.lastModified = Date.now();
        await AppStorage.saveMCPConfiguration(config);
        Logger.info('AppStorage', `MCP服务器配置已移除: ${serverName}`);
      } else {
        Logger.warn('AppStorage', `MCP服务器不存在: ${serverName}`);
      }
    } catch (e) {
      Logger.error('AppStorage', `Failed to remove MCP server: ${e}`);
      throw new Error(`Failed to remove MCP server: ${e}`);
    }
  }

  /**
   * 获取默认MCP配置
   */
  static getDefaultMCPConfiguration(): MCPConfiguration {
    return {
      servers: [],
      lastModified: Date.now()
    };
  }

  /**
   * 验证MCP配置的有效性
   */
  private static validateMCPConfiguration(config: MCPConfiguration): MCPConfiguration {
    const validatedServers = config.servers.map(server => AppStorage.validateMCPServerConfig(server));

    return {
      servers: validatedServers,
      lastModified: config.lastModified || Date.now()
    };
  }

  /**
   * 验证MCP服务器配置的有效性
   */
  private static validateMCPServerConfig(server: MCPServerConfigData): MCPServerConfigData {
    const validTransportTypes: Array<'stdio' | 'http_sse'> = ['stdio', 'http_sse'];
    const transportType = validTransportTypes.includes(server.transportType) ? server.transportType : 'http_sse';

    return {
      name: server.name || 'unnamed_server',
      description: server.description,
      transportType: transportType,
      command: server.command,
      args: server.args || [],
      env: server.env || {},
      url: server.url,
      timeout: Math.max(5000, Math.min(60000, server.timeout || 30000)),
      retryAttempts: Math.max(0, Math.min(10, server.retryAttempts || 3))
    };
  }

  /**
   * 重置MCP配置为默认值
   */
  static async resetMCPConfiguration(): Promise<void> {
    try {
      const defaultConfig = AppStorage.getDefaultMCPConfiguration();
      await AppStorage.saveMCPConfiguration(defaultConfig);
      Logger.info('AppStorage', 'MCP配置已重置为默认值');
    } catch (e) {
      Logger.error('AppStorage', `Failed to reset MCP configuration: ${e}`);
      throw new Error(`Failed to reset MCP configuration: ${e}`);
    }
  }

  //=================== MCP配置监听器相关方法 ===================

  private static mcpConfigurationListeners: ((config: MCPConfiguration) => void)[] = [];

  /**
   * 添加MCP配置变更监听器
   */
  static addMCPConfigurationListener(listener: (config: MCPConfiguration) => void): void {
    AppStorage.mcpConfigurationListeners.push(listener);
    Logger.debug('AppStorage', `添加MCP配置监听器，当前监听器数量: ${AppStorage.mcpConfigurationListeners.length}`);
  }

  /**
   * 移除MCP配置变更监听器
   */
  static removeMCPConfigurationListener(listener: (config: MCPConfiguration) => void): void {
    const index = AppStorage.mcpConfigurationListeners.indexOf(listener);
    if (index > -1) {
      AppStorage.mcpConfigurationListeners.splice(index, 1);
      Logger.debug('AppStorage', `移除MCP配置监听器，当前监听器数量: ${AppStorage.mcpConfigurationListeners.length}`);
    }
  }

  /**
   * 通知所有MCP配置监听器
   */
  private static notifyMCPConfigurationListeners(config: MCPConfiguration): void {
    Logger.debug('AppStorage', `通知 ${AppStorage.mcpConfigurationListeners.length} 个MCP配置监听器`);
    AppStorage.mcpConfigurationListeners.forEach(listener => {
      try {
        listener(config);
      } catch (e) {
        Logger.error('AppStorage', `MCP配置监听器执行失败: ${e}`);
      }
    });
  }

  //=================== MCP工具配置管理方法 ===================

  /**
   * 获取默认MCP工具配置
   */
  static getDefaultMCPToolsConfig(): MCPToolsConfig {
    return {
      enabledTools: {
        'calculator': true,      // 计算器默认启用
        'app_launcher': true,    // 应用启动器默认启用
        'weather_service': true  // 天气服务默认启用
      },
      globalEnabled: true,
      lastModified: Date.now(),
      toolUsageStats: {}
    };
  }

  /**
   * 获取MCP工具配置
   */
  static async getMCPToolsConfig(): Promise<MCPToolsConfig> {
    try {
      const storage = AppStorage.getStorage();
      const configStr = await storage.get(MCP_TOOLS_CONFIG_KEY, '');

      if (configStr && typeof configStr === 'string') {
        const config = JSON.parse(configStr) as MCPToolsConfig;
        Logger.debug('AppStorage', `MCP工具配置加载成功: ${Object.keys(config.enabledTools).length} 个工具`);
        return config;
      } else {
        Logger.info('AppStorage', '未找到MCP工具配置，使用默认配置');
        const defaultConfig = AppStorage.getDefaultMCPToolsConfig();
        await AppStorage.saveMCPToolsConfig(defaultConfig);
        return defaultConfig;
      }
    } catch (e) {
      Logger.error('AppStorage', `Failed to get MCP tools config: ${e}`);
      return AppStorage.getDefaultMCPToolsConfig();
    }
  }

  /**
   * 保存MCP工具配置
   */
  static async saveMCPToolsConfig(config: MCPToolsConfig): Promise<void> {
    try {
      const validatedConfig = AppStorage.validateMCPToolsConfig(config);

      const storage = AppStorage.getStorage();
      await storage.put(MCP_TOOLS_CONFIG_KEY, JSON.stringify(validatedConfig));
      await storage.flush();

      Logger.info('AppStorage', `MCP工具配置已保存: 全局=${validatedConfig.globalEnabled}, 启用工具=${Object.keys(validatedConfig.enabledTools).filter(tool => validatedConfig.enabledTools[tool]).length}`);

      // 通知监听器
      AppStorage.notifyMCPToolsConfigListeners(validatedConfig);
    } catch (e) {
      Logger.error('AppStorage', `Failed to save MCP tools config: ${e}`);
      throw new Error(`Failed to save MCP tools config: ${e}`);
    }
  }

  /**
   * 更新MCP工具配置（部分更新）
   */
  static async updateMCPToolsConfig(updates: Partial<MCPToolsConfig>): Promise<MCPToolsConfig> {
    try {
      const currentConfig = await AppStorage.getMCPToolsConfig();
      const newConfig: MCPToolsConfig = {
        enabledTools: updates.enabledTools !== undefined ? updates.enabledTools : currentConfig.enabledTools,
        globalEnabled: updates.globalEnabled !== undefined ? updates.globalEnabled : currentConfig.globalEnabled,
        lastModified: Date.now(),
        toolUsageStats: updates.toolUsageStats !== undefined ? updates.toolUsageStats : currentConfig.toolUsageStats
      };

      await AppStorage.saveMCPToolsConfig(newConfig);
      return newConfig;
    } catch (e) {
      Logger.error('AppStorage', `Failed to update MCP tools config: ${e}`);
      throw new Error(`Failed to update MCP tools config: ${e}`);
    }
  }

  /**
   * 设置工具启用状态
   */
  static async setToolEnabled(toolName: string, enabled: boolean): Promise<void> {
    try {
      const config = await AppStorage.getMCPToolsConfig();
      config.enabledTools[toolName] = enabled;
      config.lastModified = Date.now();

      await AppStorage.saveMCPToolsConfig(config);
      Logger.info('AppStorage', `工具 ${toolName} 已${enabled ? '启用' : '禁用'}`);
    } catch (e) {
      Logger.error('AppStorage', `Failed to set tool enabled: ${e}`);
      throw new Error(`Failed to set tool enabled: ${e}`);
    }
  }

  /**
   * 检查工具是否启用
   */
  static async isToolEnabled(toolName: string): Promise<boolean> {
    try {
      const config = await AppStorage.getMCPToolsConfig();
      const enabled = config.globalEnabled && (config.enabledTools[toolName] ?? true);
      Logger.debug('AppStorage', `工具 ${toolName} 启用状态: ${enabled}`);
      return enabled;
    } catch (e) {
      Logger.error('AppStorage', `Failed to check tool enabled: ${e}`);
      return true; // 默认启用
    }
  }

  /**
   * 批量设置工具启用状态
   */
  static async setMultipleToolsEnabled(toolStates: Record<string, boolean>): Promise<void> {
    try {
      const config = await AppStorage.getMCPToolsConfig();

      const entries = Object.entries(toolStates);
      for (let i = 0; i < entries.length; i++) {
        const entry = entries[i];
        config.enabledTools[entry[0]] = entry[1];
      }

      config.lastModified = Date.now();
      await AppStorage.saveMCPToolsConfig(config);

      Logger.info('AppStorage', `批量更新工具状态: ${Object.keys(toolStates).length} 个工具`);
    } catch (e) {
      Logger.error('AppStorage', `Failed to set multiple tools enabled: ${e}`);
      throw new Error(`Failed to set multiple tools enabled: ${e}`);
    }
  }

  /**
   * 全部启用工具
   */
  static async enableAllTools(): Promise<void> {
    try {
      const config = await AppStorage.getMCPToolsConfig();

      for (const toolName of Object.keys(config.enabledTools)) {
        config.enabledTools[toolName] = true;
      }

      config.lastModified = Date.now();
      await AppStorage.saveMCPToolsConfig(config);

      Logger.info('AppStorage', '所有工具已启用');
    } catch (e) {
      Logger.error('AppStorage', `Failed to enable all tools: ${e}`);
      throw new Error(`Failed to enable all tools: ${e}`);
    }
  }

  /**
   * 全部禁用工具
   */
  static async disableAllTools(): Promise<void> {
    try {
      const config = await AppStorage.getMCPToolsConfig();

      for (const toolName of Object.keys(config.enabledTools)) {
        config.enabledTools[toolName] = false;
      }

      config.lastModified = Date.now();
      await AppStorage.saveMCPToolsConfig(config);

      Logger.info('AppStorage', '所有工具已禁用');
    } catch (e) {
      Logger.error('AppStorage', `Failed to disable all tools: ${e}`);
      throw new Error(`Failed to disable all tools: ${e}`);
    }
  }

  /**
   * 增加工具使用统计
   */
  static async incrementToolUsage(toolName: string): Promise<void> {
    try {
      const config = await AppStorage.getMCPToolsConfig();
      config.toolUsageStats[toolName] = (config.toolUsageStats[toolName] || 0) + 1;
      config.lastModified = Date.now();

      await AppStorage.saveMCPToolsConfig(config);
      Logger.debug('AppStorage', `工具 ${toolName} 使用次数: ${config.toolUsageStats[toolName]}`);
    } catch (e) {
      Logger.error('AppStorage', `Failed to increment tool usage: ${e}`);
    }
  }

  /**
   * 获取工具使用统计
   */
  static async getToolUsageStats(): Promise<Record<string, number>> {
    try {
      const config = await AppStorage.getMCPToolsConfig();
      return config.toolUsageStats;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get tool usage stats: ${e}`);
      return {};
    }
  }

  /**
   * 重置工具使用统计
   */
  static async resetToolUsageStats(): Promise<void> {
    try {
      const config = await AppStorage.getMCPToolsConfig();
      config.toolUsageStats = {};
      config.lastModified = Date.now();

      await AppStorage.saveMCPToolsConfig(config);
      Logger.info('AppStorage', '工具使用统计已重置');
    } catch (e) {
      Logger.error('AppStorage', `Failed to reset tool usage stats: ${e}`);
      throw new Error(`Failed to reset tool usage stats: ${e}`);
    }
  }

  /**
   * 验证MCP工具配置的有效性
   */
  private static validateMCPToolsConfig(config: MCPToolsConfig): MCPToolsConfig {
    const validatedEnabledTools: Record<string, boolean> = {};

    // 验证启用工具配置
    if (config.enabledTools && typeof config.enabledTools === 'object') {
      const toolEntries = Object.entries(config.enabledTools);
      for (let i = 0; i < toolEntries.length; i++) {
        const entry = toolEntries[i];
        const toolName = entry[0];
        const enabled = entry[1];
        if (typeof toolName === 'string' && typeof enabled === 'boolean') {
          validatedEnabledTools[toolName] = enabled;
        }
      }
    }

    // 验证使用统计
    const validatedUsageStats: Record<string, number> = {};
    if (config.toolUsageStats && typeof config.toolUsageStats === 'object') {
      const statsEntries = Object.entries(config.toolUsageStats);
      for (let i = 0; i < statsEntries.length; i++) {
        const entry = statsEntries[i];
        const toolName = entry[0];
        const count = entry[1];
        if (typeof toolName === 'string' && typeof count === 'number' && count >= 0) {
          validatedUsageStats[toolName] = Math.floor(count);
        }
      }
    }

    return {
      enabledTools: validatedEnabledTools,
      globalEnabled: typeof config.globalEnabled === 'boolean' ? config.globalEnabled : true,
      lastModified: typeof config.lastModified === 'number' ? config.lastModified : Date.now(),
      toolUsageStats: validatedUsageStats
    };
  }

  /**
   * 重置MCP工具配置为默认值
   */
  static async resetMCPToolsConfig(): Promise<void> {
    try {
      const defaultConfig = AppStorage.getDefaultMCPToolsConfig();
      await AppStorage.saveMCPToolsConfig(defaultConfig);
      Logger.info('AppStorage', 'MCP工具配置已重置为默认值');
    } catch (e) {
      Logger.error('AppStorage', `Failed to reset MCP tools config: ${e}`);
      throw new Error(`Failed to reset MCP tools config: ${e}`);
    }
  }

  //=================== 已应用角色管理相关方法 ===================

  /**
   * 获取已应用到侧边栏的角色ID列表
   */
  static async getAppliedRoleIds(): Promise<string[]> {
    try {
      Logger.debug('AppStorage', '获取已应用角色ID列表');
      const storage = AppStorage.getStorage();
      const appliedRolesStr = await storage.get(APPLIED_ROLES_KEY, '') as string;

      if (!appliedRolesStr) {
        Logger.debug('AppStorage', '没有找到已应用角色列表，返回空数组');
        return [];
      }

      const roleIds = JSON.parse(appliedRolesStr) as string[];
      Logger.debug('AppStorage', `找到 ${roleIds.length} 个已应用角色`);
      return roleIds;
    } catch (e) {
      Logger.error('AppStorage', `Failed to get applied role ids: ${e}`);
      return [];
    }
  }

  /**
   * 保存已应用到侧边栏的角色ID列表
   */
  static async saveAppliedRoleIds(roleIds: string[]): Promise<void> {
    try {
      Logger.info('AppStorage', `保存 ${roleIds.length} 个已应用角色ID`);
      const storage = AppStorage.getStorage();
      await storage.put(APPLIED_ROLES_KEY, JSON.stringify(roleIds));
      await storage.flush();
      Logger.info('AppStorage', '已应用角色ID列表保存成功');
    } catch (e) {
      Logger.error('AppStorage', `Failed to save applied role ids: ${e}`);
      throw new Error(`Failed to save applied role ids: ${e}`);
    }
  }

  /**
   * 添加角色到已应用列表
   */
  static async addAppliedRole(roleId: string): Promise<void> {
    try {
      Logger.info('AppStorage', `添加角色到已应用列表: ${roleId}`);
      const currentRoleIds = await AppStorage.getAppliedRoleIds();

      // 去重检查
      if (!currentRoleIds.includes(roleId)) {
        currentRoleIds.push(roleId);
        await AppStorage.saveAppliedRoleIds(currentRoleIds);
        Logger.info('AppStorage', `角色 ${roleId} 已添加到已应用列表`);
      } else {
        Logger.debug('AppStorage', `角色 ${roleId} 已存在于已应用列表中`);
      }
    } catch (e) {
      Logger.error('AppStorage', `Failed to add applied role: ${e}`);
      throw new Error(`Failed to add applied role: ${e}`);
    }
  }

  /**
   * 从已应用列表中移除角色
   */
  static async removeAppliedRole(roleId: string): Promise<void> {
    try {
      Logger.info('AppStorage', `从已应用列表中移除角色: ${roleId}`);
      const currentRoleIds = await AppStorage.getAppliedRoleIds();
      const updatedRoleIds = currentRoleIds.filter(id => id !== roleId);

      if (updatedRoleIds.length !== currentRoleIds.length) {
        await AppStorage.saveAppliedRoleIds(updatedRoleIds);
        Logger.info('AppStorage', `角色 ${roleId} 已从已应用列表中移除`);
      } else {
        Logger.debug('AppStorage', `角色 ${roleId} 不在已应用列表中`);
      }
    } catch (e) {
      Logger.error('AppStorage', `Failed to remove applied role: ${e}`);
      throw new Error(`Failed to remove applied role: ${e}`);
    }
  }

  /**
   * 检查角色是否已被应用到侧边栏
   */
  static async isRoleApplied(roleId: string): Promise<boolean> {
    try {
      Logger.debug('AppStorage', `检查角色是否已应用: ${roleId}`);
      const appliedRoleIds = await AppStorage.getAppliedRoleIds();
      const isApplied = appliedRoleIds.includes(roleId);
      Logger.debug('AppStorage', `角色 ${roleId} 应用状态: ${isApplied}`);
      return isApplied;
    } catch (e) {
      Logger.error('AppStorage', `Failed to check if role is applied: ${e}`);
      return false;
    }
  }

  /**
   * 清空已应用角色列表
   */
  static async clearAppliedRoles(): Promise<void> {
    try {
      Logger.info('AppStorage', '清空已应用角色列表');
      await AppStorage.saveAppliedRoleIds([]);
      Logger.info('AppStorage', '已应用角色列表已清空');
    } catch (e) {
      Logger.error('AppStorage', `Failed to clear applied roles: ${e}`);
      throw new Error(`Failed to clear applied roles: ${e}`);
    }
  }

  //=================== MCP工具配置监听器相关方法 ===================

  private static mcpToolsConfigListeners: ((config: MCPToolsConfig) => void)[] = [];

  /**
   * 添加MCP工具配置变更监听器
   */
  static addMCPToolsConfigListener(listener: (config: MCPToolsConfig) => void): void {
    AppStorage.mcpToolsConfigListeners.push(listener);
    Logger.debug('AppStorage', `添加MCP工具配置监听器，当前监听器数量: ${AppStorage.mcpToolsConfigListeners.length}`);
  }

  /**
   * 移除MCP工具配置变更监听器
   */
  static removeMCPToolsConfigListener(listener: (config: MCPToolsConfig) => void): void {
    const index = AppStorage.mcpToolsConfigListeners.indexOf(listener);
    if (index > -1) {
      AppStorage.mcpToolsConfigListeners.splice(index, 1);
      Logger.debug('AppStorage', `移除MCP工具配置监听器，当前监听器数量: ${AppStorage.mcpToolsConfigListeners.length}`);
    }
  }

  /**
   * 通知所有MCP工具配置监听器
   */
  private static notifyMCPToolsConfigListeners(config: MCPToolsConfig): void {
    Logger.debug('AppStorage', `通知 ${AppStorage.mcpToolsConfigListeners.length} 个MCP工具配置监听器`);
    AppStorage.mcpToolsConfigListeners.forEach(listener => {
      try {
        listener(config);
      } catch (e) {
        Logger.error('AppStorage', `MCP工具配置监听器执行失败: ${e}`);
      }
    });
  }
}
