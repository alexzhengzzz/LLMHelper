/**
 * 内容压缩服务 - 优化深度思考消息传递
 */

import { Logger } from '../utils/Logger';

// 压缩配置
interface CompressionConfig {
  maxSummaryLength: number;    // 最大摘要长度
  keyInsightsCount: number;    // 关键洞察数量
  compressionRatio: number;    // 压缩比例
}

// 步骤数据接口
interface StepData {
  content: string;
  type: string;
}

// 结构化思考内容
export interface StructuredContent {
  keyInsights: string[];       // 关键洞察
  conclusion: string;          // 核心结论
  context: string;            // 必要上下文
}

/**
 * 内容压缩器
 */
export class ContentCompressor {
  private static instance: ContentCompressor;
  private config: CompressionConfig;

  private constructor() {
    this.config = {
      maxSummaryLength: 300,     // 摘要最多300字
      keyInsightsCount: 3,       // 提取3个关键洞察
      compressionRatio: 0.25     // 压缩到原内容的25%
    };
  }

  public static getInstance(): ContentCompressor {
    if (!ContentCompressor.instance) {
      ContentCompressor.instance = new ContentCompressor();
    }
    return ContentCompressor.instance;
  }

  /**
   * 压缩思考步骤内容
   */
  compressStepContent(content: string, stepType: string): StructuredContent {
    Logger.debug('ContentCompressor', `压缩${stepType}内容，原长度: ${content.length}`);
    
    const keyInsights = this.extractKeyInsights(content, stepType);
    const conclusion = this.extractConclusion(content, stepType);
    const context = this.extractContext(content, stepType);
    
    const result: StructuredContent = {
      keyInsights,
      conclusion,
      context
    };
    
    const compressedSize = JSON.stringify(result).length;
    Logger.debug('ContentCompressor', `压缩完成，压缩后长度: ${compressedSize}, 压缩比: ${(compressedSize/content.length*100).toFixed(1)}%`);
    
    return result;
  }

  /**
   * 提取关键洞察
   */
  private extractKeyInsights(content: string, stepType: string): string[] {
    const insights: string[] = [];
    
    // 根据不同步骤类型使用不同的提取策略
    switch (stepType) {
      case 'analyze':
        insights.push(...this.extractAnalysisInsights(content));
        break;
      case 'think':
        insights.push(...this.extractThinkingInsights(content));
        break;
      case 'verify':
        insights.push(...this.extractVerificationInsights(content));
        break;
      default:
        insights.push(...this.extractGenericInsights(content));
    }
    
    return insights.slice(0, this.config.keyInsightsCount);
  }

  /**
   * 提取分析步骤的关键洞察
   */
  private extractAnalysisInsights(content: string): string[] {
    const insights: string[] = [];
    
    // 寻找核心要点标记
    const corePointMarkers = ['核心要点', '关键因素', '主要问题', '核心问题'];
    for (const marker of corePointMarkers) {
      const match = content.match(new RegExp(`${marker}[：:]([^\\n]{1,100})`, 'g'));
      if (match) {
        const mapped = match.map(m => m.replace(/.*?[：:]/, '').trim());
        for (const item of mapped) {
          insights.push(item);
        }
      }
    }
    
    // 提取编号列表项
    const listItems = content.match(/[1-9]\.\s*([^\\n]{20,100})/g);
    if (listItems) {
      const mapped = listItems.map(item => item.replace(/^[1-9]\.\s*/, '')).slice(0, 2);
      for (const item of mapped) {
        insights.push(item);
      }
    }
    
    return insights;
  }

  /**
   * 提取思考步骤的关键洞察
   */
  private extractThinkingInsights(content: string): string[] {
    const insights: string[] = [];
    
    // 寻找解决方案和观点
    const solutionMarkers = ['解决方案', '方法', '建议', '策略', '观点'];
    for (const marker of solutionMarkers) {
      const match = content.match(new RegExp(`${marker}[：:]([^\\n]{1,100})`, 'g'));
      if (match) {
        const mapped = match.map(m => m.replace(/.*?[：:]/, '').trim());
        for (const item of mapped) {
          insights.push(item);
        }
      }
    }
    
    // 提取要点
    const bulletPoints = content.match(/[-*•]\s*([^\\n]{20,100})/g);
    if (bulletPoints) {
      const mapped = bulletPoints.map(point => point.replace(/^[-*•]\s*/, '')).slice(0, 2);
      for (const item of mapped) {
        insights.push(item);
      }
    }
    
    return insights;
  }

  /**
   * 提取验证步骤的关键洞察
   */
  private extractVerificationInsights(content: string): string[] {
    const insights: string[] = [];
    
    // 寻找问题和风险
    const issueMarkers = ['问题', '风险', '漏洞', '不足', '质疑', '局限'];
    for (const marker of issueMarkers) {
      const match = content.match(new RegExp(`${marker}[：:]([^\\n]{1,100})`, 'g'));
      if (match) {
        const mapped = match.map(m => m.replace(/.*?[：:]/, '').trim());
        for (const item of mapped) {
          insights.push(item);
        }
      }
    }
    
    return insights;
  }

  /**
   * 通用洞察提取
   */
  private extractGenericInsights(content: string): string[] {
    const insights: string[] = [];
    
    // 提取句号结尾的完整句子，优先选择较短的
    const sentences = content.split(/[。！？]/).filter(s => s.trim().length > 10 && s.trim().length < 100);
    const selected = sentences.slice(0, 3);
    for (const sentence of selected) {
      insights.push(sentence);
    }
    
    return insights;
  }

  /**
   * 提取核心结论
   */
  private extractConclusion(content: string, stepType: string): string {
    // 寻找结论性语句
    const conclusionMarkers = ['总结', '结论', '综上', '因此', '所以', '总的来说'];
    
    for (const marker of conclusionMarkers) {
      const match = content.match(new RegExp(`${marker}[，：:]([^。！？]{10,200})[。！？]`));
      if (match) {
        return match[1].trim();
      }
    }
    
    // 如果没找到明确结论，取最后一段的关键句
    const paragraphs = content.split('\n').filter(p => p.trim().length > 20);
    if (paragraphs.length > 0) {
      const lastParagraph = paragraphs[paragraphs.length - 1];
      const sentences = lastParagraph.split(/[。！？]/).filter(s => s.trim().length > 10);
      if (sentences.length > 0) {
        return sentences[0].trim().substring(0, 100);
      }
    }
    
    return '';
  }

  /**
   * 提取必要上下文
   */
  private extractContext(content: string, stepType: string): string {
    // 保留少量关键上下文信息
    const contextLength = Math.min(50, Math.floor(content.length * 0.1));
    
    // 尝试找到首段的关键信息
    const firstParagraph = content.split('\n').find(p => p.trim().length > 20);
    if (firstParagraph && firstParagraph.length <= contextLength) {
      return firstParagraph.trim();
    }
    
    // 否则截取开头部分
    return content.substring(0, contextLength).trim() + '...';
  }

  /**
   * 构建压缩后的传递内容
   */
  buildCompressedPrompt(structuredContent: StructuredContent, stepType: string): string {
    const keyInsights = structuredContent.keyInsights;
    const conclusion = structuredContent.conclusion;
    const context = structuredContent.context;
    
    let compressed = '';
    
    if (context) {
      compressed += `背景: ${context}\n`;
    }
    
    if (keyInsights.length > 0) {
      compressed += `要点: ${keyInsights.join('; ')}\n`;
    }
    
    if (conclusion) {
      compressed += `结论: ${conclusion}`;
    }
    
    return compressed.trim();
  }

  /**
   * 批量压缩多个步骤内容
   */
  compressMultipleSteps(steps: StepData[]): string {
    const compressedSteps = steps.map((step, index) => {
      const structured = this.compressStepContent(step.content, step.type);
      const compressed = this.buildCompressedPrompt(structured, step.type);
      return `步骤${index + 1}: ${compressed}`;
    });
    
    return compressedSteps.join('\n\n');
  }

  /**
   * 更新压缩配置
   */
  updateConfig(newConfig: Partial<CompressionConfig>): void {
    if (newConfig.maxSummaryLength !== undefined) {
      this.config.maxSummaryLength = newConfig.maxSummaryLength;
    }
    if (newConfig.keyInsightsCount !== undefined) {
      this.config.keyInsightsCount = newConfig.keyInsightsCount;
    }
    if (newConfig.compressionRatio !== undefined) {
      this.config.compressionRatio = newConfig.compressionRatio;
    }
    Logger.info('ContentCompressor', '压缩配置已更新');
  }

  /**
   * 获取当前配置
   */
  getConfig(): CompressionConfig {
    return {
      maxSummaryLength: this.config.maxSummaryLength,
      keyInsightsCount: this.config.keyInsightsCount,
      compressionRatio: this.config.compressionRatio
    };
  }
}