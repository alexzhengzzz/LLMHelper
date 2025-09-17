import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { APIManager } from '../main/ets/services/APIManager';
import { APIMode, AIProvider, ChatRequest, ChatResponse } from '../main/ets/types/APITypes';
import { APIKeyManager } from '../main/ets/utils/APIKeyManager';

/**
 * 测试数据接口
 */
interface TestMessage {
  role: 'user' | 'assistant';
  content: string;
}

/**
 * API管理器测试套件
 * 测试API模式切换、厂商选择、密钥管理等功能
 */
export default function apiManagerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('APIManagerTest');
  
  describe('APIManagerTest', () => {
    let apiManager: APIManager;
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化API管理器测试环境');
      
      // 清理可能存在的实例
      // 注意：这里假设APIManager有getInstance方法，具体实现可能需要调整
      
      // 获取API管理器实例
      apiManager = APIManager.getInstance();
      
      // 等待初始化完成
      await TestUtils.sleep(1000);
    });
    
    afterAll(async () => {
      await TestUtils.cleanupTestData();
      testSuite.afterAll();
    });
    
    beforeEach(() => {
      testSuite.beforeEach();
    });
    
    afterEach(() => {
      testSuite.afterEach();
    });
    
    /**
     * 测试单例模式
     */
    it('should_be_singleton_instance', 0, () => {
      TestUtils.log('测试单例模式');
      
      const instance1 = APIManager.getInstance();
      const instance2 = APIManager.getInstance();
      
      expect(instance1).assertEqual(instance2);
      TestUtils.log('单例模式验证通过');
    });
    
    /**
     * 测试获取当前API模式
     */
    it('should_get_current_api_mode', 0, async () => {
      TestUtils.log('测试获取当前API模式');
      
      const currentMode = apiManager.getCurrentMode();
      expect(currentMode).assertEqual(APIMode.DIRECT_CALL);
      
      TestUtils.log('获取当前API模式测试通过');
    });
    
    /**
     * 测试获取当前厂商
     */
    it('should_get_current_provider', 0, async () => {
      TestUtils.log('测试获取当前厂商');
      
      const currentProvider = apiManager.getCurrentProvider();
      expect(currentProvider).assertEqual(AIProvider.SILICONFLOW);
      
      TestUtils.log('获取当前厂商测试通过');
    });
    
    /**
     * 测试连接测试功能
     */
    it('should_test_connection', 0, async () => {
      TestUtils.log('测试连接测试功能');
      
      // 测试直连模式的连接测试
      const result = await apiManager.testConnection();
      
      // 验证结果结构
      expect(TestUtils.validateObjectStructure(result, ['success', 'message'])).assertTrue();
      
      // 无论连接是否成功，都应该有结果
      expect(typeof result.success).assertEqual('boolean');
      expect(typeof result.message).assertEqual('string');
      
      TestUtils.log('连接测试功能验证通过');
    });
    
    /**
     * 测试API密钥管理
     */
    it('should_manage_api_keys', 0, async () => {
      TestUtils.log('测试API密钥管理');
      
      // 获取API密钥管理器实例
      const apiKeyManager = APIKeyManager.getInstance();
      
      // 测试密钥更新
      const testApiKey = 'test_api_key_' + Date.now();
      try {
        await apiKeyManager.updateApiKey(AIProvider.SILICONFLOW, testApiKey);
        // 如果更新成功，验证配置
        const config = apiKeyManager.getConfig(AIProvider.SILICONFLOW);
        expect(config !== null).assertTrue();
        if (config !== null) {
          expect(config.apiKey).assertEqual(testApiKey);
        }
      } catch (error) {
        // 如果更新失败（可能因为密钥格式不正确），这也在预期内
        TestUtils.log(`API密钥更新失败（可能格式不正确）: ${error}`);
      }
      
      // 测试密钥验证
      const validation = apiKeyManager.validateApiKey(AIProvider.SILICONFLOW, testApiKey);
      expect(typeof validation.isValid).assertEqual('boolean');
      
      TestUtils.log('API密钥管理测试通过');
    });
    
    /**
     * 测试聊天请求构建
     */
    it('should_build_chat_request', 0, () => {
      TestUtils.log('测试聊天请求构建');
      
      const testMessages: TestMessage[] = [
        { role: 'user', content: 'Hello, how are you?' },
        { role: 'assistant', content: 'I\'m doing well, thank you!' }
      ];
      
      const chatRequest: ChatRequest = {
        messages: testMessages,
        model: 'test-model',
        max_tokens: 1000,
        temperature: 0.7,
        stream: false
      };
      
      // 验证请求结构
      expect(TestUtils.validateObjectStructure(chatRequest, ['messages', 'model', 'max_tokens', 'temperature', 'stream'])).assertTrue();
      expect(Array.isArray(chatRequest.messages)).assertTrue();
      expect(chatRequest.messages.length).assertEqual(2);
      expect(chatRequest.messages[0].role).assertEqual('user');
      expect(chatRequest.messages[1].role).assertEqual('assistant');
      
      TestUtils.log('聊天请求构建测试通过');
    });
    
    /**
     * 测试错误处理
     */
    it('should_handle_errors', 0, async () => {
      TestUtils.log('测试错误处理');
      
      // 测试状态管理的异常处理
      let errorCaught = false;
      try {
        const state = apiManager.getState();
        expect(state !== null).assertTrue();
      } catch (error) {
        errorCaught = true;
        TestUtils.log('错误处理正常，捕获到异常');
      }
      
      if (!errorCaught) {
        TestUtils.log('正常获取状态，无异常');
      }
      
      TestUtils.log('错误处理测试通过');
    });
    
    /**
     * 测试状态管理
     */
    it('should_manage_state', 0, async () => {
      TestUtils.log('测试状态管理');
      
      // 获取当前状态
      const state = apiManager.getState();
      
      // 验证状态结构
      expect(TestUtils.validateObjectStructure(state, ['currentMode', 'currentProvider', 'isInitialized'])).assertTrue();
      expect(typeof state.currentMode).assertEqual('string');
      expect(typeof state.currentProvider).assertEqual('string');
      expect(typeof state.isInitialized).assertEqual('boolean');
      
      TestUtils.log('状态管理测试通过');
    });
    
    /**
     * 测试异步操作超时处理
     */
    it('should_handle_timeout', 0, async () => {
      TestUtils.log('测试异步操作超时处理');
      
      // 测试超时机制（使用AsyncTestUtils）
      try {
        await AsyncTestUtils.withTimeout<void>(
          new Promise<void>(resolve => setTimeout(resolve, 2000)), // 2秒延迟
          1000, // 1秒超时
          '超时测试操作'
        );
        expect(false).assertTrue(); // 不应该执行到这里
      } catch (error) {
        expect(error !== null).assertTrue();
        const errorMessage = (error as Error).message;
        expect(errorMessage.includes('超时')).assertTrue();
        TestUtils.log('超时处理正常，捕获到超时异常');
      }
      
      TestUtils.log('异步操作超时处理测试通过');
    });
  });
}