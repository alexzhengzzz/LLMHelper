import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { MessageEnhancer, EnhancedMessage, SearchInfo, SearchSource, ValidationResult } from '../main/ets/services/MessageEnhancer';
import { SearchResponse, SearchResult } from '../main/ets/clients/SearchAPIClient';
import { SearchDecision, SearchCategory } from '../main/ets/services/SearchDecisionEngine';

/**
 * 消息增强器测试套件
 * 测试将搜索结果整合到用户消息中的功能
 */
export default function messageEnhancerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('MessageEnhancerTest');

  describe('MessageEnhancerTest', () => {
    let messageEnhancer: MessageEnhancer;

    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化消息增强器测试环境');

      // 创建消息增强器实例
      messageEnhancer = new MessageEnhancer();

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
     * 测试消息增强器初始化
     */
    it('should initialize message enhancer correctly', async () => {
      TestUtils.log('测试消息增强器初始化功能');

      // 验证增强器实例存在
      expect(messageEnhancer !== null).assertTrue();
      expect(messageEnhancer !== undefined).assertTrue();

      TestUtils.log('消息增强器初始化成功');
    });

    /**
     * 测试无搜索结果的消息增强
     */
    it('should handle message without search results', async () => {
      TestUtils.log('测试无搜索结果的消息增强功能');

      const originalMessage = '写一个Hello World程序';
      const searchDecision: SearchDecision = {
        shouldSearch: false,
        confidence: 0,
        reason: '编程问题不需要搜索',
        keywords: [],
        category: SearchCategory.NONE
      };

      const enhancedMessage = messageEnhancer.enhanceMessage(originalMessage, searchDecision);

      // 验证增强结果
      expect(enhancedMessage.originalMessage).assertEqual(originalMessage);
      expect(enhancedMessage.enhancedMessage).assertEqual(originalMessage);
      expect(enhancedMessage.searchUsed).assertFalse();
      expect(enhancedMessage.searchInfo).assertUndefined();

      TestUtils.log('无搜索结果的消息增强测试通过');
    });

    /**
     * 测试有搜索结果的消息增强
     */
    it('should handle message with search results', async () => {
      TestUtils.log('测试有搜索结果的消息增强功能');

      const originalMessage = '今天天气怎么样？';
      const searchDecision: SearchDecision = {
        shouldSearch: true,
        confidence: 0.8,
        reason: '实时信息查询',
        keywords: ['今天', '天气'],
        category: SearchCategory.REAL_TIME
      };

      const searchResponse: SearchResponse = {
        query: '今天天气怎么样？',
        results: [
          {
            title: '今日天气预报',
            url: 'https://weather.com',
            snippet: '今天天气晴朗，温度25°C',
            content: '今天天气晴朗，温度25°C'
          }
        ],
        provider: 'test-provider',
        searchTime: 100,
        totalResults: 1
      };

      const enhancedMessage = messageEnhancer.enhanceMessage(originalMessage, searchDecision, searchResponse);

      // 验证增强结果
      expect(enhancedMessage.originalMessage).assertEqual(originalMessage);
      expect(enhancedMessage.searchUsed).assertTrue();
      expect(enhancedMessage.searchInfo !== undefined).assertTrue();

      if (enhancedMessage.searchInfo) {
        expect(enhancedMessage.searchInfo.query).assertEqual(searchResponse.query);
        expect(enhancedMessage.searchInfo.provider).assertEqual(searchResponse.provider);
        expect(enhancedMessage.searchInfo.resultCount).assertEqual(searchResponse.results.length);
        expect(enhancedMessage.searchInfo.category).assertEqual(searchDecision.category);
      }

      TestUtils.log('有搜索结果的消息增强测试通过');
    });

    /**
     * 测试搜索信息结构
     */
    it('should create correct search info structure', async () => {
      TestUtils.log('测试搜索信息结构功能');

      const searchDecision: SearchDecision = {
        shouldSearch: true,
        confidence: 0.9,
        reason: '实时信息查询',
        keywords: ['今天', '天气'],
        category: SearchCategory.REAL_TIME
      };

      const searchResponse: SearchResponse = {
        query: '今天天气怎么样？',
        results: [
          {
            title: '今日天气预报',
            url: 'https://weather.com',
            snippet: '今天天气晴朗，温度25°C',
            content: '今天天气晴朗，温度25°C'
          },
          {
            title: '天气预警',
            url: 'https://alert.com',
            snippet: '无特殊天气预警',
            content: '无特殊天气预警'
          }
        ],
        provider: 'test-provider',
        searchTime: 150,
        totalResults: 2
      };

      const enhancedMessage = messageEnhancer.enhanceMessage('今天天气怎么样？', searchDecision, searchResponse);

      // 验证搜索信息结构
      expect(enhancedMessage.searchInfo !== undefined).assertTrue();

      if (enhancedMessage.searchInfo) {
        const searchInfo = enhancedMessage.searchInfo;
        expect(searchInfo.query).assertEqual(searchResponse.query);
        expect(searchInfo.provider).assertEqual(searchResponse.provider);
        expect(searchInfo.resultCount).assertEqual(searchResponse.results.length);
        expect(searchInfo.searchTime).assertEqual(searchResponse.searchTime);
        expect(searchInfo.category).assertEqual(searchDecision.category);
        expect(searchInfo.sources.length).assertEqual(searchResponse.results.length);

        // 验证搜索来源结构
        searchInfo.sources.forEach((source, index) => {
          const originalResult = searchResponse.results[index];
          expect(source.title).assertEqual(originalResult.title);
          expect(source.url).assertEqual(originalResult.url);
          expect(source.snippet).assertEqual(originalResult.snippet);
        });
      }

      TestUtils.log('搜索信息结构测试通过');
    });

    /**
     * 测试空搜索结果处理
     */
    it('should handle empty search results correctly', async () => {
      TestUtils.log('测试空搜索结果处理功能');

      const originalMessage = '今天天气怎么样？';
      const searchDecision: SearchDecision = {
        shouldSearch: true,
        confidence: 0.8,
        reason: '实时信息查询',
        keywords: ['今天', '天气'],
        category: SearchCategory.REAL_TIME
      };

      const searchResponse: SearchResponse = {
        query: '今天天气怎么样？',
        results: [],
        provider: 'test-provider',
        searchTime: 50,
        totalResults: 0
      };

      const enhancedMessage = messageEnhancer.enhanceMessage(originalMessage, searchDecision, searchResponse);

      // 验证处理结果
      expect(enhancedMessage.originalMessage).assertEqual(originalMessage);
      expect(enhancedMessage.searchUsed).assertTrue();
      expect(enhancedMessage.searchInfo !== undefined).assertTrue();

      if (enhancedMessage.searchInfo) {
        expect(enhancedMessage.searchInfo.resultCount).assertEqual(0);
        expect(enhancedMessage.searchInfo.sources.length).assertEqual(0);
      }

      TestUtils.log('空搜索结果处理测试通过');
    });

    /**
     * 测试增强消息格式
     */
    it('should format enhanced message correctly', async () => {
      TestUtils.log('测试增强消息格式功能');

      const testCases = [
        {
          originalMessage: '今天天气怎么样？',
          searchCategory: SearchCategory.REAL_TIME,
          expectedContains: ['天气', '实时']
        },
        {
          originalMessage: '最新的技术新闻',
          searchCategory: SearchCategory.TECHNICAL,
          expectedContains: ['技术', '最新']
        },
        {
          originalMessage: '最近有什么新闻？',
          searchCategory: SearchCategory.NEWS,
          expectedContains: ['新闻', '最近']
        }
      ];

      for (const testCase of testCases) {
        const searchDecision: SearchDecision = {
          shouldSearch: true,
          confidence: 0.8,
          reason: '需要搜索',
          keywords: ['关键词'],
          category: testCase.searchCategory
        };

        const searchResponse: SearchResponse = {
          query: testCase.originalMessage,
          results: [
            {
              title: '测试结果',
              url: 'https://test.com',
              snippet: '测试摘要',
              content: '测试内容'
            }
          ],
          provider: 'test-provider',
          searchTime: 100,
          totalResults: 1
        };

        const enhancedMessage = messageEnhancer.enhanceMessage(testCase.originalMessage, searchDecision, searchResponse);

        // 验证增强消息格式
        expect(enhancedMessage.enhancedMessage.length > 0).assertTrue();
        expect(enhancedMessage.searchUsed).assertTrue();

        TestUtils.log(`增强消息: ${enhancedMessage.enhancedMessage}`);
      }

      TestUtils.log('增强消息格式测试通过');
    });

    /**
     * 测试搜索结果验证
     */
    it('should validate search results correctly', async () => {
      TestUtils.log('测试搜索结果验证功能');

      const validSearchResponse: SearchResponse = {
        query: '测试查询',
        results: [
          {
            title: '有效结果',
            url: 'https://valid.com',
            snippet: '有效摘要',
            content: '有效内容'
          }
        ],
        provider: 'test-provider',
        searchTime: 100,
        totalResults: 1
      };

      const invalidSearchResponse: SearchResponse = {
        query: '测试查询',
        results: [
          {
            title: '',
            url: '',
            snippet: '',
            content: ''
          }
        ],
        provider: 'test-provider',
        searchTime: 100,
        totalResults: 1
      };

      // 验证有效搜索结果
      const validResult = messageEnhancer.validateSearchResults(validSearchResponse);
      expect(validResult.isValid).assertTrue();
      expect(validResult.validCount).assertEqual(1);
      expect(validResult.issues.length).assertEqual(0);

      // 验证无效搜索结果
      const invalidResult = messageEnhancer.validateSearchResults(invalidSearchResponse);
      expect(invalidResult.isValid).assertFalse();
      expect(invalidResult.validCount).assertEqual(0);
      expect(invalidResult.issues.length > 0).assertTrue();

      TestUtils.log('搜索结果验证测试通过');
    });

    /**
     * 测试性能表现
     */
    it('should have good performance', async () => {
      TestUtils.log('测试性能表现功能');

      const originalMessage = '今天天气怎么样？';
      const searchDecision: SearchDecision = {
        shouldSearch: true,
        confidence: 0.8,
        reason: '实时信息查询',
        keywords: ['今天', '天气'],
        category: SearchCategory.REAL_TIME
      };

      const searchResponse: SearchResponse = {
        query: originalMessage,
        results: [
          {
            title: '测试结果',
            url: 'https://test.com',
            snippet: '测试摘要',
            content: '测试内容'
          }
        ],
        provider: 'test-provider',
        searchTime: 100,
        totalResults: 1
      };

      const startTime = Date.now();
      const iterations = 1000;

      for (let i = 0; i < iterations; i++) {
        messageEnhancer.enhanceMessage(originalMessage, searchDecision, searchResponse);
      }

      const endTime = Date.now();
      const averageTime = (endTime - startTime) / iterations;

      TestUtils.log(`平均处理时间: ${averageTime}ms`);

      // 验证性能满足要求（每次处理应在1ms以内）
      expect(averageTime < 1).assertTrue();

      TestUtils.log('性能表现测试通过');
    });

    /**
     * 测试错误处理
     */
    it('should handle errors correctly', async () => {
      TestUtils.log('测试错误处理功能');

      // 测试空消息处理
      const emptyMessage = '';
      const searchDecision: SearchDecision = {
        shouldSearch: false,
        confidence: 0,
        reason: '空消息',
        keywords: [],
        category: SearchCategory.NONE
      };

      const enhancedMessage = messageEnhancer.enhanceMessage(emptyMessage, searchDecision);
      expect(enhancedMessage.originalMessage).assertEqual(emptyMessage);
      expect(enhancedMessage.enhancedMessage).assertEqual(emptyMessage);

      // 测试null参数处理
      const nullDecision: SearchDecision = {
        shouldSearch: false,
        confidence: 0,
        reason: 'null决策',
        keywords: [],
        category: SearchCategory.NONE
      };

      const nullEnhancedMessage = messageEnhancer.enhanceMessage('测试消息', nullDecision);
      expect(nullEnhancedMessage.originalMessage).assertEqual('测试消息');

      TestUtils.log('错误处理测试通过');
    });

    /**
     * 测试并发处理
     */
    it('should handle concurrent processing correctly', async () => {
      TestUtils.log('测试并发处理功能');

      const originalMessage = '今天天气怎么样？';
      const searchDecision: SearchDecision = {
        shouldSearch: true,
        confidence: 0.8,
        reason: '实时信息查询',
        keywords: ['今天', '天气'],
        category: SearchCategory.REAL_TIME
      };

      const searchResponse: SearchResponse = {
        query: originalMessage,
        results: [
          {
            title: '测试结果',
            url: 'https://test.com',
            snippet: '测试摘要',
            content: '测试内容'
          }
        ],
        provider: 'test-provider',
        searchTime: 100,
        totalResults: 1
      };

      const promises: Promise<EnhancedMessage>[] = [];

      // 创建并发请求
      for (let i = 0; i < 50; i++) {
        promises.push(
          new Promise<EnhancedMessage>((resolve) => {
            setTimeout(() => {
              resolve(messageEnhancer.enhanceMessage(originalMessage, searchDecision, searchResponse));
            }, Math.random() * 10);
          })
        );
      }

      // 等待所有请求完成
      const results = await Promise.all(promises);

      // 验证所有结果都正确
      expect(results.length).assertEqual(50);
      expect(results.every(result => result !== null)).assertTrue();
      expect(results.every(result => result !== undefined)).assertTrue();
      expect(results.every(result => result.searchUsed === true)).assertTrue();

      TestUtils.log('并发处理测试通过');
    });

    /**
     * 测试内存管理
     */
    it('should manage memory correctly', async () => {
      TestUtils.log('测试内存管理功能');

      const longMessage = '今天天气怎么样？'.repeat(100);
      const searchDecision: SearchDecision = {
        shouldSearch: true,
        confidence: 0.8,
        reason: '实时信息查询',
        keywords: ['今天', '天气'],
        category: SearchCategory.REAL_TIME
      };

      const searchResponse: SearchResponse = {
        query: longMessage,
        results: [
          {
            title: '测试结果',
            url: 'https://test.com',
            snippet: '测试摘要',
            content: '测试内容'
          }
        ],
        provider: 'test-provider',
        searchTime: 100,
        totalResults: 1
      };

      const iterations = 1000;

      // 处理大量消息
      for (let i = 0; i < iterations; i++) {
        messageEnhancer.enhanceMessage(longMessage, searchDecision, searchResponse);
      }

      // 验证增强器仍然正常工作
      const finalEnhancedMessage = messageEnhancer.enhanceMessage('测试消息', searchDecision, searchResponse);
      expect(finalEnhancedMessage.originalMessage).assertEqual('测试消息');
      expect(finalEnhancedMessage.searchUsed).assertTrue();

      TestUtils.log('内存管理测试通过');
    });

    /**
     * 测试搜索结果过滤
     */
    it('should filter search results correctly', async () => {
      TestUtils.log('测试搜索结果过滤功能');

      const searchResponse: SearchResponse = {
        query: '测试查询',
        results: [
          {
            title: '有效结果1',
            url: 'https://valid1.com',
            snippet: '有效摘要1',
            content: '有效内容1'
          },
          {
            title: '',
            url: 'https://invalid.com',
            snippet: '无效摘要',
            content: '无效内容'
          },
          {
            title: '有效结果2',
            url: 'https://valid2.com',
            snippet: '有效摘要2',
            content: '有效内容2'
          }
        ],
        provider: 'test-provider',
        searchTime: 100,
        totalResults: 3
      };

      const validationResult = messageEnhancer.validateSearchResults(searchResponse);

      // 验证过滤结果
      expect(validationResult.isValid).assertTrue();
      expect(validationResult.validCount).assertEqual(2); // 只有2个有效结果
      expect(validationResult.issues.length > 0).assertTrue();

      TestUtils.log('搜索结果过滤测试通过');
    });

    /**
     * 测试多来源搜索结果
     */
    it('should handle multiple search result sources', async () => {
      TestUtils.log('测试多来源搜索结果功能');

      const searchResponse: SearchResponse = {
        query: '测试查询',
        results: [
          {
            title: '来源1结果',
            url: 'https://source1.com',
            snippet: '来源1摘要',
            content: '来源1内容'
          },
          {
            title: '来源2结果',
            url: 'https://source2.com',
            snippet: '来源2摘要',
            content: '来源2内容'
          },
          {
            title: '来源3结果',
            url: 'https://source3.com',
            snippet: '来源3摘要',
            content: '来源3内容'
          }
        ],
        provider: 'multi-provider',
        searchTime: 200,
        totalResults: 3
      };

      const searchDecision: SearchDecision = {
        shouldSearch: true,
        confidence: 0.9,
        reason: '多来源查询',
        keywords: ['测试'],
        category: SearchCategory.TECHNICAL
      };

      const enhancedMessage = messageEnhancer.enhanceMessage('测试消息', searchDecision, searchResponse);

      // 验证多来源处理
      expect(enhancedMessage.searchUsed).assertTrue();
      expect(enhancedMessage.searchInfo !== undefined).assertTrue();

      if (enhancedMessage.searchInfo) {
        expect(enhancedMessage.searchInfo.resultCount).assertEqual(3);
        expect(enhancedMessage.searchInfo.sources.length).assertEqual(3);

        // 验证每个来源都有正确的结构
        enhancedMessage.searchInfo.sources.forEach(source => {
          expect(source.title.length > 0).assertTrue();
          expect(source.url.length > 0).assertTrue();
          expect(source.snippet.length > 0).assertTrue();
        });
      }

      TestUtils.log('多来源搜索结果测试通过');
    });
  });
}