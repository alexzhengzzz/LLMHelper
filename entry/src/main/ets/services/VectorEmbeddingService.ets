import { VectorSearchConfig, VectorServiceStatus } from '../types/MemoryTypes';
import { Logger } from '../utils/Logger';
import { ApiService } from './ApiService';

/**
 * 向量化服务 - 调用后端API生成文本向量
 * 实现高性能的语义搜索和相似度计算
 */
export class VectorEmbeddingService {
  private static instance: VectorEmbeddingService | null = null;
  private config: VectorSearchConfig;
  private apiService: ApiService;
  private isInitialized: boolean = false;
  private totalEmbeddings: number = 0;
  private totalGenerationTime: number = 0;

  private constructor() {
    this.config = {
      enabled: true,
      hybridSearch: true,
      vectorWeight: 0.8,    // 提高向量权重，强调语义搜索
      keywordWeight: 0.2,   // 降低关键词权重，减少关键词影响
      minSimilarity: 0.4,  // 提高相似度阈值，确保语义相关性
      maxResults: 10
    };
    this.apiService = new ApiService();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): VectorEmbeddingService {
    if (!VectorEmbeddingService.instance) {
      VectorEmbeddingService.instance = new VectorEmbeddingService();
    }
    return VectorEmbeddingService.instance;
  }

  /**
   * 初始化向量化服务
   */
  async initialize(): Promise<boolean> {
    try {
      Logger.info('VectorEmbeddingService', '正在初始化向量化服务...');

      // 测试API连接
      const isConnected = await this.apiService.testConnection();
      if (!isConnected) {
        Logger.warn('VectorEmbeddingService', 'API连接测试失败，服务可能不可用');
        return false;
      }

      this.isInitialized = true;
      Logger.info('VectorEmbeddingService', '向量化服务初始化成功');
      return true;

    } catch (error) {
      Logger.error('VectorEmbeddingService', `向量化服务初始化失败: ${error}`);
      return false;
    }
  }

  /**
   * 生成文本向量 - 调用后端API
   */
  async generateEmbedding(text: string): Promise<number[] | null> {
    try {
      if (!this.isInitialized) {
        Logger.warn('VectorEmbeddingService', '向量化服务未初始化');
        return null;
      }

      const startTime = Date.now();

      // 调用后端API生成向量
      const vector = await this.apiService.generateEmbedding(text);

      const generationTime = Date.now() - startTime;

      // 更新统计信息
      this.totalEmbeddings++;
      this.totalGenerationTime += generationTime;

      // 输出详细的向量信息日志
      Logger.info('VectorEmbeddingService',
        `生成向量完成 - 文本: "${text.substring(0, 50)}${text.length > 50 ? '...' : ''}"`);
      Logger.info('VectorEmbeddingService',
        `向量详情 - 维度: ${vector.length}, 耗时: ${generationTime}ms`);
      Logger.info('VectorEmbeddingService',
        `向量前10个值: [${vector.slice(0, 10).map(v => v.toFixed(4)).join(', ')}]`);
      Logger.info('VectorEmbeddingService',
        `向量统计 - 最小值: ${Math.min(...vector).toFixed(4)}, 最大值: ${Math.max(...vector).toFixed(4)}`);
      Logger.info('VectorEmbeddingService',
        `向量统计 - 平均值: ${(vector.reduce((a, b) => a + b, 0) / vector.length).toFixed(4)}`);
      Logger.info('VectorEmbeddingService',
        `累计生成向量总数: ${this.totalEmbeddings}, 平均耗时: ${(this.totalGenerationTime / this.totalEmbeddings).toFixed(2)}ms`);

      return vector;

    } catch (error) {
      Logger.error('VectorEmbeddingService', `生成向量失败: ${error}`);
      return null;
    }
  }

  /**
   * 批量生成向量
   */
  async generateEmbeddings(texts: string[]): Promise<(number[] | null)[]> {
    if (!this.isInitialized) {
      Logger.warn('VectorEmbeddingService', '向量嵌入服务未初始化');
      return texts.map(() => null);
    }

    try {
      const startTime = Date.now();

      // 批量生成向量
      const promises = texts.map(text => this.generateEmbedding(text));
      const embeddings = await Promise.all(promises);

      const generationTime = Date.now() - startTime;

      Logger.info('VectorEmbeddingService',
        `批量生成向量完成，数量: ${embeddings.length}，耗时: ${generationTime}ms`);

      return embeddings;

    } catch (error) {
      Logger.error('VectorEmbeddingService', `批量生成向量失败: ${error}`);
      return texts.map(() => null);
    }
  }

  /**
   * 计算余弦相似度
   */
  calculateCosineSimilarity(vector1: number[], vector2: number[]): number {
    if (vector1.length !== vector2.length) {
      Logger.warn('VectorEmbeddingService', '向量维度不匹配');
      return 0;
    }

    let dotProduct = 0;
    let norm1 = 0;
    let norm2 = 0;

    for (let i = 0; i < vector1.length; i++) {
      dotProduct += vector1[i] * vector2[i];
      norm1 += vector1[i] * vector1[i];
      norm2 += vector2[i] * vector2[i];
    }

    if (norm1 === 0 || norm2 === 0) {
      return 0;
    }

    return dotProduct / (Math.sqrt(norm1) * Math.sqrt(norm2));
  }

  /**
   * 计算关键词匹配分数
   */
  calculateKeywordScore(text: string, keywords: string[]): number {
    if (!keywords || keywords.length === 0) {
      return 0;
    }

    const lowerText = text.toLowerCase();
    let matchCount = 0;

    keywords.forEach(keyword => {
      if (lowerText.includes(keyword.toLowerCase())) {
        matchCount++;
      }
    });

    return matchCount / keywords.length;
  }

  /**
   * 获取服务状态
   */
  getStatus(): VectorServiceStatus {
    return {
      modelLoaded: this.isInitialized,
      modelName: 'BGE-Small-ZH-v1.5',
      embeddingDimension: 512, // BGE-small-zh-v1.5模型的实际维度
      totalEmbeddings: this.totalEmbeddings,
      averageGenerationTime: this.totalEmbeddings > 0 ?
        this.totalGenerationTime / this.totalEmbeddings : 0
    };
  }

  /**
   * 更新搜索配置
   */
  updateConfig(config: Partial<VectorSearchConfig>): void {
    const newConfig: VectorSearchConfig = {
      enabled: config.enabled !== undefined ? config.enabled : this.config.enabled,
      hybridSearch: config.hybridSearch !== undefined ? config.hybridSearch : this.config.hybridSearch,
      vectorWeight: config.vectorWeight !== undefined ? config.vectorWeight : this.config.vectorWeight,
      keywordWeight: config.keywordWeight !== undefined ? config.keywordWeight : this.config.keywordWeight,
      minSimilarity: config.minSimilarity !== undefined ? config.minSimilarity : this.config.minSimilarity,
      maxResults: config.maxResults !== undefined ? config.maxResults : this.config.maxResults
    };
    this.config = newConfig;
    Logger.info('VectorEmbeddingService', '向量搜索配置已更新', JSON.stringify(this.config));
  }

  /**
   * 获取当前配置
   */
  getConfig(): VectorSearchConfig {
    return {
      enabled: this.config.enabled,
      hybridSearch: this.config.hybridSearch,
      vectorWeight: this.config.vectorWeight,
      keywordWeight: this.config.keywordWeight,
      minSimilarity: this.config.minSimilarity,
      maxResults: this.config.maxResults
    };
  }

  /**
   * 检查服务是否就绪
   */
  isReady(): boolean {
    return this.isInitialized;
  }

  /**
   * 重置统计信息
   */
  resetStats(): void {
    this.totalEmbeddings = 0;
    this.totalGenerationTime = 0;
    Logger.info('VectorEmbeddingService', '统计信息已重置');
  }
}

export default VectorEmbeddingService;