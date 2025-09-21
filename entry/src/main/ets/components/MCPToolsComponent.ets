import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  JSONSchema,
  ParamType,
  TextContent,
  ImageContent
} from '../types/MCPTypes';
import { LocalToolManager } from '../services/LocalToolManager';
import { Logger } from '../utils/Logger';
import { ThemeManager } from '../utils/ThemeManager';

interface ToolCategoryInfo {
  key: string;
  name: string;
  count: number;
}

/**
 * MCP工具组件
 * 提供本地MCP工具的可视化界面和调用功能
 */
@ComponentV2
export struct MCPToolsComponent {
  @Local private availableTools: Array<MCPTool> = [];
  @Local private selectedTool: MCPTool | null = null;
  @Local private toolParams: ParamType = {};
  @Local private isExecuting: boolean = false;
  @Local private executionResult: ToolCallResult | null = null;
  @Local private showResult: boolean = false;
  @Local private searchText: string = '';
  @Local private selectedCategory: string = 'all';

  @Param onToolExecuted?: (result: ToolCallResult) => void = () => {};
  @Param onClose?: () => void = () => {};

  private localToolManager: LocalToolManager | null = null;

  aboutToAppear(): void {
    try {
      this.localToolManager = LocalToolManager.getInstance();
      this.loadAvailableTools();
      Logger.info('MCPToolsComponent', 'MCP tools component initialized');
    } catch (error) {
      Logger.error('MCPToolsComponent', 'Failed to initialize', error);
    }
  }

  /**
   * 加载可用工具
   */
  private loadAvailableTools(): void {
    if (this.localToolManager) {
      this.availableTools = this.localToolManager.getAvailableTools();
      Logger.info('MCPToolsComponent', `Loaded ${this.availableTools.length} tools`);
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

      Logger.info('MCPToolsComponent', `Executing tool: ${this.selectedTool.name}`, JSON.stringify(this.toolParams));

      const result = await this.localToolManager.executeTool(request);
      this.executionResult = result;
      this.showResult = true;

      // 通知父组件
      if (this.onToolExecuted) {
        this.onToolExecuted(result);
      }

      Logger.info('MCPToolsComponent', `Tool execution completed: ${this.selectedTool.name}`, JSON.stringify({
        success: !result.isError
      }));

    } catch (error) {
      Logger.error('MCPToolsComponent', `Tool execution failed: ${this.selectedTool.name}`, error);
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

  /**
   * 渲染参数输入表单
   */
  @Builder
  buildParameterForm() {
    if (this.selectedTool) {
      Column({ space: 12 }) {
        Text('参数设置')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .alignSelf(ItemAlign.Start)

        this.buildParameterInputs()

        Row({ space: 12 }) {
          Button('重置')
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .borderWidth(1)
            .borderColor($r('app.color.border_color'))
            .fontColor($r('app.color.text_secondary'))
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .onClick(() => {
              this.resetParams();
            })

          Button('执行')
            .type(ButtonType.Normal)
            .backgroundColor($r('app.color.primary_color'))
            .fontColor(Color.White)
            .borderRadius(8)
            .height(40)
            .layoutWeight(1)
            .enabled(!this.isExecuting)
            .onClick(() => {
              this.executeTool();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
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
      Column({ space: 8 }) {
        Row() {
          Text(paramName)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))

          if (this.selectedTool?.inputSchema.required?.includes(paramName)) {
            Text(' *')
              .fontSize(14)
              .fontColor('#F44336')
          }

          Blank()

          if (schema.description) {
            Text(schema.description)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')

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
    }
  }

  /**
   * 构建枚举选择器
   */
  @Builder
  buildEnumSelector(paramName: string, options: Array<string>) {
    Row({ space: 8 }) {
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
          .borderRadius(6)
          .fontSize(12)
          .height(32)
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
        .onChange((isOn: boolean) => {
          this.toolParams[paramName] = isOn;
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
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
      .fontSize(14)
      .backgroundColor($r('app.color.input_background'))
      .borderRadius(8)
      .height(40)
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
      placeholder: schema.description || `输入${paramName}`,
      text: this.toolParams[paramName] as string || ''
    })
      .fontSize(14)
      .backgroundColor($r('app.color.input_background'))
      .borderRadius(8)
      .height(40)
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

  build() {
    Column() {
      // 头部标题栏
      Row() {
        Text('MCP 工具箱')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        if (this.onClose) {
          Button() {
            Text('✕')
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
          }
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(32)
          .height(32)
          .onClick(() => {
            if (this.onClose) {
              this.onClose();
            }
          })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .border({
        width: { bottom: 1 },
        color: $r('app.color.border_color')
      })

      Scroll() {
        Column({ space: 16 }) {
          // 搜索和分类筛选
          Column({ space: 12 }) {
            // 搜索框
            TextInput({
              placeholder: '搜索工具...',
              text: this.searchText
            })
              .fontSize(14)
              .backgroundColor($r('app.color.input_background'))
              .borderRadius(8)
              .height(40)
              .onChange((value: string) => {
                this.searchText = value;
              })

            // 分类标签
            Row({ space: 8 }) {
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
                  .fontSize(12)
                  .height(32)
                  .onClick(() => {
                    this.selectedCategory = category.key;
                  })
              });
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface_color'))
          .borderRadius(12)

          // 工具列表
          Column({ space: 8 }) {
            Text(`可用工具 (${this.getFilteredTools().length})`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .alignSelf(ItemAlign.Start)

            ForEach(this.getFilteredTools(), (tool: MCPTool) => {
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(tool.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .alignSelf(ItemAlign.Start)

                  if (tool.description) {
                    Text(tool.description)
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .alignSelf(ItemAlign.Start)
                  }

                  Text(`分类: ${this.getCategoryDisplayName(this.getToolCategory(tool.name))}`)
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                    .alignSelf(ItemAlign.Start)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Button('选择')
                  .type(ButtonType.Normal)
                  .backgroundColor(this.selectedTool?.name === tool.name ?
                    $r('app.color.primary_color') : Color.Transparent)
                  .fontColor(this.selectedTool?.name === tool.name ?
                    Color.White : $r('app.color.primary_color'))
                  .borderWidth(1)
                  .borderColor($r('app.color.primary_color'))
                  .borderRadius(6)
                  .fontSize(12)
                  .height(32)
                  .onClick(() => {
                    this.selectedTool = tool;
                    this.resetParams();
                  })
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.selectedTool?.name === tool.name ?
                $r('app.color.surface_color') : $r('app.color.background_color'))
              .borderRadius(8)
              .border({
                width: 1,
                color: this.selectedTool?.name === tool.name ?
                  $r('app.color.primary_color') : $r('app.color.border_color')
              })
            });
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface_color'))
          .borderRadius(12)

          // 参数表单
          if (this.selectedTool) {
            this.buildParameterForm();
          }

          // 执行结果
          if (this.showResult && this.executionResult) {
            Column({ space: 12 }) {
              Row() {
                Text('执行结果')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Button('关闭')
                  .type(ButtonType.Normal)
                  .backgroundColor(Color.Transparent)
                  .fontColor($r('app.color.text_secondary'))
                  .fontSize(12)
                  .height(32)
                  .onClick(() => {
                    this.showResult = false;
                  })
              }
              .width('100%')

              Scroll() {
                Column({ space: 8 }) {
                  ForEach(this.executionResult!.content, (content: TextContent | ImageContent) => {
                    if (content.type === 'text' && (content as TextContent).text) {
                      Text((content as TextContent).text)
                        .fontSize(12)
                        .fontColor(this.executionResult!.isError ?
                          '#F44336' : $r('app.color.text_primary'))
                        .backgroundColor(this.executionResult!.isError ?
                          '#FFF5F5' : $r('app.color.code_background'))
                        .padding(8)
                        .borderRadius(6)
                        .width('100%')
                        .textAlign(TextAlign.Start)
                        .copyOption(CopyOptions.InApp)
                    }
                  });
                }
                .width('100%')
              }
              .height(200)
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.surface_color'))
            .borderRadius(12)
            .border({
              width: 1,
              color: this.executionResult.isError ? '#F44336' : $r('app.color.border_color')
            })
          }

          // 加载状态
          if (this.isExecuting) {
            Column({ space: 12 }) {
              LoadingProgress()
                .width(32)
                .height(32)
                .color($r('app.color.primary_color'))

              Text('正在执行工具...')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .height(100)
            .justifyContent(FlexAlign.Center)
            .backgroundColor($r('app.color.surface_color'))
            .borderRadius(12)
          }
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
}

export default MCPToolsComponent;