import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { AppStorage } from '../main/ets/utils/AppStorage';
import { Message, SystemPrompt, Session, SystemPromptData } from '../main/ets/models/ChatModels';
import { AvatarSettings, AutoTTSSettings, ModelConfig, UserProfileData } from '../main/ets/utils/AppStorage';

/**
 * AppStorage测试套件
 * 测试数据存储、读取、更新、删除等功能
 */
export default function appStorageTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('AppStorageTest');
  
  describe('AppStorageTest', () => {
    let testDataPrefix = 'test_';
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化AppStorage测试环境');
      
      // 清理可能存在的测试数据
      await cleanupTestData();
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
        await AppStorage.clearMessages();
        TestUtils.log('测试消息清理完成');
      } catch (error) {
        TestUtils.warn('清理测试消息时出错: ' + (error as Error).message);
      }
    }
    
    /**
     * 测试AppStorage基本功能
     */
    it('should_have_basic_storage_methods', 0, () => {
      TestUtils.log('测试AppStorage基本功能');
      
      // 验证静态方法存在
      expect(typeof AppStorage.getStorage).assertEqual('function');
      expect(typeof AppStorage.saveMessages).assertEqual('function');
      expect(typeof AppStorage.getMessages).assertEqual('function');
      expect(typeof AppStorage.clearMessages).assertEqual('function');
      expect(typeof AppStorage.saveSystemPrompts).assertEqual('function');
      expect(typeof AppStorage.getSystemPrompts).assertEqual('function');
      expect(typeof AppStorage.saveSessions).assertEqual('function');
      expect(typeof AppStorage.getSessions).assertEqual('function');
      
      TestUtils.log('AppStorage基本功能测试通过');
    });
    
    /**
     * 测试消息存储功能
     */
    it('should_save_and_get_messages', 0, async () => {
      TestUtils.log('测试消息存储功能');
      
      // 创建测试消息
      const testMessages: Message[] = [
        TestUtils.createMockMessage(testDataPrefix + 'msg1', '你好，我想了解更多关于AI编程助手的信息'),
        TestUtils.createMockMessage(testDataPrefix + 'msg2', 'AI编程助手可以帮助你进行代码生成、调试和优化'),
        TestUtils.createMockMessage(testDataPrefix + 'msg3', '能否给我一个Python的Hello World示例？')
      ];
      
      // 保存消息
      await AppStorage.saveMessages(testMessages);
      TestUtils.log('测试消息保存完成');
      
      // 等待存储操作完成
      await TestUtils.sleep(500);
      
      // 读取消息
      const retrievedMessages = await AppStorage.getMessages();
      
      // 验证消息数量
      expect(retrievedMessages.length).assertEqual(3);
      
      // 验证消息内容
      expect(retrievedMessages[0].id).assertEqual(testDataPrefix + 'msg1');
      expect(retrievedMessages[0].content).assertEqual('你好，我想了解更多关于AI编程助手的信息');
      expect(retrievedMessages[0].role).assertEqual('user');
      
      expect(retrievedMessages[1].id).assertEqual(testDataPrefix + 'msg2');
      expect(retrievedMessages[1].content).assertEqual('AI编程助手可以帮助你进行代码生成、调试和优化');
      expect(retrievedMessages[1].role).assertEqual('assistant');
      
      expect(retrievedMessages[2].id).assertEqual(testDataPrefix + 'msg3');
      expect(retrievedMessages[2].content).assertEqual('能否给我一个Python的Hello World示例？');
      
      TestUtils.log('消息存储功能测试通过');
    });
    
    /**
     * 测试消息清理功能
     */
    it('should_clear_messages', 0, async () => {
      TestUtils.log('测试消息清理功能');
      
      // 先保存一些消息
      const testMessages: Message[] = [
        TestUtils.createMockMessage(testDataPrefix + 'clear_msg1', '这条消息将被删除'),
        TestUtils.createMockMessage(testDataPrefix + 'clear_msg2', '这条消息也将被删除')
      ];
      
      await AppStorage.saveMessages(testMessages);
      
      // 验证消息已保存
      let retrievedMessages = await AppStorage.getMessages();
      expect(retrievedMessages.length).assertLarger(0);
      
      // 清理消息
      await AppStorage.clearMessages();
      
      // 等待清理操作完成
      await TestUtils.sleep(500);
      
      // 验证消息已清理
      retrievedMessages = await AppStorage.getMessages();
      expect(retrievedMessages.length).assertEqual(0);
      
      TestUtils.log('消息清理功能测试通过');
    });
    
    /**
     * 测试系统提示词存储功能
     */
    it('should_save_and_get_system_prompts', 0, async () => {
      TestUtils.log('测试系统提示词存储功能');
      
      // 创建测试系统提示词
      const testPrompts: SystemPrompt[] = [
        TestUtils.createMockSystemPrompt(testDataPrefix + 'prompt1', '编程助手', '你是一个专业的编程助手，可以帮助用户解决各种编程问题。', '编程'),
        TestUtils.createMockSystemPrompt(testDataPrefix + 'prompt2', '代码审查', '请对以下代码进行审查，指出可能的问题和改进建议。', '代码'),
        TestUtils.createMockSystemPrompt(testDataPrefix + 'prompt3', '学习助手', '用简单易懂的方式解释复杂的概念，帮助用户更好地理解。', '学习')
      ];
      
      // 保存系统提示词
      await AppStorage.saveSystemPrompts(testPrompts);
      TestUtils.log('测试系统提示词保存完成');
      
      // 等待存储操作完成
      await TestUtils.sleep(500);
      
      // 读取系统提示词
      const retrievedPrompts = await AppStorage.getSystemPrompts();
      
      // 验证提示词数量
      expect(retrievedPrompts.length).assertEqual(3);
      
      // 验证提示词内容
      expect(retrievedPrompts[0].id).assertEqual(testDataPrefix + 'prompt1');
      expect(retrievedPrompts[0].name).assertEqual('编程助手');
      expect(retrievedPrompts[0].content).toContain('编程助手');
      expect(retrievedPrompts[0].category).assertEqual('编程');
      
      expect(retrievedPrompts[1].id).assertEqual(testDataPrefix + 'prompt2');
      expect(retrievedPrompts[1].name).assertEqual('代码审查');
      expect(retrievedPrompts[1].category).assertEqual('代码');
      
      expect(retrievedPrompts[2].id).assertEqual(testDataPrefix + 'prompt3');
      expect(retrievedPrompts[2].name).assertEqual('学习助手');
      expect(retrievedPrompts[2].category).assertEqual('学习');
      
      TestUtils.log('系统提示词存储功能测试通过');
    });
    
    /**
     * 测试会话存储功能
     */
    it('should_save_and_get_sessions', 0, async () => {
      TestUtils.log('测试会话存储功能');
      
      // 创建测试会话
      const testSessions: Session[] = [
        TestUtils.createMockSession(testDataPrefix + 'session1', '编程讨论', 5),
        TestUtils.createMockSession(testDataPrefix + 'session2', '学习咨询', 3),
        TestUtils.createMockSession(testDataPrefix + 'session3', '代码审查', 8)
      ];
      
      // 保存会话
      await AppStorage.saveSessions(testSessions);
      TestUtils.log('测试会话保存完成');
      
      // 等待存储操作完成
      await TestUtils.sleep(500);
      
      // 读取会话
      const retrievedSessions = await AppStorage.getSessions();
      
      // 验证会话数量
      expect(retrievedSessions.length).assertEqual(3);
      
      // 验证会话内容
      expect(retrievedSessions[0].id).assertEqual(testDataPrefix + 'session1');
      expect(retrievedSessions[0].title).assertEqual('编程讨论');
      expect(retrievedSessions[0].messageCount).assertEqual(5);
      
      expect(retrievedSessions[1].id).assertEqual(testDataPrefix + 'session2');
      expect(retrievedSessions[1].title).assertEqual('学习咨询');
      expect(retrievedSessions[1].messageCount).assertEqual(3);
      
      expect(retrievedSessions[2].id).assertEqual(testDataPrefix + 'session3');
      expect(retrievedSessions[2].title).assertEqual('代码审查');
      expect(retrievedSessions[2].messageCount).assertEqual(8);
      
      TestUtils.log('会话存储功能测试通过');
    });
    
    /**
     * 测试头像设置存储功能
     */
    it('should_save_and_get_avatar_settings', 0, async () => {
      TestUtils.log('测试头像设置存储功能');
      
      // 创建测试头像设置
      const testAvatarSettings = new AvatarSettings(
        'emoji',
        '😊',
        'default',
        '#34A853'
      );
      
      // 保存头像设置
      await AppStorage.saveAvatarSettings(testAvatarSettings);
      TestUtils.log('测试头像设置保存完成');
      
      // 等待存储操作完成
      await TestUtils.sleep(500);
      
      // 读取头像设置
      const retrievedSettings = await AppStorage.getAvatarSettings();
      
      // 验证头像设置内容
      expect(retrievedSettings).assertEqual(true);
      expect(retrievedSettings.userAvatarType).assertEqual('emoji');
      expect(retrievedSettings.userAvatarValue).assertEqual('😊');
      expect(retrievedSettings.aiAvatarType).assertEqual('default');
      expect(retrievedSettings.aiAvatarValue).assertEqual('#34A853');
      
      TestUtils.log('头像设置存储功能测试通过');
    });
    
    /**
     * 测试TTS设置存储功能
     */
    it('should_save_and_get_tts_settings', 0, async () => {
      TestUtils.log('测试TTS设置存储功能');
      
      // 创建测试TTS设置
      const testTTSSettings: AutoTTSSettings = {
        muted: false,
        speed: 1.2,
        volume: 0.8,
        pitch: 1.0,
        language: 'zh-CN',
        autoPlayOnReceive: true
      };
      
      // 保存TTS设置
      await AppStorage.saveAutoTTSSettings(testTTSSettings);
      TestUtils.log('测试TTS设置保存完成');
      
      // 等待存储操作完成
      await TestUtils.sleep(500);
      
      // 读取TTS设置
      const retrievedSettings = await AppStorage.getAutoTTSSettings();
      
      // 验证TTS设置内容
      expect(retrievedSettings).assertEqual(true);
      expect(retrievedSettings.muted).assertEqual(true);
      expect(retrievedSettings.speed).assertEqual(1.2);
      expect(retrievedSettings.volume).assertEqual(0.8);
      expect(retrievedSettings.pitch).assertEqual(1.0);
      expect(retrievedSettings.language).assertEqual('zh-CN');
      expect(retrievedSettings.autoPlayOnReceive).assertEqual(true);
      
      TestUtils.log('TTS设置存储功能测试通过');
    });
    
    /**
     * 测试用户资料存储功能
     */
    it('should_save_and_get_user_profile', 0, async () => {
      TestUtils.log('测试用户资料存储功能');
      
      // 创建测试用户资料
      const testUserProfile: UserProfileData = {
        userName: '测试用户',
        userSignature: '这是一个测试用户的个性签名',
        userAvatarType: 'emoji',
        userAvatarValue: '🧪',
        updatedAt: Date.now()
      };
      
      // 保存用户资料
      await AppStorage.saveUserProfile(testUserProfile);
      TestUtils.log('测试用户资料保存完成');
      
      // 等待存储操作完成
      await TestUtils.sleep(500);
      
      // 读取用户资料
      const retrievedProfile = await AppStorage.getUserProfile();
      
      // 验证用户资料内容
      expect(retrievedProfile).assertEqual(true);
      expect(retrievedProfile.userName).assertEqual('测试用户');
      expect(retrievedProfile.userSignature).assertEqual('这是一个测试用户的个性签名');
      expect(retrievedProfile.userAvatarType).assertEqual('emoji');
      expect(retrievedProfile.userAvatarValue).assertEqual('🧪');
      
      TestUtils.log('用户资料存储功能测试通过');
    });
    
    /**
     * 测试模型配置存储功能
     */
    it('should_save_and_get_model_config', 0, async () => {
      TestUtils.log('测试模型配置存储功能');
      
      // 创建测试模型配置
      const testModelConfig: ModelConfig = {
        provider: 'siliconflow',
        model: 'Qwen/Qwen2.5-7B-Instruct',
        savedAt: Date.now()
      };
      
      // 保存模型配置
      await AppStorage.saveModelConfig(testModelConfig);
      TestUtils.log('测试模型配置保存完成');
      
      // 等待存储操作完成
      await TestUtils.sleep(500);
      
      // 读取模型配置
      const retrievedConfig = await AppStorage.getModelConfig();
      
      // 验证模型配置内容
      expect(retrievedConfig).assertEqual(true);
      expect(retrievedConfig.provider).assertEqual('siliconflow');
      expect(retrievedConfig.model).assertEqual('Qwen/Qwen2.5-7B-Instruct');
      expect(typeof retrievedConfig.savedAt).assertEqual('number');
      
      TestUtils.log('模型配置存储功能测试通过');
    });
    
    /**
     * 测试错误处理
     */
    it('should_handle_storage_errors', 0, async () => {
      TestUtils.log('测试存储错误处理');
      
      // 测试空数据处理
      const emptyMessages: Message[] = [];
      await AppStorage.saveMessages(emptyMessages);
      
      const retrievedEmptyMessages = await AppStorage.getMessages();
      expect(retrievedEmptyMessages.length).assertEqual(0);
      
      // 测试空系统提示词处理
      const emptyPrompts: SystemPrompt[] = [];
      await AppStorage.saveSystemPrompts(emptyPrompts);
      
      const retrievedEmptyPrompts = await AppStorage.getSystemPrompts();
      expect(retrievedEmptyPrompts.length).assertEqual(0);
      
      TestUtils.log('存储错误处理测试通过');
    });
    
    /**
     * 测试并发访问
     */
    it('should_handle_concurrent_access', 0, async () => {
      TestUtils.log('测试并发访问');
      
      // 创建多个并发存储操作
      const concurrentOperations = [
        AppStorage.saveMessages([
          TestUtils.createMockMessage(testDataPrefix + 'concurrent1', '并发消息1'),
          TestUtils.createMockMessage(testDataPrefix + 'concurrent2', '并发消息2')
        ]),
        AppStorage.saveSessions([
          TestUtils.createMockSession(testDataPrefix + 'concurrent_session1', '并发会话1', 2)
        ]),
        AppStorage.saveSystemPrompts([
          TestUtils.createMockSystemPrompt(testDataPrefix + 'concurrent_prompt1', '并发提示词1', '并发内容1', '测试')
        ])
      ];
      
      // 等待所有操作完成
      await Promise.all(concurrentOperations);
      
      // 等待存储操作完成
      await TestUtils.sleep(1000);
      
      // 验证数据完整性
      const messages = await AppStorage.getMessages();
      const sessions = await AppStorage.getSessions();
      const prompts = await AppStorage.getSystemPrompts();
      
      expect(messages.length).assertLarger(0);
      expect(sessions.length).assertLarger(0);
      expect(prompts.length).assertLarger(0);
      
      TestUtils.log('并发访问测试通过');
    });
  });
}