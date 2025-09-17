import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 测试数据接口定义
 */
export interface MockMessage {
  id: string;
  content: string;
  role: 'user' | 'assistant';
  timestamp: number;
  thinking?: string;
}

export interface MockSession {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  messageCount: number;
}

export interface MockSystemPrompt {
  id: string;
  title: string;
  content: string;
  category: string;
  isDefault: boolean;
  createdAt: number;
  updatedAt: number;
}

/**
 * 测试工具类 - 提供通用的测试辅助功能
 */
export class TestUtils {
  private static readonly TEST_LOG_PREFIX = '[Test]';
  
  /**
   * 记录测试日志
   */
  static log(message: string, tag: string = 'TestUtils'): void {
    hilog.info(0x0000, tag, `${TestUtils.TEST_LOG_PREFIX} %{public}s`, message);
  }
  
  /**
   * 记录测试错误
   */
  static error(message: string, tag: string = 'TestUtils'): void {
    hilog.error(0x0000, tag, `${TestUtils.TEST_LOG_PREFIX} %{public}s`, message);
  }
  
  /**
   * 记录测试警告
   */
  static warn(message: string, tag: string = 'TestUtils'): void {
    hilog.warn(0x0000, tag, `${TestUtils.TEST_LOG_PREFIX} %{public}s`, message);
  }
  
  /**
   * 创建模拟数据 - 消息
   */
  static createMockMessage(id: string, content: string, role: 'user' | 'assistant' = 'user'): MockMessage {
    return {
      id,
      content,
      role,
      timestamp: Date.now(),
      thinking: role === 'assistant' ? '思考过程...' : undefined
    };
  }
  
  /**
   * 创建模拟数据 - 会话
   */
  static createMockSession(id: string, title: string, messageCount: number = 0): MockSession {
    return {
      id,
      title,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      messageCount
    };
  }
  
  /**
   * 创建模拟数据 - 系统提示词
   */
  static createMockSystemPrompt(id: string, title: string, content: string, category: string = '通用'): MockSystemPrompt {
    return {
      id,
      title,
      content,
      category,
      isDefault: false,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
  }
  
  /**
   * 等待指定时间
   */
  static async sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
  
  /**
   * 验证对象结构
   */
  static validateObjectStructure(obj: object, expectedFields: string[]): boolean {
    if (!obj || typeof obj !== 'object') {
      return false;
    }
    
    const objRecord = obj as Record<string, Object | string | number | boolean>;
    return expectedFields.every(field => objRecord[field] !== undefined);
  }
  
  /**
   * 生成随机ID
   */
  static generateRandomId(): string {
    return `test_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
  
  /**
   * 清理测试数据
   */
  static async cleanupTestData(): Promise<void> {
    // 这里可以添加清理测试数据的逻辑
    TestUtils.log('测试数据清理完成');
  }
}

/**
 * 测试套件基类 - 提供通用的测试设置和清理
 */
export class TestSuiteBase {
  protected testTag: string = 'TestSuite';
  
  beforeAll(): void {
    TestUtils.log(`测试套件开始: ${this.testTag}`, this.testTag);
  }
  
  afterAll(): void {
    TestUtils.log(`测试套件结束: ${this.testTag}`, this.testTag);
  }
  
  beforeEach(): void {
    TestUtils.log('开始测试用例', this.testTag);
  }
  
  afterEach(): void {
    TestUtils.log('结束测试用例', this.testTag);
  }
  
  /**
   * 设置测试标签
   */
  public setTestTag(tag: string): void {
    this.testTag = tag;
  }
  
  /**
   * 创建测试失败的错误信息
   */
  protected createTestErrorMessage(operation: string, expected: object, actual: object): string {
    return `${operation} 失败 - 期望: ${JSON.stringify(expected)}, 实际: ${JSON.stringify(actual)}`;
  }
}

/**
 * 异步测试工具类
 */
export class AsyncTestUtils {
  /**
   * 测试异步操作超时
   */
  static async withTimeout<T>(
    operation: Promise<T>, 
    timeoutMs: number = 5000,
    operationName: string = '异步操作'
  ): Promise<T> {
    const timeoutPromise = new Promise<never>((_, reject) => {
      setTimeout(() => {
        reject(new Error(`${operationName} 超时 (${timeoutMs}ms)`));
      }, timeoutMs);
    });
    
    return Promise.race([operation, timeoutPromise]);
  }
  
  /**
   * 重试机制
   */
  static async withRetry<T>(
    operation: () => Promise<T>,
    maxRetries: number = 3,
    delayMs: number = 1000,
    operationName: string = '异步操作'
  ): Promise<T> {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        if (attempt === maxRetries) {
          throw new Error(`${operationName} 重试 ${maxRetries} 次后仍然失败: ${error}`);
        }
        TestUtils.warn(`${operationName} 第 ${attempt} 次尝试失败，${delayMs}ms 后重试`, 'AsyncTestUtils');
        await TestUtils.sleep(delayMs);
      }
    }
    
    throw new Error(`${operationName} 重试逻辑异常`);
  }
  
  /**
   * 等待条件满足
   */
  static async waitForCondition(
    condition: () => boolean | Promise<boolean>,
    timeoutMs: number = 5000,
    intervalMs: number = 100,
    conditionName: string = '条件'
  ): Promise<void> {
    const startTime = Date.now();
    
    while (Date.now() - startTime < timeoutMs) {
      const result = await condition();
      if (result) {
        return;
      }
      await TestUtils.sleep(intervalMs);
    }
    
    throw new Error(`等待 ${conditionName} 超时 (${timeoutMs}ms)`);
  }
}