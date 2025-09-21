import {
  MCPServerConfig,
  MCPConnectionState,
  MCPClientState,
  MCPTool,
  MCPResource,
  MCPPrompt,
  MCPTransportType,
  MCPMessageType,
  InitializeRequest,
  InitializeResult,
  ToolCallRequest,
  ToolCallResult,
  ResourceListRequest,
  ResourceListResult,
  ResourceReadRequest,
  ResourceReadResult,
  PromptListRequest,
  PromptListResult,
  PromptGetRequest,
  PromptGetResult,
  ClientCapabilities,
  JSONRPCNotification,
  MCPEvent,
  MCPEventListener,
  ParamType,
  BaseType,
  ComplexType
} from '../types/MCPTypes';
import { MCPJSONRPCClient, MCPError } from './MCPJSONRPCClient';
import { Logger } from '../utils/Logger';
import { AppStorage } from '../utils/AppStorage';

/**
 * MCP客户端管理器
 * 管理多个MCP服务器连接、工具、资源和提示词
 */
export class MCPClientManager {
  private static instance: MCPClientManager | null = null;
  private rpcClients: Map<string, MCPJSONRPCClient> = new Map();
  private state: MCPClientState;
  private eventListeners: Array<MCPEventListener> = [];
  private reconnectTimers: Map<string, number> = new Map();

  private constructor() {
    this.state = {
      servers: new Map(),
      availableTools: new Map(),
      availableResources: new Map(),
      availablePrompts: new Map()
    };
    this.loadConfiguration();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): MCPClientManager {
    if (!MCPClientManager.instance) {
      MCPClientManager.instance = new MCPClientManager();
    }
    return MCPClientManager.instance;
  }

  /**
   * 添加事件监听器
   */
  addEventListener(listener: MCPEventListener): void {
    this.eventListeners.push(listener);
  }

  /**
   * 移除事件监听器
   */
  removeEventListener(listener: MCPEventListener): void {
    const index = this.eventListeners.indexOf(listener);
    if (index >= 0) {
      this.eventListeners.splice(index, 1);
    }
  }

  /**
   * 触发事件
   */
  private emitEvent(type: string, serverId: string, data?: BaseType | MCPError | Array<BaseType | MCPError>): void {
    const event: MCPEvent = {
      type: type,
      serverId: serverId,
      data: data,
      timestamp: Date.now()
    };

    this.eventListeners.forEach(listener => {
      try {
        listener(event);
      } catch (error) {
        Logger.error('MCPClientManager', 'Event listener error', error);
      }
    });
  }

  /**
   * 添加MCP服务器配置
   */
  async addServer(config: MCPServerConfig): Promise<void> {
    Logger.info('MCPClientManager', `Adding MCP server: ${config.name}`);

    const connectionState: MCPConnectionState = {
      connected: false,
      connecting: false,
      error: undefined,
      lastConnected: undefined,
      serverInfo: undefined,
      capabilities: undefined
    };

    this.state.servers.set(config.name, connectionState);
    await this.saveConfiguration();
    this.emitEvent('server_added', config.name, config);
  }

  /**
   * 移除MCP服务器
   */
  async removeServer(serverId: string): Promise<void> {
    Logger.info('MCPClientManager', `Removing MCP server: ${serverId}`);

    await this.disconnectServer(serverId);
    this.state.servers.delete(serverId);
    await this.saveConfiguration();
    this.emitEvent('server_removed', serverId);
  }

  /**
   * 连接到MCP服务器
   */
  async connectServer(serverId: string, config: MCPServerConfig): Promise<void> {
    const connectionState = this.state.servers.get(serverId);
    if (!connectionState) {
      throw new Error(`Server not found: ${serverId}`);
    }

    if (connectionState.connected || connectionState.connecting) {
      Logger.warn('MCPClientManager', `Server already connected/connecting: ${serverId}`);
      return;
    }

    Logger.info('MCPClientManager', `Connecting to MCP server: ${serverId}`);
    connectionState.connecting = true;
    connectionState.error = undefined;
    this.emitEvent('connection_started', serverId);

    try {
      const rpcClient = new MCPJSONRPCClient();
      this.rpcClients.set(serverId, rpcClient);

      rpcClient.setNotificationHandler((notification: JSONRPCNotification) => {
        this.handleServerNotification(serverId, notification);
      });

      await this.initializeTransport(serverId, config, rpcClient);
      await this.initializeServer(serverId, rpcClient);

      connectionState.connected = true;
      connectionState.connecting = false;
      connectionState.lastConnected = Date.now();

      await this.refreshServerCapabilities(serverId);

      Logger.info('MCPClientManager', `Successfully connected to MCP server: ${serverId}`);
      this.emitEvent('connection_established', serverId);

    } catch (error) {
      Logger.error('MCPClientManager', `Failed to connect to MCP server: ${serverId}`, error);
      connectionState.connected = false;
      connectionState.connecting = false;
      connectionState.error = error instanceof Error ? error.message : 'Unknown error';
      this.rpcClients.delete(serverId);
      this.emitEvent('connection_failed', serverId, { error: connectionState.error });
      throw error;
    }
  }

  /**
   * 断开MCP服务器连接
   */
  async disconnectServer(serverId: string): Promise<void> {
    const connectionState = this.state.servers.get(serverId);
    if (!connectionState || !connectionState.connected) {
      return;
    }

    Logger.info('MCPClientManager', `Disconnecting from MCP server: ${serverId}`);

    const reconnectTimer = this.reconnectTimers.get(serverId);
    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
      this.reconnectTimers.delete(serverId);
    }

    const rpcClient = this.rpcClients.get(serverId);
    if (rpcClient) {
      rpcClient.cancelAllRequests();
      this.rpcClients.delete(serverId);
    }

    connectionState.connected = false;
    connectionState.connecting = false;
    this.emitEvent('connection_closed', serverId);
  }

  /**
   * 初始化传输层（简化版，仅支持HTTP SSE模拟）
   */
  private async initializeTransport(serverId: string, config: MCPServerConfig, rpcClient: MCPJSONRPCClient): Promise<void> {
    Logger.debug('MCPClientManager', `Initializing transport for server: ${serverId}`, { type: config.transportType });

    rpcClient.setMessageHandler((message: string) => {
      Logger.debug('MCPClientManager', `Sending message to ${serverId}`, { message: message });
    });
  }

  /**
   * 初始化MCP服务器
   */
  private async initializeServer(serverId: string, rpcClient: MCPJSONRPCClient): Promise<void> {
    const clientCapabilities: ClientCapabilities = {
      sampling: {},
      roots: {
        listChanged: true
      },
      experimental: {}
    };

    const initRequest: InitializeRequest = {
      protocolVersion: '2024-11-05',
      capabilities: clientCapabilities,
      clientInfo: {
        name: 'Javis HarmonyOS',
        version: '1.0.0'
      }
    };

    const result = await rpcClient.request<InitializeResult>(MCPMessageType.INITIALIZE, initRequest as ParamType);
    const initResult = result as InitializeResult;

    const connectionState = this.state.servers.get(serverId);
    if (connectionState) {
      connectionState.serverInfo = initResult.serverInfo;
      connectionState.capabilities = initResult.capabilities;
    }

    await rpcClient.notify(MCPMessageType.INITIALIZED);
    Logger.info('MCPClientManager', `Server initialized: ${serverId}`, initResult.serverInfo);
  }

  /**
   * 刷新服务器能力
   */
  private async refreshServerCapabilities(serverId: string): Promise<void> {
    const rpcClient = this.rpcClients.get(serverId);
    if (!rpcClient) {
      return;
    }

    try {
      if (this.hasCapability(serverId, 'tools')) {
        await this.refreshTools(serverId);
      }

      if (this.hasCapability(serverId, 'resources')) {
        await this.refreshResources(serverId);
      }

      if (this.hasCapability(serverId, 'prompts')) {
        await this.refreshPrompts(serverId);
      }
    } catch (error) {
      Logger.error('MCPClientManager', `Failed to refresh capabilities for ${serverId}`, error);
    }
  }

  /**
   * 检查服务器是否具有特定能力
   */
  private hasCapability(serverId: string, capability: string): boolean {
    const connectionState = this.state.servers.get(serverId);
    if (!connectionState || !connectionState.capabilities) {
      return false;
    }

    return connectionState.capabilities.hasOwnProperty(capability);
  }

  /**
   * 刷新工具列表
   */
  private async refreshTools(serverId: string): Promise<void> {
    const rpcClient = this.rpcClients.get(serverId);
    if (!rpcClient) {
      return;
    }

    try {
      const result = await rpcClient.request<{ tools: Array<MCPTool> }>(MCPMessageType.TOOLS_LIST, {});
      const toolsList = result as { tools: Array<MCPTool> };

      toolsList.tools.forEach(tool => {
        const toolKey = `${serverId}.${tool.name}`;
        this.state.availableTools.set(toolKey, tool);
      });

      Logger.info('MCPClientManager', `Refreshed ${toolsList.tools.length} tools for ${serverId}`);
      this.emitEvent('tools_updated', serverId, { count: toolsList.tools.length });
    } catch (error) {
      Logger.error('MCPClientManager', `Failed to refresh tools for ${serverId}`, error);
    }
  }

  /**
   * 刷新资源列表
   */
  private async refreshResources(serverId: string): Promise<void> {
    const rpcClient = this.rpcClients.get(serverId);
    if (!rpcClient) {
      return;
    }

    try {
      const result = await rpcClient.request<ResourceListResult>(MCPMessageType.RESOURCES_LIST, {});
      const resourcesList = result as ResourceListResult;

      resourcesList.resources.forEach(resource => {
        const resourceKey = `${serverId}.${resource.uri}`;
        this.state.availableResources.set(resourceKey, resource);
      });

      Logger.info('MCPClientManager', `Refreshed ${resourcesList.resources.length} resources for ${serverId}`);
      this.emitEvent('resources_updated', serverId, { count: resourcesList.resources.length });
    } catch (error) {
      Logger.error('MCPClientManager', `Failed to refresh resources for ${serverId}`, error);
    }
  }

  /**
   * 刷新提示词列表
   */
  private async refreshPrompts(serverId: string): Promise<void> {
    const rpcClient = this.rpcClients.get(serverId);
    if (!rpcClient) {
      return;
    }

    try {
      const result = await rpcClient.request<PromptListResult>(MCPMessageType.PROMPTS_LIST, {});
      const promptsList = result as PromptListResult;

      promptsList.prompts.forEach(prompt => {
        const promptKey = `${serverId}.${prompt.name}`;
        this.state.availablePrompts.set(promptKey, prompt);
      });

      Logger.info('MCPClientManager', `Refreshed ${promptsList.prompts.length} prompts for ${serverId}`);
      this.emitEvent('prompts_updated', serverId, { count: promptsList.prompts.length });
    } catch (error) {
      Logger.error('MCPClientManager', `Failed to refresh prompts for ${serverId}`, error);
    }
  }

  /**
   * 调用工具
   */
  async callTool(toolKey: string, args?: ParamType): Promise<ToolCallResult> {
    const [serverId, toolName] = toolKey.split('.');
    if (!serverId || !toolName) {
      throw new Error(`Invalid tool key: ${toolKey}`);
    }

    const rpcClient = this.rpcClients.get(serverId);
    if (!rpcClient) {
      throw new Error(`Server not connected: ${serverId}`);
    }

    const request: ToolCallRequest = {
      name: toolName,
      arguments: args
    };

    Logger.info('MCPClientManager', `Calling tool: ${toolKey}`, args);

    try {
      const result = await rpcClient.request<ToolCallResult>(MCPMessageType.TOOLS_CALL, request as ParamType);
      const toolResult = result as ToolCallResult;

      this.emitEvent('tool_called', serverId, { tool: toolName, success: !toolResult.isError });
      return toolResult;
    } catch (error) {
      Logger.error('MCPClientManager', `Tool call failed: ${toolKey}`, error);
      this.emitEvent('tool_called', serverId, { tool: toolName, success: false, error: error });
      throw error;
    }
  }

  /**
   * 读取资源
   */
  async readResource(resourceKey: string): Promise<ResourceReadResult> {
    const [serverId, ...uriParts] = resourceKey.split('.');
    const uri = uriParts.join('.');

    if (!serverId || !uri) {
      throw new Error(`Invalid resource key: ${resourceKey}`);
    }

    const rpcClient = this.rpcClients.get(serverId);
    if (!rpcClient) {
      throw new Error(`Server not connected: ${serverId}`);
    }

    const request: ResourceReadRequest = { uri: uri };

    Logger.info('MCPClientManager', `Reading resource: ${resourceKey}`);

    try {
      const result = await rpcClient.request<ResourceReadResult>(MCPMessageType.RESOURCES_READ, request as ParamType);
      const resourceResult = result as ResourceReadResult;

      this.emitEvent('resource_read', serverId, { uri: uri, success: true });
      return resourceResult;
    } catch (error) {
      Logger.error('MCPClientManager', `Resource read failed: ${resourceKey}`, error);
      this.emitEvent('resource_read', serverId, { uri: uri, success: false, error: error });
      throw error;
    }
  }

  /**
   * 获取提示词
   */
  async getPrompt(promptKey: string, args?: Record<string, string>): Promise<PromptGetResult> {
    const [serverId, promptName] = promptKey.split('.');
    if (!serverId || !promptName) {
      throw new Error(`Invalid prompt key: ${promptKey}`);
    }

    const rpcClient = this.rpcClients.get(serverId);
    if (!rpcClient) {
      throw new Error(`Server not connected: ${serverId}`);
    }

    const request: PromptGetRequest = {
      name: promptName,
      arguments: args
    };

    Logger.info('MCPClientManager', `Getting prompt: ${promptKey}`, args);

    try {
      const result = await rpcClient.request<PromptGetResult>(MCPMessageType.PROMPTS_GET, request as ParamType);
      const promptResult = result as PromptGetResult;

      this.emitEvent('prompt_retrieved', serverId, { prompt: promptName, success: true });
      return promptResult;
    } catch (error) {
      Logger.error('MCPClientManager', `Prompt get failed: ${promptKey}`, error);
      this.emitEvent('prompt_retrieved', serverId, { prompt: promptName, success: false, error: error });
      throw error;
    }
  }

  /**
   * 处理服务器通知
   */
  private handleServerNotification(serverId: string, notification: JSONRPCNotification): void {
    Logger.debug('MCPClientManager', `Received notification from ${serverId}`, notification);

    switch (notification.method) {
      case MCPMessageType.NOTIFICATION_TOOLS_LIST_CHANGED:
        this.refreshTools(serverId);
        break;
      case MCPMessageType.NOTIFICATION_RESOURCES_LIST_CHANGED:
        this.refreshResources(serverId);
        break;
      case MCPMessageType.NOTIFICATION_PROMPTS_LIST_CHANGED:
        this.refreshPrompts(serverId);
        break;
      default:
        Logger.debug('MCPClientManager', `Unhandled notification: ${notification.method}`);
    }

    this.emitEvent('notification_received', serverId, notification);
  }

  /**
   * 获取当前状态
   */
  getState(): MCPClientState {
    return {
      servers: new Map(this.state.servers),
      availableTools: new Map(this.state.availableTools),
      availableResources: new Map(this.state.availableResources),
      availablePrompts: new Map(this.state.availablePrompts)
    };
  }

  /**
   * 获取可用工具列表
   */
  getAvailableTools(): Array<{ key: string, tool: MCPTool, serverId: string }> {
    const tools: Array<{ key: string, tool: MCPTool, serverId: string }> = [];

    for (const [key, tool] of this.state.availableTools) {
      const serverId = key.split('.')[0];
      tools.push({ key: key, tool: tool, serverId: serverId });
    }

    return tools;
  }

  /**
   * 获取连接状态
   */
  getConnectionState(serverId: string): MCPConnectionState | undefined {
    return this.state.servers.get(serverId);
  }

  /**
   * 加载配置
   */
  private async loadConfiguration(): Promise<void> {
    try {
      const config = await AppStorage.getMCPConfiguration();
      if (config && config.servers) {
        for (const serverConfig of config.servers) {
          const connectionState: MCPConnectionState = {
            connected: false,
            connecting: false,
            error: undefined,
            lastConnected: undefined,
            serverInfo: undefined,
            capabilities: undefined
          };
          this.state.servers.set(serverConfig.name, connectionState);
        }
      }
      Logger.info('MCPClientManager', 'Configuration loaded');
    } catch (error) {
      Logger.error('MCPClientManager', 'Failed to load configuration', error);
    }
  }

  /**
   * 保存配置
   */
  private async saveConfiguration(): Promise<void> {
    try {
      const serverConfigs = Array.from(this.state.servers.keys()).map(serverId => ({
        name: serverId,
        description: `MCP Server: ${serverId}`,
        transportType: MCPTransportType.HTTP_SSE,
        timeout: 30000,
        retryAttempts: 3
      }));

      await AppStorage.saveMCPConfiguration({
        servers: serverConfigs,
        lastModified: Date.now()
      });

      Logger.debug('MCPClientManager', 'Configuration saved');
    } catch (error) {
      Logger.error('MCPClientManager', 'Failed to save configuration', error);
    }
  }

  /**
   * 销毁实例
   */
  destroy(): void {
    for (const [serverId, timer] of this.reconnectTimers) {
      clearTimeout(timer);
    }
    this.reconnectTimers.clear();

    for (const [serverId, rpcClient] of this.rpcClients) {
      rpcClient.cancelAllRequests();
    }
    this.rpcClients.clear();

    this.eventListeners.length = 0;
    MCPClientManager.instance = null;
  }
}

export default MCPClientManager;