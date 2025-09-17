/**
 * 自适应超时管理器
 * 根据请求历史和网络条件动态调整超时时间，优化用户体验
 */

import { Logger } from './Logger';

/**
 * 请求类型枚举
 */
export enum RequestType {
  CHAT = 'chat',
  MODEL_LIST = 'model_list',
  CONNECTION_TEST = 'connection_test',
  CODE_EXECUTION = 'code_execution',
  SEARCH = 'search',
  FILE_OPERATION = 'file_operation',
  WEBSOCKET = 'websocket',
  OTHER = 'other'
}

/**
 * 超时策略配置
 */
export interface TimeoutStrategy {
  baseTimeout: number;      // 基础超时时间(ms)
  minTimeout: number;       // 最小超时时间(ms)
  maxTimeout: number;       // 最大超时时间(ms)
  adaptiveFactor: number;   // 自适应因子(0-1)
  failureMultiplier: number; // 失败时的超时倍数
  successDivisor: number;   // 成功时的超时除数
}

/**
 * 请求历史记录
 */
interface RequestHistory {
  requestType: RequestType;
  hostname: string;
  startTime: number;
  endTime: number;
  success: boolean;
  timeout: number;
  actualDuration: number;
  errorType?: string;
}

/**
 * 主机性能统计
 */
interface HostPerformance {
  hostname: string;
  totalRequests: number;
  successRequests: number;
  averageResponseTime: number;
  medianResponseTime: number;
  p95ResponseTime: number;
  successRate: number;
  lastUpdateTime: number;
  currentOptimalTimeout: number;
}

/**
 * 超时管理器配置
 */
export interface TimeoutManagerConfig {
  maxHistorySize: number;           // 最大历史记录数
  historyRetentionTime: number;     // 历史记录保留时间(ms)
  performanceUpdateInterval: number; // 性能统计更新间隔(ms)
  adaptiveThreshold: number;        // 自适应阈值
  enableLearning: boolean;          // 是否启用学习功能
  enableNetworkDetection: boolean;  // 是否启用网络状况检测
}

/**
 * 超时统计信息
 */
export interface TimeoutStats {
  totalRequests: number;
  timeoutAdjustments: number;
  averageTimeoutReduction: number;
  performanceImprovement: number;
  currentOptimalTimeouts: Map<string, number>;
  hostPerformanceMap: Map<string, HostPerformance>;
}

/**
 * 性能报告接口
 */
interface PerformanceReport {
  config: TimeoutManagerConfig;
  strategies: Map<string, TimeoutStrategy>;
  hostPerformance: Map<string, HostPerformance>;
  recentActivity: RecentActivity;
}

/**
 * 最近活动统计
 */
interface RecentActivity {
  totalRequests: number;
  successRate: number;
  avgResponseTime: number;
}

/**
 * 自适应超时管理器类
 */
export class AdaptiveTimeoutManager {
  private static instance: AdaptiveTimeoutManager;
  private config: TimeoutManagerConfig;
  private strategies: Map<RequestType, TimeoutStrategy> = new Map();
  private requestHistory: RequestHistory[] = [];
  private hostPerformance: Map<string, HostPerformance> = new Map();
  private stats: TimeoutStats;
  private updateTimer?: number;

  private constructor(config?: Partial<TimeoutManagerConfig>) {
    this.config = {
      maxHistorySize: 1000,
      historyRetentionTime: 24 * 60 * 60 * 1000, // 24小时
      performanceUpdateInterval: 60000, // 1分钟
      adaptiveThreshold: 0.8,
      enableLearning: true,
      enableNetworkDetection: true
    };

    // 手动合并配置以符合ArkTS规范
    if (config) {
      if (config.maxHistorySize !== undefined) this.config.maxHistorySize = config.maxHistorySize;
      if (config.historyRetentionTime !== undefined) this.config.historyRetentionTime = config.historyRetentionTime;
      if (config.performanceUpdateInterval !== undefined) this.config.performanceUpdateInterval = config.performanceUpdateInterval;
      if (config.adaptiveThreshold !== undefined) this.config.adaptiveThreshold = config.adaptiveThreshold;
      if (config.enableLearning !== undefined) this.config.enableLearning = config.enableLearning;
      if (config.enableNetworkDetection !== undefined) this.config.enableNetworkDetection = config.enableNetworkDetection;
    }

    this.stats = {
      totalRequests: 0,
      timeoutAdjustments: 0,
      averageTimeoutReduction: 0,
      performanceImprovement: 0,
      currentOptimalTimeouts: new Map(),
      hostPerformanceMap: new Map()
    };

    this.initializeDefaultStrategies();
    this.startPerformanceUpdateTimer();

    Logger.info('AdaptiveTimeoutManager', `自适应超时管理器初始化完成，配置: ${JSON.stringify(this.config)}`);
  }

  /**
   * 获取单例实例
   */
  static getInstance(config?: Partial<TimeoutManagerConfig>): AdaptiveTimeoutManager {
    if (!AdaptiveTimeoutManager.instance) {
      AdaptiveTimeoutManager.instance = new AdaptiveTimeoutManager(config);
    }
    return AdaptiveTimeoutManager.instance;
  }

  /**
   * 初始化默认超时策略
   */
  private initializeDefaultStrategies(): void {
    // 聊天请求 - 通常需要较长时间
    this.strategies.set(RequestType.CHAT, {
      baseTimeout: 60000,
      minTimeout: 15000,
      maxTimeout: 180000,
      adaptiveFactor: 0.3,
      failureMultiplier: 1.5,
      successDivisor: 1.2
    });

    // 模型列表 - 通常较快
    this.strategies.set(RequestType.MODEL_LIST, {
      baseTimeout: 10000,
      minTimeout: 3000,
      maxTimeout: 30000,
      adaptiveFactor: 0.5,
      failureMultiplier: 1.8,
      successDivisor: 1.3
    });

    // 连接测试 - 应该很快
    this.strategies.set(RequestType.CONNECTION_TEST, {
      baseTimeout: 5000,
      minTimeout: 1000,
      maxTimeout: 15000,
      adaptiveFactor: 0.7,
      failureMultiplier: 2.0,
      successDivisor: 1.5
    });

    // 代码执行 - 可能需要很长时间
    this.strategies.set(RequestType.CODE_EXECUTION, {
      baseTimeout: 120000,
      minTimeout: 30000,
      maxTimeout: 300000,
      adaptiveFactor: 0.2,
      failureMultiplier: 1.3,
      successDivisor: 1.1
    });

    // 搜索请求 - 中等时间
    this.strategies.set(RequestType.SEARCH, {
      baseTimeout: 20000,
      minTimeout: 5000,
      maxTimeout: 60000,
      adaptiveFactor: 0.4,
      failureMultiplier: 1.6,
      successDivisor: 1.3
    });

    // 文件操作 - 依赖文件大小
    this.strategies.set(RequestType.FILE_OPERATION, {
      baseTimeout: 30000,
      minTimeout: 5000,
      maxTimeout: 120000,
      adaptiveFactor: 0.3,
      failureMultiplier: 1.4,
      successDivisor: 1.2
    });

    // WebSocket连接 - 应该较快
    this.strategies.set(RequestType.WEBSOCKET, {
      baseTimeout: 8000,
      minTimeout: 2000,
      maxTimeout: 20000,
      adaptiveFactor: 0.6,
      failureMultiplier: 1.8,
      successDivisor: 1.4
    });

    // 其他请求 - 通用策略
    this.strategies.set(RequestType.OTHER, {
      baseTimeout: 30000,
      minTimeout: 5000,
      maxTimeout: 90000,
      adaptiveFactor: 0.4,
      failureMultiplier: 1.5,
      successDivisor: 1.2
    });

    Logger.info('AdaptiveTimeoutManager', '默认超时策略初始化完成');
  }

  /**
   * 获取自适应超时时间
   */
  getAdaptiveTimeout(requestType: RequestType, hostname: string, url?: string): number {
    this.stats.totalRequests++;

    const strategy = this.strategies.get(requestType) || this.strategies.get(RequestType.OTHER)!;
    const hostPerf = this.hostPerformance.get(hostname);

    let adaptiveTimeout = strategy.baseTimeout;

    if (this.config.enableLearning && hostPerf) {
      // 基于历史性能调整超时
      adaptiveTimeout = this.calculateAdaptiveTimeout(strategy, hostPerf);
    }

    // 考虑当前网络状况
    if (this.config.enableNetworkDetection) {
      adaptiveTimeout = this.adjustForNetworkCondition(adaptiveTimeout, hostname);
    }

    // 特殊URL路径调整
    if (url) {
      adaptiveTimeout = this.adjustForUrlPattern(adaptiveTimeout, url, requestType);
    }

    // 确保在合理范围内
    adaptiveTimeout = Math.max(strategy.minTimeout, Math.min(strategy.maxTimeout, adaptiveTimeout));

    Logger.debug('AdaptiveTimeoutManager',
      `${requestType}请求到${hostname}的自适应超时: ${adaptiveTimeout}ms (基础: ${strategy.baseTimeout}ms)`);

    return adaptiveTimeout;
  }

  /**
   * 计算自适应超时时间
   */
  private calculateAdaptiveTimeout(strategy: TimeoutStrategy, hostPerf: HostPerformance): number {
    let adaptiveTimeout = strategy.baseTimeout;

    // 基于成功率调整
    if (hostPerf.successRate < this.config.adaptiveThreshold) {
      // 成功率较低，增加超时时间
      adaptiveTimeout *= strategy.failureMultiplier;
    } else if (hostPerf.successRate > 0.95) {
      // 成功率很高，可以减少超时时间
      adaptiveTimeout /= strategy.successDivisor;
    }

    // 基于响应时间调整
    const responseTimeRatio = hostPerf.p95ResponseTime / strategy.baseTimeout;
    if (responseTimeRatio > 0.8) {
      // P95响应时间接近超时，增加超时时间
      adaptiveTimeout = Math.max(adaptiveTimeout, hostPerf.p95ResponseTime * 1.3);
    } else if (responseTimeRatio < 0.3) {
      // 响应时间很短，可以减少超时时间
      adaptiveTimeout = Math.min(adaptiveTimeout, hostPerf.p95ResponseTime * 2.5);
    }

    // 应用自适应因子
    const adjustment = (adaptiveTimeout - strategy.baseTimeout) * strategy.adaptiveFactor;
    return strategy.baseTimeout + adjustment;
  }

  /**
   * 根据网络状况调整超时
   */
  private adjustForNetworkCondition(timeout: number, hostname: string): number {
    const hostPerf = this.hostPerformance.get(hostname);
    if (!hostPerf) return timeout;

    // 基于最近的性能趋势调整
    const recentHistory = this.getRecentHistory(hostname, 10);
    if (recentHistory.length >= 5) {
      const recentAvgTime = recentHistory.reduce((sum, h) => sum + h.actualDuration, 0) / recentHistory.length;
      const historicalAvgTime = hostPerf.averageResponseTime;

      if (recentAvgTime > historicalAvgTime * 1.5) {
        // 最近性能下降，增加超时
        timeout *= 1.3;
        Logger.debug('AdaptiveTimeoutManager', `检测到${hostname}网络性能下降，增加超时至${timeout}ms`);
      } else if (recentAvgTime < historicalAvgTime * 0.7) {
        // 最近性能提升，减少超时
        timeout *= 0.8;
        Logger.debug('AdaptiveTimeoutManager', `检测到${hostname}网络性能提升，减少超时至${timeout}ms`);
      }
    }

    return timeout;
  }

  /**
   * 根据URL模式调整超时
   */
  private adjustForUrlPattern(timeout: number, url: string, requestType: RequestType): number {
    // 根据URL路径特征调整超时
    if (url.includes('/chat/completions') || url.includes('/v1/chat')) {
      // 聊天完成接口通常需要更长时间
      if (requestType === RequestType.CHAT) {
        timeout *= 1.2;
      }
    } else if (url.includes('/models')) {
      // 模型列表接口通常较快
      timeout *= 0.7;
    } else if (url.includes('/search')) {
      // 搜索接口时间可变
      timeout *= 1.1;
    }

    return timeout;
  }

  /**
   * 记录请求结果
   */
  recordRequestResult(
    requestType: RequestType,
    hostname: string,
    startTime: number,
    endTime: number,
    success: boolean,
    usedTimeout: number,
    errorType?: string
  ): void {
    const actualDuration = endTime - startTime;

    const history: RequestHistory = {
      requestType,
      hostname,
      startTime,
      endTime,
      success,
      timeout: usedTimeout,
      actualDuration,
      errorType
    };

    this.requestHistory.push(history);

    // 限制历史记录大小
    if (this.requestHistory.length > this.config.maxHistorySize) {
      this.requestHistory = this.requestHistory.slice(-this.config.maxHistorySize);
    }

    // 立即更新该主机的性能数据
    this.updateHostPerformance(hostname);

    // 检查是否需要调整超时策略
    if (this.config.enableLearning) {
      this.adjustStrategyIfNeeded(requestType, hostname, history);
    }

    Logger.debug('AdaptiveTimeoutManager',
      `记录${requestType}请求结果: ${hostname}, 耗时: ${actualDuration}ms, 成功: ${success}, 超时设置: ${usedTimeout}ms`);
  }

  /**
   * 更新主机性能统计
   */
  private updateHostPerformance(hostname: string): void {
    const hostHistory = this.requestHistory.filter(h => h.hostname === hostname);

    if (hostHistory.length === 0) return;

    const successHistory = hostHistory.filter(h => h.success);
    const responseTimes = successHistory.map(h => h.actualDuration).sort((a, b) => a - b);

    const performance: HostPerformance = {
      hostname,
      totalRequests: hostHistory.length,
      successRequests: successHistory.length,
      averageResponseTime: responseTimes.length > 0 ?
        responseTimes.reduce((sum, time) => sum + time, 0) / responseTimes.length : 0,
      medianResponseTime: responseTimes.length > 0 ?
        responseTimes[Math.floor(responseTimes.length / 2)] : 0,
      p95ResponseTime: responseTimes.length > 0 ?
        responseTimes[Math.floor(responseTimes.length * 0.95)] : 0,
      successRate: hostHistory.length > 0 ? successHistory.length / hostHistory.length : 0,
      lastUpdateTime: Date.now(),
      currentOptimalTimeout: 0
    };

    // 计算当前最优超时时间
    if (performance.p95ResponseTime > 0) {
      performance.currentOptimalTimeout = Math.max(
        performance.p95ResponseTime * 1.5,
        performance.averageResponseTime * 2
      );
    }

    this.hostPerformance.set(hostname, performance);
    this.stats.hostPerformanceMap.set(hostname, performance);
  }

  /**
   * 根据需要调整策略
   */
  private adjustStrategyIfNeeded(
    requestType: RequestType,
    hostname: string,
    history: RequestHistory
  ): void {
    const strategy = this.strategies.get(requestType);
    if (!strategy) return;

    const typeHistory = this.getRequestTypeHistory(requestType, hostname, 20);
    if (typeHistory.length < 10) return; // 需要足够的样本

    const timeouts = typeHistory.filter(h => h.actualDuration >= h.timeout);
    const timeoutRate = timeouts.length / typeHistory.length;

    // 如果超时率过高，调整基础超时
    if (timeoutRate > 0.1) { // 超过10%的请求超时
      const newBaseTimeout = Math.min(
        strategy.maxTimeout,
        strategy.baseTimeout * strategy.failureMultiplier
      );

      if (newBaseTimeout !== strategy.baseTimeout) {
        strategy.baseTimeout = newBaseTimeout;
        this.stats.timeoutAdjustments++;
        Logger.info('AdaptiveTimeoutManager',
          `调整${requestType}类型的基础超时时间至${newBaseTimeout}ms，原因：超时率${(timeoutRate * 100).toFixed(1)}%`);
      }
    }

    // 如果性能很好，可以尝试降低超时
    const successRate = typeHistory.filter(h => h.success).length / typeHistory.length;
    const avgDuration = typeHistory.reduce((sum, h) => sum + h.actualDuration, 0) / typeHistory.length;

    if (successRate > 0.95 && avgDuration < strategy.baseTimeout * 0.5) {
      const newBaseTimeout = Math.max(
        strategy.minTimeout,
        strategy.baseTimeout / strategy.successDivisor
      );

      if (newBaseTimeout !== strategy.baseTimeout) {
        strategy.baseTimeout = newBaseTimeout;
        this.stats.timeoutAdjustments++;
        Logger.info('AdaptiveTimeoutManager',
          `优化${requestType}类型的基础超时时间至${newBaseTimeout}ms，原因：性能良好`);
      }
    }
  }

  /**
   * 获取指定类型的请求历史
   */
  private getRequestTypeHistory(requestType: RequestType, hostname: string, limit: number): RequestHistory[] {
    return this.requestHistory
      .filter(h => h.requestType === requestType && h.hostname === hostname)
      .slice(-limit);
  }

  /**
   * 获取最近的主机历史
   */
  private getRecentHistory(hostname: string, limit: number): RequestHistory[] {
    return this.requestHistory
      .filter(h => h.hostname === hostname)
      .slice(-limit);
  }

  /**
   * 启动性能更新定时器
   */
  private startPerformanceUpdateTimer(): void {
    this.updateTimer = setInterval(() => {
      this.cleanupOldHistory();
      this.updateAllHostsPerformance();
      this.updateStats();
    }, this.config.performanceUpdateInterval);

    Logger.info('AdaptiveTimeoutManager', '性能更新定时器已启动');
  }

  /**
   * 清理过期历史记录
   */
  private cleanupOldHistory(): void {
    const cutoffTime = Date.now() - this.config.historyRetentionTime;
    const originalLength = this.requestHistory.length;

    this.requestHistory = this.requestHistory.filter(h => h.startTime > cutoffTime);

    const removedCount = originalLength - this.requestHistory.length;
    if (removedCount > 0) {
      Logger.debug('AdaptiveTimeoutManager', `清理了${removedCount}条过期历史记录`);
    }
  }

  /**
   * 更新所有主机的性能统计
   */
  private updateAllHostsPerformance(): void {
    const hostnameSet = new Set<string>();
    this.requestHistory.forEach(h => hostnameSet.add(h.hostname));
    const uniqueHosts = Array.from(hostnameSet);
    uniqueHosts.forEach(hostname => this.updateHostPerformance(hostname));
  }

  /**
   * 更新统计信息
   */
  private updateStats(): void {
    // 计算平均超时减少量
    let totalReduction = 0;
    let reductionCount = 0;

    this.strategies.forEach((strategy, requestType) => {
      const defaultStrategy = this.getDefaultStrategy(requestType);
      if (strategy.baseTimeout < defaultStrategy.baseTimeout) {
        totalReduction += defaultStrategy.baseTimeout - strategy.baseTimeout;
        reductionCount++;
      }
    });

    this.stats.averageTimeoutReduction = reductionCount > 0 ? totalReduction / reductionCount : 0;

    // 更新当前最优超时
    this.stats.currentOptimalTimeouts.clear();
    this.hostPerformance.forEach((perf, hostname) => {
      if (perf.currentOptimalTimeout > 0) {
        this.stats.currentOptimalTimeouts.set(hostname, perf.currentOptimalTimeout);
      }
    });

    // 计算性能改进
    const totalRequests = this.requestHistory.length;
    const successfulRequests = this.requestHistory.filter(h => h.success).length;
    this.stats.performanceImprovement = totalRequests > 0 ?
      (successfulRequests / totalRequests) * 100 : 0;
  }

  /**
   * 获取默认策略（用于比较）
   */
  private getDefaultStrategy(requestType: RequestType): TimeoutStrategy {
    // 返回初始化时的默认值
    switch (requestType) {
      case RequestType.CHAT:
        return { baseTimeout: 60000, minTimeout: 15000, maxTimeout: 180000, adaptiveFactor: 0.3, failureMultiplier: 1.5, successDivisor: 1.2 };
      case RequestType.MODEL_LIST:
        return { baseTimeout: 10000, minTimeout: 3000, maxTimeout: 30000, adaptiveFactor: 0.5, failureMultiplier: 1.8, successDivisor: 1.3 };
      case RequestType.CONNECTION_TEST:
        return { baseTimeout: 5000, minTimeout: 1000, maxTimeout: 15000, adaptiveFactor: 0.7, failureMultiplier: 2.0, successDivisor: 1.5 };
      default:
        return { baseTimeout: 30000, minTimeout: 5000, maxTimeout: 90000, adaptiveFactor: 0.4, failureMultiplier: 1.5, successDivisor: 1.2 };
    }
  }

  /**
   * 获取统计信息
   */
  getStats(): TimeoutStats {
    this.updateStats();
    return {
      totalRequests: this.stats.totalRequests,
      timeoutAdjustments: this.stats.timeoutAdjustments,
      averageTimeoutReduction: this.stats.averageTimeoutReduction,
      performanceImprovement: this.stats.performanceImprovement,
      currentOptimalTimeouts: this.stats.currentOptimalTimeouts,
      hostPerformanceMap: this.stats.hostPerformanceMap
    };
  }

  /**
   * 获取详细的性能报告
   */
  getPerformanceReport(): PerformanceReport {
    // 最近活动统计
    const last24Hours = Date.now() - 24 * 60 * 60 * 1000;
    const recentRequests = this.requestHistory.filter(h => h.startTime > last24Hours);

    const recentActivity: RecentActivity = {
      totalRequests: recentRequests.length,
      successRate: recentRequests.length > 0 ?
        recentRequests.filter(h => h.success).length / recentRequests.length : 0,
      avgResponseTime: recentRequests.length > 0 ?
        recentRequests.reduce((sum, h) => sum + h.actualDuration, 0) / recentRequests.length : 0
    };

    const report: PerformanceReport = {
      config: this.config,
      strategies: new Map<string, TimeoutStrategy>(),
      hostPerformance: new Map<string, HostPerformance>(),
      recentActivity: recentActivity
    };

    // 策略信息
    this.strategies.forEach((strategy, type) => {
      report.strategies.set(type, strategy);
    });

    // 主机性能
    this.hostPerformance.forEach((perf, hostname) => {
      report.hostPerformance.set(hostname, perf);
    });

    return report;
  }

  /**
   * 强制清理
   */
  cleanup(): void {
    this.requestHistory = [];
    this.hostPerformance.clear();

    if (this.updateTimer) {
      clearInterval(this.updateTimer);
      this.updateTimer = undefined;
    }

    this.updateStats();
    Logger.info('AdaptiveTimeoutManager', '自适应超时管理器已完全清理');
  }

  /**
   * 重新配置管理器
   */
  reconfigure(newConfig: Partial<TimeoutManagerConfig>): void {
    // 手动合并配置以符合ArkTS规范
    if (newConfig.maxHistorySize !== undefined) this.config.maxHistorySize = newConfig.maxHistorySize;
    if (newConfig.historyRetentionTime !== undefined) this.config.historyRetentionTime = newConfig.historyRetentionTime;
    if (newConfig.performanceUpdateInterval !== undefined) this.config.performanceUpdateInterval = newConfig.performanceUpdateInterval;
    if (newConfig.adaptiveThreshold !== undefined) this.config.adaptiveThreshold = newConfig.adaptiveThreshold;
    if (newConfig.enableLearning !== undefined) this.config.enableLearning = newConfig.enableLearning;
    if (newConfig.enableNetworkDetection !== undefined) this.config.enableNetworkDetection = newConfig.enableNetworkDetection;

    Logger.info('AdaptiveTimeoutManager', `自适应超时管理器配置已更新: ${JSON.stringify(this.config)}`);
  }

  /**
   * 手动设置请求类型策略
   */
  setTimeoutStrategy(requestType: RequestType, strategy: Partial<TimeoutStrategy>): void {
    const currentStrategy = this.strategies.get(requestType) || this.strategies.get(RequestType.OTHER)!;

    // 手动合并策略以符合ArkTS规范
    const newStrategy: TimeoutStrategy = {
      baseTimeout: currentStrategy.baseTimeout,
      minTimeout: currentStrategy.minTimeout,
      maxTimeout: currentStrategy.maxTimeout,
      adaptiveFactor: currentStrategy.adaptiveFactor,
      failureMultiplier: currentStrategy.failureMultiplier,
      successDivisor: currentStrategy.successDivisor
    };

    if (strategy.baseTimeout !== undefined) newStrategy.baseTimeout = strategy.baseTimeout;
    if (strategy.minTimeout !== undefined) newStrategy.minTimeout = strategy.minTimeout;
    if (strategy.maxTimeout !== undefined) newStrategy.maxTimeout = strategy.maxTimeout;
    if (strategy.adaptiveFactor !== undefined) newStrategy.adaptiveFactor = strategy.adaptiveFactor;
    if (strategy.failureMultiplier !== undefined) newStrategy.failureMultiplier = strategy.failureMultiplier;
    if (strategy.successDivisor !== undefined) newStrategy.successDivisor = strategy.successDivisor;

    this.strategies.set(requestType, newStrategy);
    Logger.info('AdaptiveTimeoutManager', `已更新${requestType}类型的超时策略`);
  }
}