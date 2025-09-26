/**
 * MCP工具测试对话框
 * 用于测试MCP工具的参数配置和执行功能
 */

import { Logger } from '../utils/Logger';
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

interface ToolTestDialogParams {
  tool: MCPTool;
  localToolManager: LocalToolManager;
  onClose: () => void;
}

@ComponentV2
export struct MCPToolTestDialog {
  @Param tool: MCPTool = null!;
  @Param localToolManager: LocalToolManager = null!;
  @Param onClose: () => void = () => {};

  @Local private toolParams: ParamType = {};
  @Local private isExecuting: boolean = false;
  @Local private executionResult: ToolCallResult | null = null;
  @Local private showResult: boolean = false;

  aboutToAppear() {
    Logger.info('MCPToolTestDialog', 'Dialog appeared, setting back press handler');
  }

  aboutToDisappear() {
    Logger.info('MCPToolTestDialog', 'Dialog disappeared');
  }

  onBackPress(): boolean {
    Logger.info('MCPToolTestDialog', 'Back button pressed, closing dialog');
    this.onClose();
    return true; // 返回true表示已处理，阻止事件继续传递
  }

  private getParameterNames(): Array<string> {
    const properties = this.tool.inputSchema.properties || {};
    return Object.keys(properties);
  }

  private getParameterSchema(paramName: string): JSONSchema | undefined {
    const properties = this.tool.inputSchema.properties || {};
    return properties[paramName];
  }

  private resetParams(): void {
    this.toolParams = {} as ParamType;
    this.executionResult = null;
    this.showResult = false;
  }

  private async executeTool(): Promise<void> {
    this.isExecuting = true;
    this.executionResult = null;

    try {
      const request: ToolCallRequest = {
        name: this.tool.name,
        arguments: this.toolParams
      };

      Logger.info('MCPToolTestDialog', `Executing tool: ${this.tool.name}`, JSON.stringify(this.toolParams));

      const result = await this.localToolManager.executeTool(request);
      this.executionResult = result;
      this.showResult = true;

      Logger.info('MCPToolTestDialog', `Tool execution completed: ${this.tool.name}`, JSON.stringify({
        success: !result.isError
      }));

    } catch (error) {
      Logger.error('MCPToolTestDialog', `Tool execution failed: ${this.tool.name}`, error);
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

  build() {
    Column() {
      // 对话框标题栏
      Row() {
        Text('工具测试')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('关闭')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .borderWidth(0)
          .fontColor($r('app.color.text_secondary'))
          .fontSize(16)
          .height(40)
          .width(60)
          .padding({ left: 8, right: 8 })
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .height(64)
      .padding({ left: 20, right: 20 })
      .justifyContent(FlexAlign.SpaceBetween)

      // 工具信息
      Column({ space: 16 }) {
        Text(this.tool.name)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .margin({top: 16})
          .textAlign(TextAlign.Start)

        if (this.tool.description) {
          Text(this.tool.description)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(20)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
      .backgroundColor($r('app.color.input_background'))
      .borderRadius(12)

      Scroll() {
        Column({ space: 24 }) {
          // 参数表单
          if (this.getParameterNames().length > 0) {
            Column({ space: 20 }) {
              Text('参数设置')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .alignSelf(ItemAlign.Start)

              this.buildParameterInputs()
            }
            .width('100%')
            .padding(24)
            .backgroundColor($r('app.color.surface_color'))
            .borderRadius(16)
          }

          // 操作按钮
          Row({ space: 16 }) {
            Button('重置')
              .type(ButtonType.Normal)
              .backgroundColor($r('app.color.input_background'))
              .borderWidth(0)
              .fontColor($r('app.color.text_secondary'))
              .borderRadius(12)
              .fontSize(16)
              .height(52)
              .layoutWeight(1)
              .shadow({
                radius: 2,
                color: Color.Gray,
                offsetX: 0,
                offsetY: 1
              })
              .onClick(() => {
                this.resetParams();
              })

            Button('执行')
              .type(ButtonType.Normal)
              .backgroundColor($r('app.color.primary_color'))
              .borderWidth(0)
              .fontColor(Color.White)
              .borderRadius(12)
              .fontSize(16)
              .height(52)
              .layoutWeight(1)
              .enabled(!this.isExecuting && this.getParameterNames().length > 0)
              .shadow({
                radius: 4,
                color: Color.Gray,
                offsetX: 0,
                offsetY: 2
              })
              .onClick(() => {
                this.executeTool();
              })
          }
          .width('100%')

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
        .padding({ left: 2, right: 2, bottom: 20 })
      }
      .layoutWeight(1)
      .margin({top: 16})
    }
    .width('95%')
    .height('92%')
    .backgroundColor($r('app.color.background_color'))
    .borderRadius(24)
    .shadow({
      radius: 20,
      color: Color.Gray,
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  buildParameterInputs() {
    ForEach(this.getParameterNames(), (paramName: string) => {
      if (this.getParameterSchema(paramName)) {
        this.buildParameterInput(paramName, this.getParameterSchema(paramName));
      }
    });
  }

  @Builder
  buildParameterInput(paramName: string, schema: JSONSchema | undefined) {
    if (schema) {
      Column({ space: 12 }) {
        Column({ space: 8 }) {
          Row() {
            Text(paramName)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({overflow: TextOverflow.Ellipsis})

            if (this.tool.inputSchema.required?.includes(paramName)) {
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
          this.buildEnumSelector(paramName, schema.enum as Array<string>);
        } else if (schema.type === 'boolean') {
          this.buildBooleanToggle(paramName);
        } else if (schema.type === 'number') {
          this.buildNumberInput(paramName, schema);
        } else {
          this.buildTextInput(paramName, schema);
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.input_background'))
      .borderRadius(12)
      .shadow({
        radius: 4,
        color: Color.Gray,
        offsetX: 0,
        offsetY: 1
      })
    }
  }

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
          .height(40)
          .padding({ left: 12, right: 12 })
          .margin({ right: 8, bottom: 8 })
          .onClick(() => {
            this.toolParams[paramName] = option;
          })
      });
    }
    .width('100%')
  }

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
      .height(44)
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

  @Builder
  buildTextInput(paramName: string, schema: JSONSchema) {
    TextInput({
      placeholder: `请输入${paramName}`,
      text: this.toolParams[paramName] as string || ''
    })
      .fontSize(16)
      .backgroundColor(Color.White)
      .borderRadius(8)
      .height(44)
      .padding({ left: 16, right: 16 })
      .border({
        width: 1,
        color: $r('app.color.border_color')
      })
      .onChange((value: string) => {
        if (value.trim()) {
          this.toolParams[paramName] = value;
        } else {
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
            this.showResult = false;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

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
                .padding(12)
                .borderRadius(8)
                .width('100%')
                .textAlign(TextAlign.Start)
                .copyOption(CopyOptions.InApp)
                .lineHeight(20)
                .shadow({
                  radius: 2,
                  color: Color.Gray,
                  offsetX: 0,
                  offsetY: 1
                })
            }
          });
        }
        .width('100%')
      }
      .constraintSize({ minHeight: 80, maxHeight: 160 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .shadow({
      radius: 8,
      color: this.executionResult!.isError ? Color.Red : Color.Green,
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  buildLoadingState() {
    Column({ space: 20 }) {
      LoadingProgress()
        .width(48)
        .height(48)
        .color($r('app.color.primary_color'))

      Text('正在执行工具...')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Text('请稍候，工具正在处理您的请求')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(20)
    }
    .width('100%')
    .height(140)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .shadow({
      radius: 8,
      color: $r('app.color.primary_color'),
      offsetX: 0,
      offsetY: 2
    })
  }
}