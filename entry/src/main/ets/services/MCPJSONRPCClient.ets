import {
  JSONRPCRequest,
  JSONRPCResponse,
  JSONRPCNotification,
  JSONRPCError,
  MCPMessage,
  MCPErrorCode,
  MCPMessageType,
  InitializeRequest,
  InitializeResult,
  ToolCallRequest,
  ToolCallResult,
  ResourceListRequest,
  ResourceListResult,
  ResourceReadRequest,
  ResourceReadResult,
  PromptListRequest,
  PromptListResult,
  PromptGetRequest,
  PromptGetResult,
  ParamType,
  ResultType,
  ErrorDataType
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';

/**
 * JSON-RPC 2.0客户端实现
 * 处理MCP协议的JSON-RPC通信
 */
export class MCPJSONRPCClient {
  private requestId: number = 1;
  private pendingRequests: Map<string | number, PendingRequest<ResultType>> = new Map();
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
  async request<T = ResultType>(method: string, params?: ParamType, timeout: number = 30000): Promise<T> {
    const id = this.generateRequestId();

    const request: JSONRPCRequest = {
      jsonrpc: '2.0',
      id: id,
      method: method,
      params: params
    };

    return new Promise<T>((resolve, reject) => {
      const timeoutHandle = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new Error(`Request timeout: ${method}`));
      }, timeout);

      this.pendingRequests.set(id, {
        resolve: (result: ResultType) => {
          clearTimeout(timeoutHandle);
          resolve(result as T);
        },
        reject: (error: Error) => {
          clearTimeout(timeoutHandle);
          reject(error);
        }
      });

      this.sendMessage(JSON.stringify(request));
    });
  }

  /**
   * 发送JSON-RPC通知
   */
  notify(method: string, params?: ParamType): void {
    const notification: JSONRPCNotification = {
      jsonrpc: '2.0',
      method: method,
      params: params
    };

    this.sendMessage(JSON.stringify(notification));
  }

  /**
   * 发送消息
   */
  private sendMessage(message: string): void {
    if (this.messageHandler) {
      this.messageHandler(message);
    } else {
      Logger.warn('MCPJSONRPCClient', 'No message handler set, message not sent');
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
        Logger.warn('MCPJSONRPCClient', 'Received invalid JSON-RPC message', parsed);
      }
    } catch (error) {
      Logger.error('MCPJSONRPCClient', 'Failed to parse message', error);
    }
  }

  /**
   * 处理响应
   */
  private handleResponse(response: JSONRPCResponse): void {
    const pendingRequest = this.pendingRequests.get(response.id);
    if (!pendingRequest) {
      Logger.warn('MCPJSONRPCClient', `Received response for unknown request: ${response.id}`);
      return;
    }

    this.pendingRequests.delete(response.id);

    if (response.error) {
      const error = new MCPError(
        response.error.message,
        response.error.code,
        response.error.data
      );
      pendingRequest.reject(error);
    } else if (response.result !== undefined) {
      pendingRequest.resolve(response.result);
    } else {
      pendingRequest.reject(new Error('Invalid response: no result or error'));
    }
  }

  /**
   * 处理通知
   */
  private handleNotification(notification: JSONRPCNotification): void {
    if (this.notificationHandler) {
      this.notificationHandler(notification);
    } else {
      Logger.warn('MCPJSONRPCClient', 'No notification handler set');
    }
  }

  /**
   * 检查是否为JSON-RPC响应
   */
  private isJSONRPCResponse(obj: Record<string, unknown>): obj is JSONRPCResponse {
    return obj &&
           typeof obj === 'object' &&
           obj.jsonrpc === '2.0' &&
           (typeof obj.id === 'string' || typeof obj.id === 'number' || obj.id === null) &&
           (obj.result !== undefined || obj.error !== undefined);
  }

  /**
   * 检查是否为JSON-RPC通知
   */
  private isJSONRPCNotification(obj: Record<string, unknown>): obj is JSONRPCNotification {
    return obj &&
           typeof obj === 'object' &&
           obj.jsonrpc === '2.0' &&
           obj.method &&
           obj.id === undefined;
  }

  /**
   * 生成请求ID
   */
  private generateRequestId(): number {
    return this.requestId++;
  }

  /**
   * 取消所有请求
   */
  cancelAllRequests(): void {
    for (const [id, request] of this.pendingRequests) {
      request.reject(new Error('Request cancelled'));
    }
    this.pendingRequests.clear();
  }
}

/**
 * 待处理请求接口
 */
interface PendingRequest<T> {
  resolve: (result: T) => void;
  reject: (error: Error) => void;
}

/**
 * MCP错误类
 */
export class MCPError extends Error {
  readonly code: number;
  readonly data?: ErrorDataType;

  constructor(message: string, code: number = MCPErrorCode.INTERNAL_ERROR, data?: ErrorDataType) {
    super(message);
    this.name = 'MCPError';
    this.code = code;
    this.data = data;
  }

  static toolExecutionError(message: string, data?: ErrorDataType): MCPError {
    return new MCPError(message, MCPErrorCode.TOOL_EXECUTION_ERROR, data);
  }

  static invalidToolError(message: string, data?: ErrorDataType): MCPError {
    return new MCPError(message, MCPErrorCode.INVALID_TOOL, data);
  }

  static invalidResourceError(message: string, data?: ErrorDataType): MCPError {
    return new MCPError(message, MCPErrorCode.INVALID_RESOURCE, data);
  }

  static invalidPromptError(message: string, data?: ErrorDataType): MCPError {
    return new MCPError(message, MCPErrorCode.INVALID_PROMPT, data);
  }

  static resourceNotFoundError(message: string, data?: ErrorDataType): MCPError {
    return new MCPError(message, MCPErrorCode.RESOURCE_NOT_FOUND, data);
  }

  static unsupportedOperationError(message: string, data?: ErrorDataType): MCPError {
    return new MCPError(message, MCPErrorCode.UNSUPPORTED_OPERATION, data);
  }

  toJSON(): Record<string, unknown> {
    return {
      name: this.name,
      message: this.message,
      code: this.code,
      data: this.data
    };
  }
}

export default MCPJSONRPCClient;