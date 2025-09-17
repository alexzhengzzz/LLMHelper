import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { APIManager } from '../main/ets/services/APIManager';
import { AutoTTSService, PlaybackState } from '../main/ets/services/AutoTTSService';
import { SearchDecisionEngine, SearchCategory } from '../main/ets/services/SearchDecisionEngine';
import { MessageEnhancer } from '../main/ets/services/MessageEnhancer';
import { AnimationManager, AnimationType } from '../main/ets/animations/AnimationManager';
import { PromptRecommendationManager } from '../main/ets/utils/PromptRecommendationManager';

/**
 * 应用集成测试套件
 * 测试各个服务之间的协作和完整的应用流程
 */
export default function integrationTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('IntegrationTest');

  describe('IntegrationTest', () => {
    let apiManager: APIManager;
    let autoTTS: AutoTTSService;
    let searchEngine: SearchDecisionEngine;
    let messageEnhancer: MessageEnhancer;
    let animationManager: AnimationManager;
    let promptManager: PromptRecommendationManager;

    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化集成测试环境');

      // 初始化各个服务
      apiManager = APIManager.getInstance();
      autoTTS = AutoTTSService.getInstance();
      searchEngine = SearchDecisionEngine.getInstance();
      messageEnhancer = new MessageEnhancer();
      animationManager = AnimationManager.getInstance();
      promptManager = PromptRecommendationManager.getInstance();

      // 初始化所有服务
      await initializeAllServices();

      await TestUtils.sleep(1000);
    });

    afterAll(async () => {
      await cleanupAllServices();
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
     * 初始化所有服务
     */
    async function initializeAllServices(): Promise<void> {
      TestUtils.log('初始化所有服务');

      try {
        // 初始化API管理器
        const apiInitialized = await apiManager.initialize();
        TestUtils.log(`API管理器初始化: ${apiInitialized}`);

        // 初始化自动TTS服务
        const ttsInitialized = await autoTTS.initialize();
        TestUtils.log(`TTS服务初始化: ${ttsInitialized}`);

        // 初始化动画管理器
        const animationConfig = animationManager.getConfig();
        TestUtils.log(`动画管理器配置: ${JSON.stringify(animationConfig)}`);

        // 初始化提示词推荐管理器
        const promptConfig = promptManager.getConfig();
        TestUtils.log(`提示词推荐配置: ${JSON.stringify(promptConfig)}`);

      } catch (error) {
        TestUtils.error(`服务初始化失败: ${(error as Error).message}`);
      }
    }

    /**
     * 清理所有服务
     */
    async function cleanupAllServices(): Promise<void> {
      TestUtils.log('清理所有服务');

      try {
        await autoTTS.destroy();
        TestUtils.log('TTS服务已清理');
      } catch (error) {
        TestUtils.error(`TTS服务清理失败: ${(error as Error).message}`);
      }
    }

    /**
     * 测试完整的消息处理流程
     */
    it('should handle complete message processing workflow', async () => {
      TestUtils.log('测试完整消息处理流程');

      // 模拟用户输入
      const userMessage = '今天天气怎么样？';

      // 1. 搜索决策
      const searchDecision = searchEngine.shouldSearch(userMessage, true);
      TestUtils.log(`搜索决策: ${JSON.stringify(searchDecision)}`);

      // 验证搜索决策
      expect(searchDecision.shouldSearch).assertTrue();
      expect(searchDecision.category).assertEqual(SearchCategory.REAL_TIME);
      expect(searchDecision.confidence > 0).assertTrue();

      // 2. 消息增强（模拟搜索结果）
      const enhancedMessage = messageEnhancer.enhanceMessage(userMessage, searchDecision);
      TestUtils.log(`增强消息: ${JSON.stringify(enhancedMessage)}`);

      // 验证消息增强
      expect(enhancedMessage.originalMessage).assertEqual(userMessage);
      expect(enhancedMessage.searchUsed).assertEqual(searchDecision.shouldSearch);

      // 3. 播放用户消息（语音反馈）
      const ttsTaskId = await autoTTS.addPlaybackTask(userMessage, 'msg_001', 1);
      TestUtils.log(`TTS任务ID: ${ttsTaskId}`);

      // 验证TTS任务创建
      expect(ttsTaskId.length > 0).assertTrue();

      // 4. 触发动画
      animationManager.startAnimation(AnimationType.MESSAGE_SENT);
      const animationState = animationManager.getAnimationState(AnimationType.MESSAGE_SENT);
      TestUtils.log(`动画状态: ${animationState}`);

      TestUtils.log('完整消息处理流程测试通过');
    });

    /**
     * 测试语音交互流程
     */
    it('should handle voice interaction workflow', async () => {
      TestUtils.log('测试语音交互流程');

      // 1. 开始语音录制动画
      animationManager.startAnimation(AnimationType.VOICE_RECORDING);
      await TestUtils.sleep(200);

      // 2. 模拟语音识别结果
      const voiceText = '帮我写一个Hello World程序';

      // 3. 搜索决策
      const searchDecision = searchEngine.shouldSearch(voiceText, true);
      TestUtils.log(`语音搜索决策: ${JSON.stringify(searchDecision)}`);

      // 验证不需要搜索（编程问题）
      expect(searchDecision.shouldSearch).assertFalse();

      // 4. 消息增强
      const enhancedMessage = messageEnhancer.enhanceMessage(voiceText, searchDecision);
      TestUtils.log(`语音消息增强: ${JSON.stringify(enhancedMessage)}`);

      // 5. 播放确认音效
      await autoTTS.playMessage('好的，我来帮您写一个Hello World程序', 'voice_confirm');
      await TestUtils.sleep(300);

      // 6. 停止语音录制动画
      animationManager.stopAnimation(AnimationType.VOICE_RECORDING);

      // 7. 开始处理动画
      animationManager.startAnimation(AnimationType.PROCESSING);
      await TestUtils.sleep(500);

      // 8. 完成动画
      animationManager.stopAnimation(AnimationType.PROCESSING);
      animationManager.startAnimation(AnimationType.SUCCESS);

      TestUtils.log('语音交互流程测试通过');
    });

    /**
     * 测试深度思考流程
     */
    it('should handle deep thinking workflow', async () => {
      TestUtils.log('测试深度思考流程');

      const complexQuestion = '请详细分析人工智能的未来发展趋势，包括技术挑战、应用场景和社会影响。';

      // 1. 开始深度思考动画
      animationManager.startAnimation(AnimationType.DEEP_THINKING);
      await TestUtils.sleep(200);

      // 2. 搜索决策（复杂问题可能需要搜索）
      const searchDecision = searchEngine.shouldSearch(complexQuestion, true);
      TestUtils.log(`深度思考搜索决策: ${JSON.stringify(searchDecision)}`);

      // 3. 消息增强
      const enhancedMessage = messageEnhancer.enhanceMessage(complexQuestion, searchDecision);

      // 4. 分阶段思考动画
      const thinkingStages = ['分析问题', '搜索信息', '整理思路', '生成答案'];
      for (const stage of thinkingStages) {
        TestUtils.log(`思考阶段: ${stage}`);
        await TestUtils.sleep(300);
      }

      // 5. 完成思考
      animationManager.stopAnimation(AnimationType.DEEP_THINKING);
      animationManager.startAnimation(AnimationType.SUCCESS);

      // 6. 播放完整答案
      const answer = '根据我的分析，人工智能的未来发展趋势包括...';
      await autoTTS.addPlaybackTask(answer, 'deep_thinking_answer', 5);

      TestUtils.log('深度思考流程测试通过');
    });

    /**
     * 测试错误处理和恢复流程
     */
    it('should handle error and recovery workflow', async () => {
      TestUtils.log('测试错误处理和恢复流程');

      // 1. 模拟网络错误
      animationManager.startAnimation(AnimationType.ERROR);
      await TestUtils.sleep(200);

      // 2. 错误提示
      const errorMessage = '网络连接失败，正在尝试重新连接...';
      await autoTTS.playMessage(errorMessage, 'error_message');

      // 3. 重试机制
      let retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        retryCount++;
        TestUtils.log(`重试第 ${retryCount} 次`);

        // 模拟重试动画
        animationManager.startAnimation(AnimationType.LOADING);
        await TestUtils.sleep(500);

        // 模拟重试成功
        if (retryCount === maxRetries) {
          animationManager.stopAnimation(AnimationType.LOADING);
          animationManager.startAnimation(AnimationType.SUCCESS);
          break;
        }
      }

      // 4. 恢复确认
      const recoveryMessage = '网络连接已恢复，服务正常运行';
      await autoTTS.playMessage(recoveryMessage, 'recovery_message');

      TestUtils.log('错误处理和恢复流程测试通过');
    });

    /**
     * 测试用户偏好学习流程
     */
    it('should handle user preference learning workflow', async () => {
      TestUtils.log('测试用户偏好学习流程');

      // 1. 模拟用户使用不同类型的提示词
      const userPrompts = [
        { text: '帮我优化这段JavaScript代码', category: 'programming' },
        { text: '写一个创意故事', category: 'creative' },
        { text: '解释量子计算的基本原理', category: 'technical' },
        { text: '分析最新的科技趋势', category: 'analysis' }
      ];

      // 2. 记录用户使用习惯
      for (let i = 0; i < 3; i++) {
        for (const prompt of userPrompts) {
          await promptManager.recordUsage(`prompt_${i}`, prompt.category, false);

          // 模拟使用反馈
          animationManager.startAnimation(AnimationType.BUTTON_PRESS);
          await TestUtils.sleep(100);
          animationManager.stopAnimation(AnimationType.BUTTON_PRESS);
        }
      }

      // 3. 获取个性化推荐
      const recommendations = await promptManager.getRecommendations('programming', 3);
      TestUtils.log(`个性化推荐结果: ${JSON.stringify(recommendations)}`);

      // 验证推荐结果
      expect(recommendations.length > 0).assertTrue();

      // 4. 验证推荐包含用户偏好
      const programmingRecommendations = recommendations.filter(r => r.category === 'programming');
      expect(programmingRecommendations.length > 0).assertTrue();

      TestUtils.log('用户偏好学习流程测试通过');
    });

    /**
     * 测试多模态交互流程
     */
    it('should handle multimodal interaction workflow', async () => {
      TestUtils.log('测试多模态交互流程');

      // 1. 文本输入
      const textMessage = '请帮我分析这张图片中的内容';

      // 2. 搜索决策
      const searchDecision = searchEngine.shouldSearch(textMessage, true);

      // 3. 消息增强
      const enhancedMessage = messageEnhancer.enhanceMessage(textMessage, searchDecision);

      // 4. 图片上传动画
      animationManager.startAnimation(AnimationType.FILE_UPLOAD);
      await TestUtils.sleep(300);

      // 5. 分析处理动画
      animationManager.stopAnimation(AnimationType.FILE_UPLOAD);
      animationManager.startAnimation(AnimationType.PROCESSING);
      await TestUtils.sleep(500);

      // 6. 语音播报结果
      const analysisResult = '我已经分析了您上传的图片，这是一张关于...的图片';
      await autoTTS.playMessage(analysisResult, 'image_analysis');

      // 7. 完成动画
      animationManager.stopAnimation(AnimationType.PROCESSING);
      animationManager.startAnimation(AnimationType.SUCCESS);

      TestUtils.log('多模态交互流程测试通过');
    });

    /**
     * 测试设置和配置流程
     */
    it('should handle settings and configuration workflow', async () => {
      TestUtils.log('测试设置和配置流程');

      // 1. 更新TTS设置
      await autoTTS.updateSettings({
        muted: false,
        speed: 1.2,
        volume: 0.8,
        pitch: 1.0,
        language: 'zh-CN',
        autoPlayOnReceive: true
      });

      // 2. 更新动画配置
      animationManager.setPerformanceConfig({
        maxConcurrentAnimations: 5,
        defaultDuration: 300,
        enableHardwareAcceleration: true,
        frameRate: 60
      });

      // 3. 更新推荐配置
      const recommendationConfig = promptManager.getConfig();
      recommendationConfig.maxRecommendations = 8;
      recommendationConfig.enablePersonalization = true;
      promptManager.setConfig(recommendationConfig);

      // 4. 验证配置应用
      const ttsSettings = autoTTS.getSettings();
      expect(ttsSettings.speed).assertEqual(1.2);
      expect(ttsSettings.volume).assertEqual(0.8);

      const animationConfig = animationManager.getPerformanceConfig();
      expect(animationConfig.maxConcurrentAnimations).assertEqual(5);

      const promptConfig = promptManager.getConfig();
      expect(promptConfig.maxRecommendations).assertEqual(8);

      // 5. 播放确认消息
      await autoTTS.playMessage('设置已更新完成', 'settings_confirm');

      TestUtils.log('设置和配置流程测试通过');
    });

    /**
     * 测试性能监控流程
     */
    it('should handle performance monitoring workflow', async () => {
      TestUtils.log('测试性能监控流程');

      // 1. 启用性能监控
      animationManager.enablePerformanceMonitoring(true);

      // 2. 模拟高负载场景
      const concurrentOperations = [];
      for (let i = 0; i < 10; i++) {
        concurrentOperations.push(
          new Promise<void>(async (resolve) => {
            // 模拟消息处理
            const message = `性能测试消息 ${i}`;
            const searchDecision = searchEngine.shouldSearch(message, true);
            const enhancedMessage = messageEnhancer.enhanceMessage(message, searchDecision);

            // 模拟动画
            animationManager.startAnimation(AnimationType.LOADING);
            await TestUtils.sleep(100);
            animationManager.stopAnimation(AnimationType.LOADING);

            resolve();
          })
        );
      }

      // 3. 等待所有操作完成
      await Promise.all(concurrentOperations);

      // 4. 获取性能指标
      const performance = animationManager.getPerformanceMetrics();
      TestUtils.log(`性能指标: ${JSON.stringify(performance)}`);

      // 5. 验证性能数据
      expect(performance !== null).assertTrue();
      if (performance) {
        expect(performance.averageFrameTime >= 0).assertTrue();
        expect(performance.maxFrameTime >= 0).assertTrue();
        expect(performance.droppedFrames >= 0).assertTrue();
      }

      // 6. 获取动画统计
      const animationStats = animationManager.getStatistics();
      TestUtils.log(`动画统计: ${JSON.stringify(animationStats)}`);

      TestUtils.log('性能监控流程测试通过');
    });

    /**
     * 测试数据持久化流程
     */
    it('should handle data persistence workflow', async () => {
      TestUtils.log('测试数据持久化流程');

      // 1. 记录一些用户数据
      await promptManager.recordUsage('persistence_test_1', 'programming', false);
      await promptManager.recordUsage('persistence_test_2', 'general', true);

      // 2. 保存数据
      await promptManager.saveData();
      TestUtils.log('数据保存完成');

      // 3. 模拟应用重启
      await TestUtils.sleep(100);

      // 4. 重新加载数据
      await promptManager.loadData();
      TestUtils.log('数据加载完成');

      // 5. 验证数据持久化
      const stats1 = promptManager.getPromptUsageStats('persistence_test_1');
      const stats2 = promptManager.getPromptUsageStats('persistence_test_2');

      expect(stats1 !== null).assertTrue();
      expect(stats2 !== null).assertTrue();

      if (stats1 && stats2) {
        expect(stats1.usageCount > 0).assertTrue();
        expect(stats2.usageCount > 0).assertTrue();
        expect(stats2.voiceTriggerUsageCount > 0).assertTrue();
      }

      // 6. 播放确认消息
      await autoTTS.playMessage('用户数据已保存', 'persistence_confirm');

      TestUtils.log('数据持久化流程测试通过');
    });

    /**
     * 测试并发处理流程
     */
    it('should handle concurrent processing workflow', async () => {
      TestUtils.log('测试并发处理流程');

      // 1. 创建并发任务
      const concurrentTasks = [];
      for (let i = 0; i < 5; i++) {
        concurrentTasks.push(
          new Promise<void>(async (resolve) => {
            const message = `并发测试消息 ${i}`;

            // 搜索决策
            const searchDecision = searchEngine.shouldSearch(message, true);

            // 消息增强
            const enhancedMessage = messageEnhancer.enhanceMessage(message, searchDecision);

            // 动画处理
            animationManager.startAnimation(AnimationType.PROCESSING);
            await TestUtils.sleep(200);
            animationManager.stopAnimation(AnimationType.PROCESSING);

            // 语音反馈
            await autoTTS.addPlaybackTask(`任务 ${i} 完成`, `concurrent_${i}`, 1);

            resolve();
          })
        );
      }

      // 2. 同时启动所有任务
      await Promise.all(concurrentTasks);

      // 3. 验证系统稳定性
      const ttsState = autoTTS.getCurrentState();
      expect(ttsState === PlaybackState.IDLE || ttsState === PlaybackState.PLAYING).assertTrue();

      const animationPerformance = animationManager.getPerformanceMetrics();
      expect(animationPerformance !== null).assertTrue();

      TestUtils.log('并发处理流程测试通过');
    });
  });
}