/**
 * 消息增强器
 * 将搜索结果整合到用户消息中
 */

import { Logger } from '../utils/Logger';
import { SearchResponse, SearchResult } from '../clients/SearchAPIClient';
import { SearchDecision, SearchCategory } from './SearchDecisionEngine';

/**
 * 增强后的消息结果
 */
export interface EnhancedMessage {
  originalMessage: string;
  enhancedMessage: string;
  searchUsed: boolean;
  searchInfo?: SearchInfo;
}

/**
 * 搜索信息
 */
export interface SearchInfo {
  query: string;
  provider?: string;
  resultCount: number;
  searchTime?: number;
  category: SearchCategory;
  sources: SearchSource[];
}

/**
 * 搜索来源
 */
export interface SearchSource {
  title: string;
  url: string;
  snippet: string;
}

/**
 * 搜索结果验证结果
 */
export interface ValidationResult {
  isValid: boolean;
  validCount: number;
  issues: string[];
}

export class MessageEnhancer {
  private static instance: MessageEnhancer;

  private constructor() {}

  static getInstance(): MessageEnhancer {
    if (!MessageEnhancer.instance) {
      MessageEnhancer.instance = new MessageEnhancer();
    }
    return MessageEnhancer.instance;
  }

  /**
   * 增强用户消息，将搜索结果整合到消息中
   */
  enhanceMessage(
    originalMessage: string,
    searchResponse: SearchResponse,
    searchDecision: SearchDecision
  ): EnhancedMessage {
    Logger.info('MessageEnhancer', `=== 消息增强开始 ===`);
    Logger.info('MessageEnhancer', `原始消息: "${originalMessage}"`);
    Logger.info('MessageEnhancer', `搜索成功: ${searchResponse.success}`);
    Logger.info('MessageEnhancer', `搜索结果数量: ${searchResponse.results.length}`);

    if (!searchResponse.success || searchResponse.results.length === 0) {
      // 搜索失败或无结果，返回原始消息
      const result: EnhancedMessage = {
        originalMessage,
        enhancedMessage: originalMessage,
        searchUsed: false
      };
      Logger.info('MessageEnhancer', `搜索失败或无结果，返回原始消息`);
      return result;
    }

    // 构建搜索信息
    const sources = searchResponse.results.slice(0, 5).map(result => {
      const source: SearchSource = {
        title: result.title,
        url: result.url,
        snippet: result.snippet
      };
      return source;
    });
    
    Logger.info('MessageEnhancer', `搜索结果数量: ${searchResponse.results.length}`);
    Logger.info('MessageEnhancer', `选择的来源数量: ${sources.length}`);
    if (sources.length > 0) {
      Logger.info('MessageEnhancer', `第一个来源标题: ${sources[0].title}`);
      Logger.info('MessageEnhancer', `第一个来源URL: ${sources[0].url}`);
      Logger.info('MessageEnhancer', `第一个来源摘要: ${sources[0].snippet.substring(0, 50)}...`);
    }
    
    const searchInfo: SearchInfo = {
      query: searchResponse.query,
      provider: searchResponse.provider,
      resultCount: searchResponse.results.length,
      searchTime: searchResponse.search_time,
      category: searchDecision.category,
      sources: sources
    };

    // 生成增强消息
    const enhancedMessage = this.generateEnhancedMessage(
      originalMessage,
      searchResponse.results,
      searchDecision
    );

    const result: EnhancedMessage = {
      originalMessage,
      enhancedMessage,
      searchUsed: true,
      searchInfo
    };

    Logger.info('MessageEnhancer', `=== 消息增强完成 ===`);
    Logger.info('MessageEnhancer', `增强消息长度: ${enhancedMessage.length}字符`);
    Logger.info('MessageEnhancer', `搜索来源数量: ${searchInfo.sources.length}`);
    Logger.info('MessageEnhancer', `搜索类别: ${searchInfo.category}`);

    return result;
  }

  /**
   * 生成增强消息
   */
  private generateEnhancedMessage(
    originalMessage: string,
    searchResults: SearchResult[],
    searchDecision: SearchDecision
  ): string {
    Logger.info('MessageEnhancer', '生成增强消息');

    // 选择最相关的搜索结果（前3-5个）
    const relevantResults = this.selectRelevantResults(searchResults, searchDecision.category);
    
    // 构建搜索上下文
    const searchContext = this.buildSearchContext(relevantResults, searchDecision);
    
    // 组合原始消息和搜索上下文
    const enhancedMessage = `${originalMessage}

[网络搜索结果]
${searchContext}

请基于以上网络搜索结果和你的知识来回答我的问题。如果搜索结果与问题相关，请重点参考这些最新信息。`;

    Logger.info('MessageEnhancer', `生成的增强消息字符数: ${enhancedMessage.length}`);
    return enhancedMessage;
  }

  /**
   * 选择最相关的搜索结果
   */
  private selectRelevantResults(searchResults: SearchResult[], category: SearchCategory): SearchResult[] {
    Logger.info('MessageEnhancer', `从${searchResults.length}个结果中选择相关结果`);

    let maxResults = 3; // 默认选择3个结果
    
    // 根据搜索类别调整选择数量
    switch (category) {
      case SearchCategory.REAL_TIME:
      case SearchCategory.NEWS:
        maxResults = 4; // 实时信息和新闻需要更多结果
        break;
      case SearchCategory.TECHNICAL:
        maxResults = 3; // 技术查询通常需要精确信息
        break;
      case SearchCategory.CURRENT_AFFAIRS:
      case SearchCategory.FACTUAL:
        maxResults = 3;
        break;
      default:
        maxResults = 3;
    }

    // 过滤掉内容过短的结果
    const validResults = searchResults.filter(result => 
      result.title && result.title.length > 5 &&
      result.snippet && result.snippet.length > 20
    );

    // 选择前N个结果
    const selectedResults = validResults.slice(0, maxResults);
    
    Logger.info('MessageEnhancer', `选择了${selectedResults.length}个相关结果`);
    return selectedResults;
  }

  /**
   * 构建搜索上下文（用于AI模型）
   */
  private buildSearchContext(searchResults: SearchResult[], searchDecision: SearchDecision): string {
    Logger.info('MessageEnhancer', '构建搜索上下文');

    if (searchResults.length === 0) {
      return '暂无相关搜索结果。';
    }

    const contextParts: string[] = [];
    
    // 添加搜索摘要
    const summaryLine = `搜索关键词: "${searchDecision.keywords.join(', ')}" | 搜索类别: ${this.getCategoryDisplayName(searchDecision.category)} | 结果数量: ${searchResults.length}`;
    contextParts.push(summaryLine);
    contextParts.push('');

    // 添加每个搜索结果
    searchResults.forEach((result, index) => {
      const resultNumber = index + 1;
      const title = this.cleanText(result.title);
      const snippet = this.cleanText(result.snippet);
      const url = result.url;

      const resultBlock = `${resultNumber}. ${title}
   摘要: ${snippet}
   来源: ${url}`;
      
      contextParts.push(resultBlock);
      
      // 在结果之间添加分隔线
      if (index < searchResults.length - 1) {
        contextParts.push('');
      }
    });

    const context = contextParts.join('\n');
    Logger.info('MessageEnhancer', `构建的搜索上下文字符数: ${context.length}`);
    
    return context;
  }

  /**
   * 构建用户界面搜索详情（用于气泡显示）
   */
  buildUserSearchDetails(searchInfo: SearchInfo): string {
    Logger.info('MessageEnhancer', '构建用户界面搜索详情');
    Logger.info('MessageEnhancer', `搜索详情来源数量: ${searchInfo.sources.length}`);

    const detailsParts: string[] = [];
    
    // 添加搜索基本信息
    detailsParts.push('🔍 网络搜索详情');
    detailsParts.push('');
    
    // 搜索引擎和查询
    detailsParts.push(`📊 搜索引擎: ${searchInfo.provider || '默认'}`);
    detailsParts.push(`🔎 搜索查询: "${searchInfo.query}"`);
    detailsParts.push(`📂 搜索类别: ${this.getCategoryDisplayName(searchInfo.category)}`);
    detailsParts.push(`📈 结果数量: ${searchInfo.resultCount}`);
    
    if (searchInfo.searchTime) {
      detailsParts.push(`⏱️ 搜索耗时: ${searchInfo.searchTime}ms`);
    }
    
    detailsParts.push('');
    detailsParts.push('📋 搜索来源:');
    detailsParts.push('');

    // 添加搜索来源
    Logger.info('MessageEnhancer', `开始处理搜索来源，数量: ${searchInfo.sources.length}`);
    searchInfo.sources.forEach((source, index) => {
      const sourceNumber = index + 1;
      const title = this.cleanText(source.title);
      const snippet = this.cleanText(source.snippet);
      const url = source.url;
      
      Logger.info('MessageEnhancer', `处理来源${index + 1}: ${title.substring(0, 30)}..., URL: ${url.substring(0, 50)}...`);

      const sourceBlock = `${sourceNumber}. ${title}
   📝 ${snippet}
   🔗 ${url}`;
      
      detailsParts.push(sourceBlock);
      
      // 在来源之间添加分隔线
      if (index < searchInfo.sources.length - 1) {
        detailsParts.push('');
      }
    });

    const details = detailsParts.join('\n');
    Logger.info('MessageEnhancer', `构建的搜索详情字符数: ${details.length}`);
    
    return details;
  }

  /**
   * 构建简化搜索信息（用于主消息显示）
   */
  buildSimpleSearchInfo(searchInfo: SearchInfo): string {
    const parts: string[] = [];
    parts.push('🔍 网络搜索');
    
    if (searchInfo.searchTime) {
      parts.push(`⏱️ ${searchInfo.searchTime}ms`);
    }
    
    parts.push(`📊 ${searchInfo.resultCount}个结果`);
    
    return parts.join(' | ');
  }

  /**
   * 清理文本内容
   */
  private cleanText(text: string): string {
    if (!text) return '';
    
    return text
      .replace(/\s+/g, ' ') // 多个空白字符替换为单个空格
      .replace(/\n/g, ' ') // 换行符替换为空格
      .trim(); // 去除首尾空白
  }

  /**
   * 获取搜索类别显示名称
   */
  private getCategoryDisplayName(category: SearchCategory): string {
    const displayNames: Record<SearchCategory, string> = {
      [SearchCategory.REAL_TIME]: '实时信息',
      [SearchCategory.TECHNICAL]: '技术查询',
      [SearchCategory.NEWS]: '新闻事件',
      [SearchCategory.CURRENT_AFFAIRS]: '时事信息',
      [SearchCategory.FACTUAL]: '事实查询',
      [SearchCategory.NONE]: '无'
    };
    
    return displayNames[category] || '未知';
  }

  /**
   * 创建搜索失败时的增强消息
   */
  createFailureMessage(originalMessage: string, reason: string): EnhancedMessage {
    Logger.info('MessageEnhancer', `创建搜索失败消息: ${reason}`);
    
    return {
      originalMessage,
      enhancedMessage: originalMessage, // 搜索失败时保持原始消息
      searchUsed: false
    };
  }

  /**
   * 验证搜索结果的质量
   */
  validateSearchResults(searchResults: SearchResult[]): ValidationResult {
    const issues: string[] = [];
    let validCount = 0;

    if (!searchResults || searchResults.length === 0) {
      issues.push('搜索结果为空');
      return { isValid: false, validCount: 0, issues };
    }

    for (let i = 0; i < searchResults.length; i++) {
      const result = searchResults[i];
      let isResultValid = true;

      if (!result.title || result.title.trim().length === 0) {
        issues.push(`结果${i + 1}: 标题为空`);
        isResultValid = false;
      }

      if (!result.snippet || result.snippet.trim().length < 10) {
        issues.push(`结果${i + 1}: 摘要过短或为空`);
        isResultValid = false;
      }

      if (!result.url || !this.isValidUrl(result.url)) {
        issues.push(`结果${i + 1}: URL无效`);
        isResultValid = false;
      }

      if (isResultValid) {
        validCount++;
      }
    }

    const isValid = validCount > 0;
    Logger.info('MessageEnhancer', `搜索结果验证: ${isValid ? '通过' : '失败'}, 有效结果: ${validCount}/${searchResults.length}`);

    const result: ValidationResult = { isValid, validCount, issues };
    return result;
  }

  /**
   * 验证URL格式
   */
  private isValidUrl(url: string): boolean {
    try {
      // 简单的URL格式验证
      return url.startsWith('http://') || url.startsWith('https://');
    } catch {
      return false;
    }
  }
}