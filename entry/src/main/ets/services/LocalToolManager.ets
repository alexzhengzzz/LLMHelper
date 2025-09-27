import { common } from '@kit.AbilityKit';
import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  ParamType,
  MCPToolConfig,
  MCPToolCategory,
  MCPToolStatus,
  ToolEnabledMap,
  ToolUsageStatsMap,
  ToolStatistics,
  ToolOperationResult
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';
import CalculatorTool from './CalculatorTool';
import AppLauncherTool from './AppLauncherTool';
import MemoryTool from './MemoryTool';
import { AppStorage, MCPToolsConfig } from '../utils/AppStorage';
import { AppInitializer } from '../utils/AppInitializer';

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
 * 应用启动工具执行器
 */
class AppLauncherToolExecutor implements LocalToolExecutor {
  private appLauncherTool: AppLauncherTool;

  constructor(appLauncherTool: AppLauncherTool) {
    this.appLauncherTool = appLauncherTool;
  }

  async execute(request: ToolCallRequest): Promise<ToolCallResult> {
    return this.appLauncherTool.execute(request);
  }
}


/**
 * 记忆搜索工具执行器
 */
class MemoryToolExecutor implements LocalToolExecutor {
  private memoryTool: MemoryTool;

  constructor(memoryTool: MemoryTool) {
    this.memoryTool = memoryTool;
  }

  async execute(request: ToolCallRequest): Promise<ToolCallResult> {
    return this.memoryTool.execute(request);
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
  private toolConfigs: Map<string, MCPToolConfig> = new Map();
  private context: common.UIAbilityContext;
  private toolsConfig: MCPToolsConfig | null = null;

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.registerAppManagementTools();
    this.registerCalculatorTool();
    this.registerAppLauncherTool();
    this.registerMemoryTool();

    // 异步初始化工具配置
    this.initializeToolsConfig().then(() => {
      Logger.info('LocalToolManager', 'Local tool manager initialized with tools config');
    }).catch((error: Error) => {
      Logger.error('LocalToolManager', `Failed to initialize tools config: ${error}`);
    });

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
   * 注册应用启动工具
   */
  private registerAppLauncherTool(): void {
    const appLauncherTool = AppLauncherTool.getInstance(this.context);
    const toolDefinition = appLauncherTool.getToolDefinition();

    this.registeredTools.set(toolDefinition.name, toolDefinition);
    const executor: LocalToolExecutor = new AppLauncherToolExecutor(appLauncherTool);
    this.toolExecutors.set(toolDefinition.name, executor);

    Logger.info('LocalToolManager', `App launcher tool registered: ${toolDefinition.name}`);
  }


  /**
   * 注册记忆搜索工具
   */
  private registerMemoryTool(): void {
    const memoryTool = MemoryTool.getInstance();
    const toolDefinition = memoryTool.getToolDefinition();

    this.registeredTools.set(toolDefinition.name, toolDefinition);
    const executor: LocalToolExecutor = new MemoryToolExecutor(memoryTool);
    this.toolExecutors.set(toolDefinition.name, executor);

    Logger.info('LocalToolManager', `Memory tool registered: ${toolDefinition.name}`);
  }


  /**
   * 获取所有可用工具（只返回已启用的工具）
   */
  getAvailableTools(): Array<MCPTool> {
    if (!this.toolsConfig || !this.toolsConfig.globalEnabled) {
      return [];
    }

    const availableTools: Array<MCPTool> = [];
    const toolEntries = Array.from(this.registeredTools.entries());
    for (let i = 0; i < toolEntries.length; i++) {
      const entry = toolEntries[i];
      const toolName = entry[0];
      const tool = entry[1];
      if (this.isToolEnabledSync(toolName)) {
        availableTools.push(tool);
      }
    }

    Logger.debug('LocalToolManager', `返回 ${availableTools.length} 个已启用工具`);
    return availableTools;
  }

  /**
   * 获取所有注册的工具（包括禁用的）
   */
  getAllRegisteredTools(): Array<MCPTool> {
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
    // 检查工具是否存在
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

    // 检查全局MCP开关
    if (!this.toolsConfig || !this.toolsConfig.globalEnabled) {
      const disabledResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: 'MCP工具功能已禁用，请在设置中启用'
        }],
        isError: true
      };
      return disabledResult;
    }

    // 检查单个工具是否启用
    if (!this.isToolEnabledSync(request.name)) {
      const toolDisabledResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `工具 ${request.name} 已禁用，请在MCP设置中启用`
        }],
        isError: true
      };
      return toolDisabledResult;
    }

    Logger.info('LocalToolManager', `Executing local tool: ${request.name}`, JSON.stringify(request.arguments));

    try {
      const result = await executor.execute(request);

      // 记录工具使用统计
      await this.incrementToolUsage(request.name);

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
    if (toolName === 'app_launcher' || toolName.startsWith('app_')) {
      return 'system';
    }
    if (toolName === 'calculator') {
      return 'utility';
    }
    if (toolName === 'search_user_memories' || toolName.startsWith('memory_')) { // 修改工具名称
      return 'utility';
    }
    return 'custom';
  }

  //=================== 工具配置管理方法 ===================

  /**
   * 初始化工具配置
   */
  private async initializeToolsConfig(): Promise<void> {
    try {
      // 使用AppInitializer的安全存储操作方法确保存储已初始化
      this.toolsConfig = await AppStorage.safeStorageOperation(async (storage) => {
        return await AppStorage.getMCPToolsConfig();
      });
      Logger.info('LocalToolManager', '工具配置初始化完成');
    } catch (error) {
      Logger.error('LocalToolManager', `Failed to initialize tools config: ${error}`);
      this.toolsConfig = AppStorage.getDefaultMCPToolsConfig();
    }
  }

  /**
   * 同步检查工具是否启用
   */
  private isToolEnabledSync(toolName: string): boolean {
    if (!this.toolsConfig) {
      return true; // 默认启用
    }
    return this.toolsConfig.globalEnabled && (this.toolsConfig.enabledTools[toolName] ?? true);
  }

  /**
   * 异步检查工具是否启用
   */
  async isToolEnabled(toolName: string): Promise<boolean> {
    return AppStorage.isToolEnabled(toolName);
  }

  /**
   * 设置工具启用状态
   */
  async setToolEnabled(toolName: string, enabled: boolean): Promise<ToolOperationResult> {
    try {
      if (!this.registeredTools.has(toolName)) {
        return {
          success: false,
          message: `工具不存在: ${toolName}`,
          toolName: toolName,
          error: 'TOOL_NOT_FOUND'
        };
      }

      await AppStorage.setToolEnabled(toolName, enabled);

      // 更新本地配置缓存
      await this.refreshToolsConfig();

      Logger.info('LocalToolManager', `工具 ${toolName} 已${enabled ? '启用' : '禁用'}`);

      return {
        success: true,
        message: `工具 ${toolName} 已${enabled ? '启用' : '禁用'}`,
        toolName: toolName
      };
    } catch (error) {
      Logger.error('LocalToolManager', `Failed to set tool enabled: ${error}`);
      return {
        success: false,
        message: `设置工具状态失败: ${error instanceof Error ? error.message : '未知错误'}`,
        toolName: toolName,
        error: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  /**
   * 批量设置工具启用状态
   */
  async setMultipleToolsEnabled(toolStates: Record<string, boolean>): Promise<Array<ToolOperationResult>> {
    const results: Array<ToolOperationResult> = [];

    const stateEntries = Object.entries(toolStates);
    for (let i = 0; i < stateEntries.length; i++) {
      const entry = stateEntries[i];
      const result = await this.setToolEnabled(entry[0], entry[1]);
      results.push(result);
    }

    return results;
  }

  /**
   * 启用所有工具
   */
  async enableAllTools(): Promise<ToolOperationResult> {
    try {
      await AppStorage.enableAllTools();
      await this.refreshToolsConfig();

      Logger.info('LocalToolManager', '所有工具已启用');

      return {
        success: true,
        message: '所有工具已启用'
      };
    } catch (error) {
      Logger.error('LocalToolManager', `Failed to enable all tools: ${error}`);
      return {
        success: false,
        message: `启用所有工具失败: ${error instanceof Error ? error.message : '未知错误'}`,
        error: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  /**
   * 禁用所有工具
   */
  async disableAllTools(): Promise<ToolOperationResult> {
    try {
      await AppStorage.disableAllTools();
      await this.refreshToolsConfig();

      Logger.info('LocalToolManager', '所有工具已禁用');

      return {
        success: true,
        message: '所有工具已禁用'
      };
    } catch (error) {
      Logger.error('LocalToolManager', `Failed to disable all tools: ${error}`);
      return {
        success: false,
        message: `禁用所有工具失败: ${error instanceof Error ? error.message : '未知错误'}`,
        error: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  /**
   * 刷新工具配置缓存
   */
  async refreshToolsConfig(): Promise<void> {
    try {
      this.toolsConfig = await AppStorage.getMCPToolsConfig();
      Logger.debug('LocalToolManager', '工具配置缓存已刷新');
    } catch (error) {
      Logger.error('LocalToolManager', `Failed to refresh tools config: ${error}`);
    }
  }

  /**
   * 增加工具使用统计
   */
  private async incrementToolUsage(toolName: string): Promise<void> {
    try {
      await AppStorage.incrementToolUsage(toolName);
      Logger.debug('LocalToolManager', `工具使用统计已更新: ${toolName}`);
    } catch (error) {
      Logger.error('LocalToolManager', `Failed to increment tool usage: ${error}`);
    }
  }

  /**
   * 获取工具使用统计
   */
  async getToolUsageStats(): Promise<Record<string, number>> {
    return AppStorage.getToolUsageStats();
  }

  /**
   * 获取工具统计信息
   */
  async getToolStatistics(): Promise<ToolStatistics> {
    try {
      const usageStats = await this.getToolUsageStats();
      const totalTools = this.registeredTools.size;
      const enabledTools = this.getAvailableTools().length;
      const disabledTools = totalTools - enabledTools;

      let mostUsedTool: string | undefined;
      let leastUsedTool: string | undefined;
      let maxUsage = 0;
      let minUsage = Number.MAX_SAFE_INTEGER;
      let totalUsage = 0;

      const categoryStats: Record<MCPToolCategory, number> = {
        [MCPToolCategory.UTILITY]: 0,
        [MCPToolCategory.SYSTEM]: 0,
        [MCPToolCategory.APPLICATION]: 0,
        [MCPToolCategory.FILESYSTEM]: 0,
        [MCPToolCategory.NETWORK]: 0,
        [MCPToolCategory.CUSTOM]: 0
      };

      const usageEntries = Object.entries(usageStats);
      for (let i = 0; i < usageEntries.length; i++) {
        const entry = usageEntries[i];
        const toolName = entry[0];
        const count = entry[1];
        totalUsage += count;

        if (count > maxUsage) {
          maxUsage = count;
          mostUsedTool = toolName;
        }

        if (count < minUsage) {
          minUsage = count;
          leastUsedTool = toolName;
        }

        // 统计分类
        const category = this.getToolCategory(toolName) as MCPToolCategory;
        if (categoryStats[category] !== undefined) {
          categoryStats[category]++;
        } else {
          categoryStats[MCPToolCategory.CUSTOM]++;
        }
      }

      return {
        totalTools,
        enabledTools,
        disabledTools,
        mostUsedTool,
        leastUsedTool,
        totalUsage,
        categoryStats
      };
    } catch (error) {
      Logger.error('LocalToolManager', `Failed to get tool statistics: ${error}`);
      return {
        totalTools: 0,
        enabledTools: 0,
        disabledTools: 0,
        totalUsage: 0,
        categoryStats: {
          [MCPToolCategory.UTILITY]: 0,
          [MCPToolCategory.SYSTEM]: 0,
          [MCPToolCategory.APPLICATION]: 0,
          [MCPToolCategory.FILESYSTEM]: 0,
          [MCPToolCategory.NETWORK]: 0,
          [MCPToolCategory.CUSTOM]: 0
        }
      };
    }
  }

  /**
   * 重置所有工具使用统计
   */
  async resetToolUsageStats(): Promise<ToolOperationResult> {
    try {
      await AppStorage.resetToolUsageStats();
      Logger.info('LocalToolManager', '工具使用统计已重置');

      return {
        success: true,
        message: '工具使用统计已重置'
      };
    } catch (error) {
      Logger.error('LocalToolManager', `Failed to reset tool usage stats: ${error}`);
      return {
        success: false,
        message: `重置使用统计失败: ${error instanceof Error ? error.message : '未知错误'}`,
        error: error instanceof Error ? error.message : '未知错误'
      };
    }
  }

  /**
   * 获取工具配置
   */
  async getToolConfig(toolName: string): Promise<MCPToolConfig | null> {
    try {
      if (!this.registeredTools.has(toolName)) {
        return null;
      }

      const tool = this.registeredTools.get(toolName)!;
      const isEnabled = await this.isToolEnabled(toolName);
      const usageStats = await this.getToolUsageStats();
      const usageCount = usageStats[toolName] || 0;

      return {
        name: toolName,
        enabled: isEnabled,
        category: this.getToolCategory(toolName) as MCPToolCategory,
        priority: 1, // 默认优先级
        description: tool.description,
        usageCount: usageCount,
        configurable: true,
        systemTool: ['calculator', 'app_launcher', 'search_user_memories'].includes(toolName)
      };
    } catch (error) {
      Logger.error('LocalToolManager', `Failed to get tool config: ${error}`);
      return null;
    }
  }

  /**
   * 获取所有工具配置
   */
  async getAllToolConfigs(): Promise<Array<MCPToolConfig>> {
    const configs: Array<MCPToolConfig> = [];

    for (const toolName of this.registeredTools.keys()) {
      const config = await this.getToolConfig(toolName);
      if (config) {
        configs.push(config);
      }
    }

    return configs;
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