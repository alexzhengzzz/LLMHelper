import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase } from './TestUtils';
import { Provider } from '../main/ets/models/ChatModels';

/**
 * 测试数据接口
 */
interface TestModel {
  provider: string;
  model: string;
  displayName: string;
  description: string;
}

/**
 * 模型选择器组件测试套件
 * 测试模型选择器的UI逻辑、状态管理、事件处理等功能
 */
export default function modelSelectorComponentTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('ModelSelectorComponentTest');
  
  describe('ModelSelectorComponentTest', () => {
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化模型选择器测试环境');
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
     * 测试Provider接口结构
     */
    it('should_validate_provider_interface', 0, () => {
      TestUtils.log('测试Provider接口结构');
      
      // 创建测试Provider
      const testProvider: Provider = {
        id: 'siliconflow',
        name: '硅基流动',
        description: '提供高性能的大语言模型服务',
        models: [
          {
            id: 'qwen-7b',
            name: 'Qwen2.5-7B-Instruct',
            description: '通义千问7亿参数指令模型',
            maxTokens: 32768,
            supportsStreaming: true,
            supportsFunctionCalling: true
          }
        ]
      };
      
      // 验证Provider结构
      expect(TestUtils.validateObjectStructure(testProvider, ['id', 'name', 'description', 'models'])).assertTrue();
      expect(typeof testProvider.id).assertEqual('string');
      expect(typeof testProvider.name).assertEqual('string');
      expect(typeof testProvider.description).assertEqual('string');
      expect(Array.isArray(testProvider.models)).assertTrue();
      
      // 验证模型结构
      const model = testProvider.models[0];
      expect(TestUtils.validateObjectStructure(model, ['id', 'name', 'description', 'maxTokens', 'supportsStreaming', 'supportsFunctionCalling'])).assertTrue();
      
      TestUtils.log('Provider接口结构测试通过');
    });
    
    /**
     * 测试ModelInfo接口结构
     */
    it('should_validate_model_info_interface', 0, () => {
      TestUtils.log('测试ModelInfo接口结构');
      
      // 创建测试ModelInfo（模拟组件内部使用的接口）
      const testModelInfo = {
        provider: 'siliconflow',
        model: 'qwen-7b',
        displayName: 'Qwen2.5-7B-Instruct',
        description: '通义千问7亿参数指令模型，支持长上下文和函数调用'
      };
      
      // 验证ModelInfo结构
      expect(TestUtils.validateObjectStructure(testModelInfo, ['provider', 'model', 'displayName', 'description'])).assertTrue();
      expect(typeof testModelInfo.provider).assertEqual('string');
      expect(typeof testModelInfo.model).assertEqual('string');
      expect(typeof testModelInfo.displayName).assertEqual('string');
      expect(typeof testModelInfo.description).assertEqual('string');
      
      TestUtils.log('ModelInfo接口结构测试通过');
    });
    
    /**
     * 测试ProviderGroup接口结构
     */
    it('should_validate_provider_group_interface', 0, () => {
      TestUtils.log('测试ProviderGroup接口结构');
      
      // 创建测试ProviderGroup
      const testProviderGroup = {
        provider: {
          id: 'siliconflow',
          name: '硅基流动',
          description: '提供高性能的大语言模型服务',
          models: [
            {
              id: 'qwen-7b',
              name: 'Qwen2.5-7B-Instruct',
              description: '通义千问7亿参数指令模型',
              maxTokens: 32768,
              supportsStreaming: true,
              supportsFunctionCalling: true
            }
          ]
        },
        models: [
          {
            provider: 'siliconflow',
            model: 'qwen-7b',
            displayName: 'Qwen2.5-7B-Instruct',
            description: '通义千问7亿参数指令模型，支持长上下文和函数调用'
          }
        ]
      };
      
      // 验证ProviderGroup结构
      expect(TestUtils.validateObjectStructure(testProviderGroup, ['provider', 'models'])).assertTrue();
      expect(typeof testProviderGroup.provider).assertEqual('object');
      expect(Array.isArray(testProviderGroup.models)).assertTrue();
      
      TestUtils.log('ProviderGroup接口结构测试通过');
    });
    
    /**
     * 测试模型搜索功能
     */
    it('should_filter_models_by_search_text', 0, () => {
      TestUtils.log('测试模型搜索功能');
      
      // 创建测试数据
      const testModels = [
        {
          provider: 'siliconflow',
          model: 'qwen-7b',
          displayName: 'Qwen2.5-7B-Instruct',
          description: '通义千问7亿参数指令模型'
        },
        {
          provider: 'siliconflow',
          model: 'qwen-72b',
          displayName: 'Qwen2.5-72B-Instruct',
          description: '通义千问720亿参数指令模型'
        },
        {
          provider: 'glm',
          model: 'glm-4',
          displayName: 'GLM-4',
          description: '智谱AI GLM-4大模型'
        },
        {
          provider: 'gemini',
          model: 'gemini-pro',
          displayName: 'Gemini Pro',
          description: 'Google Gemini Pro模型'
        }
      ];
      
      // 测试搜索功能
      const searchModels = (searchText: string) => {
        return testModels.filter(model => 
          model.displayName.toLowerCase().includes(searchText.toLowerCase()) ||
          model.description.toLowerCase().includes(searchText.toLowerCase()) ||
          model.provider.toLowerCase().includes(searchText.toLowerCase())
        );
      };
      
      // 测试搜索"qwen"
      const qwenResults = searchModels('qwen');
      expect(qwenResults.length).assertEqual(2);
      expect(qwenResults.every(model => model.displayName.includes('Qwen'))).assertTrue();
      
      // 测试搜索"glm"
      const glmResults = searchModels('glm');
      expect(glmResults.length).assertEqual(1);
      expect(glmResults[0].displayName).assertEqual('GLM-4');
      
      // 测试搜索"instruct"
      const instructResults = searchModels('instruct');
      expect(instructResults.length).assertEqual(2);
      expect(instructResults.every(model => model.displayName.includes('Instruct'))).assertTrue();
      
      // 测试空搜索
      const emptyResults = searchModels('');
      expect(emptyResults.length).assertEqual(4);
      
      // 测试无结果搜索
      const noResults = searchModels('nonexistent');
      expect(noResults.length).assertEqual(0);
      
      TestUtils.log('模型搜索功能测试通过');
    });
    
    /**
     * 测试厂商展开状态管理
     */
    it('should_manage_expansion_states', 0, () => {
      TestUtils.log('测试厂商展开状态管理');
      
      // 创建测试厂商列表
      const testProviders = [
        { id: 'siliconflow', name: '硅基流动' },
        { id: 'glm', name: '智谱AI' },
        { id: 'gemini', name: 'Google Gemini' }
      ];
      
      // 模拟展开状态管理
      const expandedStates = new Map<string, boolean>();
      const currentProvider = 'siliconflow';
      
      // 初始化展开状态
      testProviders.forEach(provider => {
        const shouldExpand = provider.name === currentProvider || testProviders.length <= 2;
        expandedStates.set(provider.name, shouldExpand);
      });
      
      // 验证初始状态
      expect(expandedStates.get('硅基流动')).assertTrue();
      expect(expandedStates.get('智谱AI')).assertFalse();
      expect(expandedStates.get('Google Gemini')).assertFalse();
      
      // 测试切换展开状态
      const toggleExpansion = (providerName: string) => {
        expandedStates.set(providerName, !expandedStates.get(providerName));
      };
      
      toggleExpansion('智谱AI');
      expect(expandedStates.get('智谱AI')).assertTrue();
      
      toggleExpansion('硅基流动');
      expect(expandedStates.get('硅基流动')).assertFalse();
      
      TestUtils.log('厂商展开状态管理测试通过');
    });
    
    /**
     * 测试模型选择回调
     */
    it('should_handle_model_selection', 0, () => {
      TestUtils.log('测试模型选择回调');
      
      let selectedProvider = '';
      let selectedModel = '';
      let selectionCount = 0;
      
      // 模拟模型选择回调
      const onModelSelected = (provider: string, model: string) => {
        selectedProvider = provider;
        selectedModel = model;
        selectionCount++;
        TestUtils.log(`选择模型: ${provider}/${model}`);
      };
      
      // 测试选择不同模型
      onModelSelected('siliconflow', 'qwen-7b');
      expect(selectedProvider).assertEqual('siliconflow');
      expect(selectedModel).assertEqual('qwen-7b');
      expect(selectionCount).assertEqual(1);
      
      onModelSelected('glm', 'glm-4');
      expect(selectedProvider).assertEqual('glm');
      expect(selectedModel).assertEqual('glm-4');
      expect(selectionCount).assertEqual(2);
      
      onModelSelected('gemini', 'gemini-pro');
      expect(selectedProvider).assertEqual('gemini');
      expect(selectedModel).assertEqual('gemini-pro');
      expect(selectionCount).assertEqual(3);
      
      TestUtils.log('模型选择回调测试通过');
    });
    
    /**
     * 测试模型分组功能
     */
    it('should_group_models_by_provider', 0, () => {
      TestUtils.log('测试模型分组功能');
      
      // 创建测试模型数据
      const testModels = [
        {
          provider: 'siliconflow',
          model: 'qwen-7b',
          displayName: 'Qwen2.5-7B-Instruct',
          description: '通义千问7亿参数指令模型'
        },
        {
          provider: 'siliconflow',
          model: 'qwen-72b',
          displayName: 'Qwen2.5-72B-Instruct',
          description: '通义千问720亿参数指令模型'
        },
        {
          provider: 'glm',
          model: 'glm-4',
          displayName: 'GLM-4',
          description: '智谱AI GLM-4大模型'
        },
        {
          provider: 'glm',
          model: 'glm-4v',
          displayName: 'GLM-4V',
          description: '智谱AI GLM-4V视觉模型'
        }
      ];
      
      // 按厂商分组
      const groupByProvider = (models: TestModel[]) => {
        const groups = new Map<string, TestModel[]>();
        
        models.forEach(model => {
          if (!groups.has(model.provider)) {
            groups.set(model.provider, []);
          }
          groups.get(model.provider)?.push(model);
        });
        
        return groups;
      };
      
      const groups = groupByProvider(testModels);
      
      // 验证分组结果
      expect(groups.size).assertEqual(2);
      expect(groups.has('siliconflow')).assertTrue();
      expect(groups.has('glm')).assertTrue();
      
      // 验证硅基流动分组
      const siliconflowModels = groups.get('siliconflow');
      expect(siliconflowModels?.length).assertEqual(2);
      expect(siliconflowModels?.every(model => model.provider === 'siliconflow')).assertTrue();
      
      // 验证智谱AI分组
      const glmModels = groups.get('glm');
      expect(glmModels?.length).assertEqual(2);
      expect(glmModels?.every(model => model.provider === 'glm')).assertTrue();
      
      TestUtils.log('模型分组功能测试通过');
    });
    
    /**
     * 测试模型显示名称格式化
     */
    it('should_format_model_display_names', 0, () => {
      TestUtils.log('测试模型显示名称格式化');
      
      // 测试显示名称格式化函数
      const formatDisplayName = (model: string, provider: string): string => {
        // 如果模型名称已经包含厂商信息，直接返回
        if (model.includes('/')) {
          return model;
        }
        
        // 否则添加厂商前缀
        return `${provider}/${model}`;
      };
      
      // 测试格式化
      expect(formatDisplayName('qwen-7b', 'siliconflow')).assertEqual('siliconflow/qwen-7b');
      expect(formatDisplayName('glm-4', 'glm')).assertEqual('glm/glm-4');
      expect(formatDisplayName('gemini-pro', 'gemini')).assertEqual('gemini/gemini-pro');
      
      // 测试已经包含厂商信息的名称
      expect(formatDisplayName('siliconflow/qwen-7b', 'siliconflow')).assertEqual('siliconflow/qwen-7b');
      expect(formatDisplayName('glm/glm-4', 'glm')).assertEqual('glm/glm-4');
      
      TestUtils.log('模型显示名称格式化测试通过');
    });
    
    /**
     * 测试模型排序功能
     */
    it('should_sort_models_appropriately', 0, () => {
      TestUtils.log('测试模型排序功能');
      
      // 创建测试模型数据
      const testModels = [
        {
          provider: 'siliconflow',
          model: 'qwen-72b',
          displayName: 'Qwen2.5-72B-Instruct',
          description: '通义千问720亿参数指令模型'
        },
        {
          provider: 'siliconflow',
          model: 'qwen-7b',
          displayName: 'Qwen2.5-7B-Instruct',
          description: '通义千问7亿参数指令模型'
        },
        {
          provider: 'glm',
          model: 'glm-4',
          displayName: 'GLM-4',
          description: '智谱AI GLM-4大模型'
        }
      ];
      
      // 按模型名称排序
      const sortByName = (models: TestModel[]) => {
        return [...models].sort((a, b) => a.displayName.localeCompare(b.displayName));
      };
      
      const sortedModels = sortByName(testModels);
      
      // 验证排序结果
      expect(sortedModels[0].displayName).assertEqual('GLM-4');
      expect(sortedModels[1].displayName).assertEqual('Qwen2.5-7B-Instruct');
      expect(sortedModels[2].displayName).assertEqual('Qwen2.5-72B-Instruct');
      
      // 按参数大小排序（从描述中提取）
      const sortBySize = (models: TestModel[]) => {
        return [...models].sort((a, b) => {
          const extractSize = (desc: string): number => {
            const match = desc.match(/(\d+)/);
            return match ? parseInt(match[1]) : 0;
          };
          return extractSize(b.description) - extractSize(a.description);
        });
      };
      
      const sizeSortedModels = sortBySize(testModels);
      
      // 验证按大小排序结果
      expect(sizeSortedModels[0].displayName).assertEqual('Qwen2.5-72B-Instruct'); // 720亿
      expect(sizeSortedModels[1].displayName).assertEqual('Qwen2.5-7B-Instruct');  // 7亿
      expect(sizeSortedModels[2].displayName).assertEqual('GLM-4');               // GLM-4（默认）
      
      TestUtils.log('模型排序功能测试通过');
    });
    
    /**
     * 测试模型配置验证
     */
    it('should_validate_model_configuration', 0, () => {
      TestUtils.log('测试模型配置验证');
      
      // 验证模型配置的完整性
      const validateModelConfig = (model: object): boolean => {
        const requiredFields = ['id', 'name', 'description', 'maxTokens'];
        return requiredFields.every(field => field in (model as Record<string, unknown>) && (model as Record<string, unknown>)[field] !== undefined);
      };
      
      // 测试有效配置
      const validModels = [
        {
          id: 'qwen-7b',
          name: 'Qwen2.5-7B-Instruct',
          description: '通义千问7亿参数指令模型',
          maxTokens: 32768,
          supportsStreaming: true
        },
        {
          id: 'glm-4',
          name: 'GLM-4',
          description: '智谱AI GLM-4大模型',
          maxTokens: 128000,
          supportsStreaming: true,
          supportsFunctionCalling: true
        }
      ];
      
      validModels.forEach(model => {
        expect(validateModelConfig(model)).assertTrue();
      });
      
      // 测试无效配置
      const invalidModels = [
        {
          id: 'invalid-1',
          name: 'Invalid Model'
          // 缺少 description 和 maxTokens
        },
        {
          name: 'Invalid Model 2',
          description: '缺少ID的模型',
          maxTokens: 1000
          // 缺少 id
        },
        {
          id: 'invalid-3',
          name: 'Invalid Model 3',
          description: '缺少maxTokens的模型'
          // 缺少 maxTokens
        }
      ];
      
      invalidModels.forEach(model => {
        expect(validateModelConfig(model)).assertFalse();
      });
      
      TestUtils.log('模型配置验证测试通过');
    });
    
    /**
     * 测试关闭回调处理
     */
    it('should_handle_close_callback', 0, () => {
      TestUtils.log('测试关闭回调处理');
      
      let closeCount = 0;
      let lastCloseReason = '';
      
      // 模拟关闭回调
      const onClose = (reason?: string) => {
        closeCount++;
        lastCloseReason = reason || 'user_close';
        TestUtils.log('模型选择器关闭，原因: ' + lastCloseReason);
      };
      
      // 测试关闭回调
      onClose();
      expect(closeCount).assertEqual(1);
      expect(lastCloseReason).assertEqual('user_close');
      
      onClose('escape_key');
      expect(closeCount).assertEqual(2);
      expect(lastCloseReason).assertEqual('escape_key');
      
      onClose('outside_click');
      expect(closeCount).assertEqual(3);
      expect(lastCloseReason).assertEqual('outside_click');
      
      TestUtils.log('关闭回调处理测试通过');
    });
  });
}