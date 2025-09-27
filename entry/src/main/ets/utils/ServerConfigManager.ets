/**
 * 服务器配置管理器
 * 管理服务器IP地址和端口配置，支持动态修改和验证
 */

import { Logger } from './Logger';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';

export interface ServerEndpoint {
  ip: string;
  port: number;
  protocol: 'http' | 'https';
  wsProtocol: 'ws' | 'wss';
  description?: string;
}

export interface ServerConfiguration {
  current: ServerEndpoint;
  presets: ServerEndpoint[];
  customEndpoints: ServerEndpoint[];
  lastValidated: number;
  validationStatus: 'unknown' | 'valid' | 'invalid' | 'testing';
}

export interface ServerInfo {
  version?: string;
  status?: string;
  features?: string[];
}

export interface ValidationStatus {
  status: string;
  lastValidated: number;
}

export interface ServerValidationResult {
  success: boolean;
  responseTime?: number;
  errorMessage?: string;
  serverInfo?: ServerInfo;
}

export class ServerConfigManager {
  private static instance: ServerConfigManager;
  private config: ServerConfiguration;
  private storageKey = 'server_configuration';
  private validationTimeoutMs = 10000; // 10秒超时
  private storage: preferences.Preferences | null = null;
  private configChangeListeners: Array<(config: ServerEndpoint) => void> = [];

  private constructor() {
    this.config = this.getDefaultConfig();
  }

  /**
   * 获取存储实例
   */
  private async getStorage(): Promise<preferences.Preferences> {
    if (!this.storage) {
      const context = getContext() as common.UIAbilityContext;
      this.storage = await preferences.getPreferences(context, 'ServerConfig');
    }
    return this.storage;
  }

  static getInstance(): ServerConfigManager {
    if (!ServerConfigManager.instance) {
      ServerConfigManager.instance = new ServerConfigManager();
    }
    return ServerConfigManager.instance;
  }

  /**
   * 获取默认配置
   */
  private getDefaultConfig(): ServerConfiguration {
    // 默认配置 - 使用生产服务器（根据CLAUDE.md中的配置）
    const productionEndpoint: ServerEndpoint = {
      ip: '45.127.32.38',
      port: 8080,
      protocol: 'http',
      wsProtocol: 'ws',
      description: '生产服务器'
    };

    const localhostEndpoint: ServerEndpoint = {
      ip: 'localhost',
      port: 8080,
      protocol: 'http',
      wsProtocol: 'ws',
      description: '本地开发服务器'
    };

    return {
      current: productionEndpoint, // 默认使用生产服务器
      presets: [
        productionEndpoint,
        localhostEndpoint,
        {
          ip: '127.0.0.1',
          port: 8080,
          protocol: 'http',
          wsProtocol: 'ws',
          description: '本地回环地址'
        },
        {
          ip: '192.168.1.100',
          port: 8080,
          protocol: 'http',
          wsProtocol: 'ws',
          description: '局域网服务器示例'
        }
      ],
      customEndpoints: [],
      lastValidated: 0,
      validationStatus: 'unknown'
    };
  }

  /**
   * 初始化配置管理器
   */
  async initialize(): Promise<void> {
    try {
      Logger.info('ServerConfigManager', '初始化服务器配置管理器');

      const storage = await this.getStorage();
      const savedConfig: string = await storage.get(this.storageKey, '') as string;

      if (savedConfig) {
        try {
          const parsedConfig: ServerConfiguration = JSON.parse(savedConfig) as ServerConfiguration;
          // 验证配置有效性
          if (this.isValidConfiguration(parsedConfig)) {
            this.config = this.mergeConfigurations(this.getDefaultConfig(), parsedConfig);
            Logger.info('ServerConfigManager', `已加载保存的服务器配置: ${this.getBaseUrl()}`);
          } else {
            Logger.warn('ServerConfigManager', '保存的配置无效，使用默认配置');
            this.config = this.getDefaultConfig();
            await this.saveConfig();
          }
        } catch (parseError) {
          Logger.error('ServerConfigManager', `解析保存的配置失败: ${parseError}`);
          this.config = this.getDefaultConfig();
          await this.saveConfig();
        }
      } else {
        Logger.info('ServerConfigManager', '使用默认服务器配置');
        this.config = this.getDefaultConfig();
        await this.saveConfig();
      }
    } catch (error) {
      Logger.error('ServerConfigManager', `初始化失败: ${error}`);
      this.config = this.getDefaultConfig();
      // 尝试保存默认配置
      try {
        await this.saveConfig();
      } catch (saveError) {
        Logger.error('ServerConfigManager', `保存默认配置失败: ${saveError}`);
      }
    }
  }

  /**
   * 验证配置有效性
   */
  private isValidConfiguration(config: ServerConfiguration): boolean {
    try {
      // 验证基本结构
      if (!config || typeof config !== 'object') {
        return false;
      }

      // 验证当前服务器配置
      if (!config.current || !this.isValidEndpoint(config.current)) {
        return false;
      }

      // 验证预设端点数组
      if (!Array.isArray(config.presets)) {
        return false;
      }

      // 验证自定义端点数组
      if (!Array.isArray(config.customEndpoints)) {
        return false;
      }

      return true;
    } catch (error) {
      Logger.error('ServerConfigManager', `配置验证失败: ${error}`);
      return false;
    }
  }

  /**
   * 验证端点配置有效性
   */
  private isValidEndpoint(endpoint: ServerEndpoint): boolean {
    if (!endpoint || typeof endpoint !== 'object') {
      return false;
    }

    // 验证IP地址
    if (!endpoint.ip || typeof endpoint.ip !== 'string' || !this.validateIpFormat(endpoint.ip)) {
      return false;
    }

    // 验证端口
    if (!endpoint.port || typeof endpoint.port !== 'number' || !this.validatePort(endpoint.port)) {
      return false;
    }

    // 验证协议
    if (!endpoint.protocol || (endpoint.protocol !== 'http' && endpoint.protocol !== 'https')) {
      return false;
    }

    // 验证WebSocket协议
    if (!endpoint.wsProtocol || (endpoint.wsProtocol !== 'ws' && endpoint.wsProtocol !== 'wss')) {
      return false;
    }

    return true;
  }

  /**
   * 保存配置
   */
  private async saveConfig(): Promise<void> {
    try {
      // 验证配置有效性
      if (!this.isValidConfiguration(this.config)) {
        Logger.error('ServerConfigManager', '配置验证失败，无法保存');
        return;
      }

      const storage = await this.getStorage();
      const configJson = JSON.stringify(this.config);

      // 验证JSON序列化是否成功
      if (!configJson || configJson === '{}') {
        Logger.error('ServerConfigManager', '配置序列化失败');
        return;
      }

      await storage.put(this.storageKey, configJson);
      await storage.flush();

      Logger.info('ServerConfigManager', `服务器配置已保存: ${this.getBaseUrl()}`);

      // 验证保存是否成功
      const savedConfig = await storage.get(this.storageKey, '') as string;
      if (savedConfig !== configJson) {
        Logger.error('ServerConfigManager', '配置保存验证失败');
      }
    } catch (error) {
      Logger.error('ServerConfigManager', `保存配置失败: ${error}`);
      throw new Error(`保存配置失败: ${error}`);
    }
  }

  /**
   * 合并配置
   */
  private mergeConfigurations(defaultConfig: ServerConfiguration, savedConfig: ServerConfiguration): ServerConfiguration {
    const mergedCustomEndpoints: ServerEndpoint[] = [];
    // 复制自定义端点
    if (savedConfig.customEndpoints) {
      for (let i = 0; i < savedConfig.customEndpoints.length; i++) {
        mergedCustomEndpoints.push(savedConfig.customEndpoints[i]);
      }
    }

    const mergedPresets: ServerEndpoint[] = [];
    // 复制预设端点
    for (let i = 0; i < defaultConfig.presets.length; i++) {
      mergedPresets.push(defaultConfig.presets[i]);
    }

    return {
      current: savedConfig.current || defaultConfig.current,
      presets: mergedPresets,
      customEndpoints: mergedCustomEndpoints,
      lastValidated: savedConfig.lastValidated || defaultConfig.lastValidated,
      validationStatus: savedConfig.validationStatus || defaultConfig.validationStatus
    };
  }

  /**
   * 获取当前服务器配置
   */
  getCurrentServer(): ServerEndpoint {
    return this.copyServerEndpoint(this.config.current);
  }

  /**
   * 复制服务器端点
   */
  private copyServerEndpoint(endpoint: ServerEndpoint): ServerEndpoint {
    return {
      ip: endpoint.ip,
      port: endpoint.port,
      protocol: endpoint.protocol,
      wsProtocol: endpoint.wsProtocol,
      description: endpoint.description
    };
  }

  /**
   * 获取完整配置
   */
  getConfiguration(): ServerConfiguration {
    const customEndpoints: ServerEndpoint[] = [];
    for (let i = 0; i < this.config.customEndpoints.length; i++) {
      customEndpoints.push(this.copyServerEndpoint(this.config.customEndpoints[i]));
    }

    const presets: ServerEndpoint[] = [];
    for (let i = 0; i < this.config.presets.length; i++) {
      presets.push(this.copyServerEndpoint(this.config.presets[i]));
    }

    return {
      current: this.copyServerEndpoint(this.config.current),
      presets: presets,
      customEndpoints: customEndpoints,
      lastValidated: this.config.lastValidated,
      validationStatus: this.config.validationStatus
    };
  }

  /**
   * 设置当前服务器
   */
  async setCurrentServer(endpoint: ServerEndpoint): Promise<void> {
    if (!endpoint || !endpoint.ip || !endpoint.port) {
      Logger.error('ServerConfigManager', '无效的服务器端点');
      return;
    }
    
    Logger.info('ServerConfigManager', `设置当前服务器: ${this.formatEndpoint(endpoint)}`);
    
    this.config.current = this.copyServerEndpoint(endpoint);
    this.config.lastValidated = 0;
    this.config.validationStatus = 'unknown';
    
    await this.saveConfig();
    
    // 通知所有监听器配置已变更
    this.notifyConfigChange(this.config.current);
  }

  /**
   * 添加自定义服务器端点
   */
  async addCustomEndpoint(endpoint: ServerEndpoint): Promise<void> {
    // 检查是否已存在相同配置
    let exists = false;
    for (let i = 0; i < this.config.customEndpoints.length; i++) {
      const ep = this.config.customEndpoints[i];
      if (ep.ip === endpoint.ip && ep.port === endpoint.port) {
        exists = true;
        break;
      }
    }
    
    if (!exists) {
      this.config.customEndpoints.push(this.copyServerEndpoint(endpoint));
      await this.saveConfig();
      Logger.info('ServerConfigManager', `添加自定义端点: ${this.formatEndpoint(endpoint)}`);
    }
  }

  /**
   * 删除自定义端点
   */
  async removeCustomEndpoint(endpoint: ServerEndpoint): Promise<void> {
    const index = this.config.customEndpoints.findIndex(ep => 
      ep.ip === endpoint.ip && ep.port === endpoint.port);
    
    if (index >= 0) {
      this.config.customEndpoints.splice(index, 1);
      await this.saveConfig();
      Logger.info('ServerConfigManager', `删除自定义端点: ${this.formatEndpoint(endpoint)}`);
    }
  }

  /**
   * 获取所有可用端点（预设 + 自定义）
   */
  getAllEndpoints(): ServerEndpoint[] {
    const allEndpoints: ServerEndpoint[] = [];
    
    // 添加预设端点
    for (let i = 0; i < this.config.presets.length; i++) {
      allEndpoints.push(this.copyServerEndpoint(this.config.presets[i]));
    }
    
    // 添加自定义端点
    for (let i = 0; i < this.config.customEndpoints.length; i++) {
      allEndpoints.push(this.copyServerEndpoint(this.config.customEndpoints[i]));
    }
    
    return allEndpoints;
  }

  /**
   * 验证服务器连接
   */
  async validateServer(endpoint?: ServerEndpoint): Promise<ServerValidationResult> {
    const targetEndpoint = endpoint || this.config.current;
    
    if (!targetEndpoint || !targetEndpoint.ip || !targetEndpoint.port) {
      return {
        success: false,
        errorMessage: '无效的服务器配置'
      };
    }
    
    const baseUrl = this.formatBaseUrl(targetEndpoint);
    
    Logger.info('ServerConfigManager', `验证服务器连接: ${baseUrl}`);
    
    this.config.validationStatus = 'testing';
    
    try {
      const startTime = Date.now();
      const httpRequest = http.createHttp();
      
      const response = await httpRequest.request(
        `${baseUrl}/api/providers`,
        {
          method: http.RequestMethod.GET,
          connectTimeout: this.validationTimeoutMs,
          readTimeout: this.validationTimeoutMs,
          header: {
            'Content-Type': 'application/json'
          }
        }
      );
      
      const responseTime = Date.now() - startTime;
      httpRequest.destroy();
      
      if (response.responseCode === 200) {
        this.config.validationStatus = 'valid';
        this.config.lastValidated = Date.now();
        
        // 尝试解析服务器信息
        let serverInfo: ServerInfo = {
          version: 'unknown',
          status: 'online',
          features: []
        };
        
        try {
          if (response.result) {
            const responseData: Record<string, Object> = JSON.parse(response.result as string) as Record<string, Object>;
            if (responseData && typeof responseData === 'object') {
              const version = responseData.version;
              const providers = responseData.providers;
              serverInfo = {
                version: (typeof version === 'string') ? version : 'unknown',
                status: 'online',
                features: Array.isArray(providers) ? providers as string[] : []
              };
            }
          }
        } catch (parseError) {
          Logger.warn('ServerConfigManager', `解析服务器信息失败: ${parseError}`);
        }
        
        await this.saveConfig();
        
        Logger.info('ServerConfigManager', `服务器验证成功，响应时间: ${responseTime}ms`);
        
        return {
          success: true,
          responseTime,
          serverInfo
        };
      } else {
        throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
      }
      
    } catch (error) {
      this.config.validationStatus = 'invalid';
      await this.saveConfig();
      
      const errorMessage = error instanceof Error ? error.message : String(error);
      Logger.error('ServerConfigManager', `服务器验证失败: ${errorMessage}`);
      
      // 提供更友好的错误信息
      let userFriendlyMessage = errorMessage;
      if (errorMessage.includes('Network error')) {
        userFriendlyMessage = '网络连接失败，请检查网络或服务器地址';
      } else if (errorMessage.includes('timeout')) {
        userFriendlyMessage = '连接超时，请检查服务器是否正常运行';
      } else if (errorMessage.includes('HTTP 404')) {
        userFriendlyMessage = '服务器未找到，请检查API路径是否正确';
      } else if (errorMessage.includes('HTTP 403')) {
        userFriendlyMessage = '访问被拒绝，请检查服务器权限配置';
      } else if (errorMessage.includes('HTTP 500')) {
        userFriendlyMessage = '服务器内部错误，请联系管理员';
      } else if (errorMessage.includes('Failed to connect')) {
        userFriendlyMessage = '无法连接到服务器，请检查地址和端口';
      }
      
      return {
        success: false,
        errorMessage: userFriendlyMessage
      };
    }
  }

  /**
   * 获取基础URL
   */
  getBaseUrl(): string {
    return this.formatBaseUrl(this.config.current);
  }

  /**
   * 获取WebSocket URL
   */
  getWebSocketUrl(): string {
    const current = this.config.current;
    return `${current.wsProtocol}://${current.ip}:${current.port}`;
  }

  /**
   * 获取搜索URL
   */
  getSearchUrl(): string {
    return this.getBaseUrl();
  }

  /**
   * 格式化端点为基础URL
   */
  private formatBaseUrl(endpoint: ServerEndpoint): string {
    if (!endpoint || !endpoint.protocol || !endpoint.ip || !endpoint.port) {
      return 'http://localhost:8080';
    }
    return `${endpoint.protocol}://${endpoint.ip}:${endpoint.port}`;
  }

  /**
   * 格式化端点为显示字符串
   */
  private formatEndpoint(endpoint: ServerEndpoint): string {
    if (!endpoint || !endpoint.protocol || !endpoint.ip || !endpoint.port) {
      return 'http://localhost:8080';
    }
    return `${endpoint.protocol}://${endpoint.ip}:${endpoint.port}`;
  }

  /**
   * 验证IP地址格式
   */
  validateIpFormat(ip: string): boolean {
    // 支持IPv4、域名、localhost
    const ipv4Regex = /^(\d{1,3}\.){3}\d{1,3}$/;
    const domainRegex = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;
    
    if (ip === 'localhost') return true;
    if (ipv4Regex.test(ip)) {
      // 验证IPv4范围
      const parts = ip.split('.');
      for (let i = 0; i < parts.length; i++) {
        const part = Number(parts[i]);
        if (part < 0 || part > 255) {
          return false;
        }
      }
      return true;
    }
    if (domainRegex.test(ip)) return true;
    
    return false;
  }

  /**
   * 验证端口范围
   */
  validatePort(port: number): boolean {
    return port >= 1 && port <= 65535;
  }

  /**
   * 获取验证状态
   */
  getValidationStatus(): ValidationStatus {
    return {
      status: this.config.validationStatus,
      lastValidated: this.config.lastValidated
    };
  }

  /**
   * 重置为默认配置
   */
  async resetToDefault(): Promise<void> {
    Logger.info('ServerConfigManager', '重置服务器配置为默认值');

    try {
      const defaultConfig = this.getDefaultConfig();
      this.config = defaultConfig;
      await this.saveConfig();

      Logger.info('ServerConfigManager', '服务器配置已重置为默认值');

      // 通知所有监听器配置已变更
      this.notifyConfigChange(this.config.current);
    } catch (error) {
      Logger.error('ServerConfigManager', `重置配置失败: ${error}`);
      throw new Error(`重置配置失败: ${error}`);
    }
  }

  /**
   * 强制恢复配置（清除保存的配置，重新使用默认值）
   */
  async forceRecoverConfiguration(): Promise<void> {
    Logger.warn('ServerConfigManager', '强制恢复配置');

    try {
      const storage = await this.getStorage();

      // 清除保存的配置
      await storage.delete(this.storageKey);
      await storage.flush();

      // 重新初始化
      await this.initialize();

      Logger.info('ServerConfigManager', '配置强制恢复完成');

      // 通知所有监听器配置已变更
      this.notifyConfigChange(this.config.current);
    } catch (error) {
      Logger.error('ServerConfigManager', `强制恢复配置失败: ${error}`);
      // 如果连强制恢复都失败，至少确保内存中有默认配置
      this.config = this.getDefaultConfig();
      this.notifyConfigChange(this.config.current);
      throw new Error(`强制恢复配置失败: ${error}`);
    }
  }

  /**
   * 添加配置变更监听器
   */
  addConfigChangeListener(listener: (config: ServerEndpoint) => void): void {
    this.configChangeListeners.push(listener);
    Logger.info('ServerConfigManager', `添加配置变更监听器，当前监听器数量: ${this.configChangeListeners.length}`);
  }

  /**
   * 移除配置变更监听器
   */
  removeConfigChangeListener(listener: (config: ServerEndpoint) => void): void {
    const index = this.configChangeListeners.indexOf(listener);
    if (index >= 0) {
      this.configChangeListeners.splice(index, 1);
      Logger.info('ServerConfigManager', `移除配置变更监听器，当前监听器数量: ${this.configChangeListeners.length}`);
    }
  }

  /**
   * 通知所有监听器配置已变更
   */
  private notifyConfigChange(newConfig: ServerEndpoint): void {
    Logger.info('ServerConfigManager', `通知 ${this.configChangeListeners.length} 个监听器配置已变更: ${this.formatEndpoint(newConfig)}`);
    this.configChangeListeners.forEach(listener => {
      try {
        listener(this.copyServerEndpoint(newConfig));
      } catch (error) {
        Logger.error('ServerConfigManager', `配置变更监听器执行失败: ${error}`);
      }
    });
  }
}