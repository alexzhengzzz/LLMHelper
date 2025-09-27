import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  JSONSchema,
  ParamType
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';
import { MemoryManager } from '../utils/MemoryManager';

interface MemoryToolJSONSchema extends JSONSchema {
  type: string;
  required: Array<string>;
}

/**
 * 记忆搜索工具类
 * 允许AI主动搜索用户的长期记忆
 */
export class MemoryTool {
  private static instance: MemoryTool | null = null;
  private memoryManager: MemoryManager;

  private constructor() {
    this.memoryManager = MemoryManager.getInstance();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): MemoryTool {
    if (!MemoryTool.instance) {
      MemoryTool.instance = new MemoryTool();
    }
    return MemoryTool.instance;
  }

  /**
   * 获取记忆搜索工具定义
   */
  getToolDefinition(): MCPTool {
    const semanticQuerySchema: JSONSchema = {
      type: 'string',
      description: "一个详细的问题或描述，用于在用户记忆中进行语义搜索。例如：'用户对编程语言有什么偏好？'或'用户上次提到的关于周末计划的内容'",
      minLength: 1,
      maxLength: 200
    };

    const keywordsSchema: JSONSchema = {
      type: 'string',
      description: "从语义查询中提炼出的1-3个核心关键词，以空格分隔。例如：'编程语言 偏好' 或 '周末计划'",
      minLength: 1,
      maxLength: 50
    };

    const properties: Record<string, JSONSchema> = {} as Record<string, JSONSchema>;
    properties.semantic_query = semanticQuerySchema;
    properties.keywords = keywordsSchema;

    const schema: MemoryToolJSONSchema = {
      type: 'object',
      properties: properties,
      required: ['semantic_query', 'keywords']
    };

    const toolDefinition: MCPTool = {
      name: 'search_user_memories',
      description: '在需要回忆用户的个人信息、偏好或历史对话时使用此工具。请同时提供详细的`semantic_query`和精简的`keywords`以获得最佳搜索结果。',
      inputSchema: schema
    };
    return toolDefinition;
  }

  /**
   * 执行记忆搜索
   */
  async execute(request: ToolCallRequest): Promise<ToolCallResult> {
    try {
      const args = request.arguments as ParamType;
      const semanticQuery = args.semantic_query as string;
      const keywords = args.keywords as string;

      if (!semanticQuery || !keywords || typeof semanticQuery !== 'string' || typeof keywords !== 'string' || semanticQuery.trim().length === 0 || keywords.trim().length === 0) {
        throw new Error('语义查询和关键词均不能为空');
      }

      const trimmedSemanticQuery = semanticQuery.trim();
      const trimmedKeywords = keywords.trim();
      Logger.info('MemoryTool', `搜索用户记忆，语义查询: "${trimmedSemanticQuery}", 关键词: "${trimmedKeywords}"`);

      // 使用MemoryManager搜索记忆，传入两个参数
      const searchResults = await this.memoryManager.searchMemories(trimmedSemanticQuery, trimmedKeywords);

      if (searchResults.length === 0) {
        const noResultsResult: ToolCallResult = {
          content: [{
            type: 'text',
            text: `未找到与"${trimmedKeywords}"相关的记忆内容。用户可能还没有保存相关的记忆信息。`
          }]
        };
        return noResultsResult;
      }

      // 格式化搜索结果
      const formattedMemories = searchResults.map((memory, index) => {
        const categoryText = this.getCategoryDisplayName(memory.category);
        const importanceText = this.getImportanceDisplayName(memory.importance);
        const usageInfo = memory.usageCount > 0 ? `（已使用${memory.usageCount}次）` : '';
        const tagsText = memory.tags.length > 0 ? `\n标签: ${memory.tags.join(', ')}` : '';

        return `${index + 1}. [${categoryText}·${importanceText}] ${memory.content}${usageInfo}${tagsText}`;
      }).join('\n\n');

      // 更新记忆使用统计
      for (const memory of searchResults) {
        await this.memoryManager.incrementUsageCount(memory.id);
      }

      const successResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `找到 ${searchResults.length} 条与"${trimmedKeywords}"相关的记忆：\n\n${formattedMemories}`
        }]
      };

      Logger.info('MemoryTool', `成功搜索到 ${searchResults.length} 条记忆`);
      return successResult;

    } catch (error) {
      Logger.error('MemoryTool', '记忆搜索失败', error);
      const errorResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `记忆搜索失败：${error instanceof Error ? error.message : '未知错误'}`
        }],
        isError: true
      };
      return errorResult;
    }
  }

  /**
   * 获取分类显示名称
   */
  private getCategoryDisplayName(category: string): string {
    const categoryMap: Record<string, string> = {
      'personal': '个人',
      'preference': '偏好',
      'work': '工作',
      'study': '学习',
      'hobby': '爱好',
      'family': '家庭',
      'health': '健康',
      'custom': '自定义'
    };
    return categoryMap[category] || category;
  }

  /**
   * 获取重要性显示名称
   */
  private getImportanceDisplayName(importance: string): string {
    const importanceMap: Record<string, string> = {
      'low': '低',
      'medium': '中',
      'high': '高',
      'critical': '重要'
    };
    return importanceMap[importance] || importance;
  }
}

export default MemoryTool;