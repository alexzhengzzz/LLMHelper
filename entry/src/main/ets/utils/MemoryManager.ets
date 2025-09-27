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
  VectorMigrationStatus,
  // 用户主动触发记忆功能相关类型
  MemoryTriggerSource,
  MemoryContentType,
  UserMemoryItem,
  MemoryCommandParseResult,
  MemoryCommand,
  SaveUserMemoryRequest,
  MemoryOperationFeedback,
  UserMemoryManagerConfig
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
  private userMemoryConfig: UserMemoryManagerConfig;
  private readonly supportedCommands: MemoryCommand[];

  private constructor() {
    // 初始化用户记忆配置
    this.userMemoryConfig = {
      autoGenerateTitle: true,
      maxTitleLength: 50,
      defaultCategory: MemoryCategory.CUSTOM,
      defaultImportance: MemoryImportance.MEDIUM,
      enableTagSuggestion: true,
      maxRecentMemories: 20,
      enableExportImport: true
    };

    // 初始化支持的记忆指令
    this.supportedCommands = [
      {
        trigger: '记住',
        pattern: /^记住[:：]\s*(.+)$/i,
        description: '记住指定内容',
        example: '记住：我喜欢喝拿铁咖啡'
      },
      {
        trigger: '记下',
        pattern: /^记下[:：]\s*(.+)$/i,
        description: '记下指定内容',
        example: '记下：我的生日是3月15日'
      },
      {
        trigger: '保存',
        pattern: /^保存[:：]\s*(.+)$/i,
        description: '保存指定内容到记忆',
        example: '保存：我在字节跳动工作'
      },
      {
        trigger: '记录',
        pattern: /^记录[:：]\s*(.+)$/i,
        description: '记录指定内容',
        example: '记录：我喜欢周末去爬山'
      }
    ];

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
      const storage = await AppStorage.getStorageAsync();
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
      const memoryId: string = this.generateId();
      let vector: number[] | undefined = undefined;
      try {
        Logger.info('MemoryManager', `开始为记忆生成向量 - 内容: "${request.content.trim().substring(0, 100)}${request.content.trim().length > 100 ? '...' : ''}"`);
        const embeddingResult = await VectorEmbeddingService.getInstance().generateEmbedding(request.content.trim());
        if (embeddingResult !== null) {
          vector = embeddingResult;
          Logger.info('MemoryManager', `记忆向量生成成功 - ID: ${memoryId}, 维度: ${vector.length}`);
          Logger.info('MemoryManager', `向量前10个值: [${vector.slice(0, 10).map(v => v.toFixed(4)).join(', ')}]`);
        } else {
          Logger.warn('MemoryManager', `向量生成返回null，将保存为无向量记忆`);
        }
      } catch (error) {
        Logger.error('MemoryManager', `生成向量失败，将保存为无向量记忆: ${error}`);
        Logger.info('MemoryManager', `记忆将保存为纯文本模式，无向量信息`);
        // 向量生成失败时继续保存，只是没有向量
      }

      const memory: MemoryFragment = {
        id: memoryId,
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

      const storage = await AppStorage.getStorageAsync();
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
          Logger.info('MemoryManager', `内容更新，重新生成向量 - ID: ${id}`);
          Logger.info('MemoryManager', `新内容: "${memory.content.substring(0, 100)}${memory.content.length > 100 ? '...' : ''}"`);
          const vector = await VectorEmbeddingService.getInstance().generateEmbedding(memory.content);
          if (vector) {
            memory.vector = vector;
            Logger.info('MemoryManager', `记忆更新后向量重新生成成功 - ID: ${id}, 维度: ${vector.length}`);
            Logger.info('MemoryManager', `新向量前10个值: [${vector.slice(0, 10).map(v => v.toFixed(4)).join(', ')}]`);
          } else {
            Logger.warn('MemoryManager', `更新后向量生成返回null，保留原向量`);
          }
        } catch (error) {
          Logger.error('MemoryManager', `重新生成向量失败，保留原向量或设为无向量: ${error}`);
          Logger.info('MemoryManager', `保留原向量状态或设为无向量`);
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

      const storage = await AppStorage.getStorageAsync();
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
      const storage = await AppStorage.getStorageAsync();
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

            // 输出详细的相似度调试信息
            Logger.info('MemoryManager', `向量搜索阈值: ${config.minSimilarity}, 原始候选: ${tempVectorResults.length} 个, 过滤后: ${vectorResults.length} 个`);
            if (vectorResults.length > 0) {
              Logger.info('MemoryManager', `候选结果相似度分数: ${vectorResults.map(r => `${r.memory.content.substring(0, 20)}...(${r.similarity.toFixed(3)})`).join(', ')}`);
            }
            if (tempVectorResults.length > vectorResults.length) {
              const filteredResults = tempVectorResults.filter(result => result.similarity < config.minSimilarity);
              Logger.info('MemoryManager', `被过滤的结果: ${filteredResults.map(r => `${r.memory.content.substring(0, 20)}...(${r.similarity.toFixed(3)})`).join(', ')}`);
            }
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
        const storage = await AppStorage.getStorageAsync();
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

      const storage = await AppStorage.getStorageAsync();
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
      const storage = await AppStorage.getStorageAsync();
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
      const storage = await AppStorage.getStorageAsync();
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
      const storage = await AppStorage.getStorageAsync();
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

  /**
   * 记录所有记忆的向量信息到日志
   */
  async logAllMemoryVectors(): Promise<void> {
    try {
      const memories = await this.getAllMemories();
      Logger.info('MemoryManager', `========== 开始记录所有记忆向量信息 ==========`);
      Logger.info('MemoryManager', `总记忆数量: ${memories.length}`);

      const memoriesWithVectors = memories.filter(memory => memory.vector && memory.vector.length > 0);
      const memoriesWithoutVectors = memories.filter(memory => !memory.vector || memory.vector.length === 0);

      Logger.info('MemoryManager', `有向量的记忆: ${memoriesWithVectors.length}`);
      Logger.info('MemoryManager', `无向量的记忆: ${memoriesWithoutVectors.length}`);

      // 记录有向量的记忆详情
      memoriesWithVectors.forEach((memory, index) => {
        Logger.info('MemoryManager', `--- 记忆 ${index + 1} ---`);
        Logger.info('MemoryManager', `ID: ${memory.id}`);
        Logger.info('MemoryManager', `内容: "${memory.content.substring(0, 50)}${memory.content.length > 50 ? '...' : ''}"`);
        Logger.info('MemoryManager', `向量维度: ${memory.vector!.length}`);
        Logger.info('MemoryManager', `向量前10个值: [${memory.vector!.slice(0, 10).map(v => v.toFixed(4)).join(', ')}]`);
        Logger.info('MemoryManager', `向量统计 - 最小值: ${Math.min(...memory.vector!).toFixed(4)}, 最大值: ${Math.max(...memory.vector!).toFixed(4)}`);
        Logger.info('MemoryManager', `向量统计 - 平均值: ${(memory.vector!.reduce((a, b) => a + b, 0) / memory.vector!.length).toFixed(4)}`);
        Logger.info('MemoryManager', `创建时间: ${new Date(memory.createdAt).toLocaleString()}`);
        Logger.info('MemoryManager', `更新时间: ${new Date(memory.updatedAt).toLocaleString()}`);
        Logger.info('MemoryManager', `使用次数: ${memory.usageCount}`);
        Logger.info('MemoryManager', `分类: ${memory.category}, 重要性: ${memory.importance}`);
      });

      // 记录无向量的记忆
      if (memoriesWithoutVectors.length > 0) {
        Logger.info('MemoryManager', `--- 无向量记忆列表 ---`);
        memoriesWithoutVectors.forEach((memory, index) => {
          Logger.info('MemoryManager', `${index + 1}. ID: ${memory.id}, 内容: "${memory.content.substring(0, 30)}${memory.content.length > 30 ? '...' : ''}"`);
        });
      }

      Logger.info('MemoryManager', `========== 记忆向量信息记录完成 ==========`);
    } catch (error) {
      Logger.error('MemoryManager', `记录记忆向量信息失败: ${error}`);
    }
  }

  /**
   * 获取指定记忆的向量信息
   */
  async logMemoryVector(id: string): Promise<void> {
    try {
      const memory = await this.getMemory(id);
      if (!memory) {
        Logger.warn('MemoryManager', `未找到ID为 ${id} 的记忆`);
        return;
      }

      Logger.info('MemoryManager', `========== 记忆向量信息 ==========`);
      Logger.info('MemoryManager', `ID: ${memory.id}`);
      Logger.info('MemoryManager', `内容: "${memory.content}"`);

      if (memory.vector && memory.vector.length > 0) {
        Logger.info('MemoryManager', `向量状态: 有向量`);
        Logger.info('MemoryManager', `向量维度: ${memory.vector.length}`);
        Logger.info('MemoryManager', `完整向量: [${memory.vector.map(v => v.toFixed(4)).join(', ')}]`);
        Logger.info('MemoryManager', `向量前10个值: [${memory.vector.slice(0, 10).map(v => v.toFixed(4)).join(', ')}]`);
        Logger.info('MemoryManager', `向量后10个值: [${memory.vector.slice(-10).map(v => v.toFixed(4)).join(', ')}]`);
        Logger.info('MemoryManager', `向量统计 - 最小值: ${Math.min(...memory.vector).toFixed(4)}, 最大值: ${Math.max(...memory.vector).toFixed(4)}`);
        Logger.info('MemoryManager', `向量统计 - 平均值: ${(memory.vector.reduce((a, b) => a + b, 0) / memory.vector.length).toFixed(4)}`);
        Logger.info('MemoryManager', `向量统计 - 标准差: ${Math.sqrt(memory.vector.reduce((a, b) => a + b * b, 0) / memory.vector.length - Math.pow(memory.vector.reduce((a, b) => a + b, 0) / memory.vector.length, 2)).toFixed(4)}`);
      } else {
        Logger.info('MemoryManager', `向量状态: 无向量`);
      }

      Logger.info('MemoryManager', `创建时间: ${new Date(memory.createdAt).toLocaleString()}`);
      Logger.info('MemoryManager', `更新时间: ${new Date(memory.updatedAt).toLocaleString()}`);
      Logger.info('MemoryManager', `使用次数: ${memory.usageCount}`);
      Logger.info('MemoryManager', `分类: ${memory.category}, 重要性: ${memory.importance}`);
      Logger.info('MemoryManager', `===============================`);
    } catch (error) {
      Logger.error('MemoryManager', `获取记忆向量信息失败: ${error}`);
    }
  }

  // ====== 用户主动触发记忆功能 ======

  /**
   * 解析用户输入中的记忆指令
   */
  parseMemoryCommand(input: string): MemoryCommandParseResult {
    const trimmedInput = input.trim();

    for (const command of this.supportedCommands) {
      const match = trimmedInput.match(command.pattern);
      if (match && match[1]) {
        const content = match[1].trim();
        const title = this.userMemoryConfig.autoGenerateTitle
          ? this.generateTitle(content)
          : undefined;

        return {
          isMemoryCommand: true,
          command: command.trigger,
          content: content,
          title: title,
          tags: this.userMemoryConfig.enableTagSuggestion ? this.suggestTags(content) : [],
          category: this.inferCategory(content)
        };
      }
    }

    return {
      isMemoryCommand: false,
      command: '',
      content: '',
      title: undefined,
      tags: [],
      category: undefined
    };
  }

  /**
   * 保存用户主动触发的记忆
   */
  async saveUserMemory(request: SaveUserMemoryRequest): Promise<MemoryOperationFeedback> {
    try {
      Logger.info('MemoryManager', `保存用户记忆: 来源=${request.triggerSource}, 内容="${request.content.substring(0, 50)}..."`);

      // 生成标题
      const title = request.title || (this.userMemoryConfig.autoGenerateTitle
        ? this.generateTitle(request.content)
        : `记忆-${Date.now()}`);

      // 推断内容类型
      const contentType = request.contentType || this.inferContentType(request.content);

      // 创建记忆请求
      const createRequest: CreateMemoryRequest = {
        content: request.content,
        tags: request.tags || (this.userMemoryConfig.enableTagSuggestion ? this.suggestTags(request.content) : []),
        category: request.category || this.userMemoryConfig.defaultCategory,
        importance: request.importance || this.userMemoryConfig.defaultImportance,
        isActive: true
      };

      // 保存记忆
      const result = await this.createMemory(createRequest);

      if (result.success && result.data) {
        const memory = Array.isArray(result.data) ? result.data[0] : result.data;
        Logger.info('MemoryManager', `用户记忆保存成功: ID=${memory.id}, 标题="${title}"`);

        return {
          success: true,
          message: `已记住：${title}`,
          memoryId: memory.id,
          title: title,
          action: 'save'
        };
      } else {
        Logger.error('MemoryManager', `用户记忆保存失败: ${result.message}`);
        return {
          success: false,
          message: `记忆保存失败：${result.message}`,
          action: 'save'
        };
      }

    } catch (error) {
      Logger.error('MemoryManager', `保存用户记忆异常: ${error}`);
      return {
        success: false,
        message: `记忆保存异常：${error}`,
        action: 'save'
      };
    }
  }

  /**
   * 从消息内容保存用户记忆
   */
  async saveMemoryFromMessage(messageId: string, content: string, sessionId?: string): Promise<MemoryOperationFeedback> {
    const request: SaveUserMemoryRequest = {
      content: content,
      triggerSource: MemoryTriggerSource.USER_CLICK,
      contentType: MemoryContentType.MESSAGE,
      sessionId: sessionId,
      messageId: messageId,
      originalContext: content
    };

    return await this.saveUserMemory(request);
  }

  /**
   * 生成记忆标题
   */
  private generateTitle(content: string): string {
    const maxLength = this.userMemoryConfig.maxTitleLength;

    // 如果内容较短，直接使用内容作为标题
    if (content.length <= maxLength) {
      return content;
    }

    // 尝试找到合适的截断点
    const sentences = content.split(/[。！？.!?]/);
    if (sentences.length > 1 && sentences[0].length <= maxLength) {
      return sentences[0];
    }

    // 按词截断
    const words = content.split(/\s+/);
    let title = '';
    for (const word of words) {
      if (title.length + word.length + 1 <= maxLength) {
        title += (title ? ' ' : '') + word;
      } else {
        break;
      }
    }

    // 如果还是太长，直接截断
    if (!title || title.length === 0) {
      title = content.substring(0, maxLength - 3) + '...';
    }

    return title;
  }

  /**
   * 推断内容类型
   */
  private inferContentType(content: string): MemoryContentType {
    // 检测代码特征
    const codePatterns = [
      /```[\s\S]*?```/,  // 代码块
      /`[^`]+`/,         // 行内代码
      /function\s+\w+/,  // JavaScript函数
      /def\s+\w+/,       // Python函数
      /class\s+\w+/,     // 类定义
      /import\s+/,       // 导入语句
      /console\.log/,    // 控制台输出
      /print\s*\(/       // 打印函数
    ];

    for (const pattern of codePatterns) {
      if (pattern.test(content)) {
        return MemoryContentType.CODE;
      }
    }

    // 如果包含问答格式，可能是对话
    if (content.includes('问：') || content.includes('答：') ||
        content.includes('Q:') || content.includes('A:')) {
      return MemoryContentType.CONVERSATION;
    }

    // 默认为文本
    return MemoryContentType.TEXT;
  }

  /**
   * 推断记忆分类
   */
  private inferCategory(content: string): MemoryCategory {
    const lowerContent = content.toLowerCase();

    // 个人信息关键词
    const personalKeywords = ['我叫', '我是', '我的名字', '我的生日', '我住在', '我来自'];
    if (personalKeywords.some(keyword => lowerContent.includes(keyword))) {
      return MemoryCategory.PERSONAL;
    }

    // 偏好关键词
    const preferenceKeywords = ['我喜欢', '我不喜欢', '我爱', '我讨厌', '我偏好', '我习惯'];
    if (preferenceKeywords.some(keyword => lowerContent.includes(keyword))) {
      return MemoryCategory.PREFERENCE;
    }

    // 工作关键词
    const workKeywords = ['工作', '公司', '职位', '同事', '项目', '会议', '职业'];
    if (workKeywords.some(keyword => lowerContent.includes(keyword))) {
      return MemoryCategory.WORK;
    }

    // 学习关键词
    const studyKeywords = ['学习', '课程', '考试', '学校', '教程', '培训'];
    if (studyKeywords.some(keyword => lowerContent.includes(keyword))) {
      return MemoryCategory.STUDY;
    }

    // 家庭关键词
    const familyKeywords = ['家人', '父母', '妻子', '丈夫', '孩子', '家庭'];
    if (familyKeywords.some(keyword => lowerContent.includes(keyword))) {
      return MemoryCategory.FAMILY;
    }

    // 健康关键词
    const healthKeywords = ['健康', '医生', '药物', '运动', '锻炼', '饮食'];
    if (healthKeywords.some(keyword => lowerContent.includes(keyword))) {
      return MemoryCategory.HEALTH;
    }

    // 爱好关键词
    const hobbyKeywords = ['爱好', '兴趣', '娱乐', '游戏', '电影', '音乐', '阅读'];
    if (hobbyKeywords.some(keyword => lowerContent.includes(keyword))) {
      return MemoryCategory.HOBBY;
    }

    // 默认为自定义
    return MemoryCategory.CUSTOM;
  }

  /**
   * 建议标签
   */
  private suggestTags(content: string): string[] {
    const tags: string[] = [];
    const lowerContent = content.toLowerCase();

    // 基于关键词的标签建议
    const tagMap: Record<string, string[]> = {
      '工作': ['工作', '职业'],
      '学习': ['学习', '教育'],
      '家庭': ['家庭', '亲情'],
      '健康': ['健康', '医疗'],
      '爱好': ['爱好', '兴趣'],
      '旅行': ['旅行', '出行'],
      '美食': ['美食', '饮食'],
      '运动': ['运动', '健身'],
      '音乐': ['音乐', '娱乐'],
      '电影': ['电影', '娱乐'],
      '阅读': ['阅读', '学习'],
      '编程': ['编程', '技术'],
      '技术': ['技术', '工作']
    };

    Object.entries(tagMap).forEach((entry: [string, string[]]) => {
      const keyword = entry[0];
      const suggestedTags = entry[1];
      if (lowerContent.includes(keyword)) {
        suggestedTags.forEach(tag => {
          if (!tags.includes(tag)) {
            tags.push(tag);
          }
        });
      }
    });

    // 限制标签数量
    return tags.slice(0, 5);
  }

  /**
   * 获取支持的记忆指令列表
   */
  getSupportedCommands(): MemoryCommand[] {
    const result: MemoryCommand[] = [];
    for (let i = 0; i < this.supportedCommands.length; i++) {
      result.push(this.supportedCommands[i]);
    }
    return result;
  }

  /**
   * 获取用户记忆配置
   */
  getUserMemoryConfig(): UserMemoryManagerConfig {
    return {
      autoGenerateTitle: this.userMemoryConfig.autoGenerateTitle,
      maxTitleLength: this.userMemoryConfig.maxTitleLength,
      defaultCategory: this.userMemoryConfig.defaultCategory,
      defaultImportance: this.userMemoryConfig.defaultImportance,
      enableTagSuggestion: this.userMemoryConfig.enableTagSuggestion,
      maxRecentMemories: this.userMemoryConfig.maxRecentMemories,
      enableExportImport: this.userMemoryConfig.enableExportImport
    };
  }

  /**
   * 更新用户记忆配置
   */
  updateUserMemoryConfig(config: Partial<UserMemoryManagerConfig>): void {
    if (config.autoGenerateTitle !== undefined) {
      this.userMemoryConfig.autoGenerateTitle = config.autoGenerateTitle;
    }
    if (config.maxTitleLength !== undefined) {
      this.userMemoryConfig.maxTitleLength = config.maxTitleLength;
    }
    if (config.defaultCategory !== undefined) {
      this.userMemoryConfig.defaultCategory = config.defaultCategory;
    }
    if (config.defaultImportance !== undefined) {
      this.userMemoryConfig.defaultImportance = config.defaultImportance;
    }
    if (config.enableTagSuggestion !== undefined) {
      this.userMemoryConfig.enableTagSuggestion = config.enableTagSuggestion;
    }
    if (config.maxRecentMemories !== undefined) {
      this.userMemoryConfig.maxRecentMemories = config.maxRecentMemories;
    }
    if (config.enableExportImport !== undefined) {
      this.userMemoryConfig.enableExportImport = config.enableExportImport;
    }
    Logger.info('MemoryManager', '用户记忆配置已更新');
  }

}