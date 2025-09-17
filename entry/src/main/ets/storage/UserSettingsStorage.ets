import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { UserProfile, AvatarSettings } from '../utils/AppStorage';
import { Logger } from '../utils/Logger';

const USER_PROFILE_KEY = 'user_profile';
const AVATAR_SETTINGS_KEY = 'avatar_settings';
const AUTO_TTS_SETTINGS_KEY = 'auto_tts_settings';

/**
 * 用户设置存储管理器
 * 负责用户个人设置、头像设置、语音设置等的存储
 */
export class UserSettingsStorage {
  private static storage: preferences.Preferences | null = null;
  private static avatarListeners: ((settings: AvatarSettings) => void)[] = [];
  private static userProfileListeners: ((profile: UserProfile) => void)[] = [];

  private static getStorage(): preferences.Preferences {
    if (!UserSettingsStorage.storage) {
      try {
        const context = getContext() as common.UIAbilityContext;
        Logger.debug('UserSettingsStorage', `正在初始化用户设置存储，Context: ${!!context}`);
        UserSettingsStorage.storage = preferences.getPreferencesSync(context, { name: 'user_settings_storage' });
        Logger.debug('UserSettingsStorage', '用户设置存储初始化成功');
      } catch (e) {
        Logger.error('UserSettingsStorage', `Failed to initialize user settings storage: ${e}`);
        throw Error('User settings storage initialization failed');
      }
    }
    return UserSettingsStorage.storage;
  }

  // ==================== 自动语音播报设置管理 ====================

  /**
   * 获取默认语音播报设置
   */
  static getDefaultAutoTTSSettings() {
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
  static async saveAutoTTSSettings(settings: any): Promise<void> {
    try {
      Logger.debug('UserSettingsStorage', `正在保存自动播报设置: ${JSON.stringify(settings)}`);
      const storage = UserSettingsStorage.getStorage();
      const jsonStr = JSON.stringify(settings);
      await storage.put(AUTO_TTS_SETTINGS_KEY, jsonStr);
      await storage.flush();
      Logger.debug('UserSettingsStorage', '自动播报设置保存成功');
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to save auto TTS settings: ${e}`);
      throw e;
    }
  }

  /**
   * 获取自动播报设置
   */
  static async getAutoTTSSettings() {
    try {
      const storage = UserSettingsStorage.getStorage();
      const settingsStr = await storage.get(AUTO_TTS_SETTINGS_KEY, '{}') as string;
      const defaultSettings = UserSettingsStorage.getDefaultAutoTTSSettings();

      if (!settingsStr || settingsStr === '{}') {
        return defaultSettings;
      }

      try {
        const savedSettings = JSON.parse(settingsStr);
        return { ...defaultSettings, ...savedSettings };
      } catch {
        return defaultSettings;
      }
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to get auto TTS settings: ${e}`);
      return UserSettingsStorage.getDefaultAutoTTSSettings();
    }
  }

  /**
   * 更新自动播报设置
   */
  static async updateAutoTTSSettings(updates: any): Promise<void> {
    try {
      const currentSettings = await UserSettingsStorage.getAutoTTSSettings();
      const newSettings = { ...currentSettings, ...updates };
      await UserSettingsStorage.saveAutoTTSSettings(newSettings);
      Logger.debug('UserSettingsStorage', '自动播报设置更新成功');
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to update auto TTS settings: ${e}`);
      throw e;
    }
  }

  // ==================== 头像设置管理 ====================

  /**
   * 保存头像设置
   */
  static async saveAvatarSettings(settings: any): Promise<void> {
    try {
      Logger.debug('UserSettingsStorage', `正在保存头像设置: ${JSON.stringify(settings)}`);
      const storage = UserSettingsStorage.getStorage();
      const jsonStr = JSON.stringify(settings);
      await storage.put(AVATAR_SETTINGS_KEY, jsonStr);
      await storage.flush();

      // 通知监听器
      const avatarSettings = new AvatarSettings(
        settings.userAvatarType || 'default',
        settings.userAvatarValue || '#4285F4',
        settings.aiAvatarType || 'default',
        settings.aiAvatarValue || '#34A853'
      );
      UserSettingsStorage.notifyAvatarListeners(avatarSettings);

      Logger.debug('UserSettingsStorage', '头像设置保存成功');
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to save avatar settings: ${e}`);
      throw e;
    }
  }

  /**
   * 获取头像设置
   */
  static async getAvatarSettings() {
    try {
      const storage = UserSettingsStorage.getStorage();
      const settingsStr = await storage.get(AVATAR_SETTINGS_KEY, '{}') as string;

      if (!settingsStr || settingsStr === '{}') {
        return new AvatarSettings().toObject();
      }

      try {
        return JSON.parse(settingsStr);
      } catch {
        return new AvatarSettings().toObject();
      }
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to get avatar settings: ${e}`);
      return new AvatarSettings().toObject();
    }
  }

  /**
   * 更新头像设置
   */
  static async updateAvatarSettings(settings: any): Promise<void> {
    try {
      const avatarSettings = new AvatarSettings(
        settings.userAvatarType,
        settings.userAvatarValue,
        settings.aiAvatarType,
        settings.aiAvatarValue
      );
      await UserSettingsStorage.saveAvatarSettings(avatarSettings.toObject());
      Logger.debug('UserSettingsStorage', '头像设置更新成功');
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to update avatar settings: ${e}`);
      throw e;
    }
  }

  /**
   * 添加头像设置监听器
   */
  static addAvatarListener(listener: (settings: AvatarSettings) => void): void {
    UserSettingsStorage.avatarListeners.push(listener);
    Logger.debug('UserSettingsStorage', `头像监听器已添加，当前数量: ${UserSettingsStorage.avatarListeners.length}`);
  }

  /**
   * 移除头像设置监听器
   */
  static removeAvatarListener(listener: (settings: AvatarSettings) => void): void {
    const index = UserSettingsStorage.avatarListeners.indexOf(listener);
    if (index !== -1) {
      UserSettingsStorage.avatarListeners.splice(index, 1);
      Logger.debug('UserSettingsStorage', `头像监听器已移除，当前数量: ${UserSettingsStorage.avatarListeners.length}`);
    }
  }

  /**
   * 通知头像设置监听器
   */
  private static notifyAvatarListeners(settings: AvatarSettings): void {
    UserSettingsStorage.avatarListeners.forEach(listener => {
      try {
        listener(settings);
      } catch (e) {
        Logger.error('UserSettingsStorage', `Failed to notify avatar listener: ${e}`);
      }
    });
  }

  // ==================== 用户资料管理 ====================

  /**
   * 保存用户资料
   */
  static async saveUserProfile(profile: any): Promise<void> {
    try {
      Logger.debug('UserSettingsStorage', `正在保存用户资料: ${JSON.stringify(profile)}`);
      const storage = UserSettingsStorage.getStorage();
      const jsonStr = JSON.stringify(profile);
      await storage.put(USER_PROFILE_KEY, jsonStr);
      await storage.flush();

      // 通知监听器
      const userProfile = new UserProfile(
        profile.userName || 'Javis用户',
        profile.userSignature || '让AI成为你的编程伙伴',
        profile.userAvatarType || 'default',
        profile.userAvatarValue || '#4285F4',
        profile.updatedAt || Date.now()
      );
      UserSettingsStorage.notifyUserProfileListeners(userProfile);

      Logger.debug('UserSettingsStorage', '用户资料保存成功');
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to save user profile: ${e}`);
      throw e;
    }
  }

  /**
   * 获取用户资料
   */
  static async getUserProfile() {
    try {
      const storage = UserSettingsStorage.getStorage();
      const profileStr = await storage.get(USER_PROFILE_KEY, '{}') as string;

      if (!profileStr || profileStr === '{}') {
        return new UserProfile().toObject();
      }

      try {
        return JSON.parse(profileStr);
      } catch {
        return new UserProfile().toObject();
      }
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to get user profile: ${e}`);
      return new UserProfile().toObject();
    }
  }

  /**
   * 更新用户资料
   */
  static async updateUserProfile(updates: any): Promise<void> {
    try {
      const currentProfile = await UserSettingsStorage.getUserProfile();
      const newProfile = {
        ...currentProfile,
        ...updates,
        updatedAt: Date.now()
      };
      await UserSettingsStorage.saveUserProfile(newProfile);
      Logger.debug('UserSettingsStorage', '用户资料更新成功');
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to update user profile: ${e}`);
      throw e;
    }
  }

  /**
   * 添加用户资料监听器
   */
  static addUserProfileListener(listener: (profile: UserProfile) => void): void {
    UserSettingsStorage.userProfileListeners.push(listener);
    Logger.debug('UserSettingsStorage', `用户资料监听器已添加，当前数量: ${UserSettingsStorage.userProfileListeners.length}`);
  }

  /**
   * 移除用户资料监听器
   */
  static removeUserProfileListener(listener: (profile: UserProfile) => void): void {
    const index = UserSettingsStorage.userProfileListeners.indexOf(listener);
    if (index !== -1) {
      UserSettingsStorage.userProfileListeners.splice(index, 1);
      Logger.debug('UserSettingsStorage', `用户资料监听器已移除，当前数量: ${UserSettingsStorage.userProfileListeners.length}`);
    }
  }

  /**
   * 通知用户资料监听器
   */
  private static notifyUserProfileListeners(profile: UserProfile): void {
    UserSettingsStorage.userProfileListeners.forEach(listener => {
      try {
        listener(profile);
      } catch (e) {
        Logger.error('UserSettingsStorage', `Failed to notify user profile listener: ${e}`);
      }
    });
  }

  // ==================== 会话消息管理 ====================

  /**
   * 删除指定会话的消息
   */
  static async deleteSessionMessages(sessionId: string): Promise<void> {
    try {
      // 这里需要实现根据会话ID删除消息的逻辑
      // 由于消息存储在另一个管理器中，这里提供一个接口
      Logger.debug('UserSettingsStorage', `删除会话消息: ${sessionId}`);
      // 实际实现需要与MessageStorage协调
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to delete session messages: ${e}`);
      throw e;
    }
  }

  /**
   * 清除所有用户数据
   */
  static async clearAllUserData(): Promise<void> {
    try {
      const storage = UserSettingsStorage.getStorage();
      await storage.clear();
      await storage.flush();
      Logger.info('UserSettingsStorage', '所有用户数据清除成功');
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to clear all user data: ${e}`);
      throw e;
    }
  }

  // ==================== 数据迁移工具 ====================

  /**
   * 从旧版AppStorage迁移数据
   */
  static async migrateFromLegacyStorage(): Promise<void> {
    try {
      Logger.info('UserSettingsStorage', '开始从旧版存储迁移数据');

      // 这里可以实现从旧版AppStorage迁移数据的逻辑
      // 由于原AppStorage使用单个存储文件，需要分别提取不同类型的数据

      Logger.info('UserSettingsStorage', '数据迁移完成');
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to migrate from legacy storage: ${e}`);
      throw e;
    }
  }

  /**
   * 备份用户设置
   */
  static async backupUserSettings(): Promise<string> {
    try {
      const storage = UserSettingsStorage.getStorage();
      const allKeys = await storage.keys();
      const backupData: Record<string, any> = {};

      for (const key of allKeys) {
        const value = await storage.get(key, null);
        if (value !== null) {
          backupData[key] = value;
        }
      }

      return JSON.stringify(backupData);
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to backup user settings: ${e}`);
      throw e;
    }
  }

  /**
   * 恢复用户设置
   */
  static async restoreUserSettings(backupData: string): Promise<void> {
    try {
      const storage = UserSettingsStorage.getStorage();
      const userData = JSON.parse(backupData);

      for (const [key, value] of Object.entries(userData)) {
        await storage.put(key, value);
      }

      await storage.flush();
      Logger.info('UserSettingsStorage', '用户设置恢复成功');
    } catch (e) {
      Logger.error('UserSettingsStorage', `Failed to restore user settings: ${e}`);
      throw e;
    }
  }
}