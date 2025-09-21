import { common } from '@kit.AbilityKit';
import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  TextContent
} from '../types/MCPTypes';
import { LocalFileSystemTool } from './LocalFileSystemTool';
import { SystemInfoTool } from './SystemInfoTool';
import { Logger } from '../utils/Logger';
import { AppStorage } from '../utils/AppStorage';
import { ThemeManager } from '../utils/ThemeManager';

/**
 * 本地工具管理器
 * 管理和执行本地MCP工具
 */
export class LocalToolManager {
  private static instance: LocalToolManager | null = null;
  private fileSystemTool: LocalFileSystemTool;
  private systemInfoTool: SystemInfoTool;
  private registeredTools: Map<string, MCPTool> = new Map();
  private toolExecutors: Map<string, LocalToolExecutor> = new Map();

  private constructor(context: common.UIAbilityContext) {
    this.fileSystemTool = new LocalFileSystemTool(context);
    this.systemInfoTool = new SystemInfoTool(context);

    this.registerBuiltInTools();
    Logger.info('LocalToolManager', 'Local tool manager initialized');
  }

  /**
   * 获取单例实例
   */
  static getInstance(context?: common.UIAbilityContext): LocalToolManager {
    if (!LocalToolManager.instance) {
      if (!context) {
        throw new Error('Context is required for first initialization');
      }
      LocalToolManager.instance = new LocalToolManager(context);
    }
    return LocalToolManager.instance;
  }

  /**
   * 注册内置工具
   */
  private registerBuiltInTools(): void {
    // 注册文件系统工具
    const fileSystemTools = this.fileSystemTool.getTools();
    for (const tool of fileSystemTools) {
      this.registeredTools.set(tool.name, tool);
      this.toolExecutors.set(tool.name, {
        execute: (request: ToolCallRequest) => this.fileSystemTool.executeCall(request)
      });
    }

    // 注册系统信息工具
    const systemInfoTools = this.systemInfoTool.getTools();
    for (const tool of systemInfoTools) {
      this.registeredTools.set(tool.name, tool);
      this.toolExecutors.set(tool.name, {
        execute: (request: ToolCallRequest) => this.systemInfoTool.executeCall(request)
      });
    }

    // 注册应用管理工具
    this.registerAppManagementTools();

    Logger.info('LocalToolManager', `Registered ${this.registeredTools.size} built-in tools`);
  }

  /**
   * 注册应用管理工具
   */
  private registerAppManagementTools(): void {
    // 主题管理工具
    const themeTools: Array<MCPTool> = [
      {
        name: 'switch_theme',
        description: '切换应用主题',
        inputSchema: {
          type: 'object',
          properties: {
            theme: {
              type: 'string',
              enum: ['light', 'dark', 'auto'],
              description: '主题类型：light（浅色）、dark（深色）、auto（跟随系统）'
            }
          },
          required: ['theme']
        }
      },
      {
        name: 'get_theme_status',
        description: '获取当前主题状态',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      }
    ];

    // 字体设置工具
    const fontTools: Array<MCPTool> = [
      {
        name: 'update_font_settings',
        description: '更新字体设置',
        inputSchema: {
          type: 'object',
          properties: {
            chatFontSize: {
              type: 'number',
              minimum: 12,
              maximum: 20,
              description: '聊天字体大小 (12-20px)'
            },
            codeFontSize: {
              type: 'number',
              minimum: 10,
              maximum: 18,
              description: '代码字体大小 (10-18px)'
            },
            fontFamily: {
              type: 'string',
              enum: ['system', 'serif', 'monospace', 'rounded', 'elegant', 'playful', 'modern', 'classic'],
              description: '字体家族'
            }
          }
        }
      },
      {
        name: 'get_font_settings',
        description: '获取当前字体设置',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      }
    ];

    // 会话管理工具
    const sessionTools: Array<MCPTool> = [
      {
        name: 'get_session_count',
        description: '获取会话数量统计',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      },
      {
        name: 'clear_old_sessions',
        description: '清理旧会话（超过指定天数）',
        inputSchema: {
          type: 'object',
          properties: {
            days: {
              type: 'number',
              minimum: 1,
              description: '保留多少天内的会话',
              default: 30
            }
          }
        }
      }
    ];

    // 注册所有应用管理工具
    const allAppTools = [...themeTools, ...fontTools, ...sessionTools];
    for (const tool of allAppTools) {
      this.registeredTools.set(tool.name, tool);
      this.toolExecutors.set(tool.name, {
        execute: (request: ToolCallRequest) => this.executeAppManagementTool(request)
      });
    }
  }

  /**
   * 执行应用管理工具
   */
  private async executeAppManagementTool(request: ToolCallRequest): Promise<ToolCallResult> {
    try {
      switch (request.name) {
        case 'switch_theme':
          return await this.switchTheme(request.arguments);
        case 'get_theme_status':
          return await this.getThemeStatus();
        case 'update_font_settings':
          return await this.updateFontSettings(request.arguments);
        case 'get_font_settings':
          return await this.getFontSettings();
        case 'get_session_count':
          return await this.getSessionCount();
        case 'clear_old_sessions':
          return await this.clearOldSessions(request.arguments);
        default:
          throw new Error(`Unknown app management tool: ${request.name}`);
      }
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `应用管理工具执行失败: ${error instanceof Error ? error.message : '未知错误'}`
        }],
        isError: true
      };
    }
  }

  /**
   * 切换主题
   */
  private async switchTheme(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const theme = args.theme as string;

    try {
      switch (theme) {
        case 'light':
          ThemeManager.setTheme('light');
          break;
        case 'dark':
          ThemeManager.setTheme('dark');
          break;
        case 'auto':
          ThemeManager.setTheme('auto');
          break;
        default:
          throw new Error(`无效的主题类型: ${theme}`);
      }

      return {
        content: [{
          type: 'text',
          text: `主题已切换为: ${theme}`
        }]
      };
    } catch (error) {
      throw new Error(`切换主题失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取主题状态
   */
  private async getThemeStatus(): Promise<ToolCallResult> {
    try {
      const status = {
        currentTheme: ThemeManager.getCurrentTheme(),
        isDarkMode: ThemeManager.isDarkMode(),
        supportedThemes: ['light', 'dark', 'auto']
      };

      return {
        content: [{
          type: 'text',
          text: `主题状态:\n${JSON.stringify(status, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取主题状态失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 更新字体设置
   */
  private async updateFontSettings(args: Record<string, ESObject>): Promise<ToolCallResult> {
    try {
      const updates: Record<string, ESObject> = {};

      if (args.chatFontSize !== undefined) {
        updates.chatFontSize = args.chatFontSize;
      }
      if (args.codeFontSize !== undefined) {
        updates.codeFontSize = args.codeFontSize;
      }
      if (args.fontFamily !== undefined) {
        updates.fontFamily = args.fontFamily;
      }

      const newSettings = await AppStorage.updateFontSettings(updates);

      return {
        content: [{
          type: 'text',
          text: `字体设置已更新:\n${JSON.stringify(newSettings, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`更新字体设置失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取字体设置
   */
  private async getFontSettings(): Promise<ToolCallResult> {
    try {
      const settings = await AppStorage.getFontSettings();

      return {
        content: [{
          type: 'text',
          text: `当前字体设置:\n${JSON.stringify(settings, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取字体设置失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取会话数量统计
   */
  private async getSessionCount(): Promise<ToolCallResult> {
    try {
      const sessions = await AppStorage.getAllSessions();
      const sessionCount = sessions.length;
      const totalMessages = sessions.reduce((total, session) => total + session.messageCount, 0);

      const stats = {
        totalSessions: sessionCount,
        totalMessages: totalMessages,
        averageMessagesPerSession: sessionCount > 0 ? Math.round(totalMessages / sessionCount) : 0,
        oldestSession: sessionCount > 0 ? new Date(Math.min(...sessions.map(s => s.createdAt))).toISOString() : null,
        newestSession: sessionCount > 0 ? new Date(Math.max(...sessions.map(s => s.updatedAt))).toISOString() : null
      };

      return {
        content: [{
          type: 'text',
          text: `会话统计:\n${JSON.stringify(stats, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取会话统计失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 清理旧会话
   */
  private async clearOldSessions(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const days = (args.days as number) || 30;

    try {
      const cutoffTime = Date.now() - (days * 24 * 60 * 60 * 1000);
      const sessions = await AppStorage.getAllSessions();

      const sessionsToDelete = sessions.filter(session => session.updatedAt < cutoffTime);
      let deletedCount = 0;

      for (const session of sessionsToDelete) {
        await AppStorage.deleteSession(session.id);
        deletedCount++;
      }

      return {
        content: [{
          type: 'text',
          text: `已清理 ${deletedCount} 个超过 ${days} 天的旧会话`
        }]
      };
    } catch (error) {
      throw new Error(`清理旧会话失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取所有可用工具
   */
  getAvailableTools(): Array<MCPTool> {
    return Array.from(this.registeredTools.values());
  }

  /**
   * 根据名称获取工具
   */
  getTool(name: string): MCPTool | undefined {
    return this.registeredTools.get(name);
  }

  /**
   * 检查工具是否存在
   */
  hasTool(name: string): boolean {
    return this.registeredTools.has(name);
  }

  /**
   * 执行工具调用
   */
  async executeTool(request: ToolCallRequest): Promise<ToolCallResult> {
    const executor = this.toolExecutors.get(request.name);
    if (!executor) {
      return {
        content: [{
          type: 'text',
          text: `工具不存在: ${request.name}`
        }],
        isError: true
      };
    }

    Logger.info('LocalToolManager', `Executing local tool: ${request.name}`, request.arguments);

    try {
      const result = await executor.execute(request);
      Logger.debug('LocalToolManager', `Tool executed successfully: ${request.name}`);
      return result;
    } catch (error) {
      Logger.error('LocalToolManager', `Tool execution failed: ${request.name}`, error);
      return {
        content: [{
          type: 'text',
          text: `工具执行失败: ${error instanceof Error ? error.message : '未知错误'}`
        }],
        isError: true
      };
    }
  }

  /**
   * 注册自定义工具
   */
  registerCustomTool(tool: MCPTool, executor: LocalToolExecutor): void {
    if (this.registeredTools.has(tool.name)) {
      Logger.warn('LocalToolManager', `Tool already exists: ${tool.name}, will be overridden`);
    }

    this.registeredTools.set(tool.name, tool);
    this.toolExecutors.set(tool.name, executor);
    Logger.info('LocalToolManager', `Custom tool registered: ${tool.name}`);
  }

  /**
   * 取消注册工具
   */
  unregisterTool(name: string): boolean {
    const existed = this.registeredTools.has(name);
    this.registeredTools.delete(name);
    this.toolExecutors.delete(name);

    if (existed) {
      Logger.info('LocalToolManager', `Tool unregistered: ${name}`);
    }

    return existed;
  }

  /**
   * 获取工具统计信息
   */
  getToolStats(): ToolStats {
    const tools = Array.from(this.registeredTools.values());
    const categories = new Map<string, number>();

    for (const tool of tools) {
      // 根据工具名称前缀分类
      const category = this.getToolCategory(tool.name);
      categories.set(category, (categories.get(category) || 0) + 1);
    }

    return {
      totalTools: tools.length,
      categories: Object.fromEntries(categories),
      toolNames: tools.map(tool => tool.name).sort()
    };
  }

  /**
   * 获取工具分类
   */
  private getToolCategory(toolName: string): string {
    if (toolName.startsWith('read_') || toolName.startsWith('write_') ||
        toolName.startsWith('list_') || toolName.startsWith('create_') ||
        toolName.startsWith('delete_') || toolName.startsWith('get_file_')) {
      return 'filesystem';
    }
    if (toolName.startsWith('get_device_') || toolName.startsWith('get_app_') ||
        toolName.startsWith('get_network_') || toolName.startsWith('get_battery_') ||
        toolName.startsWith('get_display_') || toolName.startsWith('get_runtime_')) {
      return 'system';
    }
    if (toolName.startsWith('switch_') || toolName.startsWith('update_') ||
        toolName.startsWith('get_theme_') || toolName.startsWith('get_font_') ||
        toolName.startsWith('get_session_') || toolName.startsWith('clear_')) {
      return 'application';
    }
    return 'custom';
  }
}

/**
 * 本地工具执行器接口
 */
interface LocalToolExecutor {
  execute(request: ToolCallRequest): Promise<ToolCallResult>;
}

/**
 * 工具统计信息
 */
interface ToolStats {
  totalTools: number;
  categories: Record<string, number>;
  toolNames: Array<string>;
}

export default LocalToolManager;