import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Message } from '../models/ChatModels';
import { Logger } from '../utils/Logger';

const MESSAGES_KEY = 'chat_messages';

/**
 * 消息存储管理器
 * 负责聊天消息的存储、读取、删除等操作
 */
export class MessageStorage {
  private static storage: preferences.Preferences | null = null;

  private static getStorage(): preferences.Preferences {
    if (!MessageStorage.storage) {
      try {
        const context = getContext() as common.UIAbilityContext;
        Logger.debug('MessageStorage', `正在初始化消息存储，Context: ${!!context}`);
        MessageStorage.storage = preferences.getPreferencesSync(context, { name: 'message_storage' });
        Logger.debug('MessageStorage', '消息存储初始化成功');
      } catch (e) {
        Logger.error('MessageStorage', `Failed to initialize message storage: ${e}`);
        throw Error('Message storage initialization failed');
      }
    }
    return MessageStorage.storage;
  }

  /**
   * 保存消息列表
   */
  static async saveMessages(messages: Message[]): Promise<void> {
    try {
      Logger.info('MessageStorage', `正在保存 ${messages.length} 条消息`);
      const storage = MessageStorage.getStorage();
      const jsonStr = JSON.stringify(messages);
      Logger.debug('MessageStorage', `消息JSON长度: ${jsonStr.length}`);
      await storage.put(MESSAGES_KEY, jsonStr);
      await storage.flush();
      Logger.info('MessageStorage', '消息保存成功');
    } catch (e) {
      Logger.error('MessageStorage', `Failed to save messages: ${e}`);
      throw e;
    }
  }

  /**
   * 读取消息列表
   */
  static async getMessages(): Promise<Message[]> {
    try {
      Logger.debug('MessageStorage', '正在读取历史消息');
      const storage = MessageStorage.getStorage();
      const messagesStr = await storage.get(MESSAGES_KEY, '[]');
      Logger.debug('MessageStorage', `读取到的JSON长度: ${(messagesStr as string).length}`);
      const messages: Message[] = JSON.parse(messagesStr as string);
      Logger.debug('MessageStorage', `解析后消息数量: ${messages.length}`);
      return messages;
    } catch (e) {
      Logger.error('MessageStorage', `Failed to get messages: ${e}`);
      return [];
    }
  }

  /**
   * 清除所有消息
   */
  static async clearMessages(): Promise<void> {
    try {
      const storage = MessageStorage.getStorage();
      await storage.delete(MESSAGES_KEY);
      await storage.flush();
      Logger.info('MessageStorage', '消息清除成功');
    } catch (e) {
      Logger.error('MessageStorage', `Failed to clear messages: ${e}`);
      throw e;
    }
  }

  /**
   * 添加单条消息
   */
  static async addMessage(message: Message): Promise<void> {
    try {
      const messages = await MessageStorage.getMessages();
      messages.push(message);
      await MessageStorage.saveMessages(messages);
      Logger.debug('MessageStorage', '消息添加成功');
    } catch (e) {
      Logger.error('MessageStorage', `Failed to add message: ${e}`);
      throw e;
    }
  }

  /**
   * 更新消息
   */
  static async updateMessage(messageId: string, updates: Partial<Message>): Promise<void> {
    try {
      const messages = await MessageStorage.getMessages();
      const index = messages.findIndex(m => m.id === messageId);
      if (index !== -1) {
        messages[index] = { ...messages[index], ...updates };
        await MessageStorage.saveMessages(messages);
        Logger.debug('MessageStorage', '消息更新成功');
      } else {
        Logger.warn('MessageStorage', `Message not found: ${messageId}`);
      }
    } catch (e) {
      Logger.error('MessageStorage', `Failed to update message: ${e}`);
      throw e;
    }
  }

  /**
   * 删除单条消息
   */
  static async deleteMessage(messageId: string): Promise<void> {
    try {
      const messages = await MessageStorage.getMessages();
      const filteredMessages = messages.filter(m => m.id !== messageId);
      await MessageStorage.saveMessages(filteredMessages);
      Logger.debug('MessageStorage', '消息删除成功');
    } catch (e) {
      Logger.error('MessageStorage', `Failed to delete message: ${e}`);
      throw e;
    }
  }

  /**
   * 获取消息数量
   */
  static async getMessageCount(): Promise<number> {
    try {
      const messages = await MessageStorage.getMessages();
      return messages.length;
    } catch (e) {
      Logger.error('MessageStorage', `Failed to get message count: ${e}`);
      return 0;
    }
  }

  /**
   * 检查是否有消息
   */
  static async hasMessages(): Promise<boolean> {
    try {
      const count = await MessageStorage.getMessageCount();
      return count > 0;
    } catch (e) {
      Logger.error('MessageStorage', `Failed to check messages: ${e}`);
      return false;
    }
  }

  /**
   * 获取最新的消息
   */
  static async getLatestMessage(): Promise<Message | null> {
    try {
      const messages = await MessageStorage.getMessages();
      if (messages.length === 0) {
        return null;
      }
      return messages[messages.length - 1];
    } catch (e) {
      Logger.error('MessageStorage', `Failed to get latest message: ${e}`);
      return null;
    }
  }

  /**
   * 获取指定时间范围内的消息
   */
  static async getMessagesByTimeRange(startTime: number, endTime: number): Promise<Message[]> {
    try {
      const messages = await MessageStorage.getMessages();
      return messages.filter(m => m.timestamp >= startTime && m.timestamp <= endTime);
    } catch (e) {
      Logger.error('MessageStorage', `Failed to get messages by time range: ${e}`);
      return [];
    }
  }

  /**
   * 搜索包含关键词的消息
   */
  static async searchMessages(keyword: string): Promise<Message[]> {
    try {
      const messages = await MessageStorage.getMessages();
      return messages.filter(m =>
        m.content.toLowerCase().includes(keyword.toLowerCase()) ||
        (m.role && m.role.toLowerCase().includes(keyword.toLowerCase()))
      );
    } catch (e) {
      Logger.error('MessageStorage', `Failed to search messages: ${e}`);
      return [];
    }
  }

  /**
   * 清理旧消息（保留指定数量）
   */
  static async cleanupOldMessages(keepCount: number = 1000): Promise<void> {
    try {
      const messages = await MessageStorage.getMessages();
      if (messages.length > keepCount) {
        const keepMessages = messages.slice(messages.length - keepCount);
        await MessageStorage.saveMessages(keepMessages);
        Logger.info('MessageStorage', `清理旧消息完成，保留 ${keepCount} 条`);
      }
    } catch (e) {
      Logger.error('MessageStorage', `Failed to cleanup old messages: ${e}`);
      throw e;
    }
  }

  /**
   * 备份消息数据
   */
  static async backupMessages(): Promise<string> {
    try {
      const messages = await MessageStorage.getMessages();
      return JSON.stringify(messages);
    } catch (e) {
      Logger.error('MessageStorage', `Failed to backup messages: ${e}`);
      throw e;
    }
  }

  /**
   * 恢复消息数据
   */
  static async restoreMessages(backupData: string): Promise<void> {
    try {
      const messages = JSON.parse(backupData);
      await MessageStorage.saveMessages(messages);
      Logger.info('MessageStorage', '消息数据恢复成功');
    } catch (e) {
      Logger.error('MessageStorage', `Failed to restore messages: ${e}`);
      throw e;
    }
  }
}