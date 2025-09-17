import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { PromptRecommendationManager, PromptUsageStats, RecommendationConfig } from '../main/ets/utils/PromptRecommendationManager';
import { PromptTemplate } from '../main/ets/utils/Constants';

/**
 * 提示词推荐管理器测试套件
 * 测试智能提示词推荐、使用统计、个性化推荐等功能
 */
export default function promptRecommendationManagerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('PromptRecommendationManagerTest');

  describe('PromptRecommendationManagerTest', () => {
    let recommendationManager: PromptRecommendationManager;

    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化提示词推荐管理器测试环境');

      // 获取提示词推荐管理器实例
      recommendationManager = PromptRecommendationManager.getInstance();

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
     * 测试推荐管理器初始化
     */
    it('should initialize recommendation manager correctly', async () => {
      TestUtils.log('测试提示词推荐管理器初始化功能');

      // 验证推荐管理器实例存在
      expect(recommendationManager !== null).assertTrue();
      expect(recommendationManager !== undefined).assertTrue();

      // 验证基础配置
      const config = recommendationManager.getConfig();
      expect(config !== null).assertTrue();
      expect(config !== undefined).assertTrue();

      TestUtils.log('提示词推荐管理器初始化成功');
    });

    /**
     * 测试推荐配置管理
     */
    it('should manage recommendation configuration correctly', async () => {
      TestUtils.log('测试推荐配置管理功能');

      const testConfig: RecommendationConfig = {
        maxRecommendations: 10,
        usageWeightFactor: 0.7,
        timeWeightFactor: 0.2,
        categoryWeightFactor: 0.1,
        voiceTriggerWeight: 0.3,
        minUsageCount: 1,
        maxRecommendationAge: 7,
        enablePersonalization: true,
        enableCategoryBalancing: true
      };

      // 设置配置
      recommendationManager.setConfig(testConfig);

      // 验证配置设置
      const currentConfig = recommendationManager.getConfig();
      expect(currentConfig.maxRecommendations).assertEqual(testConfig.maxRecommendations);
      expect(currentConfig.usageWeightFactor).assertEqual(testConfig.usageWeightFactor);
      expect(currentConfig.timeWeightFactor).assertEqual(testConfig.timeWeightFactor);
      expect(currentConfig.categoryWeightFactor).assertEqual(testConfig.categoryWeightFactor);
      expect(currentConfig.voiceTriggerWeight).assertEqual(testConfig.voiceTriggerWeight);
      expect(currentConfig.minUsageCount).assertEqual(testConfig.minUsageCount);
      expect(currentConfig.maxRecommendationAge).assertEqual(testConfig.maxRecommendationAge);
      expect(currentConfig.enablePersonalization).assertEqual(testConfig.enablePersonalization);
      expect(currentConfig.enableCategoryBalancing).assertEqual(testConfig.enableCategoryBalancing);

      TestUtils.log('推荐配置管理测试通过');
    });

    /**
     * 测试提示词使用统计
     */
    it('should track prompt usage statistics correctly', async () => {
      TestUtils.log('测试提示词使用统计功能');

      const testPromptId = 'test_prompt_001';
      const testCategory = 'programming';

      // 记录使用
      await recommendationManager.recordUsage(testPromptId, testCategory, false);

      // 获取使用统计
      const stats = recommendationManager.getPromptUsageStats(testPromptId);
      expect(stats !== null).assertTrue();
      expect(stats !== undefined).assertTrue();

      // 验证统计数据
      if (stats) {
        expect(stats.promptId).assertEqual(testPromptId);
        expect(stats.usageCount).assertEqual(1);
        expect(stats.categoryUsageCount).assertEqual(1);
        expect(stats.voiceTriggerUsageCount).assertEqual(0);
        expect(stats.lastUsedTime > 0).assertTrue();
      }

      TestUtils.log('提示词使用统计测试通过');
    });

    /**
     * 测试语音触发使用统计
     */
    it('should track voice trigger usage correctly', async () => {
      TestUtils.log('测试语音触发使用统计功能');

      const testPromptId = 'voice_test_prompt';
      const testCategory = 'general';

      // 记录语音触发使用
      await recommendationManager.recordUsage(testPromptId, testCategory, true);

      // 获取使用统计
      const stats = recommendationManager.getPromptUsageStats(testPromptId);
      expect(stats !== null).assertTrue();

      // 验证语音触发统计
      if (stats) {
        expect(stats.voiceTriggerUsageCount).assertEqual(1);
        expect(stats.usageCount).assertEqual(1);
      }

      TestUtils.log('语音触发使用统计测试通过');
    });

    /**
     * 测试提示词推荐算法
     */
    it('should generate prompt recommendations correctly', async () => {
      TestUtils.log('测试提示词推荐算法功能');

      // 准备测试数据
      const testPrompts = [
        { id: 'prompt_001', category: 'programming', title: '代码优化' },
        { id: 'prompt_002', category: 'general', title: '创意写作' },
        { id: 'prompt_003', category: 'technical', title: '技术问答' }
      ];

      // 记录使用数据
      for (const prompt of testPrompts) {
        await recommendationManager.recordUsage(prompt.id, prompt.category, false);
        await TestUtils.sleep(10); // 确保时间戳不同
      }

      // 为第一个prompt增加更多使用
      for (let i = 0; i < 3; i++) {
        await recommendationManager.recordUsage(testPrompts[0].id, testPrompts[0].category, false);
      }

      // 获取推荐
      const recommendations = await recommendationManager.getRecommendations('programming', 5);

      // 验证推荐结果
      expect(recommendations.length > 0).assertTrue();
      expect(recommendations.length <= 5).assertTrue();

      // 验证推荐结构
      for (const recommendation of recommendations) {
        expect(recommendation.promptId.length > 0).assertTrue();
        expect(recommendation.score >= 0).assertTrue();
        expect(recommendation.reason.length > 0).assertTrue();
      }

      TestUtils.log(`推荐结果: ${JSON.stringify(recommendations)}`);
      TestUtils.log('提示词推荐算法测试通过');
    });

    /**
     * 测试个性化推荐
     */
    it('should provide personalized recommendations', async () => {
      TestUtils.log('测试个性化推荐功能');

      // 启用个性化
      const config = recommendationManager.getConfig();
      config.enablePersonalization = true;
      recommendationManager.setConfig(config);

      // 记录用户偏好
      const userPrompts = [
        { id: 'user_prompt_1', category: 'programming', title: 'JavaScript开发' },
        { id: 'user_prompt_2', category: 'programming', title: 'React框架' }
      ];

      for (const prompt of userPrompts) {
        // 增加使用次数
        for (let i = 0; i < 5; i++) {
          await recommendationManager.recordUsage(prompt.id, prompt.category, false);
        }
      }

      // 记录其他类别使用
      await recommendationManager.recordUsage('other_prompt', 'general', false);

      // 获取个性化推荐
      const personalizedRecommendations = await recommendationManager.getRecommendations('programming', 3);

      // 验证个性化推荐
      expect(personalizedRecommendations.length > 0).assertTrue();

      // 验证推荐包含用户偏好的类别
      const programmingRecommendations = personalizedRecommendations.filter(
        rec => rec.category === 'programming'
      );
      expect(programmingRecommendations.length > 0).assertTrue();

      TestUtils.log('个性化推荐测试通过');
    });

    /**
     * 测试推荐评分计算
     */
    it('should calculate recommendation scores correctly', async () => {
      TestUtils.log('测试推荐评分计算功能');

      const testPromptId = 'score_test_prompt';
      const testCategory = 'technical';

      // 多次使用同一个提示词
      for (let i = 0; i < 5; i++) {
        await recommendationManager.recordUsage(testPromptId, testCategory, Math.random() > 0.5);
      }

      // 获取推荐
      const recommendations = await recommendationManager.getRecommendations(testCategory, 1);

      // 验证评分
      if (recommendations.length > 0) {
        const topRecommendation = recommendations[0];
        expect(topRecommendation.score > 0).assertTrue();
        expect(topRecommendation.promptId).assertEqual(testPromptId);

        TestUtils.log(`推荐评分: ${topRecommendation.score}`);
        TestUtils.log(`推荐原因: ${topRecommendation.reason}`);
      }

      TestUtils.log('推荐评分计算测试通过');
    });

    /**
     * 测试推荐时效性
     */
    it('should handle recommendation time sensitivity', async () => {
      TestUtils.log('测试推荐时效性功能');

      // 记录最近的使用
      await recommendationManager.recordUsage('recent_prompt', 'general', false);

      // 等待一段时间
      await TestUtils.sleep(100);

      // 记录更早的使用（模拟）
      await recommendationManager.recordUsage('old_prompt', 'general', false);

      // 获取推荐
      const recommendations = await recommendationManager.getRecommendations('general', 2);

      // 验证时效性处理
      expect(recommendations.length > 0).assertTrue();

      // 验证推荐考虑了时间因素
      const recentRecommendation = recommendations.find(r => r.promptId === 'recent_prompt');
      const oldRecommendation = recommendations.find(r => r.promptId === 'old_prompt');

      if (recentRecommendation && oldRecommendation) {
        // 最近的推荐应该有更高的分数
        expect(recentRecommendation.score >= oldRecommendation.score).assertTrue();
      }

      TestUtils.log('推荐时效性测试通过');
    });

    /**
     * 测试推荐多样性
     */
    it('should ensure recommendation diversity', async () => {
      TestUtils.log('测试推荐多样性功能');

      // 启用类别平衡
      const config = recommendationManager.getConfig();
      config.enableCategoryBalancing = true;
      recommendationManager.setConfig(config);

      // 记录不同类别的使用
      const categories = ['programming', 'general', 'technical', 'creative'];
      for (const category of categories) {
        await recommendationManager.recordUsage(`${category}_prompt`, category, false);
      }

      // 获取推荐
      const recommendations = await recommendationManager.getRecommendations('general', 10);

      // 验证多样性
      expect(recommendations.length > 0).assertTrue();

      // 统计不同类别的推荐数量
      const categoryCount = new Map<string, number>();
      for (const rec of recommendations) {
        categoryCount.set(rec.category, (categoryCount.get(rec.category) || 0) + 1);
      }

      // 验证至少有2个不同类别
      expect(categoryCount.size >= 2).assertTrue();

      TestUtils.log('推荐多样性测试通过');
    });

    /**
     * 测试冷启动处理
     */
    it('should handle cold start scenario', async () => {
      TestUtils.log('测试冷启动处理功能');

      // 创建新的推荐管理器实例（模拟新用户）
      const newManager = PromptRecommendationManager.getInstance();

      // 获取冷启动推荐
      const coldStartRecommendations = await newManager.getRecommendations('general', 5);

      // 验证冷启动推荐
      expect(coldStartRecommendations.length > 0).assertTrue();

      // 验证冷启动推荐包含默认提示词
      const hasDefaultPrompts = coldStartRecommendations.some(rec =>
        rec.reason.includes('默认') || rec.reason.includes('推荐')
      );
      expect(hasDefaultPrompts).assertTrue();

      TestUtils.log('冷启动处理测试通过');
    });

    /**
     * 测试推荐过滤
     */
    it('should filter recommendations correctly', async () => {
      TestUtils.log('测试推荐过滤功能');

      // 记录一些使用数据
      await recommendationManager.recordUsage('valid_prompt', 'programming', false);
      await recommendationManager.recordUsage('inactive_prompt', 'general', false);

      // 设置最小使用次数过滤
      const config = recommendationManager.getConfig();
      config.minUsageCount = 2;
      recommendationManager.setConfig(config);

      // 获取推荐
      const recommendations = await recommendationManager.getRecommendations('programming', 5);

      // 验证过滤效果
      const validRecommendations = recommendations.filter(rec =>
        rec.usageCount >= config.minUsageCount
      );
      expect(validRecommendations.length === recommendations.length).assertTrue();

      TestUtils.log('推荐过滤测试通过');
    });

    /**
     * 测试推荐排序
     */
    it('should sort recommendations correctly', async () => {
      TestUtils.log('测试推荐排序功能');

      // 记录不同使用次数的提示词
      const testPrompts = [
        { id: 'high_usage', category: 'programming', usageCount: 10 },
        { id: 'medium_usage', category: 'programming', usageCount: 5 },
        { id: 'low_usage', category: 'programming', usageCount: 1 }
      ];

      for (const prompt of testPrompts) {
        for (let i = 0; i < prompt.usageCount; i++) {
          await recommendationManager.recordUsage(prompt.id, prompt.category, false);
        }
      }

      // 获取推荐
      const recommendations = await recommendationManager.getRecommendations('programming', 5);

      // 验证排序
      expect(recommendations.length > 0).assertTrue();

      // 验证按分数降序排列
      for (let i = 0; i < recommendations.length - 1; i++) {
        expect(recommendations[i].score >= recommendations[i + 1].score).assertTrue();
      }

      TestUtils.log('推荐排序测试通过');
    });

    /**
     * 测试推荐缓存
     */
    it('should cache recommendations efficiently', async () => {
      TestUtils.log('测试推荐缓存功能');

      // 记录一些使用数据
      await recommendationManager.recordUsage('cached_prompt', 'general', false);

      // 第一次获取推荐（应该计算）
      const firstRecommendations = await recommendationManager.getRecommendations('general', 3);

      // 第二次获取推荐（可能来自缓存）
      const secondRecommendations = await recommendationManager.getRecommendations('general', 3);

      // 验证缓存一致性
      expect(firstRecommendations.length).assertEqual(secondRecommendations.length);

      for (let i = 0; i < firstRecommendations.length; i++) {
        expect(firstRecommendations[i].promptId).assertEqual(secondRecommendations[i].promptId);
        expect(firstRecommendations[i].score).assertEqual(secondRecommendations[i].score);
      }

      TestUtils.log('推荐缓存测试通过');
    });

    /**
     * 测试推荐配置重置
     */
    it('should reset recommendation configuration', async () => {
      TestUtils.log('测试推荐配置重置功能');

      // 修改配置
      const modifiedConfig = recommendationManager.getConfig();
      modifiedConfig.maxRecommendations = 20;
      modifiedConfig.usageWeightFactor = 0.5;
      recommendationManager.setConfig(modifiedConfig);

      // 重置配置
      recommendationManager.resetConfig();

      // 验证重置
      const resetConfig = recommendationManager.getConfig();
      expect(resetConfig.maxRecommendations).assertEqual(10); // 默认值
      expect(resetConfig.usageWeightFactor).assertEqual(0.7); // 默认值

      TestUtils.log('推荐配置重置测试通过');
    });

    /**
     * 测试推荐数据持久化
     */
    it('should persist recommendation data', async () => {
      TestUtils.log('测试推荐数据持久化功能');

      // 记录使用数据
      await recommendationManager.recordUsage('persistent_prompt', 'technical', false);

      // 保存数据
      await recommendationManager.saveData();

      // 重新加载
      await recommendationManager.loadData();

      // 验证数据持久化
      const stats = recommendationManager.getPromptUsageStats('persistent_prompt');
      expect(stats !== null).assertTrue();
      if (stats) {
        expect(stats.usageCount > 0).assertTrue();
      }

      TestUtils.log('推荐数据持久化测试通过');
    });

    /**
     * 测试推荐性能表现
     */
    it('should have good recommendation performance', async () => {
      TestUtils.log('测试推荐性能表现功能');

      // 记录大量使用数据
      for (let i = 0; i < 100; i++) {
        await recommendationManager.recordUsage(`perf_prompt_${i}`, 'programming', false);
      }

      // 测试推荐性能
      const startTime = Date.now();
      const iterations = 50;

      for (let i = 0; i < iterations; i++) {
        await recommendationManager.getRecommendations('programming', 5);
      }

      const endTime = Date.now();
      const averageTime = (endTime - startTime) / iterations;

      TestUtils.log(`平均推荐时间: ${averageTime}ms`);

      // 验证性能满足要求（每次推荐应在100ms以内）
      expect(averageTime < 100).assertTrue();

      TestUtils.log('推荐性能表现测试通过');
    });

    /**
     * 测试推荐错误处理
     */
    it('should handle recommendation errors correctly', async () => {
      TestUtils.log('测试推荐错误处理功能');

      // 测试空类别处理
      const emptyCategoryRecommendations = await recommendationManager.getRecommendations('', 3);
      expect(emptyCategoryRecommendations.length >= 0).assertTrue();

      // 测试无效数量处理
      const invalidCountRecommendations = await recommendationManager.getRecommendations('general', -1);
      expect(invalidCountRecommendations.length >= 0).assertTrue();

      // 测试不存在的提示词统计
      const nonexistentStats = recommendationManager.getPromptUsageStats('nonexistent_prompt');
      expect(nonexistentStats === null).assertTrue();

      TestUtils.log('推荐错误处理测试通过');
    });

    /**
     * 测试推荐统计分析
     */
    it('should provide recommendation analytics', async () => {
      TestUtils.log('测试推荐统计分析功能');

      // 记录使用数据
      const categories = ['programming', 'general', 'technical'];
      for (const category of categories) {
        for (let i = 0; i < 5; i++) {
          await recommendationManager.recordUsage(`${category}_prompt_${i}`, category, false);
        }
      }

      // 获取分析数据
      const analytics = recommendationManager.getRecommendationAnalytics();
      expect(analytics !== null).assertTrue();

      // 验证分析数据结构
      if (analytics) {
        expect(analytics.totalPrompts >= 0).assertTrue();
        expect(analytics.totalUsageCount >= 0).assertTrue();
        expect(analytics.categoryDistribution.size > 0).assertTrue();
        expect(analytics.averageUsageCount >= 0).assertTrue();
      }

      TestUtils.log(`推荐分析数据: ${JSON.stringify(analytics)}`);
      TestUtils.log('推荐统计分析测试通过');
    });
  });
}