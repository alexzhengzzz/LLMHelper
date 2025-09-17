import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { SearchDecisionEngine, SearchDecision, SearchCategory, SpecialPatternResult } from '../main/ets/services/SearchDecisionEngine';

/**
 * 搜索决策引擎测试套件
 * 测试智能判断用户输入是否需要联网搜索的功能
 */
export default function searchDecisionEngineTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('SearchDecisionEngineTest');

  describe('SearchDecisionEngineTest', () => {
    let searchEngine: SearchDecisionEngine;

    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化搜索决策引擎测试环境');

      // 获取搜索决策引擎实例
      searchEngine = SearchDecisionEngine.getInstance();

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
     * 测试引擎初始化
     */
    it('should initialize search decision engine correctly', async () => {
      TestUtils.log('测试搜索决策引擎初始化功能');

      // 验证引擎实例存在
      expect(searchEngine !== null).assertTrue();
      expect(searchEngine !== undefined).assertTrue();

      TestUtils.log('搜索决策引擎初始化成功');
    });

    /**
     * 测试搜索开关关闭时的决策
     */
    it('should return no search when search is disabled', async () => {
      TestUtils.log('测试搜索开关关闭时的决策功能');

      const message = '今天天气怎么样？';
      const decision = searchEngine.shouldSearch(message, false);

      // 验证决策结果
      expect(decision.shouldSearch).assertFalse();
      expect(decision.confidence).assertEqual(0);
      expect(decision.reason).assertEqual('联网搜索开关已关闭');
      expect(decision.keywords.length).assertEqual(0);
      expect(decision.category).assertEqual(SearchCategory.NONE);

      TestUtils.log('搜索开关关闭决策测试通过');
    });

    /**
     * 测试实时信息搜索判断
     */
    it('should detect real-time information correctly', async () => {
      TestUtils.log('测试实时信息搜索判断功能');

      const testCases = [
        { message: '今天天气怎么样？', shouldSearch: true, category: SearchCategory.REAL_TIME },
        { message: '现在几点了？', shouldSearch: true, category: SearchCategory.REAL_TIME },
        { message: '最新新闻是什么？', shouldSearch: true, category: SearchCategory.REAL_TIME },
        { message: '2025年的技术趋势', shouldSearch: true, category: SearchCategory.REAL_TIME },
        { message: '当前时间', shouldSearch: true, category: SearchCategory.REAL_TIME }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertEqual(testCase.shouldSearch);
        expect(decision.category).assertEqual(testCase.category);
        expect(decision.confidence > 0).assertTrue();
        expect(decision.keywords.length > 0).assertTrue();
      }

      TestUtils.log('实时信息搜索判断测试通过');
    });

    /**
     * 测试技术查询搜索判断
     */
    it('should detect technical queries correctly', async () => {
      TestUtils.log('测试技术查询搜索判断功能');

      const testCases = [
        { message: '如何使用React最新版本？', shouldSearch: true, category: SearchCategory.TECHNICAL },
        { message: 'OpenAI最新的API文档', shouldSearch: true, category: SearchCategory.TECHNICAL },
        { message: '鸿蒙系统开发指南', shouldSearch: true, category: SearchCategory.TECHNICAL },
        { message: 'ArkTS语法介绍', shouldSearch: true, category: SearchCategory.TECHNICAL }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertTrue();
        expect(decision.category).assertEqual(testCase.category);
        expect(decision.confidence > 0).assertTrue();
        expect(decision.keywords.length > 0).assertTrue();
      }

      TestUtils.log('技术查询搜索判断测试通过');
    });

    /**
     * 测试新闻事件搜索判断
     */
    it('should detect news events correctly', async () => {
      TestUtils.log('测试新闻事件搜索判断功能');

      const testCases = [
        { message: '最近有什么重要新闻？', shouldSearch: true, category: SearchCategory.NEWS },
        { message: '今日头条新闻', shouldSearch: true, category: SearchCategory.NEWS },
        { message: '突发新闻事件', shouldSearch: true, category: SearchCategory.NEWS },
        { message: '新闻报道分析', shouldSearch: true, category: SearchCategory.NEWS }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertTrue();
        expect(decision.category).assertEqual(testCase.category);
        expect(decision.confidence > 0).assertTrue();
        expect(decision.keywords.length > 0).assertTrue();
      }

      TestUtils.log('新闻事件搜索判断测试通过');
    });

    /**
     * 测试时事搜索判断
     */
    it('should detect current affairs correctly', async () => {
      TestUtils.log('测试时事搜索判断功能');

      const testCases = [
        { message: '最近的政治局势', shouldSearch: true, category: SearchCategory.CURRENT_AFFAIRS },
        { message: '当前国际形势', shouldSearch: true, category: SearchCategory.CURRENT_AFFAIRS },
        { message: '经济政策分析', shouldSearch: true, category: SearchCategory.CURRENT_AFFAIRS },
        { message: '社会热点问题', shouldSearch: true, category: SearchCategory.CURRENT_AFFAIRS }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertTrue();
        expect(decision.category).assertEqual(testCase.category);
        expect(decision.confidence > 0).assertTrue();
        expect(decision.keywords.length > 0).assertTrue();
      }

      TestUtils.log('时事搜索判断测试通过');
    });

    /**
     * 测试不需要搜索的情况
     */
    it('should detect no search scenarios correctly', async () => {
      TestUtils.log('测试不需要搜索的情况功能');

      const testCases = [
        { message: '写一个Hello World程序', shouldSearch: false },
        { message: '解释什么是递归', shouldSearch: false },
        { message: '帮我优化这段代码', shouldSearch: false },
        { message: '什么是算法复杂度', shouldSearch: false },
        { message: '计算1+1等于多少', shouldSearch: false }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertEqual(testCase.shouldSearch);
        expect(decision.category).assertEqual(SearchCategory.NONE);
      }

      TestUtils.log('不需要搜索的情况测试通过');
    });

    /**
     * 测试置信度计算
     */
    it('should calculate confidence correctly', async () => {
      TestUtils.log('测试置信度计算功能');

      const testCases = [
        { message: '今天', expectedMinConfidence: 0.1, expectedMaxConfidence: 0.6 },
        { message: '今天天气怎么样？', expectedMinConfidence: 0.3, expectedMaxConfidence: 0.8 },
        { message: '今天最新的新闻是什么？', expectedMinConfidence: 0.5, expectedMaxConfidence: 1.0 }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`置信度: ${decision.confidence}`);

        expect(decision.confidence >= testCase.expectedMinConfidence).assertTrue();
        expect(decision.confidence <= testCase.expectedMaxConfidence).assertTrue();
      }

      TestUtils.log('置信度计算测试通过');
    });

    /**
     * 测试关键词提取
     */
    it('should extract keywords correctly', async () => {
      TestUtils.log('测试关键词提取功能');

      const message = '今天最新的技术新闻是什么？';
      const decision = searchEngine.shouldSearch(message, true);

      TestUtils.log(`测试消息: "${message}"`);
      TestUtils.log(`提取的关键词: ${decision.keywords.join(', ')}`);

      // 验证关键词不为空
      expect(decision.keywords.length > 0).assertTrue();

      // 验证关键词包含在消息中
      const messageLower = message.toLowerCase();
      for (const keyword of decision.keywords) {
        expect(messageLower.includes(keyword.toLowerCase())).assertTrue();
      }

      TestUtils.log('关键词提取测试通过');
    });

    /**
     * 测试特殊模式检测
     */
    it('should detect special patterns correctly', async () => {
      TestUtils.log('测试特殊模式检测功能');

      const testCases = [
        { message: '今天几点了？', shouldSearch: true },
        { message: '2025年1月1日是什么时候？', shouldSearch: true },
        { message: '最近有什么新闻？', shouldSearch: true },
        { message: '帮我写代码', shouldSearch: false }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertEqual(testCase.shouldSearch);
      }

      TestUtils.log('特殊模式检测测试通过');
    });

    /**
     * 测试混合类型查询
     */
    it('should handle mixed type queries correctly', async () => {
      TestUtils.log('测试混合类型查询功能');

      const testCases = [
        { message: '今天React有什么新特性吗？', shouldSearch: true },
        { message: '最新的AI技术发展趋势', shouldSearch: true },
        { message: '现在流行的编程语言', shouldSearch: true },
        { message: '当前软件工程最佳实践', shouldSearch: true }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertTrue();
        expect(decision.confidence > 0).assertTrue();
        expect(decision.keywords.length > 0).assertTrue();
      }

      TestUtils.log('混合类型查询测试通过');
    });

    /**
     * 测试边界情况
     */
    it('should handle edge cases correctly', async () => {
      TestUtils.log('测试边界情况功能');

      const testCases = [
        { message: '', shouldSearch: false },
        { message: ' ', shouldSearch: false },
        { message: '你好', shouldSearch: false },
        { message: 'test', shouldSearch: false },
        { message: 'a', shouldSearch: false }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertEqual(testCase.shouldSearch);
      }

      TestUtils.log('边界情况测试通过');
    });

    /**
     * 测试大小写不敏感
     */
    it('should be case insensitive', async () => {
      TestUtils.log('测试大小写不敏感功能');

      const testCases = [
        { message: '今天天气怎么样？', shouldSearch: true },
        { message: '今天天气怎么样？', shouldSearch: true },
        { message: 'TODAY WEATHER', shouldSearch: true },
        { message: 'Today Weather', shouldSearch: true }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertEqual(testCase.shouldSearch);
      }

      TestUtils.log('大小写不敏感测试通过');
    });

    /**
     * 测试多语言支持
     */
    it('should support multiple languages', async () => {
      TestUtils.log('测试多语言支持功能');

      const testCases = [
        { message: '今天天气怎么样？', shouldSearch: true },
        { message: '今天天气怎么样？', shouldSearch: true },
        { message: 'latest news', shouldSearch: true },
        { message: 'current time', shouldSearch: true }
      ];

      for (const testCase of testCases) {
        const decision = searchEngine.shouldSearch(testCase.message, true);

        TestUtils.log(`测试消息: "${testCase.message}"`);
        TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

        expect(decision.shouldSearch).assertEqual(testCase.shouldSearch);
      }

      TestUtils.log('多语言支持测试通过');
    });

    /**
     * 测试决策结果结构
     */
    it('should return complete decision structure', async () => {
      TestUtils.log('测试决策结果结构功能');

      const message = '今天天气怎么样？';
      const decision = searchEngine.shouldSearch(message, true);

      // 验证决策结果包含所有必需字段
      TestUtils.log(`决策结果: ${JSON.stringify(decision)}`);

      expect(decision.hasOwnProperty('shouldSearch')).assertTrue();
      expect(decision.hasOwnProperty('confidence')).assertTrue();
      expect(decision.hasOwnProperty('reason')).assertTrue();
      expect(decision.hasOwnProperty('keywords')).assertTrue();
      expect(decision.hasOwnProperty('category')).assertTrue();

      // 验证字段类型
      expect(typeof decision.shouldSearch).assertEqual('boolean');
      expect(typeof decision.confidence).assertEqual('number');
      expect(typeof decision.reason).assertEqual('string');
      expect(Array.isArray(decision.keywords)).assertTrue();
      expect(typeof decision.category).assertEqual('string');

      TestUtils.log('决策结果结构测试通过');
    });

    /**
     * 测试性能表现
     */
    it('should have good performance', async () => {
      TestUtils.log('测试性能表现功能');

      const testMessages = [
        '今天天气怎么样？',
        '最新技术新闻',
        '如何使用React',
        '当前时间',
        '帮我写代码'
      ];

      const startTime = Date.now();
      const iterations = 100;

      for (let i = 0; i < iterations; i++) {
        for (const message of testMessages) {
          searchEngine.shouldSearch(message, true);
        }
      }

      const endTime = Date.now();
      const averageTime = (endTime - startTime) / (iterations * testMessages.length);

      TestUtils.log(`平均处理时间: ${averageTime}ms`);

      // 验证性能满足要求（每次处理应在1ms以内）
      expect(averageTime < 1).assertTrue();

      TestUtils.log('性能表现测试通过');
    });

    /**
     * 测试并发处理
     */
    it('should handle concurrent processing correctly', async () => {
      TestUtils.log('测试并发处理功能');

      const testMessages = [
        '今天天气怎么样？',
        '最新技术新闻',
        '如何使用React',
        '当前时间'
      ];

      const promises: Promise<SearchDecision>[] = [];

      // 创建并发请求
      for (let i = 0; i < 10; i++) {
        for (const message of testMessages) {
          promises.push(
            new Promise<SearchDecision>((resolve) => {
              setTimeout(() => {
                resolve(searchEngine.shouldSearch(message, true));
              }, Math.random() * 10);
            })
          );
        }
      }

      // 等待所有请求完成
      const results = await Promise.all(promises);

      // 验证所有结果都正确
      expect(results.length).assertEqual(40); // 10 * 4
      expect(results.every(result => result !== null)).assertTrue();
      expect(results.every(result => result !== undefined)).assertTrue();

      TestUtils.log('并发处理测试通过');
    });

    /**
     * 测试内存管理
     */
    it('should manage memory correctly', async () => {
      TestUtils.log('测试内存管理功能');

      const longMessage = '今天天气怎么样？'.repeat(100);
      const iterations = 1000;

      // 处理大量消息
      for (let i = 0; i < iterations; i++) {
        searchEngine.shouldSearch(longMessage, true);
      }

      // 验证引擎仍然正常工作
      const finalDecision = searchEngine.shouldSearch('今天天气怎么样？', true);
      expect(finalDecision.shouldSearch).assertTrue();

      TestUtils.log('内存管理测试通过');
    });
  });
}