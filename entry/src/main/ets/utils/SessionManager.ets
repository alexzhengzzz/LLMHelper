import { Session, Message, SystemPrompt, MultiRoleSession, SessionParticipant, SessionParticipantData, isMultiRoleSession } from '../models/ChatModels';
import { AppStorage } from './AppStorage';
import { Logger } from './Logger';

interface SessionStats {
  totalSessions: number;
  maxSessions: number;
  currentSessionId: string | null;
}

interface SessionDataQuality {
  totalSessions: number;
  totalMessages: number;
  validMessages: number;
  invalidMessages: number;
  emptyContentMessages: number;
  sessionsWithIssues: string[];
}

interface SaveSessionMessagesOptions {
  participants?: Array<SessionParticipant | SessionParticipantData>;
  name?: string;
}

interface UpdateSessionInfoOptions {
  name?: string;
  messages?: Message[];
  participants?: Array<SessionParticipant | SessionParticipantData>;
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

      // 获取系统提示词信息，判断是否为角色
      let roleId: string | undefined;
      let sessionName: string;

      if (systemPromptId) {
        const prompts = await AppStorage.getSystemPrompts();
        const prompt = prompts.find(p => p.id === systemPromptId);
        if (prompt && prompt.isRole) {
          roleId = systemPromptId; // 如果是角色，设置roleId
        }
      }

      // 生成会话名称
      if (firstMessage && firstMessage.trim()) {
        const prompt = systemPromptId ? await this.getSystemPromptById(systemPromptId) : null;
        sessionName = Session.generateSessionName(firstMessage, prompt || undefined);
      } else {
        // 如果没有首条消息，使用临时名称
        if (systemPromptId) {
          const prompt = await this.getSystemPromptById(systemPromptId);
          if (prompt && prompt.isRole) {
            sessionName = `与"${prompt.name}"的对话`;
          } else {
            sessionName = '新对话'; // 临时名称，首条消息后会更新
          }
        } else {
          sessionName = `新对话 ${existingSessions.length + 1}`;
        }
      }

      // 创建新会话（传入系统提示词ID和角色ID）
      const session = new Session(sessionName, systemPromptId, roleId);
      Logger.info('SessionManager', `创建新会话: ${session.id} - ${session.name}, 提示词ID: ${systemPromptId || '无'}, 角色ID: ${roleId || '无'}`);

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
   * 创建多人会话
   */
  async createMultiRoleSession(participantPrompts: SystemPrompt[]): Promise<MultiRoleSession> {
    try {
      Logger.info('SessionManager', `创建多人会话，参与者数量: ${participantPrompts.length}`);

      const existingSessions = await this.getSessions();
      if (existingSessions.length >= this.MAX_SESSIONS) {
        Logger.warn('SessionManager', `会话数量已达上限 ${this.MAX_SESSIONS}`);
        throw new Error(`会话数量已达上限 ${this.MAX_SESSIONS} 个`);
      }

      const participants = participantPrompts.map(prompt =>
        new SessionParticipant(prompt.id, prompt.name, prompt.roleIcon || undefined)
      );
      const normalizedParticipants = this.normalizeParticipants(participants);

      const sessionName = this.buildMultiSessionName(normalizedParticipants, existingSessions.length);
      const session = new MultiRoleSession(sessionName, normalizedParticipants, []);

      await AppStorage.saveSession(session);
      await this.setCurrentSession(session.id);

      Logger.info('SessionManager', `新多人会话创建成功: ${session.id}`);
      return session;
    } catch (error) {
      Logger.error('SessionManager', `创建多人会话失败: ${error}`);
      throw error as Error;
    }
  }

  private buildMultiSessionName(participants: SessionParticipant[], existingCount: number): string {
    const baseName = `多人会话 ${existingCount + 1}`;
    if (!participants || participants.length === 0) {
      return baseName;
    }

    const previewNames = participants.slice(0, 2).map(participant => participant.displayName).join(', ');
    const hasMore = participants.length > 2;
    return `${baseName} (${previewNames}${hasMore ? '...' : ''})`;
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

      // 创建新会话并绑定角色ID（同时设置systemPromptId和roleId）
      const session = new Session(sessionName, role.id, role.id);
      Logger.info('SessionManager', `创建角色会话: ${session.id} - ${session.name}, systemPromptId: ${role.id}, roleId: ${role.id}`);

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
   * 根据ID获取系统提示词
   */
  private async getSystemPromptById(promptId: string): Promise<SystemPrompt | null> {
    try {
      const prompts = await AppStorage.getSystemPrompts();
      const prompt = prompts.find(p => p.id === promptId);
      return prompt || null;
    } catch (error) {
      Logger.error('SessionManager', `获取系统提示词失败: ${error}`);
      return null;
    }
  }

  /**
   * 获取会话绑定的角色信息
   */
  async getSessionRole(sessionId: string): Promise<SystemPrompt | null> {
    try {
      const session = (await this.getSessions()).find(s => s.id === sessionId);
      if (!session) {
        return null;
      }

      // 优先使用roleId，如果没有则使用systemPromptId
      const roleId = session.roleId || session.systemPromptId;
      if (!roleId) {
        return null;
      }

      // 获取所有系统提示词
      const prompts = await AppStorage.getSystemPrompts();
      const role = prompts.find(p => p.id === roleId && p.isRole);

      if (role) {
        Logger.debug('SessionManager', `获取会话角色: ${sessionId} -> ${role.name} (使用${session.roleId ? 'roleId' : 'systemPromptId'})`);
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

      // 获取会话
      const sessions = await this.getSessions();
      const session = sessions.find(s => s.id === sessionId);

      if (!session) {
        throw Error('会话不存在');
      }

      // 更新会话的系统提示词ID和角色ID
      session.systemPromptId = newRoleId;
      session.roleId = newRoleId || undefined; // 如果为null则设置为undefined
      session.updatedAt = Date.now();

      // 保存更新
      await AppStorage.saveSession(session);

      Logger.info('SessionManager', `会话角色切换成功: ${sessionId} (systemPromptId: ${newRoleId}, roleId: ${session.roleId || '无'})`);
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
      // 同时检查roleId和systemPromptId，确保兼容性
      const roleSessions = sessions.filter(s => s.roleId === roleId || s.systemPromptId === roleId);

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
  async saveSessionMessages(
    sessionId: string,
    messages: Message[],
    options?: SaveSessionMessagesOptions
  ): Promise<void> {
    try {
      await AppStorage.saveSessionMessages(sessionId, messages);

      // 更新会话的消息数量、更新时间及参与者快照
      const updateOptions: UpdateSessionInfoOptions = {
        messages,
        participants: options?.participants,
        name: options?.name
      };
      await this.updateSessionInfo(sessionId, messages.length, updateOptions);

      Logger.debug('SessionManager', `保存会话消息: ${sessionId}, 数量: ${messages.length}`);
    } catch (error) {
      Logger.error('SessionManager', `保存会话消息失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 更新会话信息（消息数量、更新时间等）
   */
  async updateSessionInfo(
    sessionId: string,
    messageCount?: number,
    options?: UpdateSessionInfoOptions
  ): Promise<void> {
    try {
      const sessions = await this.getSessions();
      const session = sessions.find(s => s.id === sessionId);

      if (session) {
        const nextMessageCount = messageCount ?? options?.messages?.length ?? session.messageCount;
        const nextName = options?.name ?? session.name;

        session.updateInfo(nextMessageCount, nextName);

        if (isMultiRoleSession(session)) {
          const multiSession = session as MultiRoleSession;
          const snapshotMessages = options?.messages;

          if (snapshotMessages) {
            multiSession.messages = snapshotMessages.map(message => Message.fromObject(message.toObject()));
          }

          if (options?.participants !== undefined) {
            multiSession.participants = this.normalizeParticipants(options.participants);
          } else if (snapshotMessages) {
            multiSession.participants = this.buildParticipantSnapshot(snapshotMessages, multiSession.participants);
          }
        }

        await AppStorage.saveSession(session);
        Logger.debug('SessionManager', `更新会话信息: ${sessionId}`);
      }
    } catch (error) {
      Logger.error('SessionManager', `更新会话信息失败: ${error}`);
    }
  }

  private normalizeParticipants(participants: Array<SessionParticipant | SessionParticipantData>): SessionParticipant[] {
    return participants
      .filter(participant => participant !== undefined && participant !== null)
      .map(participant => {
      if (participant instanceof SessionParticipant) {
        return SessionParticipant.fromObject(participant.toObject());
      }
      return SessionParticipant.fromObject(participant);
    });
  }

  private buildParticipantSnapshot(
    messages: Message[],
    existingParticipants: Array<SessionParticipant | SessionParticipantData> = []
  ): SessionParticipant[] {
    const participantsMap = new Map<string, SessionParticipant>();

    this.normalizeParticipants(existingParticipants).forEach(existing => {
      if (!existing.roleId) {
        return;
      }
      participantsMap.set(existing.roleId, existing);
    });

    messages.forEach(message => {
      const roleKey = message.senderRoleId || message.role;
      if (!roleKey) {
        return;
      }

      const existing = participantsMap.get(roleKey);
      const displayName = message.senderName || existing?.displayName || roleKey;
      const avatar = message.senderAvatar !== undefined ? message.senderAvatar : existing?.avatar;
      const model = existing?.model;

      if (existing) {
        existing.displayName = displayName;
        existing.avatar = avatar;
      } else {
        participantsMap.set(roleKey, new SessionParticipant(roleKey, displayName, avatar, model));
      }
    });

    return Array.from(participantsMap.values());
  }

  /**
   * 构建多人会话快照（包含参与者和消息）
   */
  async getMultiRoleSession(sessionId: string): Promise<MultiRoleSession | null> {
    try {
      const sessions = await this.getSessions();
      const baseSession = sessions.find(s => s.id === sessionId);

      if (!baseSession) {
        Logger.warn('SessionManager', `未找到会话用于生成多人会话快照: ${sessionId}`);
        return null;
      }

      const messages = await this.getSessionMessages(sessionId);
      const participants = this.buildParticipantSnapshot(
        messages,
        isMultiRoleSession(baseSession) ? (baseSession as MultiRoleSession).participants : []
      );

      const multiSession = new MultiRoleSession(
        baseSession.name,
        participants,
        messages,
        baseSession.systemPromptId,
        baseSession.roleId,
        baseSession.id
      );
      multiSession.createdAt = baseSession.createdAt;
      multiSession.updatedAt = baseSession.updatedAt;
      multiSession.messageCount = messages.length;

      return multiSession;
    } catch (error) {
      Logger.error('SessionManager', `获取多人会话失败: ${error}`);
      return null;
    }
  }

  /**
   * 保存多人会话（同步消息与参与者快照）
   */
  async saveMultiRoleSession(session: MultiRoleSession): Promise<void> {
    try {
      const messages = session.messages || [];
      const participants = session.participants || [];

      const saveOptions: SaveSessionMessagesOptions = {
        participants,
        name: session.name
      };
      await this.saveSessionMessages(session.id, messages, saveOptions);

      Logger.info('SessionManager', `保存多人会话成功: ${session.id}`);
    } catch (error) {
      Logger.error('SessionManager', `保存多人会话失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 获取会话参与者列表
   */
  async getSessionParticipants(sessionId: string): Promise<SessionParticipant[]> {
    try {
      const sessions = await this.getSessions();
      const session = sessions.find(s => s.id === sessionId);

      if (!session) {
        Logger.warn('SessionManager', `未找到会话参与者: ${sessionId}`);
        return [];
      }

      if (isMultiRoleSession(session)) {
        return this.normalizeParticipants((session as MultiRoleSession).participants);
      }

      const messages = await this.getSessionMessages(sessionId);
      return this.buildParticipantSnapshot(messages);
    } catch (error) {
      Logger.error('SessionManager', `获取会话参与者失败: ${error}`);
      return [];
    }
  }

  /**
   * 更新会话参与者信息（不触发消息变更）
   */
  async updateSessionParticipants(
    sessionId: string,
    participants: Array<SessionParticipant | SessionParticipantData>
  ): Promise<void> {
    try {
      const updateOptions: UpdateSessionInfoOptions = { participants };
      await this.updateSessionInfo(sessionId, undefined, updateOptions);
      Logger.debug('SessionManager', `更新会话参与者: ${sessionId}, 数量: ${participants.length}`);
    } catch (error) {
      Logger.error('SessionManager', `更新会话参与者失败: ${error}`);
      throw error as Error;
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
   * 数据迁移：为旧会话添加systemPromptId和roleId字段
   */
  private async migrateSessionsData(sessions: Session[]): Promise<void> {
    try {
      let needsMigration = false;

      // 检查是否需要迁移
      for (const session of sessions) {
        if (session.systemPromptId === undefined || session.roleId === undefined) {
          needsMigration = true;
          break;
        }
      }

      if (!needsMigration) {
        Logger.debug('SessionManager', '会话数据已是最新格式，无需迁移');
        return;
      }

      Logger.info('SessionManager', `开始迁移会话数据，共 ${sessions.length} 个会话`);

      // 为每个会话设置默认字段
      for (const session of sessions) {
        let migrated = false;

        // 迁移systemPromptId
        if (session.systemPromptId === undefined) {
          session.systemPromptId = null;
          migrated = true;
        }

        // 迁移roleId - 如果有systemPromptId且对应的提示词是角色，则设置roleId
        if (session.roleId === undefined && session.systemPromptId) {
          const prompts = await AppStorage.getSystemPrompts();
          const prompt = prompts.find(p => p.id === session.systemPromptId);
          if (prompt && prompt.isRole) {
            session.roleId = session.systemPromptId; // 设置roleId为角色ID
          } else {
            session.roleId = undefined; // 非角色会话不设置roleId
          }
          migrated = true;
        } else if (session.roleId === undefined) {
          session.roleId = undefined; // 明确设置为undefined
          migrated = true;
        }

        if (migrated) {
          await AppStorage.saveSession(session);
          Logger.debug('SessionManager', `迁移会话: ${session.id} -> systemPromptId: ${session.systemPromptId}, roleId: ${session.roleId || '无'}`);
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
   * 搜索会话 - 根据关键词搜索会话标题和消息内容
   */
  async searchSessions(query: string): Promise<Session[]> {
    try {
      Logger.info('SessionManager', `searchSessions被调用，原始查询: "${query}"`);

      if (!query || !query.trim()) {
        // 如果搜索词为空，返回所有会话
        Logger.info('SessionManager', '搜索词为空，返回所有会话');
        return await this.getSessions();
      }

      const lowerCaseQuery = query.toLowerCase().trim();
      Logger.info('SessionManager', `搜索会话，关键词: "${lowerCaseQuery}"`);

      // 获取所有会话
      const allSessions = await this.getSessions();
      Logger.info('SessionManager', `总共有 ${allSessions.length} 个会话`);

      if (allSessions.length === 0) {
        Logger.warn('SessionManager', '没有找到任何会话');
        return [];
      }

      const matchedSessions: Session[] = [];
      let totalMessagesChecked = 0;
      let validMessagesFound = 0;
      let invalidMessagesFound = 0;

      // 遍历每个会话进行检查
      for (let i = 0; i < allSessions.length; i++) {
        const session = allSessions[i];
        Logger.debug('SessionManager', `检查会话 ${i + 1}/${allSessions.length}: ${session.name} (ID: ${session.id})`);

        // 1. 检查会话标题
        const sessionNameLower = session.name.toLowerCase();
        const titleMatch = sessionNameLower.includes(lowerCaseQuery);

        if (titleMatch) {
          Logger.info('SessionManager', `✅ 会话标题匹配: "${session.name}"`);
          matchedSessions.push(session);
          continue; // 匹配到标题，无需检查消息内容
        }

        // 2. 检查会话内的消息内容
        try {
          const messages = await this.getSessionMessages(session.id);
          Logger.debug('SessionManager', `会话 ${session.id} 有 ${messages.length} 条消息`);
          totalMessagesChecked += messages.length;

          let messageMatchFound = false;
          let sessionValidMessages = 0;
          let sessionInvalidMessages = 0;

          for (let j = 0; j < messages.length && !messageMatchFound; j++) {
            const message = messages[j];

            // 验证消息数据完整性
            if (!message.content) {
              sessionInvalidMessages++;
              invalidMessagesFound++;
              Logger.warn('SessionManager', `会话 ${session.id} 消息 ${j} content为空: ${message.id}`);
              continue;
            }

            if (typeof message.content !== 'string') {
              sessionInvalidMessages++;
              invalidMessagesFound++;
              Logger.warn('SessionManager', `会话 ${session.id} 消息 ${j} content类型错误: ${typeof message.content}`);
              continue;
            }

            const trimmedContent = message.content.trim();
            if (!trimmedContent) {
              sessionInvalidMessages++;
              invalidMessagesFound++;
              Logger.debug('SessionManager', `会话 ${session.id} 消息 ${j} content为空字符串`);
              continue;
            }

            sessionValidMessages++;
            validMessagesFound++;

            // 执行内容搜索
            const messageContentLower = trimmedContent.toLowerCase();
            const contentMatch = messageContentLower.includes(lowerCaseQuery);

            if (contentMatch) {
              Logger.info('SessionManager', `✅ 消息内容匹配: 会话="${session.name}", 消息="${trimmedContent.substring(0, 50)}..."`);
              matchedSessions.push(session);
              messageMatchFound = true;
            }
          }

          if (sessionInvalidMessages > 0) {
            Logger.warn('SessionManager', `会话 ${session.id} 有 ${sessionInvalidMessages} 条无效消息，${sessionValidMessages} 条有效消息`);
          }

        } catch (error) {
          Logger.error('SessionManager', `获取会话 ${session.id} 的消息失败，跳过消息内容搜索: ${error}`);
        }
      }

      // 输出搜索统计信息
      Logger.info('SessionManager', `📊 搜索统计:`);
      Logger.info('SessionManager', `  - 搜索关键词: "${lowerCaseQuery}"`);
      Logger.info('SessionManager', `  - 检查会话数: ${allSessions.length}`);
      Logger.info('SessionManager', `  - 检查消息数: ${totalMessagesChecked}`);
      Logger.info('SessionManager', `  - 有效消息数: ${validMessagesFound}`);
      Logger.info('SessionManager', `  - 无效消息数: ${invalidMessagesFound}`);
      Logger.info('SessionManager', `  - 匹配会话数: ${matchedSessions.length}`);

      if (invalidMessagesFound > 0) {
        Logger.warn('SessionManager', `⚠️ 发现 ${invalidMessagesFound} 条无效消息，建议运行数据修复`);
      }

      Logger.info('SessionManager', `🎉 搜索完成，找到 ${matchedSessions.length} 个匹配会话`);
      return matchedSessions;

    } catch (error) {
      Logger.error('SessionManager', `搜索会话失败: ${error}`);
      return [];
    }
  }

  /**
   * 修复所有会话的消息数据
   */
  async repairAllSessionMessages(): Promise<void> {
    try {
      Logger.info('SessionManager', '🔧 开始修复所有会话的消息数据');

      const allSessions = await this.getSessions();
      let repairedSessionCount = 0;
      let totalRepairedMessages = 0;

      for (const session of allSessions) {
        try {
          Logger.debug('SessionManager', `修复会话: ${session.name} (${session.id})`);

          // 获取会话消息，这个过程中会自动修复数据
          const messages = await this.getSessionMessages(session.id);

          // 检查是否有无效消息
          let invalidCount = 0;
          const validMessages = messages.filter(msg => {
            if (!msg.content || typeof msg.content !== 'string') {
              invalidCount++;
              return false;
            }
            return true;
          });

          if (invalidCount > 0 || validMessages.length !== messages.length) {
            // 重新保存有效消息
            await this.saveSessionMessages(session.id, validMessages);
            repairedSessionCount++;
            totalRepairedMessages += invalidCount;

            Logger.info('SessionManager', `✅ 修复会话 ${session.name}: 移除 ${invalidCount} 条无效消息`);
          }

        } catch (error) {
          Logger.error('SessionManager', `修复会话 ${session.id} 失败: ${error}`);
        }
      }

      Logger.info('SessionManager', `🎉 数据修复完成:`);
      Logger.info('SessionManager', `  - 检查会话数: ${allSessions.length}`);
      Logger.info('SessionManager', `  - 修复会话数: ${repairedSessionCount}`);
      Logger.info('SessionManager', `  - 修复消息数: ${totalRepairedMessages}`);

    } catch (error) {
      Logger.error('SessionManager', `修复会话数据失败: ${error}`);
      throw new Error(`修复会话数据失败: ${error}`);
    }
  }

  /**
   * 诊断会话数据质量
   */
  async diagnoseSessionDataQuality(): Promise<SessionDataQuality> {
    try {
      Logger.info('SessionManager', '🔍 开始诊断会话数据质量');

      const allSessions = await this.getSessions();
      let totalMessages = 0;
      let validMessages = 0;
      let invalidMessages = 0;
      let emptyContentMessages = 0;
      const sessionsWithIssues: string[] = [];

      for (const session of allSessions) {
        try {
          const messages = await AppStorage.getSessionMessages(session.id);
          totalMessages += messages.length;

          let sessionHasIssues = false;

          for (const message of messages) {
            if (!message.content) {
              invalidMessages++;
              sessionHasIssues = true;
            } else if (typeof message.content !== 'string') {
              invalidMessages++;
              sessionHasIssues = true;
            } else if (!message.content.trim()) {
              emptyContentMessages++;
              sessionHasIssues = true;
            } else {
              validMessages++;
            }
          }

          if (sessionHasIssues) {
            sessionsWithIssues.push(`${session.name} (${session.id})`);
          }

        } catch (error) {
          Logger.error('SessionManager', `诊断会话 ${session.id} 失败: ${error}`);
          sessionsWithIssues.push(`${session.name} (${session.id}) - 读取失败`);
        }
      }

      const result: SessionDataQuality = {
        totalSessions: allSessions.length,
        totalMessages,
        validMessages,
        invalidMessages,
        emptyContentMessages,
        sessionsWithIssues
      };

      Logger.info('SessionManager', `📊 数据质量诊断结果:`);
      Logger.info('SessionManager', `  - 会话总数: ${result.totalSessions}`);
      Logger.info('SessionManager', `  - 消息总数: ${result.totalMessages}`);
      Logger.info('SessionManager', `  - 有效消息: ${result.validMessages}`);
      Logger.info('SessionManager', `  - 无效消息: ${result.invalidMessages}`);
      Logger.info('SessionManager', `  - 空内容消息: ${result.emptyContentMessages}`);
      Logger.info('SessionManager', `  - 有问题的会话: ${result.sessionsWithIssues.length}`);

      return result;

    } catch (error) {
      Logger.error('SessionManager', `诊断会话数据质量失败: ${error}`);
      throw new Error(`诊断会话数据质量失败: ${error}`);
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
