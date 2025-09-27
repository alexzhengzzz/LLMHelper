import { SystemPrompt } from '../models/ChatModels';
import { Logger } from './Logger';
import { DefaultPrompts } from '../data/DefaultPrompts';

/**
 * 分类信息接口
 */
interface CategoryInfo {
  id: string;
  name: string;
  count: number;
}

/**
 * 加载状态接口
 */
interface LoadStatus {
  loaded: boolean;
  count: number;
}

/**
 * 提示词配置管理器
 * 统一管理提示词的加载、缓存和更新
 */
export class PromptsConfigManager {
  private static instance: PromptsConfigManager | null = null;
  private prompts: SystemPrompt[] = [];
  private isLoaded: boolean = false;
  private loadPromise: Promise<SystemPrompt[]> | null = null;

  /**
   * 获取单例实例
   */
  static getInstance(): PromptsConfigManager {
    if (!PromptsConfigManager.instance) {
      PromptsConfigManager.instance = new PromptsConfigManager();
    }
    return PromptsConfigManager.instance;
  }

  /**
   * 私有构造函数
   */
  private constructor() {
    // 初始化时预加载提示词
    this.preloadPrompts();
  }

  /**
   * 预加载提示词（异步）
   */
  private preloadPrompts(): void {
    this.loadPromise = this.loadPrompts();
    this.loadPromise.catch((error: Error) => {
      Logger.error('PromptsConfigManager', `预加载提示词失败: ${error}`);
    });
  }

  /**
   * 异步加载提示词
   */
  private async loadPrompts(): Promise<SystemPrompt[]> {
    try {
      Logger.info('PromptsConfigManager', '开始加载提示词配置');
      const prompts = await DefaultPrompts.getAllPrompts();
      this.prompts = prompts;
      this.isLoaded = true;
      Logger.info('PromptsConfigManager', `成功加载 ${prompts.length} 个提示词`);
      return prompts;
    } catch (error) {
      Logger.error('PromptsConfigManager', `加载提示词失败: ${error}`);
      // 使用同步方法作为后备
      this.prompts = DefaultPrompts.getAllPromptsSync();
      this.isLoaded = true;
      return this.prompts;
    }
  }

  /**
   * 获取所有提示词（异步）
   */
  async getAllPrompts(): Promise<SystemPrompt[]> {
    if (this.isLoaded) {
      return this.prompts;
    }

    if (this.loadPromise) {
      return await this.loadPromise;
    }

    return await this.loadPrompts();
  }

  /**
   * 获取所有提示词（同步，用于向后兼容）
   */
  getAllPromptsSync(): SystemPrompt[] {
    if (this.isLoaded) {
      return this.prompts;
    }

    // 如果还没加载完成，尝试等待异步加载或返回空数组
    if (this.loadPromise) {
      Logger.warn('PromptsConfigManager', '提示词正在异步加载中，暂时返回空数组');
    } else {
      Logger.warn('PromptsConfigManager', '提示词尚未开始加载，返回空数组');
    }
    return DefaultPrompts.getAllPromptsSync();
  }

  /**
   * 根据分类获取提示词
   */
  getPromptsByCategory(category: string): SystemPrompt[] {
    const allPrompts = this.getAllPromptsSync();
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
  searchPrompts(keyword: string): SystemPrompt[] {
    const lowerKeyword = keyword.toLowerCase();
    const allPrompts = this.getAllPromptsSync();
    return allPrompts.filter(prompt =>
      prompt.name.toLowerCase().includes(lowerKeyword) ||
      prompt.content.toLowerCase().includes(lowerKeyword)
    );
  }

  /**
   * 获取提示词分类列表
   */
  getCategories(): CategoryInfo[] {
    const allPrompts = this.getAllPromptsSync();
    const professionalCount = allPrompts.filter(p => p.roleCategory === 'professional').length;
    const characterCount = allPrompts.filter(p => p.roleCategory === 'character').length;

    const professionalCategory: CategoryInfo = { id: 'professional', name: '专业咨询类', count: professionalCount };
    const characterCategory: CategoryInfo = { id: 'character', name: '人物角色', count: characterCount };

    return [professionalCategory, characterCategory];
  }

  /**
   * 重新加载配置
   */
  async reloadConfig(): Promise<SystemPrompt[]> {
    Logger.info('PromptsConfigManager', '重新加载提示词配置');
    this.isLoaded = false;
    this.loadPromise = null;
    DefaultPrompts.clearCache();
    return await this.loadPrompts();
  }

  /**
   * 检查是否已加载完成
   */
  isConfigLoaded(): boolean {
    return this.isLoaded;
  }

  /**
   * 获取加载状态
   */
  getLoadStatus(): LoadStatus {
    const status: LoadStatus = {
      loaded: this.isLoaded,
      count: this.prompts.length
    };
    return status;
  }

  /**
   * 清除实例（用于测试）
   */
  static clearInstance(): void {
    PromptsConfigManager.instance = null;
  }
}