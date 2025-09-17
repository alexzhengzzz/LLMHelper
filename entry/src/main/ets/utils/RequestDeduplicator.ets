/**
 * 请求去重器
 * 防止相同的HTTP请求重复发送，通过共享Promise来减少网络开销
 */

import { util } from '@kit.ArkTS';
import { Logger } from './Logger';

/**
 * 请求标识符
 */
interface RequestIdentifier {
  url: string;
  method: string;
  headers: Record<string, string>;
  body?: string;
}

/**
 * 待处理的请求信息
 */
interface PendingRequest<T> {
  promise: Promise<T>;
  timestamp: number;
  refCount: number;
  resolvers: Array<(value: T) => void>;
  rejectors: Array<(reason: Error) => void>;
}

/**
 * 去重器配置
 */
export interface DeduplicatorConfig {
  maxCacheTime: number;    // 最大缓存时间(ms)
  maxCacheSize: number;    // 最大缓存条目数
  enableHashing: boolean;  // 是否启用请求哈希
  hashExcludeHeaders: string[]; // 哈希时排除的请求头
}

/**
 * 去重统计信息
 */
export interface DeduplicationStats {
  totalRequests: number;
  duplicateRequests: number;
  deduplicationRate: number;
  activePendingRequests: number;
  cacheHitRate: number;
  averageDeduplicationTime: number;
}

/**
 * 待处理请求详细信息
 */
interface PendingRequestDetail {
  timestamp: string;
  refCount: number;
  age: number;
  waitingCallers: number;
}

/**
 * 哈希输入对象
 */
interface HashInput {
  url: string;
  method: string;
  headers: Record<string, string>;
  body: string;
}

/**
 * 请求去重器类
 */
export class RequestDeduplicator {
  private static instance: RequestDeduplicator;
  private pendingRequests: Map<string, PendingRequest<string>> = new Map();
  private config: DeduplicatorConfig;
  private stats: DeduplicationStats;
  private cleanupTimer?: number;

  private constructor(config?: Partial<DeduplicatorConfig>) {
    this.config = {
      maxCacheTime: 30000,  // 30秒
      maxCacheSize: 100,
      enableHashing: true,
      hashExcludeHeaders: ['user-agent', 'accept-encoding', 'connection']
    };

    // 手动合并配置以符合ArkTS规范
    if (config) {
      if (config.maxCacheTime !== undefined) this.config.maxCacheTime = config.maxCacheTime;
      if (config.maxCacheSize !== undefined) this.config.maxCacheSize = config.maxCacheSize;
      if (config.enableHashing !== undefined) this.config.enableHashing = config.enableHashing;
      if (config.hashExcludeHeaders !== undefined) this.config.hashExcludeHeaders = config.hashExcludeHeaders;
    }

    this.stats = {
      totalRequests: 0,
      duplicateRequests: 0,
      deduplicationRate: 0,
      activePendingRequests: 0,
      cacheHitRate: 0,
      averageDeduplicationTime: 0
    };

    this.startCleanupTimer();
    Logger.info('RequestDeduplicator', `请求去重器初始化完成，配置: ${JSON.stringify(this.config)}`);
  }

  /**
   * 获取单例实例
   */
  static getInstance(config?: Partial<DeduplicatorConfig>): RequestDeduplicator {
    if (!RequestDeduplicator.instance) {
      RequestDeduplicator.instance = new RequestDeduplicator(config);
    }
    return RequestDeduplicator.instance;
  }

  /**
   * 执行去重请求
   */
  async executeRequest(
    requestId: RequestIdentifier,
    requestExecutor: () => Promise<string>
  ): Promise<string> {
    const hash = this.generateRequestHash(requestId);
    this.stats.totalRequests++;

    // 检查是否有相同的待处理请求
    const existingRequest = this.pendingRequests.get(hash);
    if (existingRequest) {
      this.stats.duplicateRequests++;
      existingRequest.refCount++;

      Logger.debug('RequestDeduplicator', `发现重复请求: ${hash}, 引用计数: ${existingRequest.refCount}`);

      // 返回共享的Promise
      return new Promise<string>((resolve, reject) => {
        existingRequest.resolvers.push(resolve);
        existingRequest.rejectors.push(reject);
      });
    }

    // 创建新的待处理请求
    const resolvers: Array<(value: string) => void> = [];
    const rejectors: Array<(reason: Error) => void> = [];

    const sharedPromise = new Promise<string>((resolve, reject) => {
      resolvers.push(resolve);
      rejectors.push(reject);

      // 异步执行实际请求
      this.executeActualRequest(requestExecutor, hash, resolvers, rejectors);
    });

    const pendingRequest: PendingRequest<string> = {
      promise: sharedPromise,
      timestamp: Date.now(),
      refCount: 1,
      resolvers: resolvers,
      rejectors: rejectors
    };

    this.pendingRequests.set(hash, pendingRequest);
    this.updateStats();

    Logger.debug('RequestDeduplicator', `创建新请求: ${hash}`);
    return sharedPromise;
  }

  /**
   * 执行实际的HTTP请求
   */
  private async executeActualRequest(
    requestExecutor: () => Promise<string>,
    hash: string,
    resolvers: Array<(value: string) => void>,
    rejectors: Array<(reason: Error) => void>
  ): Promise<void> {
    const startTime = Date.now();

    try {
      Logger.debug('RequestDeduplicator', `开始执行请求: ${hash}`);
      const result = await requestExecutor();
      const endTime = Date.now();

      // 通知所有等待的调用者
      resolvers.forEach(resolve => resolve(result));

      // 清理待处理请求
      this.pendingRequests.delete(hash);
      this.updateStats();

      Logger.debug('RequestDeduplicator', `请求完成: ${hash}, 耗时: ${endTime - startTime}ms, 共享给${resolvers.length}个调用者`);

    } catch (error) {
      const endTime = Date.now();

      // 通知所有等待的调用者请求失败
      rejectors.forEach(reject => reject(error as Error));

      // 清理待处理请求
      this.pendingRequests.delete(hash);
      this.updateStats();

      Logger.debug('RequestDeduplicator', `请求失败: ${hash}, 耗时: ${endTime - startTime}ms, 错误: ${(error as Error).message}`);
    }
  }

  /**
   * 生成请求哈希
   */
  private generateRequestHash(requestId: RequestIdentifier): string {
    if (!this.config.enableHashing) {
      return `${requestId.method}_${requestId.url}`;
    }

    // 过滤请求头
    const filteredHeaders: Record<string, string> = {};
    Object.keys(requestId.headers).forEach(key => {
      const lowerKey = key.toLowerCase();
      if (!this.config.hashExcludeHeaders.includes(lowerKey)) {
        filteredHeaders[lowerKey] = requestId.headers[key];
      }
    });

    // 构建哈希输入
    const hashInput: HashInput = {
      url: requestId.url,
      method: requestId.method.toUpperCase(),
      headers: filteredHeaders,
      body: requestId.body || ''
    };

    // ArkTS不支持util.hash，直接使用简单哈希
    const inputString = JSON.stringify(hashInput);
    return this.simpleStringHash(inputString);
  }

  /**
   * 简单字符串哈希（fallback）
   */
  private simpleStringHash(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 转换为32位整数
    }
    return hash.toString(36);
  }

  /**
   * 清理过期的待处理请求
   */
  private cleanupExpiredRequests(): void {
    const now = Date.now();
    const expiredHashes: string[] = [];

    this.pendingRequests.forEach((request, hash) => {
      const age = now - request.timestamp;
      if (age > this.config.maxCacheTime) {
        expiredHashes.push(hash);
      }
    });

    expiredHashes.forEach(hash => {
      const request = this.pendingRequests.get(hash);
      if (request) {
        // 通知等待者请求超时
        const timeoutError = new Error(`请求去重超时: ${hash}`);
        request.rejectors.forEach(reject => reject(timeoutError));

        this.pendingRequests.delete(hash);
        Logger.debug('RequestDeduplicator', `清理过期请求: ${hash}`);
      }
    });

    // 如果缓存大小超过限制，清理最旧的条目
    if (this.pendingRequests.size > this.config.maxCacheSize) {
      const sortedEntries = Array.from(this.pendingRequests.entries())
        .sort((a, b) => a[1].timestamp - b[1].timestamp);

      const toRemove = sortedEntries.slice(0, this.pendingRequests.size - this.config.maxCacheSize);
      toRemove.forEach((entry) => {
        const hash = entry[0];
        const request = entry[1];
        const sizeError = new Error(`请求去重缓存已满: ${hash}`);
        request.rejectors.forEach(reject => reject(sizeError));
        this.pendingRequests.delete(hash);
      });

      Logger.debug('RequestDeduplicator', `清理缓存，移除${toRemove.length}个最旧的请求`);
    }

    this.updateStats();
  }

  /**
   * 更新统计信息
   */
  private updateStats(): void {
    this.stats.activePendingRequests = this.pendingRequests.size;

    if (this.stats.totalRequests > 0) {
      this.stats.deduplicationRate = (this.stats.duplicateRequests / this.stats.totalRequests) * 100;
      this.stats.cacheHitRate = this.stats.deduplicationRate;
    }

    // 计算平均去重时间
    let totalRefs = 0;
    this.pendingRequests.forEach(request => {
      totalRefs += request.refCount;
    });

    this.stats.averageDeduplicationTime = this.pendingRequests.size > 0 ?
      totalRefs / this.pendingRequests.size : 0;
  }

  /**
   * 启动清理定时器
   */
  private startCleanupTimer(): void {
    // 每10秒清理一次过期请求
    this.cleanupTimer = setInterval(() => {
      this.cleanupExpiredRequests();
    }, 10000);

    Logger.info('RequestDeduplicator', '请求去重器清理定时器已启动');
  }

  /**
   * 获取统计信息
   */
  getStats(): DeduplicationStats {
    this.updateStats();
    return {
      totalRequests: this.stats.totalRequests,
      duplicateRequests: this.stats.duplicateRequests,
      deduplicationRate: this.stats.deduplicationRate,
      activePendingRequests: this.stats.activePendingRequests,
      cacheHitRate: this.stats.cacheHitRate,
      averageDeduplicationTime: this.stats.averageDeduplicationTime
    };
  }

  /**
   * 获取详细的待处理请求信息
   */
  getDetailedStats(): Record<string, PendingRequestDetail> {
    const details: Record<string, PendingRequestDetail> = {};

    this.pendingRequests.forEach((request, hash) => {
      const detail: PendingRequestDetail = {
        timestamp: new Date(request.timestamp).toISOString(),
        refCount: request.refCount,
        age: Date.now() - request.timestamp,
        waitingCallers: request.resolvers.length
      };
      details[hash] = detail;
    });

    return details;
  }

  /**
   * 强制清理所有待处理请求
   */
  cleanup(): void {
    this.pendingRequests.forEach((request, hash) => {
      const cleanupError = new Error(`请求去重器清理: ${hash}`);
      request.rejectors.forEach(reject => reject(cleanupError));
    });

    this.pendingRequests.clear();

    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = undefined;
    }

    this.updateStats();
    Logger.info('RequestDeduplicator', '请求去重器已完全清理');
  }

  /**
   * 重新配置去重器
   */
  reconfigure(newConfig: Partial<DeduplicatorConfig>): void {
    // 手动合并配置以符合ArkTS规范
    if (newConfig.maxCacheTime !== undefined) this.config.maxCacheTime = newConfig.maxCacheTime;
    if (newConfig.maxCacheSize !== undefined) this.config.maxCacheSize = newConfig.maxCacheSize;
    if (newConfig.enableHashing !== undefined) this.config.enableHashing = newConfig.enableHashing;
    if (newConfig.hashExcludeHeaders !== undefined) this.config.hashExcludeHeaders = newConfig.hashExcludeHeaders;

    Logger.info('RequestDeduplicator', `请求去重器配置已更新: ${JSON.stringify(this.config)}`);
  }

  /**
   * 手动取消特定请求的去重
   */
  cancelRequest(requestId: RequestIdentifier): boolean {
    const hash = this.generateRequestHash(requestId);
    const request = this.pendingRequests.get(hash);

    if (request) {
      const cancelError = new Error(`请求被手动取消: ${hash}`);
      request.rejectors.forEach(reject => reject(cancelError));
      this.pendingRequests.delete(hash);
      this.updateStats();
      Logger.debug('RequestDeduplicator', `手动取消请求: ${hash}`);
      return true;
    }

    return false;
  }

  /**
   * 检查请求是否正在处理中
   */
  isRequestPending(requestId: RequestIdentifier): boolean {
    const hash = this.generateRequestHash(requestId);
    return this.pendingRequests.has(hash);
  }
}