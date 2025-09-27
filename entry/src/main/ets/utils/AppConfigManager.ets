/**
 * 应用配置管理器
 * 统一管理应用配置，支持从配置文件读取配置
 */

import { Logger } from './Logger';
import { resourceManager } from '@kit.LocalizationKit';
import { AppContext } from './AppContext';
import { ServerConfigManager, ServerEndpoint } from './ServerConfigManager';
import { util } from '@kit.ArkTS';

export interface ServerConfig {
  baseUrl: string;
  wsUrl: string;
  searchUrl: string;
}

export interface ApiConfig {
  providers: string;
  chat: string;
  execute: string;
}

export interface AppConfig {
  defaultProvider: string;
  defaultModel: string;
  defaultLanguage: string;
}

export interface PrivacyConfig {
  showDeveloperInfo: boolean;
  developerName: string;
  developerContact: string;
  githubUrl: string;
}

export interface SecurityConfig {
  enableApiKeyValidation: boolean;
  logSensitiveData: boolean;
}

export interface AppConfiguration {
  server: ServerConfig;
  api: ApiConfig;
  app: AppConfig;
  privacy: PrivacyConfig;
  security: SecurityConfig;
}

export class AppConfigManager {
  private static instance: AppConfigManager;
  private config: AppConfiguration;
  private initialized: boolean = false;
  private serverConfigManager: ServerConfigManager;

  private constructor() {
    this.config = this.getDefaultConfig();
    this.serverConfigManager = ServerConfigManager.getInstance();
  }

  static getInstance(): AppConfigManager {
    if (!AppConfigManager.instance) {
      AppConfigManager.instance = new AppConfigManager();
    }
    return AppConfigManager.instance;
  }

  private getDefaultConfig(): AppConfiguration {
    return {
      server: {
        baseUrl: '',
        wsUrl: '',
        searchUrl: ''
      },
      api: {
        providers: '/providers',
        chat: '/chat',
        execute: '/execute'
      },
      app: {
        defaultProvider: 'siliconflow',
        defaultModel: 'Qwen/Qwen2.5-7B-Instruct',
        defaultLanguage: 'python'
      },
      privacy: {
        showDeveloperInfo: false,
        developerName: 'Javis',
        developerContact: '',
        githubUrl: ''
      },
      security: {
        enableApiKeyValidation: true,
        logSensitiveData: false
      }
    };
  }

  async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }

    try {
      Logger.info('AppConfigManager', '开始初始化配置管理器');
      
      // 尝试从资源文件加载配置
      const resourceConfig = await this.loadConfigFromResource();
      if (resourceConfig) {
        this.config = this.mergeConfig(this.config, resourceConfig);
        Logger.info('AppConfigManager', '已从资源文件加载配置');
      } else {
        Logger.info('AppConfigManager', '使用默认配置');
      }

      // 初始化服务器配置管理器
      await this.serverConfigManager.initialize();
      
      this.initialized = true;
      Logger.info('AppConfigManager', '配置管理器初始化完成');
    } catch (error) {
      Logger.error('AppConfigManager', `配置管理器初始化失败: ${error}`);
      // 使用默认配置
      this.config = this.getDefaultConfig();
      this.initialized = true;
    }
  }

  private async loadConfigFromResource(): Promise<AppConfiguration | null> {
    try {
      Logger.debug('AppConfigManager', '尝试从资源文件加载配置');

      // 从配置文件读取配置
      const configFromFile = await this.loadConfigFromFile();
      if (configFromFile) {
        Logger.info('AppConfigManager', '从配置文件加载配置成功');
        return configFromFile;
      }

      Logger.debug('AppConfigManager', '配置文件不存在，使用默认配置');
      return null;
    } catch (error) {
      Logger.debug('AppConfigManager', `加载资源配置失败: ${error}，使用默认配置`);
      return null;
    }
  }

  private async loadConfigFromFile(): Promise<AppConfiguration | null> {
    try {
      // 获取资源管理器
      const resMgr = AppContext.getInstance().getContext()?.resourceManager;
      if (!resMgr) {
        Logger.warn('AppConfigManager', '无法获取资源管理器');
        return null;
      }

      // 读取配置文件
      const rawFileContent: Uint8Array = await resMgr.getRawFileContent('config.json');

      // 使用鸿蒙系统的util.TextDecoder正确处理UTF-8编码
      const textDecoder = new util.TextDecoder('utf-8', { ignoreBOM: true });
      const configString = textDecoder.decodeToString(rawFileContent);
      
      // 解析JSON
      const configFromFile = JSON.parse(configString) as AppConfiguration;
      
      Logger.info('AppConfigManager', '从配置文件读取配置成功');
      return configFromFile;
    } catch (error) {
      Logger.warn('AppConfigManager', `从配置文件加载配置失败: ${error}`);
      return null;
    }
  }

  private mergeConfig(defaultConfig: AppConfiguration, resourceConfig: Partial<AppConfiguration>): AppConfiguration {
    if (!resourceConfig) {
      return defaultConfig;
    }

    const result: AppConfiguration = {
      server: this.mergeServerConfig(defaultConfig.server, resourceConfig.server),
      api: this.mergeApiConfig(defaultConfig.api, resourceConfig.api),
      app: this.mergeAppConfig(defaultConfig.app, resourceConfig.app),
      privacy: this.mergePrivacyConfig(defaultConfig.privacy, resourceConfig.privacy),
      security: this.mergeSecurityConfig(defaultConfig.security, resourceConfig.security)
    };

    return result;
  }

  private mergeServerConfig(defaultConfig: ServerConfig, resourceConfig?: Partial<ServerConfig>): ServerConfig {
    if (!resourceConfig) {
      return defaultConfig;
    }
    
    return {
      baseUrl: resourceConfig.baseUrl || defaultConfig.baseUrl,
      wsUrl: resourceConfig.wsUrl || defaultConfig.wsUrl,
      searchUrl: resourceConfig.searchUrl || defaultConfig.searchUrl
    };
  }

  private mergeApiConfig(defaultConfig: ApiConfig, resourceConfig?: Partial<ApiConfig>): ApiConfig {
    if (!resourceConfig) {
      return defaultConfig;
    }
    
    return {
      providers: resourceConfig.providers || defaultConfig.providers,
      chat: resourceConfig.chat || defaultConfig.chat,
      execute: resourceConfig.execute || defaultConfig.execute
    };
  }

  private mergeAppConfig(defaultConfig: AppConfig, resourceConfig?: Partial<AppConfig>): AppConfig {
    if (!resourceConfig) {
      return defaultConfig;
    }
    
    return {
      defaultProvider: resourceConfig.defaultProvider || defaultConfig.defaultProvider,
      defaultModel: resourceConfig.defaultModel || defaultConfig.defaultModel,
      defaultLanguage: resourceConfig.defaultLanguage || defaultConfig.defaultLanguage
    };
  }

  private mergePrivacyConfig(defaultConfig: PrivacyConfig, resourceConfig?: Partial<PrivacyConfig>): PrivacyConfig {
    if (!resourceConfig) {
      return defaultConfig;
    }
    
    return {
      showDeveloperInfo: resourceConfig.showDeveloperInfo !== undefined ? resourceConfig.showDeveloperInfo : defaultConfig.showDeveloperInfo,
      developerName: resourceConfig.developerName || defaultConfig.developerName,
      developerContact: resourceConfig.developerContact !== undefined ? resourceConfig.developerContact : defaultConfig.developerContact,
      githubUrl: resourceConfig.githubUrl !== undefined ? resourceConfig.githubUrl : defaultConfig.githubUrl
    };
  }

  private mergeSecurityConfig(defaultConfig: SecurityConfig, resourceConfig?: Partial<SecurityConfig>): SecurityConfig {
    if (!resourceConfig) {
      return defaultConfig;
    }
    
    return {
      enableApiKeyValidation: resourceConfig.enableApiKeyValidation !== undefined ? resourceConfig.enableApiKeyValidation : defaultConfig.enableApiKeyValidation,
      logSensitiveData: resourceConfig.logSensitiveData !== undefined ? resourceConfig.logSensitiveData : defaultConfig.logSensitiveData
    };
  }

  getConfig(): AppConfiguration {
    if (!this.initialized) {
      Logger.warn('AppConfigManager', '配置管理器未初始化，返回默认配置');
      return this.getDefaultConfig();
    }
    return this.config;
  }

  getServerConfig(): ServerConfig {
    try {
      // 优先使用ServerConfigManager的动态配置
      const currentServer = this.serverConfigManager.getCurrentServer();
      
      // 检查服务器配置是否有效
      if (!currentServer.ip || currentServer.ip.trim() === '') {
        Logger.warn('AppConfigManager', '服务器配置为空，使用静态配置作为回退');
        return this.getConfig().server;
      }
      
      return {
        baseUrl: this.serverConfigManager.getBaseUrl() + '/api',
        wsUrl: this.serverConfigManager.getWebSocketUrl() + '/api/ws',
        searchUrl: this.serverConfigManager.getSearchUrl()
      };
    } catch (error) {
      Logger.warn('AppConfigManager', `获取动态服务器配置失败，使用静态配置: ${error}`);
      return this.getConfig().server;
    }
  }

  getApiConfig(): ApiConfig {
    return this.getConfig().api;
  }

  getAppConfig(): AppConfig {
    return this.getConfig().app;
  }

  getPrivacyConfig(): PrivacyConfig {
    return this.getConfig().privacy;
  }

  getSecurityConfig(): SecurityConfig {
    return this.getConfig().security;
  }

  updateServerConfig(serverConfig: Partial<ServerConfig>): void {
    // 简化更新逻辑
    if (serverConfig.baseUrl) {
      this.config.server.baseUrl = serverConfig.baseUrl;
    }
    if (serverConfig.wsUrl) {
      this.config.server.wsUrl = serverConfig.wsUrl;
    }
    if (serverConfig.searchUrl) {
      this.config.server.searchUrl = serverConfig.searchUrl;
    }
    Logger.info('AppConfigManager', '服务器配置已更新');
  }

  updatePrivacyConfig(privacyConfig: Partial<PrivacyConfig>): void {
    // 简化更新逻辑
    if (privacyConfig.showDeveloperInfo !== undefined) {
      this.config.privacy.showDeveloperInfo = privacyConfig.showDeveloperInfo;
    }
    if (privacyConfig.developerName !== undefined) {
      this.config.privacy.developerName = privacyConfig.developerName;
    }
    if (privacyConfig.developerContact !== undefined) {
      this.config.privacy.developerContact = privacyConfig.developerContact;
    }
    if (privacyConfig.githubUrl !== undefined) {
      this.config.privacy.githubUrl = privacyConfig.githubUrl;
    }
    Logger.info('AppConfigManager', '隐私配置已更新');
  }

  updateSecurityConfig(securityConfig: Partial<SecurityConfig>): void {
    // 简化更新逻辑
    if (securityConfig.enableApiKeyValidation !== undefined) {
      this.config.security.enableApiKeyValidation = securityConfig.enableApiKeyValidation;
    }
    if (securityConfig.logSensitiveData !== undefined) {
      this.config.security.logSensitiveData = securityConfig.logSensitiveData;
    }
    Logger.info('AppConfigManager', '安全配置已更新');
  }

  /**
   * 更新服务器配置
   * @param endpoint 服务器端点配置
   */
  async updateServerEndpoint(endpoint: ServerEndpoint): Promise<void> {
    try {
      // 更新服务器配置
      this.config.server.baseUrl = `${endpoint.protocol}://${endpoint.ip}:${endpoint.port}`;
      this.config.server.wsUrl = `${endpoint.wsProtocol}://${endpoint.ip}:${endpoint.port}`;
      this.config.server.searchUrl = this.config.server.baseUrl;
      
      Logger.info('AppConfigManager', `服务器配置已更新: ${this.config.server.baseUrl}`);
    } catch (error) {
      Logger.error('AppConfigManager', `更新服务器配置失败: ${error}`);
      throw new Error(`更新服务器配置失败: ${error}`);
    }
  }

  isInitialized(): boolean {
    return this.initialized;
  }

  resetToDefault(): void {
    this.config = this.getDefaultConfig();
    Logger.info('AppConfigManager', '配置已重置为默认值');
  }
}