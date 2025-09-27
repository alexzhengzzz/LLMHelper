import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { 
  SessionInfo, 
  WSMessageData, 
  SessionCreateData,
  SessionSwitchData,
  SessionCloseData,
  SessionListData,
  SessionCreatedData,
  SessionSwitchedData,
  TerminalInputData,
  TerminalResizeData,
  TerminalOutputData,
  AICommandData,
  AIResponseData,
  ErrorData,
  PingData,
  PongData
} from '../models/ChatModels';
import { AppConfigManager } from '../utils/AppConfigManager';
import { Logger } from '../utils/Logger';

/**
 * WebSocket消息类型
 */
export enum MessageType {
  // 连接管理
  CONNECT = 'connect',
  DISCONNECT = 'disconnect',
  PING = 'ping',
  PONG = 'pong',
  
  // 终端操作
  TERMINAL_INPUT = 'terminal_input',
  TERMINAL_OUTPUT = 'terminal_output',
  TERMINAL_RESIZE = 'terminal_resize',
  
  // 会话管理
  SESSION_CREATE = 'session_create',
  SESSION_SWITCH = 'session_switch',
  SESSION_CLOSE = 'session_close',
  SESSION_LIST = 'session_list',
  
  // 文件系统
  FILE_BROWSE = 'file_browse',
  FILE_READ = 'file_read',
  FILE_WRITE = 'file_write',
  
  // AI助手
  AI_COMMAND = 'ai_command',
  AI_RESPONSE = 'ai_response',
  
  // 错误处理
  ERROR = 'error'
}

/**
 * WebSocket消息结构
 */
export interface WSMessage {
  id: string;
  type: MessageType;
  session_id?: string;
  data?: WSMessageData;
  timestamp: number;
}


/**
 * WebSocket服务类
 */
@ObservedV2
export class WebSocketService {
  @Trace private ws?: webSocket.WebSocket;
  @Trace public connected: boolean = false;
  @Trace public connecting: boolean = false;
  @Trace public sessions: SessionInfo[] = [];
  @Trace public activeSessionId: string = '';
  
  private baseUrl: string;
  private configManager: AppConfigManager;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;
  private reconnectDelay: number = 1000;
  
  // 消息处理回调
  private messageHandlers: Map<MessageType, (data: WSMessageData) => void> = new Map();
  
  /**
   * 连接WebSocket
   */
  async connect(): Promise<void> {
    if (this.connected || this.connecting) {
      Logger.info('WebSocketService', 'WebSocket已连接或正在连接中，跳过重复连接请求');
      return;
    }
    
    // 初始化配置管理器
    if (!this.configManager) {
      this.configManager = AppConfigManager.getInstance();
      this.baseUrl = this.configManager.getServerConfig().wsUrl;
    }
    
    this.connecting = true;
    Logger.info('WebSocketService', `正在连接WebSocket: ${this.baseUrl}`);
    
    try {
      // 如果已有连接，先关闭
      if (this.ws) {
        try {
          this.ws.close();
        } catch (e) {
          Logger.warn('WebSocketService', `关闭旧连接失败: ${e}`);
        }
      }
      
      this.ws = webSocket.createWebSocket();
      
      // 先设置事件监听器
      this.setupEventListeners();
      
      // 然后连接 - 使用官方API规范（回调有两个参数）
      this.ws.connect(this.baseUrl, (err: BusinessError, value: boolean) => {
        this.connecting = false;
        if (err) {
          Logger.error('WebSocketService', `WebSocket连接回调错误: ${JSON.stringify(err)}`);
          this.scheduleReconnect();
          return;
        }
        if (value) {
          Logger.info('WebSocketService', 'WebSocket连接回调成功，等待open事件');
        } else {
          Logger.error('WebSocketService', 'WebSocket连接失败，value为false');
          this.scheduleReconnect();
        }
      });
      
    } catch (error) {
      Logger.error('WebSocketService', `WebSocket连接异常: ${error}`);
      this.connecting = false;
      this.scheduleReconnect();
    }
  }
  
  /**
   * 断开连接
   */
  disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = undefined;
    }
    this.connected = false;
    this.connecting = false;
  }
  
  /**
   * 发送消息
   */
  sendMessage(type: MessageType, data?: WSMessageData, sessionId?: string): void {
    if (!this.connected || !this.ws) {
      Logger.error('WebSocketService', 'WebSocket未连接');
      return;
    }
    
    const message: WSMessage = {
      id: this.generateId(),
      type: type,
      session_id: sessionId,
      data: data,
      timestamp: Date.now()
    };
    
    try {
      const messageStr = JSON.stringify(message);
      Logger.info('WebSocketService', `发送WebSocket消息: ${messageStr.substring(0, 100)}`);
      
      this.ws.send(messageStr, (err: BusinessError) => {
        if (err) {
          Logger.error('WebSocketService', `发送消息失败: ${JSON.stringify(err)}`);
        } else {
          Logger.info('WebSocketService', '消息发送成功');
        }
      });
    } catch (error) {
      Logger.error('WebSocketService', `发送消息异常: ${error}`);
    }
  }
  
  /**
   * 设置消息处理器
   */
  setMessageHandler(type: MessageType, handler: (data: WSMessageData) => void): void {
    this.messageHandlers.set(type, handler);
  }
  
  /**
   * 创建新会话
   */
  createSession(name?: string, workingDir?: string): void {
    const data: SessionCreateData = {
      name: name || '',
      working_dir: workingDir || ''
    };
    
    this.sendMessage(MessageType.SESSION_CREATE, data);
  }
  
  /**
   * 切换会话
   */
  switchSession(sessionId: string): void {
    const data: SessionSwitchData = {
      session_id: sessionId
    };
    
    this.sendMessage(MessageType.SESSION_SWITCH, data);
  }
  
  /**
   * 关闭会话
   */
  closeSession(sessionId: string): void {
    const data: SessionCloseData = {
      session_id: sessionId
    };
    
    this.sendMessage(MessageType.SESSION_CLOSE, data);
  }
  
  /**
   * 请求会话列表
   */
  requestSessionList(): void {
    this.sendMessage(MessageType.SESSION_LIST);
  }
  
  /**
   * 发送终端输入
   */
  sendTerminalInput(input: string): void {
    if (!this.activeSessionId) {
      Logger.error('WebSocketService', '没有活跃的会话');
      return;
    }
    
    const data: TerminalInputData = {
      input: input
    };
    
    this.sendMessage(MessageType.TERMINAL_INPUT, data, this.activeSessionId);
  }
  
  /**
   * 调整终端大小
   */
  resizeTerminal(cols: number, rows: number): void {
    if (!this.activeSessionId) {
      return;
    }
    
    const data: TerminalResizeData = {
      cols: cols,
      rows: rows
    };
    
    this.sendMessage(MessageType.TERMINAL_RESIZE, data, this.activeSessionId);
  }
  
  /**
   * 设置事件监听器
   */
  private setupEventListeners(): void {
    if (!this.ws) return;
    
    this.ws.on('open', () => {
      Logger.info('WebSocketService', 'WebSocket open事件触发');
      this.connected = true;
      this.connecting = false;
      this.reconnectAttempts = 0;
      // 延迟发送第一个消息，确保连接稳定
      setTimeout(() => {
        if (this.connected) {
          Logger.info('WebSocketService', '发送会话列表请求');
          this.requestSessionList();
        }
      }, 100);
    });
    
    this.ws.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (err) {
        Logger.error('WebSocketService', `接收消息错误: ${err}`);
        return;
      }
      
      try {
        Logger.info('WebSocketService', `收到原始WebSocket数据: ${typeof value} ${value}`);
        
        let messageStr: string;
        if (typeof value === 'string') {
          messageStr = value;
        } else if (value instanceof ArrayBuffer) {
          // 使用String.fromCharCode配合Uint8Array处理UTF-8编码的WebSocket消息
          const uint8Array = new Uint8Array(value);
          messageStr = '';
          for (let i = 0; i < uint8Array.length; i++) {
            messageStr += String.fromCharCode(uint8Array[i]);
          }
        } else {
          messageStr = String(value);
        }
        
        Logger.info('WebSocketService', `解析后的消息字符串: ${messageStr}`);
        const message: WSMessage = JSON.parse(messageStr);
        Logger.info('WebSocketService', `解析后的消息对象: ${JSON.stringify(message)}`);
        this.handleMessage(message);
      } catch (error) {
        Logger.error('WebSocketService', `解析消息失败: ${error}, 原始数据: ${value}`);
      }
    });
    
    this.ws.on('close', (err: BusinessError, code: webSocket.CloseResult) => {
      Logger.warn('WebSocketService', `WebSocket连接关闭, 错误: ${err}, 代码: ${code.code}, 原因: ${code.reason}`);
      this.connected = false;
      this.connecting = false;
      this.scheduleReconnect();
    });
    
    this.ws.on('error', (err: BusinessError) => {
      Logger.error('WebSocketService', `WebSocket错误事件: ${JSON.stringify(err)}`);
      
      // 检查错误代码，200可能不是致命错误
      if (err.code === 200) {
        Logger.warn('WebSocketService', 'WebSocket收到状态码200，可能是服务器正常响应');
        return;
      }
      
      Logger.error('WebSocketService', 'WebSocket致命错误，断开连接');
      this.connected = false;
      this.connecting = false;
    });
  }
  
  /**
   * 处理收到的消息
   */
  private handleMessage(message: WSMessage): void {
    Logger.info('WebSocketService', `收到消息: ${message.type} ${JSON.stringify(message.data)}`);
    
    switch (message.type) {
      case MessageType.PONG:
        this.handlePong(message.data);
        break;
      case MessageType.SESSION_LIST:
        this.handleSessionList(message.data);
        break;
      case MessageType.SESSION_CREATE:
        this.handleSessionCreated(message.data);
        break;
      case MessageType.SESSION_SWITCH:
        this.handleSessionSwitched(message.data);
        break;
      case MessageType.TERMINAL_OUTPUT:
        this.handleTerminalOutput(message.data);
        break;
      case MessageType.ERROR:
        this.handleError(message.data);
        break;
    }
    
    // 调用自定义处理器
    const handler = this.messageHandlers.get(message.type);
    if (handler) {
      handler(message.data || {});
    }
  }
  
  
  /**
   * 处理Pong消息
   */
  private handlePong(data?: WSMessageData): void {
    const pongData = data as PongData;
    if (pongData) {
      Logger.info('WebSocketService', `收到Pong响应: ${pongData.timestamp}`);
    }
  }
  
  /**
   * 处理会话列表
   */
  private handleSessionList(data?: WSMessageData): void {
    const sessionListData = data as SessionListData;
    if (sessionListData && sessionListData.sessions) {
      this.sessions = sessionListData.sessions;
      if (sessionListData.active_session_id) {
        this.activeSessionId = sessionListData.active_session_id;
      }
    }
  }
  
  /**
   * 处理会话创建
   */
  private handleSessionCreated(data?: WSMessageData): void {
    const sessionCreatedData = data as SessionCreatedData;
    if (sessionCreatedData && sessionCreatedData.session) {
      this.sessions.push(sessionCreatedData.session);
      this.activeSessionId = sessionCreatedData.session.id;
    }
  }
  
  /**
   * 处理会话切换
   */
  private handleSessionSwitched(data?: WSMessageData): void {
    const sessionSwitchedData = data as SessionSwitchedData;
    if (sessionSwitchedData && sessionSwitchedData.session_id) {
      this.activeSessionId = sessionSwitchedData.session_id;
    }
  }
  
  /**
   * 处理终端输出
   */
  private handleTerminalOutput(data?: WSMessageData): void {
    // 终端输出由终端组件处理
  }
  
  /**
   * 处理错误
   */
  private handleError(data?: WSMessageData): void {
    const errorData = data as ErrorData;
    if (errorData) {
      const message = errorData.message || '未知错误';
      Logger.error('WebSocketService', `服务器错误: ${JSON.stringify(message)}`);
    }
  }
  
  /**
   * 计划重连
   */
  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      Logger.error('WebSocketService', '达到最大重连次数，停止重连');
      return;
    }
    
    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);
    
    Logger.info('WebSocketService', `${delay}ms后尝试第${this.reconnectAttempts}次重连`);
    
    setTimeout(() => {
      this.connect();
    }, delay);
  }
  
  /**
   * 生成消息ID
   */
  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }
  
  /**
   * 销毁服务
   */
  destroy(): void {
    this.disconnect();
    this.messageHandlers.clear();
  }
}