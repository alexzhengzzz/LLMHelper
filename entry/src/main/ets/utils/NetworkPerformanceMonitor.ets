/**
 * 网络性能监控器
 * 统一管理和监控HTTP连接池、请求去重、自适应超时等优化功能的性能指标
 */

import { NetworkRequestOptimizer, OptimizationStats } from './NetworkRequestOptimizer';
import { HTTPConnectionPool, PoolStats } from './HTTPConnectionPool';
import { RequestDeduplicator, DeduplicationStats } from './RequestDeduplicator';
import { AdaptiveTimeoutManager, TimeoutStats } from './AdaptiveTimeoutManager';
import { Logger } from './Logger';

/**
 * 性能监控配置
 */
export interface PerformanceMonitorConfig {
  enableRealTimeMonitoring: boolean;  // 是否启用实时监控
  enablePerformanceAlerts: boolean;   // 是否启用性能告警
  alertThresholds: {
    connectionPoolUtilization: number;  // 连接池利用率告警阈值
    deduplicationRate: number;          // 去重率告警阈值
    timeoutAdjustmentRate: number;      // 超时调整率告警阈值
    errorRate: number;                  // 错误率告警阈值
  };
  monitoringInterval: number;          // 监控间隔(ms)
  historyRetentionTime: number;        // 历史数据保留时间(ms)
}

/**
 * 性能快照
 */
export interface PerformanceSnapshot {
  timestamp: number;
  totalRequests: number;
  successRate: number;
  averageResponseTime: number;
  connectionReuseRate: number;
  deduplicationRate: number;
  timeoutOptimizationRate: number;
  networkEfficiency: number;
}

/**
 * 性能趋势数据
 */
export interface PerformanceTrend {
  period: string;  // '1h', '24h', '7d'
  snapshots: PerformanceSnapshot[];
  summary: {
    avgSuccessRate: number;
    avgResponseTime: number;
    avgConnectionReuse: number;
    avgDeduplication: number;
    performanceGain: number;
  };
}

/**
 * 性能告警
 */
export interface PerformanceAlert {
  id: string;
  type: 'connection_pool' | 'deduplication' | 'timeout' | 'error_rate';
  severity: 'low' | 'medium' | 'high';
  message: string;
  threshold: number;
  currentValue: number;
  timestamp: number;
  resolved: boolean;
}

/**
 * 综合性能报告
 */
export interface ComprehensivePerformanceReport {
  summary: {
    overallHealth: 'excellent' | 'good' | 'fair' | 'poor';
    totalRequests: number;
    successRate: number;
    averagePerformanceGain: number;
    keyOptimizations: string[];
  };
  connectionPool: {
    totalConnections: number;
    reuseRate: number;
    avgConnectionAge: number;
    efficiency: string;
  };
  requestDeduplication: {
    totalDuplicatesSaved: number;
    deduplicationRate: number;
    timeSaved: number;
    efficiency: string;
  };
  adaptiveTimeout: {
    totalAdjustments: number;
    avgTimeoutReduction: number;
    performanceImprovement: number;
    efficiency: string;
  };
  trends: PerformanceTrend[];
  alerts: PerformanceAlert[];
  recommendations: string[];
}

/**
 * 网络性能监控器类
 */
export class NetworkPerformanceMonitor {
  private static instance: NetworkPerformanceMonitor;
  private config: PerformanceMonitorConfig;
  private networkOptimizer: NetworkRequestOptimizer;
  private connectionPool: HTTPConnectionPool;
  private requestDeduplicator: RequestDeduplicator;
  private timeoutManager: AdaptiveTimeoutManager;

  private performanceHistory: PerformanceSnapshot[] = [];
  private activeAlerts: Map<string, PerformanceAlert> = new Map();
  private monitoringTimer?: number;
  private alertCounter: number = 0;

  private constructor(config?: Partial<PerformanceMonitorConfig>) {
    this.config = {
      enableRealTimeMonitoring: true,
      enablePerformanceAlerts: true,
      alertThresholds: {
        connectionPoolUtilization: 90,  // 90%
        deduplicationRate: 20,          // 20%
        timeoutAdjustmentRate: 10,      // 10%
        errorRate: 5                    // 5%
      },
      monitoringInterval: 30000,        // 30秒
      historyRetentionTime: 24 * 60 * 60 * 1000  // 24小时
    };

    // 手动合并配置以符合ArkTS规范
    if (config) {
      if (config.enableRealTimeMonitoring !== undefined) this.config.enableRealTimeMonitoring = config.enableRealTimeMonitoring;
      if (config.enablePerformanceAlerts !== undefined) this.config.enablePerformanceAlerts = config.enablePerformanceAlerts;
      if (config.alertThresholds !== undefined) {
        if (config.alertThresholds.connectionPoolUtilization !== undefined) this.config.alertThresholds.connectionPoolUtilization = config.alertThresholds.connectionPoolUtilization;
        if (config.alertThresholds.deduplicationRate !== undefined) this.config.alertThresholds.deduplicationRate = config.alertThresholds.deduplicationRate;
        if (config.alertThresholds.timeoutAdjustmentRate !== undefined) this.config.alertThresholds.timeoutAdjustmentRate = config.alertThresholds.timeoutAdjustmentRate;
        if (config.alertThresholds.errorRate !== undefined) this.config.alertThresholds.errorRate = config.alertThresholds.errorRate;
      }
      if (config.monitoringInterval !== undefined) this.config.monitoringInterval = config.monitoringInterval;
      if (config.historyRetentionTime !== undefined) this.config.historyRetentionTime = config.historyRetentionTime;
    }

    this.networkOptimizer = NetworkRequestOptimizer.getInstance();
    this.connectionPool = HTTPConnectionPool.getInstance();
    this.requestDeduplicator = RequestDeduplicator.getInstance();
    this.timeoutManager = AdaptiveTimeoutManager.getInstance();

    if (this.config.enableRealTimeMonitoring) {
      this.startRealTimeMonitoring();
    }

    Logger.info('NetworkPerformanceMonitor', `性能监控器初始化完成，配置: ${JSON.stringify(this.config)}`);
  }

  /**
   * 获取单例实例
   */
  static getInstance(config?: Partial<PerformanceMonitorConfig>): NetworkPerformanceMonitor {
    if (!NetworkPerformanceMonitor.instance) {
      NetworkPerformanceMonitor.instance = new NetworkPerformanceMonitor(config);
    }
    return NetworkPerformanceMonitor.instance;
  }

  /**
   * 启动实时监控
   */
  private startRealTimeMonitoring(): void {
    this.monitoringTimer = setInterval(() => {
      this.collectPerformanceSnapshot();
      this.checkPerformanceAlerts();
      this.cleanupOldData();
    }, this.config.monitoringInterval);

    Logger.info('NetworkPerformanceMonitor', '实时性能监控已启动');
  }

  /**
   * 收集性能快照
   */
  private collectPerformanceSnapshot(): void {
    try {
      const optimizationStats = this.networkOptimizer.getOptimizationStats();
      const poolStats = this.connectionPool.getStats();
      const deduplicationStats = this.requestDeduplicator.getStats();
      const timeoutStats = this.timeoutManager.getStats();

      const snapshot: PerformanceSnapshot = {
        timestamp: Date.now(),
        totalRequests: optimizationStats.totalRequests,
        successRate: optimizationStats.averagePerformanceGain,
        averageResponseTime: 0, // 需要从详细统计中计算
        connectionReuseRate: poolStats.connectionReuseRate,
        deduplicationRate: deduplicationStats.deduplicationRate,
        timeoutOptimizationRate: timeoutStats.timeoutAdjustments > 0 ?
          (timeoutStats.averageTimeoutReduction / timeoutStats.timeoutAdjustments) * 100 : 0,
        networkEfficiency: optimizationStats.networkEfficiencyImprovement
      };

      this.performanceHistory.push(snapshot);
      Logger.debug('NetworkPerformanceMonitor', `收集性能快照: ${JSON.stringify(snapshot)}`);

    } catch (error) {
      Logger.error('NetworkPerformanceMonitor', `收集性能快照失败: ${(error as Error).message}`);
    }
  }

  /**
   * 检查性能告警
   */
  private checkPerformanceAlerts(): void {
    if (!this.config.enablePerformanceAlerts) return;

    try {
      const poolStats = this.connectionPool.getStats();
      const deduplicationStats = this.requestDeduplicator.getStats();
      const optimizationStats = this.networkOptimizer.getOptimizationStats();

      // 检查连接池利用率
      const poolUtilization = poolStats.totalConnections > 0 ?
        (poolStats.activeConnections / poolStats.totalConnections) * 100 : 0;

      if (poolUtilization > this.config.alertThresholds.connectionPoolUtilization) {
        this.createAlert(
          'connection_pool',
          'high',
          `连接池利用率过高: ${poolUtilization.toFixed(1)}%`,
          this.config.alertThresholds.connectionPoolUtilization,
          poolUtilization
        );
      }

      // 检查去重率
      if (deduplicationStats.deduplicationRate < this.config.alertThresholds.deduplicationRate) {
        this.createAlert(
          'deduplication',
          'medium',
          `请求去重率过低: ${deduplicationStats.deduplicationRate.toFixed(1)}%`,
          this.config.alertThresholds.deduplicationRate,
          deduplicationStats.deduplicationRate
        );
      }

      // 检查错误率
      const errorRate = optimizationStats.totalRequests > 0 ?
        ((optimizationStats.totalRequests - optimizationStats.optimizedRequests) / optimizationStats.totalRequests) * 100 : 0;

      if (errorRate > this.config.alertThresholds.errorRate) {
        this.createAlert(
          'error_rate',
          'high',
          `请求错误率过高: ${errorRate.toFixed(1)}%`,
          this.config.alertThresholds.errorRate,
          errorRate
        );
      }

    } catch (error) {
      Logger.error('NetworkPerformanceMonitor', `检查性能告警失败: ${(error as Error).message}`);
    }
  }

  /**
   * 创建性能告警
   */
  private createAlert(
    type: PerformanceAlert['type'],
    severity: PerformanceAlert['severity'],
    message: string,
    threshold: number,
    currentValue: number
  ): void {
    const alertId = `${type}_${Date.now()}_${++this.alertCounter}`;

    const alert: PerformanceAlert = {
      id: alertId,
      type,
      severity,
      message,
      threshold,
      currentValue,
      timestamp: Date.now(),
      resolved: false
    };

    this.activeAlerts.set(alertId, alert);
    Logger.warn('NetworkPerformanceMonitor', `性能告警: ${message}`);
  }

  /**
   * 清理过期数据
   */
  private cleanupOldData(): void {
    const cutoffTime = Date.now() - this.config.historyRetentionTime;

    // 清理过期的性能快照
    this.performanceHistory = this.performanceHistory.filter(
      snapshot => snapshot.timestamp > cutoffTime
    );

    // 清理已解决的告警
    const resolvedAlerts = Array.from(this.activeAlerts.entries())
      .filter(([_, alert]) => alert.resolved && alert.timestamp < cutoffTime);

    resolvedAlerts.forEach(([alertId]) => {
      this.activeAlerts.delete(alertId);
    });
  }

  /**
   * 获取当前性能快照
   */
  getCurrentPerformanceSnapshot(): PerformanceSnapshot {
    this.collectPerformanceSnapshot();
    return this.performanceHistory[this.performanceHistory.length - 1] || {
      timestamp: Date.now(),
      totalRequests: 0,
      successRate: 0,
      averageResponseTime: 0,
      connectionReuseRate: 0,
      deduplicationRate: 0,
      timeoutOptimizationRate: 0,
      networkEfficiency: 0
    };
  }

  /**
   * 获取性能趋势
   */
  getPerformanceTrend(period: '1h' | '24h' | '7d'): PerformanceTrend {
    const now = Date.now();
    let timeRange: number;

    switch (period) {
      case '1h':
        timeRange = 60 * 60 * 1000;
        break;
      case '24h':
        timeRange = 24 * 60 * 60 * 1000;
        break;
      case '7d':
        timeRange = 7 * 24 * 60 * 60 * 1000;
        break;
    }

    const cutoffTime = now - timeRange;
    const snapshots = this.performanceHistory.filter(
      snapshot => snapshot.timestamp > cutoffTime
    );

    // 计算趋势汇总
    const summary = this.calculateTrendSummary(snapshots);

    return {
      period,
      snapshots,
      summary
    };
  }

  /**
   * 计算趋势汇总
   */
  private calculateTrendSummary(snapshots: PerformanceSnapshot[]) {
    if (snapshots.length === 0) {
      return {
        avgSuccessRate: 0,
        avgResponseTime: 0,
        avgConnectionReuse: 0,
        avgDeduplication: 0,
        performanceGain: 0
      };
    }

    const sum = snapshots.reduce((acc, snapshot) => ({
      successRate: acc.successRate + snapshot.successRate,
      responseTime: acc.responseTime + snapshot.averageResponseTime,
      connectionReuse: acc.connectionReuse + snapshot.connectionReuseRate,
      deduplication: acc.deduplication + snapshot.deduplicationRate,
      networkEfficiency: acc.networkEfficiency + snapshot.networkEfficiency
    }), {
      successRate: 0,
      responseTime: 0,
      connectionReuse: 0,
      deduplication: 0,
      networkEfficiency: 0
    });

    const count = snapshots.length;
    return {
      avgSuccessRate: sum.successRate / count,
      avgResponseTime: sum.responseTime / count,
      avgConnectionReuse: sum.connectionReuse / count,
      avgDeduplication: sum.deduplication / count,
      performanceGain: sum.networkEfficiency / count
    };
  }

  /**
   * 生成综合性能报告
   */
  generateComprehensiveReport(): ComprehensivePerformanceReport {
    const optimizationStats = this.networkOptimizer.getOptimizationStats();
    const poolStats = this.connectionPool.getStats();
    const deduplicationStats = this.requestDeduplicator.getStats();
    const timeoutStats = this.timeoutManager.getStats();

    // 计算整体健康状态
    const overallHealth = this.calculateOverallHealth(optimizationStats);

    // 生成关键优化列表
    const keyOptimizations = this.generateKeyOptimizations(poolStats, deduplicationStats, timeoutStats);

    // 生成推荐建议
    const recommendations = this.generateRecommendations(optimizationStats, poolStats, deduplicationStats);

    const report: ComprehensivePerformanceReport = {
      summary: {
        overallHealth,
        totalRequests: optimizationStats.totalRequests,
        successRate: optimizationStats.averagePerformanceGain,
        averagePerformanceGain: optimizationStats.networkEfficiencyImprovement,
        keyOptimizations
      },
      connectionPool: {
        totalConnections: poolStats.totalConnections,
        reuseRate: poolStats.connectionReuseRate,
        avgConnectionAge: poolStats.averageConnectionAge,
        efficiency: this.evaluateEfficiency(poolStats.connectionReuseRate)
      },
      requestDeduplication: {
        totalDuplicatesSaved: deduplicationStats.duplicateRequests,
        deduplicationRate: deduplicationStats.deduplicationRate,
        timeSaved: deduplicationStats.averageDeduplicationTime,
        efficiency: this.evaluateEfficiency(deduplicationStats.deduplicationRate)
      },
      adaptiveTimeout: {
        totalAdjustments: timeoutStats.timeoutAdjustments,
        avgTimeoutReduction: timeoutStats.averageTimeoutReduction,
        performanceImprovement: timeoutStats.performanceImprovement,
        efficiency: this.evaluateEfficiency(timeoutStats.performanceImprovement)
      },
      trends: [
        this.getPerformanceTrend('1h'),
        this.getPerformanceTrend('24h'),
        this.getPerformanceTrend('7d')
      ],
      alerts: Array.from(this.activeAlerts.values()),
      recommendations
    };

    Logger.info('NetworkPerformanceMonitor', `生成综合性能报告: 健康状态=${overallHealth}, 总请求=${optimizationStats.totalRequests}`);
    return report;
  }

  /**
   * 计算整体健康状态
   */
  private calculateOverallHealth(stats: OptimizationStats): 'excellent' | 'good' | 'fair' | 'poor' {
    const successRate = stats.averagePerformanceGain;
    const efficiency = stats.networkEfficiencyImprovement;

    if (successRate >= 95 && efficiency >= 30) return 'excellent';
    if (successRate >= 90 && efficiency >= 20) return 'good';
    if (successRate >= 80 && efficiency >= 10) return 'fair';
    return 'poor';
  }

  /**
   * 生成关键优化列表
   */
  private generateKeyOptimizations(
    poolStats: PoolStats,
    deduplicationStats: DeduplicationStats,
    timeoutStats: TimeoutStats
  ): string[] {
    const optimizations: string[] = [];

    if (poolStats.connectionReuseRate > 50) {
      optimizations.push(`连接复用率达到${poolStats.connectionReuseRate.toFixed(1)}%`);
    }

    if (deduplicationStats.deduplicationRate > 20) {
      optimizations.push(`请求去重率达到${deduplicationStats.deduplicationRate.toFixed(1)}%`);
    }

    if (timeoutStats.timeoutAdjustments > 0) {
      optimizations.push(`自适应超时优化${timeoutStats.timeoutAdjustments}次`);
    }

    if (optimizations.length === 0) {
      optimizations.push('基础网络优化正在运行');
    }

    return optimizations;
  }

  /**
   * 评估效率等级
   */
  private evaluateEfficiency(value: number): string {
    if (value >= 80) return '优秀';
    if (value >= 60) return '良好';
    if (value >= 40) return '一般';
    if (value >= 20) return '较差';
    return '差';
  }

  /**
   * 生成推荐建议
   */
  private generateRecommendations(
    optimizationStats: OptimizationStats,
    poolStats: PoolStats,
    deduplicationStats: DeduplicationStats
  ): string[] {
    const recommendations: string[] = [];

    if (poolStats.connectionReuseRate < 30) {
      recommendations.push('建议增加连接池大小以提高连接复用率');
    }

    if (deduplicationStats.deduplicationRate < 10) {
      recommendations.push('建议启用更多请求去重以减少重复网络调用');
    }

    if (optimizationStats.averagePerformanceGain < 85) {
      recommendations.push('建议检查网络连接质量和服务器响应时间');
    }

    if (optimizationStats.totalRequests < 100) {
      recommendations.push('建议增加请求量以充分发挥优化效果');
    }

    if (recommendations.length === 0) {
      recommendations.push('网络性能表现良好，继续保持当前配置');
    }

    return recommendations;
  }

  /**
   * 解决告警
   */
  resolveAlert(alertId: string): boolean {
    const alert = this.activeAlerts.get(alertId);
    if (alert) {
      alert.resolved = true;
      Logger.info('NetworkPerformanceMonitor', `告警已解决: ${alertId}`);
      return true;
    }
    return false;
  }

  /**
   * 获取活跃告警列表
   */
  getActiveAlerts(): PerformanceAlert[] {
    return Array.from(this.activeAlerts.values()).filter(alert => !alert.resolved);
  }

  /**
   * 重新配置监控器
   */
  reconfigure(newConfig: Partial<PerformanceMonitorConfig>): void {
    // 手动合并配置以符合ArkTS规范
    if (newConfig.enableRealTimeMonitoring !== undefined) this.config.enableRealTimeMonitoring = newConfig.enableRealTimeMonitoring;
    if (newConfig.enablePerformanceAlerts !== undefined) this.config.enablePerformanceAlerts = newConfig.enablePerformanceAlerts;
    if (newConfig.alertThresholds !== undefined) {
      if (newConfig.alertThresholds.connectionPoolUtilization !== undefined) this.config.alertThresholds.connectionPoolUtilization = newConfig.alertThresholds.connectionPoolUtilization;
      if (newConfig.alertThresholds.deduplicationRate !== undefined) this.config.alertThresholds.deduplicationRate = newConfig.alertThresholds.deduplicationRate;
      if (newConfig.alertThresholds.timeoutAdjustmentRate !== undefined) this.config.alertThresholds.timeoutAdjustmentRate = newConfig.alertThresholds.timeoutAdjustmentRate;
      if (newConfig.alertThresholds.errorRate !== undefined) this.config.alertThresholds.errorRate = newConfig.alertThresholds.errorRate;
    }
    if (newConfig.monitoringInterval !== undefined) this.config.monitoringInterval = newConfig.monitoringInterval;
    if (newConfig.historyRetentionTime !== undefined) this.config.historyRetentionTime = newConfig.historyRetentionTime;

    // 重启监控计时器
    if (this.monitoringTimer) {
      clearInterval(this.monitoringTimer);
    }

    if (this.config.enableRealTimeMonitoring) {
      this.startRealTimeMonitoring();
    }

    Logger.info('NetworkPerformanceMonitor', `性能监控器配置已更新: ${JSON.stringify(this.config)}`);
  }

  /**
   * 清理监控器
   */
  cleanup(): void {
    if (this.monitoringTimer) {
      clearInterval(this.monitoringTimer);
      this.monitoringTimer = undefined;
    }

    this.performanceHistory = [];
    this.activeAlerts.clear();

    Logger.info('NetworkPerformanceMonitor', '网络性能监控器已清理');
  }

  /**
   * 导出性能数据
   */
  exportPerformanceData(): Record<string, Object> {
    return {
      config: this.config,
      history: this.performanceHistory,
      alerts: Array.from(this.activeAlerts.values()),
      currentSnapshot: this.getCurrentPerformanceSnapshot(),
      comprehensiveReport: this.generateComprehensiveReport()
    };
  }
}