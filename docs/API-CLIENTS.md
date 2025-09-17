# Javis API Clients Documentation

## Overview

Javis provides a comprehensive client architecture for interacting with multiple AI model providers. This document details the implementation patterns, usage examples, and extension guidelines for all API clients.

## Client Architecture

### Base Architecture

```
BaseAPIClient (Abstract)
├── SiliconFlowClient
├── GeminiClient
└── GLMClient
```

All clients inherit from `BaseAPIClient` and implement a unified interface for:
- Authentication
- Request/Response handling
- Error management
- Rate limiting
- Streaming support

## BaseAPIClient

### Overview

`BaseAPIClient` provides the foundation for all AI model interactions with common functionality including HTTP client management, authentication, and error handling.

### Class Definition

```typescript
/**
 * Base API client for AI model interactions
 * Provides common functionality for HTTP requests, authentication, and error handling
 */
export abstract class BaseAPIClient {
  protected baseUrl: string;
  protected apiKey: string;
  protected httpClient: http.HttpClient;
  protected rateLimiter: RateLimiter;
  protected timeout: number;

  constructor(config: BaseClientConfig) {
    // Implementation
  }

  /**
   * Send HTTP request with authentication and error handling
   */
  protected async sendRequest<T>(
    endpoint: string,
    options: HttpRequestOptions
  ): Promise<ApiResponse<T>> {
    // Implementation
  }

  /**
   * Handle streaming responses
   */
  protected async sendStreamRequest(
    endpoint: string,
    options: HttpRequestOptions,
    onChunk: (chunk: string) => void
  ): Promise<void> {
    // Implementation
  }

  /**
   * Abstract method for chat completion
   */
  abstract chatCompletion(
    request: ChatCompletionRequest
  ): Promise<ChatCompletionResponse>;

  /**
   * Abstract method for streaming chat
   */
  abstract streamChatCompletion(
    request: ChatCompletionRequest,
    onChunk: (chunk: string) => void
  ): Promise<void>;
}
```

### Configuration

```typescript
interface BaseClientConfig {
  baseUrl: string;
  apiKey: string;
  timeout?: number;
  maxRetries?: number;
  enableRateLimit?: boolean;
  headers?: Record<string, string>;
}
```

### Usage Example

```typescript
// Custom client implementation
class CustomAIClient extends BaseAPIClient {
  async chatCompletion(request: ChatCompletionRequest): Promise<ChatCompletionResponse> {
    const response = await this.sendRequest('/chat', {
      method: 'POST',
      body: JSON.stringify(request)
    });

    return this.parseResponse(response);
  }
}
```

---

## SiliconFlowClient

### Overview

`SiliconFlowClient` provides integration with SiliconFlow's API, supporting models like Qwen, DeepSeek, and Llama.

### Features

- Support for multiple AI models (Qwen, DeepSeek, Llama)
- Streaming responses
- Function calling
- Token usage tracking
- Rate limiting

### Class Definition

```typescript
/**
 * SiliconFlow API client for accessing Qwen, DeepSeek, and Llama models
 */
export class SiliconFlowClient extends BaseAPIClient {
  private supportedModels: Map<string, ModelInfo>;

  constructor(config: SiliconFlowConfig) {
    super({
      baseUrl: 'https://api.siliconflow.cn/v1',
      apiKey: config.apiKey,
      timeout: config.timeout || 30000
    });

    this.initializeSupportedModels();
  }

  /**
   * Get list of available models
   */
  async getModels(): Promise<ModelInfo[]> {
    const response = await this.sendRequest('/models', {
      method: 'GET'
    });
    return response.data;
  }

  /**
   * Send chat completion request
   */
  async chatCompletion(
    request: ChatCompletionRequest
  ): Promise<ChatCompletionResponse> {
    const siliconFlowRequest = this.transformRequest(request);

    const response = await this.sendRequest('/chat/completions', {
      method: 'POST',
      body: JSON.stringify(siliconFlowRequest)
    });

    return this.transformResponse(response);
  }

  /**
   * Stream chat completion
   */
  async streamChatCompletion(
    request: ChatCompletionRequest,
    onChunk: (chunk: string) => void
  ): Promise<void> {
    const siliconFlowRequest = this.transformRequest(request);

    await this.sendStreamRequest('/chat/completions', {
      method: 'POST',
      body: JSON.stringify(siliconFlowRequest),
      headers: { 'Accept': 'text/event-stream' }
    }, onChunk);
  }

  /**
   * Check if model supports function calling
   */
  supportsFunctionCalling(model: string): boolean {
    const modelInfo = this.supportedModels.get(model);
    return modelInfo?.supportsFunctions || false;
  }
}
```

### Configuration

```typescript
interface SiliconFlowConfig {
  apiKey: string;
  timeout?: number;
  defaultModel?: string;
  enableStreaming?: boolean;
  maxTokens?: number;
  temperature?: number;
}
```

### Usage Examples

#### Basic Chat Completion

```typescript
import { SiliconFlowClient } from './clients/SiliconFlowClient';

const client = new SiliconFlowClient({
  apiKey: 'your-siliconflow-api-key',
  defaultModel: 'Qwen/Qwen2.5-7B-Instruct',
  temperature: 0.7
});

const response = await client.chatCompletion({
  model: 'Qwen/Qwen2.5-7B-Instruct',
  messages: [
    { role: 'user', content: 'Write a Python function for fibonacci' }
  ],
  max_tokens: 1000
});

console.log(response.choices[0].message.content);
```

#### Streaming Chat

```typescript
let fullResponse = '';

await client.streamChatCompletion({
  model: 'Qwen/Qwen2.5-7B-Instruct',
  messages: [
    { role: 'user', content: 'Explain quantum computing' }
  ],
  stream: true
}, (chunk) => {
  fullResponse += chunk;
  console.log('Received chunk:', chunk);
});

console.log('Complete response:', fullResponse);
```

#### Function Calling

```typescript
const tools = [
  {
    type: 'function',
    function: {
      name: 'get_weather',
      description: 'Get weather information for a location',
      parameters: {
        type: 'object',
        properties: {
          location: { type: 'string', description: 'City name' },
          units: { type: 'string', enum: ['celsius', 'fahrenheit'] }
        },
        required: ['location']
      }
    }
  }
];

const response = await client.chatCompletion({
  model: 'Qwen/Qwen2.5-7B-Instruct',
  messages: [
    { role: 'user', content: 'What\'s the weather in Beijing?' }
  ],
  tools: tools,
  tool_choice: 'auto'
});

if (response.choices[0].message.tool_calls) {
  // Handle function calls
  const toolCall = response.choices[0].message.tool_calls[0];
  console.log('Function call:', toolCall.function);
}
```

---

## GeminiClient

### Overview

`GeminiClient` provides integration with Google's Gemini API, supporting Gemini Pro and Gemini Flash models with multimodal capabilities.

### Features

- Multimodal support (text, images, audio)
- Streaming responses
- Safety filtering
- Grounding in web search
- Context caching

### Class Definition

```typescript
/**
 * Google Gemini API client for accessing Gemini Pro and Flash models
 */
export class GeminiClient extends BaseAPIClient {
  private safetySettings: SafetySetting[];
  private generationConfig: GenerationConfig;

  constructor(config: GeminiConfig) {
    super({
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      apiKey: config.apiKey,
      timeout: config.timeout || 60000
    });

    this.safetySettings = config.safetySettings || this.getDefaultSafetySettings();
    this.generationConfig = config.generationConfig || this.getDefaultGenerationConfig();
  }

  /**
   * Generate content with text and/or images
   */
  async generateContent(
    request: GenerateContentRequest
  ): Promise<GenerateContentResponse> {
    const geminiRequest = this.transformGenerateRequest(request);

    const response = await this.sendRequest(
      `/models/${request.model}:generateContent`,
      {
        method: 'POST',
        body: JSON.stringify(geminiRequest)
      }
    );

    return this.transformGenerateResponse(response);
  }

  /**
   * Stream content generation
   */
  async streamGenerateContent(
    request: GenerateContentRequest,
    onChunk: (chunk: GenerateContentResponse) => void
  ): Promise<void> {
    const geminiRequest = this.transformGenerateRequest(request);

    await this.sendStreamRequest(
      `/models/${request.model}:streamGenerateContent`,
      {
        method: 'POST',
        body: JSON.stringify(geminiRequest)
      },
      onChunk
    );
  }

  /**
   * Chat completion (conversation mode)
   */
  async chatCompletion(
    request: ChatCompletionRequest
  ): Promise<ChatCompletionResponse> {
    const geminiChatRequest = this.transformChatRequest(request);

    const response = await this.sendRequest(
      `/models/${request.model}:generateContent`,
      {
        method: 'POST',
        body: JSON.stringify(geminiChatRequest)
      }
    );

    return this.transformChatResponse(response);
  }
}
```

### Configuration

```typescript
interface GeminiConfig {
  apiKey: string;
  safetySettings?: SafetySetting[];
  generationConfig?: GenerationConfig;
  timeout?: number;
  enableSearch?: boolean;
}

interface SafetySetting {
  category: 'HARM_CATEGORY_HARASSMENT' | 'HARM_CATEGORY_HATE_SPEECH' |
           'HARM_CATEGORY_SEXUALLY_EXPLICIT' | 'HARM_CATEGORY_DANGEROUS_CONTENT';
  threshold: 'BLOCK_NONE' | 'BLOCK_LOW_AND_ABOVE' | 'BLOCK_MEDIUM_AND_ABOVE' | 'BLOCK_ONLY_HIGH';
}

interface GenerationConfig {
  temperature?: number;
  topP?: number;
  topK?: number;
  maxOutputTokens?: number;
  stopSequences?: string[];
}
```

### Usage Examples

#### Text Generation

```typescript
import { GeminiClient } from './clients/GeminiClient';

const client = new GeminiClient({
  apiKey: 'your-gemini-api-key',
  generationConfig: {
    temperature: 0.7,
    maxOutputTokens: 1000
  }
});

const response = await client.generateContent({
  model: 'gemini-1.5-flash',
  contents: [
    {
      role: 'user',
      parts: [{ text: 'Write a poem about artificial intelligence' }]
    }
  ]
});

console.log(response.candidates[0].content.parts[0].text);
```

#### Multimodal Generation

```typescript
const response = await client.generateContent({
  model: 'gemini-1.5-flash',
  contents: [
    {
      role: 'user',
      parts: [
        { text: 'Describe this image' },
        {
          inline_data: {
            mime_type: 'image/jpeg',
            data: 'base64-encoded-image-data'
          }
        }
      ]
    }
  ]
});
```

#### Chat Conversation

```typescript
const chatHistory = [
  {
    role: 'user',
    parts: [{ text: 'Hello, my name is Alex' }]
  },
  {
    role: 'model',
    parts: [{ text: 'Hello Alex! How can I help you today?' }]
  }
];

const response = await client.chatCompletion({
  model: 'gemini-1.5-flash',
  messages: [
    { role: 'user', content: 'What\'s my name?' }
  ],
  context: chatHistory
});
```

---

## GLMClient

### Overview

`GLMClient` provides integration with Zhipu AI's GLM models, including GLM-4 and GLM-4V with vision capabilities.

### Features

- Vision model support (GLM-4V)
- Tool use and function calling
- Streaming responses
- Long context support
- Knowledge grounding

### Class Definition

```typescript
/**
 * Zhipu GLM API client for accessing GLM-4 and GLM-4V models
 */
export class GLMClient extends BaseAPIClient {
  private toolsRegistry: Map<string, ToolDefinition>;
  private knowledgeBase?: KnowledgeBaseConfig;

  constructor(config: GLMConfig) {
    super({
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      apiKey: config.apiKey,
      timeout: config.timeout || 30000
    });

    this.toolsRegistry = new Map();
    this.knowledgeBase = config.knowledgeBase;

    if (config.tools) {
      this.registerTools(config.tools);
    }
  }

  /**
   * Chat completion with tool support
   */
  async chatCompletion(
    request: ChatCompletionRequest
  ): Promise<ChatCompletionResponse> {
    const glmRequest = this.transformRequest(request);

    const response = await this.sendRequest('/chat/completions', {
      method: 'POST',
      body: JSON.stringify(glmRequest)
    });

    return this.transformResponse(response);
  }

  /**
   * Vision model content generation
   */
  async generateVisionContent(
    request: VisionContentRequest
  ): Promise<VisionContentResponse> {
    const glmRequest = this.transformVisionRequest(request);

    const response = await this.sendRequest('/vision/generations', {
      method: 'POST',
      body: JSON.stringify(glmRequest)
    });

    return this.transformVisionResponse(response);
  }

  /**
   * Register custom tools
   */
  registerTools(tools: ToolDefinition[]): void {
    tools.forEach(tool => {
      this.toolsRegistry.set(tool.name, tool);
    });
  }

  /**
   * Execute tool calls
   */
  async executeToolCalls(toolCalls: ToolCall[]): Promise<ToolResult[]> {
    const results: ToolResult[] = [];

    for (const toolCall of toolCalls) {
      const tool = this.toolsRegistry.get(toolCall.function.name);
      if (tool) {
        try {
          const result = await tool.execute(toolCall.function.arguments);
          results.push({
            tool_call_id: toolCall.id,
            result: result
          });
        } catch (error) {
          results.push({
            tool_call_id: toolCall.id,
            error: error.message
          });
        }
      }
    }

    return results;
  }
}
```

### Configuration

```typescript
interface GLMConfig {
  apiKey: string;
  timeout?: number;
  tools?: ToolDefinition[];
  knowledgeBase?: KnowledgeBaseConfig;
  enableVision?: boolean;
  maxTokens?: number;
}

interface ToolDefinition {
  name: string;
  description: string;
  parameters: ToolParameters;
  execute: (arguments: any) => Promise<any>;
}

interface KnowledgeBaseConfig {
  enabled: boolean;
  dataSource: string;
  searchMethod: 'vector' | 'keyword' | 'hybrid';
  topK?: number;
  scoreThreshold?: number;
}
```

### Usage Examples

#### Basic Chat

```typescript
import { GLMClient } from './clients/GLMClient';

const client = new GLMClient({
  apiKey: 'your-glm-api-key',
  maxTokens: 2000
});

const response = await client.chatCompletion({
  model: 'glm-4',
  messages: [
    { role: 'user', content: 'Explain machine learning basics' }
  ]
});

console.log(response.choices[0].message.content);
```

#### Tool Usage

```typescript
const calculatorTool = {
  name: 'calculator',
  description: 'Perform mathematical calculations',
  parameters: {
    type: 'object',
    properties: {
      expression: { type: 'string', description: 'Mathematical expression to evaluate' }
    },
    required: ['expression']
  },
  execute: async (args: { expression: string }) => {
    // Safe evaluation of mathematical expressions
    return eval(args.expression);
  }
};

const client = new GLMClient({
  apiKey: 'your-glm-api-key',
  tools: [calculatorTool]
});

const response = await client.chatCompletion({
  model: 'glm-4',
  messages: [
    { role: 'user', content: 'What is 15 * 23 + 47?' }
  ],
  tools: true
});
```

#### Vision Processing

```typescript
const visionResponse = await client.generateVisionContent({
  model: 'glm-4v',
  prompt: 'Analyze this chart and describe the key trends',
  image: {
    url: 'https://example.com/chart.png',
    mimeType: 'image/png'
  }
});

console.log(visionResponse.description);
```

---

## Error Handling Patterns

### Common Error Types

```typescript
enum ClientErrorType {
  AUTHENTICATION_ERROR = 'authentication_error',
  RATE_LIMIT_ERROR = 'rate_limit_error',
  NETWORK_ERROR = 'network_error',
  INVALID_REQUEST = 'invalid_request',
  MODEL_ERROR = 'model_error',
  TIMEOUT_ERROR = 'timeout_error'
}

interface ClientError {
  type: ClientErrorType;
  message: string;
  code: number;
  details?: any;
  retryable: boolean;
}
```

### Error Handling Strategy

```typescript
class ClientErrorHandler {
  static handle(error: ClientError): void {
    switch (error.type) {
      case ClientErrorType.RATE_LIMIT_ERROR:
        // Implement exponential backoff
        break;
      case ClientErrorType.NETWORK_ERROR:
        // Retry with jitter
        break;
      case ClientErrorType.AUTHENTICATION_ERROR:
        // Refresh API key or re-authenticate
        break;
      default:
        // Log and handle appropriately
        break;
    }
  }
}
```

### Retry Logic Implementation

```typescript
class RetryHandler {
  static async withRetry<T>(
    operation: () => Promise<T>,
    maxRetries: number = 3,
    baseDelay: number = 1000
  ): Promise<T> {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        if (attempt === maxRetries - 1 || !this.isRetryable(error)) {
          throw error;
        }

        const delay = baseDelay * Math.pow(2, attempt) + Math.random() * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
    throw new Error('Max retries exceeded');
  }

  private static isRetryable(error: ClientError): boolean {
    return error.retryable;
  }
}
```

---

## Rate Limiting

### Token Bucket Implementation

```typescript
class RateLimiter {
  private tokens: number;
  private maxTokens: number;
  private refillRate: number;
  private lastRefill: number;

  constructor(maxTokens: number, refillRate: number) {
    this.maxTokens = maxTokens;
    this.tokens = maxTokens;
    this.refillRate = refillRate;
    this.lastRefill = Date.now();
  }

  async acquire(tokens: number = 1): Promise<void> {
    this.refill();

    if (this.tokens < tokens) {
      const waitTime = ((tokens - this.tokens) / this.refillRate) * 1000;
      await new Promise(resolve => setTimeout(resolve, waitTime));
      this.refill();
    }

    this.tokens -= tokens;
  }

  private refill(): void {
    const now = Date.now();
    const elapsed = (now - this.lastRefill) / 1000;
    const newTokens = elapsed * this.refillRate;

    this.tokens = Math.min(this.maxTokens, this.tokens + newTokens);
    this.lastRefill = now;
  }
}
```

### Usage in Clients

```typescript
class BaseAPIClient {
  protected rateLimiter: RateLimiter;

  constructor(config: BaseClientConfig) {
    this.rateLimiter = new RateLimiter(100, 10); // 100 tokens, 10 per second
  }

  protected async sendRequest<T>(endpoint: string, options: HttpRequestOptions): Promise<ApiResponse<T>> {
    await this.rateLimiter.acquire();

    // Make HTTP request
    return this.httpClient.request(endpoint, options);
  }
}
```

---

## Testing Client Implementations

### Unit Testing Structure

```typescript
// SiliconFlowClient.test.ets
import { SiliconFlowClient } from './SiliconFlowClient';
import { mockHttpService } from '../test/MockHttpService';

describe('SiliconFlowClient', () => {
  let client: SiliconFlowClient;
  let mockHttp: MockHttpService;

  beforeEach(() => {
    mockHttp = new MockHttpService();
    client = new SiliconFlowClient({
      apiKey: 'test-key',
      httpClient: mockHttp
    });
  });

  describe('chatCompletion', () => {
    it('should send correct request format', async () => {
      mockHttp.mockResponse({
        choices: [{ message: { content: 'Hello!' } }]
      });

      const request = {
        model: 'Qwen/Qwen2.5-7B-Instruct',
        messages: [{ role: 'user', content: 'Hello' }]
      };

      const response = await client.chatCompletion(request);

      expect(mockHttp.lastRequest).toEqual({
        url: '/chat/completions',
        method: 'POST',
        body: expect.objectContaining({
          model: 'Qwen/Qwen2.5-7B-Instruct',
          messages: [{ role: 'user', content: 'Hello' }]
        })
      });
    });

    it('should handle rate limiting errors', async () => {
      mockHttp.mockError({
        status: 429,
        message: 'Rate limit exceeded'
      });

      await expect(client.chatCompletion(request))
        .rejects.toThrow('Rate limit exceeded');
    });
  });
});
```

### Integration Testing

```typescript
// ClientIntegration.test.ets
describe('Client Integration', () => {
  it('should handle streaming responses correctly', async () => {
    const chunks = ['Hello', ' world', '!'];
    mockHttp.mockStream(chunks);

    let receivedChunks: string[] = [];
    await client.streamChatCompletion({
      model: 'test-model',
      messages: [{ role: 'user', content: 'Test' }]
    }, (chunk) => {
      receivedChunks.push(chunk);
    });

    expect(receivedChunks).toEqual(chunks);
  });
});
```

---

## Performance Optimization

### Connection Pooling

```typescript
class ConnectionPool {
  private connections: Map<string, HttpClient> = new Map();
  private maxConnections: number = 10;

  getConnection(baseUrl: string): HttpClient {
    if (!this.connections.has(baseUrl)) {
      if (this.connections.size >= this.maxConnections) {
        this.removeOldestConnection();
      }

      const connection = this.createConnection(baseUrl);
      this.connections.set(baseUrl, connection);
    }

    return this.connections.get(baseUrl)!;
  }

  private createConnection(baseUrl: string): HttpClient {
    return http.createHttp({
      baseUrl: baseUrl,
      keepAlive: true,
      timeout: 30000
    });
  }
}
```

### Request Batching

```typescript
class RequestBatcher {
  private queue: Array<{ request: any; resolve: Function; reject: Function }> = [];
  private batchTimer: NodeJS.Timeout | null = null;
  private batchSize: number = 10;
  private batchDelay: number = 100;

  async add(request: any): Promise<any> {
    return new Promise((resolve, reject) => {
      this.queue.push({ request, resolve, reject });

      if (this.queue.length >= this.batchSize) {
        this.processBatch();
      } else if (!this.batchTimer) {
        this.batchTimer = setTimeout(() => this.processBatch(), this.batchDelay);
      }
    });
  }

  private async processBatch(): Promise<void> {
    if (this.batchTimer) {
      clearTimeout(this.batchTimer);
      this.batchTimer = null;
    }

    const batch = this.queue.splice(0, this.batchSize);

    try {
      const responses = await this.sendBatch(batch.map(item => item.request));
      batch.forEach((item, index) => item.resolve(responses[index]));
    } catch (error) {
      batch.forEach(item => item.reject(error));
    }
  }
}
```

---

## Extension Guidelines

### Adding New Client

1. **Inherit from BaseAPIClient**
2. **Implement required abstract methods**
3. **Add configuration interface**
4. **Implement provider-specific transformations**
5. **Add comprehensive tests**
6. **Update client factory**

### Example Extension

```typescript
// NewProviderClient.ets
export class NewProviderClient extends BaseAPIClient {
  constructor(config: NewProviderConfig) {
    super({
      baseUrl: 'https://api.newprovider.com/v1',
      apiKey: config.apiKey,
      timeout: config.timeout || 30000
    });
  }

  async chatCompletion(request: ChatCompletionRequest): Promise<ChatCompletionResponse> {
    const newProviderRequest = this.transformToNewProviderFormat(request);

    const response = await this.sendRequest('/chat/completions', {
      method: 'POST',
      body: JSON.stringify(newProviderRequest)
    });

    return this.transformFromNewProviderFormat(response);
  }

  async streamChatCompletion(
    request: ChatCompletionRequest,
    onChunk: (chunk: string) => void
  ): Promise<void> {
    // Implement streaming logic
  }

  private transformToNewProviderFormat(request: ChatCompletionRequest): any {
    // Provider-specific transformation
    return {
      model: request.model,
      prompt: this.formatMessages(request.messages),
      max_tokens: request.max_tokens,
      temperature: request.temperature
    };
  }

  private transformFromNewProviderFormat(response: any): ChatCompletionResponse {
    // Transform response to standard format
    return {
      id: response.id,
      object: 'chat.completion',
      created: Date.now(),
      model: response.model,
      choices: [{
        index: 0,
        message: {
          role: 'assistant',
          content: response.text
        },
        finish_reason: response.stop_reason
      }],
      usage: response.usage
    };
  }
}
```

### Best Practices

1. **Consistent Error Handling**: Use the BaseAPIClient error handling patterns
2. **Rate Limiting**: Always implement rate limiting for provider APIs
3. **Timeouts**: Set reasonable timeouts for all requests
4. **Retry Logic**: Implement retry for transient failures
5. **Logging**: Add appropriate logging for debugging
6. **Testing**: Write comprehensive unit and integration tests
7. **Documentation**: Document all configuration options and usage patterns