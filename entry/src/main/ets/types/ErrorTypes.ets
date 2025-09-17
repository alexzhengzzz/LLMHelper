/**
 * 统一错误类型定义系统
 * 标准化所有错误处理，提供统一的错误分类、级别和恢复机制
 */

/**
 * 错误严重级别
 */
export enum ErrorLevel {
  INFO = 'info',           // 信息性错误，不影响功能
  WARNING = 'warning',     // 警告级错误，可能影响体验
  ERROR = 'error',         // 一般错误，影响当前操作
  FATAL = 'fatal'          // 严重错误，可能导致应用崩溃
}

/**
 * 错误类型分类
 */
export enum ErrorType {
  NETWORK = 'network',         // 网络连接错误
  API = 'api',                 // API调用错误
  VALIDATION = 'validation',   // 数据验证错误
  BUSINESS = 'business',       // 业务逻辑错误
  SYSTEM = 'system',           // 系统级错误
  AUDIO = 'audio',             // 音频相关错误
  STORAGE = 'storage',         // 存储相关错误
  UI = 'ui',                   // 用户界面错误
  PERMISSION = 'permission'    // 权限相关错误
}

/**
 * 错误代码定义
 */
export enum ErrorCode {
  // 网络错误代码
  NETWORK_TIMEOUT = 'NETWORK_TIMEOUT',
  NETWORK_UNAVAILABLE = 'NETWORK_UNAVAILABLE',
  NETWORK_CONNECTION_FAILED = 'NETWORK_CONNECTION_FAILED',
  NETWORK_SSL_ERROR = 'NETWORK_SSL_ERROR',
  
  // API错误代码
  API_UNAUTHORIZED = 'API_UNAUTHORIZED',
  API_RATE_LIMITED = 'API_RATE_LIMITED',
  API_INVALID_REQUEST = 'API_INVALID_REQUEST',
  API_SERVER_ERROR = 'API_SERVER_ERROR',
  API_SERVICE_UNAVAILABLE = 'API_SERVICE_UNAVAILABLE',
  API_QUOTA_EXCEEDED = 'API_QUOTA_EXCEEDED',
  API_MODEL_NOT_FOUND = 'API_MODEL_NOT_FOUND',
  
  // 验证错误代码
  VALIDATION_REQUIRED_FIELD = 'VALIDATION_REQUIRED_FIELD',
  VALIDATION_INVALID_FORMAT = 'VALIDATION_INVALID_FORMAT',
  VALIDATION_LENGTH_EXCEEDED = 'VALIDATION_LENGTH_EXCEEDED',
  VALIDATION_INVALID_TYPE = 'VALIDATION_INVALID_TYPE',
  
  // 业务逻辑错误代码
  BUSINESS_SESSION_NOT_FOUND = 'BUSINESS_SESSION_NOT_FOUND',
  BUSINESS_MESSAGE_EMPTY = 'BUSINESS_MESSAGE_EMPTY',
  BUSINESS_PROVIDER_NOT_SUPPORTED = 'BUSINESS_PROVIDER_NOT_SUPPORTED',
  BUSINESS_MODEL_NOT_AVAILABLE = 'BUSINESS_MODEL_NOT_AVAILABLE',
  BUSINESS_FEATURE_DISABLED = 'BUSINESS_FEATURE_DISABLED',
  
  // 系统错误代码
  SYSTEM_OUT_OF_MEMORY = 'SYSTEM_OUT_OF_MEMORY',
  SYSTEM_DISK_FULL = 'SYSTEM_DISK_FULL',
  SYSTEM_INITIALIZATION_FAILED = 'SYSTEM_INITIALIZATION_FAILED',
  SYSTEM_COMPONENT_NOT_FOUND = 'SYSTEM_COMPONENT_NOT_FOUND',
  
  // 音频错误代码
  AUDIO_PERMISSION_DENIED = 'AUDIO_PERMISSION_DENIED',
  AUDIO_DEVICE_NOT_AVAILABLE = 'AUDIO_DEVICE_NOT_AVAILABLE',
  AUDIO_PLAYBACK_FAILED = 'AUDIO_PLAYBACK_FAILED',
  AUDIO_RECORDING_FAILED = 'AUDIO_RECORDING_FAILED',
  AUDIO_TTS_FAILED = 'AUDIO_TTS_FAILED',
  AUDIO_SPEECH_RECOGNITION_FAILED = 'AUDIO_SPEECH_RECOGNITION_FAILED',
  
  // 存储错误代码
  STORAGE_READ_FAILED = 'STORAGE_READ_FAILED',
  STORAGE_WRITE_FAILED = 'STORAGE_WRITE_FAILED',
  STORAGE_NOT_FOUND = 'STORAGE_NOT_FOUND',
  STORAGE_CORRUPTION = 'STORAGE_CORRUPTION',
  
  // UI错误代码
  UI_COMPONENT_INITIALIZATION_FAILED = 'UI_COMPONENT_INITIALIZATION_FAILED',
  UI_RENDER_ERROR = 'UI_RENDER_ERROR',
  UI_ANIMATION_FAILED = 'UI_ANIMATION_FAILED',
  
  // 权限错误代码
  PERMISSION_CAMERA_DENIED = 'PERMISSION_CAMERA_DENIED',
  PERMISSION_MICROPHONE_DENIED = 'PERMISSION_MICROPHONE_DENIED',
  PERMISSION_STORAGE_DENIED = 'PERMISSION_STORAGE_DENIED',
  PERMISSION_NETWORK_DENIED = 'PERMISSION_NETWORK_DENIED',
  
  // 通用错误代码
  UNKNOWN_ERROR = 'UNKNOWN_ERROR',
  OPERATION_CANCELLED = 'OPERATION_CANCELLED',
  OPERATION_TIMEOUT = 'OPERATION_TIMEOUT'
}

/**
 * 错误恢复策略
 */
export enum RecoveryStrategy {
  NONE = 'none',                 // 无恢复策略
  RETRY = 'retry',               // 自动重试
  RETRY_WITH_BACKOFF = 'retry_with_backoff',  // 指数退避重试
  FALLBACK = 'fallback',         // 降级处理
  USER_INTERVENTION = 'user_intervention',    // 需要用户干预
  RESTART_COMPONENT = 'restart_component',    // 重启组件
  CLEAR_CACHE = 'clear_cache'    // 清除缓存后重试
}

/**
 * 错误上下文信息
 */
export class ErrorContext {
  module: string = '';               // 错误发生的模块
  function: string = '';             // 错误发生的函数
  userId?: string = '';              // 用户ID（如果有）
  sessionId?: string = '';           // 会话ID（如果有）
  requestId?: string = '';           // 请求ID（如果有）
  additionalInfo?: string = '';      // 额外信息（JSON字符串）
}

/**
 * 错误恢复配置
 */
export interface RecoveryConfig {
  strategy: RecoveryStrategy;   // 恢复策略
  maxRetries?: number;          // 最大重试次数
  retryDelay?: number;          // 重试延迟（毫秒）
  backoffMultiplier?: number;   // 退避倍数
  timeout?: number;             // 超时时间（毫秒）
  fallbackAction?: () => Promise<void>;  // 降级处理函数
}

/**
 * 统一应用错误接口
 */
export interface AppError {
  id: string;                   // 错误唯一标识
  type: ErrorType;              // 错误类型
  level: ErrorLevel;            // 严重级别
  code: ErrorCode;              // 错误代码
  message: string;              // 错误消息（技术层面）
  userMessage: string;          // 用户友好消息
  context: ErrorContext;        // 错误上下文
  timestamp: number;            // 错误发生时间戳
  recoverable: boolean;         // 是否可恢复
  recoveryConfig?: RecoveryConfig;  // 恢复配置
  originalError?: Error;        // 原始错误对象
  stackTrace?: string;          // 错误堆栈跟踪
}

/**
 * 错误统计信息
 */
export interface ErrorStats {
  errorCode: ErrorCode;         // 错误代码
  count: number;                // 发生次数
  lastOccurrence: number;       // 最后发生时间
  averageResolutionTime: number; // 平均解决时间
}

/**
 * 错误处理结果
 */
export interface ErrorHandlingResult {
  success: boolean;             // 处理是否成功
  recovered: boolean;           // 是否已恢复
  retryCount: number;           // 重试次数
  finalError?: AppError;        // 最终错误（如果处理失败）
  recoveryTime: number;         // 恢复耗时（毫秒）
}

/**
 * 错误监听器接口
 */
export interface ErrorListener {
  onError: (error: AppError) => void;
  onRecovery: (error: AppError, result: ErrorHandlingResult) => void;
}

/**
 * 错误配置类
 */
export class ErrorConfiguration {
  enableAutoRecovery: boolean = true;        // 是否启用自动恢复
  enableErrorStats: boolean = true;          // 是否启用错误统计
  enableUserNotification: boolean = true;    // 是否启用用户通知
  maxErrorHistory: number = 1000;            // 最大错误历史记录数
  defaultRetryCount: number = 3;             // 默认重试次数
  defaultRetryDelay: number = 1000;          // 默认重试延迟
}

/**
 * 用户操作建议
 */
export interface UserActionSuggestion {
  action: string;                     // 建议操作
  description: string;                // 操作描述
  buttonText: string;                 // 按钮文字
  actionHandler: () => Promise<void>; // 操作处理函数
}

/**
 * 用户友好的错误信息
 */
export interface UserFriendlyErrorInfo {
  title: string;                      // 错误标题
  message: string;                    // 错误消息
  suggestions: UserActionSuggestion[]; // 操作建议
  showTechnicalDetails: boolean;      // 是否显示技术详情
  canRetry: boolean;                  // 是否可以重试
  canReport: boolean;                 // 是否可以报告错误
}

/**
 * 预定义的错误消息映射
 */
export const ERROR_MESSAGES: Record<ErrorCode, string> = {
  // 网络错误消息
  [ErrorCode.NETWORK_TIMEOUT]: '网络请求超时，请检查网络连接',
  [ErrorCode.NETWORK_UNAVAILABLE]: '网络不可用，请检查网络设置',
  [ErrorCode.NETWORK_CONNECTION_FAILED]: '网络连接失败，请稍后重试',
  [ErrorCode.NETWORK_SSL_ERROR]: '安全连接错误，请检查网络安全设置',
  
  // API错误消息
  [ErrorCode.API_UNAUTHORIZED]: 'API密钥无效或已过期，请检查配置',
  [ErrorCode.API_RATE_LIMITED]: 'API调用频率超限，请稍后重试',
  [ErrorCode.API_INVALID_REQUEST]: 'API请求格式错误',
  [ErrorCode.API_SERVER_ERROR]: 'API服务器内部错误',
  [ErrorCode.API_SERVICE_UNAVAILABLE]: 'API服务暂不可用，请稍后重试',
  [ErrorCode.API_QUOTA_EXCEEDED]: 'API配额已用完，请检查使用量',
  [ErrorCode.API_MODEL_NOT_FOUND]: '指定的AI模型不存在',
  
  // 验证错误消息
  [ErrorCode.VALIDATION_REQUIRED_FIELD]: '必填字段不能为空',
  [ErrorCode.VALIDATION_INVALID_FORMAT]: '数据格式不正确',
  [ErrorCode.VALIDATION_LENGTH_EXCEEDED]: '内容长度超出限制',
  [ErrorCode.VALIDATION_INVALID_TYPE]: '数据类型不正确',
  
  // 业务逻辑错误消息
  [ErrorCode.BUSINESS_SESSION_NOT_FOUND]: '会话不存在',
  [ErrorCode.BUSINESS_MESSAGE_EMPTY]: '消息内容不能为空',
  [ErrorCode.BUSINESS_PROVIDER_NOT_SUPPORTED]: '不支持的AI厂商',
  [ErrorCode.BUSINESS_MODEL_NOT_AVAILABLE]: 'AI模型暂不可用',
  [ErrorCode.BUSINESS_FEATURE_DISABLED]: '功能已禁用',
  
  // 系统错误消息
  [ErrorCode.SYSTEM_OUT_OF_MEMORY]: '系统内存不足',
  [ErrorCode.SYSTEM_DISK_FULL]: '存储空间不足',
  [ErrorCode.SYSTEM_INITIALIZATION_FAILED]: '系统初始化失败',
  [ErrorCode.SYSTEM_COMPONENT_NOT_FOUND]: '系统组件未找到',
  
  // 音频错误消息
  [ErrorCode.AUDIO_PERMISSION_DENIED]: '麦克风权限被拒绝',
  [ErrorCode.AUDIO_DEVICE_NOT_AVAILABLE]: '音频设备不可用',
  [ErrorCode.AUDIO_PLAYBACK_FAILED]: '音频播放失败',
  [ErrorCode.AUDIO_RECORDING_FAILED]: '音频录制失败',
  [ErrorCode.AUDIO_TTS_FAILED]: '语音合成失败',
  [ErrorCode.AUDIO_SPEECH_RECOGNITION_FAILED]: '语音识别失败',
  
  // 存储错误消息
  [ErrorCode.STORAGE_READ_FAILED]: '数据读取失败',
  [ErrorCode.STORAGE_WRITE_FAILED]: '数据保存失败',
  [ErrorCode.STORAGE_NOT_FOUND]: '数据不存在',
  [ErrorCode.STORAGE_CORRUPTION]: '数据已损坏',
  
  // UI错误消息
  [ErrorCode.UI_COMPONENT_INITIALIZATION_FAILED]: '界面组件初始化失败',
  [ErrorCode.UI_RENDER_ERROR]: '界面渲染错误',
  [ErrorCode.UI_ANIMATION_FAILED]: '动画执行失败',
  
  // 权限错误消息
  [ErrorCode.PERMISSION_CAMERA_DENIED]: '相机权限被拒绝',
  [ErrorCode.PERMISSION_MICROPHONE_DENIED]: '麦克风权限被拒绝',
  [ErrorCode.PERMISSION_STORAGE_DENIED]: '存储权限被拒绝',
  [ErrorCode.PERMISSION_NETWORK_DENIED]: '网络权限被拒绝',
  
  // 通用错误消息
  [ErrorCode.UNKNOWN_ERROR]: '未知错误',
  [ErrorCode.OPERATION_CANCELLED]: '操作已取消',
  [ErrorCode.OPERATION_TIMEOUT]: '操作超时'
};

/**
 * 用户友好错误消息映射
 */
export const USER_FRIENDLY_MESSAGES: Record<ErrorCode, string> = {
  // 网络错误用户消息
  [ErrorCode.NETWORK_TIMEOUT]: '网络响应慢，正在重试...',
  [ErrorCode.NETWORK_UNAVAILABLE]: '网络连接中断，请检查网络设置',
  [ErrorCode.NETWORK_CONNECTION_FAILED]: '连接失败，请稍后重试',
  [ErrorCode.NETWORK_SSL_ERROR]: '连接安全验证失败',
  
  // API错误用户消息
  [ErrorCode.API_UNAUTHORIZED]: 'API密钥配置有误，请在设置中检查',
  [ErrorCode.API_RATE_LIMITED]: '使用过于频繁，请稍等片刻',
  [ErrorCode.API_INVALID_REQUEST]: '请求格式错误，请重试',
  [ErrorCode.API_SERVER_ERROR]: 'AI服务暂时不可用，请稍后重试',
  [ErrorCode.API_SERVICE_UNAVAILABLE]: 'AI服务维护中，请稍后重试',
  [ErrorCode.API_QUOTA_EXCEEDED]: '今日使用量已达上限',
  [ErrorCode.API_MODEL_NOT_FOUND]: '所选AI模型不可用，请切换其他模型',
  
  // 验证错误用户消息
  [ErrorCode.VALIDATION_REQUIRED_FIELD]: '请填写必要信息',
  [ErrorCode.VALIDATION_INVALID_FORMAT]: '输入格式不正确',
  [ErrorCode.VALIDATION_LENGTH_EXCEEDED]: '内容过长，请精简后重试',
  [ErrorCode.VALIDATION_INVALID_TYPE]: '输入类型不正确',
  
  // 业务逻辑错误用户消息
  [ErrorCode.BUSINESS_SESSION_NOT_FOUND]: '会话已不存在，请创建新会话',
  [ErrorCode.BUSINESS_MESSAGE_EMPTY]: '请输入要发送的消息',
  [ErrorCode.BUSINESS_PROVIDER_NOT_SUPPORTED]: '暂不支持此AI厂商',
  [ErrorCode.BUSINESS_MODEL_NOT_AVAILABLE]: '当前AI模型不可用，请选择其他模型',
  [ErrorCode.BUSINESS_FEATURE_DISABLED]: '此功能暂时不可用',
  
  // 系统错误用户消息
  [ErrorCode.SYSTEM_OUT_OF_MEMORY]: '设备内存不足，请关闭其他应用',
  [ErrorCode.SYSTEM_DISK_FULL]: '存储空间不足，请清理设备存储',
  [ErrorCode.SYSTEM_INITIALIZATION_FAILED]: '应用初始化失败，请重启应用',
  [ErrorCode.SYSTEM_COMPONENT_NOT_FOUND]: '应用组件缺失，请重新安装',
  
  // 音频错误用户消息
  [ErrorCode.AUDIO_PERMISSION_DENIED]: '需要麦克风权限才能使用语音功能',
  [ErrorCode.AUDIO_DEVICE_NOT_AVAILABLE]: '音频设备不可用，请检查设备',
  [ErrorCode.AUDIO_PLAYBACK_FAILED]: '音频播放失败',
  [ErrorCode.AUDIO_RECORDING_FAILED]: '录音失败，请重试',
  [ErrorCode.AUDIO_TTS_FAILED]: '语音播报失败',
  [ErrorCode.AUDIO_SPEECH_RECOGNITION_FAILED]: '语音识别失败，请重新说话',
  
  // 存储错误用户消息
  [ErrorCode.STORAGE_READ_FAILED]: '数据读取失败',
  [ErrorCode.STORAGE_WRITE_FAILED]: '数据保存失败',
  [ErrorCode.STORAGE_NOT_FOUND]: '数据不存在',
  [ErrorCode.STORAGE_CORRUPTION]: '数据已损坏，建议重新创建',
  
  // UI错误用户消息
  [ErrorCode.UI_COMPONENT_INITIALIZATION_FAILED]: '界面加载失败，请重试',
  [ErrorCode.UI_RENDER_ERROR]: '界面显示异常',
  [ErrorCode.UI_ANIMATION_FAILED]: '动画效果异常',
  
  // 权限错误用户消息
  [ErrorCode.PERMISSION_CAMERA_DENIED]: '需要相机权限',
  [ErrorCode.PERMISSION_MICROPHONE_DENIED]: '需要麦克风权限',
  [ErrorCode.PERMISSION_STORAGE_DENIED]: '需要存储权限',
  [ErrorCode.PERMISSION_NETWORK_DENIED]: '需要网络权限',
  
  // 通用错误用户消息
  [ErrorCode.UNKNOWN_ERROR]: '遇到未知问题，请重试',
  [ErrorCode.OPERATION_CANCELLED]: '操作已取消',
  [ErrorCode.OPERATION_TIMEOUT]: '操作超时，请重试'
};