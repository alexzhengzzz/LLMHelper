/**
 * 服务器设置页面 - 简化重写版本
 * 专注于核心功能，避免复杂的状态管理
 */

import { router } from '@kit.ArkUI';
import { ServerConfigManager, ServerEndpoint } from '../utils/ServerConfigManager';
import { Logger } from '../utils/Logger';

@Entry
@ComponentV2
struct ServerSettingsPage {
  // 基础状态变量
  @Local serverIp: string = '';
  @Local serverPort: string = '8080';
  @Local serverProtocol: 'http' | 'https' = 'http';
  @Local isLoading: boolean = false;
  @Local statusBarHeight: number = 44;
  
  // 错误状态
  @Local errorMessage: string = '';
  @Local successMessage: string = '';
  
  // 当前服务器信息显示
  @Local currentServerInfo: string = '';

  private serverConfigManager: ServerConfigManager = ServerConfigManager.getInstance();

  async aboutToAppear(): Promise<void> {
    Logger.info('ServerSettingsPage', '页面初始化');
    await this.loadCurrentServerInfo();
  }

  /**
   * 加载当前服务器信息
   */
  private async loadCurrentServerInfo(): Promise<void> {
    try {
      await this.serverConfigManager.initialize();
      const currentServer = this.serverConfigManager.getCurrentServer();
      
      if (currentServer) {
        this.currentServerInfo = `${currentServer.protocol}://${currentServer.ip}:${currentServer.port}`;
        // 设置输入框的初始值为当前服务器配置
        this.serverIp = currentServer.ip;
        this.serverPort = currentServer.port.toString();
        this.serverProtocol = currentServer.protocol;
      } else {
        this.currentServerInfo = '未配置';
      }
      
      Logger.info('ServerSettingsPage', `当前服务器: ${this.currentServerInfo}`);
    } catch (error) {
      Logger.error('ServerSettingsPage', `加载服务器信息失败: ${error}`);
      this.currentServerInfo = '加载失败';
    }
  }

  /**
   * 保存服务器配置
   */
  private async saveServerConfig(): Promise<void> {
    // 清除之前的消息
    this.errorMessage = '';
    this.successMessage = '';
    
    // 验证输入
    if (!this.validateInput()) {
      return;
    }
    
    this.isLoading = true;
    
    try {
      const newEndpoint: ServerEndpoint = {
        ip: this.serverIp.trim(),
        port: parseInt(this.serverPort),
        protocol: this.serverProtocol,
        wsProtocol: this.serverProtocol === 'https' ? 'wss' : 'ws',
        description: '用户自定义服务器'
      };
      
      // 更新服务器配置
      await this.serverConfigManager.setCurrentServer(newEndpoint);
      
      // 更新显示信息
      this.currentServerInfo = `${newEndpoint.protocol}://${newEndpoint.ip}:${newEndpoint.port}`;
      this.successMessage = '服务器配置保存成功！';
      
      Logger.info('ServerSettingsPage', `服务器配置已更新: ${this.currentServerInfo}`);
      
      // 测试连接
      setTimeout(() => {
        this.testConnection();
      }, 500);
      
    } catch (error) {
      Logger.error('ServerSettingsPage', `保存服务器配置失败: ${error}`);
      this.errorMessage = `保存失败: ${(error as Error).message}`;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 测试服务器连接
   */
  private async testConnection(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    this.successMessage = '';
    
    try {
      const endpoint: ServerEndpoint = {
        ip: this.serverIp.trim(),
        port: parseInt(this.serverPort),
        protocol: this.serverProtocol,
        wsProtocol: this.serverProtocol === 'https' ? 'wss' : 'ws'
      };
      
      const result = await this.serverConfigManager.validateServer(endpoint);
      
      if (result.success) {
        const responseTime = result.responseTime || 0;
        this.successMessage = `连接成功！响应时间: ${responseTime}ms`;
      } else {
        this.errorMessage = `连接失败: ${result.errorMessage}`;
      }
      
    } catch (error) {
      Logger.error('ServerSettingsPage', `测试连接失败: ${error}`);
      this.errorMessage = `测试失败: ${(error as Error).message}`;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 验证输入
   */
  private validateInput(): boolean {
    // 验证IP地址
    const ip = this.serverIp.trim();
    if (!ip) {
      this.errorMessage = 'IP地址不能为空';
      return false;
    }
    
    if (!this.serverConfigManager.validateIpFormat(ip)) {
      this.errorMessage = 'IP地址格式不正确';
      return false;
    }
    
    // 验证端口
    const port = parseInt(this.serverPort);
    if (isNaN(port) || !this.serverConfigManager.validatePort(port)) {
      this.errorMessage = '端口范围: 1-65535';
      return false;
    }
    
    return true;
  }

  /**
   * 重置为默认配置
   */
  private async resetToDefault(): Promise<void> {
    // 从ServerConfigManager获取默认配置
    await this.serverConfigManager.resetToDefault();
    const defaultServer = this.serverConfigManager.getCurrentServer();
    
    this.serverIp = defaultServer.ip;
    this.serverPort = defaultServer.port.toString();
    this.serverProtocol = defaultServer.protocol;
    this.errorMessage = '';
    this.successMessage = '已重置为默认配置';
    
    // 更新当前服务器信息显示
    this.currentServerInfo = `${defaultServer.protocol}://${defaultServer.ip}:${defaultServer.port}`;
  }

  /**
   * 返回上一页
   */
  private goBack(): void {
    router.back();
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button('← 返回')
          .fontSize(16)
          .backgroundColor(Color.Transparent)
          .fontColor('#007AFF')
          .onClick(() => this.goBack())

        Blank()

        Text('服务器设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#000000')

        Blank()

        // 占位保持居中
        Text('')
          .width(80)
      }
      .width('100%')
      .height(64)
      .padding({ left: 20, right: 20 })
      .backgroundColor('#F8F8F8')
      .margin({ top: this.statusBarHeight })

      // 主要内容
      Scroll() {
        Column() {
          // 当前服务器信息
          Column() {
            Text('当前服务器')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .width('100%')
              .margin({ bottom: 8 })

            Text(this.currentServerInfo)
              .fontSize(14)
              .fontColor('#666666')
              .width('100%')
              .backgroundColor('#F0F0F0')
              .padding(12)
              .borderRadius(8)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .margin({ bottom: 24 })

          // 服务器地址配置
          Column() {
            Text('服务器地址')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .width('100%')
              .margin({ bottom: 12 })

            // 协议选择
            Row() {
              Text('协议:')
                .fontSize(14)
                .fontColor('#333333')
                .width(60)

              Select([
                { value: 'HTTP' },
                { value: 'HTTPS' }
              ])
                .value(this.serverProtocol === 'http' ? 'HTTP' : 'HTTPS')
                .width(100)
                .height(40)
                .font({ size: 14 })
                .onSelect((index: number) => {
                  this.serverProtocol = index === 0 ? 'http' : 'https';
                })

              Blank()
            }
            .width('100%')
            .margin({ bottom: 12 })

            // IP地址输入
            Row() {
              Text('IP:')
                .fontSize(14)
                .fontColor('#333333')
                .width(60)

              TextInput({ text: this.serverIp, placeholder: '请输入服务器IP地址' })
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .onChange((value: string) => {
                  this.serverIp = value;
                  this.errorMessage = '';
                  this.successMessage = '';
                })
            }
            .width('100%')
            .margin({ bottom: 12 })

            // 端口输入
            Row() {
              Text('端口:')
                .fontSize(14)
                .fontColor('#333333')
                .width(60)

              TextInput({ text: this.serverPort, placeholder: '8080' })
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .type(InputType.Number)
                .onChange((value: string) => {
                  this.serverPort = value;
                  this.errorMessage = '';
                  this.successMessage = '';
                })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // 完整地址预览
            Text(`完整地址: ${this.serverProtocol}://${this.serverIp}:${this.serverPort}`)
              .fontSize(12)
              .fontColor('#999999')
              .width('100%')
              .margin({ bottom: 16 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 16 })

          // 错误和成功消息
          if (this.errorMessage) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor('#FF3B30')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 16 })
          }

          if (this.successMessage) {
            Text(this.successMessage)
              .fontSize(14)
              .fontColor('#34C759')
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 16 })
          }

          // 操作按钮
          Column() {
            Button('保存配置')
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontColor(Color.White)
              .backgroundColor('#007AFF')
              .borderRadius(8)
              .enabled(!this.isLoading)
              .margin({ bottom: 12 })
              .onClick(() => this.saveServerConfig())

            Button('测试连接')
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontColor('#007AFF')
              .backgroundColor(Color.Transparent)
              .borderWidth(1)
              .borderColor('#007AFF')
              .borderRadius(8)
              .enabled(!this.isLoading)
              .margin({ bottom: 12 })
              .onClick(() => this.testConnection())

            Button('重置为默认')
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontColor('#FF3B30')
              .backgroundColor(Color.Transparent)
              .borderWidth(1)
              .borderColor('#FF3B30')
              .borderRadius(8)
              .enabled(!this.isLoading)
              .onClick(() => this.resetToDefault())
          }
          .width('100%')

          // 加载指示器
          if (this.isLoading) {
            Row() {
              LoadingProgress()
                .width(24)
                .height(24)
                .color('#007AFF')
                .margin({ right: 8 })

              Text('处理中...')
                .fontSize(14)
                .fontColor('#007AFF')
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .margin({ top: 16 })
          }

          // 使用说明
          Column() {
            Text('使用说明')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
              .width('100%')
              .margin({ bottom: 8 })

            Text('• 支持HTTP和HTTPS协议\n• 支持IP地址和域名\n• 默认端口为8080\n• 保存后会自动测试连接')
              .fontSize(12)
              .fontColor('#999999')
              .width('100%')
              .lineHeight(20)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor('#F8F8F8')
          .borderRadius(12)
          .margin({ top: 24 })
        }
        .padding({ left: 20, right: 20, top: 20, bottom: 40 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}