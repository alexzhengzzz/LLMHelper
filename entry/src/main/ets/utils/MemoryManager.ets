import {
  MemoryFragment,
  MemoryCategory,
  MemoryImportance,
  MemoryStats,
  MemoryCategoryCounts,
  MemoryImportanceCounts,
  CreateMemoryRequest,
  UpdateMemoryRequest,
  MemoryFilterOptions,
  MemorySortBy,
  MemorySortDirection,
  MemorySortOptions,
  MemoryOperationResult,
  MemoryInjectionConfig,
  MemoryItem,
  MemorySearchResult,
  HybridSearchResult,
  VectorSearchResult,
  VectorMigrationStatus
} from '../types/MemoryTypes';
import { AppStorage } from './AppStorage';
import { Logger } from './Logger';
import { VectorEmbeddingService } from '../services/VectorEmbeddingService';

export interface MemoryItemWithoutId {
  title: string;
  content: string;
  tags: string[];
  category: MemoryCategory;
  importance: MemoryImportance;
  isActive: boolean;
  createdAt: number;
  updatedAt: number;
  usageCount: number;
  lastUsedAt: number;
}

// 关键词搜索结果接口
export interface KeywordSearchResult {
  memory: MemoryFragment;
  score: number;
}

/**
 * 记忆管理器 - 负责用户记忆碎片的管理
 */
export class MemoryManager {
  private static instance: MemoryManager | null = null;
  private readonly MEMORY_STORAGE_KEY = 'user_memories';
  private readonly MEMORY_CONFIG_KEY = 'memory_injection_config';
  private readonly MEMORY_STATS_KEY = 'memory_stats_cache';
  private memoryStatsListeners: Array<(stats: MemoryStats) => void> = [];

  private constructor() {
    // 初始化向量化服务
    this.initializeVectorService();
  }

  /**
   * 初始化向量化服务
   */
  private async initializeVectorService(): Promise<void> {
    try {
      const vectorService = VectorEmbeddingService.getInstance();
      const initialized = await vectorService.initialize();
      if (!initialized) {
        Logger.warn('MemoryManager', '向量化服务初始化失败，将使用关键词搜索');
      } else {
        Logger.info('MemoryManager', '向量化服务初始化成功');
      }
    } catch (error) {
      Logger.warn('MemoryManager', `向量化服务初始化异常: ${error}`);
    }
  }

  /**
   * 获取单例实例
   */
  static getInstance(): MemoryManager {
    if (!MemoryManager.instance) {
      MemoryManager.instance = new MemoryManager();
    }
    return MemoryManager.instance;
  }

  /**
   * 生成唯一ID
   */
  private generateId(): string {
    return `memory_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 获取所有记忆碎片
   */
  async getAllMemories(): Promise<MemoryFragment[]> {
    try {
      const storage = AppStorage.getPreferences();
      const jsonStr = await storage.get(this.MEMORY_STORAGE_KEY, '[]');
      const memories = JSON.parse(jsonStr as string) as MemoryFragment[];
      Logger.debug('MemoryManager', `获取到 ${memories.length} 个记忆碎片`);
      return memories;
    } catch (error) {
      Logger.error('MemoryManager', `获取记忆碎片失败: ${error}`);
      return [];
    }
  }

  /**
   * 创建新的记忆碎片
   */
  async createMemory(request: CreateMemoryRequest): Promise<MemoryOperationResult> {
    try {
      if (!request.content || !request.content.trim()) {
        return {
          success: false,
          message: '记忆内容不能为空'
        };
      }

      const now = Date.now();

      // 生成向量嵌入
      let vector: number[] | undefined = undefined;
      try {
        const embeddingResult = await VectorEmbeddingService.getInstance().generateEmbedding(request.content.trim());
        if (embeddingResult !== null) {
          vector = embeddingResult;
          Logger.info('MemoryManager', `成功生成记忆向量，维度: ${vector.length}`);
        }
      } catch (error) {
        Logger.warn('MemoryManager', `生成向量失败，将保存为无向量记忆: ${error}`);
        // 向量生成失败时继续保存，只是没有向量
      }

      const memory: MemoryFragment = {
        id: this.generateId(),
        content: request.content.trim(),
        tags: request.tags || [],
        category: request.category || MemoryCategory.CUSTOM,
        importance: request.importance || MemoryImportance.MEDIUM,
        isActive: request.isActive !== undefined ? request.isActive : true,
        createdAt: now,
        updatedAt: now,
        usageCount: 0,
        lastUsedAt: 0,
        vector: vector
      };

      const memories = await this.getAllMemories();
      memories.push(memory);

      const storage = AppStorage.getPreferences();
      await storage.put(this.MEMORY_STORAGE_KEY, JSON.stringify(memories));
      await storage.flush();

      // 更新统计缓存
      await this.updateMemoryStatsCache();

      Logger.info('MemoryManager', `创建记忆碎片成功: ${memory.id}`);
      return {
        success: true,
        message: '记忆碎片创建成功',
        data: memory
      };

    } catch (error) {
      Logger.error('MemoryManager', `创建记忆碎片失败: ${error}`);
      return {
        success: false,
        message: `创建记忆碎片失败: ${error}`
      };
    }
  }

  /**
   * 更新记忆碎片
   */
  async updateMemory(id: string, request: UpdateMemoryRequest): Promise<MemoryOperationResult> {
    try {
      const memories = await this.getAllMemories();
      const index = memories.findIndex(m => m.id === id);

      if (index === -1) {
        return {
          success: false,
          message: '记忆碎片不存在'
        };
      }

      const memory = memories[index];

      // 更新字段
      if (request.content !== undefined) {
        if (!request.content.trim()) {
          return {
            success: false,
            message: '记忆内容不能为空'
          };
        }
        memory.content = request.content.trim();

        // 内容更新时重新生成向量
        try {
          const vector = await VectorEmbeddingService.getInstance().generateEmbedding(memory.content);
          if (vector) {
            memory.vector = vector;
            Logger.info('MemoryManager', `内容更新后重新生成向量，维度: ${vector.length}`);
          }
        } catch (error) {
          Logger.warn('MemoryManager', `重新生成向量失败，保留原向量或设为无向量: ${error}`);
          // 向量生成失败时保留原vector或设为undefined
        }
      }

      if (request.tags !== undefined) {
        memory.tags = request.tags;
      }

      if (request.category !== undefined) {
        memory.category = request.category;
      }

      if (request.importance !== undefined) {
        memory.importance = request.importance;
      }

      if (request.isActive !== undefined) {
        memory.isActive = request.isActive;
      }

      memory.updatedAt = Date.now();

      const storage = AppStorage.getPreferences();
      await storage.put(this.MEMORY_STORAGE_KEY, JSON.stringify(memories));
      await storage.flush();

      Logger.info('MemoryManager', `更新记忆碎片成功: ${id}`);
      return {
        success: true,
        message: '记忆碎片更新成功',
        data: memory
      };

    } catch (error) {
      Logger.error('MemoryManager', `更新记忆碎片失败: ${error}`);
      return {
        success: false,
        message: `更新记忆碎片失败: ${error}`
      };
    }
  }

  /**
   * 删除记忆碎片
   */
  async deleteMemory(id: string): Promise<MemoryOperationResult> {
    try {
      const memories = await this.getAllMemories();
      const index = memories.findIndex(m => m.id === id);

      if (index === -1) {
        return {
          success: false,
          message: '记忆碎片不存在'
        };
      }

      memories.splice(index, 1);
      const storage = AppStorage.getPreferences();
      await storage.put(this.MEMORY_STORAGE_KEY, JSON.stringify(memories));
      await storage.flush();

      // 更新统计缓存
      await this.updateMemoryStatsCache();

      Logger.info('MemoryManager', `删除记忆碎片成功: ${id}`);
      return {
        success: true,
        message: '记忆碎片删除成功'
      };

    } catch (error) {
      Logger.error('MemoryManager', `删除记忆碎片失败: ${error}`);
      return {
        success: false,
        message: `删除记忆碎片失败: ${error}`
      };
    }
  }

  /**
   * 获取单个记忆碎片
   */
  async getMemory(id: string): Promise<MemoryFragment | null> {
    try {
      const memories = await this.getAllMemories();
      const memory = memories.find(m => m.id === id);
      return memory || null;
    } catch (error) {
      Logger.error('MemoryManager', `获取记忆碎片失败: ${error}`);
      return null;
    }
  }

  /**
   * 获取激活的记忆碎片（用于注入到对话中）
   */
  async getActiveMemories(): Promise<MemoryFragment[]> {
    try {
      const memories = await this.getAllMemories();
      const activeMemories = memories.filter(m => m.isActive);

      // 按重要性和使用频率排序
      activeMemories.sort((a, b) => {
        // 首先按重要性排序
        let aWeight = 0;
        let bWeight = 0;

        // 设置a的权重
        if (a.importance === MemoryImportance.CRITICAL) aWeight = 4;
        else if (a.importance === MemoryImportance.HIGH) aWeight = 3;
        else if (a.importance === MemoryImportance.MEDIUM) aWeight = 2;
        else if (a.importance === MemoryImportance.LOW) aWeight = 1;

        // 设置b的权重
        if (b.importance === MemoryImportance.CRITICAL) bWeight = 4;
        else if (b.importance === MemoryImportance.HIGH) bWeight = 3;
        else if (b.importance === MemoryImportance.MEDIUM) bWeight = 2;
        else if (b.importance === MemoryImportance.LOW) bWeight = 1;

        if (aWeight !== bWeight) {
          return bWeight - aWeight; // 重要性高的在前
        }

        // 重要性相同时，按使用频率排序
        if (a.usageCount !== b.usageCount) {
          return b.usageCount - a.usageCount; // 使用频率高的在前
        }

        // 最后按更新时间排序
        return b.updatedAt - a.updatedAt; // 最近更新的在前
      });

      Logger.debug('MemoryManager', `获取到 ${activeMemories.length} 个激活的记忆碎片`);
      return activeMemories;
    } catch (error) {
      Logger.error('MemoryManager', `获取激活记忆碎片失败: ${error}`);
      return [];
    }
  }

  /**
   * 搜索记忆碎片 - 支持向量搜索和关键词搜索
   */
  async searchMemories(semanticQuery: string, keywords: string): Promise<MemoryFragment[]> {
    try {
      if (!semanticQuery?.trim() && !keywords?.trim()) {
        return await this.getAllMemories();
      }

      const memories = await this.getAllMemories();
      const vectorService = VectorEmbeddingService.getInstance();
      const config = vectorService.getConfig();

      // 1. Vector Search
      let vectorResults: VectorSearchResult[] = [];
      if (semanticQuery?.trim()) {
        try {
          const queryVector = await vectorService.generateEmbedding(semanticQuery);
          if (queryVector) {
            Logger.info('MemoryManager', `生成查询向量成功，开始向量搜索，维度: ${queryVector.length}`);
            const memoriesWithVectors = memories.filter(m => m.vector && m.vector.length > 0);
            const tempVectorResults: VectorSearchResult[] = memoriesWithVectors
              .map(memory => {
                const vectorResult: VectorSearchResult = {
                  memory: memory,
                  similarity: vectorService.calculateCosineSimilarity(queryVector, memory.vector!)
                };
                return vectorResult;
              });
            vectorResults = tempVectorResults.filter(result => result.similarity >= config.minSimilarity);
            Logger.info('MemoryManager', `向量搜索找到 ${vectorResults.length} 个候选结果`);
          }
        } catch (error) {
          Logger.warn('MemoryManager', `向量搜索失败: ${error}`);
        }
      }

      // 2. Keyword Search
      let keywordResults: KeywordSearchResult[] = [];
      if (keywords?.trim()) {
        const expandedKeywords = this.expandKeywords(keywords.toLowerCase().trim());
        const tempKeywordResults: KeywordSearchResult[] = memories.map(memory => {
          const keywordResult: KeywordSearchResult = {
            memory: memory,
            score: this.calculateKeywordScore(memory, expandedKeywords)
          };
          return keywordResult;
        });
        keywordResults = tempKeywordResults.filter(result => result.score > 0);
        Logger.info('MemoryManager', `关键词搜索找到 ${keywordResults.length} 个候选结果`);
      }

      // 3. Hybrid Merge & Rank
      const resultMap = new Map<string, HybridSearchResult>();

      // Add keyword results to map
      keywordResults.forEach(res => {
        resultMap.set(res.memory.id, {
          memory: res.memory,
          finalScore: res.score * config.keywordWeight,
          keywordScore: res.score,
          vectorScore: 0
        });
      });

      // Add vector results, boosting score if also found by keyword search
      vectorResults.forEach(res => {
        if (resultMap.has(res.memory.id)) {
          const existing = resultMap.get(res.memory.id)!;
          existing.vectorScore = res.similarity;
          existing.finalScore += res.similarity * config.vectorWeight;
        } else {
          resultMap.set(res.memory.id, {
            memory: res.memory,
            finalScore: res.similarity * config.vectorWeight,
            vectorScore: res.similarity,
            keywordScore: 0
          });
        }
      });

      const hybridResults = Array.from(resultMap.values());

      // Sort by final score, then importance, then usage
      hybridResults.sort((a, b) => {
        if (a.finalScore !== b.finalScore) return b.finalScore - a.finalScore;
        const aImportance = this.getImportanceWeight(a.memory.importance);
        const bImportance = this.getImportanceWeight(b.memory.importance);
        if (aImportance !== bImportance) return bImportance - aImportance;
        return b.memory.usageCount - a.memory.usageCount;
      });

      const finalResults = hybridResults.slice(0, config.maxResults).map(result => result.memory);

      Logger.info('MemoryManager', `混合搜索完成，返回 ${finalResults.length} 个结果.`);
      return finalResults;

    } catch (error) {
      Logger.error('MemoryManager', `搜索记忆碎片失败: ${error}`);
      return [];
    }
  }

  /**
   * Expands a keyword string into a set of unique search terms using semantic mappings.
   */
  private expandKeywords(keyword: string): string[] {
    const semanticMappings = this.getSemanticMappings();
    let searchTerms = new Set<string>(keyword.split(/\s+/).filter(k => k));

    Object.entries(semanticMappings).forEach((entry: [string, string[]]) => {
      const pattern = entry[0];
      const terms = entry[1];
      if (keyword.includes(pattern)) {
        terms.forEach(term => searchTerms.add(term));
      }
    });
    
    const expanded = Array.from(searchTerms);
    Logger.debug('MemoryManager', `关键词 "${keyword}" 扩展为: [${expanded.join(', ')}]`);
    return expanded;
  }

  /**
   * Calculates a score based on how well a memory's content and tags match a set of keywords.
   */
  private calculateKeywordScore(memory: MemoryFragment, keywords: string[]): number {
    const lowerContent = memory.content.toLowerCase();
    const lowerTags = memory.tags.map(tag => tag.toLowerCase());
    let score = 0;

    keywords.forEach(kw => {
      if (lowerContent.includes(kw)) {
        score += 1; // Base score for content match
      }
      if (lowerTags.some(tag => tag.includes(kw))) {
        score += 2; // Higher score for tag match
      }
    });

    // Normalize score - simple normalization for demonstration
    return score > 0 ? Math.min(score / 5, 1.0) : 0;
  }


  /**
   * 语义映射：将自然语言问题映射到相关关键词
   */
  private getSemanticMappings(): Record<string, string[]> {
    return {
      '名字': ['名字', '姓名', '称呼', '叫我什么', '怎么称呼', '我是谁'],
      '你叫': ['名字', '姓名', '称呼', '助手', 'ai', '机器人'],
      '我叫': ['名字', '姓名', '用户', '主人'],
      '称呼': ['名字', '姓名', '叫我什么', '怎么称呼'],
      '我是': ['名字', '姓名', '用户', '主人'],
      '用户': ['名字', '姓名', '用户', '主人', '你'],
      '偏好': ['喜欢', '不喜欢', '偏好', '习惯', '爱好', '兴趣'],
      '设置': ['配置', '设置', '选项', '参数', '偏好'],
      '工作': ['工作', '职业', '公司', '职位', '专业'],
      '学习': ['学习', '教育', '学校', '专业', '课程'],
      '家庭': ['家庭', '家人', '父母', '子女', '配偶'],
      '爱好': ['爱好', '兴趣', '喜欢', '娱乐', '运动']
    };
  }



  /**
   * 获取重要性权重
   */
  private getImportanceWeight(importance: string): number {
    switch (importance) {
      case 'critical': return 4;
      case 'high': return 3;
      case 'medium': return 2;
      case 'low': return 1;
      default: return 1;
    }
  }

  /**
   * 按分类获取记忆碎片
   */
  async getMemoriesByCategory(category: MemoryCategory): Promise<MemoryFragment[]> {
    try {
      const memories = await this.getAllMemories();
      const categoryMemories = memories.filter(m => m.category === category);

      Logger.debug('MemoryManager', `分类 ${category} 有 ${categoryMemories.length} 个记忆碎片`);
      return categoryMemories;
    } catch (error) {
      Logger.error('MemoryManager', `按分类获取记忆碎片失败: ${error}`);
      return [];
    }
  }

  /**
   * 获取记忆统计信息
   */
  async getMemoryStats(): Promise<MemoryStats> {
    try {
      const memories = await this.getAllMemories();

      const categoryCounts: MemoryCategoryCounts = {
        personal: 0,
        preference: 0,
        work: 0,
        study: 0,
        hobby: 0,
        family: 0,
        health: 0,
        custom: 0
      };

      const importanceCounts: MemoryImportanceCounts = {
        low: 0,
        medium: 0,
        high: 0,
        critical: 0
      };

      let lastUpdated = 0;
      let totalUsageCount = 0;

      memories.forEach(memory => {
        // 更新分类统计
        if (memory.category === MemoryCategory.PERSONAL) categoryCounts.personal++;
        else if (memory.category === MemoryCategory.PREFERENCE) categoryCounts.preference++;
        else if (memory.category === MemoryCategory.WORK) categoryCounts.work++;
        else if (memory.category === MemoryCategory.STUDY) categoryCounts.study++;
        else if (memory.category === MemoryCategory.HOBBY) categoryCounts.hobby++;
        else if (memory.category === MemoryCategory.FAMILY) categoryCounts.family++;
        else if (memory.category === MemoryCategory.HEALTH) categoryCounts.health++;
        else if (memory.category === MemoryCategory.CUSTOM) categoryCounts.custom++;

        // 更新重要性统计
        if (memory.importance === MemoryImportance.LOW) importanceCounts.low++;
        else if (memory.importance === MemoryImportance.MEDIUM) importanceCounts.medium++;
        else if (memory.importance === MemoryImportance.HIGH) importanceCounts.high++;
        else if (memory.importance === MemoryImportance.CRITICAL) importanceCounts.critical++;

        totalUsageCount += memory.usageCount;

        if (memory.updatedAt > lastUpdated) {
          lastUpdated = memory.updatedAt;
        }
      });

      const stats: MemoryStats = {
        totalFragments: memories.length,
        activeFragments: memories.filter(m => m.isActive).length,
        categoryCounts: categoryCounts,
        importanceCounts: importanceCounts,
        lastUpdated: lastUpdated,
        totalUsageCount: totalUsageCount
      };

      return stats;
    } catch (error) {
      Logger.error('MemoryManager', `获取记忆统计失败: ${error}`);
      return {
        totalFragments: 0,
        activeFragments: 0,
        categoryCounts: {
          personal: 0,
          preference: 0,
          work: 0,
          study: 0,
          hobby: 0,
          family: 0,
          health: 0,
          custom: 0
        },
        importanceCounts: {
          low: 0,
          medium: 0,
          high: 0,
          critical: 0
        },
        lastUpdated: 0,
        totalUsageCount: 0
      };
    }
  }

  /**
   * 增加记忆使用次数
   */
  async incrementUsageCount(id: string): Promise<void> {
    try {
      const memories = await this.getAllMemories();
      const memory = memories.find(m => m.id === id);

      if (memory) {
        memory.usageCount++;
        memory.lastUsedAt = Date.now();
        const storage = AppStorage.getPreferences();
      await storage.put(this.MEMORY_STORAGE_KEY, JSON.stringify(memories));
      await storage.flush();
        Logger.debug('MemoryManager', `记忆碎片 ${id} 使用次数增加至 ${memory.usageCount}`);
      }
    } catch (error) {
      Logger.error('MemoryManager', `增加使用次数失败: ${error}`);
    }
  }

  /**
   * 生成记忆注入文本（用于系统提示词）
   */
  async generateMemoryInjectionText(): Promise<string> {
    try {
      const activeMemories = await this.getActiveMemories();

      if (activeMemories.length === 0) {
        return '';
      }

      // 限制最大数量（避免提示词过长）
      const maxMemories = 10;
      const memoriesToUse = activeMemories.slice(0, maxMemories);

      // 增加使用次数
      for (const memory of memoriesToUse) {
        await this.incrementUsageCount(memory.id);
      }

      // 生成注入文本
      const memoryLines = memoriesToUse.map(memory => `- ${memory.content}`);

      const injectionText = `---
这是关于用户的一些重要记忆，请在回答时参考：
${memoryLines.join('\n')}
---`;

      Logger.info('MemoryManager', `生成记忆注入文本，包含 ${memoriesToUse.length} 个记忆碎片`);
      return injectionText;

    } catch (error) {
      Logger.error('MemoryManager', `生成记忆注入文本失败: ${error}`);
      return '';
    }
  }

  /**
   * 切换记忆碎片的激活状态
   */
  async toggleMemoryActive(id: string): Promise<MemoryOperationResult> {
    try {
      const memories = await this.getAllMemories();
      const memory = memories.find(m => m.id === id);

      if (!memory) {
        return {
          success: false,
          message: '记忆碎片不存在'
        };
      }

      memory.isActive = !memory.isActive;
      memory.updatedAt = Date.now();

      const storage = AppStorage.getPreferences();
      await storage.put(this.MEMORY_STORAGE_KEY, JSON.stringify(memories));
      await storage.flush();

      Logger.info('MemoryManager', `记忆碎片 ${id} 激活状态切换为: ${memory.isActive}`);
      return {
        success: true,
        message: `记忆碎片已${memory.isActive ? '激活' : '停用'}`,
        data: memory
      };

    } catch (error) {
      Logger.error('MemoryManager', `切换记忆碎片激活状态失败: ${error}`);
      return {
        success: false,
        message: `切换激活状态失败: ${error}`
      };
    }
  }

  /**
   * 清空所有记忆碎片
   */
  async clearAllMemories(): Promise<MemoryOperationResult> {
    try {
      const storage = AppStorage.getPreferences();
      await storage.put(this.MEMORY_STORAGE_KEY, JSON.stringify([]));
      await storage.flush();

      Logger.info('MemoryManager', '已清空所有记忆碎片');
      return {
        success: true,
        message: '所有记忆碎片已清空'
      };

    } catch (error) {
      Logger.error('MemoryManager', `清空记忆碎片失败: ${error}`);
      return {
        success: false,
        message: `清空失败: ${error}`
      };
    }
  }

  /**
   * 获取记忆项列表（兼容MemoryItem接口）
   */
  async getMemoryItems(): Promise<MemoryItem[]> {
    const fragments = await this.getAllMemories();
    return fragments.map(fragment => ({
      id: fragment.id,
      title: `记忆-${fragment.createdAt}`,
      content: fragment.content,
      tags: fragment.tags,
      category: fragment.category,
      importance: fragment.importance,
      isActive: fragment.isActive,
      createdAt: fragment.createdAt,
      updatedAt: fragment.updatedAt,
      usageCount: fragment.usageCount,
      lastUsedAt: fragment.lastUsedAt
    } as MemoryItem));
  }

  /**
   * 添加记忆项（兼容MemoryItem接口）
   */
  async addMemoryItem(item: MemoryItemWithoutId): Promise<MemoryItem> {
    const request: CreateMemoryRequest = {
      content: item.content,
      tags: item.tags,
      category: item.category,
      importance: item.importance,
      isActive: item.isActive
    };

    const result = await this.createMemory(request);
    if (result.success && result.data) {
      const fragment = Array.isArray(result.data) ? result.data[0] : result.data;
      return {
        id: fragment.id,
        title: `记忆-${fragment.createdAt}`,
        content: fragment.content,
        tags: fragment.tags,
        category: fragment.category,
        importance: fragment.importance,
        isActive: fragment.isActive,
        createdAt: fragment.createdAt,
        updatedAt: fragment.updatedAt,
        usageCount: fragment.usageCount,
        lastUsedAt: fragment.lastUsedAt
      } as MemoryItem;
    }
    throw new Error(result.message || '添加记忆失败');
  }

  /**
   * 更新记忆项（兼容MemoryItem接口）
   */
  async updateMemoryItem(id: string, item: MemoryItemWithoutId): Promise<MemoryItem> {
    const request: UpdateMemoryRequest = {
      content: item.content,
      tags: item.tags,
      category: item.category,
      importance: item.importance,
      isActive: item.isActive
    };

    Logger.debug('MemoryManager', `updateMemoryItem调用，ID: ${id}, 内容长度: ${item.content.length}`);
    const result = await this.updateMemory(id, request);
    if (result.success && result.data) {
      const fragment = Array.isArray(result.data) ? result.data[0] : result.data;
      // 🔧 修复：使用动态生成的title而不是传入的title
      const generatedTitle = `记忆-${fragment.createdAt}`;
      Logger.debug('MemoryManager', `updateMemoryItem成功，生成title: ${generatedTitle}`);
      return {
        id: fragment.id,
        title: generatedTitle, // 使用动态生成的title
        content: fragment.content,
        tags: fragment.tags,
        category: fragment.category,
        importance: fragment.importance,
        isActive: fragment.isActive,
        createdAt: fragment.createdAt,
        updatedAt: fragment.updatedAt,
        usageCount: fragment.usageCount,
        lastUsedAt: fragment.lastUsedAt
      } as MemoryItem;
    }
    Logger.error('MemoryManager', `updateMemoryItem失败: ${result.message}`);
    throw new Error(result.message || '更新记忆失败');
  }

  /**
   * 删除记忆项（兼容MemoryItem接口）
   */
  async deleteMemoryItem(id: string): Promise<boolean> {
    const result = await this.deleteMemory(id);
    return result.success;
  }

  /**
   * 保存记忆统计数据到缓存
   */
  private async saveMemoryStatsCache(stats: MemoryStats): Promise<void> {
    try {
      const storage = AppStorage.getPreferences();
      await storage.put(this.MEMORY_STATS_KEY, JSON.stringify(stats));
      await storage.flush();
      Logger.debug('MemoryManager', `记忆统计数据已缓存: 总计${stats.totalFragments}个，激活${stats.activeFragments}个`);
    } catch (error) {
      Logger.error('MemoryManager', `保存记忆统计缓存失败: ${error}`);
    }
  }

  /**
   * 从缓存获取记忆统计数据
   */
  async getCachedMemoryStats(): Promise<MemoryStats | null> {
    try {
      const storage = AppStorage.getPreferences();
      const jsonStr = await storage.get(this.MEMORY_STATS_KEY, '');

      if (!jsonStr) {
        Logger.debug('MemoryManager', '未找到记忆统计缓存');
        return null;
      }

      const stats = JSON.parse(jsonStr as string) as MemoryStats;
      Logger.debug('MemoryManager', `从缓存获取记忆统计: 总计${stats.totalFragments}个，激活${stats.activeFragments}个`);
      return stats;
    } catch (error) {
      Logger.error('MemoryManager', `获取记忆统计缓存失败: ${error}`);
      return null;
    }
  }

  /**
   * 更新记忆统计缓存（在数据变更时调用）
   */
  async updateMemoryStatsCache(): Promise<void> {
    try {
      const stats = await this.getMemoryStats();
      await this.saveMemoryStatsCache(stats);
      Logger.info('MemoryManager', `记忆统计缓存已更新: 总计${stats.totalFragments}个，激活${stats.activeFragments}个`);

      // 通知所有监听器
      this.notifyMemoryStatsListeners(stats);
    } catch (error) {
      Logger.error('MemoryManager', `更新记忆统计缓存失败: ${error}`);
    }
  }

  /**
   * 添加记忆统计变更监听器
   */
  addMemoryStatsListener(listener: (stats: MemoryStats) => void): void {
    this.memoryStatsListeners.push(listener);
    Logger.debug('MemoryManager', `添加记忆统计监听器，当前监听器数量: ${this.memoryStatsListeners.length}`);
  }

  /**
   * 移除记忆统计变更监听器
   */
  removeMemoryStatsListener(listener: (stats: MemoryStats) => void): void {
    const index = this.memoryStatsListeners.indexOf(listener);
    if (index > -1) {
      this.memoryStatsListeners.splice(index, 1);
      Logger.debug('MemoryManager', `移除记忆统计监听器，当前监听器数量: ${this.memoryStatsListeners.length}`);
    }
  }

  /**
   * 通知所有记忆统计监听器
   */
  private notifyMemoryStatsListeners(stats: MemoryStats): void {
    Logger.debug('MemoryManager', `通知 ${this.memoryStatsListeners.length} 个记忆统计监听器`);
    this.memoryStatsListeners.forEach(listener => {
      try {
        listener(stats);
      } catch (error) {
        Logger.error('MemoryManager', `记忆统计监听器执行失败: ${error}`);
      }
    });
  }

  /**
   * 迁移现有记忆数据，为没有向量的记忆生成向量
   */
  async migrateMemoriesToVectors(): Promise<MemoryOperationResult> {
    try {
      Logger.info('MemoryManager', '开始迁移记忆数据到向量格式...');

      const memories = await this.getAllMemories();
      const vectorService = VectorEmbeddingService.getInstance();

      // 检查是否需要迁移
      const memoriesWithoutVectors = memories.filter(memory => !memory.vector || memory.vector.length === 0);

      if (memoriesWithoutVectors.length === 0) {
        Logger.info('MemoryManager', '所有记忆已有向量，无需迁移');
        return {
          success: true,
          message: '所有记忆已有向量，无需迁移'
        };
      }

      Logger.info('MemoryManager', `发现 ${memoriesWithoutVectors.length} 个记忆需要向量迁移`);

      // 限制每次迁移的数量，避免API限制
      const batchSize = 50;
      let successCount = 0;
      let failCount = 0;

      for (let i = 0; i < memoriesWithoutVectors.length; i += batchSize) {
        const batch = memoriesWithoutVectors.slice(i, i + batchSize);
        Logger.info('MemoryManager', `正在处理第 ${Math.floor(i / batchSize) + 1} 批，共 ${batch.length} 个记忆`);

        // 为这一批记忆生成向量
        const texts: string[] = batch.map(memory => memory.content);
        const embeddings: (number[] | null)[] = await vectorService.generateEmbeddings(texts);

        // 更新记忆的向量
        for (let j = 0; j < batch.length; j++) {
          const memory = batch[j];
          const vector = embeddings[j];

          if (vector && vector.length > 0) {
            // 找到原始记忆并更新
            const originalIndex = memories.findIndex(m => m.id === memory.id);
            if (originalIndex !== -1) {
              memories[originalIndex].vector = vector;
              memories[originalIndex].updatedAt = Date.now();
              successCount++;
            }
          } else {
            failCount++;
            Logger.warn('MemoryManager', `记忆 "${memory.content.substring(0, 50)}..." 向量生成失败`);
          }
        }

        // 每批完成后保存一次
        const storage = AppStorage.getPreferences();
        await storage.put(this.MEMORY_STORAGE_KEY, JSON.stringify(memories));
        await storage.flush();

        // 添加延迟避免API限制
        if (i + batchSize < memoriesWithoutVectors.length) {
          await new Promise<void>(resolve => setTimeout(resolve, 1000));
        }
      }

      Logger.info('MemoryManager',
        `向量迁移完成: 成功 ${successCount} 个，失败 ${failCount} 个`
      );

      // 更新统计缓存
      await this.updateMemoryStatsCache();

      return {
        success: true,
        message: `向量迁移完成: 成功 ${successCount} 个，失败 ${failCount} 个`,
        data: memories
      };

    } catch (error) {
      Logger.error('MemoryManager', `向量迁移失败: ${error}`);
      return {
        success: false,
        message: `向量迁移失败: ${error}`
      };
    }
  }

  
  /**
   * 获取向量迁移状态
   */
  async getVectorMigrationStatus(): Promise<VectorMigrationStatus> {
    try {
      const memories = await this.getAllMemories();
      const memoriesWithVectors = memories.filter(memory => memory.vector && memory.vector.length > 0).length;
      const memoriesWithoutVectors = memories.length - memoriesWithVectors;

      const status: VectorMigrationStatus = {
        totalMemories: memories.length,
        memoriesWithVectors: memoriesWithVectors,
        memoriesWithoutVectors: memoriesWithoutVectors,
        migrationNeeded: memoriesWithoutVectors > 0
      };
      return status;
    } catch (error) {
      Logger.error('MemoryManager', `获取向量迁移状态失败: ${error}`);
      const errorStatus: VectorMigrationStatus = {
        totalMemories: 0,
        memoriesWithVectors: 0,
        memoriesWithoutVectors: 0,
        migrationNeeded: false
      };
      return errorStatus;
    }
  }

}