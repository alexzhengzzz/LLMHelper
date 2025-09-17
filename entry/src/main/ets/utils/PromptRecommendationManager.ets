import { AppStorage } from './AppStorage';
import { Constants, PromptTemplate } from './Constants';
import { Logger } from './Logger';

/**
 * Prompt使用统计数据
 */
export interface PromptUsageStats {
  promptId: string;
  usageCount: number;
  lastUsedTime: number;
  categoryUsageCount: number;
  voiceTriggerUsageCount: number;
  averageResponseQuality?: number; // 未来可用于质量评估
}

/**
 * Prompt使用统计数据实现类
 */
class PromptUsageStatsImpl implements PromptUsageStats {
  promptId: string;
  usageCount: number;
  lastUsedTime: number;
  categoryUsageCount: number;
  voiceTriggerUsageCount: number;
  averageResponseQuality?: number;

  constructor(
    promptId: string,
    usageCount: number,
    lastUsedTime: number,
    categoryUsageCount: number,
    voiceTriggerUsageCount: number,
    averageResponseQuality?: number
  ) {
    this.promptId = promptId;
    this.usageCount = usageCount;
    this.lastUsedTime = lastUsedTime;
    this.categoryUsageCount = categoryUsageCount;
    this.voiceTriggerUsageCount = voiceTriggerUsageCount;
    this.averageResponseQuality = averageResponseQuality;
  }
}

/**
 * 推荐配置
 */
export interface RecommendationConfig {
  maxRecommendations: number;
  usageWeightFactor: number;
  recencyWeightFactor: number;
  categoryDiversityFactor: number;
  enableVoiceBasedRecommendation: boolean;
}

/**
 * 带分数的Prompt项
 */
interface ScoredPromptItem {
  template: PromptTemplate;
  score: number;
}

/**
 * Prompt推荐和个性化管理器
 */
export class PromptRecommendationManager {
  private static instance: PromptRecommendationManager;
  private usageStats: Map<string, PromptUsageStats> = new Map();
  private config: RecommendationConfig;
  private isInitialized: boolean = false;

  // 存储键
  private static readonly USAGE_STATS_KEY = 'prompt_usage_stats';
  private static readonly RECOMMENDATION_CONFIG_KEY = 'recommendation_config';

  private constructor() {
    this.config = this.getDefaultConfig();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): PromptRecommendationManager {
    if (!PromptRecommendationManager.instance) {
      PromptRecommendationManager.instance = new PromptRecommendationManager();
    }
    return PromptRecommendationManager.instance;
  }

  /**
   * 初始化管理器
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      Logger.info('PromptRecommendationManager', '初始化推荐管理器');
      
      // 加载使用统计数据
      await this.loadUsageStats();
      
      // 加载推荐配置
      await this.loadConfig();
      
      this.isInitialized = true;
      Logger.info('PromptRecommendationManager', '推荐管理器初始化成功');
    } catch (error) {
      Logger.error('PromptRecommendationManager', `初始化失败: ${error}`);
    }
  }

  /**
   * 记录Prompt使用
   */
  async recordPromptUsage(promptId: string, triggeredByVoice: boolean = false): Promise<void> {
    try {
      const now = Date.now();
      const existingStats = this.usageStats.get(promptId);
      
      if (existingStats) {
        // 更新现有统计
        existingStats.usageCount++;
        existingStats.lastUsedTime = now;
        if (triggeredByVoice) {
          existingStats.voiceTriggerUsageCount++;
        }
      } else {
        // 创建新的统计记录
        const template = Constants.PROMPT_TEMPLATES.find(t => t.id === promptId);
        const newStats = new PromptUsageStatsImpl(
          promptId,
          1,
          now,
          0,
          triggeredByVoice ? 1 : 0
        );
        this.usageStats.set(promptId, newStats);
      }

      // 更新分类使用统计
      await this.updateCategoryUsage(promptId);

      // 保存统计数据
      await this.saveUsageStats();

      Logger.info('PromptRecommendationManager', `记录使用: ${promptId}, 语音触发: ${triggeredByVoice}`);
    } catch (error) {
      Logger.error('PromptRecommendationManager', `记录使用失败: ${error}`);
    }
  }

  /**
   * 获取个性化推荐的Prompt列表
   */
  getPersonalizedRecommendations(maxCount?: number): PromptTemplate[] {
    const count = maxCount || this.config.maxRecommendations;
    
    // 计算所有prompt的推荐分数
    const scoredPrompts: ScoredPromptItem[] = [];
    Constants.PROMPT_TEMPLATES.forEach(template => {
      scoredPrompts.push({
        template: template,
        score: this.calculateRecommendationScore(template)
      });
    });

    // 按分数排序
    scoredPrompts.sort((a, b) => b.score - a.score);

    // 应用分类多样性
    const diversifiedPrompts = this.applyDiversityFilter(scoredPrompts, count);

    Logger.debug('PromptRecommendationManager', `生成 ${diversifiedPrompts.length} 个个性化推荐`);
    return diversifiedPrompts.map(item => item.template);
  }

  /**
   * 获取基于使用频率排序的Prompt列表
   */
  getFrequencyBasedSorting(prompts: PromptTemplate[]): PromptTemplate[] {
    return prompts.sort((a, b) => {
      const aStats = this.usageStats.get(a.id);
      const bStats = this.usageStats.get(b.id);
      
      const aScore = aStats ? aStats.usageCount : 0;
      const bScore = bStats ? bStats.usageCount : 0;
      
      return bScore - aScore;
    });
  }

  /**
   * 获取最近使用的Prompt列表
   */
  getRecentlyUsedPrompts(maxCount: number = 5): PromptTemplate[] {
    const recentStats = Array.from(this.usageStats.values())
      .sort((a, b) => b.lastUsedTime - a.lastUsedTime)
      .slice(0, maxCount);

    const recentPrompts: PromptTemplate[] = [];
    recentStats.forEach(stats => {
      const template = Constants.PROMPT_TEMPLATES.find(t => t.id === stats.promptId);
      if (template) {
        recentPrompts.push(template);
      }
    });

    Logger.debug('PromptRecommendationManager', `获取最近使用的 ${recentPrompts.length} 个prompt`);
    return recentPrompts;
  }

  /**
   * 获取语音触发相关的推荐
   */
  getVoiceBasedRecommendations(): PromptTemplate[] {
    if (!this.config.enableVoiceBasedRecommendation) {
      return [];
    }

    // 筛选有语音触发词且使用过的prompt
    const voicePrompts = Constants.PROMPT_TEMPLATES.filter(template => {
      const stats = this.usageStats.get(template.id);
      return template.voiceTriggers && 
             template.voiceTriggers.length > 0 && 
             stats && 
             stats.voiceTriggerUsageCount > 0;
    });

    // 按语音使用频率排序
    voicePrompts.sort((a, b) => {
      const aStats = this.usageStats.get(a.id)!;
      const bStats = this.usageStats.get(b.id)!;
      return bStats.voiceTriggerUsageCount - aStats.voiceTriggerUsageCount;
    });

    return voicePrompts.slice(0, 3); // 返回前3个
  }

  /**
   * 获取分类使用统计
   */
  getCategoryUsageStats(): Map<string, number> {
    const categoryStats = new Map<string, number>();
    
    Constants.PROMPT_CATEGORIES.forEach(category => {
      let totalUsage = 0;
      Constants.PROMPT_TEMPLATES
        .filter(template => template.category.id === category.id)
        .forEach(template => {
          const stats = this.usageStats.get(template.id);
          if (stats) {
            totalUsage += stats.usageCount;
          }
        });
      categoryStats.set(category.id, totalUsage);
    });

    return categoryStats;
  }

  /**
   * 重置所有统计数据
   */
  async resetAllStats(): Promise<void> {
    try {
      this.usageStats.clear();
      await this.saveUsageStats();
      Logger.info('PromptRecommendationManager', '所有统计数据已重置');
    } catch (error) {
      Logger.error('PromptRecommendationManager', `重置统计数据失败: ${error}`);
    }
  }

  /**
   * 更新推荐配置
   */
  async updateConfig(newConfig: Partial<RecommendationConfig>): Promise<void> {
    try {
      // 手动更新配置属性
      if (newConfig.maxRecommendations !== undefined) {
        this.config.maxRecommendations = newConfig.maxRecommendations;
      }
      if (newConfig.usageWeightFactor !== undefined) {
        this.config.usageWeightFactor = newConfig.usageWeightFactor;
      }
      if (newConfig.recencyWeightFactor !== undefined) {
        this.config.recencyWeightFactor = newConfig.recencyWeightFactor;
      }
      if (newConfig.categoryDiversityFactor !== undefined) {
        this.config.categoryDiversityFactor = newConfig.categoryDiversityFactor;
      }
      if (newConfig.enableVoiceBasedRecommendation !== undefined) {
        this.config.enableVoiceBasedRecommendation = newConfig.enableVoiceBasedRecommendation;
      }
      
      await this.saveConfig();
      Logger.info('PromptRecommendationManager', '推荐配置已更新');
    } catch (error) {
      Logger.error('PromptRecommendationManager', `更新配置失败: ${error}`);
    }
  }

  /**
   * 获取使用统计信息
   */
  getUsageStats(): Map<string, PromptUsageStats> {
    return new Map(this.usageStats);
  }

  /**
   * 计算推荐分数
   */
  private calculateRecommendationScore(template: PromptTemplate): number {
    const stats = this.usageStats.get(template.id);
    if (!stats) {
      return 0; // 未使用过的prompt基础分数为0
    }

    const now = Date.now();
    const daysSinceLastUse = (now - stats.lastUsedTime) / (1000 * 60 * 60 * 24);
    
    // 使用频率权重
    const usageScore = stats.usageCount * this.config.usageWeightFactor;
    
    // 时效性权重 (越近使用分数越高)
    const recencyScore = Math.max(0, 10 - daysSinceLastUse) * this.config.recencyWeightFactor;
    
    // 语音使用加分
    const voiceBonus = stats.voiceTriggerUsageCount * 0.5;
    
    return usageScore + recencyScore + voiceBonus;
  }

  /**
   * 应用分类多样性过滤
   */
  private applyDiversityFilter(
    scoredPrompts: ScoredPromptItem[], 
    maxCount: number
  ): ScoredPromptItem[] {
    const result: ScoredPromptItem[] = [];
    const categoryCount = new Map<string, number>();

    for (const item of scoredPrompts) {
      if (result.length >= maxCount) {
        break;
      }

      const categoryId = item.template.category.id;
      const currentCount = categoryCount.get(categoryId) || 0;
      
      // 限制每个分类的最大推荐数量
      const maxPerCategory = Math.ceil(maxCount / Constants.PROMPT_CATEGORIES.length);
      
      if (currentCount < maxPerCategory) {
        result.push(item);
        categoryCount.set(categoryId, currentCount + 1);
      }
    }

    return result;
  }

  /**
   * 更新分类使用统计
   */
  private async updateCategoryUsage(promptId: string): Promise<void> {
    const template = Constants.PROMPT_TEMPLATES.find(t => t.id === promptId);
    if (!template) return;

    // 更新同分类的所有prompt的分类使用计数
    const categoryPrompts = Constants.PROMPT_TEMPLATES.filter(
      t => t.category.id === template.category.id
    );

    categoryPrompts.forEach(prompt => {
      const stats = this.usageStats.get(prompt.id);
      if (stats) {
        stats.categoryUsageCount++;
      }
    });
  }

  /**
   * 加载使用统计数据
   */
  private async loadUsageStats(): Promise<void> {
    try {
      const storage = AppStorage.getPreferences();
      const statsStr = await storage.get(PromptRecommendationManager.USAGE_STATS_KEY, '[]');
      
      if (statsStr && statsStr !== '[]') {
        const statsArray: PromptUsageStats[] = JSON.parse(statsStr as string);
        this.usageStats.clear();
        
        statsArray.forEach(stats => {
          this.usageStats.set(stats.promptId, stats);
        });
        
        Logger.debug('PromptRecommendationManager', `加载了 ${statsArray.length} 条使用统计`);
      }
    } catch (error) {
      Logger.error('PromptRecommendationManager', `加载统计数据失败: ${error}`);
    }
  }

  /**
   * 保存使用统计数据
   */
  private async saveUsageStats(): Promise<void> {
    try {
      const statsArray = Array.from(this.usageStats.values());
      const storage = AppStorage.getPreferences();
      const jsonStr = JSON.stringify(statsArray);
      
      await storage.put(PromptRecommendationManager.USAGE_STATS_KEY, jsonStr);
      await storage.flush();
      
      Logger.debug('PromptRecommendationManager', `保存了 ${statsArray.length} 条使用统计`);
    } catch (error) {
      Logger.error('PromptRecommendationManager', `保存统计数据失败: ${error}`);
    }
  }

  /**
   * 加载推荐配置
   */
  private async loadConfig(): Promise<void> {
    try {
      const storage = AppStorage.getPreferences();
      const configStr = await storage.get(PromptRecommendationManager.RECOMMENDATION_CONFIG_KEY, '');
      
      if (configStr) {
        const loadedConfig: RecommendationConfig = JSON.parse(configStr as string);
        const defaultConfig = this.getDefaultConfig();
        this.config = {
          maxRecommendations: loadedConfig.maxRecommendations || defaultConfig.maxRecommendations,
          usageWeightFactor: loadedConfig.usageWeightFactor || defaultConfig.usageWeightFactor,
          recencyWeightFactor: loadedConfig.recencyWeightFactor || defaultConfig.recencyWeightFactor,
          categoryDiversityFactor: loadedConfig.categoryDiversityFactor || defaultConfig.categoryDiversityFactor,
          enableVoiceBasedRecommendation: loadedConfig.enableVoiceBasedRecommendation !== undefined ? 
            loadedConfig.enableVoiceBasedRecommendation : defaultConfig.enableVoiceBasedRecommendation
        };
        Logger.debug('PromptRecommendationManager', '推荐配置加载成功');
      }
    } catch (error) {
      Logger.error('PromptRecommendationManager', `加载推荐配置失败: ${error}`);
    }
  }

  /**
   * 保存推荐配置
   */
  private async saveConfig(): Promise<void> {
    try {
      const storage = AppStorage.getPreferences();
      const jsonStr = JSON.stringify(this.config);
      
      await storage.put(PromptRecommendationManager.RECOMMENDATION_CONFIG_KEY, jsonStr);
      await storage.flush();
      
      Logger.debug('PromptRecommendationManager', '推荐配置保存成功');
    } catch (error) {
      Logger.error('PromptRecommendationManager', `保存推荐配置失败: ${error}`);
    }
  }

  /**
   * 获取默认配置
   */
  private getDefaultConfig(): RecommendationConfig {
    return {
      maxRecommendations: 8,
      usageWeightFactor: 2.0,
      recencyWeightFactor: 1.5,
      categoryDiversityFactor: 1.0,
      enableVoiceBasedRecommendation: true
    };
  }
}