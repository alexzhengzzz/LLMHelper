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
    const querySchema: JSONSchema = {
      type: 'string',
      description: '搜索关键词，用于在用户的长期记忆中查找相关内容。可以是任何与用户对话相关的词汇、概念或主题',
      minLength: 1,
      maxLength: 100
    };

    const properties: Record<string, JSONSchema> = {} as Record<string, JSONSchema>;
    properties.query = querySchema;

    const schema: MemoryToolJSONSchema = {
      type: 'object',
      properties: properties,
      required: ['query']
    };

    const toolDefinition: MCPTool = {
      name: 'search_memories',
      description: '【重要】在回答涉及用户个人信息、偏好设置、历史记录、个人习惯等问题前，必须先使用此工具搜索记忆！使用场景：用户名字、称呼、偏好、设置、历史对话、个人习惯、工作信息、家庭信息、学习偏好等任何需要个性化回答的问题。注意：基础问候和通用知识不需要搜索记忆。',
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
      const query = args.query as string;

      if (!query || typeof query !== 'string' || query.trim().length === 0) {
        throw new Error('搜索关键词不能为空');
      }

      const trimmedQuery = query.trim();
      Logger.info('MemoryTool', `搜索用户记忆，关键词: "${trimmedQuery}"`);

      // 使用MemoryManager搜索记忆
      const searchResults = await this.memoryManager.searchMemories(trimmedQuery);

      if (searchResults.length === 0) {
        const noResultsResult: ToolCallResult = {
          content: [{
            type: 'text',
            text: `未找到与"${trimmedQuery}"相关的记忆内容。用户可能还没有保存相关的记忆信息。`
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
          text: `找到 ${searchResults.length} 条与"${trimmedQuery}"相关的记忆：\n\n${formattedMemories}`
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