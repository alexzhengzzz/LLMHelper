/**
 * MCP (Model Context Protocol) 协议类型定义
 * 基于JSON-RPC 2.0规范
 */

// 基础类型
type BaseType = string | number | boolean;
type ComplexType = JSONSchema | Array<BaseType | JSONSchema>;
type ParamType = Record<string, BaseType | ComplexType>;
type ResultType = BaseType | InitializeResult | ToolCallResult | ResourceListResult | ResourceReadResult | PromptListResult | PromptGetResult;
type ErrorDataType = BaseType | JSONRPCError | Array<BaseType | JSONRPCError>;

// JSON-RPC 2.0 基础类型
interface JSONRPCRequestType<T = ParamType> {
  jsonrpc: '2.0';
  id: string | number | null;
  method: string;
  params?: T;
}

interface JSONRPCResponseType<T = ResultType> {
  jsonrpc: '2.0';
  id: string | number | null;
  result?: T;
  error?: JSONRPCErrorType;
}

interface JSONRPCNotificationType<T = ParamType> {
  jsonrpc: '2.0';
  method: string;
  params?: T;
}

interface JSONRPCErrorType<T = ErrorDataType> {
  code: number;
  message: string;
  data?: T;
}

export interface JSONRPCRequest<T = ParamType> extends JSONRPCRequestType<T> {}
export interface JSONRPCResponse<T = ResultType> extends JSONRPCResponseType<T> {}
export interface JSONRPCNotification<T = ParamType> extends JSONRPCNotificationType<T> {}
export interface JSONRPCError<T = ErrorDataType> extends JSONRPCErrorType<T> {}

// MCP核心消息类型
export type MCPMessage = JSONRPCRequest | JSONRPCResponse | JSONRPCNotification;

// MCP能力定义
interface ServerCapabilitiesType {
  resources?: ResourcesCapability;
  tools?: ToolsCapability;
  prompts?: PromptsCapability;
  logging?: LoggingCapability;
}

interface ClientCapabilitiesType {
  sampling?: SamplingCapability;
  roots?: RootsCapability;
  experimental?: Record<string, BaseType | ComplexType>;
}

interface ResourcesCapabilityType {
  subscribe?: boolean;
  listChanged?: boolean;
}

interface ToolsCapabilityType {
  listChanged?: boolean;
}

interface PromptsCapabilityType {
  listChanged?: boolean;
}

interface LoggingCapabilityType {
  level?: LogLevel;
}

interface SamplingCapabilityType {}

interface RootsCapabilityType {
  listChanged?: boolean;
}

export interface ServerCapabilities extends ServerCapabilitiesType {}
export interface ClientCapabilities extends ClientCapabilitiesType {}
export interface ResourcesCapability extends ResourcesCapabilityType {}
export interface ToolsCapability extends ToolsCapabilityType {}
export interface PromptsCapability extends PromptsCapabilityType {}
export interface LoggingCapability extends LoggingCapabilityType {}
export interface SamplingCapability extends SamplingCapabilityType {}
export interface RootsCapability extends RootsCapabilityType {}

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
interface MCPToolType {
  name: string;
  description?: string;
  inputSchema: JSONSchema;
}

interface ToolResultType {
  content: Array<TextContent | ImageContent>;
  isError?: boolean;
}

interface TextContentType {
  type: 'text';
  text: string;
}

interface ImageContentType {
  type: 'image';
  data: string;
  mimeType: string;
}

// MCP资源定义
interface MCPResourceType {
  uri: string;
  name: string;
  description?: string;
  mimeType?: string;
}

interface ResourceContentsType {
  uri: string;
  mimeType?: string;
  text?: string;
  blob?: string;
}

// MCP提示词定义
interface MCPPromptType {
  name: string;
  description?: string;
  arguments?: Array<PromptArgument>;
}

interface PromptArgumentType {
  name: string;
  description?: string;
  required?: boolean;
}

interface PromptMessageType {
  role: 'user' | 'assistant';
  content: TextContent | ImageContent;
}

export interface MCPTool extends MCPToolType {}
export interface ToolResult extends ToolResultType {}
export interface TextContent extends TextContentType {}
export interface ImageContent extends ImageContentType {}
export interface MCPResource extends MCPResourceType {}
export interface ResourceContents extends ResourceContentsType {}
export interface MCPPrompt extends MCPPromptType {}
export interface PromptArgument extends PromptArgumentType {}
export interface PromptMessage extends PromptMessageType {}

// JSON Schema定义
export interface JSONSchema {
  type?: string;
  properties?: Record<string, JSONSchema>;
  required?: Array<string>;
  items?: JSONSchema;
  enum?: Array<string | number>;
  const?: string | number | boolean;
  description?: string;
  default?: BaseType | ComplexType;
  examples?: Array<BaseType | ComplexType>;
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

interface MCPServerConfigType {
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

interface MCPConnectionStateType {
  connected: boolean;
  connecting: boolean;
  error?: string;
  lastConnected?: number;
  serverInfo?: ServerInfo;
  capabilities?: ServerCapabilities;
}

interface ServerInfoType {
  name: string;
  version: string;
  protocolVersion: string;
}

export interface MCPServerConfig extends MCPServerConfigType {}
export interface MCPConnectionState extends MCPConnectionStateType {}
export interface ServerInfo extends ServerInfoType {}

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
interface ClientInfoType {
  name: string;
  version: string;
}

interface InitializeRequestType {
  protocolVersion: string;
  capabilities: ClientCapabilities;
  clientInfo: ClientInfoType;
}

interface InitializeResultType {
  protocolVersion: string;
  capabilities: ServerCapabilities;
  serverInfo: ServerInfo;
}

export interface InitializeRequest extends InitializeRequestType {}
export interface InitializeResult extends InitializeResultType {}

// 工具调用
interface ToolCallRequestType {
  name: string;
  arguments?: ParamType;
}

interface ToolCallResultType {
  content: Array<TextContent | ImageContent>;
  isError?: boolean;
}

export interface ToolCallRequest extends ToolCallRequestType {}
export interface ToolCallResult extends ToolCallResultType {}

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
interface MCPClientStateType {
  servers: Map<string, MCPConnectionState>;
  availableTools: Map<string, MCPTool>;
  availableResources: Map<string, MCPResource>;
  availablePrompts: Map<string, MCPPrompt>;
}

export interface MCPClientState extends MCPClientStateType {}

// 事件监听器类型
interface MCPEventType {
  type: string;
  serverId: string;
  data?: BaseType | JSONRPCError | Array<BaseType | JSONRPCError>;
  timestamp: number;
}

export interface MCPEvent extends MCPEventType {}
export type MCPEventListener = (event: MCPEvent) => void;

// 导出需要的类型
export type { ParamType };

// ========================================
// 应用拉起工具相关类型定义
// ========================================

/**
 * 应用启动参数类型
 */
export interface AppLaunchParameters {
  bundleName: string;
  abilityName?: string;
  parameters?: Record<string, string | number | boolean>;
}

/**
 * 应用启动结果枚举
 */
export enum AppLaunchResult {
  SUCCESS = 'success',
  PERMISSION_DENIED = 'permission_denied',
  APP_NOT_FOUND = 'app_not_found',
  LAUNCH_FAILED = 'launch_failed',
  INVALID_PARAMETERS = 'invalid_parameters'
}

/**
 * 应用启动权限枚举
 */
export enum AppLaunchPermission {
  START_ABILITIES_FROM_BACKGROUND = 'ohos.permission.START_ABILITIES_FROM_BACKGROUND',
  GET_BUNDLE_INFO = 'ohos.permission.GET_BUNDLE_INFO'
}

/**
 * 已安装应用信息类型
 */
export interface InstalledApplication {
  bundleName: string;
  appName: string;
  version: string;
}

/**
 * 应用启动验证结果类型
 */
export interface AppLaunchValidationResult {
  isValid: boolean;
  error?: string;
}

/**
 * 应用权限检查结果类型
 */
export interface AppLaunchPermissionCheck {
  hasPermissions: boolean;
  missingPermissions?: Array<AppLaunchPermission>;
  error?: string;
}

/**
 * 应用存在检查结果类型
 */
export interface AppLaunchExistenceCheck {
  exists: boolean;
  appName?: string;
  version?: string;
  error?: string;
}

/**
 * 应用启动执行结果类型
 */
export interface AppLaunchExecutionResult {
  result: AppLaunchResult;
  error?: string;
  details?: Record<string, string | number | boolean>;
}

/**
 * JSON Schema 扩展接口 - 用于应用启动工具
 */
export interface AppLauncherJSONSchema extends JSONSchema {
  type: string;
  required: Array<string>;
  properties: Record<string, JSONSchema>;
}

// ======================== 天气服务相关类型定义 ========================

/**
 * 天气查询类型枚举
 */
export enum WeatherQueryType {
  CURRENT = 'current',
  DAILY = 'daily',
  HOURLY = 'hourly',
  MINUTE = 'minute',
  ALERTS = 'alerts',
  INDICES = 'indices',
  TIDES = 'tides'
}

/**
 * 位置查询方式枚举
 */
export enum LocationQueryType {
  COORDINATES = 'coordinates',
  CITY_NAME = 'city_name',
  AUTO_LOCATION = 'auto_location'
}

/**
 * 天气查询参数接口
 */
export interface WeatherQueryParameters {
  queryType: WeatherQueryType;
  locationType: LocationQueryType;
  latitude?: number;
  longitude?: number;
  cityName?: string;
  days?: number;
  hours?: number;
}

/**
 * 位置信息接口
 */
export interface WeatherLocation {
  latitude: number;
  longitude: number;
  cityName?: string;
  address?: string;
}

/**
 * 当前天气数据接口
 */
export interface CurrentWeatherData {
  temperature: number;
  humidity: number;
  pressure: number;
  windSpeed: number;
  windDirection: number;
  weatherCondition: string;
  weatherDescription: string;
  visibility: number;
  uvIndex: number;
  feelLike: number;
  updateTime: string;
}

/**
 * 每日天气预报接口
 */
export interface DailyWeatherData {
  date: string;
  maxTemperature: number;
  minTemperature: number;
  weatherCondition: string;
  weatherDescription: string;
  windSpeed: number;
  windDirection: number;
  humidity: number;
  pressure: number;
  uvIndex: number;
  sunrise: string;
  sunset: string;
}

/**
 * 每小时天气预报接口
 */
export interface HourlyWeatherData {
  time: string;
  temperature: number;
  humidity: number;
  pressure: number;
  windSpeed: number;
  windDirection: number;
  weatherCondition: string;
  weatherDescription: string;
  precipitation: number;
}

/**
 * 分钟级降水预报接口
 */
export interface MinutePrecipitationData {
  time: string;
  intensity: number;
  description: string;
}

/**
 * 天气预警信息接口
 */
export interface WeatherAlertData {
  alertId: string;
  title: string;
  description: string;
  severity: string;
  certainty: string;
  urgency: string;
  startTime: string;
  endTime: string;
  areas: Array<string>;
}

/**
 * 生活指数接口
 */
export interface WeatherIndicesData {
  name: string;
  level: string;
  category: string;
  description: string;
  advice: string;
}

/**
 * 潮汐信息接口
 */
export interface TideData {
  time: string;
  height: number;
  type: string;
  description: string;
}

/**
 * 天气服务响应数据接口
 */
export interface WeatherServiceResponse {
  location: WeatherLocation;
  current?: CurrentWeatherData;
  daily?: Array<DailyWeatherData>;
  hourly?: Array<HourlyWeatherData>;
  minute?: Array<MinutePrecipitationData>;
  alerts?: Array<WeatherAlertData>;
  indices?: Array<WeatherIndicesData>;
  tides?: Array<TideData>;
  requestTime: string;
}

/**
 * 天气服务权限枚举
 */
export enum WeatherServicePermission {
  LOCATION = 'ohos.permission.APPROXIMATELY_LOCATION',
  INTERNET = 'ohos.permission.INTERNET'
}

/**
 * 天气服务验证结果接口
 */
export interface WeatherServiceValidationResult {
  isValid: boolean;
  error?: string;
}

/**
 * 天气服务权限检查结果接口
 */
export interface WeatherServicePermissionCheck {
  hasPermissions: boolean;
  missingPermissions?: Array<WeatherServicePermission>;
  error?: string;
}

/**
 * 通用执行结果接口
 */
export interface GenericExecutionResult<T> {
  success: boolean;
  data?: T;
  error?: string;
  errorCode?: string;
}

/**
 * 天气服务执行结果接口
 */
export interface WeatherServiceExecutionResult extends GenericExecutionResult<WeatherServiceResponse> {}

/**
 * JSON Schema 扩展接口 - 用于天气服务工具
 */
export interface WeatherServiceJSONSchema extends JSONSchema {
  type: string;
  required: Array<string>;
  properties: Record<string, JSONSchema>;
}

/**
 * 城市坐标接口
 */
export interface CityCoordinates {
  lat: number;
  lon: number;
}

/**
 * 城市坐标映射接口
 */
export interface CityCoordinatesMap extends Record<string, CityCoordinates> {}

// ======================== MCP工具配置相关类型定义 ========================

/**
 * MCP工具配置接口
 */
export interface MCPToolConfig {
  name: string;
  enabled: boolean;
  category: MCPToolCategory;
  priority: number;
  description?: string;
  lastUsed?: number;
  usageCount: number;
  configurable: boolean;
  systemTool: boolean;
}

/**
 * MCP工具分类枚举
 */
export enum MCPToolCategory {
  UTILITY = 'utility',         // 实用工具
  SYSTEM = 'system',           // 系统工具
  APPLICATION = 'application', // 应用管理
  FILESYSTEM = 'filesystem',   // 文件系统
  NETWORK = 'network',         // 网络工具
  CUSTOM = 'custom'            // 自定义工具
}

/**
 * 工具启用状态映射
 */
export interface ToolEnabledMap extends Record<string, boolean> {}

/**
 * 工具使用统计映射
 */
export interface ToolUsageStatsMap extends Record<string, number> {}

/**
 * MCP工具状态枚举
 */
export enum MCPToolStatus {
  ENABLED = 'enabled',
  DISABLED = 'disabled',
  ERROR = 'error',
  LOADING = 'loading'
}

/**
 * 工具配置更新请求
 */
export interface ToolConfigUpdateRequest {
  toolName: string;
  enabled?: boolean;
  priority?: number;
  description?: string;
}

/**
 * 批量工具配置更新请求
 */
export interface BatchToolConfigUpdateRequest {
  toolUpdates: Array<ToolConfigUpdateRequest>;
  globalEnabled?: boolean;
}

/**
 * 工具配置验证结果
 */
export interface ToolConfigValidationResult {
  isValid: boolean;
  errors: Array<string>;
  warnings: Array<string>;
}

/**
 * 工具统计信息
 */
export interface ToolStatistics {
  totalTools: number;
  enabledTools: number;
  disabledTools: number;
  mostUsedTool?: string;
  leastUsedTool?: string;
  totalUsage: number;
  categoryStats: Record<MCPToolCategory, number>;
}

/**
 * 工具搜索过滤器
 */
export interface ToolSearchFilter {
  query?: string;
  category?: MCPToolCategory;
  status?: MCPToolStatus;
  sortBy?: 'name' | 'usage' | 'lastUsed' | 'priority';
  sortOrder?: 'asc' | 'desc';
}

/**
 * 工具操作结果
 */
export interface ToolOperationResult {
  success: boolean;
  message: string;
  toolName?: string;
  error?: string;
  data?: Record<string, BaseType | JSONRPCError | Array<BaseType | JSONRPCError>>;
}

/**
 * 工具批量操作结果
 */
export interface BatchToolOperationResult {
  success: boolean;
  message: string;
  results: Array<ToolOperationResult>;
  totalCount: number;
  successCount: number;
  failureCount: number;
}