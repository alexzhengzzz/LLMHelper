import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { SystemPrompt, SystemPromptData } from '../models/ChatModels';
import { DefaultPrompts } from '../data/DefaultPrompts';
import { Logger } from '../utils/Logger';

const SYSTEM_PROMPTS_KEY = 'system_prompts';

/**
 * 系统提示词存储管理器
 * 负责系统提示词的存储、读取、管理
 */
export class SystemPromptStorage {
  private static storage: preferences.Preferences | null = null;

  private static getStorage(): preferences.Preferences {
    if (!SystemPromptStorage.storage) {
      try {
        const context = getContext() as common.UIAbilityContext;
        Logger.debug('SystemPromptStorage', `正在初始化系统提示词存储，Context: ${!!context}`);
        SystemPromptStorage.storage = preferences.getPreferencesSync(context, { name: 'system_prompt_storage' });
        Logger.debug('SystemPromptStorage', '系统提示词存储初始化成功');
      } catch (e) {
        Logger.error('SystemPromptStorage', `Failed to initialize system prompt storage: ${e}`);
        throw Error('System prompt storage initialization failed');
      }
    }
    return SystemPromptStorage.storage;
  }

  /**
   * 保存系统提示词列表
   */
  static async saveSystemPrompts(prompts: SystemPrompt[]): Promise<void> {
    try {
      Logger.info('SystemPromptStorage', `正在保存 ${prompts.length} 条系统提示词`);

      // 转换为可序列化对象
      const serializablePrompts: SystemPromptData[] = prompts.map(prompt => prompt.toObject());

      const storage = SystemPromptStorage.getStorage();
      const jsonStr = JSON.stringify(serializablePrompts);
      Logger.debug('SystemPromptStorage', `系统提示词JSON长度: ${jsonStr.length}`);

      await storage.put(SYSTEM_PROMPTS_KEY, jsonStr);
      await storage.flush();

      Logger.info('SystemPromptStorage', '系统提示词保存成功');
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to save system prompts: ${e}`);
      throw e;
    }
  }

  /**
   * 读取系统提示词列表
   */
  static async getSystemPrompts(): Promise<SystemPrompt[]> {
    try {
      Logger.debug('SystemPromptStorage', '正在读取系统提示词');

      const storage = SystemPromptStorage.getStorage();
      const promptsStr = await storage.get(SYSTEM_PROMPTS_KEY, '[]');
      Logger.debug('SystemPromptStorage', `读取到的字符串长度: ${(promptsStr as string).length}`);

      if (!promptsStr || promptsStr === '[]') {
        Logger.info('SystemPromptStorage', '没有找到系统提示词，返回空数组');
        return [];
      }

      const parsedObjects: SystemPromptData[] = JSON.parse(promptsStr as string);
      const prompts: SystemPrompt[] = parsedObjects.map((obj: SystemPromptData) => SystemPrompt.fromObject(obj));
      Logger.debug('SystemPromptStorage', `解析后系统提示词数量: ${prompts.length}`);

      return prompts;
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to get system prompts: ${e}`);
      return [];
    }
  }

  /**
   * 添加系统提示词
   */
  static async addSystemPrompt(prompt: SystemPrompt): Promise<void> {
    try {
      const prompts = await SystemPromptStorage.getSystemPrompts();
      prompts.push(prompt);
      await SystemPromptStorage.saveSystemPrompts(prompts);
      Logger.debug('SystemPromptStorage', '系统提示词添加成功');
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to add system prompt: ${e}`);
      throw e;
    }
  }

  /**
   * 更新系统提示词
   */
  static async updateSystemPrompt(prompt: SystemPrompt): Promise<void> {
    try {
      const prompts = await SystemPromptStorage.getSystemPrompts();
      const index = prompts.findIndex(p => p.id === prompt.id);
      if (index !== -1) {
        prompts[index] = prompt;
        await SystemPromptStorage.saveSystemPrompts(prompts);
        Logger.debug('SystemPromptStorage', '系统提示词更新成功');
      } else {
        Logger.warn('SystemPromptStorage', `System prompt not found: ${prompt.id}`);
      }
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to update system prompt: ${e}`);
      throw e;
    }
  }

  /**
   * 删除系统提示词
   */
  static async deleteSystemPrompt(promptId: string): Promise<void> {
    try {
      const prompts = await SystemPromptStorage.getSystemPrompts();
      const filteredPrompts = prompts.filter(p => p.id !== promptId);
      await SystemPromptStorage.saveSystemPrompts(filteredPrompts);
      Logger.debug('SystemPromptStorage', '系统提示词删除成功');
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to delete system prompt: ${e}`);
      throw e;
    }
  }

  /**
   * 清除所有系统提示词
   */
  static async clearSystemPrompts(): Promise<void> {
    try {
      const storage = SystemPromptStorage.getStorage();
      await storage.delete(SYSTEM_PROMPTS_KEY);
      await storage.flush();
      Logger.info('SystemPromptStorage', '系统提示词清除成功');
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to clear system prompts: ${e}`);
      throw e;
    }
  }

  /**
   * 根据ID获取系统提示词
   */
  static async getSystemPromptById(promptId: string): Promise<SystemPrompt | null> {
    try {
      const prompts = await SystemPromptStorage.getSystemPrompts();
      return prompts.find(p => p.id === promptId) || null;
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to get system prompt by ID: ${e}`);
      return null;
    }
  }

  /**
   * 根据名称搜索系统提示词
   */
  static async searchSystemPromptsByName(keyword: string): Promise<SystemPrompt[]> {
    try {
      const prompts = await SystemPromptStorage.getSystemPrompts();
      return prompts.filter(p =>
        p.name.toLowerCase().includes(keyword.toLowerCase()) ||
        p.content.toLowerCase().includes(keyword.toLowerCase())
      );
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to search system prompts: ${e}`);
      return [];
    }
  }

  /**
   * 获取系统提示词数量
   */
  static async getSystemPromptCount(): Promise<number> {
    try {
      const prompts = await SystemPromptStorage.getSystemPrompts();
      return prompts.length;
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to get system prompt count: ${e}`);
      return 0;
    }
  }

  /**
   * 检查是否有系统提示词
   */
  static async hasSystemPrompts(): Promise<boolean> {
    try {
      const count = await SystemPromptStorage.getSystemPromptCount();
      return count > 0;
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to check system prompts: ${e}`);
      return false;
    }
  }

  /**
   * 获取默认系统提示词
   */
  static getDefaultSystemPrompts(): SystemPrompt[] {
    return DefaultPrompts.getAllPrompts();
  }

  /**
   * 初始化默认系统提示词
   */
  static async initializeDefaultPrompts(): Promise<void> {
    try {
      const existingPrompts = await SystemPromptStorage.getSystemPrompts();
      if (existingPrompts.length === 0) {
        const defaultPrompts = SystemPromptStorage.getDefaultSystemPrompts();
        await SystemPromptStorage.saveSystemPrompts(defaultPrompts);
        Logger.info('SystemPromptStorage', '已初始化默认系统提示词');
      }
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to initialize default prompts: ${e}`);
      throw e;
    }
  }

  /**
   * 重置为默认系统提示词
   */
  static async resetToDefaultPrompts(): Promise<void> {
    try {
      const defaultPrompts = SystemPromptStorage.getDefaultSystemPrompts();
      await SystemPromptStorage.saveSystemPrompts(defaultPrompts);
      Logger.info('SystemPromptStorage', '已重置为默认系统提示词');
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to reset to default prompts: ${e}`);
      throw e;
    }
  }

  /**
   * 备份系统提示词数据
   */
  static async backupSystemPrompts(): Promise<string> {
    try {
      const prompts = await SystemPromptStorage.getSystemPrompts();
      const serializablePrompts = prompts.map(p => p.toObject());
      return JSON.stringify(serializablePrompts);
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to backup system prompts: ${e}`);
      throw e;
    }
  }

  /**
   * 恢复系统提示词数据
   */
  static async restoreSystemPrompts(backupData: string): Promise<void> {
    try {
      const parsedObjects: SystemPromptData[] = JSON.parse(backupData);
      const prompts: SystemPrompt[] = parsedObjects.map((obj: SystemPromptData) => SystemPrompt.fromObject(obj));
      await SystemPromptStorage.saveSystemPrompts(prompts);
      Logger.info('SystemPromptStorage', '系统提示词数据恢复成功');
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to restore system prompts: ${e}`);
      throw e;
    }
  }

  /**
   * 批量导入系统提示词
   */
  static async importSystemPrompts(prompts: SystemPrompt[], overwrite: boolean = false): Promise<void> {
    try {
      if (overwrite) {
        await SystemPromptStorage.saveSystemPrompts(prompts);
      } else {
        const existingPrompts = await SystemPromptStorage.getSystemPrompts();
        const mergedPrompts = [...existingPrompts, ...prompts];
        await SystemPromptStorage.saveSystemPrompts(mergedPrompts);
      }
      Logger.info('SystemPromptStorage', `系统提示词导入成功，导入 ${prompts.length} 条`);
    } catch (e) {
      Logger.error('SystemPromptStorage', `Failed to import system prompts: ${e}`);
      throw e;
    }
  }
}