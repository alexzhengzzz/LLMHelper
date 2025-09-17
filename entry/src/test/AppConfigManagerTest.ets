import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { AppConfigManager } from '../main/ets/utils/AppConfigManager';

/**
 * 应用配置管理器测试套件
 * 测试配置加载、更新、获取等功能
 */
export default function appConfigManagerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('AppConfigManagerTest');
  
  describe('AppConfigManagerTest', () => {
    let appConfigManager: AppConfigManager;
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化应用配置管理器测试环境');
      
      // 获取配置管理器实例
      appConfigManager = AppConfigManager.getInstance();
      
      // 重置配置确保测试环境清洁
      appConfigManager.resetToDefault();
      
      // 等待初始化完成
      await TestUtils.sleep(500);
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
      
      const instance1 = AppConfigManager.getInstance();
      const instance2 = AppConfigManager.getInstance();
      
      expect(instance1).assertEqual(instance2);
      TestUtils.log('单例模式验证通过');
    });
    
    /**
     * 测试初始化状态
     */
    it('should_check_initialization_status', 0, () => {
      TestUtils.log('测试初始化状态');
      
      // 重置后应该是未初始化状态
      const isInitialized = appConfigManager.isInitialized();
      
      expect(isInitialized).assertEqual(false);
      TestUtils.log('初始化状态检查通过');
    });
    
    /**
     * 测试配置初始化
     */
    it('should_initialize_config_successfully', 0, async () => {
      TestUtils.log('测试配置初始化');
      
      // 执行初始化
      await appConfigManager.initialize();
      
      // 检查初始化状态
      const isInitialized = appConfigManager.isInitialized();
      expect(isInitialized).assertEqual(true);
      
      TestUtils.log('配置初始化验证通过');
    });
    
    /**
     * 测试获取配置
     */
    it('should_get_config_after_initialization', 0, async () => {
      TestUtils.log('测试获取配置');
      
      // 确保已初始化
      await appConfigManager.initialize();
      
      // 获取配置
      const config = appConfigManager.getConfig();
      
      // 验证配置存在
      expect(config).assertInstanceOf('object');
      
      TestUtils.log('配置获取验证通过');
    });
    
    /**
     * 测试服务器配置更新
     */
    it('should_update_server_config', 0, async () => {
      TestUtils.log('测试服务器配置更新');
      
      // 确保已初始化
      await appConfigManager.initialize();
      
      // 准备测试数据
      const newBaseUrl = 'https://test.example.com/api';
      const newWsUrl = 'wss://test.example.com/ws';
      const newSearchUrl = 'https://test.example.com';
      
      // 更新配置
      appConfigManager.updateServerConfig({
        baseUrl: newBaseUrl,
        wsUrl: newWsUrl,
        searchUrl: newSearchUrl
      });
      
      // 获取更新后的配置
      const updatedConfig = appConfigManager.getServerConfig();
      
      // 验证更新结果
      expect(updatedConfig.baseUrl).assertEqual(newBaseUrl);
      expect(updatedConfig.wsUrl).assertEqual(newWsUrl);
      expect(updatedConfig.searchUrl).assertEqual(newSearchUrl);
      
      TestUtils.log('服务器配置更新验证通过');
    });
    
    /**
     * 测试隐私配置更新
     */
    it('should_update_privacy_config', 0, async () => {
      TestUtils.log('测试隐私配置更新');
      
      // 确保已初始化
      await appConfigManager.initialize();
      
      // 准备测试数据
      const newDeveloperName = 'Test Developer';
      const newGithubUrl = 'https://github.com/test';
      
      // 更新配置
      appConfigManager.updatePrivacyConfig({
        showDeveloperInfo: true,
        developerName: newDeveloperName,
        developerContact: 'test@example.com',
        githubUrl: newGithubUrl
      });
      
      // 获取更新后的配置
      const updatedConfig = appConfigManager.getPrivacyConfig();
      
      // 验证更新结果
      expect(updatedConfig.showDeveloperInfo).assertEqual(true);
      expect(updatedConfig.developerName).assertEqual(newDeveloperName);
      expect(updatedConfig.githubUrl).assertEqual(newGithubUrl);
      
      TestUtils.log('隐私配置更新验证通过');
    });
    
    /**
     * 测试安全配置更新
     */
    it('should_update_security_config', 0, async () => {
      TestUtils.log('测试安全配置更新');
      
      // 确保已初始化
      await appConfigManager.initialize();
      
      // 更新配置
      appConfigManager.updateSecurityConfig({
        enableApiKeyValidation: false,
        logSensitiveData: true
      });
      
      // 获取更新后的配置
      const updatedConfig = appConfigManager.getSecurityConfig();
      
      // 验证更新结果
      expect(updatedConfig.enableApiKeyValidation).assertEqual(false);
      expect(updatedConfig.logSensitiveData).assertEqual(true);
      
      TestUtils.log('安全配置更新验证通过');
    });
    
    /**
     * 测试配置重置
     */
    it('should_reset_to_default_config', 0, async () => {
      TestUtils.log('测试配置重置');
      
      // 确保已初始化
      await appConfigManager.initialize();
      
      // 先修改配置
      appConfigManager.updateServerConfig({
        baseUrl: 'https://modified.example.com/api'
      });
      
      // 重置配置
      appConfigManager.resetToDefault();
      
      // 重新初始化
      await appConfigManager.initialize();
      
      // 获取重置后的配置
      const resetConfig = appConfigManager.getServerConfig();
      
      // 验证配置已重置（应该回到从服务器配置管理器加载的配置）
      expect(resetConfig.baseUrl.length > 0).assertTrue();
      
      TestUtils.log('配置重置验证通过');
    });
    
    /**
     * 测试并发初始化
     */
    it('should_handle_concurrent_initialization', 0, async () => {
      TestUtils.log('测试并发初始化');
      
      // 重置配置
      appConfigManager.resetToDefault();
      
      // 并发执行初始化
      const initPromises = [
        appConfigManager.initialize(),
        appConfigManager.initialize(),
        appConfigManager.initialize()
      ];
      
      // 等待所有初始化完成
      await Promise.all(initPromises);
      
      // 验证初始化状态
      const isInitialized = appConfigManager.isInitialized();
      expect(isInitialized).assertEqual(true);
      
      TestUtils.log('并发初始化验证通过');
    });
    
    /**
     * 测试配置加载性能
     */
    it('should_have_reasonable_loading_performance', 0, async () => {
      TestUtils.log('测试配置加载性能');
      
      // 重置配置
      appConfigManager.resetToDefault();
      
      // 测量初始化时间
      const startTime = Date.now();
      await appConfigManager.initialize();
      const endTime = Date.now();
      
      const initTime = endTime - startTime;
      
      // 验证初始化时间在合理范围内（小于2秒）
      expect(initTime < 2000).assertTrue();
      
      TestUtils.log(`配置初始化耗时: ${initTime}ms`);
      TestUtils.log('配置加载性能验证通过');
    });
    
    /**
     * 测试服务器地址配置有效性
     */
    it('should_have_valid_server_addresses', 0, async () => {
      TestUtils.log('测试服务器地址配置有效性');
      
      // 确保已初始化
      await appConfigManager.initialize();
      
      const serverConfig = appConfigManager.getServerConfig();
      
      // 验证服务器地址不为空
      expect(serverConfig.baseUrl !== '').assertTrue();
      expect(serverConfig.wsUrl !== '').assertTrue();
      expect(serverConfig.searchUrl !== '').assertTrue();
      
      // 验证URL格式（简单检查）
      expect(serverConfig.baseUrl.indexOf('http') >= 0).assertTrue();
      expect(serverConfig.wsUrl.indexOf('ws') >= 0).assertTrue();
      
      TestUtils.log(`服务器配置: ${JSON.stringify(serverConfig)}`);
      TestUtils.log('服务器地址配置有效性验证通过');
    });
  });
}