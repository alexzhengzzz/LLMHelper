/**
 * 错误处理装饰器
 * 提供方法级别的自动错误处理、重试机制和性能监控
 */

import { ErrorManager } from './ErrorManager';
import { ErrorType, ErrorCode, ErrorContext, RecoveryConfig, ErrorLevel } from '../types/ErrorTypes';
import { Logger } from './Logger';

/**
 * 错误处理装饰器选项
 */
export interface ErrorHandlerOptions {
  module: string;                    // 模块名称
  function?: string;                 // 函数名称（可选，自动从方法名获取）
  errorType?: ErrorType;            // 默认错误类型
  errorCode?: ErrorCode;            // 默认错误代码
  level?: ErrorLevel;               // 错误级别
  enableRetry?: boolean;            // 是否启用重试
  maxRetries?: number;              // 最大重试次数
  retryDelay?: number;              // 重试延迟（毫秒）
  enablePerformanceMonitoring?: boolean; // 是否启用性能监控
  customRecovery?: RecoveryConfig;  // 自定义恢复配置
  silentError?: boolean;            // 是否静默处理错误
  fallbackValue?: unknown;          // 降级返回值
}

/**
 * 性能监控信息
 */
interface PerformanceMetrics {
  functionName: string;
  executionTime: number;
  timestamp: number;
  success: boolean;
  errorCount: number;
}

/**
 * 错误处理装饰器类
 */
export class ErrorDecorator {
  private static errorManager = ErrorManager.getInstance();
  private static performanceMetrics: PerformanceMetrics[] = [];
  private static readonly MAX_METRICS_HISTORY = 1000;

  /**
   * 方法错误处理装饰器工厂
   */
  static handleErrors(options: ErrorHandlerOptions) {
    return function (target: unknown, propertyKey: string, descriptor: PropertyDescriptor) {
      const originalMethod = descriptor.value;
      const functionName = options.function || propertyKey;

      descriptor.value = async function (...args: unknown[]) {
        const startTime = Date.now();
        let errorCount = 0;
        const maxRetries = options.enableRetry ? (options.maxRetries || 3) : 0;
        
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
          try {
            // 记录性能监控开始
            if (options.enablePerformanceMonitoring) {
              Logger.debug('ErrorDecorator', `开始执行 ${options.module}.${functionName} (尝试 ${attempt + 1}/${maxRetries + 1})`);
            }

            // 执行原方法
            const result = await originalMethod.apply(this, args);
            
            // 记录性能指标（成功）
            if (options.enablePerformanceMonitoring) {
              ErrorDecorator.recordPerformanceMetrics({
                functionName: `${options.module}.${functionName}`,
                executionTime: Date.now() - startTime,
                timestamp: Date.now(),
                success: true,
                errorCount
              });
            }

            return result;

          } catch (error) {
            errorCount++;
            const executionTime = Date.now() - startTime;

            // 创建错误上下文
            const context: ErrorContext = {
              module: options.module,
              function: functionName,
              additionalInfo: {
                attempt: (attempt + 1).toString(),
                maxRetries: (maxRetries + 1).toString(),
                executionTime: executionTime.toString(),
                args: JSON.stringify(args).substring(0, 200) // 限制参数日志长度
              }
            };

            // 判断错误类型和代码
            let errorType = options.errorType || ErrorType.SYSTEM;
            let errorCode = options.errorCode || ErrorCode.UNKNOWN_ERROR;
            
            // 智能推断错误类型
            if (!options.errorType || !options.errorCode) {
              const inferred = ErrorDecorator.inferErrorTypeAndCode(error as Error);
              errorType = options.errorType || inferred.type;
              errorCode = options.errorCode || inferred.code;
            }

            // 创建应用错误
            const appError = ErrorDecorator.errorManager.createError(
              errorType,
              errorCode,
              (error as Error).message,
              context,
              options.level || ErrorLevel.ERROR,
              error as Error,
              options.customRecovery
            );

            // 如果不是最后一次尝试，记录重试信息
            if (attempt < maxRetries) {
              Logger.warn('ErrorDecorator', `${options.module}.${functionName} 第${attempt + 1}次尝试失败，准备重试: ${appError.message}`);
              
              // 等待重试延迟
              if (options.retryDelay) {
                await ErrorDecorator.sleep(options.retryDelay);
              }
              continue;
            }

            // 记录性能指标（失败）
            if (options.enablePerformanceMonitoring) {
              ErrorDecorator.recordPerformanceMetrics({
                functionName: `${options.module}.${functionName}`,
                executionTime,
                timestamp: Date.now(),
                success: false,
                errorCount
              });
            }

            // 如果启用了静默错误处理，返回降级值
            if (options.silentError) {
              Logger.warn('ErrorDecorator', `静默处理错误: ${appError.message}`);
              await ErrorDecorator.errorManager.handleError(appError);
              return options.fallbackValue;
            }

            // 处理错误
            await ErrorDecorator.errorManager.handleError(appError);
            
            // 抛出原始错误
            throw error;
          }
        }
      };

      return descriptor;
    };
  }

  /**
   * 异步方法错误处理装饰器（简化版）
   */
  static asyncErrorHandler(module: string, errorType: ErrorType = ErrorType.SYSTEM) {
    return ErrorDecorator.handleErrors({
      module,
      errorType,
      enableRetry: false,
      enablePerformanceMonitoring: false
    });
  }

  /**
   * 网络请求错误处理装饰器
   */
  static networkErrorHandler(module: string, maxRetries: number = 3) {
    return ErrorDecorator.handleErrors({
      module,
      errorType: ErrorType.NETWORK,
      errorCode: ErrorCode.NETWORK_CONNECTION_FAILED,
      enableRetry: true,
      maxRetries,
      retryDelay: 1000,
      enablePerformanceMonitoring: true
    });
  }

  /**
   * API调用错误处理装饰器
   */
  static apiErrorHandler(module: string, maxRetries: number = 2) {
    return ErrorDecorator.handleErrors({
      module,
      errorType: ErrorType.API,
      errorCode: ErrorCode.API_SERVER_ERROR,
      enableRetry: true,
      maxRetries,
      retryDelay: 2000,
      enablePerformanceMonitoring: true
    });
  }

  /**
   * 业务逻辑错误处理装饰器
   */
  static businessErrorHandler(module: string, fallbackValue?: unknown) {
    return ErrorDecorator.handleErrors({
      module,
      errorType: ErrorType.BUSINESS,
      enableRetry: false,
      enablePerformanceMonitoring: true,
      silentError: fallbackValue !== undefined,
      fallbackValue
    });
  }

  /**
   * 存储操作错误处理装饰器
   */
  static storageErrorHandler(module: string, maxRetries: number = 2) {
    return ErrorDecorator.handleErrors({
      module,
      errorType: ErrorType.STORAGE,
      errorCode: ErrorCode.STORAGE_READ_FAILED,
      enableRetry: true,
      maxRetries,
      retryDelay: 500,
      enablePerformanceMonitoring: true
    });
  }

  /**
   * 音频操作错误处理装饰器
   */
  static audioErrorHandler(module: string) {
    return ErrorDecorator.handleErrors({
      module,
      errorType: ErrorType.AUDIO,
      enableRetry: false,
      enablePerformanceMonitoring: true
    });
  }

  /**
   * UI操作错误处理装饰器
   */
  static uiErrorHandler(module: string, fallbackValue?: unknown) {
    return ErrorDecorator.handleErrors({
      module,
      errorType: ErrorType.UI,
      enableRetry: false,
      enablePerformanceMonitoring: false,
      silentError: true,
      fallbackValue
    });
  }

  /**
   * 性能监控装饰器
   */
  static performanceMonitor(module: string, threshold?: number) {
    return function (target: unknown, propertyKey: string, descriptor: PropertyDescriptor) {
      const originalMethod = descriptor.value;
      const functionName = `${module}.${propertyKey}`;

      descriptor.value = async function (...args: unknown[]) {
        const startTime = Date.now();
        
        try {
          const result = await originalMethod.apply(this, args);
          const executionTime = Date.now() - startTime;
          
          // 记录性能指标
          ErrorDecorator.recordPerformanceMetrics({
            functionName,
            executionTime,
            timestamp: Date.now(),
            success: true,
            errorCount: 0
          });

          // 如果设置了阈值且超过阈值，发出警告
          if (threshold && executionTime > threshold) {
            Logger.warn('ErrorDecorator', `性能警告: ${functionName} 执行时间 ${executionTime}ms 超过阈值 ${threshold}ms`);
          }

          return result;
        } catch (error) {
          const executionTime = Date.now() - startTime;
          
          ErrorDecorator.recordPerformanceMetrics({
            functionName,
            executionTime,
            timestamp: Date.now(),
            success: false,
            errorCount: 1
          });

          throw error;
        }
      };

      return descriptor;
    };
  }

  /**
   * 批处理错误处理装饰器
   */
  static batchErrorHandler(module: string, continueOnError: boolean = true) {
    return function (target: unknown, propertyKey: string, descriptor: PropertyDescriptor) {
      const originalMethod = descriptor.value;

      descriptor.value = async function (items: unknown[], ...otherArgs: unknown[]) {
        const results: unknown[] = [];
        const errors: { index: number, error: Error }[] = [];

        for (let i = 0; i < items.length; i++) {
          try {
            const result = await originalMethod.apply(this, [items[i], ...otherArgs]);
            results.push(result);
          } catch (error) {
            errors.push({ index: i, error: error as Error });
            
            if (!continueOnError) {
              // 如果不继续处理，立即抛出错误
              const context: ErrorContext = {
                module,
                function: propertyKey,
                additionalInfo: {
                  batchIndex: i.toString(),
                  totalItems: items.length.toString()
                }
              };

              const appError = ErrorDecorator.errorManager.createError(
                ErrorType.BUSINESS,
                ErrorCode.UNKNOWN_ERROR,
                (error as Error).message,
                context,
                ErrorLevel.ERROR,
                error as Error
              );

              await ErrorDecorator.errorManager.handleError(appError);
              throw error;
            }

            results.push(null); // 添加null占位符
          }
        }

        // 如果有错误且允许继续，记录汇总错误
        if (errors.length > 0) {
          const context: ErrorContext = {
            module,
            function: propertyKey,
            additionalInfo: {
              totalItems: items.length.toString(),
              errorCount: errors.length.toString(),
              successCount: (items.length - errors.length).toString()
            }
          };

          const batchError = ErrorDecorator.errorManager.createError(
            ErrorType.BUSINESS,
            ErrorCode.UNKNOWN_ERROR,
            `批处理部分失败: ${errors.length}/${items.length} 项目处理失败`,
            context,
            ErrorLevel.WARNING
          );

          await ErrorDecorator.errorManager.handleError(batchError);
        }

        return { results, errors };
      };

      return descriptor;
    };
  }

  /**
   * 智能推断错误类型和代码
   */
  private static inferErrorTypeAndCode(error: Error): { type: ErrorType, code: ErrorCode } {
    const message = error.message.toLowerCase();
    const name = error.name.toLowerCase();

    // 网络相关错误
    if (message.includes('network') || message.includes('fetch') || message.includes('xhr')) {
      if (message.includes('timeout')) {
        return { type: ErrorType.NETWORK, code: ErrorCode.NETWORK_TIMEOUT };
      } else if (message.includes('offline') || message.includes('unavailable')) {
        return { type: ErrorType.NETWORK, code: ErrorCode.NETWORK_UNAVAILABLE };
      } else {
        return { type: ErrorType.NETWORK, code: ErrorCode.NETWORK_CONNECTION_FAILED };
      }
    }

    // API相关错误
    if (message.includes('api') || message.includes('http') || message.includes('status')) {
      if (message.includes('401') || message.includes('unauthorized')) {
        return { type: ErrorType.API, code: ErrorCode.API_UNAUTHORIZED };
      } else if (message.includes('429') || message.includes('rate limit')) {
        return { type: ErrorType.API, code: ErrorCode.API_RATE_LIMITED };
      } else if (message.includes('400') || message.includes('bad request')) {
        return { type: ErrorType.API, code: ErrorCode.API_INVALID_REQUEST };
      } else if (message.includes('500') || message.includes('server error')) {
        return { type: ErrorType.API, code: ErrorCode.API_SERVER_ERROR };
      } else if (message.includes('503') || message.includes('service unavailable')) {
        return { type: ErrorType.API, code: ErrorCode.API_SERVICE_UNAVAILABLE };
      } else {
        return { type: ErrorType.API, code: ErrorCode.API_SERVER_ERROR };
      }
    }

    // 验证相关错误
    if (name.includes('validation') || message.includes('validation') || message.includes('invalid')) {
      if (message.includes('required') || message.includes('missing')) {
        return { type: ErrorType.VALIDATION, code: ErrorCode.VALIDATION_REQUIRED_FIELD };
      } else if (message.includes('format') || message.includes('pattern')) {
        return { type: ErrorType.VALIDATION, code: ErrorCode.VALIDATION_INVALID_FORMAT };
      } else if (message.includes('length') || message.includes('too long') || message.includes('exceed')) {
        return { type: ErrorType.VALIDATION, code: ErrorCode.VALIDATION_LENGTH_EXCEEDED };
      } else {
        return { type: ErrorType.VALIDATION, code: ErrorCode.VALIDATION_INVALID_TYPE };
      }
    }

    // 存储相关错误
    if (message.includes('storage') || message.includes('database') || message.includes('file')) {
      if (message.includes('not found') || message.includes('missing')) {
        return { type: ErrorType.STORAGE, code: ErrorCode.STORAGE_NOT_FOUND };
      } else if (message.includes('read') || message.includes('load')) {
        return { type: ErrorType.STORAGE, code: ErrorCode.STORAGE_READ_FAILED };
      } else if (message.includes('write') || message.includes('save')) {
        return { type: ErrorType.STORAGE, code: ErrorCode.STORAGE_WRITE_FAILED };
      } else if (message.includes('corrupt')) {
        return { type: ErrorType.STORAGE, code: ErrorCode.STORAGE_CORRUPTION };
      } else {
        return { type: ErrorType.STORAGE, code: ErrorCode.STORAGE_READ_FAILED };
      }
    }

    // 音频相关错误
    if (message.includes('audio') || message.includes('microphone') || message.includes('speaker') || message.includes('tts')) {
      if (message.includes('permission') || message.includes('denied')) {
        return { type: ErrorType.AUDIO, code: ErrorCode.AUDIO_PERMISSION_DENIED };
      } else if (message.includes('device') || message.includes('not available')) {
        return { type: ErrorType.AUDIO, code: ErrorCode.AUDIO_DEVICE_NOT_AVAILABLE };
      } else if (message.includes('playback') || message.includes('play')) {
        return { type: ErrorType.AUDIO, code: ErrorCode.AUDIO_PLAYBACK_FAILED };
      } else if (message.includes('record') || message.includes('capture')) {
        return { type: ErrorType.AUDIO, code: ErrorCode.AUDIO_RECORDING_FAILED };
      } else if (message.includes('tts') || message.includes('speech synthesis')) {
        return { type: ErrorType.AUDIO, code: ErrorCode.AUDIO_TTS_FAILED };
      } else if (message.includes('recognition') || message.includes('speech')) {
        return { type: ErrorType.AUDIO, code: ErrorCode.AUDIO_SPEECH_RECOGNITION_FAILED };
      } else {
        return { type: ErrorType.AUDIO, code: ErrorCode.AUDIO_DEVICE_NOT_AVAILABLE };
      }
    }

    // 权限相关错误
    if (message.includes('permission') || message.includes('denied') || message.includes('unauthorized')) {
      if (message.includes('camera')) {
        return { type: ErrorType.PERMISSION, code: ErrorCode.PERMISSION_CAMERA_DENIED };
      } else if (message.includes('microphone') || message.includes('audio')) {
        return { type: ErrorType.PERMISSION, code: ErrorCode.PERMISSION_MICROPHONE_DENIED };
      } else if (message.includes('storage') || message.includes('file')) {
        return { type: ErrorType.PERMISSION, code: ErrorCode.PERMISSION_STORAGE_DENIED };
      } else if (message.includes('network') || message.includes('internet')) {
        return { type: ErrorType.PERMISSION, code: ErrorCode.PERMISSION_NETWORK_DENIED };
      } else {
        return { type: ErrorType.PERMISSION, code: ErrorCode.PERMISSION_MICROPHONE_DENIED };
      }
    }

    // 超时错误
    if (message.includes('timeout') || name.includes('timeout')) {
      return { type: ErrorType.SYSTEM, code: ErrorCode.OPERATION_TIMEOUT };
    }

    // 取消操作
    if (message.includes('cancel') || message.includes('abort')) {
      return { type: ErrorType.SYSTEM, code: ErrorCode.OPERATION_CANCELLED };
    }

    // 默认系统错误
    return { type: ErrorType.SYSTEM, code: ErrorCode.UNKNOWN_ERROR };
  }

  /**
   * 记录性能指标
   */
  private static recordPerformanceMetrics(metrics: PerformanceMetrics): void {
    ErrorDecorator.performanceMetrics.push(metrics);
    
    // 限制历史记录大小
    if (ErrorDecorator.performanceMetrics.length > ErrorDecorator.MAX_METRICS_HISTORY) {
      ErrorDecorator.performanceMetrics.shift();
    }

    // 记录到日志
    Logger.debug('ErrorDecorator', 
      `性能监控: ${metrics.functionName} - ${metrics.success ? '成功' : '失败'} - ${metrics.executionTime}ms`);
  }

  /**
   * 获取性能指标统计
   */
  static getPerformanceStats(): {
    functionName: string;
    averageExecutionTime: number;
    successRate: number;
    totalCalls: number;
    errorRate: number;
  }[] {
    const functionStats = new Map<string, {
      totalTime: number;
      successCount: number;
      totalCount: number;
      errorCount: number;
    }>();

    // 统计各个函数的指标
    for (const metric of ErrorDecorator.performanceMetrics) {
      const existing = functionStats.get(metric.functionName) || {
        totalTime: 0,
        successCount: 0,
        totalCount: 0,
        errorCount: 0
      };

      existing.totalTime += metric.executionTime;
      existing.totalCount++;
      if (metric.success) {
        existing.successCount++;
      } else {
        existing.errorCount += metric.errorCount;
      }

      functionStats.set(metric.functionName, existing);
    }

    // 转换为结果格式
    return Array.from(functionStats.entries()).map(([functionName, stats]) => ({
      functionName,
      averageExecutionTime: Math.round(stats.totalTime / stats.totalCount),
      successRate: Math.round((stats.successCount / stats.totalCount) * 100),
      totalCalls: stats.totalCount,
      errorRate: Math.round((stats.errorCount / stats.totalCount) * 100)
    }));
  }

  /**
   * 清空性能指标历史
   */
  static clearPerformanceMetrics(): void {
    ErrorDecorator.performanceMetrics = [];
    Logger.info('ErrorDecorator', '性能指标历史已清空');
  }

  /**
   * 等待指定时间
   */
  private static sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}