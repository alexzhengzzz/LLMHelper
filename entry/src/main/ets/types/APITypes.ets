/**
 * API类型定义
 * 严格遵循ArkTS类型系统要求
 */

// 位置坐标接口
export interface Position {
  x: number;
  y: number;
}

// API调用模式枚举
export enum APIMode {
  SERVER_PROXY = 'server_proxy',
  DIRECT_CALL = 'direct_call'
}

// 支持的AI厂商
export enum AIProvider {
  GLM = 'glm',
  SILICONFLOW = 'siliconflow',
  GEMINI = 'gemini' // 已禁用 - 暂不可用
}

// 消息接口
export interface ChatMessage {
  role: string;
  content: string;
  tool_calls?: ToolCall[]; // 工具调用列表
  tool_call_id?: string; // 工具结果消息的ID
}

// 工具调用接口
export interface ToolCall {
  id: string;
  type: 'function';
  function: ToolCallFunction;
}

export interface ToolCallFunction {
  name: string;
  arguments: string; // JSON字符串格式的参数
}

// 工具结果消息接口
export interface ToolResultMessage {
  role: 'tool';
  tool_call_id: string;
  content: string;
}

// 聊天请求接口
export interface ChatRequest {
  messages: ChatMessage[];
  model?: string;
  max_tokens?: number;
  temperature?: number;
  stream?: boolean;
  enable_web?: boolean; // 是否启用联网搜索
  timeout?: number; // 请求超时时间(毫秒)
  tools?: Tool[]; // 工具定义列表
  tool_choice?: string; // 工具选择策略：'auto', 'none', 或特定工具名
}

// 工具定义接口
export interface Tool {
  type: 'function';
  function: ToolFunction;
}

export interface ToolFunction {
  name: string;
  description: string;
  parameters: ToolParameters;
}

export interface ToolParameters {
  type: 'object';
  properties: Record<string, ParameterProperty>;
  required: string[];
}

export interface ParameterProperty {
  type: string;
  description?: string;
  enum?: string[];
}

// 聊天响应接口
export interface ChatResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: ChatChoice[];
  usage: TokenUsage;
  web_used?: boolean; // 是否使用了联网搜索
  search_info?: string; // 搜索相关信息
  tool_status?: string; // 工具调用状态："idle", "calling", "completed", "failed"
}

export interface ChatChoice {
  index: number;
  message: ChatMessage;
  finish_reason: string;
}

export interface TokenUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

// API配置接口
export interface APIConfig {
  provider: AIProvider;
  model: string;
  apiKey: string;
  baseUrl: string;
}

// API响应基础接口
export interface BaseAPIResponse {
  success: boolean;
  data?: ChatResponse;
  error?: string;
}

// 连接测试结果接口
export interface ConnectionTestResult {
  success: boolean;
  mode: APIMode;
  provider?: AIProvider;
  message: string;
  latency?: number;
}

// HTTP请求配置接口
export interface RequestConfig {
  url: string;
  method: string;
  headers: Map<string, string>;
  body?: string;
  timeout?: number;
}

// 错误信息接口
export interface APIError {
  code: string;
  message: string;
  details?: string;
}

// 厂商配置映射接口
export interface ProviderConfig {
  name: string;
  baseUrl: string;
  models: string[];
  headers: Map<string, string>;
}

// 模式配置接口
export interface ModeConfig {
  displayName: string;
  description: string;
  enabled: boolean;
}

// API管理器状态接口
export interface APIManagerState {
  currentMode: APIMode;
  currentProvider: AIProvider;
  isInitialized: boolean;
  lastTestResult?: ConnectionTestResult;
}

// GLM特定接口
export interface GLMRequestBody {
  model: string;
  messages: ChatMessage[];
  max_tokens: number;
  temperature: number;
  stream: boolean;
  tools?: Tool[]; // 工具定义列表
  tool_choice?: string; // 工具选择策略
}

export interface GLMResponse extends StandardProviderResponse {
  choices: GLMChoice[];
  usage: GLMUsage;
  error?: GLMError;
}

export interface GLMChoice {
  index: number;
  message: ChatMessage;
  finish_reason: string;
}

export interface GLMUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

export interface GLMError {
  message: string;
  type: string;
  code: string;
}

// SiliconFlow特定接口
export interface SiliconFlowRequestBody {
  model: string;
  messages: ChatMessage[];
  max_tokens: number;
  temperature: number;
  stream: boolean;
  tools?: Tool[]; // 工具定义列表
  tool_choice?: string; // 工具选择策略
}

export interface SiliconFlowResponse extends StandardProviderResponse {
  choices: SiliconFlowChoice[];
  usage: SiliconFlowUsage;
  error?: SiliconFlowError;
}

export interface SiliconFlowChoice {
  index: number;
  message: ChatMessage;
  finish_reason: string;
}

export interface SiliconFlowUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

export interface SiliconFlowError {
  message: string;
  type: string;
  code: string;
}

// Gemini特定接口
export interface GeminiRequestBody {
  contents: GeminiContent[];
  generationConfig: GeminiGenerationConfig;
  safetySettings: GeminiSafetySetting[];
}

export interface GeminiContent {
  role: string;
  parts: GeminiPart[];
}

export interface GeminiPart {
  text: string;
}

export interface GeminiGenerationConfig {
  maxOutputTokens: number;
  temperature: number;
  topK: number;
  topP: number;
}

export interface GeminiSafetySetting {
  category: string;
  threshold: string;
}

export interface GeminiResponse {
  candidates: GeminiCandidate[];
  usageMetadata?: GeminiUsageMetadata;
  error?: GeminiError;
}

export interface GeminiCandidate {
  content: GeminiContent;
  finishReason?: string;
  index: number;
}

export interface GeminiUsageMetadata {
  promptTokenCount: number;
  candidatesTokenCount: number;
  totalTokenCount: number;
}

export interface GeminiError {
  message: string;
  code: number;
}

// 服务统计信息接口
export interface ServiceStats {
  supportedProviders: number;
  initializedClients: number;
  availableProviders: AIProvider[];
}

// HTTP请求选项接口
export interface HttpRequestOptions {
  method: string;
  header: Record<string, string>;
  extraData?: string;
  expectDataType: string;
  connectTimeout: number;
  readTimeout: number;
}

// 错误提取结果接口
export interface ErrorExtractResult {
  message: string;
  code: string;
}

// 泛型响应解析器接口
export interface ResponseParser<T extends StandardProviderResponse> {
  parse(responseData: string): ChatResponse;
  getProviderName(): string;
  getModelEndpoint(): string;
  getModelsEndpoint(): string;
  getLocalFallbackModels(): string[];
  validateResponse?(response: T): boolean;
  extractError?(response: T): ErrorExtractResult | null;
}

// 基础厂商响应接口（通用字段）
export interface BaseProviderResponse {
  id: string;
  object: string;
  created: number;
  model: string;
}

// 基础厂商选择接口
export interface BaseProviderChoice {
  index: number;
  message: ChatMessage;
  finish_reason: string;
}

// 基础厂商使用量接口
export interface BaseProviderUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

// 基础厂商错误接口
export interface BaseProviderError {
  message: string;
  code?: string;
  type?: string;
}

// 标准化厂商响应接口
export interface StandardProviderResponse extends BaseProviderResponse {
  choices: BaseProviderChoice[];
  usage: BaseProviderUsage;
  error?: BaseProviderError;
}

// 模型缓存配置接口
export interface ModelCacheConfig {
  duration: number; // 缓存持续时间（毫秒）
  enabled: boolean; // 是否启用缓存
  forceRefresh?: boolean; // 是否强制刷新
}