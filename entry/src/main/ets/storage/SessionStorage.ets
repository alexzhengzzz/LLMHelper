import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Session, SessionData } from '../models/ChatModels';
import { Logger } from '../utils/Logger';

const SESSIONS_KEY = 'chat_sessions';
const CURRENT_SESSION_KEY = 'current_session_id';

/**
 * 会话存储管理器
 * 负责会话的存储、读取、管理
 */
export class SessionStorage {
  private static storage: preferences.Preferences | null = null;

  private static getStorage(): preferences.Preferences {
    if (!SessionStorage.storage) {
      try {
        const context = getContext() as common.UIAbilityContext;
        Logger.debug('SessionStorage', `正在初始化会话存储，Context: ${!!context}`);
        SessionStorage.storage = preferences.getPreferencesSync(context, { name: 'session_storage' });
        Logger.debug('SessionStorage', '会话存储初始化成功');
      } catch (e) {
        Logger.error('SessionStorage', `Failed to initialize session storage: ${e}`);
        throw Error('Session storage initialization failed');
      }
    }
    return SessionStorage.storage;
  }

  /**
   * 保存会话列表
   */
  static async saveSessions(sessions: Session[]): Promise<void> {
    try {
      Logger.info('SessionStorage', `正在保存 ${sessions.length} 个会话`);
      const storage = SessionStorage.getStorage();
      const serializableSessions = sessions.map(session => session.toObject());
      const jsonStr = JSON.stringify(serializableSessions);
      Logger.debug('SessionStorage', `会话JSON长度: ${jsonStr.length}`);
      await storage.put(SESSIONS_KEY, jsonStr);
      await storage.flush();
      Logger.info('SessionStorage', '会话保存成功');
    } catch (e) {
      Logger.error('SessionStorage', `Failed to save sessions: ${e}`);
      throw e;
    }
  }

  /**
   * 读取会话列表
   */
  static async getSessions(): Promise<Session[]> {
    try {
      Logger.debug('SessionStorage', '正在读取会话列表');
      const storage = SessionStorage.getStorage();
      const sessionsStr = await storage.get(SESSIONS_KEY, '[]');
      Logger.debug('SessionStorage', `读取到的字符串长度: ${(sessionsStr as string).length}`);

      if (!sessionsStr || sessionsStr === '[]') {
        Logger.info('SessionStorage', '没有找到会话，返回空数组');
        return [];
      }

      const parsedObjects: SessionData[] = JSON.parse(sessionsStr as string);
      const sessions: Session[] = parsedObjects.map((obj: SessionData) => Session.fromObject(obj));
      Logger.debug('SessionStorage', `解析后会话数量: ${sessions.length}`);

      return sessions;
    } catch (e) {
      Logger.error('SessionStorage', `Failed to get sessions: ${e}`);
      return [];
    }
  }

  /**
   * 添加会话
   */
  static async addSession(session: Session): Promise<void> {
    try {
      const sessions = await SessionStorage.getSessions();
      sessions.push(session);
      await SessionStorage.saveSessions(sessions);
      Logger.debug('SessionStorage', `会话添加成功: ${session.id}`);
    } catch (e) {
      Logger.error('SessionStorage', `Failed to add session: ${e}`);
      throw e;
    }
  }

  /**
   * 更新会话
   */
  static async updateSession(session: Session): Promise<void> {
    try {
      const sessions = await SessionStorage.getSessions();
      const index = sessions.findIndex(s => s.id === session.id);
      if (index !== -1) {
        sessions[index] = session;
        await SessionStorage.saveSessions(sessions);
        Logger.debug('SessionStorage', `会话更新成功: ${session.id}`);
      } else {
        Logger.warn('SessionStorage', `Session not found: ${session.id}`);
      }
    } catch (e) {
      Logger.error('SessionStorage', `Failed to update session: ${e}`);
      throw e;
    }
  }

  /**
   * 删除会话
   */
  static async deleteSession(sessionId: string): Promise<void> {
    try {
      const sessions = await SessionStorage.getSessions();
      const filteredSessions = sessions.filter(s => s.id !== sessionId);
      await SessionStorage.saveSessions(filteredSessions);
      Logger.debug('SessionStorage', `会话删除成功: ${sessionId}`);

      // 如果删除的是当前会话，清除当前会话ID
      const currentSessionId = await SessionStorage.getCurrentSessionId();
      if (currentSessionId === sessionId) {
        await SessionStorage.setCurrentSessionId('');
      }
    } catch (e) {
      Logger.error('SessionStorage', `Failed to delete session: ${e}`);
      throw e;
    }
  }

  /**
   * 根据ID获取会话
   */
  static async getSessionById(sessionId: string): Promise<Session | null> {
    try {
      const sessions = await SessionStorage.getSessions();
      return sessions.find(s => s.id === sessionId) || null;
    } catch (e) {
      Logger.error('SessionStorage', `Failed to get session by ID: ${e}`);
      return null;
    }
  }

  /**
   * 获取当前会话ID
   */
  static async getCurrentSessionId(): Promise<string> {
    try {
      const storage = SessionStorage.getStorage();
      return await storage.get(CURRENT_SESSION_KEY, '') as string;
    } catch (e) {
      Logger.error('SessionStorage', `Failed to get current session ID: ${e}`);
      return '';
    }
  }

  /**
   * 设置当前会话ID
   */
  static async setCurrentSessionId(sessionId: string): Promise<void> {
    try {
      const storage = SessionStorage.getStorage();
      await storage.put(CURRENT_SESSION_KEY, sessionId);
      await storage.flush();
      Logger.debug('SessionStorage', `当前会话ID设置成功: ${sessionId}`);
    } catch (e) {
      Logger.error('SessionStorage', `Failed to set current session ID: ${e}`);
      throw e;
    }
  }

  /**
   * 清除所有会话
   */
  static async clearSessions(): Promise<void> {
    try {
      const storage = SessionStorage.getStorage();
      await storage.delete(SESSIONS_KEY);
      await storage.flush();
      Logger.info('SessionStorage', '所有会话清除成功');
    } catch (e) {
      Logger.error('SessionStorage', `Failed to clear sessions: ${e}`);
      throw e;
    }
  }

  /**
   * 获取会话数量
   */
  static async getSessionCount(): Promise<number> {
    try {
      const sessions = await SessionStorage.getSessions();
      return sessions.length;
    } catch (e) {
      Logger.error('SessionStorage', `Failed to get session count: ${e}`);
      return 0;
    }
  }

  /**
   * 检查是否有会话
   */
  static async hasSessions(): Promise<boolean> {
    try {
      const count = await SessionStorage.getSessionCount();
      return count > 0;
    } catch (e) {
      Logger.error('SessionStorage', `Failed to check sessions: ${e}`);
      return false;
    }
  }

  /**
   * 获取最新的会话
   */
  static async getLatestSession(): Promise<Session | null> {
    try {
      const sessions = await SessionStorage.getSessions();
      if (sessions.length === 0) {
        return null;
      }
      // 按创建时间排序，返回最新的会话
      const sortedSessions = sessions.sort((a, b) => b.createdAt - a.createdAt);
      return sortedSessions[0];
    } catch (e) {
      Logger.error('SessionStorage', `Failed to get latest session: ${e}`);
      return null;
    }
  }

  /**
   * 获取当前会话
   */
  static async getCurrentSession(): Promise<Session | null> {
    try {
      const currentSessionId = await SessionStorage.getCurrentSessionId();
      if (!currentSessionId) {
        return null;
      }
      return await SessionStorage.getSessionById(currentSessionId);
    } catch (e) {
      Logger.error('SessionStorage', `Failed to get current session: ${e}`);
      return null;
    }
  }

  /**
   * 搜索会话
   */
  static async searchSessions(keyword: string): Promise<Session[]> {
    try {
      const sessions = await SessionStorage.getSessions();
      return sessions.filter(s =>
        s.title.toLowerCase().includes(keyword.toLowerCase()) ||
        (s.lastMessage && s.lastMessage.toLowerCase().includes(keyword.toLowerCase()))
      );
    } catch (e) {
      Logger.error('SessionStorage', `Failed to search sessions: ${e}`);
      return [];
    }
  }

  /**
   * 更新会话的最后消息
   */
  static async updateSessionLastMessage(sessionId: string, message: string): Promise<void> {
    try {
      const sessions = await SessionStorage.getSessions();
      const session = sessions.find(s => s.id === sessionId);
      if (session) {
        session.lastMessage = message;
        session.updatedAt = Date.now();
        await SessionStorage.saveSessions(sessions);
        Logger.debug('SessionStorage', `会话最后消息更新成功: ${sessionId}`);
      }
    } catch (e) {
      Logger.error('SessionStorage', `Failed to update session last message: ${e}`);
      throw e;
    }
  }

  /**
   * 更新会话标题
   */
  static async updateSessionTitle(sessionId: string, title: string): Promise<void> {
    try {
      const sessions = await SessionStorage.getSessions();
      const session = sessions.find(s => s.id === sessionId);
      if (session) {
        session.title = title;
        session.updatedAt = Date.now();
        await SessionStorage.saveSessions(sessions);
        Logger.debug('SessionStorage', `会话标题更新成功: ${sessionId}`);
      }
    } catch (e) {
      Logger.error('SessionStorage', `Failed to update session title: ${e}`);
      throw e;
    }
  }

  /**
   * 批量删除会话
   */
  static async batchDeleteSessions(sessionIds: string[]): Promise<void> {
    try {
      const sessions = await SessionStorage.getSessions();
      const filteredSessions = sessions.filter(s => !sessionIds.includes(s.id));
      await SessionStorage.saveSessions(filteredSessions);
      Logger.info('SessionStorage', `批量删除会话成功: ${sessionIds.length} 个`);

      // 检查是否删除了当前会话
      const currentSessionId = await SessionStorage.getCurrentSessionId();
      if (currentSessionId && sessionIds.includes(currentSessionId)) {
        await SessionStorage.setCurrentSessionId('');
      }
    } catch (e) {
      Logger.error('SessionStorage', `Failed to batch delete sessions: ${e}`);
      throw e;
    }
  }

  /**
   * 清理旧会话（保留指定数量）
   */
  static async cleanupOldSessions(keepCount: number = 50): Promise<void> {
    try {
      const sessions = await SessionStorage.getSessions();
      if (sessions.length > keepCount) {
        // 按更新时间排序，保留最新的会话
        const sortedSessions = sessions.sort((a, b) => b.updatedAt - a.updatedAt);
        const keepSessions = sortedSessions.slice(0, keepCount);
        await SessionStorage.saveSessions(keepSessions);
        Logger.info('SessionStorage', `清理旧会话完成，保留 ${keepCount} 个`);
      }
    } catch (e) {
      Logger.error('SessionStorage', `Failed to cleanup old sessions: ${e}`);
      throw e;
    }
  }

  /**
   * 备份会话数据
   */
  static async backupSessions(): Promise<string> {
    try {
      const sessions = await SessionStorage.getSessions();
      const serializableSessions = sessions.map(s => s.toObject());
      const currentSessionId = await SessionStorage.getCurrentSessionId();
      const backupData = {
        sessions: serializableSessions,
        currentSessionId: currentSessionId
      };
      return JSON.stringify(backupData);
    } catch (e) {
      Logger.error('SessionStorage', `Failed to backup sessions: ${e}`);
      throw e;
    }
  }

  /**
   * 恢复会话数据
   */
  static async restoreSessions(backupData: string): Promise<void> {
    try {
      const parsedData = JSON.parse(backupData);
      const serializableSessions: SessionData[] = parsedData.sessions || [];
      const sessions: Session[] = serializableSessions.map((obj: SessionData) => Session.fromObject(obj));
      await SessionStorage.saveSessions(sessions);

      if (parsedData.currentSessionId) {
        await SessionStorage.setCurrentSessionId(parsedData.currentSessionId);
      }

      Logger.info('SessionStorage', '会话数据恢复成功');
    } catch (e) {
      Logger.error('SessionStorage', `Failed to restore sessions: ${e}`);
      throw e;
    }
  }
}