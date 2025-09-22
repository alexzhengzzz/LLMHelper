/**
 * MCP设置页面
 * 简化的MCP客户端设置界面
 */

import { router } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';
import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  JSONSchema,
  ParamType,
  TextContent,
  ImageContent,
  MCPToolConfig,
  MCPToolCategory,
  MCPToolStatus,
  ToolStatistics,
  ToolOperationResult
} from '../types/MCPTypes';
import { LocalToolManager } from '../services/LocalToolManager';
import { AppContext } from '../utils/AppContext';
import { AIServiceStateManager } from '../utils/AIServiceStateManager';
import { AppStorage, MCPToolsConfig } from '../utils/AppStorage';
import { window } from '@kit.ArkUI';

interface ToolCategoryInfo {
  key: string;
  name: string;
  count: number;
}

@Entry
@ComponentV2
struct MCPSettingsPage {
  @Local private mcpEnabled: boolean = true;

  // 工具管理状态
  @Local private availableTools: Array<MCPTool> = [];
  @Local private toolConfigs: Array<MCPToolConfig> = [];
  @Local private toolsConfig: MCPToolsConfig | null = null;
  @Local private toolStatistics: ToolStatistics | null = null;
  @Local private selectedTool: MCPTool | null = null;
  @Local private toolParams: ParamType = {};
  @Local private isExecuting: boolean = false;
  @Local private executionResult: ToolCallResult | null = null;
  @Local private showResult: boolean = false;
  @Local private searchText: string = '';
  @Local private selectedCategory: string = 'all';
  @Local private statusBarHeight: number = 44; // 状态栏高度，动态获取
  @Local private showStatistics: boolean = false; // 是否显示统计信息
  @Local private isUpdatingTools: boolean = false; // 是否正在更新工具状态

  private localToolManager: LocalToolManager | null = null;
  private aiServiceStateManager: AIServiceStateManager | null = null;

  aboutToAppear(): void {
    try {
      const context = AppContext.getInstance().getContext();
      if (context) {
        this.localToolManager = LocalToolManager.getInstance();
        this.aiServiceStateManager = AIServiceStateManager.getInstance();

        // 异步加载数据
        this.loadAvailableTools().then(() => {
          Logger.info('MCPSettingsPage', 'Tools loaded successfully');
        }).catch((error: Error) => {
          Logger.error('MCPSettingsPage', 'Failed to load tools', error);
        });

        this.loadMCPState();
        this.loadToolsConfig();
      }
      this.initializeStatusBarHeight();
      Logger.info('MCPSettingsPage', 'MCP Settings page initialized');
    } catch (error) {
      Logger.error('MCPSettingsPage', 'Failed to initialize', error);
    }
  }

  onPageShow(): void {
    try {
      // 页面显示时重新加载MCP状态，确保状态同步
      this.loadMCPState();
      Logger.info('MCPSettingsPage', 'Page shown, MCP state reloaded');
    } catch (error) {
      Logger.error('MCPSettingsPage', 'Failed to reload MCP state on page show', error);
    }
  }

  /**
   * 初始化状态栏高度
   */
  private initializeStatusBarHeight(): void {
    try {
      // 先尝试从AppStorage获取缓存的状态栏高度
      const storage = AppStorage.getPreferences();
      const cachedHeight = 44; // 默认状态栏高度
      if (cachedHeight && cachedHeight > 0) {
        this.statusBarHeight = cachedHeight;
        Logger.info('MCPSettingsPage', `使用缓存的状态栏高度: ${this.statusBarHeight}vp`);
        return;
      }
    } catch (error) {
      Logger.error('MCPSettingsPage', `获取状态栏高度失败: ${error}，使用默认值`);
    }
  }

  /**
   * 加载可用工具
   */
  private async loadAvailableTools(): Promise<void> {
    if (this.localToolManager) {
      // 加载所有注册的工具（包括禁用的）
      this.availableTools = this.localToolManager.getAllRegisteredTools();

      // 加载工具配置
      this.toolConfigs = await this.localToolManager.getAllToolConfigs();

      // 加载工具统计信息
      this.toolStatistics = await this.localToolManager.getToolStatistics();

      Logger.info('MCPSettingsPage', `Loaded ${this.availableTools.length} tools, ${this.toolConfigs.length} configs`);
    }
  }

  /**
   * 加载MCP状态
   */
  private loadMCPState(): void {
    if (this.aiServiceStateManager) {
      try {
        const currentFeatures = this.aiServiceStateManager.getCurrentFeatures();
        this.mcpEnabled = currentFeatures.enableMCPTools;
        Logger.info('MCPSettingsPage', `MCP状态加载完成: ${this.mcpEnabled}`);
      } catch (error) {
        Logger.error('MCPSettingsPage', `加载MCP状态失败: ${error}`);
        // 使用默认值
        this.mcpEnabled = true;
      }
    }
  }

  /**
   * 保存MCP状态
   */
  private async saveMCPState(enabled: boolean): Promise<void> {
    if (this.aiServiceStateManager) {
      try {
        await this.aiServiceStateManager.setFeature('enableMCPTools', enabled);
        // 同时更新工具配置
        await AppStorage.updateMCPToolsConfig({ globalEnabled: enabled });
        await this.refreshData();
        Logger.info('MCPSettingsPage', `MCP状态保存成功: ${enabled}`);
      } catch (error) {
        Logger.error('MCPSettingsPage', `保存MCP状态失败: ${error}`);
        // 回滚UI状态
        this.mcpEnabled = !enabled;
      }
    }
  }

  /**
   * 加载工具配置
   */
  private async loadToolsConfig(): Promise<void> {
    try {
      this.toolsConfig = await AppStorage.getMCPToolsConfig();
      Logger.info('MCPSettingsPage', '工具配置加载完成');
    } catch (error) {
      Logger.error('MCPSettingsPage', `加载工具配置失败: ${error}`);
    }
  }

  /**
   * 刷新所有数据
   */
  private async refreshData(): Promise<void> {
    try {
      await this.loadAvailableTools();
      await this.loadToolsConfig();
      this.loadMCPState();
      Logger.info('MCPSettingsPage', '数据刷新完成');
    } catch (error) {
      Logger.error('MCPSettingsPage', `刷新数据失败: ${error}`);
    }
  }

  /**
   * 设置工具启用状态
   */
  private async setToolEnabled(toolName: string, enabled: boolean): Promise<void> {
    if (!this.localToolManager) {
      return;
    }

    this.isUpdatingTools = true;

    try {
      const result = await this.localToolManager.setToolEnabled(toolName, enabled);

      if (result.success) {
        Logger.info('MCPSettingsPage', `工具 ${toolName} 状态更新成功: ${enabled}`);
        // 刷新数据
        await this.refreshData();
      } else {
        Logger.error('MCPSettingsPage', `工具 ${toolName} 状态更新失败: ${result.error}`);
      }
    } catch (error) {
      Logger.error('MCPSettingsPage', `设置工具状态失败: ${error}`);
    } finally {
      this.isUpdatingTools = false;
    }
  }

  /**
   * 批量操作：启用所有工具
   */
  private async enableAllTools(): Promise<void> {
    if (!this.localToolManager) {
      return;
    }

    this.isUpdatingTools = true;

    try {
      const result = await this.localToolManager.enableAllTools();

      if (result.success) {
        Logger.info('MCPSettingsPage', '所有工具已启用');
        await this.refreshData();
      } else {
        Logger.error('MCPSettingsPage', `启用所有工具失败: ${result.error}`);
      }
    } catch (error) {
      Logger.error('MCPSettingsPage', `批量启用工具失败: ${error}`);
    } finally {
      this.isUpdatingTools = false;
    }
  }

  /**
   * 批量操作：禁用所有工具
   */
  private async disableAllTools(): Promise<void> {
    if (!this.localToolManager) {
      return;
    }

    this.isUpdatingTools = true;

    try {
      const result = await this.localToolManager.disableAllTools();

      if (result.success) {
        Logger.info('MCPSettingsPage', '所有工具已禁用');
        await this.refreshData();
      } else {
        Logger.error('MCPSettingsPage', `禁用所有工具失败: ${result.error}`);
      }
    } catch (error) {
      Logger.error('MCPSettingsPage', `批量禁用工具失败: ${error}`);
    } finally {
      this.isUpdatingTools = false;
    }
  }

  /**
   * 获取工具分类
   */
  private getToolCategories(): Array<ToolCategoryInfo> {
    const categories = new Map<string, number>();

    for (const tool of this.availableTools) {
      const category = this.getToolCategory(tool.name);
      categories.set(category, (categories.get(category) || 0) + 1);
    }

    const result: ToolCategoryInfo[] = [
      { key: 'all', name: '全部', count: this.availableTools.length }
    ];

    categories.forEach((count, key) => {
      result.push({
        key: key,
        name: this.getCategoryDisplayName(key),
        count: count
      });
    });

    return result;
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

  /**
   * 获取分类显示名称
   */
  private getCategoryDisplayName(category: string): string {
    switch (category) {
      case 'filesystem': return '文件系统';
      case 'system': return '系统信息';
      case 'application': return '应用管理';
      case 'custom': return '自定义';
      default: return category;
    }
  }

  /**
   * 过滤工具列表
   */
  private getFilteredTools(): Array<MCPTool> {
    let filtered = this.availableTools;

    // 按分类过滤
    if (this.selectedCategory !== 'all') {
      filtered = filtered.filter(tool => this.getToolCategory(tool.name) === this.selectedCategory);
    }

    // 按搜索文本过滤
    if (this.searchText.trim()) {
      const searchLower = this.searchText.toLowerCase();
      filtered = filtered.filter(tool =>
        tool.name.toLowerCase().includes(searchLower) ||
        (tool.description && tool.description.toLowerCase().includes(searchLower))
      );
    }

    return filtered;
  }

  /**
   * 执行工具
   */
  private async executeTool(): Promise<void> {
    if (!this.selectedTool || !this.localToolManager) {
      return;
    }

    this.isExecuting = true;
    this.executionResult = null;

    try {
      const request: ToolCallRequest = {
        name: this.selectedTool.name,
        arguments: this.toolParams
      };

      Logger.info('MCPSettingsPage', `Executing tool: ${this.selectedTool.name}`, JSON.stringify(this.toolParams));

      const result = await this.localToolManager.executeTool(request);
      this.executionResult = result;
      this.showResult = true;

      Logger.info('MCPSettingsPage', `Tool execution completed: ${this.selectedTool.name}`, JSON.stringify({
        success: !result.isError
      }));

    } catch (error) {
      Logger.error('MCPSettingsPage', `Tool execution failed: ${this.selectedTool.name}`, error);
      this.executionResult = {
        content: [{
          type: 'text',
          text: `工具执行失败: ${error instanceof Error ? error.message : '未知错误'}`
        }],
        isError: true
      };
      this.showResult = true;
    } finally {
      this.isExecuting = false;
    }
  }

  /**
   * 重置参数
   */
  private resetParams(): void {
    this.toolParams = {} as ParamType;
    this.executionResult = null;
    this.showResult = false;
  }

  build() {
    Column() {
      // 顶部导航栏 - 添加状态栏高度避让
      Column() {
        this.buildNavigationBar()
      }
      .margin({ top: this.statusBarHeight })

      // MCP控制区域 - 始终在页面上方
      this.buildMCPControlSection()

      Scroll() {
        Column({ space: 16 }) {
          this.buildMCPToolsSection()
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_color'))
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Button() {
        Text('←')
          .fontSize(20)
          .fontColor($r('app.color.text_primary'))
      }
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        router.back();
      })

      Text('MCP Settings')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank()
        .width(48)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.SpaceBetween)
    .border({
      width: { bottom: 1 },
      color: $r('app.color.border_color')
    })
  }

  @Builder
  buildMCPControlSection() {
    Column({ space: 16 }) {
      Text('MCP 工具控制')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)

      Row({ space: 12 }) {
        Text('启用 MCP 工具')
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.mcpEnabled })
          .onChange((isOn: boolean) => {
            this.mcpEnabled = isOn;
            this.saveMCPState(isOn);
            Logger.info('MCPSettingsPage', `MCP tools ${isOn ? 'enabled' : 'disabled'}`);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.mcpEnabled) {
        Text('MCP 工具已启用，可以在对话中使用本地工具功能')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(18)
      } else {
        Text('MCP 工具已禁用，本地工具功能不可用')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(18)
      }
    }
    .width('95%')
    .margin({ left: 16, right: 16, bottom: 16 })
    .padding(16)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
  }

  @Builder
  buildMCPToolsSection() {
    if (this.mcpEnabled) {
      Column({ space: 20 }) {
        // 搜索和分类筛选
        Column({ space: 16 }) {
          Text('工具管理')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .alignSelf(ItemAlign.Start)

          // 搜索框
          TextInput({
            placeholder: '搜索工具...',
            text: this.searchText
          })
            .fontSize(16)
            .backgroundColor(Color.White)
            .borderRadius(8)
            .height(48)
            .padding({ left: 16, right: 16 })
            .border({
              width: 1,
              color: $r('app.color.border_color')
            })
            .onChange((value: string) => {
              this.searchText = value;
            })

          // 分类标签
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.getToolCategories(), (category: ToolCategoryInfo) => {
              Button(`${category.name} (${category.count})`)
                .type(ButtonType.Normal)
                .backgroundColor(this.selectedCategory === category.key ?
                  $r('app.color.primary_color') : Color.Transparent)
                .fontColor(this.selectedCategory === category.key ?
                  Color.White : $r('app.color.text_secondary'))
                .borderWidth(1)
                .borderColor(this.selectedCategory === category.key ?
                  $r('app.color.primary_color') : $r('app.color.border_color'))
                .borderRadius(20)
                .fontSize(14)
                .height(36)
                .padding({ left: 16, right: 16 })
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.selectedCategory = category.key;
                })
            });
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor($r('app.color.surface_color'))
        .borderRadius(12)

        // 批量操作按钮
        this.buildBatchOperationsSection()

        // 工具列表
        if (this.getFilteredTools().length > 0) {
          Column({ space: 16 }) {
            Row({ space: 12 }) {
              Text(`工具列表 (${this.getFilteredTools().length})`)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)

              if (this.showStatistics && this.toolStatistics) {
                Button('隐藏统计')
                  .type(ButtonType.Normal)
                  .backgroundColor(Color.Transparent)
                  .fontColor($r('app.color.text_secondary'))
                  .fontSize(14)
                  .height(32)
                  .padding({ left: 12, right: 12 })
                  .onClick(() => {
                    this.showStatistics = false;
                  })
              } else {
                Button('显示统计')
                  .type(ButtonType.Normal)
                  .backgroundColor(Color.Transparent)
                  .fontColor($r('app.color.primary_color'))
                  .fontSize(14)
                  .height(32)
                  .padding({ left: 12, right: 12 })
                  .onClick(() => {
                    this.showStatistics = true;
                  })
              }
            }
            .width('100%')

            // 工具统计信息
            if (this.showStatistics && this.toolStatistics) {
              this.buildStatisticsSection()
            }

            ForEach(this.getFilteredTools(), (tool: MCPTool) => {
              this.buildToolItemWithSwitch(tool)
            });
          }
          .width('100%')
          .padding(20)
          .backgroundColor($r('app.color.surface_color'))
          .borderRadius(12)
        }

        // 参数表单
        if (this.selectedTool) {
          this.buildParameterForm();
        }

        // 执行结果
        if (this.showResult && this.executionResult) {
          this.buildExecutionResult();
        }

        // 加载状态
        if (this.isExecuting) {
          this.buildLoadingState();
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius(12)
    }
  }

  /**
   * 渲染参数输入表单
   */
  @Builder
  buildParameterForm() {
    if (this.selectedTool) {
      Column({ space: 20 }) {
        Text('参数设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .alignSelf(ItemAlign.Start)

        this.buildParameterInputs()

        Row({ space: 16 }) {
          Button('重置')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .borderWidth(1)
            .borderColor($r('app.color.border_color'))
            .fontColor($r('app.color.text_secondary'))
            .borderRadius(8)
            .height(48)
            .layoutWeight(1)
            .onClick(() => {
              this.resetParams();
            })

          Button('执行')
            .type(ButtonType.Normal)
            .backgroundColor($r('app.color.primary_color'))
            .fontColor(Color.White)
            .borderRadius(8)
            .height(48)
            .layoutWeight(1)
            .enabled(!this.isExecuting)
            .onClick(() => {
              this.executeTool();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(20)
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius(12)
    }
  }

  @Builder
  buildParameterInputs() {
    ForEach(this.getParameterNames(), (paramName: string) => {
      if (this.getParameterSchema(paramName)) {
        this.buildParameterInput(paramName, this.getParameterSchema(paramName));
      }
    });
  }

  private getParameterNames(): Array<string> {
    const properties = this.selectedTool!.inputSchema.properties || {};
    return Object.keys(properties);
  }

  private getParameterSchema(paramName: string): JSONSchema | undefined {
    const properties = this.selectedTool!.inputSchema.properties || {};
    return properties[paramName];
  }

  /**
   * 构建参数输入项
   */
  @Builder
  buildParameterInput(paramName: string, schema: JSONSchema | undefined) {
    if (schema) {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Row() {
            Text(paramName)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))

            if (this.selectedTool?.inputSchema.required?.includes(paramName)) {
              Text(' *')
                .fontSize(16)
                .fontColor('#F44336')
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)

          if (schema.description) {
            Text(schema.description)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(20)
              .width('100%')
              .textAlign(TextAlign.Start)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (schema.type === 'string' && schema.enum) {
          // 枚举选择
          this.buildEnumSelector(paramName, schema.enum as Array<string>);
        } else if (schema.type === 'boolean') {
          // 布尔开关
          this.buildBooleanToggle(paramName);
        } else if (schema.type === 'number') {
          // 数字输入
          this.buildNumberInput(paramName, schema);
        } else {
          // 文本输入
          this.buildTextInput(paramName, schema);
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.input_background'))
      .borderRadius(12)
      .border({
        width: 1,
        color: $r('app.color.border_color')
      })
    }
  }

  /**
   * 构建枚举选择器
   */
  @Builder
  buildEnumSelector(paramName: string, options: Array<string>) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(options, (option: string) => {
        Button(option)
          .type(ButtonType.Normal)
          .backgroundColor(this.toolParams[paramName] === option ?
            $r('app.color.primary_color') : Color.Transparent)
          .fontColor(this.toolParams[paramName] === option ?
            Color.White : $r('app.color.text_secondary'))
          .borderWidth(1)
          .borderColor(this.toolParams[paramName] === option ?
            $r('app.color.primary_color') : $r('app.color.border_color'))
          .borderRadius(8)
          .fontSize(14)
          .height(44)
          .padding({ left: 16, right: 16 })
          .margin({ right: 8, bottom: 8 })
          .onClick(() => {
            this.toolParams[paramName] = option;
          })
      });
    }
    .width('100%')
  }

  /**
   * 构建布尔开关
   */
  @Builder
  buildBooleanToggle(paramName: string) {
    Row() {
      Toggle({ type: ToggleType.Switch, isOn: this.toolParams[paramName] as boolean || false })
        .width(60)
        .height(32)
        .onChange((isOn: boolean) => {
          this.toolParams[paramName] = isOn;
        })
    }
    .width('100%')
    .height(44)
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 构建数字输入
   */
  @Builder
  buildNumberInput(paramName: string, schema: JSONSchema) {
    TextInput({
      placeholder: `输入数字${schema.minimum !== undefined ? ` (${schema.minimum}-${schema.maximum || '∞'})` : ''}`,
      text: this.toolParams[paramName]?.toString() || ''
    })
      .type(InputType.Number)
      .fontSize(16)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .height(48)
      .padding({ left: 16, right: 16 })
      .border({
        width: 1,
        color: $r('app.color.border_color')
      })
      .onChange((value: string) => {
        const numValue = parseFloat(value);
        if (!isNaN(numValue)) {
          this.toolParams[paramName] = numValue;
        } else {
          // 从对象中移除该属性
          const newParams: ParamType = {};
          Object.keys(this.toolParams).forEach((key: string) => {
            if (key !== paramName) {
              newParams[key] = this.toolParams[key];
            }
          });
          this.toolParams = newParams;
        }
      })
  }

  /**
   * 构建文本输入
   */
  @Builder
  buildTextInput(paramName: string, schema: JSONSchema) {
    TextInput({
      placeholder: `请输入${paramName}`,
      text: this.toolParams[paramName] as string || ''
    })
      .fontSize(16)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .height(48)
      .padding({ left: 16, right: 16 })
      .border({
        width: 1,
        color: $r('app.color.border_color')
      })
      .onChange((value: string) => {
        if (value.trim()) {
          this.toolParams[paramName] = value;
        } else {
          // 从对象中移除该属性
          const newParams: ParamType = {};
          Object.keys(this.toolParams).forEach((key: string) => {
            if (key !== paramName) {
              newParams[key] = this.toolParams[key];
            }
          });
          this.toolParams = newParams;
        }
      })
  }

  /**
   * 构建执行结果
   */
  @Builder
  buildExecutionResult() {
    Column({ space: 16 }) {
      Row() {
        Text('执行结果')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Button('关闭')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.text_secondary'))
          .fontSize(14)
          .height(40)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.showResult = false;
          })
      }
      .width('100%')

      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.executionResult!.content, (content: TextContent | ImageContent) => {
            if (content.type === 'text' && (content as TextContent).text) {
              Text((content as TextContent).text)
                .fontSize(14)
                .fontColor(this.executionResult!.isError ?
                  '#F44336' : $r('app.color.text_primary'))
                .backgroundColor(this.executionResult!.isError ?
                  '#FFF5F5' : $r('app.color.code_background'))
                .padding(16)
                .borderRadius(8)
                .width('100%')
                .textAlign(TextAlign.Start)
                .copyOption(CopyOptions.InApp)
                .lineHeight(20)
            }
          });
        }
        .width('100%')
      }
      .constraintSize({ minHeight: 120, maxHeight: 300 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
    .border({
      width: 2,
      color: this.executionResult!.isError ? '#F44336' : '#4CAF50'
    })
  }

  /**
   * 构建加载状态
   */
  @Builder
  buildLoadingState() {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
        .color($r('app.color.primary_color'))

      Text('正在执行工具...')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)

      Text('请稍候，工具正在处理您的请求')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(120)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
    .border({
      width: 1,
      color: $r('app.color.primary_color')
    })
  }

  /**
   * 构建批量操作区域
   */
  @Builder
  buildBatchOperationsSection() {
    Column({ space: 12 }) {
      Text('批量操作')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)

      Row({ space: 12 }) {
        Button('全部启用')
          .type(ButtonType.Normal)
          .backgroundColor($r('app.color.primary_color'))
          .fontColor(Color.White)
          .borderRadius(8)
          .fontSize(14)
          .height(40)
          .layoutWeight(1)
          .enabled(!this.isUpdatingTools)
          .onClick(() => {
            this.enableAllTools();
          })

        Button('全部禁用')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .borderWidth(1)
          .borderColor($r('app.color.border_color'))
          .fontColor($r('app.color.text_secondary'))
          .borderRadius(8)
          .fontSize(14)
          .height(40)
          .layoutWeight(1)
          .enabled(!this.isUpdatingTools)
          .onClick(() => {
            this.disableAllTools();
          })

        Button('刷新')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .borderWidth(1)
          .borderColor($r('app.color.primary_color'))
          .fontColor($r('app.color.primary_color'))
          .borderRadius(8)
          .fontSize(14)
          .height(40)
          .padding({ left: 16, right: 16 })
          .enabled(!this.isUpdatingTools)
          .onClick(() => {
            this.refreshData();
          })
      }
      .width('100%')

      if (this.isUpdatingTools) {
        Row({ space: 8 }) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color($r('app.color.primary_color'))

          Text('正在更新工具状态...')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
  }

  /**
   * 构建统计信息区域
   */
  @Builder
  buildStatisticsSection() {
    if (this.toolStatistics) {
      Column({ space: 12 }) {
        Text('工具统计')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .alignSelf(ItemAlign.Start)

        Row({ space: 16 }) {
          Column({ space: 4 }) {
            Text(`${this.toolStatistics.totalTools}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            Text('总工具数')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Center)

          Column({ space: 4 }) {
            Text(`${this.toolStatistics.enabledTools}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#4CAF50')

            Text('已启用')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Center)

          Column({ space: 4 }) {
            Text(`${this.toolStatistics.disabledTools}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F44336')

            Text('已禁用')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Center)

          Column({ space: 4 }) {
            Text(`${this.toolStatistics.totalUsage}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_color'))

            Text('总使用次数')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)

        if (this.toolStatistics.mostUsedTool) {
          Text(`最常用工具: ${this.toolStatistics.mostUsedTool}`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .alignSelf(ItemAlign.Start)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.input_background'))
      .borderRadius(12)
      .border({
        width: 1,
        color: $r('app.color.border_color')
      })
    }
  }

  /**
   * 构建带开关的工具项
   */
  @Builder
  buildToolItemWithSwitch(tool: MCPTool) {
    Column({ space: 12 }) {
      Row({ space: 16 }) {
        // 左侧工具信息
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(tool.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))

            // 状态指示器
            Text(this.getToolConfig(tool.name)?.enabled ? '启用' : '禁用')
              .fontSize(12)
              .fontColor(this.getToolConfig(tool.name)?.enabled ? Color.White : $r('app.color.text_secondary'))
              .backgroundColor(this.getToolConfig(tool.name)?.enabled ? '#4CAF50' : '#BDBDBD')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(10)
          }
          .alignItems(VerticalAlign.Center)

          Row({ space: 12 }) {
            Text(`分类: ${this.getCategoryDisplayName(this.getToolCategory(tool.name))}`)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))

            if ((this.getToolConfig(tool.name)?.usageCount ?? 0) > 0) {
              Text(`使用次数: ${this.getToolConfig(tool.name)?.usageCount ?? 0}`)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 右侧控制按钮区域
        Column({ space: 8 }) {
          // 工具开关
          Row({ space: 8 }) {
            Text('启用')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))

            Toggle({ type: ToggleType.Switch, isOn: this.getToolConfig(tool.name)?.enabled ?? true })
              .width(48)
              .height(28)
              .enabled(!this.isUpdatingTools)
              .onChange((isOn: boolean) => {
                this.setToolEnabled(tool.name, isOn);
              })
          }
          .alignItems(VerticalAlign.Center)

          // 测试按钮
          Button(this.selectedTool?.name === tool.name ? '已选择' : '选择测试')
            .type(ButtonType.Normal)
            .backgroundColor(this.selectedTool?.name === tool.name ? $r('app.color.primary_color') : Color.Transparent)
            .borderWidth(1)
            .borderColor($r('app.color.primary_color'))
            .fontColor(this.selectedTool?.name === tool.name ? Color.White : $r('app.color.primary_color'))
            .borderRadius(6)
            .fontSize(12)
            .height(32)
            .padding({ left: 12, right: 12 })
            .enabled(!this.isUpdatingTools)
            .onClick(() => {
              if (this.selectedTool?.name === tool.name) {
                this.selectedTool = null;
              } else {
                this.selectedTool = tool;
                this.resetParams();
              }
            })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      if (tool.description) {
        Text(tool.description)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(18)
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.selectedTool?.name === tool.name ? $r('app.color.surface_color') : Color.White)
    .borderRadius(12)
    .border({
      width: this.selectedTool?.name === tool.name ? 2 : 1,
      color: this.selectedTool?.name === tool.name ? $r('app.color.primary_color') : $r('app.color.border_color')
    })
  }

  /**
   * 获取工具配置对象
   */
  private getToolConfig(toolName: string): MCPToolConfig | undefined {
    return this.toolConfigs.find(config => config.name === toolName);
  }
}