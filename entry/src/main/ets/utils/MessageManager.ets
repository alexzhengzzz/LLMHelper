import { Message, MessageRole, Session } from '../models/ChatModels';
import { AppStorage } from './AppStorage';
import { Logger } from './Logger';

/**
 * 消息管理器 - 专门处理消息相关的业务逻辑
 */
export class MessageManager {
  private static instance: MessageManager;

  private constructor() {}

  static getInstance(): MessageManager {
    if (!MessageManager.instance) {
      MessageManager.instance = new MessageManager();
    }
    return MessageManager.instance;
  }

  /**
   * 创建用户消息
   */
  createUserMessage(content: string, sessionId: string): Message {
    const message: Message = {
      id: this.generateMessageId(),
      role: MessageRole.USER,
      content,
      timestamp: Date.now(),
      isLoading: false,
      sessionId
    };

    Logger.debug('MessageManager', `创建用户消息: ${content.substring(0, 50)}...`);
    return message;
  }

  /**
   * 创建助手消息
   */
  createAssistantMessage(content: string, sessionId: string): Message {
    const message: Message = {
      id: this.generateMessageId(),
      role: MessageRole.ASSISTANT,
      content,
      timestamp: Date.now(),
      isLoading: false,
      sessionId
    };

    Logger.debug('MessageManager', `创建助手消息: ${content.substring(0, 50)}...`);
    return message;
  }

  /**
   * 创建加载中的助手消息
   */
  createLoadingMessage(sessionId: string): Message {
    const message: Message = {
      id: this.generateMessageId(),
      role: MessageRole.ASSISTANT,
      content: '',
      timestamp: Date.now(),
      isLoading: true,
      sessionId
    };

    Logger.debug('MessageManager', '创建加载中消息');
    return message;
  }

  /**
   * 更新消息内容
   */
  updateMessageContent(message: Message, content: string): void {
    message.content = content;
    message.timestamp = Date.now();
    Logger.debug('MessageManager', `更新消息内容: ${message.id}`);
  }

  /**
   * 标记消息加载完成
   */
  markMessageComplete(message: Message): void {
    message.isLoading = false;
    message.timestamp = Date.now();
    Logger.debug('MessageManager', `消息加载完成: ${message.id}`);
  }

  /**
   * 为消息添加搜索信息
   */
  addSearchInfoToMessage(message: Message, searchInfo: string): void {
    message.webUsed = true;
    message.searchInfo = searchInfo;
    Logger.debug('MessageManager', `为消息添加搜索信息: ${message.id}`);
  }

  /**
   * 验证消息格式
   */
  validateMessage(message: Message): boolean {
    if (!message.id || !message.role || typeof message.content !== 'string') {
      Logger.error('MessageManager', `消息格式无效: ${JSON.stringify(message)}`);
      return false;
    }

    if (!Object.values(MessageRole).includes(message.role)) {
      Logger.error('MessageManager', `无效的消息角色: ${message.role}`);
      return false;
    }

    return true;
  }

  /**
   * 过滤会话消息
   */
  filterMessagesBySession(messages: Message[], sessionId: string): Message[] {
    const filtered = messages.filter(msg => msg.sessionId === sessionId);
    Logger.debug('MessageManager', `过滤会话消息: ${sessionId}, 结果数量: ${filtered.length}`);
    return filtered;
  }

  /**
   * 按时间排序消息
   */
  sortMessagesByTime(messages: Message[]): Message[] {
    return messages.sort((a, b) => a.timestamp - b.timestamp);
  }

  /**
   * 获取最后一条消息
   */
  getLastMessage(messages: Message[]): Message | null {
    if (messages.length === 0) {
      return null;
    }
    return messages[messages.length - 1];
  }

  /**
   * 获取最后一条用户消息
   */
  getLastUserMessage(messages: Message[]): Message | null {
    for (let i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role === MessageRole.USER) {
        return messages[i];
      }
    }
    return null;
  }

  /**
   * 获取最后一条助手消息
   */
  getLastAssistantMessage(messages: Message[]): Message | null {
    for (let i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role === MessageRole.ASSISTANT) {
        return messages[i];
      }
    }
    return null;
  }

  /**
   * 查找消息
   */
  findMessageById(messages: Message[], messageId: string): Message | null {
    const message = messages.find(msg => msg.id === messageId);
    return message || null;
  }

  /**
   * 删除消息
   */
  removeMessage(messages: Message[], messageId: string): Message[] {
    const index = messages.findIndex(msg => msg.id === messageId);
    if (index !== -1) {
      messages.splice(index, 1);
      Logger.debug('MessageManager', `删除消息: ${messageId}`);
    }
    return messages;
  }

  /**
   * 清空会话消息
   */
  clearSessionMessages(messages: Message[], sessionId: string): Message[] {
    const filteredMessages = messages.filter(msg => msg.sessionId !== sessionId);
    Logger.info('MessageManager', `清空会话消息: ${sessionId}`);
    return filteredMessages;
  }

  /**
   * 统计消息数量
   */
  getMessageStats(messages: Message[], sessionId?: string): {
    total: number;
    userMessages: number;
    assistantMessages: number;
    loadingMessages: number;
  } {
    const filteredMessages = sessionId ? this.filterMessagesBySession(messages, sessionId) : messages;

    const stats = {
      total: filteredMessages.length,
      userMessages: filteredMessages.filter(msg => msg.role === MessageRole.USER).length,
      assistantMessages: filteredMessages.filter(msg => msg.role === MessageRole.ASSISTANT && !msg.isLoading).length,
      loadingMessages: filteredMessages.filter(msg => msg.isLoading).length
    };

    Logger.debug('MessageManager', `消息统计: ${JSON.stringify(stats)}`);
    return stats;
  }

  /**
   * 检查是否有加载中的消息
   */
  hasLoadingMessage(messages: Message[], sessionId?: string): boolean {
    const filteredMessages = sessionId ? this.filterMessagesBySession(messages, sessionId) : messages;
    return filteredMessages.some(msg => msg.isLoading);
  }

  /**
   * 获取会话的最后活动时间
   */
  getLastActivityTime(messages: Message[], sessionId: string): number {
    const sessionMessages = this.filterMessagesBySession(messages, sessionId);
    if (sessionMessages.length === 0) {
      return 0;
    }
    return Math.max(...sessionMessages.map(msg => msg.timestamp));
  }

  /**
   * 压缩消息历史（保留重要消息）
   */
  compressMessageHistory(messages: Message[], maxCount: number): Message[] {
    if (messages.length <= maxCount) {
      return messages;
    }

    // 按时间排序
    const sorted = this.sortMessagesByTime([...messages]);

    // 保留最近的消息
    const compressed = sorted.slice(-maxCount);

    Logger.info('MessageManager', `压缩消息历史: ${messages.length} -> ${compressed.length}`);
    return compressed;
  }

  /**
   * 生成消息ID
   */
  private generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 将消息转换为简单格式（用于API调用）
   */
  convertToSimpleMessages(messages: Message[]): Array<{role: string, content: string}> {
    return messages
      .filter(msg => !msg.isLoading && msg.content.trim() !== '')
      .map(msg => ({
        role: msg.role === MessageRole.USER ? 'user' : 'assistant',
        content: msg.content
      }));
  }

  /**
   * 估算消息内容长度（用于token计算）
   */
  estimateTokenCount(messages: Message[]): number {
    const totalLength = messages.reduce((sum, msg) => sum + msg.content.length, 0);
    // 粗略估算：平均每4个字符对应1个token
    return Math.ceil(totalLength / 4);
  }

  /**
   * 检查消息内容是否包含敏感信息
   */
  containsSensitiveContent(message: Message): boolean {
    const sensitivePatterns = [
      /密码|password/i,
      /token|令牌/i,
      /api[_\s]*key/i,
      /secret|秘密/i
    ];

    return sensitivePatterns.some(pattern => pattern.test(message.content));
  }

  /**
   * 清理消息内容（移除敏感信息）
   */
  sanitizeMessageContent(content: string): string {
    // 简单的敏感信息清理
    return content
      .replace(/\b[A-Za-z0-9+/]{20,}\b/g, '[TOKEN_REDACTED]') // 可能的token
      .replace(/password\s*[:=]\s*\S+/gi, 'password: [REDACTED]') // 密码
      .replace(/api[_\s]*key\s*[:=]\s*\S+/gi, 'api_key: [REDACTED]'); // API密钥
  }

  /**
   * 导出消息为文本格式
   */
  exportMessagesToText(messages: Message[], sessionId?: string): string {
    const filteredMessages = sessionId ? this.filterMessagesBySession(messages, sessionId) : messages;
    const sortedMessages = this.sortMessagesByTime(filteredMessages);

    return sortedMessages
      .filter(msg => !msg.isLoading)
      .map(msg => {
        const timestamp = new Date(msg.timestamp).toLocaleString();
        const role = msg.role === MessageRole.USER ? '用户' : 'AI助手';
        return `[${timestamp}] ${role}:\n${msg.content}\n`;
      })
      .join('\n');
  }
}