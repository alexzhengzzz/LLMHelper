/**
 * 服务器配置变更测试
 * 测试ServerConfigManager的配置变更监听机制
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { ServerConfigManager, ServerEndpoint } from '../main/ets/utils/ServerConfigManager';
import { Logger } from '../main/ets/utils/Logger';

export default function serverConfigChangeTest() {
  describe('ServerConfigChangeTest', () => {
    let serverConfigManager: ServerConfigManager;
    let changeNotifications: ServerEndpoint[] = [];
    let testListener: (config: ServerEndpoint) => void;

    beforeEach(() => {
      Logger.info('ServerConfigChangeTest', '开始测试用例');
      serverConfigManager = ServerConfigManager.getInstance();
      changeNotifications = [];
      
      // 创建测试监听器
      testListener = (config: ServerEndpoint) => {
        Logger.info('ServerConfigChangeTest', `收到配置变更通知: ${config.ip}:${config.port}`);
        changeNotifications.push(config);
      };
    });

    afterEach(() => {
      // 清理监听器
      if (testListener) {
        serverConfigManager.removeConfigChangeListener(testListener);
      }
      Logger.info('ServerConfigChangeTest', '测试用例结束');
    });

    /**
     * 测试添加配置变更监听器
     */
    it('should_add_config_change_listener', 0, () => {
      Logger.info('ServerConfigChangeTest', '测试添加配置变更监听器');
      
      // 添加监听器不应该抛出错误
      expect(() => {
        serverConfigManager.addConfigChangeListener(testListener);
      }).not.toThrow();
      
      Logger.info('ServerConfigChangeTest', '配置变更监听器添加成功');
    });

    /**
     * 测试移除配置变更监听器
     */
    it('should_remove_config_change_listener', 0, () => {
      Logger.info('ServerConfigChangeTest', '测试移除配置变更监听器');
      
      // 先添加监听器
      serverConfigManager.addConfigChangeListener(testListener);
      
      // 移除监听器不应该抛出错误
      expect(() => {
        serverConfigManager.removeConfigChangeListener(testListener);
      }).not.toThrow();
      
      Logger.info('ServerConfigChangeTest', '配置变更监听器移除成功');
    });

    /**
     * 测试配置变更通知
     */
    it('should_notify_config_change', 0, async () => {
      Logger.info('ServerConfigChangeTest', '测试配置变更通知');
      
      // 添加监听器
      serverConfigManager.addConfigChangeListener(testListener);
      
      // 初始化ServerConfigManager
      await serverConfigManager.initialize();
      
      // 设置新的服务器配置
      const newConfig: ServerEndpoint = {
        ip: '192.168.1.100',
        port: 8080,
        protocol: 'http',
        wsProtocol: 'ws',
        description: '测试服务器'
      };
      
      // 设置配置应该触发通知
      await serverConfigManager.setCurrentServer(newConfig);
      
      // 验证通知被触发
      expect(changeNotifications.length).assertEqual(1);
      expect(changeNotifications[0].ip).assertEqual('192.168.1.100');
      expect(changeNotifications[0].port).assertEqual(8080);
      
      Logger.info('ServerConfigChangeTest', '配置变更通知测试成功');
    });

    /**
     * 测试多个监听器同时接收通知
     */
    it('should_notify_multiple_listeners', 0, async () => {
      Logger.info('ServerConfigChangeTest', '测试多个监听器同时接收通知');
      
      let secondListenerNotified = false;
      const secondListener = (config: ServerEndpoint) => {
        secondListenerNotified = true;
        Logger.info('ServerConfigChangeTest', `第二个监听器收到通知: ${config.ip}:${config.port}`);
      };
      
      // 添加两个监听器
      serverConfigManager.addConfigChangeListener(testListener);
      serverConfigManager.addConfigChangeListener(secondListener);
      
      // 初始化ServerConfigManager
      await serverConfigManager.initialize();
      
      // 设置新的服务器配置
      const newConfig: ServerEndpoint = {
        ip: '127.0.0.1',
        port: 9090,
        protocol: 'http',
        wsProtocol: 'ws',
        description: '本地测试服务器'
      };
      
      await serverConfigManager.setCurrentServer(newConfig);
      
      // 验证两个监听器都收到通知
      expect(changeNotifications.length).assertEqual(1);
      expect(secondListenerNotified).assertTrue();
      
      // 清理第二个监听器
      serverConfigManager.removeConfigChangeListener(secondListener);
      
      Logger.info('ServerConfigChangeTest', '多个监听器通知测试成功');
    });

    /**
     * 测试重置配置也会触发通知
     */
    it('should_notify_on_reset_to_default', 0, async () => {
      Logger.info('ServerConfigChangeTest', '测试重置配置通知');
      
      // 添加监听器
      serverConfigManager.addConfigChangeListener(testListener);
      
      // 初始化ServerConfigManager
      await serverConfigManager.initialize();
      
      // 重置为默认配置
      await serverConfigManager.resetToDefault();
      
      // 验证通知被触发
      expect(changeNotifications.length).assertEqual(1);
      expect(changeNotifications[0].ip).assertEqual('localhost'); // 默认IP改为localhost
      expect(changeNotifications[0].port).assertEqual(8080); // 默认端口
      
      Logger.info('ServerConfigChangeTest', '重置配置通知测试成功');
    });

    /**
     * 测试监听器异常不影响其他监听器
     */
    it('should_handle_listener_exceptions', 0, async () => {
      Logger.info('ServerConfigChangeTest', '测试监听器异常处理');
      
      // 创建一个会抛出异常的监听器
      const faultyListener = (config: ServerEndpoint) => {
        throw new Error('测试异常');
      };
      
      // 添加正常监听器和异常监听器
      serverConfigManager.addConfigChangeListener(testListener);
      serverConfigManager.addConfigChangeListener(faultyListener);
      
      // 初始化ServerConfigManager
      await serverConfigManager.initialize();
      
      // 设置新配置，不应该因为异常监听器而失败
      const newConfig: ServerEndpoint = {
        ip: '10.0.0.1',
        port: 8080,
        protocol: 'http',
        wsProtocol: 'ws',
        description: '异常测试服务器'
      };
      
      // 这应该成功执行，即使有监听器抛出异常
      await serverConfigManager.setCurrentServer(newConfig);
      
      // 验证正常监听器仍然收到通知
      expect(changeNotifications.length).assertEqual(1);
      expect(changeNotifications[0].ip).assertEqual('10.0.0.1');
      
      // 清理异常监听器
      serverConfigManager.removeConfigChangeListener(faultyListener);
      
      Logger.info('ServerConfigChangeTest', '监听器异常处理测试成功');
    });
  });
}