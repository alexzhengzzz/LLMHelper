import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { ApiService } from '../main/ets/services/ApiService';
import { ChatRequest, ChatResponse, APIMode, AIProvider } from '../main/ets/types/APITypes';

/**
 * 基础API服务测试套件
 * 测试API请求、响应处理、错误处理等功能
 */
export default function apiServiceTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('ApiServiceTest');
  
  describe('ApiServiceTest', () => {
    let apiService: ApiService;
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化API服务测试环境');
      
      // 获取API服务实例
      apiService = ApiService.getInstance();
      
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
      
      const instance1 = ApiService.getInstance();
      const instance2 = ApiService.getInstance();
      
      expect(instance1).assertEqual(instance2);
      TestUtils.log('单例模式验证通过');
    });
    
    /**
     * 测试聊天请求构建
     */
    it('should_build_chat_request', 0, () => {
      TestUtils.log('测试聊天请求构建');
      
      const request = apiService.buildChatRequest({
        message: 'Hello, how are you?',
        model: 'test-model',
        temperature: 0.7,
        maxTokens: 1000
      });
      
      // 验证请求结构
      expect(TestUtils.validateObjectStructure(request, ['messages', 'model', 'temperature', 'max_tokens'])).assertTrue();
      expect(Array.isArray(request.messages)).assertTrue();
      expect(request.messages.length).assertEqual(1);
      expect(request.messages[0].role).assertEqual('user');
      expect(request.messages[0].content).assertEqual('Hello, how are you?');
      expect(request.model).assertEqual('test-model');
      expect(request.temperature).assertEqual(0.7);
      expect(request.max_tokens).assertEqual(1000);
      
      TestUtils.log('聊天请求构建测试通过');
    });
    
    /**
     * 测试API响应解析
     */
    it('should_parse_api_response', 0, () => {
      TestUtils.log('测试API响应解析');
      
      const mockResponse: ChatResponse = {
        id: 'test-response-id',
        object: 'chat.completion',
        created: Date.now(),
        model: 'test-model',
        choices: [
          {
            index: 0,
            message: {
              role: 'assistant',
              content: 'I am doing well, thank you!'
            },
            finish_reason: 'stop'
          }
        ],
        usage: {
          prompt_tokens: 10,
          completion_tokens: 8,
          total_tokens: 18
        }
      };
      
      const result = apiService.parseChatResponse(mockResponse);
      
      // 验证解析结果
      expect(TestUtils.validateObjectStructure(result, ['content', 'role', 'id', 'usage'])).assertTrue();
      expect(result.content).assertEqual('I am doing well, thank you!');
      expect(result.role).assertEqual('assistant');
      expect(result.id).assertEqual('test-response-id');
      expect(result.usage.total_tokens).assertEqual(18);
      
      TestUtils.log('API响应解析测试通过');
    });
    
    /**
     * 测试错误处理
     */
    it('should_handle_api_errors', 0, async () => {
      TestUtils.log('测试错误处理');
      
      const errorResponse = {
        error: {
          message: 'API Error: Invalid API key',
          type: 'authentication_error',
          code: 'invalid_api_key'
        }
      };
      
      try {
        // 模拟API错误
        const result = apiService.handleApiError(errorResponse);
        expect(result.success).assertFalse();
        expect(result.error).assertEqual('Invalid API key');
        expect(result.errorType).assertEqual('authentication_error');
        
        TestUtils.log('API错误处理测试通过');
      } catch (error) {
        expect(error !== null).assertTrue();
        TestUtils.log('错误处理正常，捕获到异常');
      }
    });
    
    /**
     * 测试请求超时处理
     */
    it('should_handle_request_timeout', 0, async () => {
      TestUtils.log('测试请求超时处理');
      
      try {
        await AsyncTestUtils.withTimeout(
          new Promise(resolve => setTimeout(resolve, 3000)), // 3秒延迟
          1000, // 1秒超时
          'API请求超时测试'
        );
        expect(false).assertTrue(); // 不应该执行到这里
      } catch (error) {
        expect(error !== null).assertTrue();
        const errorMessage = (error as Error).message;
        expect(errorMessage.includes('超时')).assertTrue();
        TestUtils.log('请求超时处理正常，捕获到超时异常');
      }
      
      TestUtils.log('请求超时处理测试通过');
    });
    
    /**
     * 测试流式响应处理
     */
    it('should_handle_stream_response', 0, async () => {
      TestUtils.log('测试流式响应处理');
      
      // 模拟流式响应数据
      const streamData = [
        'data: {"id": "test-1", "choices": [{"index": 0, "delta": {"content": "Hello"}}]}',
        'data: {"id": "test-2", "choices": [{"index": 0, "delta": {"content": " world"}}]}',
        'data: {"id": "test-3", "choices": [{"index": 0, "delta": {"content": "!"}}]}',
        'data: [DONE]'
      ];
      
      const result = apiService.processStreamResponse(streamData);
      
      // 验证流式响应处理结果
      expect(result.content).assertEqual('Hello world!');
      expect(result.chunks.length).assertEqual(3);
      expect(result.chunks[0]).assertEqual('Hello');
      expect(result.chunks[1]).assertEqual(' world');
      expect(result.chunks[2]).assertEqual('!');
      
      TestUtils.log('流式响应处理测试通过');
    });
    
    /**
     * 测试请求重试机制
     */
    it('should_retry_failed_requests', 0, async () => {
      TestUtils.log('测试请求重试机制');
      
      let attemptCount = 0;
      const mockRequest = async () => {
        attemptCount++;
        if (attemptCount < 3) {
          throw new Error('网络错误');
        }
        return { success: true, data: '请求成功' };
      };
      
      try {
        const result = await AsyncTestUtils.withRetry(
          mockRequest,
          3, // 最大重试3次
          100, // 重试间隔100ms
          'API请求重试测试'
        );
        
        expect(result.success).assertTrue();
        expect(attemptCount).assertEqual(3);
        TestUtils.log('请求重试机制测试通过');
      } catch (error) {
        expect(false).assertTrue(); // 不应该执行到这里
      }
    });
    
    /**
     * 测试API模式切换
     */
    it('should_switch_api_modes', 0, () => {
      TestUtils.log('测试API模式切换');
      
      // 测试直连模式
      apiService.setMode(APIMode.DIRECT_CALL);
      expect(apiService.getCurrentMode()).assertEqual(APIMode.DIRECT_CALL);
      
      // 测试服务端模式
      apiService.setMode(APIMode.SERVER_PROXY);
      expect(apiService.getCurrentMode()).assertEqual(APIMode.SERVER_PROXY);
      
      TestUtils.log('API模式切换测试通过');
    });
    
    /**
     * 测试厂商配置
     */
    it('should_handle_provider_configuration', 0, () => {
      TestUtils.log('测试厂商配置');
      
      const providers = apiService.getSupportedProviders();
      
      // 验证支持的厂商列表
      expect(Array.isArray(providers)).assertTrue();
      expect(providers.length).assertGreaterThan(0);
      expect(providers.includes(AIProvider.SILICONFLOW)).assertTrue();
      expect(providers.includes(AIProvider.GOOGLE)).assertTrue();
      expect(providers.includes(AIProvider.ZHIPU)).assertTrue();
      
      // 测试特定厂商配置
      const siliconFlowConfig = apiService.getProviderConfig(AIProvider.SILICONFLOW);
      expect(siliconFlowConfig !== null).assertTrue();
      if (siliconFlowConfig) {
        expect(TestUtils.validateObjectStructure(siliconFlowConfig, ['name', 'baseUrl', 'models'])).assertTrue();
      }
      
      TestUtils.log('厂商配置测试通过');
    });
    
    /**
     * 测试请求参数验证
     */
    it('should_validate_request_parameters', 0, () => {
      TestUtils.log('测试请求参数验证');
      
      // 测试空消息验证
      const emptyMessageResult = apiService.validateRequest({ message: '' });
      expect(emptyMessageResult.valid).assertFalse();
      expect(emptyMessageResult.errors.length).assertGreaterThan(0);
      
      // 测试无效温度值验证
      const invalidTempResult = apiService.validateRequest({ message: 'test', temperature: 2.0 });
      expect(invalidTempResult.valid).assertFalse();
      
      // 测试有效参数
      const validResult = apiService.validateRequest({ 
        message: 'Hello', 
        temperature: 0.7, 
        maxTokens: 1000 
      });
      expect(validResult.valid).assertTrue();
      
      TestUtils.log('请求参数验证测试通过');
    });
    
    /**
     * 测试响应缓存机制
     */
    it('should_cache_responses', 0, async () => {
      TestUtils.log('测试响应缓存机制');
      
      const cacheKey = 'test_cache_key';
      const mockResponse = { content: 'Cached response', timestamp: Date.now() };
      
      // 测试缓存设置
      apiService.setCache(cacheKey, mockResponse);
      
      // 测试缓存获取
      const cachedResponse = apiService.getCache(cacheKey);
      expect(cachedResponse !== null).assertTrue();
      if (cachedResponse) {
        expect(cachedResponse.content).assertEqual('Cached response');
      }
      
      // 测试缓存删除
      apiService.clearCache(cacheKey);
      const deletedResponse = apiService.getCache(cacheKey);
      expect(deletedResponse).assertNull();
      
      TestUtils.log('响应缓存机制测试通过');
    });
  });
}