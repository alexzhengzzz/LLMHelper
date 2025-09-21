import { common } from '@kit.AbilityKit';
import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  ParamType
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';
import CalculatorTool from './CalculatorTool';

/**
 * 本地工具执行器接口
 */
interface LocalToolExecutor {
  execute(request: ToolCallRequest): Promise<ToolCallResult>;
}

/**
 * 应用管理工具执行器
 */
class AppManagementToolExecutor implements LocalToolExecutor {
  private manager: LocalToolManager;

  constructor(manager: LocalToolManager) {
    this.manager = manager;
  }

  async execute(request: ToolCallRequest): Promise<ToolCallResult> {
    return this.manager.executeAppManagementTool(request);
  }
}

/**
 * 计算器工具执行器
 */
class CalculatorToolExecutor implements LocalToolExecutor {
  private calculatorTool: CalculatorTool;

  constructor(calculatorTool: CalculatorTool) {
    this.calculatorTool = calculatorTool;
  }

  async execute(request: ToolCallRequest): Promise<ToolCallResult> {
    return this.calculatorTool.execute(request);
  }
}

/**
 * 本地工具管理器
 * 管理和执行本地MCP工具
 */
export class LocalToolManager {
  private static instance: LocalToolManager | null = null;
  private registeredTools: Map<string, MCPTool> = new Map();
  private toolExecutors: Map<string, LocalToolExecutor> = new Map();

  private constructor(context: common.UIAbilityContext) {
    this.registerAppManagementTools();
    this.registerCalculatorTool();
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
   * 注册应用管理工具
   */
  private registerAppManagementTools(): void {
    // 注册所有应用管理工具
    const allAppTools: MCPTool[] = [];
    for (const tool of allAppTools) {
      this.registeredTools.set(tool.name, tool);
      const executor: LocalToolExecutor = new AppManagementToolExecutor(this);
      this.toolExecutors.set(tool.name, executor);
    }
  }

  /**
   * 执行应用管理工具
   */
  async executeAppManagementTool(request: ToolCallRequest): Promise<ToolCallResult> {
    try {
      switch (request.name) {
        default:
          throw new Error(`Unknown app management tool: ${request.name}`);
      }
    } catch (error) {
      const result: ToolCallResult = {
        content: [{
          type: 'text',
          text: `应用管理工具执行失败: ${error instanceof Error ? error.message : '未知错误'}`
        }],
        isError: true
      };
      return result;
    }
  }

  /**
   * 注册计算器工具
   */
  private registerCalculatorTool(): void {
    const calculatorTool = CalculatorTool.getInstance();
    const toolDefinition = calculatorTool.getToolDefinition();

    this.registeredTools.set(toolDefinition.name, toolDefinition);
    const executor: LocalToolExecutor = new CalculatorToolExecutor(calculatorTool);
    this.toolExecutors.set(toolDefinition.name, executor);

    Logger.info('LocalToolManager', `Calculator tool registered: ${toolDefinition.name}`);
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
      const notFoundResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `工具不存在: ${request.name}`
        }],
        isError: true
      };
      return notFoundResult;
    }

    Logger.info('LocalToolManager', `Executing local tool: ${request.name}`, JSON.stringify(request.arguments));

    try {
      const result = await executor.execute(request);
      Logger.debug('LocalToolManager', `Tool executed successfully: ${request.name}`);
      return result;
    } catch (error) {
      Logger.error('LocalToolManager', `Tool execution failed: ${request.name}`, error);
      const errorResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `工具执行失败: ${error instanceof Error ? error.message : '未知错误'}`
        }],
        isError: true
      };
      return errorResult;
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

    const categoryRecord: Record<string, number> = {};
    categories.forEach((value, key) => {
      categoryRecord[key] = value;
    });

    return {
      totalTools: tools.length,
      categories: categoryRecord,
      toolNames: tools.map(tool => tool.name).sort()
    };
  }

  /**
   * 获取工具分类
   */
  private getToolCategory(toolName: string): string {
    if (toolName.startsWith('switch_') || toolName.startsWith('update_') ||
        toolName.startsWith('get_theme_') || toolName.startsWith('get_font_') ||
        toolName.startsWith('get_session_') || toolName.startsWith('clear_')) {
      return 'application';
    }
    return 'custom';
  }
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