/**
 * MCP设置页面
 * 简化的MCP客户端设置界面
 */

import { router } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';
import {
  MCPTool,
  MCPToolConfig,
  ToolStatistics,
} from '../types/MCPTypes';
import { LocalToolManager } from '../services/LocalToolManager';
import { AppContext } from '../utils/AppContext';
import { AIServiceStateManager } from '../utils/AIServiceStateManager';
import { AppStorage, MCPToolsConfig } from '../utils/AppStorage';
import { MCPToolTestDialog } from '../components/MCPToolTestDialog';

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
  @Local private showToolTestDialog: boolean = false;
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

  onBackPress(): boolean {
    // 当弹框显示时，拦截back事件并关闭弹框
    if (this.showToolTestDialog) {
      Logger.info('MCPSettingsPage', 'Back pressed while dialog is open, closing dialog');
      this.closeToolTestDialog();
      return true; // 阻止默认的back行为
    }
    return false; // 允许默认的back行为（返回上一页）
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
      // 加载所有注册的工具（包括禁用的）- 只在初始化时加载一次
      if (this.availableTools.length === 0) {
        this.availableTools = this.localToolManager.getAllRegisteredTools();
      }

      // 加载工具配置和统计信息
      this.toolConfigs = await this.localToolManager.getAllToolConfigs();
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
      // 只更新必要的工具配置和统计信息，避免完整页面重载
      if (this.localToolManager) {
        this.toolConfigs = await this.localToolManager.getAllToolConfigs();
        this.toolStatistics = await this.localToolManager.getToolStatistics();
      }
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

    try {
      const result = await this.localToolManager.setToolEnabled(toolName, enabled);

      if (result.success) {
        Logger.info('MCPSettingsPage', `工具 ${toolName} 状态更新成功: ${enabled}`);
        // 只更新工具配置，避免完整页面重载
        this.toolConfigs = await this.localToolManager.getAllToolConfigs();
        this.toolStatistics = await this.localToolManager.getToolStatistics();
      } else {
        Logger.error('MCPSettingsPage', `工具 ${toolName} 状态更新失败: ${result.error}`);
      }
    } catch (error) {
      Logger.error('MCPSettingsPage', `设置工具状态失败: ${error}`);
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
        // 只更新工具配置，避免完整页面重载
        this.toolConfigs = await this.localToolManager.getAllToolConfigs();
        this.toolStatistics = await this.localToolManager.getToolStatistics();
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
        // 只更新工具配置，避免完整页面重载
        this.toolConfigs = await this.localToolManager.getAllToolConfigs();
        this.toolStatistics = await this.localToolManager.getToolStatistics();
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
   * 打开工具测试对话框
   */
  private openToolTestDialog(tool: MCPTool): void {
    Logger.info('MCPSettingsPage', `Opening test dialog for tool: ${tool.name}`);
    this.selectedTool = tool;
    this.showToolTestDialog = true;
  }

  /**
   * 关闭工具测试对话框
   */
  private closeToolTestDialog(): void {
    this.showToolTestDialog = false;
    this.selectedTool = null;
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏 - 添加状态栏高度避让
        this.buildNavigationBar()

        // MCP控制区域 - 始终在页面上方
        this.buildMCPControlSection()

        Scroll() {
          Column({ space: 24 }) {
            this.buildMCPToolsSection()
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_color'))
      .margin({ top: 16, bottom: 8 })

      // 工具测试对话框
      if (this.showToolTestDialog && this.selectedTool) {
        this.buildToolTestDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  private resetParams(): void {
    // For dialog state reset
    this.showToolTestDialog = false;
    this.selectedTool = null;
  }

  // 工具测试对话框在需要时通过状态管理显示
  private showToolTestDialogInternal(): void {
    if (this.showToolTestDialog && this.selectedTool) {
      this.buildToolTestDialog()
    }
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
      .width(44)
      .height(44)
      .borderRadius(22)
      .onClick(() => {
        router.back();
      })
      .expandSafeArea([SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.START])

      Text('MCP Settings')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .margin({top: 20})
        .expandSafeArea([SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.START])

      Blank()
        .width(48)
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.SpaceBetween)
    .expandSafeArea([SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.START])
  }

  @Builder
  buildMCPControlSection() {
    Column({ space: 20 }) {
      Text('MCP 工具控制')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)

      Row({ space: 16 }) {
        Text('启用 MCP 工具')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .lineHeight(22)

        Toggle({ type: ToggleType.Switch, isOn: this.mcpEnabled })
          .width(52)
          .height(32)
          .onChange((isOn: boolean) => {
            this.mcpEnabled = isOn;
            this.saveMCPState(isOn);
            Logger.info('MCPSettingsPage', `MCP tools ${isOn ? 'enabled' : 'disabled'}`);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      if (this.mcpEnabled) {
        Text('MCP 工具已启用，可以在对话中使用本地工具功能')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      } else {
        Text('MCP 工具已禁用，本地工具功能不可用')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      }
    }
    .width('95%')
    .padding(24)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .shadow({
      radius: 8,
      color: Color.Gray,
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildMCPToolsSection() {
    if (this.mcpEnabled) {
      Column({ space: 24 }) {
        // 搜索和分类筛选
        Column({ space: 20 }) {
          Text('工具管理')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .alignSelf(ItemAlign.Start)

          // 搜索框
          TextInput({
            placeholder: '搜索工具...',
            text: this.searchText
          })
            .fontSize(16)
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(12)
            .height(52)
            .padding({ left: 20, right: 20 })
            .shadow({
              radius: 4,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 1
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
                  $r('app.color.primary_color') : $r('app.color.input_background'))
                .fontColor(this.selectedCategory === category.key ?
                  Color.White : $r('app.color.text_secondary'))
                .borderWidth(0)
                .borderRadius(20)
                .fontSize(14)
                .height(40)
                .padding({ left: 18, right: 18 })
                .margin({ right: 10, bottom: 10 })
                .shadow({
                  radius: this.selectedCategory === category.key ? 6 : 2,
                  color: Color.Gray,
                  offsetX: 0,
                  offsetY: this.selectedCategory === category.key ? 2 : 1
                })
                .onClick(() => {
                  this.selectedCategory = category.key;
                })
            });
          }
          .width('100%')
        }
        .width('100%')
        .padding(24)
        .backgroundColor($r('app.color.surface_color'))
        .borderRadius(16)
        .shadow({
          radius: 8,
          color: Color.Gray,
          offsetX: 0,
          offsetY: 2
        })

        // 批量操作按钮
        this.buildBatchOperationsSection()

        // 工具列表
        if (this.getFilteredTools().length > 0) {
          Column({ space: 20 }) {
            Row({ space: 16 }) {
              Text(`工具列表 (${this.getFilteredTools().length})`)
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)

              if (this.showStatistics && this.toolStatistics) {
                Button('隐藏统计')
                  .type(ButtonType.Normal)
                  .backgroundColor($r('app.color.input_background'))
                  .borderWidth(0)
                  .fontColor($r('app.color.text_secondary'))
                  .fontSize(14)
                  .height(36)
                  .padding({ left: 16, right: 16 })
                  .borderRadius(18)
                  .shadow({
                    radius: 2,
                    color: Color.Gray,
                    offsetX: 0,
                    offsetY: 1
                  })
                  .onClick(() => {
                    this.showStatistics = false;
                  })
              } else {
                Button('显示统计')
                  .type(ButtonType.Normal)
                  .backgroundColor($r('app.color.primary_color'))
                  .borderWidth(0)
                  .fontColor(Color.White)
                  .fontSize(14)
                  .height(36)
                  .padding({ left: 16, right: 16 })
                  .borderRadius(18)
                  .shadow({
                    radius: 4,
                    color: Color.Gray,
                    offsetX: 0,
                    offsetY: 2
                  })
                  .onClick(() => {
                    this.showStatistics = true;
                  })
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            // 工具统计信息
            if (this.showStatistics && this.toolStatistics) {
              this.buildStatisticsSection()
            }

            ForEach(this.getFilteredTools(), (tool: MCPTool) => {
              this.buildToolItemWithSwitch(tool)
            });
          }
          .width('100%')
          .padding(24)
          .backgroundColor($r('app.color.surface_color'))
          .borderRadius(16)
          .shadow({
            radius: 8,
            color: Color.Gray,
            offsetX: 0,
            offsetY: 2
          })
        }

        }
      .width('100%')
      .padding({top: 16, bottom: 16, left: 2, right: 2})
      .borderRadius(12)
    }
  }

  
  /**
   * 构建批量操作区域
   */
  @Builder
  buildBatchOperationsSection() {
    Column({ space: 20 }) {
      Text('批量操作')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)

      Row({ space: 16 }) {
        Button('启用')
          .type(ButtonType.Normal)
          .backgroundColor($r('app.color.primary_color'))
          .fontColor(Color.White)
          .borderRadius(12)
          .fontSize(15)
          .height(44)
          .layoutWeight(1)
          .enabled(!this.isUpdatingTools)
          .shadow({
            radius: 4,
            color: Color.Gray,
            offsetX: 0,
            offsetY: 2
          })
          .onClick(() => {
            this.enableAllTools();
          })

        Button('禁用')
          .type(ButtonType.Normal)
          .backgroundColor($r('app.color.input_background'))
          .borderWidth(0)
          .fontColor($r('app.color.text_secondary'))
          .borderRadius(12)
          .fontSize(15)
          .height(44)
          .layoutWeight(1)
          .enabled(!this.isUpdatingTools)
          .shadow({
            radius: 2,
            color: Color.Gray,
            offsetX: 0,
            offsetY: 1
          })
          .onClick(() => {
            this.disableAllTools();
          })

        Button('刷新')
          .type(ButtonType.Normal)
          .backgroundColor($r('app.color.primary_color'))
          .borderWidth(0)
          .fontColor(Color.White)
          .borderRadius(12)
          .fontSize(15)
          .height(44)
          .padding({ left: 20, right: 20 })
          .enabled(!this.isUpdatingTools)
          .shadow({
            radius: 4,
            color: Color.Gray,
            offsetX: 0,
            offsetY: 2
          })
          .onClick(() => {
            this.refreshData();
          })
      }
      .width('100%')

      if (this.isUpdatingTools) {
        Row({ space: 12 }) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color($r('app.color.primary_color'))

          Text('正在更新工具状态...')
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(20)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .padding({ top: 12, bottom: 12 })
      }
    }
    .width('100%')
    .padding(28)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .shadow({
      radius: 8,
      color: Color.Gray,
      offsetX: 0,
      offsetY: 2
    })
  }

  /**
   * 构建统计信息区域
   */
  @Builder
  buildStatisticsSection() {
    if (this.toolStatistics) {
      Column({ space: 20 }) {
        Text('工具统计')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .alignSelf(ItemAlign.Start)

        Row({ space: 16 }) {
          Column({ space: 8 }) {
            Text(`${this.toolStatistics.totalTools}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            Text('总工具数')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Center)

          Column({ space: 8 }) {
            Text(`${this.toolStatistics.enabledTools}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#4CAF50')

            Text('已启用')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Center)

          Column({ space: 8 }) {
            Text(`${this.toolStatistics.disabledTools}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F44336')

            Text('已禁用')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Center)

          Column({ space: 8 }) {
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
            .margin({ top: 8 })
        }
      }
      .width('100%')
      .padding(24)
      .backgroundColor($r('app.color.input_background'))
      .borderRadius(16)
      .shadow({
        radius: 4,
        color: Color.Gray,
        offsetX: 0,
        offsetY: 1
      })
    }
  }

  /**
   * 构建带开关的工具项
   */
  @Builder
  buildToolItemWithSwitch(tool: MCPTool) {
    Column({ space: 20 }) {
      Row({ space: 16 }) {
        // 左侧工具信息
        Column({ space: 12 }) {
          Row({ space: 16 }) {
            Text(tool.name)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(2)
              .textOverflow({overflow: TextOverflow.Ellipsis})
              .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Center)

          Row({ space: 20 }) {
            Text(`分类: ${this.getCategoryDisplayName(this.getToolCategory(tool.name))}`)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 右侧控制按钮区域
        Column({ space: 12 }) {
          // 工具开关
          Row({ space: 12 }) {
            Text('启用')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))

            Toggle({ type: ToggleType.Switch, isOn: this.getToolConfig(tool.name)?.enabled ?? true })
              .width(52)
              .height(32)
              .onChange((isOn: boolean) => {
                this.setToolEnabled(tool.name, isOn);
              })
          }
          .alignItems(VerticalAlign.Center)

          // 测试按钮
          Button('测试工具')
            .type(ButtonType.Normal)
            .backgroundColor($r('app.color.primary_color'))
            .borderWidth(0)
            .fontColor(Color.White)
            .borderRadius(12)
            .fontSize(14)
            .height(40)
            .padding({ left: 16, right: 16 })
            .enabled(!this.isUpdatingTools)
            .shadow({
              radius: 4,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 2
            })
            .onClick(() => {
              Logger.info('MCPSettingsPage', `Test button clicked for tool: ${tool.name}`);
              Logger.info('MCPSettingsPage', `isUpdatingTools: ${this.isUpdatingTools}`);
              this.openToolTestDialog(tool);
            })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      if (tool.description) {
        Text(tool.description)
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ top: 16 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .shadow({
      radius: 4,
      color: Color.Gray,
      offsetX: 0,
      offsetY: 1
    })
    .margin({ bottom: 8 })
  }

  /**
   * 获取工具配置对象
   */
  private getToolConfig(toolName: string): MCPToolConfig | undefined {
    return this.toolConfigs.find(config => config.name === toolName);
  }

  @Builder
  private buildToolTestDialog(): void {
    MCPToolTestDialog({
      tool: this.selectedTool!,
      localToolManager: this.localToolManager!,
      onClose: () => this.closeToolTestDialog()
    })
  }
}