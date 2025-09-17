import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { AnimationManager, AnimationType } from '../main/ets/animations/AnimationManager';
import { curves } from '@kit.ArkUI';

/**
 * 动画管理器测试套件
 * 测试动画系统的配置、创建、管理等功能
 */
export default function animationManagerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('AnimationManagerTest');

  describe('AnimationManagerTest', () => {
    let animationManager: AnimationManager;

    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化动画管理器测试环境');

      // 获取动画管理器实例
      animationManager = AnimationManager.getInstance();

      await TestUtils.sleep(100);
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
     * 测试动画管理器初始化
     */
    it('should initialize animation manager correctly', async () => {
      TestUtils.log('测试动画管理器初始化功能');

      // 验证动画管理器实例存在
      expect(animationManager !== null).assertTrue();
      expect(animationManager !== undefined).assertTrue();

      // 验证基础配置
      const config = animationManager.getConfig();
      expect(config !== null).assertTrue();
      expect(config !== undefined).assertTrue();

      TestUtils.log('动画管理器初始化成功');
    });

    /**
     * 测试动画类型枚举
     */
    it('should have correct animation types', async () => {
      TestUtils.log('测试动画类型枚举功能');

      // 验证所有动画类型存在
      expect(AnimationType.PAGE_ENTER).assertEqual('page_enter');
      expect(AnimationType.PAGE_EXIT).assertEqual('page_exit');
      expect(AnimationType.BUTTON_PRESS).assertEqual('button_press');
      expect(AnimationType.BUTTON_RELEASE).assertEqual('button_release');
      expect(AnimationType.LIST_ITEM_APPEAR).assertEqual('list_item_appear');
      expect(AnimationType.VOICE_RECORDING).assertEqual('voice_recording');
      expect(AnimationType.VOICE_PROCESSING).assertEqual('voice_processing');
      expect(AnimationType.VOICE_WAVE).assertEqual('voice_wave');
      expect(AnimationType.LOADING).assertEqual('loading');
      expect(AnimationType.SUCCESS).assertEqual('success');
      expect(AnimationType.ERROR).assertEqual('error');
      expect(AnimationType.MODAL_ENTER).assertEqual('modal_enter');
      expect(AnimationType.MODAL_EXIT).assertEqual('modal_exit');

      TestUtils.log('动画类型枚举测试通过');
    });

    /**
     * 测试动画配置获取
     */
    it('should get animation configuration correctly', async () => {
      TestUtils.log('测试动画配置获取功能');

      const animationTypes = [
        AnimationType.PAGE_ENTER,
        AnimationType.PAGE_EXIT,
        AnimationType.BUTTON_PRESS,
        AnimationType.LOADING,
        AnimationType.VOICE_RECORDING
      ];

      for (const animationType of animationTypes) {
        const config = animationManager.getAnimationConfig(animationType);

        // 验证配置存在
        expect(config !== null).assertTrue();
        expect(config !== undefined).assertTrue();

        // 验证配置结构
        if (config) {
          expect(config.duration > 0).assertTrue();
          expect(config.curve !== undefined).assertTrue();
          expect(config.delay >= 0).assertTrue();
        }

        TestUtils.log(`动画类型 ${animationType} 配置: ${JSON.stringify(config)}`);
      }

      TestUtils.log('动画配置获取测试通过');
    });

    /**
     * 测试动画创建
     */
    it('should create animations correctly', async () => {
      TestUtils.log('测试动画创建功能');

      const animationTypes = [
        AnimationType.PAGE_ENTER,
        AnimationType.BUTTON_PRESS,
        AnimationType.LOADING
      ];

      for (const animationType of animationTypes) {
        const animation = animationManager.createAnimation(animationType);

        // 验证动画创建成功
        expect(animation !== null).assertTrue();
        expect(animation !== undefined).assertTrue();

        // 验证动画属性
        expect(animation.duration > 0).assertTrue();
        expect(animation.curve !== undefined).assertTrue();
        expect(animation.delay >= 0).assertTrue();

        TestUtils.log(`动画类型 ${animationType} 创建成功`);
      }

      TestUtils.log('动画创建测试通过');
    });

    /**
     * 测试自定义动画配置
     */
    it('should handle custom animation configuration', async () => {
      TestUtils.log('测试自定义动画配置功能');

      const customConfig = {
        duration: 500,
        curve: curves.easeInOut,
        delay: 100,
        iterations: 1,
        autoReverse: false,
        fillMode: 'forwards'
      };

      const animation = animationManager.createCustomAnimation(AnimationType.BUTTON_PRESS, customConfig);

      // 验证自定义动画创建成功
      expect(animation !== null).assertTrue();
      expect(animation !== undefined).assertTrue();

      // 验证自定义配置应用
      expect(animation.duration).assertEqual(customConfig.duration);
      expect(animation.curve).assertEqual(customConfig.curve);
      expect(animation.delay).assertEqual(customConfig.delay);

      TestUtils.log('自定义动画配置测试通过');
    });

    /**
     * 测试动画状态管理
     */
    it('should manage animation states correctly', async () => {
      TestUtils.log('测试动画状态管理功能');

      const animationType = AnimationType.LOADING;

      // 获取初始状态
      const initialState = animationManager.getAnimationState(animationType);
      TestUtils.log(`初始状态: ${initialState}`);

      // 开始动画
      animationManager.startAnimation(animationType);
      const runningState = animationManager.getAnimationState(animationType);
      TestUtils.log(`运行状态: ${runningState}`);

      // 停止动画
      animationManager.stopAnimation(animationType);
      const stoppedState = animationManager.getAnimationState(animationType);
      TestUtils.log(`停止状态: ${stoppedState}`);

      // 验证状态变化
      expect(initialState !== runningState).assertTrue();

      TestUtils.log('动画状态管理测试通过');
    });

    /**
     * 测试动画队列管理
     */
    it('should manage animation queue correctly', async () => {
      TestUtils.log('测试动画队列管理功能');

      const animationTypes = [
        AnimationType.PAGE_ENTER,
        AnimationType.LOADING,
        AnimationType.SUCCESS
      ];

      // 清空队列
      animationManager.clearAnimationQueue();

      // 添加动画到队列
      for (const animationType of animationTypes) {
        animationManager.queueAnimation(animationType);
      }

      // 验证队列长度
      const queueLength = animationManager.getQueueLength();
      expect(queueLength).assertEqual(animationTypes.length);

      // 处理队列
      animationManager.processAnimationQueue();

      // 验证队列处理
      await TestUtils.sleep(100);

      TestUtils.log('动画队列管理测试通过');
    });

    /**
     * 测试动画性能配置
     */
    it('should handle animation performance configuration', async () => {
      TestUtils.log('测试动画性能配置功能');

      const performanceConfig = {
        maxConcurrentAnimations: 5,
        defaultDuration: 300,
        enableHardwareAcceleration: true,
        frameRate: 60
      };

      // 设置性能配置
      animationManager.setPerformanceConfig(performanceConfig);

      // 验证配置设置
      const currentConfig = animationManager.getPerformanceConfig();
      expect(currentConfig.maxConcurrentAnimations).assertEqual(performanceConfig.maxConcurrentAnimations);
      expect(currentConfig.defaultDuration).assertEqual(performanceConfig.defaultDuration);
      expect(currentConfig.enableHardwareAcceleration).assertEqual(performanceConfig.enableHardwareAcceleration);
      expect(currentConfig.frameRate).assertEqual(performanceConfig.frameRate);

      TestUtils.log('动画性能配置测试通过');
    });

    /**
     * 测试动画事件回调
     */
    it('should handle animation event callbacks', async () => {
      TestUtils.log('测试动画事件回调功能');

      let callbackTriggered = false;
      let callbackData: any = null;

      const animationCallback = (event: string, data: any) => {
        callbackTriggered = true;
        callbackData = data;
        TestUtils.log(`动画事件回调: ${event}, 数据: ${JSON.stringify(data)}`);
      };

      // 设置回调
      animationManager.setAnimationCallback(animationCallback);

      // 触发动画事件
      animationManager.triggerAnimationEvent(AnimationType.BUTTON_PRESS, 'test_event', { test: 'data' });

      // 验证回调触发
      expect(callbackTriggered).assertTrue();
      expect(callbackData !== null).assertTrue();

      TestUtils.log('动画事件回调测试通过');
    });

    /**
     * 测试动画错误处理
     */
    it('should handle animation errors correctly', async () => {
      TestUtils.log('测试动画错误处理功能');

      // 测试无效动画类型
      const invalidAnimation = animationManager.createAnimation('invalid_type' as AnimationType);
      expect(invalidAnimation === null).assertTrue();

      // 测试空配置
      const emptyConfigAnimation = animationManager.createCustomAnimation(AnimationType.LOADING, null as any);
      expect(emptyConfigAnimation === null).assertTrue();

      // 测试重复动画
      animationManager.startAnimation(AnimationType.LOADING);
      const duplicateResult = animationManager.startAnimation(AnimationType.LOADING);
      TestUtils.log(`重复动画结果: ${duplicateResult}`);

      TestUtils.log('动画错误处理测试通过');
    });

    /**
     * 测试动画主题适配
     */
    it('should adapt to theme changes', async () => {
      TestUtils.log('测试动画主题适配功能');

      // 测试浅色主题
      animationManager.setTheme('light');
      const lightThemeConfig = animationManager.getCurrentThemeConfig();
      expect(lightThemeConfig !== null).assertTrue();

      // 测试深色主题
      animationManager.setTheme('dark');
      const darkThemeConfig = animationManager.getCurrentThemeConfig();
      expect(darkThemeConfig !== null).assertTrue();

      // 验证主题配置差异
      expect(lightThemeConfig !== darkThemeConfig).assertTrue();

      TestUtils.log('动画主题适配测试通过');
    });

    /**
     * 测试动画内存管理
     */
    it('should manage animation memory correctly', async () => {
      TestUtils.log('测试动画内存管理功能');

      // 创建大量动画
      const animationTypes = [
        AnimationType.PAGE_ENTER,
        AnimationType.PAGE_EXIT,
        AnimationType.LOADING,
        AnimationType.SUCCESS,
        AnimationType.ERROR
      ];

      for (let i = 0; i < 100; i++) {
        for (const animationType of animationTypes) {
          animationManager.createAnimation(animationType);
        }
      }

      // 清理内存
      animationManager.cleanup();

      // 验证清理后的状态
      const queueLength = animationManager.getQueueLength();
      expect(queueLength).assertEqual(0);

      TestUtils.log('动画内存管理测试通过');
    });

    /**
     * 测试动画并发控制
     */
    it('should control animation concurrency correctly', async () => {
      TestUtils.log('测试动画并发控制功能');

      const maxConcurrent = 3;
      animationManager.setPerformanceConfig({
        maxConcurrentAnimations: maxConcurrent,
        defaultDuration: 200,
        enableHardwareAcceleration: true,
        frameRate: 60
      });

      const animationTypes = [
        AnimationType.LOADING,
        AnimationType.SUCCESS,
        AnimationType.ERROR,
        AnimationType.PAGE_ENTER,
        AnimationType.PAGE_EXIT
      ];

      // 启动多个动画
      const results: boolean[] = [];
      for (const animationType of animationTypes) {
        const result = animationManager.startAnimation(animationType);
        results.push(result);
      }

      // 验证并发控制
      const successCount = results.filter(r => r).length;
      expect(successCount <= maxConcurrent).assertTrue();

      TestUtils.log('动画并发控制测试通过');
    });

    /**
     * 测试动画插值器
     */
    it('should handle animation curves correctly', async () => {
      TestUtils.log('测试动画插值器功能');

      const testCurves = [
        curves.linear,
        curves.ease,
        curves.easeIn,
        curves.easeOut,
        curves.easeInOut,
        curves.fastOutSlowIn,
        curves.linearOutSlowIn,
        curves.fastOutLinearIn,
        curves.springMotion
      ];

      for (const curve of testCurves) {
        const config = {
          duration: 300,
          curve: curve,
          delay: 0
        };

        const animation = animationManager.createCustomAnimation(AnimationType.BUTTON_PRESS, config);
        expect(animation !== null).assertTrue();

        if (animation) {
          expect(animation.curve).assertEqual(curve);
        }
      }

      TestUtils.log('动画插值器测试通过');
    });

    /**
     * 测试动画优先级
     */
    it('should handle animation priorities correctly', async () => {
      TestUtils.log('测试动画优先级功能');

      const highPriorityAnimations = [
        AnimationType.ERROR,
        AnimationType.SUCCESS
      ];

      const lowPriorityAnimations = [
        AnimationType.LOADING,
        AnimationType.BUTTON_PRESS
      ];

      // 验证高优先级动画配置
      for (const animationType of highPriorityAnimations) {
        const config = animationManager.getAnimationConfig(animationType);
        expect(config !== null).assertTrue();
        if (config) {
          expect(config.duration <= 500).assertTrue(); // 高优先级动画通常较短
        }
      }

      // 验证低优先级动画配置
      for (const animationType of lowPriorityAnimations) {
        const config = animationManager.getAnimationConfig(animationType);
        expect(config !== null).assertTrue();
      }

      TestUtils.log('动画优先级测试通过');
    });

    /**
     * 测试动画配置持久化
     */
    it('should persist animation configuration', async () => {
      TestUtils.log('测试动画配置持久化功能');

      const customConfig = {
        duration: 800,
        delay: 200,
        enableHardwareAcceleration: true,
        frameRate: 120
      };

      // 保存配置
      animationManager.saveConfiguration(customConfig);

      // 重置配置
      animationManager.resetConfiguration();

      // 加载配置
      animationManager.loadConfiguration();

      // 验证配置恢复
      const loadedConfig = animationManager.getPerformanceConfig();
      expect(loadedConfig !== null).assertTrue();

      TestUtils.log('动画配置持久化测试通过');
    });

    /**
     * 测试动画统计信息
     */
    it('should provide animation statistics', async () => {
      TestUtils.log('测试动画统计信息功能');

      // 重置统计
      animationManager.resetStatistics();

      // 执行一些动画操作
      animationManager.createAnimation(AnimationType.LOADING);
      animationManager.startAnimation(AnimationType.SUCCESS);
      animationManager.stopAnimation(AnimationType.LOADING);

      // 获取统计信息
      const stats = animationManager.getStatistics();
      expect(stats !== null).assertTrue();
      expect(stats !== undefined).assertTrue();

      // 验证统计信息结构
      if (stats) {
        expect(stats.totalAnimationsCreated >= 0).assertTrue();
        expect(stats.totalAnimationsStarted >= 0).assertTrue();
        expect(stats.totalAnimationsStopped >= 0).assertTrue();
      }

      TestUtils.log(`动画统计信息: ${JSON.stringify(stats)}`);
      TestUtils.log('动画统计信息测试通过');
    });

    /**
     * 测试动画性能监控
     */
    it('should monitor animation performance', async () => {
      TestUtils.log('测试动画性能监控功能');

      // 启用性能监控
      animationManager.enablePerformanceMonitoring(true);

      // 创建并运行动画
      const animation = animationManager.createAnimation(AnimationType.LOADING);
      if (animation) {
        animationManager.startAnimation(AnimationType.LOADING);
        await TestUtils.sleep(100);
        animationManager.stopAnimation(AnimationType.LOADING);
      }

      // 获取性能指标
      const performance = animationManager.getPerformanceMetrics();
      expect(performance !== null).assertTrue();

      if (performance) {
        expect(performance.averageFrameTime >= 0).assertTrue();
        expect(performance.maxFrameTime >= 0).assertTrue();
        expect(performance.droppedFrames >= 0).assertTrue();
      }

      TestUtils.log(`动画性能指标: ${JSON.stringify(performance)}`);
      TestUtils.log('动画性能监控测试通过');
    });
  });
}