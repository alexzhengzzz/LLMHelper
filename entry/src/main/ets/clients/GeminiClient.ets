/**
 * Google Gemini API客户端 - 已禁用
 * 支持Gemini Pro和Flash模型
 * 
 * 注意：此客户端已被禁用，暂不可用
 */

/*
import { BaseAPIClient } from './BaseAPIClient';
import { ChatRequest, ChatResponse, ChatChoice, ChatMessage, TokenUsage, AIProvider, APIConfig, RequestConfig, GeminiRequestBody, GeminiResponse, GeminiContent, GeminiGenerationConfig, GeminiSafetySetting, GeminiPart } from '../types/APITypes';
import { Logger } from '../utils/Logger';

export class GeminiClient extends BaseAPIClient { */
  private static readonly DEFAULT_MODEL = 'gemini-1.5-flash';
  private static readonly BASE_URL = 'https://generativelanguage.googleapis.com';
  private static readonly API_ENDPOINT_TEMPLATE = '/v1beta/models/{model}:generateContent';
  
  constructor(apiKey: string = '') {
    const config: APIConfig = {
      provider: AIProvider.GEMINI,
      model: GeminiClient.DEFAULT_MODEL,
      apiKey: apiKey, // 通过构造函数传入API密钥
      baseUrl: GeminiClient.BASE_URL
    };
    super(config);
  }
  
  async sendChatRequest(request: ChatRequest): Promise<ChatResponse> {
    try {
      Logger.info('GeminiClient', `=== 开始Google Gemini API请求 ===`);
      
      this.validateRequest(request);
      
      const requestBody = this.formatRequestBody(request);
      const headers = this.getHeaders();
      const model = request.model || this.config.model;
      const endpoint = GeminiClient.API_ENDPOINT_TEMPLATE.replace('{model}', model);
      
      Logger.info('GeminiClient', `API端点: ${this.config.baseUrl}${endpoint}?key=${this.config.apiKey?.substring(0, 10)}...`);
      const headersObj: Record<string, string> = {};
        headers.forEach((value: string, key: string) => {
          headersObj[key] = value;
        });
        Logger.info('GeminiClient', `请求头: ${JSON.stringify(headersObj)}`);
      Logger.info('GeminiClient', `请求体长度: ${requestBody.length}`);
      Logger.debug('GeminiClient', `完整请求体: ${requestBody}`);
      
      const requestConfig: RequestConfig = {
        url: `${this.config.baseUrl}${endpoint}?key=${this.config.apiKey}`,
        method: 'POST',
        headers: headers,
        body: requestBody,
        timeout: this.timeout
      };
      
      const startTime = Date.now();
      const responseData = await this.sendHttpRequest(requestConfig);
      const endTime = Date.now();
      
      Logger.info('GeminiClient', `HTTP请求完成，耗时: ${endTime - startTime}ms`);
      Logger.info('GeminiClient', `响应数据长度: ${responseData.length}`);
      Logger.debug('GeminiClient', `原始响应数据: ${responseData}`);
      
      const parsedResponse = this.parseResponse(responseData);
      
      Logger.info('GeminiClient', `=== Google Gemini API请求完成 ===`);
      Logger.info('GeminiClient', `响应ID: ${parsedResponse.id}`);
      Logger.info('GeminiClient', `使用的模型: ${parsedResponse.model}`);
      Logger.info('GeminiClient', `响应内容: ${parsedResponse.choices?.[0]?.message?.content?.substring(0, 100)}...`);
      
      return parsedResponse;
      
    } catch (error) {
      Logger.error('GeminiClient', `=== Google Gemini API请求失败 ===`);
      Logger.error('GeminiClient', `错误类型: ${error.constructor.name}`);
      Logger.error('GeminiClient', `错误信息: ${(error as Error).message}`);
      Logger.error('GeminiClient', `错误堆栈: ${(error as Error).stack}`);
      throw this.handleAPIError(error as Error, 'Gemini聊天请求');
    }
  }
  
  async testConnection(): Promise<boolean> {
    try {
      const testUrl = `${this.config.baseUrl}/v1beta/models?key=${this.config.apiKey}`;
      Logger.info('GeminiClient', `=== 开始Google Gemini连接测试 ===`);
      Logger.info('GeminiClient', `测试URL: ${testUrl}`);
      Logger.info('GeminiClient', `当前API密钥前缀: ${this.config.apiKey?.substring(0, 10)}...`);
      
      const result = await this.sendTestRequest(testUrl);
      
      Logger.info('GeminiClient', `=== Google Gemini连接测试完成 ===`);
      Logger.info('GeminiClient', `测试结果: ${result ? '成功' : '失败'}`);
      
      return result;
    } catch (error) {
      Logger.error('GeminiClient', `=== Google Gemini连接测试异常 ===`);
      Logger.error('GeminiClient', `异常信息: ${(error as Error).message}`);
      Logger.error('GeminiClient', `异常堆栈: ${(error as Error).stack}`);
      return false;
    }
  }
  
  protected getHeaders(): Map<string, string> {
    const headers = new Map<string, string>();
    headers.set('Content-Type', 'application/json');
    return headers;
  }
  
  protected formatRequestBody(request: ChatRequest): string {
    // Gemini使用不同的消息格式
    const contents = this.convertMessagesToGeminiFormat(request.messages);
    
    const generationConfig: GeminiGenerationConfig = {
      maxOutputTokens: request.max_tokens || 1000,
      temperature: request.temperature || 0.7,
      topK: 40,
      topP: 0.95
    };
    
    const safetySettings: GeminiSafetySetting[] = [
      {
        category: 'HARM_CATEGORY_HARASSMENT',
        threshold: 'BLOCK_MEDIUM_AND_ABOVE'
      },
      {
        category: 'HARM_CATEGORY_HATE_SPEECH',
        threshold: 'BLOCK_MEDIUM_AND_ABOVE'
      },
      {
        category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
        threshold: 'BLOCK_MEDIUM_AND_ABOVE'
      },
      {
        category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
        threshold: 'BLOCK_MEDIUM_AND_ABOVE'
      }
    ];
    
    const geminiRequest: GeminiRequestBody = {
      contents: contents,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    };
    
    return JSON.stringify(geminiRequest);
  }
  
  protected parseResponse(responseData: string): ChatResponse {
    try {
      Logger.info('GeminiClient', `=== 开始解析Google Gemini响应 ===`);
      Logger.debug('GeminiClient', `原始响应数据: ${responseData}`);
      
      const jsonResponse = JSON.parse(responseData) as GeminiResponse;
      
      Logger.info('GeminiClient', `JSON解析成功`);
      Logger.info('GeminiClient', `候选响应数量: ${jsonResponse.candidates?.length || 0}`);
      Logger.info('GeminiClient', `使用元数据: ${JSON.stringify(jsonResponse.usageMetadata)}`);
      
      if (jsonResponse.error) {
        Logger.error('GeminiClient', `Google Gemini API返回错误: ${JSON.stringify(jsonResponse.error)}`);
        throw new Error(`Gemini API错误: ${jsonResponse.error.message}`);
      }
      
      if (!jsonResponse.candidates || jsonResponse.candidates.length === 0) {
        Logger.error('GeminiClient', `Google Gemini返回了空的候选响应`);
        throw new Error('Gemini返回了空的候选响应');
      }
      
      // 转换为标准格式
      const choices: ChatChoice[] = jsonResponse.candidates.map((candidate, index) => {
        const content = candidate.content.parts[0]?.text || '';
        const message: ChatMessage = {
          role: 'assistant',
          content: content
        };
        const choice: ChatChoice = {
          index: index,
          message: message,
          finish_reason: this.mapFinishReason(candidate.finishReason)
        };
        Logger.debug('GeminiClient', `转换候选响应 ${index}: ${content.substring(0, 50)}...`);
        return choice;
      });
      
      const usage: TokenUsage = {
        prompt_tokens: jsonResponse.usageMetadata?.promptTokenCount || 0,
        completion_tokens: jsonResponse.usageMetadata?.candidatesTokenCount || 0,
        total_tokens: jsonResponse.usageMetadata?.totalTokenCount || 0
      };
      
      Logger.info('GeminiClient', `令牌使用情况 - 输入: ${usage.prompt_tokens}, 输出: ${usage.completion_tokens}, 总计: ${usage.total_tokens}`);
      
      const parsedResponse: ChatResponse = {
        id: this.generateId(),
        object: 'chat.completion',
        created: Math.floor(Date.now() / 1000),
        model: this.config.model,
        choices: choices,
        usage: usage
      };
      
      Logger.info('GeminiClient', `=== Google Gemini响应解析完成 ===`);
      return parsedResponse;
      
    } catch (error) {
      Logger.error('GeminiClient', `=== Google Gemini响应解析失败 ===`);
      Logger.error('GeminiClient', `错误信息: ${(error as Error).message}`);
      Logger.error('GeminiClient', `错误堆栈: ${(error as Error).stack}`);
      Logger.error('GeminiClient', `原始响应数据: ${responseData}`);
      throw new Error(`解析Gemini响应失败: ${(error as Error).message}`);
    }
  }
  
  /**
   * 将标准消息格式转换为Gemini格式
   */
  private convertMessagesToGeminiFormat(messages: ChatMessage[]): GeminiContent[] {
    const contents: GeminiContent[] = [];
    
    for (const message of messages) {
      const role = message.role === 'assistant' ? 'model' : 'user';
      const part: GeminiPart = { text: message.content };
      const content: GeminiContent = {
        role: role,
        parts: [part]
      };
      contents.push(content);
    }
    
    return contents;
  }
  
  /**
   * 映射结束原因
   */
  private mapFinishReason(geminiReason?: string): string {
    const reasonMap = new Map<string, string>();
    reasonMap.set('STOP', 'stop');
    reasonMap.set('MAX_TOKENS', 'length');
    reasonMap.set('SAFETY', 'content_filter');
    reasonMap.set('RECITATION', 'content_filter');
    reasonMap.set('OTHER', 'stop');
    
    return reasonMap.get(geminiReason || '') || 'stop';
  }
  
  /**
   * 生成唯一ID
   */
  private generateId(): string {
    return 'chatcmpl-' + Date.now().toString();
  }
  
  /**
   * 获取支持的模型列表
   */
  getSupportedModels(): string[] {
    return [
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-1.0-pro',
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-2.0-flash-exp',
      'gemini-2.0-flash-thinking-exp',
      'gemini-2.0-pro-exp'
    ];
  }
  
  /**
   * 设置API密钥
   */
  setApiKey(apiKey: string): void {
    this.config.apiKey = apiKey;
  }
  
  /**
   * 获取厂商名称
   */
  getProviderName(): string {
    return 'Google Gemini';
  }
} */