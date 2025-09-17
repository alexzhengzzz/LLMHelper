import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { HybridChatService } from '../main/ets/services/HybridChatService';
import { ChatMessage, ChatSession, HybridChatMode } from '../main/ets/types/HybridChatTypes';

/**
 * 混合聊天服务测试套件
 * 测试直连API和服务端API的混合使用、智能路由、负载均衡等功能
 */
export default function hybridChatServiceTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('HybridChatServiceTest');
  
  describe('HybridChatServiceTest', () => {
    let hybridChatService: HybridChatService;
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化混合聊天服务测试环境');
      
      // 获取混合聊天服务实例
      hybridChatService = HybridChatService.getInstance();
      
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
      
      const instance1 = HybridChatService.getInstance();
      const instance2 = HybridChatService.getInstance();
      
      expect(instance1).assertEqual(instance2);
      TestUtils.log('单例模式验证通过');
    });
    
    /**
     * 测试聊天模式切换
     */
    it('should_switch_chat_modes', 0, () => {
      TestUtils.log('测试聊天模式切换');
      
      // 测试直连模式
      hybridChatService.setMode(HybridChatMode.DIRECT_ONLY);
      expect(hybridChatService.getCurrentMode()).assertEqual(HybridChatMode.DIRECT_ONLY);
      
      // 测试服务端模式
      hybridChatService.setMode(HybridChatMode.SERVER_ONLY);
      expect(hybridChatService.getCurrentMode()).assertEqual(HybridChatMode.SERVER_ONLY);
      
      // 测试混合模式
      hybridChatService.setMode(HybridChatMode.HYBRID);
      expect(hybridChatService.getCurrentMode()).assertEqual(HybridChatMode.HYBRID);
      
      TestUtils.log('聊天模式切换测试通过');
    });
    
    /**
     * 测试智能路由决策
     */
    it('should_make_intelligent_routing_decisions', 0, () => {
      TestUtils.log('测试智能路由决策');
      
      // 测试简单查询路由（应该使用直连）
      const simpleRoute = hybridChatService.determineRoute('你好，你是谁？');
      expect(simpleRoute.mode).assertEqual(HybridChatMode.DIRECT_ONLY);
      expect(simpleRoute.reason).assertEqual('简单问候查询');
      
      // 测试复杂查询路由（应该使用服务端）
      const complexRoute = hybridChatService.determineRoute('请帮我分析这个复杂的机器学习算法，并给出优化建议');
      expect(complexRoute.mode).assertEqual(HybridChatMode.SERVER_ONLY);
      expect(complexRoute.reason).assertEqual('复杂技术查询');
      
      // 测试代码查询路由（应该使用混合模式）
      const codeRoute = hybridChatService.determineRoute('这段Python代码有什么问题？\ndef example():\n    return "hello"');
      expect(codeRoute.mode).assertEqual(HybridChatMode.HYBRID);
      expect(codeRoute.reason).assertEqual('代码分析查询');
      
      TestUtils.log('智能路由决策测试通过');
    });
    
    /**
     * 测试会话创建和管理
     */
    it('should_create_and_manage_sessions', 0, async () => {
      TestUtils.log('测试会话创建和管理');
      
      // 创建新会话
      const session = await hybridChatService.createSession('测试会话');
      
      // 验证会话结构
      expect(TestUtils.validateObjectStructure(session, ['id', 'title', 'messages', 'createdAt', 'updatedAt'])).assertTrue();
      expect(session.title).assertEqual('测试会话');
      expect(Array.isArray(session.messages)).assertTrue();
      expect(session.messages.length).assertEqual(0);
      
      // 测试会话获取
      const retrievedSession = await hybridChatService.getSession(session.id);
      expect(retrievedSession !== null).assertTrue();
      if (retrievedSession) {
        expect(retrievedSession.id).assertEqual(session.id);
      }
      
      // 测试会话列表
      const sessions = await hybridChatService.getAllSessions();
      expect(sessions.length).assertGreaterThan(0);
      
      TestUtils.log('会话创建和管理测试通过');
    });
    
    /**
     * 测试消息发送和处理
     */
    it('should_send_and_process_messages', 0, async () => {
      TestUtils.log('测试消息发送和处理');
      
      // 创建会话
      const session = await hybridChatService.createSession('消息测试会话');
      
      // 发送消息
      const message: ChatMessage = {
        id: 'test-message-id',
        content: '你好，请介绍一下人工智能',
        role: 'user',
        timestamp: Date.now()
      };
      
      const response = await hybridChatService.sendMessage(session.id, message);
      
      // 验证响应结构
      expect(TestUtils.validateObjectStructure(response, ['id', 'content', 'role', 'timestamp', 'mode'])).assertTrue();
      expect(response.role).assertEqual('assistant');
      expect(response.content.length).assertGreaterThan(0);
      expect(response.mode).assertEqual(HybridChatMode.DIRECT_ONLY);
      
      // 验证会话消息已更新
      const updatedSession = await hybridChatService.getSession(session.id);
      expect(updatedSession !== null).assertTrue();
      if (updatedSession) {
        expect(updatedSession.messages.length).assertEqual(2); // 用户消息 + AI响应
      }
      
      TestUtils.log('消息发送和处理测试通过');
    });
    
    /**
     * 测试负载均衡
     */
    it('should_perform_load_balancing', 0, async () => {
      TestUtils.log('测试负载均衡');
      
      // 模拟多个并发请求
      const requests = [];
      for (let i = 0; i < 5; i++) {
        requests.push(hybridChatService.getOptimalProvider(`测试消息 ${i}`));
      }
      
      const providers = await Promise.all(requests);
      
      // 验证负载均衡
      const uniqueProviders = new Set(providers);
      expect(uniqueProviders.size).assertGreaterThan(0);
      
      // 验证负载统计
      const loadStats = hybridChatService.getLoadStatistics();
      expect(TestUtils.validateObjectStructure(loadStats, ['totalRequests', 'providerDistribution', 'averageResponseTime'])).assertTrue();
      expect(loadStats.totalRequests).assertEqual(5);
      
      TestUtils.log('负载均衡测试通过');
    });
    
    /**
     * 测试故障转移
     */
    it('should_handle_failover', 0, async () => {
      TestUtils.log('测试故障转移');
      
      // 创建会话
      const session = await hybridChatService.createSession('故障转移测试会话');
      
      // 模拟主服务故障
      await hybridChatService.simulateFailure('direct');
      
      // 发送消息，应该自动切换到备用服务
      const message: ChatMessage = {
        id: 'failover-test-message',
        content: '测试故障转移',
        role: 'user',
        timestamp: Date.now()
      };
      
      const response = await hybridChatService.sendMessage(session.id, message);
      
      // 验证故障转移成功
      expect(response.mode).assertEqual(HybridChatMode.SERVER_ONLY);
      expect(response.failoverUsed).assertTrue();
      
      // 验证故障统计
      const failoverStats = hybridChatService.getFailoverStatistics();
      expect(failoverStats.totalFailures).assertGreaterThan(0);
      expect(failoverStats.successfulFailovers).assertGreaterThan(0);
      
      TestUtils.log('故障转移测试通过');
    });
    
    /**
     * 测试性能优化
     */
    it('should_optimize_performance', 0, async () => {
      TestUtils.log('测试性能优化');
      
      // 测试缓存机制
      const query = '什么是人工智能？';
      
      // 第一次请求
      const startTime1 = Date.now();
      const response1 = await hybridChatService.sendQuery(query);
      const duration1 = Date.now() - startTime1;
      
      // 第二次相同请求（应该使用缓存）
      const startTime2 = Date.now();
      const response2 = await hybridChatService.sendQuery(query);
      const duration2 = Date.now() - startTime2;
      
      // 验证缓存效果
      expect(response2.fromCache).assertTrue();
      expect(duration2).assertLessThan(duration1);
      
      // 测试批处理
      const batchQueries = ['查询1', '查询2', '查询3'];
      const batchResponses = await hybridChatService.sendBatchQueries(batchQueries);
      
      // 验证批处理结果
      expect(batchResponses.length).assertEqual(3);
      batchResponses.forEach(response => {
        expect(TestUtils.validateObjectStructure(response, ['query', 'response', 'duration'])).assertTrue();
      });
      
      TestUtils.log('性能优化测试通过');
    });
    
    /**
     * 测试智能重试机制
     */
    it('should_handle_intelligent_retry', 0, async () => {
      TestUtils.log('测试智能重试机制');
      
      // 模拟网络波动
      const session = await hybridChatService.createSession('重试测试会话');
      
      // 设置模拟网络错误
      await hybridChatService.simulateNetworkIssues();
      
      const message: ChatMessage = {
        id: 'retry-test-message',
        content: '测试重试机制',
        role: 'user',
        timestamp: Date.now()
      };
      
      const response = await hybridChatService.sendMessage(session.id, message);
      
      // 验证重试机制
      expect(response.retryCount).assertGreaterThan(0);
      expect(response.success).assertTrue();
      
      // 验证重试统计
      const retryStats = hybridChatService.getRetryStatistics();
      expect(retryStats.totalRetries).assertGreaterThan(0);
      expect(retryStats.successRate).assertGreaterThan(0);
      
      TestUtils.log('智能重试机制测试通过');
    });
    
    /**
     * 测试会话持久化
     */
    it('should_persist_sessions', 0, async () => {
      TestUtils.log('测试会话持久化');
      
      // 创建会话并添加消息
      const session = await hybridChatService.createSession('持久化测试会话');
      await hybridChatService.sendMessage(session.id, {
        id: 'persist-test-1',
        content: '测试消息1',
        role: 'user',
        timestamp: Date.now()
      });
      
      // 保存会话
      await hybridChatService.saveSession(session.id);
      
      // 模拟重启（创建新实例）
      const newService = HybridChatService.getInstance();
      
      // 验证会话恢复
      const restoredSession = await newService.getSession(session.id);
      expect(restoredSession !== null).assertTrue();
      if (restoredSession) {
        expect(restoredSession.messages.length).assertGreaterThan(0);
      }
      
      TestUtils.log('会话持久化测试通过');
    });
    
    /**
     * 测试安全性和隐私保护
     */
    it('should_handle_security_and_privacy', 0, async () => {
      TestUtils.log('测试安全性和隐私保护');
      
      // 测试敏感信息过滤
      const sensitiveMessage = '我的API密钥是sk-1234567890abcdef';
      const filteredMessage = hybridChatService.filterSensitiveContent(sensitiveMessage);
      
      expect(filteredMessage).assertNotEqual(sensitiveMessage);
      expect(filteredMessage.includes('sk-')).assertFalse();
      
      // 测试加密通信
      const session = await hybridChatService.createSession('安全测试会话');
      const encryptedResponse = await hybridChatService.sendEncryptedMessage(session.id, {
        id: 'security-test-1',
        content: '加密测试消息',
        role: 'user',
        timestamp: Date.now()
      });
      
      expect(encryptedResponse.encrypted).assertTrue();
      expect(encryptedResponse.signature).assertNotEqual('');
      
      // 测试访问控制
      const accessLog = hybridChatService.getAccessLog();
      expect(Array.isArray(accessLog)).assertTrue();
      expect(accessLog.length).assertGreaterThan(0);
      
      TestUtils.log('安全性和隐私保护测试通过');
    });
    
    /**
     * 测试监控和诊断
     */
    it('should_provide_monitoring_and_diagnostics', 0, async () => {
      TestUtils.log('测试监控和诊断');
      
      // 执行一些操作以生成监控数据
      await hybridChatService.createSession('监控测试会话');
      await hybridChatService.sendQuery('监控测试查询');
      
      // 获取系统健康状态
      const healthStatus = hybridChatService.getHealthStatus();
      expect(TestUtils.validateObjectStructure(healthStatus, ['status', 'services', 'metrics'])).assertTrue();
      expect(healthStatus.status).assertEqual('healthy');
      
      // 获取性能指标
      const performanceMetrics = hybridChatService.getPerformanceMetrics();
      expect(TestUtils.validateObjectStructure(performanceMetrics, ['responseTime', 'throughput', 'errorRate', 'cpuUsage', 'memoryUsage'])).assertTrue();
      expect(performanceMetrics.responseTime.average).assertGreaterThan(0);
      
      // 获取诊断信息
      const diagnostics = hybridChatService.getDiagnostics();
      expect(TestUtils.validateObjectStructure(diagnostics, ['timestamp', 'version', 'uptime', 'activeConnections'])).assertTrue();
      
      TestUtils.log('监控和诊断测试通过');
    });
    
    /**
     * 测试配置管理
     */
    it('should_manage_configuration', 0, () => {
      TestUtils.log('测试配置管理');
      
      // 获取当前配置
      const config = hybridChatService.getConfiguration();
      expect(TestUtils.validateObjectStructure(config, ['mode', 'providers', 'loadBalancing', 'caching', 'security'])).assertTrue();
      
      // 测试配置更新
      const newConfig = {
        ...config,
        timeout: 30000,
        maxRetries: 5,
        enableCaching: true
      };
      
      hybridChatService.updateConfiguration(newConfig);
      
      // 验证配置更新
      const updatedConfig = hybridChatService.getConfiguration();
      expect(updatedConfig.timeout).assertEqual(30000);
      expect(updatedConfig.maxRetries).assertEqual(5);
      expect(updatedConfig.enableCaching).assertTrue();
      
      // 测试配置重置
      hybridChatService.resetConfiguration();
      const resetConfig = hybridChatService.getConfiguration();
      expect(resetConfig.timeout).assertNotEqual(30000);
      
      TestUtils.log('配置管理测试通过');
    });
  });
}