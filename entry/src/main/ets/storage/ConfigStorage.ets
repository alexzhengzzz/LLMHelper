import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Logger } from '../utils/Logger';

// 配置存储键定义
const API_MODE_KEY = 'api_mode';
const SELECTED_SYSTEM_PROMPT_KEY = 'selected_system_prompt_id';
const MESSAGE_LAYOUT_KEY = 'message_layout_preference';
const API_KEYS_KEY = 'api_keys_config';
const CURRENT_MODEL_KEY = 'current_model_config';
const NOTIFICATION_SETTINGS_KEY = 'notification_settings';

/**
 * 配置存储管理器
 * 负责应用配置的存储和读取
 */
export class ConfigStorage {
  private static storage: preferences.Preferences | null = null;

  private static getStorage(): preferences.Preferences {
    if (!ConfigStorage.storage) {
      try {
        const context = getContext() as common.UIAbilityContext;
        Logger.debug('ConfigStorage', `正在初始化配置存储，Context: ${!!context}`);
        ConfigStorage.storage = preferences.getPreferencesSync(context, { name: 'config_storage' });
        Logger.debug('ConfigStorage', '配置存储初始化成功');
      } catch (e) {
        Logger.error('ConfigStorage', `Failed to initialize config storage: ${e}`);
        throw Error('Config storage initialization failed');
      }
    }
    return ConfigStorage.storage;
  }

  /**
   * 保存API调用模式
   */
  static async saveAPIMode(mode: string): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      await storage.put(API_MODE_KEY, mode);
      await storage.flush();
      Logger.debug('ConfigStorage', `API模式保存成功: ${mode}`);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to save API mode: ${e}`);
      throw e;
    }
  }

  /**
   * 获取API调用模式
   */
  static async getAPIMode(): Promise<string> {
    try {
      const storage = ConfigStorage.getStorage();
      return await storage.get(API_MODE_KEY, 'direct_call') as string;
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to get API mode: ${e}`);
      return 'direct_call';
    }
  }

  /**
   * 保存选中的系统提示词ID
   */
  static async saveSelectedSystemPromptId(promptId: string): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      await storage.put(SELECTED_SYSTEM_PROMPT_KEY, promptId);
      await storage.flush();
      Logger.debug('ConfigStorage', `选中系统提示词ID保存成功: ${promptId}`);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to save selected system prompt ID: ${e}`);
      throw e;
    }
  }

  /**
   * 获取选中的系统提示词ID
   */
  static async getSelectedSystemPromptId(): Promise<string> {
    try {
      const storage = ConfigStorage.getStorage();
      return await storage.get(SELECTED_SYSTEM_PROMPT_KEY, '') as string;
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to get selected system prompt ID: ${e}`);
      return '';
    }
  }

  /**
   * 保存消息布局偏好
   */
  static async saveMessageLayoutPreference(useModern: boolean): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      await storage.put(MESSAGE_LAYOUT_KEY, useModern);
      await storage.flush();
      Logger.debug('ConfigStorage', `消息布局偏好保存成功: ${useModern}`);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to save message layout preference: ${e}`);
      throw e;
    }
  }

  /**
   * 获取消息布局偏好
   */
  static async getMessageLayoutPreference(): Promise<boolean> {
    try {
      const storage = ConfigStorage.getStorage();
      return await storage.get(MESSAGE_LAYOUT_KEY, false) as boolean;
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to get message layout preference: ${e}`);
      return false;
    }
  }

  /**
   * 保存API密钥配置
   */
  static async saveAPIKeysConfig(config: Record<string, string>): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      const jsonStr = JSON.stringify(config);
      await storage.put(API_KEYS_KEY, jsonStr);
      await storage.flush();
      Logger.debug('ConfigStorage', 'API密钥配置保存成功');
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to save API keys config: ${e}`);
      throw e;
    }
  }

  /**
   * 获取API密钥配置
   */
  static async getAPIKeysConfig(): Promise<Record<string, string>> {
    try {
      const storage = ConfigStorage.getStorage();
      const configStr = await storage.get(API_KEYS_KEY, '{}') as string;
      return JSON.parse(configStr);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to get API keys config: ${e}`);
      return {};
    }
  }

  /**
   * 保存当前模型配置
   */
  static async saveCurrentModelConfig(config: { provider: string; model: string }): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      const configWithTimestamp = {
        ...config,
        savedAt: Date.now()
      };
      const jsonStr = JSON.stringify(configWithTimestamp);
      await storage.put(CURRENT_MODEL_KEY, jsonStr);
      await storage.flush();
      Logger.debug('ConfigStorage', `当前模型配置保存成功: ${config.provider}/${config.model}`);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to save current model config: ${e}`);
      throw e;
    }
  }

  /**
   * 获取当前模型配置
   */
  static async getCurrentModelConfig(): Promise<{ provider: string; model: string; savedAt: number } | null> {
    try {
      const storage = ConfigStorage.getStorage();
      const configStr = await storage.get(CURRENT_MODEL_KEY, null) as string;
      if (!configStr) {
        return null;
      }
      return JSON.parse(configStr);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to get current model config: ${e}`);
      return null;
    }
  }

  /**
   * 清除当前模型配置
   */
  static async clearCurrentModel(): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      await storage.delete(CURRENT_MODEL_KEY);
      await storage.flush();
      Logger.debug('ConfigStorage', '当前模型配置清除成功');
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to clear current model: ${e}`);
      throw e;
    }
  }

  /**
   * 保存通知设置
   */
  static async saveNotificationSetting(enabled: boolean): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      await storage.put(NOTIFICATION_SETTINGS_KEY, enabled);
      await storage.flush();
      Logger.debug('ConfigStorage', `通知设置保存成功: ${enabled}`);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to save notification setting: ${e}`);
      throw e;
    }
  }

  /**
   * 获取通知设置
   */
  static async getNotificationSetting(): Promise<boolean> {
    try {
      const storage = ConfigStorage.getStorage();
      return await storage.get(NOTIFICATION_SETTINGS_KEY, true) as boolean;
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to get notification setting: ${e}`);
      return true;
    }
  }

  /**
   * 保存通用配置项
   */
  static async saveConfigItem(key: string, value: any): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      if (typeof value === 'object') {
        value = JSON.stringify(value);
      }
      await storage.put(key, value);
      await storage.flush();
      Logger.debug('ConfigStorage', `配置项保存成功: ${key}`);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to save config item: ${e}`);
      throw e;
    }
  }

  /**
   * 获取通用配置项
   */
  static async getConfigItem(key: string, defaultValue: any = null): Promise<any> {
    try {
      const storage = ConfigStorage.getStorage();
      const value = await storage.get(key, defaultValue);

      // 尝试解析JSON
      if (typeof value === 'string' && value.startsWith('{')) {
        try {
          return JSON.parse(value);
        } catch {
          return value;
        }
      }
      return value;
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to get config item: ${e}`);
      return defaultValue;
    }
  }

  /**
   * 删除配置项
   */
  static async deleteConfigItem(key: string): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      await storage.delete(key);
      await storage.flush();
      Logger.debug('ConfigStorage', `配置项删除成功: ${key}`);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to delete config item: ${e}`);
      throw e;
    }
  }

  /**
   * 检查配置项是否存在
   */
  static async hasConfigItem(key: string): Promise<boolean> {
    try {
      const storage = ConfigStorage.getStorage();
      const value = await storage.get(key, null);
      return value !== null;
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to check config item: ${e}`);
      return false;
    }
  }

  /**
   * 批量保存配置项
   */
  static async saveMultipleConfigItems(items: Record<string, any>): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      for (const [key, value] of Object.entries(items)) {
        if (typeof value === 'object') {
          await storage.put(key, JSON.stringify(value));
        } else {
          await storage.put(key, value);
        }
      }
      await storage.flush();
      Logger.debug('ConfigStorage', `批量配置项保存成功: ${Object.keys(items).length} 项`);
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to save multiple config items: ${e}`);
      throw e;
    }
  }

  /**
   * 批量获取配置项
   */
  static async getMultipleConfigItems(keys: string[]): Promise<Record<string, any>> {
    try {
      const storage = ConfigStorage.getStorage();
      const result: Record<string, any> = {};

      for (const key of keys) {
        const value = await storage.get(key, null);
        if (value !== null) {
          if (typeof value === 'string' && value.startsWith('{')) {
            try {
              result[key] = JSON.parse(value);
            } catch {
              result[key] = value;
            }
          } else {
            result[key] = value;
          }
        }
      }

      return result;
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to get multiple config items: ${e}`);
      return {};
    }
  }

  /**
   * 清除所有配置
   */
  static async clearAllConfigs(): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      await storage.clear();
      await storage.flush();
      Logger.info('ConfigStorage', '所有配置清除成功');
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to clear all configs: ${e}`);
      throw e;
    }
  }

  /**
   * 备份配置数据
   */
  static async backupConfigs(): Promise<string> {
    try {
      const storage = ConfigStorage.getStorage();
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
      Logger.error('ConfigStorage', `Failed to backup configs: ${e}`);
      throw e;
    }
  }

  /**
   * 恢复配置数据
   */
  static async restoreConfigs(backupData: string): Promise<void> {
    try {
      const storage = ConfigStorage.getStorage();
      const configData = JSON.parse(backupData);

      for (const [key, value] of Object.entries(configData)) {
        await storage.put(key, value);
      }

      await storage.flush();
      Logger.info('ConfigStorage', '配置数据恢复成功');
    } catch (e) {
      Logger.error('ConfigStorage', `Failed to restore configs: ${e}`);
      throw e;
    }
  }
}