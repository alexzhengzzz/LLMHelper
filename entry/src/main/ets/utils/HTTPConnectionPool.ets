/**
 * HTTP连接池管理器
 * 实现HTTP连接复用、减少TCP握手开销、提升网络请求性能
 */

import { http } from '@kit.NetworkKit';
import { Logger } from './Logger';

/**
 * 连接池配置
 */
export interface ConnectionPoolConfig {
  maxConnectionsPerHost: number;  // 每个主机最大连接数
  connectionTimeout: number;      // 连接超时时间(ms)
  idleTimeout: number;           // 空闲连接超时时间(ms)
  maxRetries: number;            // 最大重试次数
  enableKeepAlive: boolean;      // 是否启用Keep-Alive
}

/**
 * 连接实例信息
 */
interface ConnectionInfo {
  httpRequest: http.HttpRequest;
  host: string;
  port: number;
  createdAt: number;
  lastUsed: number;
  inUse: boolean;
  requestCount: number;
}

/**
 * 连接池统计信息
 */
export interface PoolStats {
  totalConnections: number;
  activeConnections: number;
  idleConnections: number;
  connectionsPerHost: Map<string, number>;
  totalRequests: number;
  connectionReuseRate: number;
  averageConnectionAge: number;
}

/**
 * 连接详情信息
 */
interface ConnectionDetail {
  createdAt: string;
  lastUsed: string;
  inUse: boolean;
  requestCount: number;
  age: number;
}

/**
 * HTTP连接池类
 */
export class HTTPConnectionPool {
  private static instance: HTTPConnectionPool;
  private connections: Map<string, ConnectionInfo[]> = new Map();
  private config: ConnectionPoolConfig;
  private stats: PoolStats;
  private cleanupTimer?: number;

  private constructor(config?: Partial<ConnectionPoolConfig>) {
    this.config = {
      maxConnectionsPerHost: 6,
      connectionTimeout: 30000,
      idleTimeout: 60000,
      maxRetries: 3,
      enableKeepAlive: true
    };

    // 手动合并配置以符合ArkTS规范
    if (config) {
      if (config.maxConnectionsPerHost !== undefined) this.config.maxConnectionsPerHost = config.maxConnectionsPerHost;
      if (config.connectionTimeout !== undefined) this.config.connectionTimeout = config.connectionTimeout;
      if (config.idleTimeout !== undefined) this.config.idleTimeout = config.idleTimeout;
      if (config.maxRetries !== undefined) this.config.maxRetries = config.maxRetries;
      if (config.enableKeepAlive !== undefined) this.config.enableKeepAlive = config.enableKeepAlive;
    }

    this.stats = {
      totalConnections: 0,
      activeConnections: 0,
      idleConnections: 0,
      connectionsPerHost: new Map(),
      totalRequests: 0,
      connectionReuseRate: 0,
      averageConnectionAge: 0
    };

    this.startCleanupTimer();
    Logger.info('HTTPConnectionPool', `连接池初始化完成，配置: ${JSON.stringify(this.config)}`);
  }

  /**
   * 获取单例实例
   */
  static getInstance(config?: Partial<ConnectionPoolConfig>): HTTPConnectionPool {
    if (!HTTPConnectionPool.instance) {
      HTTPConnectionPool.instance = new HTTPConnectionPool(config);
    }
    return HTTPConnectionPool.instance;
  }

  /**
   * 获取可用的HTTP连接
   */
  async getConnection(url: string): Promise<http.HttpRequest> {
    const host = this.extractHost(url);
    const port = this.extractPort(url);
    const hostKey = `${host}:${port}`;

    try {
      // 尝试获取现有连接
      const existingConnection = this.getAvailableConnection(hostKey);
      if (existingConnection) {
        existingConnection.inUse = true;
        existingConnection.lastUsed = Date.now();
        existingConnection.requestCount++;
        this.updateStats();
        Logger.debug('HTTPConnectionPool', `复用连接: ${hostKey}, 使用次数: ${existingConnection.requestCount}`);
        return existingConnection.httpRequest;
      }

      // 创建新连接
      const newConnection = await this.createConnection(host, port, hostKey);
      this.updateStats();
      Logger.debug('HTTPConnectionPool', `创建新连接: ${hostKey}`);
      return newConnection.httpRequest;

    } catch (error) {
      Logger.error('HTTPConnectionPool', `获取连接失败: ${hostKey}, 错误: ${(error as Error).message}`);
      throw new Error((error as Error).message);
    }
  }

  /**
   * 释放连接回连接池
   */
  releaseConnection(httpRequest: http.HttpRequest, url: string): void {
    const host = this.extractHost(url);
    const port = this.extractPort(url);
    const hostKey = `${host}:${port}`;

    const connections = this.connections.get(hostKey) || [];
    const connection = connections.find(conn => conn.httpRequest === httpRequest);

    if (connection) {
      connection.inUse = false;
      connection.lastUsed = Date.now();
      this.updateStats();
      Logger.debug('HTTPConnectionPool', `释放连接: ${hostKey}, 总使用次数: ${connection.requestCount}`);
    } else {
      Logger.warn('HTTPConnectionPool', `未找到要释放的连接: ${hostKey}`);
    }
  }

  /**
   * 强制销毁连接（用于错误情况）
   */
  destroyConnection(httpRequest: http.HttpRequest, url: string): void {
    const host = this.extractHost(url);
    const port = this.extractPort(url);
    const hostKey = `${host}:${port}`;

    const connections = this.connections.get(hostKey) || [];
    const connectionIndex = connections.findIndex(conn => conn.httpRequest === httpRequest);

    if (connectionIndex !== -1) {
      const connection = connections[connectionIndex];
      try {
        connection.httpRequest.destroy();
        Logger.debug('HTTPConnectionPool', `销毁连接: ${hostKey}, 使用了${connection.requestCount}次`);
      } catch (error) {
        Logger.warn('HTTPConnectionPool', `销毁连接时出错: ${(error as Error).message}`);
      }

      connections.splice(connectionIndex, 1);
      if (connections.length === 0) {
        this.connections.delete(hostKey);
      }
      this.updateStats();
    }
  }

  /**
   * 获取可用的现有连接
   */
  private getAvailableConnection(hostKey: string): ConnectionInfo | null {
    const connections = this.connections.get(hostKey) || [];

    // 查找空闲连接
    for (const connection of connections) {
      if (!connection.inUse) {
        const now = Date.now();
        const idleTime = now - connection.lastUsed;

        // 检查连接是否还在有效期内
        if (idleTime < this.config.idleTimeout) {
          return connection;
        } else {
          // 连接已过期，标记为需要清理
          Logger.debug('HTTPConnectionPool', `连接已过期: ${hostKey}, 空闲时间: ${idleTime}ms`);
        }
      }
    }

    return null;
  }

  /**
   * 创建新连接
   */
  private async createConnection(host: string, port: number, hostKey: string): Promise<ConnectionInfo> {
    const connections = this.connections.get(hostKey) || [];

    // 检查是否达到最大连接数限制
    if (connections.length >= this.config.maxConnectionsPerHost) {
      // 尝试清理过期连接
      this.cleanupExpiredConnections(hostKey);

      // 如果还是达到限制，等待可用连接
      if (connections.length >= this.config.maxConnectionsPerHost) {
        throw new Error(`主机 ${hostKey} 连接数已达到限制: ${this.config.maxConnectionsPerHost}`);
      }
    }

    const httpRequest = http.createHttp();
    const now = Date.now();

    const connectionInfo: ConnectionInfo = {
      httpRequest: httpRequest,
      host: host,
      port: port,
      createdAt: now,
      lastUsed: now,
      inUse: true,
      requestCount: 1
    };

    connections.push(connectionInfo);
    this.connections.set(hostKey, connections);

    return connectionInfo;
  }

  /**
   * 提取主机名
   */
  private extractHost(url: string): string {
    try {
      // ArkTS不支持URL类，使用字符串解析
      if (url.startsWith('https://')) {
        const hostPart = url.substring(8).split('/')[0];
        return hostPart.split(':')[0];
      } else if (url.startsWith('http://')) {
        const hostPart = url.substring(7).split('/')[0];
        return hostPart.split(':')[0];
      }
      return 'localhost';
    } catch (error) {
      Logger.warn('HTTPConnectionPool', `解析URL主机名失败: ${url}`);
      return 'unknown';
    }
  }

  /**
   * 提取端口号
   */
  private extractPort(url: string): number {
    try {
      // ArkTS不支持URL类，使用字符串解析
      let hostPart = '';
      if (url.startsWith('https://')) {
        hostPart = url.substring(8).split('/')[0];
        const portMatch = hostPart.split(':');
        return portMatch.length > 1 ? parseInt(portMatch[1]) : 443;
      } else if (url.startsWith('http://')) {
        hostPart = url.substring(7).split('/')[0];
        const portMatch = hostPart.split(':');
        return portMatch.length > 1 ? parseInt(portMatch[1]) : 80;
      }
      return 80;
    } catch (error) {
      Logger.warn('HTTPConnectionPool', `解析URL端口失败: ${url}`);
      return 80;
    }
  }

  /**
   * 更新统计信息
   */
  private updateStats(): void {
    let totalConnections = 0;
    let activeConnections = 0;
    let totalAge = 0;
    const connectionsPerHost = new Map<string, number>();

    this.connections.forEach((connections, hostKey) => {
      connectionsPerHost.set(hostKey, connections.length);

      connections.forEach(conn => {
        totalConnections++;
        if (conn.inUse) {
          activeConnections++;
        }
        totalAge += Date.now() - conn.createdAt;
      });
    });

    this.stats.totalConnections = totalConnections;
    this.stats.activeConnections = activeConnections;
    this.stats.idleConnections = totalConnections - activeConnections;
    this.stats.connectionsPerHost = connectionsPerHost;
    this.stats.averageConnectionAge = totalConnections > 0 ? totalAge / totalConnections : 0;

    // 计算连接复用率
    let totalRequestCount = 0;
    this.connections.forEach(connections => {
      connections.forEach(conn => {
        totalRequestCount += conn.requestCount;
      });
    });

    this.stats.totalRequests = totalRequestCount;
    this.stats.connectionReuseRate = totalConnections > 0 ?
      ((totalRequestCount - totalConnections) / totalRequestCount) * 100 : 0;
  }

  /**
   * 清理过期连接
   */
  private cleanupExpiredConnections(hostKey?: string): void {
    const now = Date.now();
    const hostsToClean = hostKey ? [hostKey] : Array.from(this.connections.keys());

    hostsToClean.forEach(host => {
      const connections = this.connections.get(host) || [];
      const validConnections: ConnectionInfo[] = [];

      connections.forEach(conn => {
        const idleTime = now - conn.lastUsed;

        if (conn.inUse || idleTime < this.config.idleTimeout) {
          validConnections.push(conn);
        } else {
          try {
            conn.httpRequest.destroy();
            Logger.debug('HTTPConnectionPool', `清理过期连接: ${host}, 空闲时间: ${idleTime}ms`);
          } catch (error) {
            Logger.warn('HTTPConnectionPool', `清理连接时出错: ${(error as Error).message}`);
          }
        }
      });

      if (validConnections.length === 0) {
        this.connections.delete(host);
      } else {
        this.connections.set(host, validConnections);
      }
    });

    this.updateStats();
  }

  /**
   * 启动定时清理任务
   */
  private startCleanupTimer(): void {
    // 每30秒清理一次过期连接
    this.cleanupTimer = setInterval(() => {
      this.cleanupExpiredConnections();
    }, 30000);

    Logger.info('HTTPConnectionPool', '连接池清理定时器已启动');
  }

  /**
   * 获取连接池统计信息
   */
  getStats(): PoolStats {
    this.updateStats();
    return {
      totalConnections: this.stats.totalConnections,
      activeConnections: this.stats.activeConnections,
      idleConnections: this.stats.idleConnections,
      connectionsPerHost: this.stats.connectionsPerHost,
      totalRequests: this.stats.totalRequests,
      connectionReuseRate: this.stats.connectionReuseRate,
      averageConnectionAge: this.stats.averageConnectionAge
    };
  }

  /**
   * 获取详细的连接信息（调试用）
   */
  getDetailedStats(): Record<string, ConnectionDetail[]> {
    const details: Record<string, ConnectionDetail[]> = {};

    this.connections.forEach((connections, hostKey) => {
      details[hostKey] = connections.map(conn => {
        const detail: ConnectionDetail = {
          createdAt: new Date(conn.createdAt).toISOString(),
          lastUsed: new Date(conn.lastUsed).toISOString(),
          inUse: conn.inUse,
          requestCount: conn.requestCount,
          age: Date.now() - conn.createdAt
        };
        return detail;
      });
    });

    return details;
  }

  /**
   * 强制清理所有连接
   */
  cleanup(): void {
    this.connections.forEach((connections, hostKey) => {
      connections.forEach(conn => {
        try {
          conn.httpRequest.destroy();
        } catch (error) {
          Logger.warn('HTTPConnectionPool', `清理连接时出错: ${(error as Error).message}`);
        }
      });
    });

    this.connections.clear();

    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = undefined;
    }

    this.updateStats();
    Logger.info('HTTPConnectionPool', '连接池已完全清理');
  }

  /**
   * 重新配置连接池
   */
  reconfigure(newConfig: Partial<ConnectionPoolConfig>): void {
    // 手动合并配置以符合ArkTS规范
    if (newConfig.maxConnectionsPerHost !== undefined) this.config.maxConnectionsPerHost = newConfig.maxConnectionsPerHost;
    if (newConfig.connectionTimeout !== undefined) this.config.connectionTimeout = newConfig.connectionTimeout;
    if (newConfig.idleTimeout !== undefined) this.config.idleTimeout = newConfig.idleTimeout;
    if (newConfig.maxRetries !== undefined) this.config.maxRetries = newConfig.maxRetries;
    if (newConfig.enableKeepAlive !== undefined) this.config.enableKeepAlive = newConfig.enableKeepAlive;

    Logger.info('HTTPConnectionPool', `连接池配置已更新: ${JSON.stringify(this.config)}`);
  }
}