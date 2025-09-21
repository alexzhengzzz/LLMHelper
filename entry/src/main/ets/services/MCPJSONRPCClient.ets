import {
  JSONRPCRequest,
  JSONRPCResponse,
  JSONRPCNotification,
  JSONRPCError,
  MCPMessage,
  MCPErrorCode
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';

/**
 * JSON-RPC 2.0客户端实现
 * 处理MCP协议的JSON-RPC通信
 */
export class MCPJSONRPCClient {
  private requestId: number = 1;
  private pendingRequests: Map<string | number, PendingRequest> = new Map();
  private messageHandler: ((message: string) => void) | null = null;
  private notificationHandler: ((notification: JSONRPCNotification) => void) | null = null;

  /**
   * 设置消息发送处理器
   */
  setMessageHandler(handler: (message: string) => void): void {
    this.messageHandler = handler;
  }

  /**
   * 设置通知处理器
   */
  setNotificationHandler(handler: (notification: JSONRPCNotification) => void): void {
    this.notificationHandler = handler;
  }

  /**
   * 发送JSON-RPC请求
   */
  async request(method: string, params?: Record<string, ESObject>, timeout: number = 30000): Promise<ESObject> {
    const id = this.generateRequestId();

    const request: JSONRPCRequest = {
      jsonrpc: '2.0',
      id: id,
      method: method,
      params: params
    };

    return new Promise<ESObject>((resolve, reject) => {
      const timeoutHandle = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new Error(`Request timeout: ${method}`));
      }, timeout);

      const pendingRequest: PendingRequest = {
        resolve: resolve,
        reject: reject,
        timeout: timeoutHandle,
        method: method,
        timestamp: Date.now()
      };

      this.pendingRequests.set(id, pendingRequest);

      try {
        const message = JSON.stringify(request);
        if (this.messageHandler) {
          this.messageHandler(message);
          Logger.debug('MCPJSONRPCClient', `Sent request: ${method}`, { id: id });
        } else {
          this.pendingRequests.delete(id);
          clearTimeout(timeoutHandle);
          reject(new Error('No message handler configured'));
        }
      } catch (error) {
        this.pendingRequests.delete(id);
        clearTimeout(timeoutHandle);
        reject(error);
      }
    });
  }

  /**
   * 发送JSON-RPC通知（无需响应）
   */
  notify(method: string, params?: Record<string, ESObject>): void {
    const notification: JSONRPCNotification = {
      jsonrpc: '2.0',
      method: method,
      params: params
    };

    try {
      const message = JSON.stringify(notification);
      if (this.messageHandler) {
        this.messageHandler(message);
        Logger.debug('MCPJSONRPCClient', `Sent notification: ${method}`);
      } else {
        Logger.error('MCPJSONRPCClient', 'No message handler configured for notification');
      }
    } catch (error) {
      Logger.error('MCPJSONRPCClient', `Failed to send notification: ${method}`, error);
    }
  }

  /**
   * 处理接收到的消息
   */
  handleMessage(message: string): void {
    try {
      const parsed = JSON.parse(message);

      if (this.isJSONRPCResponse(parsed)) {
        this.handleResponse(parsed);
      } else if (this.isJSONRPCNotification(parsed)) {
        this.handleNotification(parsed);
      } else {
        Logger.warn('MCPJSONRPCClient', 'Received unknown message type', parsed);
      }
    } catch (error) {
      Logger.error('MCPJSONRPCClient', 'Failed to parse message', { message: message, error: error });
    }
  }

  /**
   * 处理JSON-RPC响应
   */
  private handleResponse(response: JSONRPCResponse): void {
    const pendingRequest = this.pendingRequests.get(response.id);
    if (!pendingRequest) {
      Logger.warn('MCPJSONRPCClient', `Received response for unknown request: ${response.id}`);
      return;
    }

    this.pendingRequests.delete(response.id);
    clearTimeout(pendingRequest.timeout);

    if (response.error) {
      const error = new MCPError(response.error.message, response.error.code, response.error.data);
      Logger.error('MCPJSONRPCClient', `Request failed: ${pendingRequest.method}`, response.error);
      pendingRequest.reject(error);
    } else {
      Logger.debug('MCPJSONRPCClient', `Request completed: ${pendingRequest.method}`, { id: response.id });
      pendingRequest.resolve(response.result || {});
    }
  }

  /**
   * 处理JSON-RPC通知
   */
  private handleNotification(notification: JSONRPCNotification): void {
    Logger.debug('MCPJSONRPCClient', `Received notification: ${notification.method}`, notification.params);

    if (this.notificationHandler) {
      this.notificationHandler(notification);
    } else {
      Logger.warn('MCPJSONRPCClient', 'No notification handler configured');
    }
  }

  /**
   * 生成请求ID
   */
  private generateRequestId(): number {
    return this.requestId++;
  }

  /**
   * 检查是否为JSON-RPC响应
   */
  private isJSONRPCResponse(obj: ESObject): obj is JSONRPCResponse {
    return obj &&
           typeof obj === 'object' &&
           obj['jsonrpc'] === '2.0' &&
           obj.hasOwnProperty('id') &&
           (obj.hasOwnProperty('result') || obj.hasOwnProperty('error'));
  }

  /**
   * 检查是否为JSON-RPC通知
   */
  private isJSONRPCNotification(obj: ESObject): obj is JSONRPCNotification {
    return obj &&
           typeof obj === 'object' &&
           obj['jsonrpc'] === '2.0' &&
           obj.hasOwnProperty('method') &&
           !obj.hasOwnProperty('id');
  }

  /**
   * 获取待处理请求数量
   */
  getPendingRequestCount(): number {
    return this.pendingRequests.size;
  }

  /**
   * 取消所有待处理请求
   */
  cancelAllRequests(): void {
    const error = new Error('Connection closed');

    for (const [id, request] of this.pendingRequests) {
      clearTimeout(request.timeout);
      request.reject(error);
    }

    this.pendingRequests.clear();
    Logger.info('MCPJSONRPCClient', 'Cancelled all pending requests');
  }

  /**
   * 取消指定请求
   */
  cancelRequest(requestId: string | number): boolean {
    const request = this.pendingRequests.get(requestId);
    if (request) {
      clearTimeout(request.timeout);
      request.reject(new Error('Request cancelled'));
      this.pendingRequests.delete(requestId);
      Logger.debug('MCPJSONRPCClient', `Cancelled request: ${requestId}`);
      return true;
    }
    return false;
  }

  /**
   * 获取请求统计信息
   */
  getStats(): JSONRPCStats {
    const now = Date.now();
    const pendingRequests: Array<RequestInfo> = [];

    for (const [id, request] of this.pendingRequests) {
      pendingRequests.push({
        id: id,
        method: request.method,
        age: now - request.timestamp
      });
    }

    return {
      pendingCount: this.pendingRequests.size,
      nextRequestId: this.requestId,
      pendingRequests: pendingRequests
    };
  }

  /**
   * 清理超时请求
   */
  cleanupTimedOutRequests(maxAge: number = 60000): number {
    const now = Date.now();
    let cleanedCount = 0;

    for (const [id, request] of this.pendingRequests) {
      if (now - request.timestamp > maxAge) {
        clearTimeout(request.timeout);
        request.reject(new Error('Request timed out during cleanup'));
        this.pendingRequests.delete(id);
        cleanedCount++;
      }
    }

    if (cleanedCount > 0) {
      Logger.info('MCPJSONRPCClient', `Cleaned up ${cleanedCount} timed out requests`);
    }

    return cleanedCount;
  }
}

/**
 * 待处理请求信息
 */
interface PendingRequest {
  resolve: (result: ESObject) => void;
  reject: (error: Error) => void;
  timeout: number;
  method: string;
  timestamp: number;
}

/**
 * 请求信息
 */
interface RequestInfo {
  id: string | number;
  method: string;
  age: number;
}

/**
 * JSON-RPC统计信息
 */
interface JSONRPCStats {
  pendingCount: number;
  nextRequestId: number;
  pendingRequests: Array<RequestInfo>;
}

/**
 * MCP错误类
 */
export class MCPError extends Error {
  code: number;
  data?: ESObject;

  constructor(message: string, code: number = MCPErrorCode.INTERNAL_ERROR, data?: ESObject) {
    super(message);
    this.name = 'MCPError';
    this.code = code;
    this.data = data;
  }

  /**
   * 创建工具执行错误
   */
  static toolExecutionError(message: string, data?: ESObject): MCPError {
    return new MCPError(message, MCPErrorCode.TOOL_EXECUTION_ERROR, data);
  }

  /**
   * 创建资源未找到错误
   */
  static resourceNotFoundError(uri: string): MCPError {
    return new MCPError(`Resource not found: ${uri}`, MCPErrorCode.RESOURCE_NOT_FOUND, { uri: uri });
  }

  /**
   * 创建无效工具错误
   */
  static invalidToolError(toolName: string): MCPError {
    return new MCPError(`Invalid tool: ${toolName}`, MCPErrorCode.INVALID_TOOL, { tool: toolName });
  }

  /**
   * 创建不支持操作错误
   */
  static unsupportedOperationError(operation: string): MCPError {
    return new MCPError(`Unsupported operation: ${operation}`, MCPErrorCode.UNSUPPORTED_OPERATION, { operation: operation });
  }
}

export default MCPJSONRPCClient;