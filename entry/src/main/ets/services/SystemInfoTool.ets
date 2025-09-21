import { deviceInfo } from '@kit.BasicServicesKit';
import { bundleManager } from '@kit.AbilityKit';
import { connection } from '@kit.NetworkKit';
import { battery } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  TextContent,
  JSONSchema
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';
import { ThemeManager } from '../utils/ThemeManager';
import { AppStorage } from '../utils/AppStorage';

/**
 * 系统信息工具
 * 提供设备信息、应用状态、网络状态等系统信息访问
 */
export class SystemInfoTool {
  private static readonly TOOLS: Array<MCPTool> = [
    {
      name: 'get_device_info',
      description: '获取设备基本信息',
      inputSchema: {
        type: 'object',
        properties: {
          include_sensitive: {
            type: 'boolean',
            description: '是否包含敏感信息（如序列号）',
            default: false
          }
        }
      }
    },
    {
      name: 'get_app_info',
      description: '获取应用信息和配置',
      inputSchema: {
        type: 'object',
        properties: {
          include_storage: {
            type: 'boolean',
            description: '是否包含存储使用情况',
            default: true
          }
        }
      }
    },
    {
      name: 'get_network_status',
      description: '获取网络连接状态',
      inputSchema: {
        type: 'object',
        properties: {
          detailed: {
            type: 'boolean',
            description: '是否返回详细网络信息',
            default: false
          }
        }
      }
    },
    {
      name: 'get_battery_info',
      description: '获取电池状态信息',
      inputSchema: {
        type: 'object',
        properties: {}
      }
    },
    {
      name: 'get_display_info',
      description: '获取显示屏信息',
      inputSchema: {
        type: 'object',
        properties: {}
      }
    },
    {
      name: 'get_app_settings',
      description: '获取应用设置和偏好',
      inputSchema: {
        type: 'object',
        properties: {
          category: {
            type: 'string',
            enum: ['theme', 'font', 'api', 'voice', 'all'],
            description: '设置类别',
            default: 'all'
          }
        }
      }
    },
    {
      name: 'get_runtime_stats',
      description: '获取应用运行时统计信息',
      inputSchema: {
        type: 'object',
        properties: {}
      }
    }
  ];

  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    Logger.info('SystemInfoTool', 'System info tool initialized');
  }

  /**
   * 获取所有工具定义
   */
  getTools(): Array<MCPTool> {
    return SystemInfoTool.TOOLS;
  }

  /**
   * 执行工具调用
   */
  async executeCall(request: ToolCallRequest): Promise<ToolCallResult> {
    try {
      Logger.info('SystemInfoTool', `Executing tool: ${request.name}`, request.arguments);

      switch (request.name) {
        case 'get_device_info':
          return await this.getDeviceInfo(request.arguments);
        case 'get_app_info':
          return await this.getAppInfo(request.arguments);
        case 'get_network_status':
          return await this.getNetworkStatus(request.arguments);
        case 'get_battery_info':
          return await this.getBatteryInfo(request.arguments);
        case 'get_display_info':
          return await this.getDisplayInfo(request.arguments);
        case 'get_app_settings':
          return await this.getAppSettings(request.arguments);
        case 'get_runtime_stats':
          return await this.getRuntimeStats(request.arguments);
        default:
          throw new Error(`Unknown tool: ${request.name}`);
      }
    } catch (error) {
      Logger.error('SystemInfoTool', `Tool execution failed: ${request.name}`, error);
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
   * 获取设备信息
   */
  private async getDeviceInfo(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const includeSensitive = (args.include_sensitive as boolean) || false;

    try {
      const info = {
        // 基本设备信息
        deviceType: deviceInfo.deviceType,
        manufacture: deviceInfo.manufacture,
        brand: deviceInfo.brand,
        marketName: deviceInfo.marketName,
        productSeries: deviceInfo.productSeries,
        productModel: deviceInfo.productModel,
        softwareModel: deviceInfo.softwareModel,

        // 系统信息
        osFullName: deviceInfo.osFullName,
        displayVersion: deviceInfo.displayVersion,
        bootloaderVersion: deviceInfo.bootloaderVersion,
        abiList: deviceInfo.abiList,

        // 安全相关
        securityPatchTag: deviceInfo.securityPatchTag,
        udid: includeSensitive ? deviceInfo.udid : '[HIDDEN]',
        serial: includeSensitive ? deviceInfo.serial : '[HIDDEN]'
      };

      return {
        content: [{
          type: 'text',
          text: `设备信息:\n${JSON.stringify(info, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取设备信息失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取应用信息
   */
  private async getAppInfo(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const includeStorage = (args.include_storage as boolean) !== false;

    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);

      const appInfo = {
        bundleName: bundleInfo.name,
        version: bundleInfo.versionName,
        versionCode: bundleInfo.versionCode,
        minSdkVersion: bundleInfo.minCompatibleVersionCode,
        targetSdkVersion: bundleInfo.targetVersion,
        installTime: new Date(bundleInfo.installTime).toISOString(),
        updateTime: new Date(bundleInfo.updateTime).toISOString(),

        // 应用目录信息
        directories: {
          filesDir: this.context.filesDir,
          cacheDir: this.context.cacheDir,
          tempDir: this.context.tempDir,
          databaseDir: this.context.databaseDir
        }
      };

      if (includeStorage) {
        // 这里可以添加存储使用情况的统计
        const storageInfo = {
          // 注意：实际的存储信息获取需要权限，这里提供模拟数据
          estimatedUsage: 'Storage information requires additional permissions'
        };
        (appInfo as Record<string, ESObject>)['storage'] = storageInfo;
      }

      return {
        content: [{
          type: 'text',
          text: `应用信息:\n${JSON.stringify(appInfo, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取应用信息失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取网络状态
   */
  private async getNetworkStatus(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const detailed = (args.detailed as boolean) || false;

    try {
      const netHandle = await connection.getDefaultNet();
      const netCapabilities = await connection.getNetCapabilities(netHandle);
      const netConnection = await connection.getConnectionProperties(netHandle);

      const networkInfo = {
        connected: true,
        networkType: this.getNetworkTypeString(netCapabilities.bearerTypes),
        linkUpBandwidth: netCapabilities.linkUpBandwidthKbps,
        linkDownBandwidth: netCapabilities.linkDownBandwidthKbps,
        interfaceName: netConnection.interfaceName,
        mtu: netConnection.mtu
      };

      if (detailed) {
        const detailedInfo = {
          ...networkInfo,
          capabilities: {
            transportTypes: netCapabilities.bearerTypes,
            networkCapabilities: netCapabilities.networkCap,
            linkAddresses: netConnection.linkAddresses,
            dnses: netConnection.dnses,
            routes: netConnection.routes
          }
        };

        return {
          content: [{
            type: 'text',
            text: `网络状态（详细）:\n${JSON.stringify(detailedInfo, null, 2)}`
          }]
        };
      }

      return {
        content: [{
          type: 'text',
          text: `网络状态:\n${JSON.stringify(networkInfo, null, 2)}`
        }]
      };
    } catch (error) {
      // 网络不可用的情况
      return {
        content: [{
          type: 'text',
          text: `网络状态: 未连接或网络不可用\n错误: ${error instanceof Error ? error.message : '未知错误'}`
        }]
      };
    }
  }

  /**
   * 获取电池信息
   */
  private async getBatteryInfo(args: Record<string, ESObject>): Promise<ToolCallResult> {
    try {
      const batteryInfo = {
        batterySOC: battery.batterySOC,
        chargingStatus: this.getChargingStatusString(battery.chargingStatus),
        healthStatus: this.getHealthStatusString(battery.healthStatus),
        pluggedType: this.getPluggedTypeString(battery.pluggedType),
        voltage: battery.voltage,
        technology: battery.technology,
        batteryTemperature: battery.batteryTemperature,
        nowCurrent: battery.nowCurrent,
        remainingChargeTime: battery.remainingChargeTime,
        totalEnergy: battery.totalEnergy,
        nowCurrent: battery.nowCurrent,
        remainingEnergy: battery.remainingEnergy
      };

      return {
        content: [{
          type: 'text',
          text: `电池信息:\n${JSON.stringify(batteryInfo, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取电池信息失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取显示信息
   */
  private async getDisplayInfo(args: Record<string, ESObject>): Promise<ToolCallResult> {
    try {
      const displayInfo = await display.getDefaultDisplaySync();

      const info = {
        id: displayInfo.id,
        name: displayInfo.name,
        width: displayInfo.width,
        height: displayInfo.height,
        densityDPI: displayInfo.densityDPI,
        densityPixels: displayInfo.densityPixels,
        scaledDensity: displayInfo.scaledDensity,
        xDPI: displayInfo.xDPI,
        yDPI: displayInfo.yDPI,
        orientation: this.getOrientationString(displayInfo.orientation),
        state: this.getDisplayStateString(displayInfo.state),
        refreshRate: displayInfo.refreshRate
      };

      return {
        content: [{
          type: 'text',
          text: `显示信息:\n${JSON.stringify(info, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取显示信息失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取应用设置
   */
  private async getAppSettings(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const category = (args.category as string) || 'all';

    try {
      const settings: Record<string, ESObject> = {};

      if (category === 'theme' || category === 'all') {
        settings.theme = {
          currentTheme: ThemeManager.getCurrentTheme(),
          isDarkMode: ThemeManager.isDarkMode()
        };
      }

      if (category === 'font' || category === 'all') {
        const fontSettings = await AppStorage.getFontSettings();
        settings.font = fontSettings;
      }

      if (category === 'api' || category === 'all') {
        const currentModel = await AppStorage.getCurrentModelConfig();
        settings.api = {
          currentModel: currentModel,
          // 不包含敏感的API密钥信息
          hasApiKeys: 'API keys configured (hidden for security)'
        };
      }

      if (category === 'voice' || category === 'all') {
        const ttsSettings = await AppStorage.getAutoTTSSettings();
        settings.voice = ttsSettings;
      }

      return {
        content: [{
          type: 'text',
          text: `应用设置 (${category}):\n${JSON.stringify(settings, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取应用设置失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取运行时统计
   */
  private async getRuntimeStats(args: Record<string, ESObject>): Promise<ToolCallResult> {
    try {
      const stats = {
        timestamp: new Date().toISOString(),
        uptime: Date.now(), // 简化的运行时间

        // 内存信息（需要权限，这里提供估算）
        memory: {
          estimated: 'Memory information requires additional permissions',
          jsHeapSize: 'Available in debug mode'
        },

        // 应用状态
        application: {
          bundleName: this.context.applicationInfo.name,
          processName: this.context.applicationInfo.process || 'main',
          uid: this.context.applicationInfo.uid
        },

        // 运行环境
        runtime: {
          platform: 'HarmonyOS',
          architecture: deviceInfo.abiList[0] || 'unknown'
        }
      };

      return {
        content: [{
          type: 'text',
          text: `运行时统计:\n${JSON.stringify(stats, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取运行时统计失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取网络类型字符串
   */
  private getNetworkTypeString(bearerTypes: Array<number>): string {
    const types: Array<string> = [];
    for (const type of bearerTypes) {
      switch (type) {
        case connection.NetBearType.BEARER_CELLULAR:
          types.push('CELLULAR');
          break;
        case connection.NetBearType.BEARER_WIFI:
          types.push('WIFI');
          break;
        case connection.NetBearType.BEARER_ETHERNET:
          types.push('ETHERNET');
          break;
        default:
          types.push(`UNKNOWN(${type})`);
      }
    }
    return types.join(', ') || 'UNKNOWN';
  }

  /**
   * 获取充电状态字符串
   */
  private getChargingStatusString(status: battery.BatteryChargeState): string {
    switch (status) {
      case battery.BatteryChargeState.NONE:
        return 'NOT_CHARGING';
      case battery.BatteryChargeState.ENABLE:
        return 'CHARGING';
      case battery.BatteryChargeState.DISABLE:
        return 'DISCHARGING';
      case battery.BatteryChargeState.FULL:
        return 'FULL';
      default:
        return 'UNKNOWN';
    }
  }

  /**
   * 获取电池健康状态字符串
   */
  private getHealthStatusString(status: battery.BatteryHealthState): string {
    switch (status) {
      case battery.BatteryHealthState.UNKNOWN:
        return 'UNKNOWN';
      case battery.BatteryHealthState.GOOD:
        return 'GOOD';
      case battery.BatteryHealthState.OVERHEAT:
        return 'OVERHEAT';
      case battery.BatteryHealthState.OVERVOLTAGE:
        return 'OVERVOLTAGE';
      case battery.BatteryHealthState.COLD:
        return 'COLD';
      case battery.BatteryHealthState.DEAD:
        return 'DEAD';
      default:
        return 'UNKNOWN';
    }
  }

  /**
   * 获取充电插头类型字符串
   */
  private getPluggedTypeString(type: battery.BatteryPluggedType): string {
    switch (type) {
      case battery.BatteryPluggedType.NONE:
        return 'NONE';
      case battery.BatteryPluggedType.AC:
        return 'AC';
      case battery.BatteryPluggedType.USB:
        return 'USB';
      case battery.BatteryPluggedType.WIRELESS:
        return 'WIRELESS';
      default:
        return 'UNKNOWN';
    }
  }

  /**
   * 获取屏幕方向字符串
   */
  private getOrientationString(orientation: display.Orientation): string {
    switch (orientation) {
      case display.Orientation.PORTRAIT:
        return 'PORTRAIT';
      case display.Orientation.LANDSCAPE:
        return 'LANDSCAPE';
      case display.Orientation.PORTRAIT_INVERTED:
        return 'PORTRAIT_INVERTED';
      case display.Orientation.LANDSCAPE_INVERTED:
        return 'LANDSCAPE_INVERTED';
      default:
        return 'UNKNOWN';
    }
  }

  /**
   * 获取显示状态字符串
   */
  private getDisplayStateString(state: display.DisplayState): string {
    switch (state) {
      case display.DisplayState.STATE_UNKNOWN:
        return 'UNKNOWN';
      case display.DisplayState.STATE_OFF:
        return 'OFF';
      case display.DisplayState.STATE_ON:
        return 'ON';
      case display.DisplayState.STATE_DOZE:
        return 'DOZE';
      case display.DisplayState.STATE_DOZE_SUSPEND:
        return 'DOZE_SUSPEND';
      case display.DisplayState.STATE_VR:
        return 'VR';
      case display.DisplayState.STATE_ON_SUSPEND:
        return 'ON_SUSPEND';
      default:
        return 'UNKNOWN';
    }
  }
}

export default SystemInfoTool;