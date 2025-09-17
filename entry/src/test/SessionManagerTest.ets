import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { SessionManager } from '../main/ets/utils/SessionManager';
import { Session, Message, SystemPrompt } from '../main/ets/models/ChatModels';
import { AppStorage } from '../main/ets/utils/AppStorage';

/**
 * SessionManager测试套件
 * 测试会话创建、删除、切换、管理等功能
 */
export default function sessionManagerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('SessionManagerTest');
  
  describe('SessionManagerTest', () => {
    let sessionManager: SessionManager;
    let testDataPrefix = 'test_session_';
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化SessionManager测试环境');
      
      // 清理可能存在的测试数据
      await cleanupTestData();
      
      // 获取SessionManager实例
      sessionManager = SessionManager.getInstance();
      
      // 等待初始化完成
      await TestUtils.sleep(1000);
    });
    
    afterAll(async () => {
      // 清理测试数据
      await cleanupTestData();
      testSuite.afterAll();
    });
    
    beforeEach(() => {
      testSuite.beforeEach();
    });
    
    afterEach(() => {
      testSuite.afterEach();
    });
    
    /**
     * 清理测试数据的辅助函数
     */
    async function cleanupTestData(): Promise<void> {
      try {
        // 清理所有会话
        const sessions = await AppStorage.getSessions();
        for (const session of sessions) {
          if (session.id.startsWith(testDataPrefix)) {
            await sessionManager.deleteSession(session.id);
          }
        }
        
        // 清理当前会话ID
        await AppStorage.saveCurrentSessionId(null);
        
        TestUtils.log('测试会话数据清理完成');
      } catch (error) {
        TestUtils.warn('清理测试会话数据时出错: ' + (error as Error).message);
      }
    }
    
    /**
     * 测试SessionManager单例模式
     */
    it('should_be_singleton_instance', 0, () => {
      TestUtils.log('测试SessionManager单例模式');
      
      const instance1 = SessionManager.getInstance();
      const instance2 = SessionManager.getInstance();
      
      expect(instance1).assertEqual(instance2);
      TestUtils.log('SessionManager单例模式验证通过');
    });
    
    /**
     * 测试会话创建功能
     */
    it('should_create_session', 0, async () => {
      TestUtils.log('测试会话创建功能');
      
      const title = '测试会话_' + Date.now();
      
      // 创建会话
      const session = await sessionManager.createSession(title);
      
      // 验证会话创建成功
      expect(session).assertEqual(false);
      expect(session.id.length).assertLarger(0);
      expect(session.title).assertEqual(title);
      expect(session.messageCount).assertEqual(0);
      expect(typeof session.createdAt).assertEqual('number');
      expect(typeof session.updatedAt).assertEqual('number');
      
      TestUtils.log('会话创建功能测试通过');
    });
    
    /**
     * 测试会话列表获取
     */
    it('should_get_sessions_list', 0, async () => {
      TestUtils.log('测试会话列表获取');
      
      // 创建多个测试会话
      const sessionTitles = [
        testDataPrefix + '会话1_' + Date.now(),
        testDataPrefix + '会话2_' + Date.now(),
        testDataPrefix + '会话3_' + Date.now()
      ];
      
      const createdSessions: Session[] = [];
      for (const title of sessionTitles) {
        const session = await sessionManager.createSession(title);
        createdSessions.push(session);
      }
      
      // 等待存储操作完成
      await TestUtils.sleep(500);
      
      // 获取会话列表
      const sessions = await sessionManager.getSessions();
      
      // 验证会话列表
      expect(sessions.length).assertLarger(0);
      
      // 验证创建的会话都在列表中
      const createdIds = createdSessions.map(s => s.id);
      const retrievedIds = sessions.map(s => s.id);
      
      createdIds.forEach(id => {
        expect(retrievedIds.includes(id)).assertTrue();
      });
      
      // 验证会话按更新时间倒序排列
      for (let i = 0; i < sessions.length - 1; i++) {
        expect(sessions[i].updatedAt).assertLargerOrEqual(sessions[i + 1].updatedAt);
      }
      
      TestUtils.log('会话列表获取测试通过');
    });
    
    /**
     * 测试当前会话设置和获取
     */
    it('should_set_and_get_current_session', 0, async () => {
      TestUtils.log('测试当前会话设置和获取');
      
      // 创建测试会话
      const session = await sessionManager.createSession(testDataPrefix + 'current_test_' + Date.now());
      
      // 设置为当前会话
      await sessionManager.setCurrentSession(session.id);
      
      // 获取当前会话ID
      const currentSessionId = await sessionManager.getCurrentSessionId();
      
      // 验证当前会话设置成功
      expect(currentSessionId).assertEqual(session.id);
      
      // 获取当前会话对象
      const currentSession = await sessionManager.getCurrentSession();
      
      // 验证当前会话对象
      expect(currentSession).assertEqual(false);
      expect(currentSession?.id).assertEqual(session.id);
      expect(currentSession?.title).assertEqual(session.title);
      
      TestUtils.log('当前会话设置和获取测试通过');
    });
    
    /**
     * 测试会话删除功能
     */
    it('should_delete_session', 0, async () => {
      TestUtils.log('测试会话删除功能');
      
      // 创建测试会话
      const session = await sessionManager.createSession(testDataPrefix + 'delete_test_' + Date.now());
      
      // 设置为当前会话
      await sessionManager.setCurrentSession(session.id);
      
      // 验证会话存在
      let sessions = await sessionManager.getSessions();
      const sessionExists = sessions.some(s => s.id === session.id);
      expect(sessionExists).assertTrue();
      
      // 删除会话
      await sessionManager.deleteSession(session.id);
      
      // 等待删除操作完成
      await TestUtils.sleep(500);
      
      // 验证会话已被删除
      sessions = await sessionManager.getSessions();
      const sessionDeleted = !sessions.some(s => s.id === session.id);
      expect(sessionDeleted).assertTrue();
      
      // 验证当前会话已清除
      const currentSessionId = await sessionManager.getCurrentSessionId();
      expect(currentSessionId).assertNull();
      
      TestUtils.log('会话删除功能测试通过');
    });
    
    /**
     * 测试会话更新功能
     */
    it('should_update_session', 0, async () => {
      TestUtils.log('测试会话更新功能');
      
      // 创建测试会话
      const originalTitle = testDataPrefix + 'update_test_' + Date.now();
      const session = await sessionManager.createSession(originalTitle);
      
      // 等待创建完成
      await TestUtils.sleep(500);
      
      // 更新会话标题
      const updatedTitle = originalTitle + '_updated';
      await sessionManager.updateSession(session.id, updatedTitle);
      
      // 等待更新完成
      await TestUtils.sleep(500);
      
      // 获取更新后的会话
      const updatedSession = await sessionManager.getSession(session.id);
      
      // 验证会话更新成功
      expect(updatedSession).assertEqual(false);
      expect(updatedSession?.title).assertEqual(updatedTitle);
      expect(updatedSession?.updatedAt).assertLarger(session.updatedAt);
      
      TestUtils.log('会话更新功能测试通过');
    });
    
    /**
     * 测试会话消息管理
     */
    it('should_manage_session_messages', 0, async () => {
      TestUtils.log('测试会话消息管理');
      
      // 创建测试会话
      const session = await sessionManager.createSession(testDataPrefix + 'message_test_' + Date.now());
      
      // 创建测试消息
      const testMessages: Message[] = [
        {
          id: TestUtils.generateRandomId(),
          content: '你好，我想了解AI编程助手',
          role: 'user',
          timestamp: Date.now()
        },
        {
          id: TestUtils.generateRandomId(),
          content: 'AI编程助手可以帮助您进行代码生成、调试和优化',
          role: 'assistant',
          timestamp: Date.now()
        }
      ];
      
      // 添加消息到会话
      await sessionManager.addMessagesToSession(session.id, testMessages);
      
      // 等待添加完成
      await TestUtils.sleep(500);
      
      // 获取会话消息
      const messages = await sessionManager.getSessionMessages(session.id);
      
      // 验证消息
      expect(messages.length).assertEqual(2);
      expect(messages[0].role).assertEqual('user');
      expect(messages[0].content).assertEqual('你好，我想了解AI编程助手');
      expect(messages[1].role).assertEqual('assistant');
      expect(messages[1].content).assertEqual('AI编程助手可以帮助您进行代码生成、调试和优化');
      
      // 验证会话消息计数
      const updatedSession = await sessionManager.getSession(session.id);
      expect(updatedSession?.messageCount).assertEqual(2);
      
      TestUtils.log('会话消息管理测试通过');
    });
    
    /**
     * 测试会话统计信息
     */
    it('should_get_session_stats', 0, async () => {
      TestUtils.log('测试会话统计信息');
      
      // 创建多个测试会话
      const sessionTitles = [
        testDataPrefix + 'stats1_' + Date.now(),
        testDataPrefix + 'stats2_' + Date.now(),
        testDataPrefix + 'stats3_' + Date.now()
      ];
      
      const createdSessions: Session[] = [];
      for (const title of sessionTitles) {
        const session = await sessionManager.createSession(title);
        createdSessions.push(session);
      }
      
      // 设置一个为当前会话
      await sessionManager.setCurrentSession(createdSessions[0].id);
      
      // 等待操作完成
      await TestUtils.sleep(500);
      
      // 获取会话统计信息
      const stats = await sessionManager.getSessionStats();
      
      // 验证统计信息结构
      expect(TestUtils.validateObjectStructure(stats, ['totalSessions', 'maxSessions', 'currentSessionId'])).assertTrue();
      expect(stats.totalSessions).assertLarger(0);
      expect(stats.maxSessions).assertLarger(0);
      expect(typeof stats.currentSessionId).assertEqual('string');
      
      // 验证当前会话ID正确
      expect(stats.currentSessionId).assertEqual(createdSessions[0].id);
      
      TestUtils.log('会话统计信息测试通过');
    });
    
    /**
     * 测试会话数量限制
     */
    it('should_respect_session_limit', 0, async () => {
      TestUtils.log('测试会话数量限制');
      
      // 创建多个会话以测试限制
      const maxAttempts = 15; // 尝试创建超过限制的会话
      const createdSessions: Session[] = [];
      
      for (let i = 0; i < maxAttempts; i++) {
        try {
          const session = await sessionManager.createSession(testDataPrefix + 'limit_test_' + i + '_' + Date.now());
          createdSessions.push(session);
        } catch (error) {
          TestUtils.warn('创建会话时遇到限制: ' + (error as Error).message);
          break;
        }
      }
      
      // 获取会话列表
      const sessions = await sessionManager.getSessions();
      
      // 验证会话数量不超过限制
      expect(sessions.length).assertLessOrEqual(10); // MAX_SESSIONS = 10
      
      TestUtils.log(`创建会话数量限制测试通过，当前会话数: ${sessions.length}`);
    });
    
    /**
     * 测试会话清理功能
     */
    it('should_cleanup_old_sessions', 0, async () => {
      TestUtils.log('测试会话清理功能');
      
      // 创建一些测试会话
      const oldSessionTitles = [
        testDataPrefix + 'old1_' + Date.now(),
        testDataPrefix + 'old2_' + Date.now()
      ];
      
      const newSessionTitles = [
        testDataPrefix + 'new1_' + Date.now(),
        testDataPrefix + 'new2_' + Date.now()
      ];
      
      // 创建旧会话
      for (const title of oldSessionTitles) {
        await sessionManager.createSession(title);
      }
      
      // 等待一段时间
      await TestUtils.sleep(1000);
      
      // 创建新会话
      for (const title of newSessionTitles) {
        await sessionManager.createSession(title);
      }
      
      // 执行清理操作（清理最旧的会话）
      const sessions = await sessionManager.getSessions();
      if (sessions.length > 8) { // 如果会话数量接近限制
        await sessionManager.cleanupOldSessions();
      }
      
      // 验证清理后的会话数量
      const cleanedSessions = await sessionManager.getSessions();
      expect(cleanedSessions.length).assertLessOrEqual(10);
      
      TestUtils.log('会话清理功能测试通过');
    });
    
    /**
     * 测试会话查找功能
     */
    it('should_find_session_by_id', 0, async () => {
      TestUtils.log('测试会话查找功能');
      
      // 创建测试会话
      const session = await sessionManager.createSession(testDataPrefix + 'find_test_' + Date.now());
      
      // 查找会话
      const foundSession = await sessionManager.getSession(session.id);
      
      // 验证找到的会话
      expect(foundSession).assertEqual(false);
      expect(foundSession?.id).assertEqual(session.id);
      expect(foundSession?.title).assertEqual(session.title);
      
      // 查找不存在的会话
      const notFoundSession = await sessionManager.getSession('non_existent_id');
      expect(notFoundSession).assertNull();
      
      TestUtils.log('会话查找功能测试通过');
    });
    
    /**
     * 测试错误处理
     */
    it('should_handle_errors', 0, async () => {
      TestUtils.log('测试错误处理');
      
      // 测试无效会话ID
      try {
        await sessionManager.setCurrentSession('invalid_session_id');
        // 应该不会抛出异常，但会处理错误
        TestUtils.log('无效会话ID处理正常');
      } catch (error) {
        expect(error).assertEqual(false);
        TestUtils.log('错误处理正常，捕获到异常');
      }
      
      // 测试删除不存在的会话
      try {
        await sessionManager.deleteSession('non_existent_session_id');
        // 应该不会抛出异常，但会处理错误
        TestUtils.log('删除不存在会话处理正常');
      } catch (error) {
        expect(error).assertEqual(false);
        TestUtils.log('错误处理正常，捕获到异常');
      }
      
      TestUtils.log('错误处理测试通过');
    });
  });
}