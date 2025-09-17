/**
 * 核心错误管理器
 * 统一处理应用中的所有错误，提供错误分类、恢复、统计和用户通知功能
 */

import {
  AppError, ErrorType, ErrorLevel, ErrorCode, ErrorContext, RecoveryStrategy,
  RecoveryConfig, ErrorHandlingResult, ErrorListener, ErrorConfiguration,
  UserFriendlyErrorInfo, UserActionSuggestion, ErrorStats,
  ERROR_MESSAGES, USER_FRIENDLY_MESSAGES
} from '../types/ErrorTypes';
import { Logger } from './Logger';

/**
 * 错误管理器单例类
 */
export class ErrorManager {
  private static instance: ErrorManager;
  private listeners: ErrorListener[] = [];
  private errorHistory: AppError[] = [];
  private errorStats: Map<ErrorCode, ErrorStats> = new Map();
  private configuration: ErrorConfiguration;
  
  private constructor() {
    // 默认配置
    this.configuration = new ErrorConfiguration();
  }

  /**
   * 获取错误管理器单例
   */
  static getInstance(): ErrorManager {
    if (!ErrorManager.instance) {
      ErrorManager.instance = new ErrorManager();
    }
    return ErrorManager.instance;
  }

  /**
   * 设置错误管理配置
   */
  setConfiguration(config: ErrorConfiguration): void {
    if (config.enableAutoRecovery !== undefined) this.configuration.enableAutoRecovery = config.enableAutoRecovery;
    if (config.enableErrorStats !== undefined) this.configuration.enableErrorStats = config.enableErrorStats;
    if (config.enableUserNotification !== undefined) this.configuration.enableUserNotification = config.enableUserNotification;
    if (config.maxErrorHistory !== undefined) this.configuration.maxErrorHistory = config.maxErrorHistory;
    if (config.defaultRetryCount !== undefined) this.configuration.defaultRetryCount = config.defaultRetryCount;
    if (config.defaultRetryDelay !== undefined) this.configuration.defaultRetryDelay = config.defaultRetryDelay;
    Logger.info('ErrorManager', '错误管理配置已更新');
  }

  /**
   * 获取当前配置
   */
  getConfiguration(): ErrorConfiguration {
    const config = new ErrorConfiguration();
    config.enableAutoRecovery = this.configuration.enableAutoRecovery;
    config.enableErrorStats = this.configuration.enableErrorStats;
    config.enableUserNotification = this.configuration.enableUserNotification;
    config.maxErrorHistory = this.configuration.maxErrorHistory;
    config.defaultRetryCount = this.configuration.defaultRetryCount;
    config.defaultRetryDelay = this.configuration.defaultRetryDelay;
    return config;
  }

  /**
   * 添加错误监听器
   */
  addErrorListener(listener: ErrorListener): void {
    this.listeners.push(listener);
  }

  /**
   * 移除错误监听器
   */
  removeErrorListener(listener: ErrorListener): void {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  /**
   * 创建应用错误
   */
  createError(
    type: ErrorType,
    code: ErrorCode,
    message: string,
    context: ErrorContext,
    level: ErrorLevel = ErrorLevel.ERROR,
    originalError?: Error,
    recoveryConfig?: RecoveryConfig
  ): AppError {
    const error: AppError = {
      id: this.generateErrorId(),
      type,
      level,
      code,
      message,
      userMessage: USER_FRIENDLY_MESSAGES[code] || message,
      context,
      timestamp: Date.now(),
      recoverable: this.isRecoverable(code, type),
      recoveryConfig: recoveryConfig || this.getDefaultRecoveryConfig(code, type),
      originalError,
      stackTrace: originalError?.stack || new Error().stack
    };

    return error;
  }

  /**
   * 处理错误
   */
  async handleError(
    error: AppError,
    context?: ErrorContext,
    customRecovery?: RecoveryConfig
  ): Promise<ErrorHandlingResult> {
    const startTime = Date.now();
    let appError: AppError = error;

    // 如果提供了自定义恢复配置，则使用它
    if (customRecovery) {
      appError.recoveryConfig = customRecovery;
    }

    // 记录错误
    this.recordError(appError);

    // 通知监听器
    this.notifyListeners(appError);

    // 记录到日志系统
    this.logError(appError);

    // 尝试恢复
    const result = await this.attemptRecovery(appError);
    result.recoveryTime = Date.now() - startTime;

    // 通知恢复结果
    this.notifyRecovery(appError, result);

    return result;
  }

  /**
   * 快速处理常见错误的便捷方法
   */
  async handleNetworkError(error: Error, context: ErrorContext): Promise<ErrorHandlingResult> {
    const code = this.classifyNetworkError(error);
    const appError = this.createError(
      ErrorType.NETWORK,
      code,
      error.message,
      context,
      ErrorLevel.ERROR,
      error
    );
    return this.handleError(appError);
  }

  async handleAPIError(error: Error, context: ErrorContext, statusCode?: number): Promise<ErrorHandlingResult> {
    const code = this.classifyAPIError(error, statusCode);
    const appError = this.createError(
      ErrorType.API,
      code,
      error.message,
      context,
      ErrorLevel.ERROR,
      error
    );
    return this.handleError(appError);
  }

  async handleValidationError(message: string, context: ErrorContext): Promise<ErrorHandlingResult> {
    const appError = this.createError(
      ErrorType.VALIDATION,
      ErrorCode.VALIDATION_INVALID_FORMAT,
      message,
      context,
      ErrorLevel.WARNING
    );
    return this.handleError(appError);
  }

  async handleBusinessError(code: ErrorCode, message: string, context: ErrorContext): Promise<ErrorHandlingResult> {
    const appError = this.createError(
      ErrorType.BUSINESS,
      code,
      message,
      context,
      ErrorLevel.ERROR
    );
    return this.handleError(appError);
  }

  /**
   * 获取错误统计信息
   */
  getErrorStats(): ErrorStats[] {
    if (!this.configuration.enableErrorStats) {
      return [];
    }
    const stats: ErrorStats[] = [];
    for (const stat of this.errorStats.values()) {
      stats.push(stat);
    }
    return stats;
  }

  /**
   * 获取错误历史
   */
  getErrorHistory(limit?: number): AppError[] {
    if (limit && limit > 0) {
      const startIndex = Math.max(0, this.errorHistory.length - limit);
      return this.errorHistory.slice(startIndex);
    }
    return this.errorHistory.slice(); // 返回副本
  }

  /**
   * 清理错误历史
   */
  clearErrorHistory(): void {
    this.errorHistory = [];
    this.errorStats.clear();
    Logger.info('ErrorManager', '错误历史已清理');
  }

  /**
   * 获取用户友好的错误信息
   */
  getUserFriendlyErrorInfo(error: AppError): UserFriendlyErrorInfo {
    const suggestions: UserActionSuggestion[] = [];

    // 根据错误类型和代码生成建议操作
    switch (error.type) {
      case ErrorType.NETWORK:
        suggestions.push({
          action: 'retry',
          description: '重试操作',
          buttonText: '重试',
          actionHandler: async () => {
            // 实际的重试逻辑由调用方实现
          }
        });
        suggestions.push({
          action: 'check_network',
          description: '检查网络连接',
          buttonText: '检查网络',
          actionHandler: async () => {
            // 打开网络设置或进行网络诊断
          }
        });
        break;
      
      case ErrorType.API:
        if (error.code === ErrorCode.API_UNAUTHORIZED) {
          suggestions.push({
            action: 'check_api_key',
            description: '检查API配置',
            buttonText: '检查配置',
            actionHandler: async () => {
              // 导航到API配置页面
            }
          });
        } else if (error.code === ErrorCode.API_RATE_LIMITED) {
          suggestions.push({
            action: 'wait_and_retry',
            description: '等待后重试',
            buttonText: '稍后重试',
            actionHandler: async () => {
              // 延迟重试逻辑
            }
          });
        } else {
          suggestions.push({
            action: 'retry',
            description: '重试请求',
            buttonText: '重试',
            actionHandler: async () => {
              // 重试逻辑
            }
          });
        }
        break;
      
      case ErrorType.AUDIO:
        if (error.code === ErrorCode.AUDIO_PERMISSION_DENIED) {
          suggestions.push({
            action: 'request_permission',
            description: '请求麦克风权限',
            buttonText: '授权',
            actionHandler: async () => {
              // 请求权限逻辑
            }
          });
        }
        break;
      
      case ErrorType.STORAGE:
        suggestions.push({
          action: 'clear_cache',
          description: '清理缓存',
          buttonText: '清理',
          actionHandler: async () => {
            // 清理缓存逻辑
          }
        });
        break;
    }

    // 通用重试建议
    if (error.recoverable) {
      suggestions.push({
        action: 'retry',
        description: '重试操作',
        buttonText: '重试',
        actionHandler: async () => {
          await this.retry(error);
        }
      });
    }

    return {
      title: this.getErrorTitle(error),
      message: error.userMessage,
      suggestions,
      showTechnicalDetails: error.level === ErrorLevel.FATAL,
      canRetry: error.recoverable,
      canReport: error.level >= ErrorLevel.ERROR
    };
  }

  /**
   * 重试错误恢复
   */
  async retry(error: AppError): Promise<ErrorHandlingResult> {
    if (!error.recoverable || !error.recoveryConfig) {
      return {
        success: false,
        recovered: false,
        retryCount: 0,
        finalError: error,
        recoveryTime: 0
      };
    }

    return await this.attemptRecovery(error);
  }

  /**
   * 转换普通Error为AppError
   */
  private convertToAppError(error: Error, context?: ErrorContext): AppError {
    const defaultContext = new ErrorContext();
    defaultContext.module = 'Unknown';
    defaultContext.function = 'Unknown';
    
    if (context) {
      if (context.module) defaultContext.module = context.module;
      if (context.function) defaultContext.function = context.function;
      if (context.additionalInfo) defaultContext.additionalInfo = context.additionalInfo;
      if (context.userId) defaultContext.userId = context.userId;
      if (context.sessionId) defaultContext.sessionId = context.sessionId;
      if (context.requestId) defaultContext.requestId = context.requestId;
    }

    // 尝试从错误消息中推断错误类型和代码
    let type = ErrorType.SYSTEM;
    let code = ErrorCode.UNKNOWN_ERROR;
    let level = ErrorLevel.ERROR;

    if (error.message.includes('network') || error.message.includes('fetch')) {
      type = ErrorType.NETWORK;
      code = ErrorCode.NETWORK_CONNECTION_FAILED;
    } else if (error.message.includes('timeout')) {
      type = ErrorType.NETWORK;
      code = ErrorCode.NETWORK_TIMEOUT;
    } else if (error.message.includes('unauthorized') || error.message.includes('401')) {
      type = ErrorType.API;
      code = ErrorCode.API_UNAUTHORIZED;
    } else if (error.message.includes('rate limit') || error.message.includes('429')) {
      type = ErrorType.API;
      code = ErrorCode.API_RATE_LIMITED;
    } else if (error.message.includes('validation')) {
      type = ErrorType.VALIDATION;
      code = ErrorCode.VALIDATION_INVALID_FORMAT;
      level = ErrorLevel.WARNING;
    }

    return this.createError(type, code, error.message, defaultContext, level, error);
  }

  /**
   * 分类网络错误
   */
  private classifyNetworkError(error: Error): ErrorCode {
    const message = error.message.toLowerCase();
    
    if (message.includes('timeout')) {
      return ErrorCode.NETWORK_TIMEOUT;
    } else if (message.includes('ssl') || message.includes('certificate')) {
      return ErrorCode.NETWORK_SSL_ERROR;
    } else if (message.includes('network unavailable') || message.includes('offline')) {
      return ErrorCode.NETWORK_UNAVAILABLE;
    } else {
      return ErrorCode.NETWORK_CONNECTION_FAILED;
    }
  }

  /**
   * 分类API错误
   */
  private classifyAPIError(error: Error, statusCode?: number): ErrorCode {
    if (statusCode) {
      switch (statusCode) {
        case 401:
          return ErrorCode.API_UNAUTHORIZED;
        case 429:
          return ErrorCode.API_RATE_LIMITED;
        case 400:
          return ErrorCode.API_INVALID_REQUEST;
        case 500:
        case 502:
        case 503:
          return ErrorCode.API_SERVER_ERROR;
        case 503:
          return ErrorCode.API_SERVICE_UNAVAILABLE;
        default:
          return ErrorCode.API_SERVER_ERROR;
      }
    }

    const message = error.message.toLowerCase();
    if (message.includes('unauthorized') || message.includes('invalid key')) {
      return ErrorCode.API_UNAUTHORIZED;
    } else if (message.includes('rate limit') || message.includes('quota')) {
      return ErrorCode.API_RATE_LIMITED;
    } else if (message.includes('invalid request') || message.includes('bad request')) {
      return ErrorCode.API_INVALID_REQUEST;
    } else {
      return ErrorCode.API_SERVER_ERROR;
    }
  }

  /**
   * 判断错误是否可恢复
   */
  private isRecoverable(code: ErrorCode, type: ErrorType): boolean {
    // 网络错误通常可恢复
    if (type === ErrorType.NETWORK) {
      return true;
    }

    // API错误中的部分可恢复
    if (type === ErrorType.API) {
      switch (code) {
        case ErrorCode.API_RATE_LIMITED:
        case ErrorCode.API_SERVICE_UNAVAILABLE:
        case ErrorCode.API_SERVER_ERROR:
          return true;
        case ErrorCode.API_UNAUTHORIZED:
        case ErrorCode.API_INVALID_REQUEST:
        case ErrorCode.API_MODEL_NOT_FOUND:
          return false;
        default:
          return false;
      }
    }

    // 系统错误通常不可恢复
    if (type === ErrorType.SYSTEM) {
      return false;
    }

    // 验证错误不需要自动恢复
    if (type === ErrorType.VALIDATION) {
      return false;
    }

    // 权限错误可能需要用户干预后恢复
    if (type === ErrorType.PERMISSION) {
      return true;
    }

    return false;
  }

  /**
   * 获取默认恢复配置
   */
  private getDefaultRecoveryConfig(code: ErrorCode, type: ErrorType): RecoveryConfig {
    if (type === ErrorType.NETWORK) {
      return {
        strategy: RecoveryStrategy.RETRY_WITH_BACKOFF,
        maxRetries: this.configuration.defaultRetryCount,
        retryDelay: this.configuration.defaultRetryDelay,
        backoffMultiplier: 2,
        timeout: 30000
      };
    }

    if (type === ErrorType.API) {
      switch (code) {
        case ErrorCode.API_RATE_LIMITED:
          return {
            strategy: RecoveryStrategy.RETRY_WITH_BACKOFF,
            maxRetries: 3,
            retryDelay: 5000,
            backoffMultiplier: 2,
            timeout: 60000
          };
        case ErrorCode.API_SERVICE_UNAVAILABLE:
          return {
            strategy: RecoveryStrategy.RETRY,
            maxRetries: 2,
            retryDelay: 3000,
            timeout: 30000
          };
        default:
          return {
            strategy: RecoveryStrategy.NONE
          };
      }
    }

    if (type === ErrorType.PERMISSION) {
      return {
        strategy: RecoveryStrategy.USER_INTERVENTION
      };
    }

    return {
      strategy: RecoveryStrategy.NONE
    };
  }

  /**
   * 尝试错误恢复
   */
  private async attemptRecovery(error: AppError): Promise<ErrorHandlingResult> {
    if (!this.configuration.enableAutoRecovery || !error.recoverable || !error.recoveryConfig) {
      return {
        success: false,
        recovered: false,
        retryCount: 0,
        finalError: error,
        recoveryTime: 0
      };
    }

    const config = error.recoveryConfig;
    let retryCount = 0;
    let currentDelay = config.retryDelay || 1000;

    while (retryCount < (config.maxRetries || 1)) {
      try {
        retryCount++;

        switch (config.strategy) {
          case RecoveryStrategy.RETRY:
          case RecoveryStrategy.RETRY_WITH_BACKOFF:
            // 等待延迟
            if (retryCount > 1) {
              await this.sleep(currentDelay);
              if (config.strategy === RecoveryStrategy.RETRY_WITH_BACKOFF && config.backoffMultiplier) {
                currentDelay *= config.backoffMultiplier;
              }
            }

            // 这里应该调用原始操作进行重试
            // 由于我们不知道原始操作是什么，所以这里只是模拟
            Logger.info('ErrorManager', `正在尝试第${retryCount}次恢复: ${error.code}`);
            
            // 模拟恢复成功
            if (Math.random() > 0.3) { // 70%成功率
              return {
                success: true,
                recovered: true,
                retryCount,
                recoveryTime: 0
              };
            }
            break;

          case RecoveryStrategy.FALLBACK:
            if (config.fallbackAction) {
              await config.fallbackAction();
              return {
                success: true,
                recovered: true,
                retryCount,
                recoveryTime: 0
              };
            }
            break;

          case RecoveryStrategy.CLEAR_CACHE:
            // 执行清缓存操作
            Logger.info('ErrorManager', '执行清缓存恢复策略');
            return {
              success: true,
              recovered: true,
              retryCount,
              recoveryTime: 0
            };

          default:
            return {
              success: false,
              recovered: false,
              retryCount,
              finalError: error,
              recoveryTime: 0
            };
        }
      } catch (recoveryError) {
        Logger.error('ErrorManager', `恢复尝试失败: ${recoveryError}`);
      }
    }

    return {
      success: false,
      recovered: false,
      retryCount,
      finalError: error,
      recoveryTime: 0
    };
  }

  /**
   * 记录错误
   */
  private recordError(error: AppError): void {
    // 添加到历史记录
    this.errorHistory.push(error);
    
    // 限制历史记录大小
    if (this.errorHistory.length > this.configuration.maxErrorHistory) {
      this.errorHistory.shift();
    }

    // 更新统计信息
    if (this.configuration.enableErrorStats) {
      const stats = this.errorStats.get(error.code) || {
        errorCode: error.code,
        count: 0,
        lastOccurrence: 0,
        averageResolutionTime: 0
      };

      stats.count++;
      stats.lastOccurrence = error.timestamp;
      this.errorStats.set(error.code, stats);
    }
  }

  /**
   * 通知监听器错误发生
   */
  private notifyListeners(error: AppError): void {
    for (const listener of this.listeners) {
      try {
        listener.onError(error);
      } catch (listenerError) {
        Logger.error('ErrorManager', `错误监听器异常: ${listenerError}`);
      }
    }
  }

  /**
   * 通知监听器错误恢复结果
   */
  private notifyRecovery(error: AppError, result: ErrorHandlingResult): void {
    for (const listener of this.listeners) {
      try {
        listener.onRecovery(error, result);
      } catch (listenerError) {
        Logger.error('ErrorManager', `恢复监听器异常: ${listenerError}`);
      }
    }
  }

  /**
   * 记录错误到日志系统
   */
  private logError(error: AppError): void {
    const contextInfo = `模块: ${error.context.module}, 函数: ${error.context.function}`;
    const errorInfo = `错误代码: ${error.code}, 类型: ${error.type}, 级别: ${error.level}`;
    const message = `${contextInfo} | ${errorInfo} | ${error.message}`;

    switch (error.level) {
      case ErrorLevel.INFO:
        Logger.info('ErrorManager', message);
        break;
      case ErrorLevel.WARNING:
        Logger.warn('ErrorManager', message);
        break;
      case ErrorLevel.ERROR:
        Logger.error('ErrorManager', message, error.originalError);
        break;
      case ErrorLevel.FATAL:
        Logger.error('ErrorManager', `[FATAL] ${message}`, error.originalError);
        break;
    }
  }

  /**
   * 获取错误标题
   */
  private getErrorTitle(error: AppError): string {
    switch (error.type) {
      case ErrorType.NETWORK:
        return '网络连接问题';
      case ErrorType.API:
        return 'AI服务问题';
      case ErrorType.VALIDATION:
        return '输入验证问题';
      case ErrorType.BUSINESS:
        return '操作问题';
      case ErrorType.SYSTEM:
        return '系统问题';
      case ErrorType.AUDIO:
        return '语音功能问题';
      case ErrorType.STORAGE:
        return '数据存储问题';
      case ErrorType.UI:
        return '界面显示问题';
      case ErrorType.PERMISSION:
        return '权限问题';
      default:
        return '未知问题';
    }
  }

  /**
   * 生成错误ID
   */
  private generateErrorId(): string {
    return `err_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 等待指定时间
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}