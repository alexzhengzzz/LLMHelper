import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 鸿蒙客户端完整测试套件
 * 导入所有测试模块并执行
 */

// 导入测试工具类
import { TestUtils } from './TestUtils';

// 导入核心服务测试
import apiManagerTest from './APIManagerTest';
import webSocketServiceTest from './WebSocketServiceTest';
import speechServiceTest from './SpeechServiceTest';
import apiServiceTest from './ApiServiceTest';
import deepThinkingServiceTest from './DeepThinkingServiceTest';
import hybridChatServiceTest from './HybridChatServiceTest';

// 导入数据存储测试
import appStorageTest from './AppStorageTest';
import sessionManagerTest from './SessionManagerTest';

// 导入UI组件测试
import modelSelectorComponentTest from './ModelSelectorComponentTest';
import voiceInputComponentTest from './VoiceInputComponentTest';
import smartTextRendererTest from './SmartTextRendererTest';
import deepThinkingDialogTest from './DeepThinkingDialogTest';

// 导入工具类测试
import themeManagerTest from './ThemeManagerTest';
import systemPromptManagerTest from './SystemPromptManagerTest';

/**
 * 主测试套件
 */
export default function testsuite() {
  describe('鸿蒙客户端完整测试套件', () => {
    
    beforeAll(() => {
      TestUtils.log('🚀 开始执行鸿蒙客户端完整测试套件');
    });
    
    afterAll(() => {
      TestUtils.log('✅ 鸿蒙客户端完整测试套件执行完成');
    });
    
    // 执行核心服务测试
    TestUtils.log('📦 执行核心服务测试...');
    apiManagerTest();
    webSocketServiceTest();
    speechServiceTest();
    apiServiceTest();
    deepThinkingServiceTest();
    hybridChatServiceTest();
    
    // 执行数据存储测试
    TestUtils.log('💾 执行数据存储测试...');
    appStorageTest();
    sessionManagerTest();
    
    // 执行UI组件测试
    TestUtils.log('🎨 执行UI组件测试...');
    modelSelectorComponentTest();
    voiceInputComponentTest();
    smartTextRendererTest();
    deepThinkingDialogTest();
    
    // 执行工具类测试
    TestUtils.log('🛠️ 执行工具类测试...');
    themeManagerTest();
    systemPromptManagerTest();
  });
}

/**
 * 测试套件信息
 */
export const TestSuiteInfo = {
  name: '鸿蒙客户端完整测试套件',
  version: '1.0.0',
  description: 'Javis AI编程助手鸿蒙客户端的完整测试覆盖',
  testModules: [
    {
      name: 'APIManagerTest',
      category: '核心服务',
      description: 'API管理器功能测试'
    },
    {
      name: 'WebSocketServiceTest',
      category: '核心服务',
      description: 'WebSocket服务功能测试'
    },
    {
      name: 'SpeechServiceTest',
      category: '核心服务',
      description: '语音识别和TTS服务测试'
    },
    {
      name: 'ApiServiceTest',
      category: '核心服务',
      description: '基础API服务功能测试'
    },
    {
      name: 'DeepThinkingServiceTest',
      category: '核心服务',
      description: '深度思考服务功能测试'
    },
    {
      name: 'HybridChatServiceTest',
      category: '核心服务',
      description: '混合聊天服务功能测试'
    },
    {
      name: 'AppStorageTest',
      category: '数据存储',
      description: '应用数据存储管理测试'
    },
    {
      name: 'SessionManagerTest',
      category: '数据存储',
      description: '会话管理功能测试'
    },
    {
      name: 'ModelSelectorComponentTest',
      category: 'UI组件',
      description: '模型选择器组件测试'
    },
    {
      name: 'VoiceInputComponentTest',
      category: 'UI组件',
      description: '语音输入组件测试'
    },
    {
      name: 'SmartTextRendererTest',
      category: 'UI组件',
      description: '智能文本渲染器测试'
    },
    {
      name: 'DeepThinkingDialogTest',
      category: 'UI组件',
      description: '深度思考对话框测试'
    },
    {
      name: 'ThemeManagerTest',
      category: '工具类',
      description: '主题管理器测试'
    },
    {
      name: 'SystemPromptManagerTest',
      category: '工具类',
      description: '系统提示词管理器测试'
    }
  ],
  totalTestCases: 0, // 将在运行时统计
  estimatedDuration: '5-8分钟'
};

/**
 * 测试统计信息
 */
export const TestStatistics = {
  totalTests: 0,
  passedTests: 0,
  failedTests: 0,
  skippedTests: 0,
  startTime: 0,
  endTime: 0,
  duration: 0,
  
  start(): void {
    this.startTime = Date.now();
    TestUtils.log('📊 测试统计开始计时');
  },
  
  end(): void {
    this.endTime = Date.now();
    this.duration = this.endTime - this.startTime;
    TestUtils.log(`📊 测试执行完成，耗时: ${this.duration}ms`);
  },
  
  getSummary(): string {
    return `
📋 测试执行摘要
================================
总测试数: ${this.totalTests}
通过测试: ${this.passedTests}
失败测试: ${this.failedTests}
跳过测试: ${this.skippedTests}
执行时间: ${this.duration}ms
成功率: ${this.totalTests > 0 ? ((this.passedTests / this.totalTests) * 100).toFixed(2) : 0}%
================================`;
  }
};

/**
 * 测试环境检查
 */
export const TestEnvironment = {
  checkEnvironment(): boolean {
    TestUtils.log('🔍 检查测试环境...');
    
    try {
      // 检查必要的全局对象和模块
      if (typeof describe === 'undefined') {
        TestUtils.error('测试框架未正确初始化：describe函数不存在');
        return false;
      }
      
      if (typeof it === 'undefined') {
        TestUtils.error('测试框架未正确初始化：it函数不存在');
        return false;
      }
      
      if (typeof expect === 'undefined') {
        TestUtils.error('测试框架未正确初始化：expect函数不存在');
        return false;
      }
      
      // 检查HarmonyOS特定API
      if (typeof hilog === 'undefined') {
        TestUtils.warn('hilog模块不可用，将使用console替代');
      }
      
      TestUtils.log('✅ 测试环境检查通过');
      return true;
    } catch (error) {
      TestUtils.error(`测试环境检查失败: ${error}`);
      return false;
    }
  },
  
  getSystemInfo(): string {
    return `
🖥️  系统信息
================================
测试平台: HarmonyOS
测试框架: @ohos/hypium
测试时间: ${new Date().toISOString()}
Node.js版本: N/A
================================`;
  }
};