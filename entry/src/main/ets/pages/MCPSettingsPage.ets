/**
 * MCP设置页面
 * 简化的MCP客户端设置界面
 */

import { router } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';
import { MCPToolsComponent } from '../components/MCPToolsComponent';

@Entry
@ComponentV2
struct MCPSettingsPage {
  @Local private mcpStatus: string = 'Disconnected';
  @Local private showMCPTools: boolean = false;

  aboutToAppear(): void {
    Logger.info('MCPSettingsPage', 'MCP Settings page initialized');
  }

  build() {
    Column() {
      this.buildNavigationBar()

      Scroll() {
        Column({ space: 16 }) {
          this.buildStatusCard()
          this.buildConnectionSettings()
          this.buildMCPToolsSection()
          this.buildInfoCard()
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
  buildStatusCard() {
    Column({ space: 12 }) {
      Text('连接状态')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)

      Row({ space: 12 }) {
        Circle({ width: 12, height: 12 })
          .fill(this.mcpStatus === 'Connected' ? Color.Green : Color.Red)

        Text(this.mcpStatus)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
  }

  @Builder
  buildConnectionSettings() {
    Column({ space: 16 }) {
      Text('连接设置')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)

      Button() {
        Text('连接 MCP 服务器')
          .fontSize(16)
          .fontColor(Color.White)
      }
      .type(ButtonType.Normal)
      .backgroundColor($r('app.color.primary_color'))
      .borderRadius(8)
      .height(48)
      .width('100%')
      .onClick(() => {
        this.connectToMCP();
      })

      Button() {
        Text('断开连接')
          .fontSize(16)
          .fontColor('#F44336')
      }
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .borderWidth(1)
      .borderColor('#F44336')
      .borderRadius(8)
      .height(48)
      .width('100%')
      .onClick(() => {
        this.disconnectFromMCP();
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
  }

  @Builder
  buildMCPToolsSection() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Text('MCP 工具箱')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Button() {
          Text(this.showMCPTools ? '收起' : '展开')
            .fontSize(14)
            .fontColor(this.showMCPTools ? $r('app.color.text_secondary') : $r('app.color.primary_color'))
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .borderWidth(1)
        .borderColor(this.showMCPTools ? $r('app.color.border_color') : $r('app.color.primary_color'))
        .borderRadius(6)
        .height(32)
        .onClick(() => {
          this.showMCPTools = !this.showMCPTools;
        })
      }
      .width('100%')

      if (this.showMCPTools) {
        Column() {
          MCPToolsComponent({
            onClose: () => {
              this.showMCPTools = false;
            }
          })
        }
        .width('100%')
        .height(400)
        .borderRadius(12)
        .border({
          width: 1,
          color: $r('app.color.border_color')
        })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
  }

  @Builder
  buildInfoCard() {
    Column({ space: 12 }) {
      Text('关于 MCP')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)

      Text('Model Context Protocol (MCP) 是一个标准化的协议，用于大语言模型与外部系统的集成。通过 MCP，AI 可以访问各种工具和服务。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(20)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
  }

  private connectToMCP(): void {
    Logger.info('MCPSettingsPage', 'Connecting to MCP server...');
    this.mcpStatus = 'Connecting...';

    setTimeout(() => {
      this.mcpStatus = 'Connected';
      Logger.info('MCPSettingsPage', 'Connected to MCP server');
    }, 1000);
  }

  private disconnectFromMCP(): void {
    Logger.info('MCPSettingsPage', 'Disconnecting from MCP server...');
    this.mcpStatus = 'Disconnected';
  }
}