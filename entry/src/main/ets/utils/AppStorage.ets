import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Message, SystemPrompt, SystemPromptData, Session, SessionData } from '../models/ChatModels';
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

  private static getStorage(): preferences.Preferences {
    if (!AppStorage.storage) {
      try {
        const context = getContext() as common.UIAbilityContext;
        Logger.debug('AppStorage', `正在初始化存储，Context: ${!!context}`);
        AppStorage.storage = preferences.getPreferencesSync(context, { name: 'chat_storage' });
        Logger.debug('AppStorage', '存储初始化成功');
      } catch (e) {
        Logger.error('AppStorage', `Failed to initialize storage: ${e}`);
        throw Error('Storage initialization failed');
      }
    }
    return AppStorage.storage;
  }

  static getPreferences(): preferences.Preferences {
    return AppStorage.getStorage();
  }

  static async saveMessages(messages: Message[]): Promise<void> {
    try {
      Logger.info('AppStorage', `正在保存 ${messages.length} 条消息`);
      const storage = AppStorage.getStorage();
      const jsonStr = JSON.stringify(messages);
      console.info(`消息JSON长度: ${jsonStr.length}`);
      await storage.put(MESSAGES_KEY, jsonStr);
      await storage.flush();
      console.info('消息保存成功');
    } catch (e) {
      console.error('Failed to save messages.', e);
    }
  }

  static async getMessages(): Promise<Message[]> {
    try {
      console.info('正在读取历史消息');
      const storage = AppStorage.getStorage();
      const messagesStr = await storage.get(MESSAGES_KEY, '[]');
      console.info(`读取到的JSON长度: ${(messagesStr as string).length}`);
      const messages: Message[] = JSON.parse(messagesStr as string);
      console.info(`解析后消息数量: ${messages.length}`);
      console.info('第一条消息样例:', messages.length > 0 ? JSON.stringify(messages[0]) : 'N/A');
      return messages;
    } catch (e) {
      console.error('Failed to get messages.', e);
      return [];
    }
  }

  static async clearMessages(): Promise<void> {
    try {
      const storage = AppStorage.getStorage();
      await storage.delete(MESSAGES_KEY);
      await storage.flush();
    } catch (e) {
      console.error('Failed to clear messages.', e);
    }
  }

  // System prompt management methods
  static async saveSystemPrompts(prompts: SystemPrompt[]): Promise<void> {
    try {
      console.info('=== 开始保存系统提示词 ===');
      console.info('当前时间:', new Date().toISOString());
      console.info(`正在保存 ${prompts.length} 条系统提示词`);
      
      // 详细打印每条提示词
      prompts.forEach((prompt, index) => {
        console.info(`保存提示词[${index}]:`);
        console.info(`  ID: ${prompt.id}`);
        console.info(`  名称: ${prompt.name}`);
        console.info(`  内容: ${prompt.content.substring(0, 50)}...`);
        console.info(`  时间戳: ${prompt.timestamp}`);
      });
      
      // 转换为可序列化对象
      const serializablePrompts: SystemPromptData[] = prompts.map(prompt => prompt.toObject());
      
      const storage = AppStorage.getStorage();
      const jsonStr = JSON.stringify(serializablePrompts);
      console.info(`系统提示词JSON长度: ${jsonStr.length}`);
      console.info(`保存的JSON内容: ${jsonStr}`);
      
      await storage.put(SYSTEM_PROMPTS_KEY, jsonStr);
      await storage.flush();
      
      console.info('✅ 系统提示词保存成功');
      console.info('=== 系统提示词保存完成 ===');
    } catch (e) {
      console.error('❌ Failed to save system prompts.', e);
      console.error('错误堆栈:', (e as Error).stack);
    }
  }

  static async getSystemPrompts(): Promise<SystemPrompt[]> {
    try {
      console.info('=== 开始读取系统提示词 ===');
      console.info('当前时间:', new Date().toISOString());
      
      const storage = AppStorage.getStorage();
      const promptsStr = await storage.get(SYSTEM_PROMPTS_KEY, '[]');
      console.info(`读取到的原始字符串: ${promptsStr}`);
      console.info(`读取到的字符串长度: ${(promptsStr as string).length}`);
      
      if (!promptsStr || promptsStr === '[]') {
        console.info('⚠️ 没有找到系统提示词，返回空数组');
        console.info('=== 系统提示词读取完成 ===');
        return [];
      }
      
      const parsedObjects: SystemPromptData[] = JSON.parse(promptsStr as string);
      const prompts: SystemPrompt[] = parsedObjects.map((obj: SystemPromptData) => SystemPrompt.fromObject(obj));
      console.info(`解析后系统提示词数量: ${prompts.length}`);
      
      // 详细打印每条提示词
      prompts.forEach((prompt, index) => {
        console.info(`读取提示词[${index}]:`);
        console.info(`  ID: ${prompt.id}`);
        console.info(`  名称: ${prompt.name}`);
        console.info(`  内容: ${prompt.content.substring(0, 50)}...`);
        console.info(`  时间戳: ${prompt.timestamp}`);
      });
      
      console.info('✅ 系统提示词读取成功');
      console.info('=== 系统提示词读取完成 ===');
      
      return prompts;
    } catch (e) {
      console.error('❌ Failed to get system prompts.', e);
      console.error('错误详情:', (e as Error).stack);
      console.info('=== 系统提示词读取失败 ===');
      return [];
    }
  }

  static async addSystemPrompt(prompt: SystemPrompt): Promise<void> {
    try {
      const prompts = await AppStorage.getSystemPrompts();
      prompts.push(prompt);
      await AppStorage.saveSystemPrompts(prompts);
    } catch (e) {
      console.error('Failed to add system prompt.', e);
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
      console.error('Failed to delete system prompt.', e);
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
      const storage = AppStorage.getStorage();
      const jsonStr = JSON.stringify(settings.toObject());
      await storage.put(AVATAR_SETTINGS_KEY, jsonStr);
      await storage.flush();
      Logger.info('AppStorage', '头像设置保存成功');
      
      // 通知所有监听器
      AppStorage.notifyAvatarListeners(settings.clone());
    } catch (e) {
      Logger.error('AppStorage', `Failed to save avatar settings: ${e}`);
    }
  }

  /**
   * 获取头像设置
   */
  static async getAvatarSettings(): Promise<AvatarSettings> {
    try {
      Logger.info('AppStorage', '正在读取头像设置');
      const storage = AppStorage.getStorage();
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
      const storage = AppStorage.getStorage();
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
      
      const messages: Message[] = JSON.parse(messagesStr as string);
      Logger.debug('AppStorage', `会话 ${sessionId} 有 ${messages.length} 条消息`);
      return messages;
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
      const jsonStr = JSON.stringify(messages.filter(msg => !msg.isLoading));
      
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
}
