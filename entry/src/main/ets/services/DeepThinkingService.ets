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
// 深度思考步骤定义
type StepCapability = 'web-search' | 'self-review';

interface StepDefinition {
  id: string;
  title: string;
  description: string;
  prompt: string;
  capability?: StepCapability[];
  optional?: boolean;
}

interface StepPlanContext {
  question: string;
  messages: SimpleMessage[];
  options: ResolvedDeepThinkingOptions;
}

export interface DeepThinkingOptions {
  enableWebSearch?: boolean;
  preferFastResponse?: boolean;
  maxSteps?: number;
}

interface ResolvedDeepThinkingOptions {
  enableWebSearch: boolean;
  preferFastResponse: boolean;
  maxSteps: number;
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
  private stepTemplates: Map<string, StepDefinition>;
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
    
    // 注册推理步骤模板，后续根据问题按需选择
    this.stepTemplates = new Map<string, StepDefinition>();
    this.stepTemplates.set('plan', {
      id: 'plan',
      title: '🗺️ 思路规划',
      description: '根据问题确定推理目标与关键切入点',
      prompt: '你是资深推理规划师。\n问题：{question}\n对话上下文：\n{context}\n\n请用不超过120字给出最重要的 2-3 个分析方向，使用编号列表。每个方向注明预期成果。',
      optional: true
    });
    this.stepTemplates.set('analyze', {
      id: 'analyze',
      title: '🔍 深度分析',
      description: '提炼问题核心、约束条件与影响因素',
      prompt: '作为高级分析师，请详细拆解：{question}\n\n上下文摘录：\n{context}\n\n请输出：\n1. 核心目标与成功判据\n2. 关键背景/约束（如时间、资源、对象）\n3. 需要澄清的隐含假设\n简明条理化表达，保持 150-250 字。'
    });
    this.stepTemplates.set('research', {
      id: 'research',
      title: '🌐 资料检索',
      description: '补充权威数据与外部事实，为后续推理提供证据',
      prompt: '请围绕：{question}\n结合已知分析：\n{analysis}\n\n检索并总结最相关的 2-3 条外部事实或数据点，说明来源类别（官方/行业/学术）及与问题的关联。若缺乏足够公开资料，请给出最值得查证的方向。输出控制在 180 字以内。',
      capability: ['web-search'],
      optional: true
    });
    this.stepTemplates.set('think', {
      id: 'think',
      title: '🧠 多路径推演',
      description: '从不同角度提出可行方案并比较利弊',
      prompt: '在分析与资料基础上，对 {question} 展开多路径思考。\n分析摘要：\n{analysis}\n补充资料：\n{research}\n\n请输出至少两种思路，每种包含：策略概要、优势、潜在风险或前提。条理清晰，建议使用表格或编号。'
    });
    this.stepTemplates.set('verify', {
      id: 'verify',
      title: '✅ 批判性验证',
      description: '识别推理中的薄弱环节与反例',
      prompt: '请充当苛刻的评审者，对已提出的方案展开反思。\n方案摘要：\n{think}\n\n请列出：\n1. 主要漏洞或反对观点\n2. 关键信息缺口\n3. 需要监控的风险信号\n每点说明严重性及缓解建议。'
    });
    this.stepTemplates.set('integrate', {
      id: 'integrate',
      title: '🎯 综合整合',
      description: '整合所有成果并给出行动化结论',
      prompt: '基于前序推理，为 {question} 输出结构化结论。内容需覆盖：\n- 总结性结论（<=80字）\n- 关键论据（引用分析/资料的要点）\n- 推荐行动步骤（最多3条）\n- 风险与对应监测指标\n\n可参考：\n分析：{analysis}\n思考：{think}\n验证：{verify}\n请使用 Markdown，包含小标题。'
    });
    this.stepTemplates.set('review', {
      id: 'review',
      title: '🔁 质量复盘',
      description: '审视综合答案并提出改进方向',
      prompt: '站在读者视角复查最终答案：\n结论摘要：\n{integrate}\n\n请评估：\n1. 结论是否直接回应问题\n2. 论据是否充分、有无缺口\n3. 还需补充的后续工作\n输出为简洁建议列表。',
      capability: ['self-review'],
      optional: true
    });
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
    callbacks?: DeepThinkingCallbacks,
    options?: DeepThinkingOptions
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
    const effectiveOptions = this.resolveOptions(options);
    const planContext: StepPlanContext = {
      question,
      messages,
      options: effectiveOptions
    };
    const plannedStepDefs = this.buildStepPlan(planContext);
    const totalSteps = plannedStepDefs.length;
    const conversationContext = this.buildConversationSynopsis(messages);
    
    try {
      Logger.info('DeepThinkingService', `开始深度思考过程: ${this.currentProcessId}`);
      Logger.info('DeepThinkingService', `问题: ${question.substring(0, 100)}...`);
      Logger.info('DeepThinkingService', `执行步骤规划: ${plannedStepDefs.map(step => step.id).join(' -> ')}`);
      
      // 初始化所有步骤
      for (const stepDef of plannedStepDefs) {
        const step = new ThinkingStep(stepDef.id, stepDef.title, stepDef.description);
        steps.push(step);
      }
      
      // 依次执行每个步骤
      for (let i = 0; i < plannedStepDefs.length; i++) {
        if (this.cancellationToken) {
          Logger.info('DeepThinkingService', '深度思考过程被取消');
          throw new Error('深度思考过程被用户取消');
        }
        
        const stepDef = plannedStepDefs[i];
        const step = steps[i];
        
        Logger.info('DeepThinkingService', `开始执行步骤 ${i + 1}/${totalSteps}: ${step.title}`);
        
        // 触发步骤开始回调
        callbacks?.onStepStart?.(step);
        callbacks?.onProgress?.(i + 1, totalSteps);
        
        try {
          step.start();
          
          // 构建步骤特定的提示词
          const stepPrompt = this.buildStepPrompt(
            stepDef,
            question,
            conversationContext,
            steps,
            i,
            effectiveOptions
          );
          
          // 执行API调用
          const stepResult = await this.executeStepWithRetry(
            stepPrompt,
            model,
            stepDef,
            effectiveOptions
          );
          
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
          if (stepDef.optional) {
            Logger.warn('DeepThinkingService', `可选步骤 ${stepDef.id} 失败，继续后续流程`);
            fallbackUsed = true;
            continue;
          }

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
   * 解析并补全执行选项
   */
  private resolveOptions(options?: DeepThinkingOptions): ResolvedDeepThinkingOptions {
    const resolved: ResolvedDeepThinkingOptions = {
      enableWebSearch: options?.enableWebSearch === true,
      preferFastResponse: options?.preferFastResponse === true,
      maxSteps: options?.maxSteps !== undefined ? options.maxSteps : 6
    };

    if (resolved.maxSteps < 2) {
      resolved.maxSteps = 2;
    }
    if (resolved.maxSteps > 8) {
      resolved.maxSteps = 8;
    }

    return resolved;
  }

  /**
   * 基于当前问题生成动态推理计划
   */
  private buildStepPlan(context: StepPlanContext): StepDefinition[] {
    const complexity = this.estimateComplexity(context.question, context.messages);
    Logger.info('DeepThinkingService', `推理复杂度估计: ${complexity}`);

    const plan: StepDefinition[] = [];
    const addStep = (id: string): void => {
      const template = this.stepTemplates.get(id);
      if (template) {
        plan.push(template);
      }
    };

    const allowResearch = context.options.enableWebSearch && this.stepTemplates.has('research');

    if (context.options.preferFastResponse && complexity < 45) {
      if (complexity >= 28) {
        addStep('plan');
      }
      addStep('analyze');
      if (allowResearch && complexity >= 30) {
        addStep('research');
      }
      addStep('integrate');
      return this.trimPlan(plan, context.options.maxSteps);
    }

    if (complexity >= 55) {
      addStep('plan');
    }

    addStep('analyze');

    if (allowResearch && complexity >= 40) {
      addStep('research');
    }

    if (complexity >= 30) {
      addStep('think');
    }

    if (complexity >= 45 && !context.options.preferFastResponse) {
      addStep('verify');
    }

    addStep('integrate');

    if (complexity >= 65 && !context.options.preferFastResponse) {
      addStep('review');
    }

    return this.trimPlan(plan, context.options.maxSteps);
  }

  /**
   * 限制推理计划步数，优先保留核心步骤
   */
  private trimPlan(plan: StepDefinition[], maxSteps: number): StepDefinition[] {
    if (plan.length <= maxSteps) {
      return plan;
    }

    const trimmed: StepDefinition[] = [...plan];

    for (let i = trimmed.length - 1; i >= 0 && trimmed.length > maxSteps; i--) {
      const step = trimmed[i];
      if (step.optional && step.id !== 'integrate') {
        trimmed.splice(i, 1);
      }
    }

    while (trimmed.length > maxSteps && trimmed.length > 2) {
      trimmed.splice(trimmed.length - 2, 1);
    }

    return trimmed.slice(0, Math.min(trimmed.length, maxSteps));
  }

  /**
   * 根据问题和历史消息估算复杂度
   */
  private estimateComplexity(question: string, messages: SimpleMessage[]): number {
    let score = Math.min(question.length / 5, 40);

    const complexityKeywords: string[] = ['为什么', '如何', '策略', '规划', '优化', '风险', '?', '分析', '架构'];
    for (const keyword of complexityKeywords) {
      if (question.includes(keyword)) {
        score += 6;
      }
    }

    if (messages.length > 6) {
      score += 8;
    }

    const avgMessageLength = messages.length > 0 ? messages.reduce((acc, msg) => acc + msg.content.length, 0) / messages.length : 0;
    if (avgMessageLength > 80) {
      score += 8;
    }

    if (score > 100) {
      return 100;
    }

    return Math.round(score);
  }

  /**
   * 构建精简的对话上下文
   */
  private buildConversationSynopsis(messages: SimpleMessage[]): string {
    if (!messages || messages.length === 0) {
      return '（无历史对话）';
    }

    const recent = messages.slice(-6);
    const lines: string[] = recent.map((msg, index) => {
      const role = msg.role === 'user' ? '用户' : (msg.role === 'assistant' ? '助手' : '系统');
      return `${role}${index + 1}: ${this.truncateForSynopsis(msg.content)}`;
    });

    return lines.join('\n');
  }

  private truncateForSynopsis(content: string): string {
    const trimmed = content.replace(/\s+/g, ' ').trim();
    if (trimmed.length <= 80) {
      return trimmed;
    }
    return trimmed.substring(0, 77) + '...';
  }

  /**
   * 获取前置步骤的压缩文本
   */
  private getCompressedStepText(steps: ThinkingStep[], stepId: string, stepType: string): string {
    const referenceStep = steps.find(step => step.id === stepId && step.status === StepStatus.COMPLETED && step.content);
    if (!referenceStep || !referenceStep.content) {
      return '（暂无内容）';
    }

    try {
      const structured = this.contentCompressor.compressStepContent(referenceStep.content, stepType);
      const compressed = this.contentCompressor.buildCompressedPrompt(structured, stepType);
      return compressed || referenceStep.content.substring(0, Math.min(referenceStep.content.length, 180));
    } catch (error) {
      Logger.warn('DeepThinkingService', `压缩步骤 ${stepId} 内容失败: ${(error as Error).message}`);
      const fallbackLength = Math.min(referenceStep.content.length, 180);
      return referenceStep.content.substring(0, fallbackLength);
    }
  }

  /**
   * 带重试的步骤执行
   */
  private async executeStepWithRetry(
    prompt: string,
    model: string,
    stepDef: StepDefinition,
    options: ResolvedDeepThinkingOptions
  ): Promise<string> {
    const attempts = Math.max(1, this.config.maxRetries + 1);
    let lastError: Error | null = null;

    for (let attempt = 0; attempt < attempts; attempt++) {
      if (this.cancellationToken) {
        throw new Error('深度思考过程被用户取消');
      }

      try {
        const useWeb = Boolean(stepDef.capability?.includes('web-search') && options.enableWebSearch);
        return await this.executeStep(prompt, model, useWeb);
      } catch (error) {
        lastError = error as Error;
        Logger.warn('DeepThinkingService', `步骤 ${stepDef.id} 第 ${attempt + 1} 次尝试失败: ${lastError.message}`);
        if (attempt < attempts - 1) {
          await this.delay(250 * (attempt + 1));
        }
      }
    }

    throw lastError ?? new Error('步骤执行失败');
  }

  private async delay(ms: number): Promise<void> {
    await new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  /**
   * 构建步骤特定的提示词（优化版 - 使用内容压缩）
   */
  private buildStepPrompt(
    stepDef: StepDefinition,
    question: string,
    conversationContext: string,
    steps: ThinkingStep[],
    currentIndex: number,
    options: ResolvedDeepThinkingOptions
  ): string {
    let prompt = stepDef.prompt;
    const shortQuestion = this.compressQuestion(question);
    prompt = prompt.replace(/{question}/g, shortQuestion);
    prompt = prompt.replace(/{context}/g, conversationContext || '无补充上下文');

    const analysisSummary = this.getCompressedStepText(steps, 'analyze', 'analyze');
    const researchSummary = this.getCompressedStepText(steps, 'research', 'research');
    const thinkSummary = this.getCompressedStepText(steps, 'think', 'think');
    const verifySummary = this.getCompressedStepText(steps, 'verify', 'verify');
    const integrateSummary = this.getCompressedStepText(steps, 'integrate', 'integrate');
    const planSummary = this.getCompressedStepText(steps, 'plan', 'plan');

    prompt = prompt.replace(/{analysis}/g, analysisSummary);
    prompt = prompt.replace(/{research}/g, researchSummary);
    prompt = prompt.replace(/{think}/g, thinkSummary);
    prompt = prompt.replace(/{verify}/g, verifySummary);
    prompt = prompt.replace(/{integrate}/g, integrateSummary);
    prompt = prompt.replace(/{plan}/g, planSummary);

    if (stepDef.id === 'plan') {
      prompt += '\n\n若缺少上下文，可根据问题常见分析框架自拟。';
    }

    if (stepDef.id === 'think' && analysisSummary === '（暂无内容）') {
      prompt += '\n\n若还没有正式分析，请快速总结问题核心后给出思路。';
    }

    if (options.preferFastResponse) {
      prompt += '\n\n请在保证逻辑的前提下尽量精炼（≈150字以内）。';
    }

    Logger.debug('DeepThinkingService', `构建步骤${currentIndex + 1} (${stepDef.id}) 提示词，长度: ${prompt.length}`);
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
  private async executeStep(prompt: string, model: string, useWebSearch: boolean): Promise<string> {
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
      timeout: this.config.timeoutMs,
      enable_web: useWebSearch
    };

    Logger.debug('DeepThinkingService', `执行API调用，模型: ${model}`);
    if (useWebSearch) {
      Logger.info('DeepThinkingService', '为当前步骤启用联网检索');
    }
    
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
    const completedSteps = steps.filter(step => step.status === StepStatus.COMPLETED && step.content);

    if (completedSteps.length === 0) {
      return '深度思考过程未能完成，无法提供答案。';
    }

    const integrateStep = completedSteps.find(step => step.id === 'integrate');
    let finalAnswer = integrateStep && integrateStep.content ? integrateStep.content : '';

    if (!finalAnswer) {
      finalAnswer = '基于已完成的分析步骤，以下是综合性回答：\n\n';
      for (const step of completedSteps) {
        finalAnswer += `## ${step.title}\n${step.content}\n\n`;
      }
    }

    const reviewStep = completedSteps.find(step => step.id === 'review');
    if (reviewStep && reviewStep.content) {
      finalAnswer += '\n---\n### 质量复盘\n' + reviewStep.content;
    }

    if (fallbackUsed) {
      finalAnswer += '\n> **注意**: 部分步骤未能顺利完成，本回答基于已完成内容生成。';
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
