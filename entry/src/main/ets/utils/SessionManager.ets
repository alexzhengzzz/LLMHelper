import { Session, SessionData, Message, SystemPrompt } from '../models/ChatModels';
import { AppStorage } from './AppStorage';
import { Logger } from './Logger';

interface SessionStats {
  totalSessions: number;
  maxSessions: number;
  currentSessionId: string | null;
}

/**
 * 会话管理器 - 负责会话的创建、删除、切换等操作
 */
export class SessionManager {
  private static instance: SessionManager | null = null;
  private readonly MAX_SESSIONS = 10; // 最大会话数量限制

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): SessionManager {
    if (!SessionManager.instance) {
      SessionManager.instance = new SessionManager();
    }
    return SessionManager.instance;
  }

  /**
   * 获取所有会话列表
   */
  async getSessions(): Promise<Session[]> {
    try {
      Logger.info('SessionManager', '获取会话列表');
      const sessions = await AppStorage.getSessions();
      Logger.info('SessionManager', `获取到 ${sessions.length} 个会话`);
      return sessions.sort((a, b) => b.updatedAt - a.updatedAt); // 按更新时间倒序
    } catch (error) {
      Logger.error('SessionManager', `获取会话列表失败: ${error}`);
      return [];
    }
  }

  /**
   * 获取当前激活的会话ID
   */
  async getCurrentSessionId(): Promise<string | null> {
    try {
      return await AppStorage.getCurrentSessionId();
    } catch (error) {
      Logger.error('SessionManager', `获取当前会话ID失败: ${error}`);
      return null;
    }
  }

  /**
   * 设置当前激活的会话
   */
  async setCurrentSession(sessionId: string): Promise<void> {
    try {
      await AppStorage.setCurrentSessionId(sessionId);
      Logger.info('SessionManager', `设置当前会话: ${sessionId}`);
    } catch (error) {
      Logger.error('SessionManager', `设置当前会话失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 创建新会话（兼容旧接口，不绑定系统提示词）
   */
  async createNewSession(firstMessage?: string): Promise<Session> {
    return await this.createNewSessionWithPrompt(null, firstMessage);
  }

  /**
   * 创建新会话（绑定系统提示词）
   */
  async createNewSessionWithPrompt(systemPromptId: string | null, firstMessage?: string): Promise<Session> {
    try {
      Logger.info('SessionManager', `创建新会话，系统提示词ID: ${systemPromptId || '无'}`);
      
      // 检查会话数量限制
      const existingSessions = await this.getSessions();
      if (existingSessions.length >= this.MAX_SESSIONS) {
        Logger.warn('SessionManager', `会话数量已达上限 ${this.MAX_SESSIONS}`);
        throw Error(`会话数量已达上限 ${this.MAX_SESSIONS} 个`);
      }

      // 生成会话名称
      let sessionName: string;
      if (firstMessage && firstMessage.trim()) {
        sessionName = Session.generateSessionName(firstMessage);
      } else {
        // 如果没有首条消息，使用临时名称（后续会根据首条消息更新）
        if (systemPromptId) {
          sessionName = '新对话'; // 临时名称，首条消息后会更新为 [提示词关键词] 实际内容
        } else {
          sessionName = `新对话 ${existingSessions.length + 1}`;
        }
      }

      // 创建新会话（传入系统提示词ID）
      const session = new Session(sessionName, systemPromptId);
      Logger.info('SessionManager', `创建新会话: ${session.id} - ${session.name}, 提示词ID: ${systemPromptId || '无'}`);

      // 保存会话
      await AppStorage.saveSession(session);
      
      // 设置为当前会话
      await this.setCurrentSession(session.id);

      Logger.info('SessionManager', `新会话创建成功: ${session.id}`);
      return session;

    } catch (error) {
      Logger.error('SessionManager', `创建会话失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 通过系统提示词创建一个新会话，并返回会话ID
   */
  async createSessionFromPrompt(prompt: SystemPrompt): Promise<string> {
    try {
      Logger.info('SessionManager', `从提示词创建新会话: ${prompt.name}`);

      const existingSessions = await this.getSessions();
      if (existingSessions.length >= this.MAX_SESSIONS) {
        Logger.warn('SessionManager', `会话数量已达上限 ${this.MAX_SESSIONS}`);
        throw new Error(`会话数量已达上限 ${this.MAX_SESSIONS} 个`);
      }

      // 使用提示词名称生成会话名
      const sessionName = `与"${prompt.name}"的对话`;

      // 创建新会话并绑定系统提示词ID
      const session = new Session(sessionName, prompt.id);
      Logger.info('SessionManager', `创建新会话: ${session.id} - ${session.name}, 提示词ID: ${prompt.id}`);

      // 保存会话
      await AppStorage.saveSession(session);

      // 设置为当前会话
      await this.setCurrentSession(session.id);

      Logger.info('SessionManager', `新会话创建成功并设为当前: ${session.id}`);
      return session.id;

    } catch (error) {
      Logger.error('SessionManager', `从提示词创建会话失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 创建角色会话 - 专门为角色优化的会话创建
   */
  async createRoleSession(role: SystemPrompt, firstMessage?: string): Promise<Session> {
    try {
      Logger.info('SessionManager', `创建角色会话: ${role.name}`);

      const existingSessions = await this.getSessions();
      if (existingSessions.length >= this.MAX_SESSIONS) {
        Logger.warn('SessionManager', `会话数量已达上限 ${this.MAX_SESSIONS}`);
        throw new Error(`会话数量已达上限 ${this.MAX_SESSIONS} 个`);
      }

      // 使用角色信息生成会话名
      let sessionName: string;
      if (firstMessage && firstMessage.trim()) {
        // 如果有首条消息，使用角色名+消息内容生成会话名
        const messagePreview = firstMessage.trim().length <= 10
          ? firstMessage.trim()
          : firstMessage.trim().substring(0, 10) + '...';
        sessionName = `[${role.name.split(' ')[0]}] ${messagePreview}`;
      } else {
        // 如果没有首条消息，使用角色名生成会话名
        sessionName = `与"${role.name}"的对话`;
      }

      // 创建新会话并绑定角色ID
      const session = new Session(sessionName, role.id);
      Logger.info('SessionManager', `创建角色会话: ${session.id} - ${session.name}, 角色ID: ${role.id}`);

      // 保存会话
      await AppStorage.saveSession(session);

      // 设置为当前会话
      await this.setCurrentSession(session.id);

      Logger.info('SessionManager', `角色会话创建成功: ${session.id}`);
      return session;

    } catch (error) {
      Logger.error('SessionManager', `创建角色会话失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 获取会话绑定的角色信息
   */
  async getSessionRole(sessionId: string): Promise<SystemPrompt | null> {
    try {
      const session = (await this.getSessions()).find(s => s.id === sessionId);
      if (!session || !session.systemPromptId) {
        return null;
      }

      // 获取所有系统提示词
      const prompts = await AppStorage.getSystemPrompts();
      const role = prompts.find(p => p.id === session.systemPromptId && p.isRole);

      if (role) {
        Logger.debug('SessionManager', `获取会话角色: ${sessionId} -> ${role.name}`);
        return role;
      }

      return null;
    } catch (error) {
      Logger.error('SessionManager', `获取会话角色失败: ${error}`);
      return null;
    }
  }

  /**
   * 切换会话的角色
   */
  async switchSessionRole(sessionId: string, newRoleId: string | null): Promise<void> {
    try {
      Logger.info('SessionManager', `切换会话角色: ${sessionId} -> ${newRoleId || '无'}`);

      // 验证新角色是否存在
      if (newRoleId) {
        const prompts = await AppStorage.getSystemPrompts();
        const role = prompts.find(p => p.id === newRoleId && p.isRole);
        if (!role) {
          throw new Error('指定的角色不存在');
        }
      }

      // 更新会话的系统提示词
      await this.updateSessionPrompt(sessionId, newRoleId);

      Logger.info('SessionManager', `会话角色切换成功: ${sessionId}`);
    } catch (error) {
      Logger.error('SessionManager', `切换会话角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 获取所有使用特定角色的会话
   */
  async getSessionsByRole(roleId: string): Promise<Session[]> {
    try {
      const sessions = await this.getSessions();
      const roleSessions = sessions.filter(s => s.systemPromptId === roleId);

      Logger.debug('SessionManager', `获取角色 ${roleId} 的会话: ${roleSessions.length} 个`);
      return roleSessions;
    } catch (error) {
      Logger.error('SessionManager', `获取角色会话列表失败: ${error}`);
      return [];
    }
  }

  /**
   * 删除会话
   */
  async deleteSession(sessionId: string): Promise<void> {
    try {
      Logger.info('SessionManager', `删除会话: ${sessionId}`);

      // 获取所有会话
      const sessions = await this.getSessions();
      if (sessions.length <= 1) {
        Logger.warn('SessionManager', '不能删除最后一个会话');
        throw Error('至少需要保留一个会话');
      }

      // 检查是否是当前会话
      const currentSessionId = await this.getCurrentSessionId();
      const isCurrentSession = currentSessionId === sessionId;

      // 删除会话数据
      await AppStorage.deleteSession(sessionId);
      await AppStorage.deleteSessionMessages(sessionId);

      // 如果删除的是当前会话，切换到其他会话
      if (isCurrentSession) {
        const remainingSessions = sessions.filter(s => s.id !== sessionId);
        if (remainingSessions.length > 0) {
          await this.setCurrentSession(remainingSessions[0].id);
          Logger.info('SessionManager', `切换到会话: ${remainingSessions[0].id}`);
        }
      }

      Logger.info('SessionManager', `会话删除成功: ${sessionId}`);

    } catch (error) {
      Logger.error('SessionManager', `删除会话失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 重命名会话
   */
  async renameSession(sessionId: string, newName: string): Promise<void> {
    try {
      if (!newName.trim()) {
        throw Error('会话名称不能为空');
      }

      Logger.info('SessionManager', `重命名会话: ${sessionId} -> ${newName}`);

      // 获取会话
      const sessions = await this.getSessions();
      const session = sessions.find(s => s.id === sessionId);
      
      if (!session) {
        throw Error('会话不存在');
      }

      // 更新会话名称
      session.updateInfo(session.messageCount, newName.trim());
      
      // 保存更新
      await AppStorage.saveSession(session);

      Logger.info('SessionManager', `会话重命名成功: ${sessionId}`);

    } catch (error) {
      Logger.error('SessionManager', `重命名会话失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 更新会话的系统提示词
   */
  async updateSessionPrompt(sessionId: string, systemPromptId: string | null): Promise<void> {
    try {
      Logger.info('SessionManager', `更新会话系统提示词: ${sessionId} -> ${systemPromptId || '无'}`);

      // 获取会话
      const sessions = await this.getSessions();
      const session = sessions.find(s => s.id === sessionId);
      
      if (!session) {
        throw Error('会话不存在');
      }

      // 更新会话的系统提示词ID
      session.systemPromptId = systemPromptId;
      session.updatedAt = Date.now();
      
      // 保存更新
      await AppStorage.saveSession(session);

      Logger.info('SessionManager', `会话系统提示词更新成功: ${sessionId}`);

    } catch (error) {
      Logger.error('SessionManager', `更新会话系统提示词失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 获取会话的消息列表
   */
  async getSessionMessages(sessionId: string): Promise<Message[]> {
    try {
      const messages = await AppStorage.getSessionMessages(sessionId);
      Logger.debug('SessionManager', `获取会话消息: ${sessionId}, 数量: ${messages.length}`);
      return messages;
    } catch (error) {
      Logger.error('SessionManager', `获取会话消息失败: ${error}`);
      return [];
    }
  }

  /**
   * 保存会话消息
   */
  async saveSessionMessages(sessionId: string, messages: Message[]): Promise<void> {
    try {
      await AppStorage.saveSessionMessages(sessionId, messages);
      
      // 更新会话的消息数量和更新时间
      await this.updateSessionInfo(sessionId, messages.length);
      
      Logger.debug('SessionManager', `保存会话消息: ${sessionId}, 数量: ${messages.length}`);
    } catch (error) {
      Logger.error('SessionManager', `保存会话消息失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 更新会话信息（消息数量、更新时间等）
   */
  async updateSessionInfo(sessionId: string, messageCount?: number): Promise<void> {
    try {
      const sessions = await this.getSessions();
      const session = sessions.find(s => s.id === sessionId);
      
      if (session) {
        session.updateInfo(messageCount);
        await AppStorage.saveSession(session);
        Logger.debug('SessionManager', `更新会话信息: ${sessionId}`);
      }
    } catch (error) {
      Logger.error('SessionManager', `更新会话信息失败: ${error}`);
    }
  }

  /**
   * 检查是否需要创建默认会话
   */
  async ensureDefaultSession(): Promise<Session> {
    try {
      let sessions = await this.getSessions();
      
      // 数据迁移：为旧会话添加systemPromptId字段
      await this.migrateSessionsData(sessions);
      
      // 重新获取迁移后的会话
      sessions = await this.getSessions();
      
      if (sessions.length === 0) {
        Logger.info('SessionManager', '没有会话，创建默认会话');
        return await this.createNewSession();
      }

      // 检查是否有当前会话
      const currentSessionId = await this.getCurrentSessionId();
      if (!currentSessionId || !sessions.find(s => s.id === currentSessionId)) {
        // 设置第一个会话为当前会话
        await this.setCurrentSession(sessions[0].id);
        Logger.info('SessionManager', `设置默认当前会话: ${sessions[0].id}`);
      }

      return sessions[0];

    } catch (error) {
      Logger.error('SessionManager', `确保默认会话失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 数据迁移：为旧会话添加systemPromptId字段
   */
  private async migrateSessionsData(sessions: Session[]): Promise<void> {
    try {
      let needsMigration = false;
      
      // 检查是否需要迁移
      for (const session of sessions) {
        if (session.systemPromptId === undefined) {
          needsMigration = true;
          break;
        }
      }
      
      if (!needsMigration) {
        Logger.debug('SessionManager', '会话数据已是最新格式，无需迁移');
        return;
      }
      
      Logger.info('SessionManager', `开始迁移会话数据，共 ${sessions.length} 个会话`);
      
      // 为每个会话设置默认的systemPromptId（null表示无系统提示词）
      for (const session of sessions) {
        if (session.systemPromptId === undefined) {
          session.systemPromptId = null; // 设置为null，表示未绑定系统提示词
          await AppStorage.saveSession(session);
          Logger.debug('SessionManager', `迁移会话: ${session.id} -> systemPromptId: null`);
        }
      }
      
      Logger.info('SessionManager', '会话数据迁移完成');
      
    } catch (error) {
      Logger.error('SessionManager', `会话数据迁移失败: ${error}`);
    }
  }

  /**
   * 切换到指定会话
   */
  async switchToSession(sessionId: string): Promise<Session | null> {
    try {
      const sessions = await this.getSessions();
      const targetSession = sessions.find(s => s.id === sessionId);
      
      if (!targetSession) {
        Logger.warn('SessionManager', `会话不存在: ${sessionId}`);
        return null;
      }

      await this.setCurrentSession(sessionId);
      Logger.info('SessionManager', `切换到会话: ${sessionId} - ${targetSession.name}`);
      
      return targetSession;

    } catch (error) {
      Logger.error('SessionManager', `切换会话失败: ${error}`);
      return null;
    }
  }

  /**
   * 获取会话统计信息
   */
  async getSessionStats(): Promise<SessionStats> {
    try {
      const sessions = await this.getSessions();
      const currentSessionId = await this.getCurrentSessionId();
      
      const stats: SessionStats = {
        totalSessions: sessions.length,
        maxSessions: this.MAX_SESSIONS,
        currentSessionId: currentSessionId
      };
      return stats;
    } catch (error) {
      Logger.error('SessionManager', `获取会话统计失败: ${error}`);
      const errorStats: SessionStats = {
        totalSessions: 0,
        maxSessions: this.MAX_SESSIONS,
        currentSessionId: null
      };
      return errorStats;
    }
  }
}