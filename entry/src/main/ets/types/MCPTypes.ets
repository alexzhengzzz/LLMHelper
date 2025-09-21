/**
 * MCP (Model Context Protocol) 协议类型定义
 * 基于JSON-RPC 2.0规范
 */

// JSON-RPC 2.0 基础类型
export interface JSONRPCRequest {
  jsonrpc: '2.0';
  id: string | number | null;
  method: string;
  params?: Record<string, ESObject>;
}

export interface JSONRPCResponse {
  jsonrpc: '2.0';
  id: string | number | null;
  result?: ESObject;
  error?: JSONRPCError;
}

export interface JSONRPCNotification {
  jsonrpc: '2.0';
  method: string;
  params?: Record<string, ESObject>;
}

export interface JSONRPCError {
  code: number;
  message: string;
  data?: ESObject;
}

// MCP核心消息类型
export type MCPMessage = JSONRPCRequest | JSONRPCResponse | JSONRPCNotification;

// MCP能力定义
export interface ServerCapabilities {
  resources?: ResourcesCapability;
  tools?: ToolsCapability;
  prompts?: PromptsCapability;
  logging?: LoggingCapability;
}

export interface ClientCapabilities {
  sampling?: SamplingCapability;
  roots?: RootsCapability;
  experimental?: Record<string, ESObject>;
}

export interface ResourcesCapability {
  subscribe?: boolean;
  listChanged?: boolean;
}

export interface ToolsCapability {
  listChanged?: boolean;
}

export interface PromptsCapability {
  listChanged?: boolean;
}

export interface LoggingCapability {
  level?: LogLevel;
}

export interface SamplingCapability {}

export interface RootsCapability {
  listChanged?: boolean;
}

// 日志级别
export enum LogLevel {
  DEBUG = 'debug',
  INFO = 'info',
  NOTICE = 'notice',
  WARNING = 'warning',
  ERROR = 'error',
  CRITICAL = 'critical',
  ALERT = 'alert',
  EMERGENCY = 'emergency'
}

// MCP工具定义
export interface MCPTool {
  name: string;
  description?: string;
  inputSchema: JSONSchema;
}

export interface ToolResult {
  content: Array<TextContent | ImageContent>;
  isError?: boolean;
}

export interface TextContent {
  type: 'text';
  text: string;
}

export interface ImageContent {
  type: 'image';
  data: string;
  mimeType: string;
}

// MCP资源定义
export interface MCPResource {
  uri: string;
  name: string;
  description?: string;
  mimeType?: string;
}

export interface ResourceContents {
  uri: string;
  mimeType?: string;
  text?: string;
  blob?: string;
}

// MCP提示词定义
export interface MCPPrompt {
  name: string;
  description?: string;
  arguments?: Array<PromptArgument>;
}

export interface PromptArgument {
  name: string;
  description?: string;
  required?: boolean;
}

export interface PromptMessage {
  role: 'user' | 'assistant';
  content: TextContent | ImageContent;
}

// JSON Schema定义
export interface JSONSchema {
  type?: string;
  properties?: Record<string, JSONSchema>;
  required?: Array<string>;
  items?: JSONSchema;
  enum?: Array<string | number>;
  const?: string | number | boolean;
  description?: string;
  default?: ESObject;
  examples?: Array<ESObject>;
  format?: string;
  pattern?: string;
  minimum?: number;
  maximum?: number;
  minLength?: number;
  maxLength?: number;
  minItems?: number;
  maxItems?: number;
  uniqueItems?: boolean;
  additionalProperties?: boolean | JSONSchema;
  oneOf?: Array<JSONSchema>;
  anyOf?: Array<JSONSchema>;
  allOf?: Array<JSONSchema>;
  not?: JSONSchema;
  if?: JSONSchema;
  then?: JSONSchema;
  else?: JSONSchema;
}

// MCP连接和传输
export enum MCPTransportType {
  STDIO = 'stdio',
  HTTP_SSE = 'http_sse'
}

export interface MCPServerConfig {
  name: string;
  description?: string;
  transportType: MCPTransportType;
  command?: string;
  args?: Array<string>;
  env?: Record<string, string>;
  url?: string;
  timeout?: number;
  retryAttempts?: number;
}

export interface MCPConnectionState {
  connected: boolean;
  connecting: boolean;
  error?: string;
  lastConnected?: number;
  serverInfo?: ServerInfo;
  capabilities?: ServerCapabilities;
}

export interface ServerInfo {
  name: string;
  version: string;
  protocolVersion: string;
}

// MCP消息类型枚举
export enum MCPMessageType {
  // 初始化
  INITIALIZE = 'initialize',
  INITIALIZED = 'initialized',

  // 工具相关
  TOOLS_LIST = 'tools/list',
  TOOLS_CALL = 'tools/call',

  // 资源相关
  RESOURCES_LIST = 'resources/list',
  RESOURCES_READ = 'resources/read',
  RESOURCES_SUBSCRIBE = 'resources/subscribe',
  RESOURCES_UNSUBSCRIBE = 'resources/unsubscribe',

  // 提示词相关
  PROMPTS_LIST = 'prompts/list',
  PROMPTS_GET = 'prompts/get',

  // 日志相关
  LOGGING_SET_LEVEL = 'logging/setLevel',

  // 通知
  NOTIFICATION_CANCELLED = 'notifications/cancelled',
  NOTIFICATION_PROGRESS = 'notifications/progress',
  NOTIFICATION_RESOURCES_LIST_CHANGED = 'notifications/resources/list_changed',
  NOTIFICATION_TOOLS_LIST_CHANGED = 'notifications/tools/list_changed',
  NOTIFICATION_PROMPTS_LIST_CHANGED = 'notifications/prompts/list_changed'
}

// 初始化消息
export interface InitializeRequest {
  protocolVersion: string;
  capabilities: ClientCapabilities;
  clientInfo: {
    name: string;
    version: string;
  };
}

export interface InitializeResult {
  protocolVersion: string;
  capabilities: ServerCapabilities;
  serverInfo: ServerInfo;
}

// 工具调用
export interface ToolCallRequest {
  name: string;
  arguments?: Record<string, ESObject>;
}

export interface ToolCallResult {
  content: Array<TextContent | ImageContent>;
  isError?: boolean;
}

// 资源请求
export interface ResourceListRequest {
  cursor?: string;
}

export interface ResourceListResult {
  resources: Array<MCPResource>;
  nextCursor?: string;
}

export interface ResourceReadRequest {
  uri: string;
}

export interface ResourceReadResult {
  contents: Array<ResourceContents>;
}

// 提示词请求
export interface PromptListRequest {
  cursor?: string;
}

export interface PromptListResult {
  prompts: Array<MCPPrompt>;
  nextCursor?: string;
}

export interface PromptGetRequest {
  name: string;
  arguments?: Record<string, string>;
}

export interface PromptGetResult {
  description?: string;
  messages: Array<PromptMessage>;
}

// 进度通知
export interface ProgressNotification {
  progressToken: string | number;
  progress: number;
  total?: number;
}

// 错误代码
export enum MCPErrorCode {
  // 标准JSON-RPC错误
  PARSE_ERROR = -32700,
  INVALID_REQUEST = -32600,
  METHOD_NOT_FOUND = -32601,
  INVALID_PARAMS = -32602,
  INTERNAL_ERROR = -32603,

  // MCP特定错误
  INVALID_TOOL = -32000,
  INVALID_RESOURCE = -32001,
  INVALID_PROMPT = -32002,
  RESOURCE_NOT_FOUND = -32003,
  TOOL_EXECUTION_ERROR = -32004,
  UNSUPPORTED_OPERATION = -32005
}

// MCP客户端状态
export interface MCPClientState {
  servers: Map<string, MCPConnectionState>;
  availableTools: Map<string, MCPTool>;
  availableResources: Map<string, MCPResource>;
  availablePrompts: Map<string, MCPPrompt>;
}

// 事件监听器类型
export type MCPEventListener = (event: MCPEvent) => void;

export interface MCPEvent {
  type: string;
  serverId: string;
  data?: ESObject;
  timestamp: number;
}

// 导出所有类型
export {
  MCPTool,
  MCPResource,
  MCPPrompt,
  MCPServerConfig,
  MCPConnectionState,
  MCPClientState,
  MCPMessage,
  JSONRPCRequest,
  JSONRPCResponse,
  JSONRPCNotification,
  JSONRPCError
};