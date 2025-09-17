/**
 * 深度思考服务 - 实现多轮推理引擎
 */

import { Message, MessageRole, ThinkingStep, ThinkingStatus, StepStatus, SimpleMessage } from '../models/ChatModels';
import { APIManager, APIMode } from './APIManager';
import { ChatRequest as APIChatRequest, ChatMessage as APIChatMessage } from '../types/APITypes';
import { Logger } from '../utils/Logger';
import { ContentCompressor } from './ContentCompressor';

// 深度思考配置
interface DeepThinkingConfig {
  maxRetries: number;        // 最大重试次数
  timeoutMs: number;         // 单步超时时间
  fallbackEnabled: boolean;  // 是否启用降级
  temperature: number;       // 温度参数
  maxTokens: number;         // 最大token数
}

// 完成步骤接口
interface CompletedStep {
  content: string;
  type: string;
}

// 深度思考步骤定义
interface StepDefinition {
  id: string;
  title: string;
  description: string;
  prompt: string;
}

// 深度思考结果
export interface DeepThinkingResult {
  success: boolean;
  finalAnswer: string;
  steps: ThinkingStep[];
  totalTime: number;
  fallbackUsed: boolean;
  error?: string;
}

// 进度回调
export interface DeepThinkingCallbacks {
  onStepStart?: (step: ThinkingStep) => void;
  onStepComplete?: (step: ThinkingStep) => void;
  onStepError?: (step: ThinkingStep, error: string) => void;
  onProgress?: (currentStep: number, totalSteps: number) => void;
  onComplete?: (result: DeepThinkingResult) => void;
  onError?: (error: string) => void;
}

/**
 * 深度思考服务
 */
export class DeepThinkingService {
  private static instance: DeepThinkingService;
  private apiManager: APIManager;
  private config: DeepThinkingConfig;
  private stepDefinitions: StepDefinition[];
  private contentCompressor: ContentCompressor;
  private isProcessing: boolean = false;
  private currentProcessId: string | null = null;
  private cancellationToken: boolean = false;

  private constructor() {
    this.apiManager = APIManager.getInstance();
    this.contentCompressor = ContentCompressor.getInstance();
    this.config = {
      maxRetries: 2,
      timeoutMs: 120000, // 120秒超时
      fallbackEnabled: true,
      temperature: 0.9,
      maxTokens: 10000
    };
    
    // 定义固定的4步推理框架
    this.stepDefinitions = [
      {
        id: 'analyze',
        title: '🔍 深度分析',
        description: '分析问题的核心要点和关键信息',
        prompt: '分析问题的核心要点和关键因素：{question}\n\n请提供：\n1. 核心要点\n2. 关键因素\n3. 复杂性和挑战'
      },
      {
        id: 'think',
        title: '🧠 多角度思考',
        description: '从多个角度深入思考可能的解决方案',
        prompt: '基于分析结果思考解决方案：{question}\n\n前分析：{previousStep}\n\n请考虑：\n1. 理论和实践方案\n2. 不同角度观点\n3. 风险和机遇'
      },
      {
        id: 'verify',
        title: '✅ 批判性验证',
        description: '批判性地验证和反驳前面的思考结果',
        prompt: '批判性审视前面的分析和思考：{question}\n\n分析：{step1}\n思考：{step2}\n\n请验证：\n1. 逻辑漏洞\n2. 反驳观点\n3. 遗漏因素\n4. 反例情况'
      },
      {
        id: 'integrate',
        title: '🎯 综合整合',
        description: '整合所有思考结果，提供最终的综合性答案',
        prompt: '整合所有思考结果，提供最终答案：{question}\n\n分析：{step1}\n思考：{step2}\n验证：{step3}\n\n请提供：\n1. 关键洞察\n2. 明确结论\n3. 推理依据\n4. 行动建议'
      }
    ];
  }

  public static getInstance(): DeepThinkingService {
    if (!DeepThinkingService.instance) {
      DeepThinkingService.instance = new DeepThinkingService();
    }
    return DeepThinkingService.instance;
  }

  /**
   * 启动深度思考过程
   */
  async startDeepThinking(
    question: string,
    model: string,
    messages: SimpleMessage[],
    callbacks?: DeepThinkingCallbacks
  ): Promise<DeepThinkingResult> {
    if (this.isProcessing) {
      throw new Error('深度思考服务正忙，请稍后再试');
    }

    this.isProcessing = true;
    this.cancellationToken = false;
    this.currentProcessId = this.generateProcessId();
    
    const startTime = Date.now();
    const steps: ThinkingStep[] = [];
    let fallbackUsed = false;
    
    try {
      Logger.info('DeepThinkingService', `开始深度思考过程: ${this.currentProcessId}`);
      Logger.info('DeepThinkingService', `问题: ${question.substring(0, 100)}...`);
      
      // 初始化所有步骤
      for (const stepDef of this.stepDefinitions) {
        const step = new ThinkingStep(stepDef.id, stepDef.title, stepDef.description);
        steps.push(step);
      }
      
      // 依次执行每个步骤
      for (let i = 0; i < this.stepDefinitions.length; i++) {
        if (this.cancellationToken) {
          Logger.info('DeepThinkingService', '深度思考过程被取消');
          throw new Error('深度思考过程被用户取消');
        }
        
        const stepDef = this.stepDefinitions[i];
        const step = steps[i];
        
        Logger.info('DeepThinkingService', `开始执行步骤 ${i + 1}/${this.stepDefinitions.length}: ${step.title}`);
        
        // 触发步骤开始回调
        callbacks?.onStepStart?.(step);
        callbacks?.onProgress?.(i + 1, this.stepDefinitions.length);
        
        try {
          step.start();
          
          // 构建步骤特定的提示词
          const stepPrompt = this.buildStepPrompt(stepDef, question, steps, i);
          
          // 执行API调用
          const stepResult = await this.executeStep(stepPrompt, model);
          
          step.complete(stepResult);
          Logger.info('DeepThinkingService', `步骤 ${i + 1} 完成: ${step.title}`);
          
          // 触发步骤完成回调
          callbacks?.onStepComplete?.(step);
          
        } catch (error) {
          const errorMessage = (error as Error).message;
          Logger.error('DeepThinkingService', `步骤 ${i + 1} 执行失败: ${errorMessage}`);
          
          step.fail(errorMessage);
          callbacks?.onStepError?.(step, errorMessage);
          
          // 根据配置决定是否降级
          if (this.config.fallbackEnabled && i >= 1) {
            Logger.warn('DeepThinkingService', '启用降级模式，使用部分结果');
            fallbackUsed = true;
            break;
          } else {
            throw error as Error;
          }
        }
      }
      
      // 生成最终答案
      const finalAnswer = this.generateFinalAnswer(steps, fallbackUsed);
      const totalTime = Date.now() - startTime;
      
      const result: DeepThinkingResult = {
        success: true,
        finalAnswer,
        steps,
        totalTime,
        fallbackUsed
      };
      
      Logger.info('DeepThinkingService', `深度思考完成，总耗时: ${totalTime}ms，降级: ${fallbackUsed}`);
      callbacks?.onComplete?.(result);
      
      return result;
      
    } catch (error) {
      const errorMessage = (error as Error).message;
      Logger.error('DeepThinkingService', `深度思考失败: ${errorMessage}`);
      
      const totalTime = Date.now() - startTime;
      const result: DeepThinkingResult = {
        success: false,
        finalAnswer: '',
        steps,
        totalTime,
        fallbackUsed,
        error: errorMessage
      };
      
      callbacks?.onError?.(errorMessage);
      return result;
      
    } finally {
      this.isProcessing = false;
      this.currentProcessId = null;
      this.cancellationToken = false;
    }
  }

  /**
   * 取消当前的深度思考过程
   */
  cancel(): boolean {
    if (!this.isProcessing) {
      return false;
    }
    
    Logger.info('DeepThinkingService', '正在取消深度思考过程');
    this.cancellationToken = true;
    return true;
  }

  /**
   * 检查是否正在处理
   */
  isRunning(): boolean {
    return this.isProcessing;
  }

  /**
   * 获取当前处理ID
   */
  getCurrentProcessId(): string | null {
    return this.currentProcessId;
  }

  /**
   * 构建步骤特定的提示词（优化版 - 使用内容压缩）
   */
  private buildStepPrompt(stepDef: StepDefinition, question: string, steps: ThinkingStep[], currentIndex: number): string {
    let prompt = stepDef.prompt;
    
    // 使用简化的问题引用
    const shortQuestion = this.compressQuestion(question);
    prompt = prompt.replace(/{question}/g, shortQuestion);
    
    // 使用压缩后的前面步骤结果
    if (currentIndex > 0) {
      const completedSteps: CompletedStep[] = [];
      
      // 收集已完成的步骤
      if (steps[0] && steps[0].status === StepStatus.COMPLETED) {
        const step: CompletedStep = {content: steps[0].content, type: 'analyze'};
        completedSteps.push(step);
      }
      if (steps[1] && steps[1].status === StepStatus.COMPLETED) {
        const step: CompletedStep = {content: steps[1].content, type: 'think'};
        completedSteps.push(step);
      }
      if (steps[2] && steps[2].status === StepStatus.COMPLETED) {
        const step: CompletedStep = {content: steps[2].content, type: 'verify'};
        completedSteps.push(step);
      }
      
      // 根据当前步骤替换相应的占位符
      switch (currentIndex) {
        case 1: // 多角度思考步骤
          if (completedSteps.length >= 1) {
            const compressed = this.contentCompressor.compressStepContent(completedSteps[0].content, 'analyze');
            const compressedText = this.contentCompressor.buildCompressedPrompt(compressed, 'analyze');
            prompt = prompt.replace(/{previousStep}/g, compressedText);
          }
          break;
          
        case 2: // 批判性验证步骤
          if (completedSteps.length >= 1) {
            const compressed1 = this.contentCompressor.compressStepContent(completedSteps[0].content, 'analyze');
            const compressedText1 = this.contentCompressor.buildCompressedPrompt(compressed1, 'analyze');
            prompt = prompt.replace(/{step1}/g, compressedText1);
          }
          if (completedSteps.length >= 2) {
            const compressed2 = this.contentCompressor.compressStepContent(completedSteps[1].content, 'think');
            const compressedText2 = this.contentCompressor.buildCompressedPrompt(compressed2, 'think');
            prompt = prompt.replace(/{step2}/g, compressedText2);
          }
          break;
          
        case 3: // 综合整合步骤
          if (completedSteps.length >= 1) {
            const compressed1 = this.contentCompressor.compressStepContent(completedSteps[0].content, 'analyze');
            const compressedText1 = this.contentCompressor.buildCompressedPrompt(compressed1, 'analyze');
            prompt = prompt.replace(/{step1}/g, compressedText1);
          }
          if (completedSteps.length >= 2) {
            const compressed2 = this.contentCompressor.compressStepContent(completedSteps[1].content, 'think');
            const compressedText2 = this.contentCompressor.buildCompressedPrompt(compressed2, 'think');
            prompt = prompt.replace(/{step2}/g, compressedText2);
          }
          if (completedSteps.length >= 3) {
            const compressed3 = this.contentCompressor.compressStepContent(completedSteps[2].content, 'verify');
            const compressedText3 = this.contentCompressor.buildCompressedPrompt(compressed3, 'verify');
            prompt = prompt.replace(/{step3}/g, compressedText3);
          }
          break;
      }
    }
    
    Logger.debug('DeepThinkingService', `构建步骤${currentIndex + 1}提示词，长度: ${prompt.length}`);
    return prompt;
  }

  /**
   * 压缩问题描述
   */
  private compressQuestion(question: string): string {
    // 如果问题较短，直接返回
    if (question.length <= 100) {
      return question;
    }
    
    // 如果问题较长，提取核心部分
    const sentences = question.split(/[。！？]/).filter(s => s.trim().length > 0);
    if (sentences.length > 1) {
      // 取前两句或前100字符
      const firstTwoSentences = sentences.slice(0, 2).join('。');
      return firstTwoSentences.length <= 150 ? firstTwoSentences + '。' : firstTwoSentences.substring(0, 100) + '...';
    }
    
    // 单句情况下截断
    return question.substring(0, 100) + '...';
  }

  /**
   * 执行单个步骤
   */
  private async executeStep(prompt: string, model: string): Promise<string> {
    const messages: APIChatMessage[] = [
      {
        role: 'user',
        content: prompt
      }
    ];

    const apiRequest: APIChatRequest = {
      model,
      messages,
      max_tokens: this.config.maxTokens,
      temperature: this.config.temperature,
      timeout: this.config.timeoutMs
    };

    Logger.debug('DeepThinkingService', `执行API调用，模型: ${model}`);
    
    const response = await this.apiManager.sendChatRequest(apiRequest);
    
    if (!response.choices || response.choices.length === 0) {
      throw new Error('API返回空响应');
    }

    const content = response.choices[0].message.content;
    if (!content || content.trim().length === 0) {
      throw new Error('API返回空内容');
    }

    return content.trim();
  }

  /**
   * 生成最终答案
   */
  private generateFinalAnswer(steps: ThinkingStep[], fallbackUsed: boolean): string {
    const completedSteps = steps.filter(step => step.status === StepStatus.COMPLETED);
    
    if (completedSteps.length === 0) {
      return '深度思考过程未能完成，无法提供答案。';
    }
    
    // 如果有完整的4步，使用最后一步作为最终答案
    if (completedSteps.length === 4 && !fallbackUsed) {
      return completedSteps[3].content;
    }
    
    // 降级模式：基于完成的步骤生成答案
    let finalAnswer = '基于已完成的分析步骤，以下是综合性回答：\n\n';
    
    for (let i = 0; i < completedSteps.length; i++) {
      const step = completedSteps[i];
      finalAnswer += `## ${step.title}\n${step.content}\n\n`;
    }
    
    if (fallbackUsed) {
      finalAnswer += '> **注意**: 由于部分推理步骤未能完成，以上为基于已完成步骤的降级回答。';
    }
    
    return finalAnswer;
  }

  /**
   * 生成处理ID
   */
  private generateProcessId(): string {
    return 'thinking_' + Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  }

  /**
   * 更新配置
   */
  updateConfig(newConfig: Partial<DeepThinkingConfig>): void {
    this.config.maxRetries = newConfig.maxRetries ?? this.config.maxRetries;
    this.config.timeoutMs = newConfig.timeoutMs ?? this.config.timeoutMs;
    this.config.fallbackEnabled = newConfig.fallbackEnabled ?? this.config.fallbackEnabled;
    this.config.temperature = newConfig.temperature ?? this.config.temperature;
    this.config.maxTokens = newConfig.maxTokens ?? this.config.maxTokens;
    Logger.info('DeepThinkingService', '配置已更新');
  }

  /**
   * 获取配置
   */
  getConfig(): DeepThinkingConfig {
    return {
      maxRetries: this.config.maxRetries,
      timeoutMs: this.config.timeoutMs,
      fallbackEnabled: this.config.fallbackEnabled,
      temperature: this.config.temperature,
      maxTokens: this.config.maxTokens
    };
  }

  /**
   * 销毁服务
   */
  destroy(): void {
    this.cancel();
    Logger.info('DeepThinkingService', '服务已销毁');
  }
}