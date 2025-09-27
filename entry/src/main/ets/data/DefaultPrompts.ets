import { SystemPrompt } from '../models/ChatModels';
import { Logger } from '../utils/Logger';
import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';

/**
 * JSON配置格式接口
 */
interface PromptConfig {
  id: string;
  name: string;
  content: string;
  shortDescription: string;
  category: string;
  icon: string;
  isRole: boolean;
  tags: string[];
}

interface PromptCategory {
  id: string;
  name: string;
  description: string;
  icon: string;
}

interface PromptMetadata {
  totalPrompts: number;
  professionalCount: number;
  characterCount: number;
  formatVersion: string;
  compatibilityLevel: string;
}

interface PromptsCollection {
  professional: PromptConfig[];
  character: PromptConfig[];
}

interface PromptsConfigData {
  version: string;
  lastUpdated: string;
  prompts: PromptsCollection;
  categories: PromptCategory[];
  metadata: PromptMetadata;
}

/**
 * 默认系统提示词数据
 * 支持从JSON文件加载配置，便于管理和修改
 */
export class DefaultPrompts {
  private static cachedPrompts: SystemPrompt[] | null = null;

  /**
   * 获取所有默认系统提示词
   */
  static async getAllPrompts(): Promise<SystemPrompt[]> {
    if (DefaultPrompts.cachedPrompts) {
      return DefaultPrompts.cachedPrompts;
    }

    try {
      const prompts = await DefaultPrompts.loadPromptsFromJSON();
      DefaultPrompts.cachedPrompts = prompts;
      return prompts;
    } catch (error) {
      Logger.error('DefaultPrompts', `从JSON加载失败，使用应急后备提示词: ${error}`);
      // 如果JSON加载失败，使用最小的应急提示词集合
      const fallbackPrompts = DefaultPrompts.getEmergencyFallbackPrompts();
      DefaultPrompts.cachedPrompts = fallbackPrompts;
      return fallbackPrompts;
    }
  }

  /**
   * 同步获取所有默认系统提示词（向后兼容）
   */
  static getAllPromptsSync(): SystemPrompt[] {
    if (DefaultPrompts.cachedPrompts) {
      return DefaultPrompts.cachedPrompts;
    }
    // 如果缓存为空，返回空数组并记录警告
    Logger.warn('DefaultPrompts', '提示词尚未加载，返回空数组。请先调用 getAllPrompts() 进行异步加载。');
    return [];
  }

  /**
   * 从JSON文件加载提示词配置
   */
  private static async loadPromptsFromJSON(): Promise<SystemPrompt[]> {
    try {
      Logger.info('DefaultPrompts', '开始从JSON文件加载提示词配置');

      // 获取资源管理器
      const context = getContext();
      const mgr = context.resourceManager;

      // 读取JSON文件
      const rawFileData = await mgr.getRawFileContent('prompts_config.json');

      // 使用util.TextDecoder正确处理UTF-8编码
      const textDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
      const jsonString = textDecoder.decodeToString(rawFileData);

      Logger.debug('DefaultPrompts', `JSON字符串长度: ${jsonString.length}`);
      Logger.debug('DefaultPrompts', `JSON字符串前100字符: ${jsonString.substring(0, 100)}`);

      let configData: PromptsConfigData;
      try {
        configData = JSON.parse(jsonString) as PromptsConfigData;
      } catch (parseError) {
        const error = parseError as Error;
        Logger.error('DefaultPrompts', `JSON解析失败: ${error}`);
        Logger.error('DefaultPrompts', `错误位置: ${error.message}`);
        // 尝试找出具体的错误位置
        try {
          const errorIndex = error.message.match(/position (\d+)/);
          if (errorIndex) {
            const index = parseInt(errorIndex[1]);
            const context = jsonString.substring(Math.max(0, index - 50), Math.min(jsonString.length, index + 50));
            Logger.error('DefaultPrompts', `错误位置上下文: ...${context}...`);
          }
        } catch (e) {
          const innerError = e as Error;
          Logger.error('DefaultPrompts', `无法获取错误位置信息: ${innerError}`);
        }
        throw new Error(error.message);
      }

      Logger.info('DefaultPrompts', `成功解析JSON配置，版本: ${configData.version}`);
      Logger.info('DefaultPrompts', `总计 ${configData.metadata.totalPrompts} 个提示词`);

      const allPrompts: SystemPrompt[] = [];

      // 转换专业类提示词
      for (const promptConfig of configData.prompts.professional) {
        const prompt = new SystemPrompt(
          promptConfig.name,
          promptConfig.content,
          '', // keywords 字段
          promptConfig.isRole,
          promptConfig.category,
          promptConfig.icon,
          promptConfig.shortDescription,
          true // isDefault
        );
        allPrompts.push(prompt);
      }

      // 转换人物角色提示词
      for (const promptConfig of configData.prompts.character) {
        const prompt = new SystemPrompt(
          promptConfig.name,
          promptConfig.content,
          '', // keywords 字段
          promptConfig.isRole,
          promptConfig.category,
          promptConfig.icon,
          promptConfig.shortDescription,
          true // isDefault
        );
        allPrompts.push(prompt);
      }

      Logger.info('DefaultPrompts', `成功从JSON加载 ${allPrompts.length} 个提示词`);
      return allPrompts;

    } catch (error) {
      Logger.error('DefaultPrompts', `从JSON加载提示词失败: ${error}`);
      throw new Error(String(error));
    }
  }

  /**
   * 清除缓存，强制重新加载
   */
  static clearCache(): void {
    DefaultPrompts.cachedPrompts = null;
    Logger.info('DefaultPrompts', '已清除提示词缓存');
  }

  /**
   * 重新加载提示词配置
   */
  static async reloadPrompts(): Promise<SystemPrompt[]> {
    DefaultPrompts.clearCache();
    return await DefaultPrompts.getAllPrompts();
  }

  /**
   * 应急后备提示词（仅在JSON加载完全失败时使用）
   */
  private static getEmergencyFallbackPrompts(): SystemPrompt[] {
    Logger.warn('DefaultPrompts', '使用应急后备提示词，功能受限');
    return [
      new SystemPrompt(
        'Javis 基础助手',
        '你是Javis，一个友好的AI助手。我可以帮助你回答问题、解决问题和进行对话。虽然当前功能受限，但我会尽力为你提供帮助。',
        '',
        true,
        'professional',
        '🤖',
        '基础AI助手（应急模式）',
        true
      )
    ];
  }


  /**
   * 根据分类获取提示词
   */
  static getPromptsByCategory(category: string): SystemPrompt[] {
    const allPrompts = DefaultPrompts.getAllPromptsSync();
    switch (category.toLowerCase()) {
      case 'professional':
      case '专业':
      case '专业咨询类':
        return allPrompts.filter(prompt => prompt.roleCategory === 'professional');
      case 'character':
      case '人物':
        return allPrompts.filter(prompt => prompt.roleCategory === 'character');
      default:
        return [];
    }
  }

  /**
   * 搜索提示词
   */
  static searchPrompts(keyword: string): SystemPrompt[] {
    const lowerKeyword = keyword.toLowerCase();
    return DefaultPrompts.getAllPromptsSync().filter(prompt =>
    prompt.name.toLowerCase().includes(lowerKeyword) ||
    prompt.content.toLowerCase().includes(lowerKeyword)
    );
  }

  /**
   * 获取提示词分类列表
   */
  static getCategories(): string[] {
    return [
      '专业咨询类', '人物'
    ];
  }
}
