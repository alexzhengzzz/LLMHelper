/**
 * 服务接口契约定义
 * 定义服务层的抽象接口，实现依赖倒置原则
 */

import { ChatRequest, ChatResponse, AIProvider, ConnectionTestResult, ServiceStats, APIMode, APIManagerState, Tool } from '../types/APITypes';
import { ChatRequest as LegacyChatRequest, SimpleMessage, ChatResponse as LegacyChatResponse, ExecuteRequest, ExecuteResponse, ProvidersResponse } from '../models/ChatModels';
import { APIKeyConfig, ProviderInfo, APIKeyValidationResult } from '../types/APIKeyTypes';
import { MCPTool, ToolCallRequest, ToolCallResult } from '../types/MCPTypes';

/**
 * 直连API服务接口
 */
export interface IDirectAPIService {
  /**
   * 发送聊天请求
   */
  sendChatRequest(request: ChatRequest, provider: AIProvider): Promise<ChatResponse>;
  
  /**
   * 测试连接
   */
  testConnection(provider: AIProvider): Promise<boolean>;
  
  /**
   * 获取支持的厂商列表
   */
  getSupportedProviders(): AIProvider[];
  
  /**
   * 根据模型获取厂商
   */
  getProviderByModel(modelName: string): Promise<AIProvider | null>;
  
  /**
   * 验证模型与厂商匹配性
   */
  validateModelProviderMatch(modelName: string, provider: AIProvider): Promise<boolean>;
  
  /**
   * 获取模型到厂商映射
   */
  getModelProviderMap(): Promise<Map<string, AIProvider>>;
  
  /**
   * 设置API密钥
   */
  setApiKey(provider: AIProvider, apiKey: string): void;
  
  /**
   * 批量设置API密钥
   */
  setApiKeys(apiKeys: Map<AIProvider, string>): void;
  
  /**
   * 获取服务统计
   */
  getServiceStats(): ServiceStats;

  /**
   * 获取可用的工具列表
   */
  getAvailableTools(): Array<MCPTool>;

  /**
   * 检查工具是否存在
   */
  hasTool(toolName: string): boolean;

  /**
   * 执行工具调用
   */
  executeToolCall(request: ToolCallRequest): Promise<ToolCallResult>;

  /**
   * 转换MCP工具为API工具格式
   */
  convertMCPToolToAPITool(mcpTool: MCPTool): Tool;

  /**
   * 获取所有工具的API格式列表
   */
  getAPIToolsFormat(): Array<Tool>;

  /**
   * 为聊天请求添加工具支持
   */
  sendChatRequestWithTools(request: ChatRequest, provider: AIProvider, includeTools?: boolean): Promise<ChatResponse>;

  /**
   * 处理工具调用响应并执行工具，然后将结果返回给大模型生成最终回答
   */
  processToolCallsInResponse(response: ChatResponse, provider: AIProvider, originalRequest: ChatRequest): Promise<ChatResponse>;

  /**
   * 初始化本地工具管理器
   */
  initializeLocalToolManager(context: import('@kit.AbilityKit').common.UIAbilityContext): void;

  /**
   * 销毁服务
   */
  destroy(): void;
}

/**
 * 代理API服务接口
 */
export interface IApiService {
  /**
   * 获取厂商列表
   */
  getProviders(): Promise<ProvidersResponse>;

  /**
   * 发送聊天消息
   */
  sendChatMessage(request: LegacyChatRequest): Promise<LegacyChatResponse>;

  /**
   * 执行代码
   */
  executeCode(request: ExecuteRequest): Promise<ExecuteResponse>;

  /**
   * 生成文本向量嵌入
   */
  generateEmbedding(text: string): Promise<number[]>;

  /**
   * 测试连接
   */
  testConnection(): Promise<boolean>;

  /**
   * 销毁服务
   */
  destroy(): void;
}

/**
 * API管理器接口
 */
export interface IAPIManager {
  /**
   * 初始化管理器
   */
  initialize(): Promise<void>;
  
  /**
   * 发送聊天请求
   */
  sendChatRequest(request: ChatRequest): Promise<ChatResponse>;
  
  /**
   * 设置API模式
   */
  setAPIMode(mode: APIMode): Promise<void>;
  
  /**
   * 获取当前模式
   */
  getCurrentMode(): APIMode;
  
  /**
   * 设置当前厂商
   */
  setCurrentProvider(provider: AIProvider): Promise<void>;
  
  /**
   * 获取当前厂商
   */
  getCurrentProvider(): AIProvider;
  
  /**
   * 测试连接
   */
  testConnection(): Promise<ConnectionTestResult>;
  
  /**
   * 获取可用厂商列表
   */
  getAvailableProviders(): AIProvider[];
  
  /**
   * 获取管理器状态
   */
  getState(): APIManagerState;
  
  /**
   * 销毁管理器
   */
  destroy(): void;
}

/**
 * API密钥管理器接口
 */
export interface IAPIKeyManager {
  /**
   * 初始化管理器
   */
  initialize(): Promise<void>;
  
  /**
   * 检查是否已初始化
   */
  isInitialized(): boolean;
  
  /**
   * 获取所有配置
   */
  getAllConfigs(): Map<AIProvider, APIKeyConfig>;
  
  /**
   * 获取指定厂商配置
   */
  getConfig(provider: AIProvider): APIKeyConfig | null;
  
  /**
   * 更新API密钥
   */
  updateApiKey(provider: AIProvider, apiKey: string): Promise<void>;
  
  /**
   * 验证API密钥格式
   */
  validateApiKey(provider: AIProvider, apiKey: string): APIKeyValidationResult;
  
  /**
   * 测试连接
   */
  testConnection(provider: AIProvider): Promise<ConnectionTestResult>;
  
  /**
   * 测试所有连接
   */
  testAllConnections(): Promise<ConnectionTestResult[]>;
  
  /**
   * 启用/禁用厂商
   */
  setProviderEnabled(provider: AIProvider, enabled: boolean): Promise<void>;
  
  /**
   * 获取支持的厂商信息
   */
  getSupportedProviders(): ProviderInfo[];
  
  /**
   * 销毁管理器
   */
  destroy(): void;
}

/**
 * 容器配置接口
 */
export interface IContainerConfig {
  /**
   * 是否启用开发模式
   */
  development?: boolean;
  
  /**
   * 是否启用日志
   */
  enableLogging?: boolean;
  
  /**
   * 是否启用循环依赖检测
   */
  enableCircularDependencyDetection?: boolean;
}

/**
 * 服务生命周期接口
 */
export interface IServiceLifecycle {
  /**
   * 初始化服务
   */
  initialize(): Promise<void>;
  
  /**
   * 销毁服务
   */
  destroy(): void;
}

/**
 * 服务工厂接口
 */
export interface IServiceFactory<T> {
  /**
   * 创建服务实例
   */
  create(): T;
  
  /**
   * 获取服务类型
   */
  getServiceType(): string;
}