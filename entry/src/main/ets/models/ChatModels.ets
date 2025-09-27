/**
 * 聊天相关数据模型
 */

// 导入通用工具类型
import { Tool, ParameterProperty, ToolCall } from '../types/APITypes';

// 消息类型枚举
export enum MessageRole {
  USER = 'user',
  ASSISTANT = 'assistant',
  SYSTEM = 'system'
}

// 消息序列化接口
export interface ThinkingStepData {
  id: string;
  title: string;
  description: string;
  content: string;
  status: StepStatus;
  startTime?: number;
  endTime?: number;
  duration?: number;
  error?: string;
}

export interface MessageData {
  id?: string;
  role: string;
  content: string;
  timestamp: number;
  isLoading?: boolean;
  isPlaying?: boolean;
  canPlayAudio?: boolean;
  toolStatus?: string;
  toolType?: string;
  toolName?: string;
  mcpToolNames?: string[];
  webUsed?: boolean;
  searchInfo?: string;
  searchDetails?: string;
  isDeepThinking?: boolean;
  thinkingSteps?: ThinkingStepData[];
  thinkingStatus?: ThinkingStatus;
  senderRoleId?: string;
  senderName?: string;
  senderAvatar?: string;
}

// 深度思考状态枚举
export enum ThinkingStatus {
  IDLE = 'idle',           // 空闲状态
  PLANNING = 'planning',   // 推理规划
  ANALYZING = 'analyzing', // 分析阶段
  RESEARCHING = 'researching', // 检索阶段
  THINKING = 'thinking',   // 思考阶段  
  VERIFYING = 'verifying', // 验证阶段
  INTEGRATING = 'integrating', // 整合阶段
  REFINING = 'refining',   // 质量复盘
  COMPLETED = 'completed', // 已完成
  FAILED = 'failed',       // 失败
  CANCELLED = 'cancelled'  // 已取消
}

// 思考步骤状态枚举
export enum StepStatus {
  PENDING = 'pending',     // 待处理
  PROCESSING = 'processing', // 处理中
  COMPLETED = 'completed', // 已完成
  FAILED = 'failed'        // 失败
}

// 深度思考步骤模型
@ObservedV2
export class ThinkingStep {
  @Trace id: string = '';
  @Trace title: string = '';
  @Trace description: string = '';
  @Trace content: string = '';
  @Trace status: StepStatus = StepStatus.PENDING;
  @Trace startTime?: number;
  @Trace endTime?: number;
  @Trace duration?: number; // 毫秒
  @Trace error?: string;

  constructor(id: string, title: string, description: string) {
    this.id = id;
    this.title = title;
    this.description = description;
    this.status = StepStatus.PENDING;
  }

  // 开始处理
  start(): void {
    this.status = StepStatus.PROCESSING;
    this.startTime = Date.now();
  }

  // 完成处理
  complete(content: string): void {
    this.content = content;
    this.status = StepStatus.COMPLETED;
    this.endTime = Date.now();
    if (this.startTime) {
      this.duration = this.endTime - this.startTime;
    }
  }

  // 失败处理
  fail(error: string): void {
    this.error = error;
    this.status = StepStatus.FAILED;
    this.endTime = Date.now();
    if (this.startTime) {
      this.duration = this.endTime - this.startTime;
    }
  }

  static fromObject(data: ThinkingStepData): ThinkingStep {
    const step = new ThinkingStep(data.id, data.title, data.description);
    step.content = data.content;
    step.status = data.status;
    step.startTime = data.startTime;
    step.endTime = data.endTime;
    step.duration = data.duration;
    step.error = data.error;
    return step;
  }

  toObject(): ThinkingStepData {
    return {
      id: this.id,
      title: this.title,
      description: this.description,
      content: this.content,
      status: this.status,
      startTime: this.startTime,
      endTime: this.endTime,
      duration: this.duration,
      error: this.error
    };
  }
}

// 聊天消息模型
@ObservedV2
export class Message {
  @Trace id: string = '';
  @Trace role: MessageRole = MessageRole.USER;
  @Trace content: string = '';
  @Trace timestamp: number = 0;
  @Trace senderRoleId?: string;
  @Trace senderName?: string;
  @Trace senderAvatar?: string;
  @Trace isLoading?: boolean = false;
  @Trace isPlaying?: boolean = false; // 是否正在播放语音
  @Trace canPlayAudio?: boolean = false; // 是否可以播放语音（只有assistant消息可播放）
  @Trace toolStatus?: string = 'idle'; // 工具调用状态："idle", "calling", "completed", "failed"
  @Trace toolType?: string = ''; // 工具类型："search", "mcp", "function", "code_execution"
  @Trace toolName?: string = ''; // 工具名称，显示具体调用的工具
  @Trace mcpToolNames?: string[] = []; // MCP工具名称列表，支持多个工具调用
  @Trace webUsed?: boolean = false; // 是否使用了网络搜索
  @Trace searchInfo?: string = ''; // 网络搜索信息（简化版）
  @Trace searchDetails?: string = ''; // 网络搜索详细信息（用于气泡显示）
  @Trace isDeepThinking?: boolean = false; // 是否为深度思考模式生成的消息
  @Trace thinkingSteps?: ThinkingStep[] = []; // 深度思考步骤
  @Trace thinkingStatus?: ThinkingStatus = ThinkingStatus.IDLE; // 深度思考状态

  constructor(role: MessageRole, content: string, id?: string) {
    this.id = id || this.generateId();
    this.role = role;
    this.content = content;
    this.timestamp = Date.now();
    this.senderRoleId = undefined;
    this.senderName = undefined;
    this.senderAvatar = undefined;
    // 只有assistant消息可以播放语音
    this.canPlayAudio = role === MessageRole.ASSISTANT;
    this.isPlaying = false;
    this.toolType = '';
    this.toolName = '';
    this.mcpToolNames = [];
    this.webUsed = false;
    this.searchInfo = '';
    this.searchDetails = '';
    this.isDeepThinking = false;
    this.thinkingSteps = [];
    this.thinkingStatus = ThinkingStatus.IDLE;
  }

  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  }

  static fromObject(data: MessageData): Message {
    const role = (data.role as MessageRole) || MessageRole.USER;
    const message = new Message(role, data.content || '', data.id);
    message.timestamp = data.timestamp || Date.now();
    message.isLoading = data.isLoading ?? false;
    message.isPlaying = data.isPlaying ?? false;
    message.canPlayAudio = data.canPlayAudio ?? (role === MessageRole.ASSISTANT);
    message.toolStatus = data.toolStatus || 'idle';
    message.toolType = data.toolType || '';
    message.toolName = data.toolName || '';
    message.mcpToolNames = data.mcpToolNames || [];
    message.webUsed = data.webUsed || false;
    message.searchInfo = data.searchInfo || '';
    message.searchDetails = data.searchDetails || '';
    message.isDeepThinking = data.isDeepThinking || false;
    message.thinkingSteps = (data.thinkingSteps || []).map(step => ThinkingStep.fromObject(step));
    message.thinkingStatus = data.thinkingStatus || ThinkingStatus.IDLE;
    message.senderRoleId = data.senderRoleId;
    message.senderName = data.senderName;
    message.senderAvatar = data.senderAvatar;
    return message;
  }

  toObject(): MessageData {
    return {
      id: this.id,
      role: this.role,
      content: this.content,
      timestamp: this.timestamp,
      isLoading: this.isLoading,
      isPlaying: this.isPlaying,
      canPlayAudio: this.canPlayAudio,
      toolStatus: this.toolStatus,
      toolType: this.toolType,
      toolName: this.toolName,
      mcpToolNames: this.mcpToolNames,
      webUsed: this.webUsed,
      searchInfo: this.searchInfo,
      searchDetails: this.searchDetails,
      isDeepThinking: this.isDeepThinking,
      thinkingSteps: this.thinkingSteps?.map(step => step.toObject()),
      thinkingStatus: this.thinkingStatus,
      senderRoleId: this.senderRoleId,
      senderName: this.senderName,
      senderAvatar: this.senderAvatar
    };
  }
}

// 简单消息接口，用于API请求
export interface SimpleMessage {
  role: string;
  content: string;
}

// 聊天请求模型
export interface ChatRequest {
  provider?: string;
  model: string;
  messages: SimpleMessage[];
  enable_web?: boolean; // 是否启用联网搜索
}

// 聊天响应模型
export interface ChatResponse {
  model: string;
  content: string;
  error?: string;
  web_used?: boolean; // 是否使用了联网搜索
  search_info?: string; // 搜索相关信息
  tool_status?: string; // 工具调用状态："idle", "calling", "completed", "failed"
}

// 代码执行请求模型
export interface ExecuteRequest {
  code: string;
  language: string;
}

// 代码执行响应模型
export interface ExecuteResponse {
  output: string;
  error?: string;
}

// 厂商信息模型
@ObservedV2
export class Provider {
  @Trace name: string = '';
  @Trace models: string[] = [];

  constructor(name: string, models: string[]) {
    this.name = name;
    this.models = models;
  }
}

// 系统提示词序列化接口
export interface SystemPromptData {
  id: string;
  name: string;
  content: string;
  timestamp: number;
  isRole: boolean;
  roleCategory: string;
  roleIcon: string;
  roleDescription: string;
  isBuiltIn: boolean;
  usageCount: number;
  isPinned: boolean;
}

// 系统提示词模型
@ObservedV2
export class SystemPrompt {
  @Trace id: string = '';
  @Trace name: string = '';
  @Trace content: string = '';
  @Trace timestamp: number = 0;
  @Trace isRole: boolean = false;        // 是否为角色
  @Trace roleCategory: string = '';       // 角色分类：'professional', 'creative', 'life', 'psychology', 'custom'
  @Trace roleIcon: string = '';           // 角色图标
  @Trace roleDescription: string = '';    // 角色描述
  @Trace isBuiltIn: boolean = false;       // 是否为内置角色（不可删除）
  @Trace usageCount: number = 0;           // 使用次数统计
  @Trace isPinned: boolean = false;        // 是否置顶

  constructor(name: string = '', content: string = '', id?: string, isRole: boolean = false, roleCategory: string = '', roleIcon: string = '', roleDescription: string = '', isBuiltIn: boolean = false) {
    this.id = id || this.generateId();
    this.name = name;
    this.content = content;
    this.timestamp = Date.now();
    this.isRole = isRole;
    this.roleCategory = roleCategory;
    this.roleIcon = roleIcon;
    this.roleDescription = roleDescription;
    this.isBuiltIn = isBuiltIn;
    this.usageCount = 0;
    this.isPinned = false;
  }

  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  }

  // 添加一个静态方法用于从普通对象创建SystemPrompt实例
  static fromObject(obj: SystemPromptData): SystemPrompt {
    const prompt = new SystemPrompt();
    prompt.id = obj.id || prompt.generateId();
    prompt.name = obj.name || '';
    prompt.content = obj.content || '';
    prompt.timestamp = obj.timestamp || Date.now();
    prompt.isRole = obj.isRole || false;
    prompt.roleCategory = obj.roleCategory || '';
    prompt.roleIcon = obj.roleIcon || '';
    prompt.roleDescription = obj.roleDescription || '';
    prompt.isBuiltIn = obj.isBuiltIn || false;
    prompt.usageCount = obj.usageCount || 0;
    prompt.isPinned = obj.isPinned || false;
    return prompt;
  }

  // 转换为可序列化对象
  toObject(): SystemPromptData {
    return {
      id: this.id,
      name: this.name,
      content: this.content,
      timestamp: this.timestamp,
      isRole: this.isRole,
      roleCategory: this.roleCategory,
      roleIcon: this.roleIcon,
      roleDescription: this.roleDescription,
      isBuiltIn: this.isBuiltIn,
      usageCount: this.usageCount,
      isPinned: this.isPinned
    };
  }
}

// 厂商列表响应模型
export interface ProvidersResponse {
  providers: Record<string, string[]>;
}

//=================== 搜索相关模型 ===================

// 搜索请求模型
export interface SearchRequest {
  query: string;
}

// 搜索结果模型
export interface SearchResult {
  title: string;
  url: string;
  snippet: string;
}

// 搜索响应模型
export interface SearchResponse {
  results: SearchResult[];
  error?: string;
}

//=================== Function Calling 相关模型 ===================

// 工具类型
export type ToolType = 'function';

// 重新导出工具类型，保持兼容性
export { Tool, ParameterProperty, ToolCall };

// 参数定义
export interface ParametersDefinition {
  type: string;
  properties: Record<string, ParameterProperty>;
  required: string[];
}

// 函数工具定义
export interface ToolFunction {
  name: string;
  description: string;
  parameters: ParametersDefinition;
}

// 保留兼容性的类型别名
export interface ToolCallFunction {
  name: string;
  arguments: string; // JSON字符串
}

// 增强消息模型（支持工具调用）
export interface EnhancedMessage {
  role: string; // "user", "assistant", "system", "tool"
  content: string;
  tool_calls?: ToolCall[]; // assistant消息中的工具调用
  tool_call_id?: string; // tool消息中的调用ID
}

// 工具选择函数配置
export interface ToolChoiceFunctionConfig {
  name: string;
}

// 工具选择配置
export interface ToolChoiceConfig {
  type: "function";
  function: ToolChoiceFunctionConfig;
}

// 工具选择类型定义
export type ToolChoiceType = "auto" | "none" | ToolChoiceConfig;

// Function Calling 聊天请求模型
export interface FunctionCallingChatRequest {
  model: string;
  messages: EnhancedMessage[];
  tools?: Tool[];
  tool_choice?: ToolChoiceType;
  enable_web?: boolean;
}

// Function Calling 聊天响应模型
export interface FunctionCallingChatResponse {
  model: string;
  content: string;
  error?: string;
  web_used?: boolean;
  search_info?: string;
  tool_calls?: ToolCall[];
  tool_status?: string; // "idle", "calling", "completed", "failed"
  finish_reason?: string; // "stop", "tool_calls", "length"
}

// 工具列表响应模型
export interface ToolsResponse {
  tools: Tool[];
}

// WebSocket相关接口定义
export interface SessionInfo {
  id: string;
  name: string;
  working_dir: string;
  active: boolean;
  created_at: number;
  last_active_at: number;
}

export interface SessionCreateData {
  name?: string;
  working_dir?: string;
}

export interface SessionSwitchData {
  session_id: string;
}

export interface SessionCloseData {
  session_id: string;
}

export interface SessionListData {
  sessions?: SessionInfo[];
  active_session_id?: string;
}

export interface SessionCreatedData {
  session?: SessionInfo;
}

export interface SessionSwitchedData {
  session_id?: string;
}

export interface TerminalInputData {
  input: string;
}

export interface TerminalResizeData {
  cols: number;
  rows: number;
}

export interface TerminalOutputData {
  output: string;
  type: 'stdout' | 'stderr';
}

export interface AICommandData {
  command: string;
  context?: string;
}

export interface AIResponseData {
  response?: string;
  suggestion?: string;
  error?: string;
}

export interface ErrorData {
  message?: string;
  code?: string;
}

export interface PingData {
  timestamp?: number;
}

export interface PongData {
  timestamp?: number;
}

//=================== 会话管理相关模型 ===================

// 会话序列化接口
export interface SessionParticipantData {
  roleId: string;
  displayName: string;
  avatar?: string;
  model?: string;
}

@ObservedV2
export class SessionParticipant {
  @Trace roleId: string = '';
  @Trace displayName: string = '';
  @Trace avatar?: string;
  @Trace model?: string;

  constructor(roleId: string, displayName: string, avatar?: string, model?: string) {
    this.roleId = roleId;
    this.displayName = displayName;
    this.avatar = avatar;
    this.model = model;
  }

  static fromObject(data: SessionParticipantData): SessionParticipant {
    return new SessionParticipant(data.roleId, data.displayName, data.avatar, data.model);
  }

  toObject(): SessionParticipantData {
    return {
      roleId: this.roleId,
      displayName: this.displayName,
      avatar: this.avatar,
      model: this.model
    };
  }
}

export interface SessionData {
  id: string;
  name: string;
  createdAt: number;
  updatedAt: number;
  messageCount: number;
  systemPromptId: string | null; // 绑定的系统提示词ID
  roleId?: string; // 关联的角色ID（用于专门标识角色会话）
}

export interface MultiRoleSessionData extends SessionData {
  participants: SessionParticipantData[];
  messages: MessageData[];
}

// 会话信息模型
@ObservedV2
export class Session {
  @Trace id: string = '';
  @Trace name: string = '';
  @Trace createdAt: number = 0;
  @Trace updatedAt: number = 0;
  @Trace messageCount: number = 0;
  @Trace systemPromptId: string | null = null; // 绑定的系统提示词ID
  @Trace roleId?: string; // 关联的角色ID（用于专门标识角色会话）

  constructor(name: string = '', systemPromptId: string | null = null, roleId?: string, id?: string) {
    this.id = id || this.generateId();
    this.name = name;
    this.systemPromptId = systemPromptId;
    this.roleId = roleId;
    this.createdAt = Date.now();
    this.updatedAt = Date.now();
    this.messageCount = 0;
  }

  private generateId(): string {
    return 'session_' + Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  }

  /**
   * 更新会话信息
   */
  updateInfo(messageCount: number = this.messageCount, name: string = this.name): void {
    this.messageCount = messageCount;
    this.name = name;
    this.updatedAt = Date.now();
  }

  /**
   * 基于首条消息内容生成会话名称（包含系统提示词关键词）
   */
  static generateSessionName(firstMessageContent: string, systemPrompt?: SystemPrompt): string {
    let baseName = '';
    
    if (firstMessageContent && firstMessageContent.trim()) {
      const cleanContent = firstMessageContent.trim().replace(/\s+/g, ' ');
      baseName = cleanContent.length <= 15 ? cleanContent : cleanContent.substring(0, 15) + '...';
    } else {
      baseName = '新对话';
    }
    
    // 如果有系统提示词，添加提示词关键词
    if (systemPrompt) {
      const promptKeyword = systemPrompt.name.split(' ')[0]; // 取提示词名称第一个词作为关键词
      return `[${promptKeyword}] ${baseName}`;
    }
    
    return baseName;
  }

  /**
   * 从普通对象创建Session实例
   */
  static fromObject(obj: SessionData): Session {
    const session = new Session();
    session.id = obj.id || session.generateId();
    session.name = obj.name || '';
    session.createdAt = obj.createdAt || Date.now();
    session.updatedAt = obj.updatedAt || Date.now();
    session.messageCount = obj.messageCount || 0;
    session.systemPromptId = obj.systemPromptId || null; // 从对象恢复systemPromptId
    session.roleId = obj.roleId; // 从对象恢复roleId
    return session;
  }

  /**
   * 转换为可序列化对象
   */
  toObject(): SessionData {
    return {
      id: this.id,
      name: this.name,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
      messageCount: this.messageCount,
      systemPromptId: this.systemPromptId,
      roleId: this.roleId // 包含roleId
    };
  }

  /**
   * 格式化显示时间
   */
  getFormattedTime(): string {
    const now = new Date();
    const updateTime = new Date(this.updatedAt);
    const diffMinutes = Math.floor((now.getTime() - updateTime.getTime()) / (1000 * 60));

    if (diffMinutes < 1) {
      return '刚刚';
    } else if (diffMinutes < 60) {
      return `${diffMinutes}分钟前`;
    } else if (diffMinutes < 1440) { // 24小时
      const diffHours = Math.floor(diffMinutes / 60);
      return `${diffHours}小时前`;
    } else {
      return updateTime.toLocaleDateString();
    }
  }
}

@ObservedV2
export class MultiRoleSession extends Session {
  @Trace participants: SessionParticipant[] = [];
  @Trace messages: Message[] = [];

  constructor(
    name: string = '',
    participants: SessionParticipant[] = [],
    messages: Message[] = [],
    systemPromptId: string | null = null,
    roleId?: string,
    id?: string
  ) {
    super(name, systemPromptId, roleId, id);
    this.participants = participants;
    this.messages = messages;
  }

  static fromObject(data: MultiRoleSessionData): MultiRoleSession {
    const participants = (data.participants || []).map(participant => SessionParticipant.fromObject(participant));
    const messages = (data.messages || []).map(message => Message.fromObject(message));
    const session = new MultiRoleSession(
      data.name || '',
      participants,
      messages,
      data.systemPromptId ?? null,
      data.roleId,
      data.id
    );
    session.createdAt = data.createdAt || Date.now();
    session.updatedAt = data.updatedAt || session.createdAt;
    session.messageCount = data.messageCount || messages.length;
    return session;
  }

  override toObject(): MultiRoleSessionData {
    const base = super.toObject();
    return {
      id: base.id,
      name: base.name,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      messageCount: base.messageCount,
      systemPromptId: base.systemPromptId,
      roleId: base.roleId,
      participants: this.participants.map(participant => participant.toObject()),
      messages: this.messages.map(message => message.toObject())
    };
  }

  getParticipant(roleId: string): SessionParticipant | undefined {
    return this.participants.find(participant => participant.roleId === roleId);
  }
}

export function isMultiRoleSession(session: Session | MultiRoleSession): boolean {
  return (session as MultiRoleSession).participants !== undefined;
}

// WebSocket消息数据类型联合
export type WSMessageData = 
  | SessionCreateData
  | SessionSwitchData 
  | SessionCloseData
  | SessionListData
  | SessionCreatedData
  | SessionSwitchedData
  | TerminalInputData
  | TerminalResizeData
  | TerminalOutputData
  | AICommandData
  | AIResponseData
  | ErrorData
  | PingData
  | PongData
  | Record<string, never>; // 空对象类型
