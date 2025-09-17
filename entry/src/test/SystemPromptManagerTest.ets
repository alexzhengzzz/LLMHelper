import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { SystemPromptManager } from '../main/ets/utils/SystemPromptManager';
import { SystemPrompt, PromptCategory } from '../main/ets/types/PromptTypes';

/**
 * 系统提示词管理器测试套件
 * 测试提示词创建、编辑、分类、搜索等功能
 */
export default function systemPromptManagerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('SystemPromptManagerTest');
  
  describe('SystemPromptManagerTest', () => {
    let systemPromptManager: SystemPromptManager;
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化系统提示词管理器测试环境');
      
      // 获取系统提示词管理器实例
      systemPromptManager = SystemPromptManager.getInstance();
      
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
      
      const instance1 = SystemPromptManager.getInstance();
      const instance2 = SystemPromptManager.getInstance();
      
      expect(instance1).assertEqual(instance2);
      TestUtils.log('单例模式验证通过');
    });
    
    /**
     * 测试提示词创建
     */
    it('should_create_system_prompts', 0, async () => {
      TestUtils.log('测试提示词创建');
      
      const prompt: SystemPrompt = {
        id: 'test-prompt-1',
        title: '代码审查助手',
        content: '你是一个专业的代码审查助手，请仔细审查以下代码并提供改进建议。',
        category: 'code_review',
        tags: ['代码', '审查', '质量'],
        isDefault: false,
        priority: 1,
        createdAt: Date.now(),
        updatedAt: Date.now()
      };
      
      const createdPrompt = await systemPromptManager.createPrompt(prompt);
      
      // 验证创建结果
      expect(TestUtils.validateObjectStructure(createdPrompt, ['id', 'title', 'content', 'category', 'tags'])).assertTrue();
      expect(createdPrompt.title).assertEqual('代码审查助手');
      expect(createdPrompt.content).assertEqual('你是一个专业的代码审查助手，请仔细审查以下代码并提供改进建议。');
      expect(createdPrompt.category).assertEqual('code_review');
      expect(createdPrompt.tags.length).assertEqual(3);
      
      TestUtils.log('提示词创建测试通过');
    });
    
    /**
     * 测试提示词查询
     */
    it('should_query_system_prompts', 0, async () => {
      TestUtils.log('测试提示词查询');
      
      // 创建测试数据
      const testPrompts = [
        {
          id: 'query-test-1',
          title: 'Python助手',
          content: '你是一个Python专家',
          category: 'programming' as PromptCategory,
          tags: ['Python', '编程']
        },
        {
          id: 'query-test-2',
          title: 'JavaScript助手',
          content: '你是一个JavaScript专家',
          category: 'programming' as PromptCategory,
          tags: ['JavaScript', '编程']
        },
        {
          id: 'query-test-3',
          title: '写作助手',
          content: '你是一个写作专家',
          category: 'writing' as PromptCategory,
          tags: ['写作', '文学']
        }
      ];
      
      for (const prompt of testPrompts) {
        await systemPromptManager.createPrompt(prompt as SystemPrompt);
      }
      
      // 测试获取所有提示词
      const allPrompts = await systemPromptManager.getAllPrompts();
      expect(allPrompts.length).assertGreaterThan(0);
      
      // 测试按分类查询
      const programmingPrompts = await systemPromptManager.getPromptsByCategory('programming');
      expect(programmingPrompts.length).assertGreaterThanOrEqual(2);
      
      // 测试按标签查询
      const pythonPrompts = await systemPromptManager.getPromptsByTag('Python');
      expect(pythonPrompts.length).assertEqual(1);
      expect(pythonPrompts[0].title).assertEqual('Python助手');
      
      // 测试模糊搜索
      const searchResults = await systemPromptManager.searchPrompts('专家');
      expect(searchResults.length).assertGreaterThan(0);
      
      TestUtils.log('提示词查询测试通过');
    });
    
    /**
     * 测试提示词更新
     */
    it('should_update_system_prompts', 0, async () => {
      TestUtils.log('测试提示词更新');
      
      // 创建测试提示词
      const originalPrompt: SystemPrompt = {
        id: 'update-test-1',
        title: '原始标题',
        content: '原始内容',
        category: 'general',
        tags: ['标签1', '标签2'],
        isDefault: false,
        priority: 1,
        createdAt: Date.now(),
        updatedAt: Date.now()
      };
      
      await systemPromptManager.createPrompt(originalPrompt);
      
      // 更新提示词
      const updatedData = {
        title: '更新后的标题',
        content: '更新后的内容',
        category: 'updated',
        tags: ['新标签1', '新标签2', '新标签3'],
        priority: 2
      };
      
      const updatedPrompt = await systemPromptManager.updatePrompt('update-test-1', updatedData);
      
      // 验证更新结果
      expect(updatedPrompt.title).assertEqual('更新后的标题');
      expect(updatedPrompt.content).assertEqual('更新后的内容');
      expect(updatedPrompt.category).assertEqual('updated');
      expect(updatedPrompt.tags.length).assertEqual(3);
      expect(updatedPrompt.priority).assertEqual(2);
      expect(updatedPrompt.updatedAt).assertGreaterThan(originalPrompt.createdAt);
      
      TestUtils.log('提示词更新测试通过');
    });
    
    /**
     * 测试提示词删除
     */
    it('should_delete_system_prompts', 0, async () => {
      TestUtils.log('测试提示词删除');
      
      // 创建测试提示词
      const testPrompt: SystemPrompt = {
        id: 'delete-test-1',
        title: '待删除提示词',
        content: '这个提示词将被删除',
        category: 'test',
        tags: ['测试'],
        isDefault: false,
        priority: 1,
        createdAt: Date.now(),
        updatedAt: Date.now()
      };
      
      await systemPromptManager.createPrompt(testPrompt);
      
      // 验证创建成功
      let prompt = await systemPromptManager.getPromptById('delete-test-1');
      expect(prompt !== null).assertTrue();
      
      // 删除提示词
      const deleteResult = await systemPromptManager.deletePrompt('delete-test-1');
      expect(deleteResult.success).assertTrue();
      
      // 验证删除成功
      prompt = await systemPromptManager.getPromptById('delete-test-1');
      expect(prompt).assertNull();
      
      TestUtils.log('提示词删除测试通过');
    });
    
    /**
     * 测试提示词分类管理
     */
    it('should_manage_prompt_categories', 0, async () => {
      TestUtils.log('测试提示词分类管理');
      
      // 获取所有分类
      const categories = await systemPromptManager.getAllCategories();
      expect(Array.isArray(categories)).assertTrue();
      expect(categories.length).assertGreaterThan(0);
      
      // 创建新分类
      const newCategory = {
        name: 'test_category',
        displayName: '测试分类',
        description: '用于测试的分类',
        color: '#ff6b6b',
        icon: 'test-icon'
      };
      
      await systemPromptManager.createCategory(newCategory);
      
      // 验证分类创建
      const updatedCategories = await systemPromptManager.getAllCategories();
      const testCategory = updatedCategories.find(cat => cat.name === 'test_category');
      expect(testCategory !== undefined).assertTrue();
      if (testCategory) {
        expect(testCategory.displayName).assertEqual('测试分类');
        expect(testCategory.color).assertEqual('#ff6b6b');
      }
      
      // 更新分类
      await systemPromptManager.updateCategory('test_category', {
        displayName: '更新的测试分类',
        description: '更新的描述'
      });
      
      const updatedCategory = await systemPromptManager.getCategory('test_category');
      expect(updatedCategory !== null).assertTrue();
      if (updatedCategory) {
        expect(updatedCategory.displayName).assertEqual('更新的测试分类');
      }
      
      TestUtils.log('提示词分类管理测试通过');
    });
    
    /**
     * 测试提示词标签管理
     */
    it('should_manage_prompt_tags', 0, async () => {
      TestUtils.log('测试提示词标签管理');
      
      // 获取所有标签
      const tags = await systemPromptManager.getAllTags();
      expect(Array.isArray(tags)).assertTrue();
      expect(tags.length).assertGreaterThan(0);
      
      // 测试标签云生成
      const tagCloud = await systemPromptManager.generateTagCloud();
      expect(Array.isArray(tagCloud)).assertTrue();
      tagCloud.forEach(tag => {
        expect(TestUtils.validateObjectStructure(tag, ['name', 'count', 'weight'])).assertTrue();
      });
      
      // 测试热门标签
      const popularTags = await systemPromptManager.getPopularTags(5);
      expect(popularTags.length).assertLessThanOrEqual(5);
      
      // 测试标签建议
      const suggestions = await systemPromptManager.getTagSuggestions('编程');
      expect(Array.isArray(suggestions)).assertTrue();
      
      TestUtils.log('提示词标签管理测试通过');
    });
    
    /**
     * 测试提示词导入导出
     */
    it('should_import_and_export_prompts', 0, async () => {
      TestUtils.log('测试提示词导入导出');
      
      // 创建测试数据
      const testPrompts = [
        {
          id: 'export-test-1',
          title: '导出测试1',
          content: '内容1',
          category: 'test',
          tags: ['导出', '测试']
        },
        {
          id: 'export-test-2',
          title: '导出测试2',
          content: '内容2',
          category: 'test',
          tags: ['导出', '测试']
        }
      ];
      
      for (const prompt of testPrompts) {
        await systemPromptManager.createPrompt(prompt as SystemPrompt);
      }
      
      // 导出提示词
      const exportedData = await systemPromptManager.exportPrompts(['export-test-1', 'export-test-2']);
      expect(typeof exportedData).assertEqual('string');
      
      // 验证导出的JSON
      const parsedData = JSON.parse(exportedData);
      expect(TestUtils.validateObjectStructure(parsedData, ['version', 'prompts', 'exportTime'])).assertTrue();
      expect(parsedData.prompts.length).assertEqual(2);
      
      // 导入提示词
      await systemPromptManager.importPrompts(exportedData);
      
      // 验证导入结果
      const importedPrompts = await systemPromptManager.getAllPrompts();
      const foundPrompts = importedPrompts.filter(p => p.title.startsWith('导出测试'));
      expect(foundPrompts.length).assertGreaterThanOrEqual(2);
      
      TestUtils.log('提示词导入导出测试通过');
    });
    
    /**
     * 测试提示词模板系统
     */
    it('should_handle_prompt_templates', 0, async () => {
      TestUtils.log('测试提示词模板系统');
      
      // 创建模板
      const template = {
        id: 'template-test-1',
        name: '代码审查模板',
        description: '用于代码审查的标准模板',
        template: '你是一个{language}专家，请审查以下代码：\n\n{code}\n\n请重点关注：{focus_areas}',
        variables: [
          { name: 'language', type: 'string', description: '编程语言', required: true },
          { name: 'code', type: 'string', description: '待审查的代码', required: true },
          { name: 'focus_areas', type: 'string', description: '重点关注领域', required: false }
        ],
        category: 'template'
      };
      
      await systemPromptManager.createTemplate(template);
      
      // 验证模板创建
      const createdTemplate = await systemPromptManager.getTemplate('template-test-1');
      expect(createdTemplate !== null).assertTrue();
      if (createdTemplate) {
        expect(createdTemplate.name).assertEqual('代码审查模板');
        expect(createdTemplate.variables.length).assertEqual(3);
      }
      
      // 渲染模板
      const renderData = {
        language: 'Python',
        code: 'def hello():\n    print("Hello, World!")',
        focus_areas: '性能、可读性、错误处理'
      };
      
      const renderedPrompt = await systemPromptManager.renderTemplate('template-test-1', renderData);
      
      // 验证渲染结果
      expect(renderedPrompt.includes('Python')).assertTrue();
      expect(renderedPrompt.includes('def hello():')).assertTrue();
      expect(renderedPrompt.includes('性能、可读性、错误处理')).assertTrue();
      
      TestUtils.log('提示词模板系统测试通过');
    });
    
    /**
     * 测试提示词推荐系统
     */
    it('should_provide_prompt_recommendations', 0, async () => {
      TestUtils.log('测试提示词推荐系统');
      
      // 创建场景化的提示词
      const scenarioPrompts = [
        {
          id: 'scenario-1',
          title: '面试助手',
          content: '你是一个技术面试官',
          category: 'interview',
          tags: ['面试', '技术'],
          scenario: 'technical_interview'
        },
        {
          id: 'scenario-2',
          title: '学习助手',
          content: '你是一个学习导师',
          category: 'education',
          tags: ['学习', '教育'],
          scenario: 'learning'
        }
      ];
      
      for (const prompt of scenarioPrompts) {
        await systemPromptManager.createPrompt(prompt as SystemPrompt);
      }
      
      // 获取场景推荐
      const interviewRecommendations = await systemPromptManager.getRecommendations('technical_interview');
      expect(interviewRecommendations.length).assertGreaterThan(0);
      expect(interviewRecommendations[0].scenario).assertEqual('technical_interview');
      
      // 获取个性化推荐
      const personalRecommendations = await systemPromptManager.getPersonalizedRecommendations({
        recentCategories: ['programming', 'code_review'],
        favoriteTags: ['Python', 'JavaScript']
      });
      expect(Array.isArray(personalRecommendations)).assertTrue();
      
      // 获取趋势推荐
      const trendingPrompts = await systemPromptManager.getTrendingPrompts();
      expect(Array.isArray(trendingPrompts)).assertTrue();
      
      TestUtils.log('提示词推荐系统测试通过');
    });
    
    /**
     * 测试提示词使用统计
     */
    it('should_track_prompt_usage_statistics', 0, async () => {
      TestUtils.log('测试提示词使用统计');
      
      // 模拟提示词使用
      const testPromptId = 'stats-test-1';
      await systemPromptManager.recordPromptUsage(testPromptId);
      await systemPromptManager.recordPromptUsage(testPromptId);
      await systemPromptManager.recordPromptUsage(testPromptId);
      
      // 获取使用统计
      const usageStats = await systemPromptManager.getPromptUsageStats(testPromptId);
      expect(TestUtils.validateObjectStructure(usageStats, ['totalUses', 'recentUses', 'averageRating'])).assertTrue();
      expect(usageStats.totalUses).assertEqual(3);
      
      // 获取热门提示词
      const popularPrompts = await systemPromptManager.getMostPopularPrompts(5);
      expect(Array.isArray(popularPrompts)).assertTrue();
      
      // 获取分类统计
      const categoryStats = await systemPromptManager.getCategoryStatistics();
      expect(Array.isArray(categoryStats)).assertTrue();
      categoryStats.forEach(stat => {
        expect(TestUtils.validateObjectStructure(stat, ['category', 'count', 'percentage'])).assertTrue();
      });
      
      TestUtils.log('提示词使用统计测试通过');
    });
    
    /**
     * 测试提示词验证
     */
    it('should_validate_prompt_content', 0, async () => {
      TestUtils.log('测试提示词验证');
      
      // 测试有效提示词
      const validPrompt = {
        title: '有效提示词',
        content: '这是一个有效的提示词内容，长度足够且格式正确。',
        category: 'test'
      };
      
      const validationResult = await systemPromptManager.validatePrompt(validPrompt);
      expect(validationResult.valid).assertTrue();
      expect(validationResult.errors.length).assertEqual(0);
      
      // 测试无效提示词
      const invalidPrompt = {
        title: '', // 空标题
        content: '短', // 内容过短
        category: 'invalid_category'
      };
      
      const invalidResult = await systemPromptManager.validatePrompt(invalidPrompt);
      expect(invalidResult.valid).assertFalse();
      expect(invalidResult.errors.length).assertGreaterThan(0);
      
      // 测试内容安全检查
      const suspiciousPrompt = {
        title: '可疑提示词',
        content: '包含敏感内容：密码、密钥、个人信息等',
        category: 'test'
      };
      
      const securityResult = await systemPromptManager.checkPromptSecurity(suspiciousPrompt);
      expect(securityResult.safe).assertFalse();
      expect(securityResult.issues.length).assertGreaterThan(0);
      
      TestUtils.log('提示词验证测试通过');
    });
    
    /**
     * 测试提示词性能优化
     */
    it('should_optimize_prompt_performance', 0, async () => {
      TestUtils.log('测试提示词性能优化');
      
      // 批量创建提示词
      const batchPrompts = [];
      for (let i = 0; i < 100; i++) {
        batchPrompts.push({
          id: `batch-test-${i}`,
          title: `批量测试${i}`,
          content: `批量测试内容${i}`,
          category: 'test',
          tags: [`标签${i}`]
        });
      }
      
      const startTime = Date.now();
      await systemPromptManager.batchCreatePrompts(batchPrompts as SystemPrompt[]);
      const endTime = Date.now();
      
      // 验证批量操作性能
      expect(endTime - startTime).assertLessThan(5000);
      
      // 测试缓存性能
      const cacheStats = await systemPromptManager.getCacheStatistics();
      expect(TestUtils.validateObjectStructure(cacheStats, ['hits', 'misses', 'hitRate'])).assertTrue();
      
      // 测试搜索性能
      const searchStartTime = Date.now();
      const searchResults = await systemPromptManager.searchPrompts('批量测试');
      const searchEndTime = Date.now();
      
      expect(searchEndTime - searchStartTime).assertLessThan(1000);
      expect(searchResults.length).assertGreaterThan(0);
      
      TestUtils.log('提示词性能优化测试通过');
    });
    
    /**
     * 测试提示词版本管理
     */
    it('should_manage_prompt_versions', 0, async () => {
      TestUtils.log('测试提示词版本管理');
      
      // 创建提示词
      const prompt: SystemPrompt = {
        id: 'version-test-1',
        title: '版本测试',
        content: '版本1内容',
        category: 'test',
        version: '1.0.0'
      } as SystemPrompt;
      
      await systemPromptManager.createPrompt(prompt);
      
      // 创建新版本
      const version2Data = {
        content: '版本2内容',
        changelog: '更新内容，改进功能'
      };
      
      const version2Prompt = await systemPromptManager.createVersion('version-test-1', '2.0.0', version2Data);
      expect(version2Prompt.version).assertEqual('2.0.0');
      expect(version2Prompt.content).assertEqual('版本2内容');
      
      // 获取版本历史
      const versionHistory = await systemPromptManager.getVersionHistory('version-test-1');
      expect(versionHistory.length).assertEqual(2);
      expect(versionHistory[0].version).assertEqual('1.0.0');
      expect(versionHistory[1].version).assertEqual('2.0.0');
      
      // 恢复到指定版本
      const restoredPrompt = await systemPromptManager.restoreVersion('version-test-1', '1.0.0');
      expect(restoredPrompt.content).assertEqual('版本1内容');
      
      TestUtils.log('提示词版本管理测试通过');
    });
  });
}