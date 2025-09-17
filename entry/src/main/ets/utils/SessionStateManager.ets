import { Session, SessionData, SystemPrompt, Message } from '../models/ChatModels';
import { SessionManager } from './SessionManager';
import { MessageManager } from './MessageManager';
import { Logger } from './Logger';

/**
 * 会话状态管理器 - 专门处理会话状态相关逻辑
 */
export class SessionStateManager {
  private static instance: SessionStateManager;
  private sessionManager: SessionManager;
  private messageManager: MessageManager;

  // 会话状态缓存
  private sessionCache: Map<string, Session> = new Map();
  private currentSessionId: string | null = null;

  private constructor() {
    this.sessionManager = SessionManager.getInstance();
    this.messageManager = MessageManager.getInstance();
  }

  static getInstance(): SessionStateManager {
    if (!SessionStateManager.instance) {
      SessionStateManager.instance = new SessionStateManager();
    }
    return SessionStateManager.instance;
  }

  /**
   * 初始化会话状态管理器
   */
  async initialize(): Promise<void> {
    try {
      // 初始化会话管理器
      await this.sessionManager.initialize();

      // 加载会话缓存
      await this.loadSessionCache();

      // 设置当前会话
      const currentSession = this.sessionManager.getCurrentSession();
      if (currentSession) {
        this.currentSessionId = currentSession.id;
      }

      Logger.info('SessionStateManager', '会话状态管理器初始化完成');
    } catch (error) {
      Logger.error('SessionStateManager', `初始化失败: ${error}`);
      throw error;
    }
  }

  /**
   * 加载会话缓存
   */
  private async loadSessionCache(): Promise<void> {
    try {
      const sessions = await this.sessionManager.getAllSessions();
      this.sessionCache.clear();

      sessions.forEach(session => {
        this.sessionCache.set(session.id, session);
      });

      Logger.debug('SessionStateManager', `加载会话缓存: ${sessions.length}个会话`);
    } catch (error) {
      Logger.error('SessionStateManager', `加载会话缓存失败: ${error}`);
    }
  }

  /**
   * 获取当前会话ID
   */
  getCurrentSessionId(): string | null {
    return this.currentSessionId;
  }

  /**
   * 获取当前会话
   */
  getCurrentSession(): Session | null {
    if (!this.currentSessionId) {
      return null;
    }
    return this.sessionCache.get(this.currentSessionId) || null;
  }

  /**
   * 获取所有会话
   */
  getAllSessions(): Session[] {
    return Array.from(this.sessionCache.values()).sort((a, b) => b.lastActiveTime - a.lastActiveTime);
  }

  /**
   * 切换到指定会话
   */
  async switchToSession(sessionId: string): Promise<boolean> {
    try {
      const session = this.sessionCache.get(sessionId);
      if (!session) {
        Logger.error('SessionStateManager', `会话不存在: ${sessionId}`);
        return false;
      }

      // 更新当前会话ID
      this.currentSessionId = sessionId;

      // 通过SessionManager设置当前会话
      await this.sessionManager.switchToSession(sessionId);

      // 更新会话活跃时间
      await this.updateSessionActivity(sessionId);

      Logger.info('SessionStateManager', `切换到会话: ${sessionId}`);
      return true;
    } catch (error) {
      Logger.error('SessionStateManager', `切换会话失败: ${error}`);
      return false;
    }
  }

  /**
   * 创建新会话
   */
  async createSession(name?: string, systemPrompt?: SystemPrompt): Promise<string> {
    try {
      const sessionId = await this.sessionManager.createSession(name, systemPrompt);

      // 获取新创建的会话
      const newSession = await this.sessionManager.getSession(sessionId);
      if (newSession) {
        this.sessionCache.set(sessionId, newSession);
      }

      // 切换到新会话
      this.currentSessionId = sessionId;

      Logger.info('SessionStateManager', `创建新会话: ${sessionId}, 名称: ${name || '默认'}`);
      return sessionId;
    } catch (error) {
      Logger.error('SessionStateManager', `创建会话失败: ${error}`);
      throw error;
    }
  }

  /**
   * 删除会话
   */
  async deleteSession(sessionId: string): Promise<boolean> {
    try {
      // 从SessionManager删除
      const success = await this.sessionManager.deleteSession(sessionId);

      if (success) {
        // 从缓存中移除
        this.sessionCache.delete(sessionId);

        // 如果删除的是当前会话，切换到其他会话
        if (this.currentSessionId === sessionId) {
          const remainingSessions = this.getAllSessions();
          if (remainingSessions.length > 0) {
            await this.switchToSession(remainingSessions[0].id);
          } else {
            // 创建新的默认会话
            await this.createSession();
          }
        }

        Logger.info('SessionStateManager', `删除会话: ${sessionId}`);
      }

      return success;
    } catch (error) {
      Logger.error('SessionStateManager', `删除会话失败: ${error}`);
      return false;
    }
  }

  /**
   * 重命名会话
   */
  async renameSession(sessionId: string, newName: string): Promise<boolean> {
    try {
      const success = await this.sessionManager.renameSession(sessionId, newName);

      if (success) {
        // 更新缓存中的会话名称
        const session = this.sessionCache.get(sessionId);
        if (session) {
          session.name = newName;
          session.lastActiveTime = Date.now();
        }

        Logger.info('SessionStateManager', `重命名会话: ${sessionId} -> ${newName}`);
      }

      return success;
    } catch (error) {
      Logger.error('SessionStateManager', `重命名会话失败: ${error}`);
      return false;
    }
  }

  /**
   * 更新会话活跃时间
   */
  async updateSessionActivity(sessionId: string): Promise<void> {
    try {
      const session = this.sessionCache.get(sessionId);
      if (session) {
        session.lastActiveTime = Date.now();
        await this.sessionManager.updateSession(session);
      }
    } catch (error) {
      Logger.error('SessionStateManager', `更新会话活跃时间失败: ${error}`);
    }
  }

  /**
   * 获取会话的消息数量
   */
  getSessionMessageCount(sessionId: string, messages: Message[]): number {
    return this.messageManager.filterMessagesBySession(messages, sessionId).length;
  }

  /**
   * 获取会话的最后活跃时间
   */
  getSessionLastActivity(sessionId: string, messages: Message[]): number {
    const session = this.sessionCache.get(sessionId);
    if (!session) {
      return 0;
    }

    // 优先使用消息中的最后活跃时间
    const messageLastActivity = this.messageManager.getLastActivityTime(messages, sessionId);
    return Math.max(session.lastActiveTime, messageLastActivity);
  }

  /**
   * 检查会话是否存在
   */
  sessionExists(sessionId: string): boolean {
    return this.sessionCache.has(sessionId);
  }

  /**
   * 获取会话统计信息
   */
  getSessionStats(): {
    totalSessions: number;
    currentSessionId: string | null;
    activeSessions: number;
    oldestSessionTime: number;
    newestSessionTime: number;
  } {
    const sessions = this.getAllSessions();
    const now = Date.now();
    const oneWeekAgo = now - (7 * 24 * 60 * 60 * 1000);

    return {
      totalSessions: sessions.length,
      currentSessionId: this.currentSessionId,
      activeSessions: sessions.filter(s => s.lastActiveTime > oneWeekAgo).length,
      oldestSessionTime: sessions.length > 0 ? Math.min(...sessions.map(s => s.createdTime)) : 0,
      newestSessionTime: sessions.length > 0 ? Math.max(...sessions.map(s => s.createdTime)) : 0
    };
  }

  /**
   * 清理旧会话
   */
  async cleanupOldSessions(maxAge: number = 30 * 24 * 60 * 60 * 1000): Promise<number> {
    try {
      const now = Date.now();
      const sessions = this.getAllSessions();
      const oldSessions = sessions.filter(s => (now - s.lastActiveTime) > maxAge);

      let deletedCount = 0;
      for (const session of oldSessions) {
        if (session.id !== this.currentSessionId) { // 不删除当前会话
          const success = await this.deleteSession(session.id);
          if (success) {
            deletedCount++;
          }
        }
      }

      Logger.info('SessionStateManager', `清理旧会话: 删除了${deletedCount}个会话`);
      return deletedCount;
    } catch (error) {
      Logger.error('SessionStateManager', `清理旧会话失败: ${error}`);
      return 0;
    }
  }

  /**
   * 导出会话数据
   */
  async exportSession(sessionId: string, messages: Message[]): Promise<SessionData | null> {
    try {
      const session = this.sessionCache.get(sessionId);
      if (!session) {
        return null;
      }

      const sessionMessages = this.messageManager.filterMessagesBySession(messages, sessionId);

      return {
        ...session,
        messages: sessionMessages.map(msg => ({
          id: msg.id,
          role: msg.role,
          content: msg.content,
          timestamp: msg.timestamp,
          isLoading: msg.isLoading,
          webUsed: msg.webUsed,
          searchInfo: msg.searchInfo
        }))
      };
    } catch (error) {
      Logger.error('SessionStateManager', `导出会话失败: ${error}`);
      return null;
    }
  }

  /**
   * 搜索会话
   */
  searchSessions(keyword: string): Session[] {
    const lowerKeyword = keyword.toLowerCase();
    return this.getAllSessions().filter(session =>
      session.name.toLowerCase().includes(lowerKeyword) ||
      (session.systemPrompt && session.systemPrompt.name.toLowerCase().includes(lowerKeyword))
    );
  }

  /**
   * 获取会话的系统提示词
   */
  getSessionSystemPrompt(sessionId: string): SystemPrompt | null {
    const session = this.sessionCache.get(sessionId);
    return session?.systemPrompt || null;
  }

  /**
   * 更新会话的系统提示词
   */
  async updateSessionSystemPrompt(sessionId: string, systemPrompt: SystemPrompt | null): Promise<boolean> {
    try {
      const session = this.sessionCache.get(sessionId);
      if (!session) {
        return false;
      }

      session.systemPrompt = systemPrompt;
      session.lastActiveTime = Date.now();

      await this.sessionManager.updateSession(session);

      Logger.info('SessionStateManager', `更新会话系统提示词: ${sessionId}`);
      return true;
    } catch (error) {
      Logger.error('SessionStateManager', `更新会话系统提示词失败: ${error}`);
      return false;
    }
  }

  /**
   * 复制会话
   */
  async duplicateSession(sessionId: string, newName?: string): Promise<string | null> {
    try {
      const originalSession = this.sessionCache.get(sessionId);
      if (!originalSession) {
        return null;
      }

      const duplicatedName = newName || `${originalSession.name} (副本)`;
      const newSessionId = await this.createSession(duplicatedName, originalSession.systemPrompt);

      Logger.info('SessionStateManager', `复制会话: ${sessionId} -> ${newSessionId}`);
      return newSessionId;
    } catch (error) {
      Logger.error('SessionStateManager', `复制会话失败: ${error}`);
      return null;
    }
  }

  /**
   * 刷新会话缓存
   */
  async refreshCache(): Promise<void> {
    await this.loadSessionCache();
    Logger.info('SessionStateManager', '会话缓存已刷新');
  }

  /**
   * 清理资源
   */
  destroy(): void {
    this.sessionCache.clear();
    this.currentSessionId = null;
    Logger.info('SessionStateManager', '会话状态管理器已销毁');
  }
}