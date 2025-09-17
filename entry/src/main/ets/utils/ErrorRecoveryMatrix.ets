/**
 * 错误恢复策略矩阵
 * 为不同类型的错误提供智能恢复策略配置
 */

import {
  ErrorType, ErrorCode, RecoveryStrategy, RecoveryConfig, ErrorLevel,
  AppError, ErrorHandlingResult
} from '../types/ErrorTypes';
import { ErrorManager } from './ErrorManager';
import { Logger } from './Logger';

/**
 * 恢复策略优先级
 */
enum RecoveryPriority {
  LOW = 1,
  MEDIUM = 2,
  HIGH = 3,
  CRITICAL = 4
}

/**
 * 恢复策略配置
 */
interface StrategyConfig {
  strategy: RecoveryStrategy;
  priority: RecoveryPriority;
  config: RecoveryConfig;
  description: string;
  applicableConditions?: (error: AppError) => boolean;
}

/**
 * 错误模式
 */
interface ErrorPattern {
  type: ErrorType;
  codes: ErrorCode[];
  strategies: StrategyConfig[];
  fallbackStrategy?: StrategyConfig;
}

/**
 * 错误恢复策略矩阵
 */
export class ErrorRecoveryMatrix {
  private static instance: ErrorRecoveryMatrix;
  private errorManager = ErrorManager.getInstance();
  private patterns: ErrorPattern[] = [];

  private constructor() {
    this.initializePatterns();
  }

  static getInstance(): ErrorRecoveryMatrix {
    if (!ErrorRecoveryMatrix.instance) {
      ErrorRecoveryMatrix.instance = new ErrorRecoveryMatrix();
    }
    return ErrorRecoveryMatrix.instance;
  }

  /**
   * 初始化错误模式和恢复策略
   */
  private initializePatterns(): void {
    // 网络错误恢复策略
    this.patterns.push({
      type: ErrorType.NETWORK,
      codes: [
        ErrorCode.NETWORK_CONNECTION_FAILED,
        ErrorCode.NETWORK_TIMEOUT,
        ErrorCode.NETWORK_UNAVAILABLE
      ],
      strategies: [
        {
          strategy: RecoveryStrategy.RETRY_WITH_BACKOFF,
          priority: RecoveryPriority.HIGH,
          config: {
            strategy: RecoveryStrategy.RETRY_WITH_BACKOFF,
            maxRetries: 3,
            retryDelay: 1000,
            backoffMultiplier: 2,
            timeout: 30000
          },
          description: '指数退避重试策略',
          applicableConditions: (error) => error.context.additionalInfo?.['attempt'] !== '3'
        },
        {
          strategy: RecoveryStrategy.FALLBACK,
          priority: RecoveryPriority.MEDIUM,
          config: {
            strategy: RecoveryStrategy.FALLBACK,
            fallbackAction: async () => {
              Logger.info('ErrorRecoveryMatrix', '网络降级: 切换到缓存模式');
            }
          },
          description: '降级到缓存模式'
        }
      ],
      fallbackStrategy: {
        strategy: RecoveryStrategy.USER_INTERVENTION,
        priority: RecoveryPriority.LOW,
        config: {
          strategy: RecoveryStrategy.USER_INTERVENTION
        },
        description: '需要用户手动处理网络问题'
      }
    });

    // API错误恢复策略
    this.patterns.push({
      type: ErrorType.API,
      codes: [
        ErrorCode.API_SERVER_ERROR,
        ErrorCode.API_SERVICE_UNAVAILABLE,
        ErrorCode.API_RATE_LIMITED
      ],
      strategies: [
        {
          strategy: RecoveryStrategy.RETRY_WITH_BACKOFF,
          priority: RecoveryPriority.HIGH,
          config: {
            strategy: RecoveryStrategy.RETRY_WITH_BACKOFF,
            maxRetries: 2,
            retryDelay: 2000,
            backoffMultiplier: 2,
            timeout: 60000
          },
          description: 'API重试策略',
          applicableConditions: (error) => error.code !== ErrorCode.API_UNAUTHORIZED
        },
        {
          strategy: RecoveryStrategy.FALLBACK,
          priority: RecoveryPriority.MEDIUM,
          config: {
            strategy: RecoveryStrategy.FALLBACK,
            fallbackAction: async () => {
              Logger.info('ErrorRecoveryMatrix', 'API降级: 切换到备用API');
            }
          },
          description: '切换到备用API服务'
        }
      ],
      fallbackStrategy: {
        strategy: RecoveryStrategy.NONE,
        priority: RecoveryPriority.LOW,
        config: {
          strategy: RecoveryStrategy.NONE
        },
        description: 'API服务完全不可用'
      }
    });

    // 音频错误恢复策略
    this.patterns.push({
      type: ErrorType.AUDIO,
      codes: [
        ErrorCode.AUDIO_RECORDING_FAILED,
        ErrorCode.AUDIO_PLAYBACK_FAILED,
        ErrorCode.AUDIO_TTS_FAILED,
        ErrorCode.AUDIO_SPEECH_RECOGNITION_FAILED
      ],
      strategies: [
        {
          strategy: RecoveryStrategy.RETRY,
          priority: RecoveryPriority.HIGH,
          config: {
            strategy: RecoveryStrategy.RETRY,
            maxRetries: 2,
            retryDelay: 1000,
            timeout: 15000
          },
          description: '音频服务重试',
          applicableConditions: (error) => error.code !== ErrorCode.AUDIO_PERMISSION_DENIED
        },
        {
          strategy: RecoveryStrategy.FALLBACK,
          priority: RecoveryPriority.MEDIUM,
          config: {
            strategy: RecoveryStrategy.FALLBACK,
            fallbackAction: async () => {
              Logger.info('ErrorRecoveryMatrix', '音频降级: 禁用音频功能');
            }
          },
          description: '禁用音频功能，使用文本模式'
        }
      ],
      fallbackStrategy: {
        strategy: RecoveryStrategy.USER_INTERVENTION,
        priority: RecoveryPriority.LOW,
        config: {
          strategy: RecoveryStrategy.USER_INTERVENTION
        },
        description: '需要用户检查音频设备和权限'
      }
    });

    // 存储错误恢复策略
    this.patterns.push({
      type: ErrorType.STORAGE,
      codes: [
        ErrorCode.STORAGE_READ_FAILED,
        ErrorCode.STORAGE_WRITE_FAILED,
        ErrorCode.STORAGE_NOT_FOUND,
        ErrorCode.STORAGE_CORRUPTION
      ],
      strategies: [
        {
          strategy: RecoveryStrategy.RETRY,
          priority: RecoveryPriority.HIGH,
          config: {
            strategy: RecoveryStrategy.RETRY,
            maxRetries: 2,
            retryDelay: 500,
            timeout: 10000
          },
          description: '存储操作重试',
          applicableConditions: (error) => error.code !== ErrorCode.STORAGE_CORRUPTION
        },
        {
          strategy: RecoveryStrategy.CLEAR_CACHE,
          priority: RecoveryPriority.MEDIUM,
          config: {
            strategy: RecoveryStrategy.CLEAR_CACHE
          },
          description: '清理存储缓存',
          applicableConditions: (error) => error.code === ErrorCode.STORAGE_CORRUPTION
        },
        {
          strategy: RecoveryStrategy.FALLBACK,
          priority: RecoveryPriority.MEDIUM,
          config: {
            strategy: RecoveryStrategy.FALLBACK,
            fallbackAction: async () => {
              Logger.info('ErrorRecoveryMatrix', '存储降级: 使用内存模式');
            }
          },
          description: '降级到内存存储模式'
        }
      ],
      fallbackStrategy: {
        strategy: RecoveryStrategy.USER_INTERVENTION,
        priority: RecoveryPriority.LOW,
        config: {
          strategy: RecoveryStrategy.USER_INTERVENTION
        },
        description: '需要用户手动处理存储问题'
      }
    });

    // 权限错误恢复策略
    this.patterns.push({
      type: ErrorType.PERMISSION,
      codes: [
        ErrorCode.PERMISSION_MICROPHONE_DENIED,
        ErrorCode.PERMISSION_CAMERA_DENIED,
        ErrorCode.PERMISSION_STORAGE_DENIED,
        ErrorCode.PERMISSION_NETWORK_DENIED
      ],
      strategies: [
        {
          strategy: RecoveryStrategy.USER_INTERVENTION,
          priority: RecoveryPriority.CRITICAL,
          config: {
            strategy: RecoveryStrategy.USER_INTERVENTION
          },
          description: '引导用户授权权限'
        }
      ],
      fallbackStrategy: {
        strategy: RecoveryStrategy.FALLBACK,
        priority: RecoveryPriority.LOW,
        config: {
          strategy: RecoveryStrategy.FALLBACK,
          fallbackAction: async () => {
            Logger.info('ErrorRecoveryMatrix', '权限降级: 禁用相关功能');
          }
        },
        description: '禁用需要权限的功能'
      }
    });

    // 业务逻辑错误恢复策略
    this.patterns.push({
      type: ErrorType.BUSINESS,
      codes: [ErrorCode.UNKNOWN_ERROR],
      strategies: [
        {
          strategy: RecoveryStrategy.RETRY,
          priority: RecoveryPriority.MEDIUM,
          config: {
            strategy: RecoveryStrategy.RETRY,
            maxRetries: 1,
            retryDelay: 1000,
            timeout: 10000
          },
          description: '业务逻辑重试'
        },
        {
          strategy: RecoveryStrategy.FALLBACK,
          priority: RecoveryPriority.MEDIUM,
          config: {
            strategy: RecoveryStrategy.FALLBACK,
            fallbackAction: async () => {
              Logger.info('ErrorRecoveryMatrix', '业务降级: 使用默认行为');
            }
          },
          description: '降级到默认业务逻辑'
        }
      ],
      fallbackStrategy: {
        strategy: RecoveryStrategy.NONE,
        priority: RecoveryPriority.LOW,
        config: {
          strategy: RecoveryStrategy.NONE
        },
        description: '无法恢复的业务错误'
      }
    });

    // UI错误恢复策略
    this.patterns.push({
      type: ErrorType.UI,
      codes: [ErrorCode.UNKNOWN_ERROR],
      strategies: [
        {
          strategy: RecoveryStrategy.FALLBACK,
          priority: RecoveryPriority.HIGH,
          config: {
            strategy: RecoveryStrategy.FALLBACK,
            fallbackAction: async () => {
              Logger.info('ErrorRecoveryMatrix', 'UI降级: 使用简化界面');
            }
          },
          description: '降级到简化UI模式'
        }
      ],
      fallbackStrategy: {
        strategy: RecoveryStrategy.NONE,
        priority: RecoveryPriority.LOW,
        config: {
          strategy: RecoveryStrategy.NONE
        },
        description: 'UI错误静默处理'
      }
    });

    Logger.info('ErrorRecoveryMatrix', `已初始化 ${this.patterns.length} 种错误模式的恢复策略`);
  }

  /**
   * 获取错误的最佳恢复策略
   */
  getBestRecoveryStrategy(error: AppError): RecoveryConfig | null {
    const pattern = this.findMatchingPattern(error);
    if (!pattern) {
      Logger.warn('ErrorRecoveryMatrix', `未找到错误类型 ${error.type} 代码 ${error.code} 的恢复模式`);
      return null;
    }

    // 筛选适用的策略
    const applicableStrategies = pattern.strategies.filter(strategy => {
      if (strategy.applicableConditions) {
        return strategy.applicableConditions(error);
      }
      return true;
    });

    if (applicableStrategies.length === 0) {
      Logger.warn('ErrorRecoveryMatrix', `无适用的恢复策略，使用降级策略`);
      return pattern.fallbackStrategy?.config || null;
    }

    // 按优先级排序，选择最高优先级的策略
    applicableStrategies.sort((a, b) => b.priority - a.priority);
    const bestStrategy = applicableStrategies[0];

    Logger.info('ErrorRecoveryMatrix', 
      `选择恢复策略: ${bestStrategy.description} (优先级: ${bestStrategy.priority})`);

    return bestStrategy.config;
  }

  /**
   * 获取所有可用的恢复策略
   */
  getAllRecoveryStrategies(error: AppError): StrategyConfig[] {
    const pattern = this.findMatchingPattern(error);
    if (!pattern) {
      return [];
    }

    const applicableStrategies = pattern.strategies.filter(strategy => {
      if (strategy.applicableConditions) {
        return strategy.applicableConditions(error);
      }
      return true;
    });

    // 按优先级排序
    applicableStrategies.sort((a, b) => b.priority - a.priority);

    // 添加降级策略
    if (pattern.fallbackStrategy) {
      applicableStrategies.push(pattern.fallbackStrategy);
    }

    return applicableStrategies;
  }

  /**
   * 应用智能恢复策略
   */
  async applyIntelligentRecovery(error: AppError): Promise<ErrorHandlingResult> {
    const strategy = this.getBestRecoveryStrategy(error);
    if (!strategy) {
      return {
        success: false,
        recovered: false,
        retryCount: 0,
        finalError: error,
        recoveryTime: 0
      };
    }

    // 使用选定的策略更新错误的恢复配置
    error.recoveryConfig = strategy;

    // 应用恢复策略
    return await this.errorManager.handleError(error);
  }

  /**
   * 预测错误恢复成功率
   */
  predictRecoverySuccess(error: AppError): number {
    const strategies = this.getAllRecoveryStrategies(error);
    if (strategies.length === 0) {
      return 0;
    }

    // 基于错误类型和策略优先级计算成功率
    let successRate = 0;
    for (const strategy of strategies) {
      switch (strategy.strategy) {
        case RecoveryStrategy.RETRY:
        case RecoveryStrategy.RETRY_WITH_BACKOFF:
          successRate += strategy.priority * 0.2; // 重试策略成功率较高
          break;
        case RecoveryStrategy.FALLBACK:
          successRate += strategy.priority * 0.15; // 降级策略中等成功率
          break;
        case RecoveryStrategy.CLEAR_CACHE:
          successRate += strategy.priority * 0.1; // 清缓存策略较低成功率
          break;
        case RecoveryStrategy.USER_INTERVENTION:
          successRate += strategy.priority * 0.05; // 需要用户干预成功率最低
          break;
        default:
          successRate += 0;
      }
    }

    // 标准化到0-1范围
    return Math.min(1, successRate / 10);
  }

  /**
   * 添加自定义恢复模式
   */
  addCustomPattern(pattern: ErrorPattern): void {
    this.patterns.push(pattern);
    Logger.info('ErrorRecoveryMatrix', `添加自定义错误模式: ${pattern.type}`);
  }

  /**
   * 获取恢复策略统计
   */
  getRecoveryStats(): {
    totalPatterns: number;
    strategiesByType: Record<string, number>;
    priorityDistribution: Record<string, number>;
  } {
    const strategiesByType: Record<string, number> = {};
    const priorityDistribution: Record<string, number> = {};

    for (const pattern of this.patterns) {
      strategiesByType[pattern.type] = (strategiesByType[pattern.type] || 0) + pattern.strategies.length;
      
      for (const strategy of pattern.strategies) {
        const priorityKey = RecoveryPriority[strategy.priority];
        priorityDistribution[priorityKey] = (priorityDistribution[priorityKey] || 0) + 1;
      }
    }

    return {
      totalPatterns: this.patterns.length,
      strategiesByType,
      priorityDistribution
    };
  }

  /**
   * 查找匹配的错误模式
   */
  private findMatchingPattern(error: AppError): ErrorPattern | null {
    return this.patterns.find(pattern => 
      pattern.type === error.type && 
      (pattern.codes.length === 0 || pattern.codes.includes(error.code))
    ) || null;
  }
}