# Javis Service Layer Documentation

## Overview

The Javis service layer implements the business logic and coordination between UI components and data sources. This document provides detailed documentation of all services, their architecture, usage patterns, and integration guidelines.

## Service Layer Architecture

### Service Categories

```
Services Layer
├── Core Services (Foundation)
│   ├── APIManager.ets
│   ├── WebSocketService.ets
│   └── DirectAPIService.ets
├── AI Services (Intelligence)
│   ├── DeepThinkingService.ets
│   ├── HybridChatService.ets
│   ├── MessageEnhancer.ets
│   └── SearchDecisionEngine.ets
├── Voice Services (Interaction)
│   ├── SpeechRecognitionService.ets
│   ├── TTSService.ets
│   ├── AutoTTSService.ets
│   └── AudioCapturer.ets
├── Utility Services (Support)
│   ├── SessionManager.ets
│   ├── ThemeManager.ets
│   └── SystemPromptManager.ets
└── Network Services (Communication)
    ├── ApiService.ets
    └── APIKeyManager.ets
```

### Service Design Patterns

1. **Singleton Pattern**: Most services are singletons for state consistency
2. **Observer Pattern**: Services emit events for state changes
3. **Strategy Pattern**: Different algorithms for the same operation
4. **Factory Pattern**: Service instantiation and dependency injection
5. **Command Pattern**: Encapsulating requests as objects

## Core Services

### APIManager

#### Overview

`APIManager` is the central orchestrator for all API communications, managing multiple AI model providers and implementing intelligent routing, load balancing, and fallback mechanisms.

#### Architecture

```typescript
/**
 * Central API management service for multi-provider AI model interactions
 * Implements intelligent routing, load balancing, and fallback mechanisms
 */
export class APIManager {
  private static instance: APIManager;
  private clients: Map<string, BaseAPIClient> = new Map();
  private loadBalancer: LoadBalancer;
  private circuitBreaker: CircuitBreaker;
  private metricsCollector: MetricsCollector;

  private constructor() {
    this.initializeClients();
    this.initializeLoadBalancer();
    this.initializeCircuitBreaker();
    this.initializeMetrics();
  }

  /**
   * Get singleton instance of APIManager
   */
  static getInstance(): APIManager {
    if (!APIManager.instance) {
      APIManager.instance = new APIManager();
    }
    return APIManager.instance;
  }

  /**
   * Send chat request with intelligent routing
   */
  async sendChatRequest(request: ChatRequest): Promise<ChatResponse> {
    const provider = this.selectProvider(request);
    const client = this.clients.get(provider);

    if (!client) {
      throw new Error(`Provider ${provider} not available`);
    }

    return this.circuitBreaker.execute(() =>
      client.chatCompletion(request)
    );
  }

  /**
   * Send streaming chat request
   */
  async sendStreamingChatRequest(
    request: ChatRequest,
    onChunk: (chunk: string) => void
  ): Promise<void> {
    const provider = this.selectProvider(request);
    const client = this.clients.get(provider);

    if (!client) {
      throw new Error(`Provider ${provider} not available`);
    }

    await client.streamChatCompletion(request, onChunk);
  }

  /**
   * Intelligent provider selection based on request characteristics
   */
  private selectProvider(request: ChatRequest): string {
    const factors = {
      modelCapability: this.assessModelCapability(request),
      performance: this.assessProviderPerformance(),
      cost: this.assessProviderCost(request),
      availability: this.assessProviderAvailability()
    };

    return this.loadBalancer.selectProvider(factors);
  }
}
```

#### Key Features

- **Multi-Provider Support**: Seamless integration with SiliconFlow, Gemini, and GLM
- **Intelligent Routing**: Smart provider selection based on request characteristics
- **Load Balancing**: Distributes requests across available providers
- **Circuit Breaker**: Prevents cascading failures
- **Metrics Collection**: Tracks performance and usage statistics
- **Fallback Mechanisms**: Automatic failover to backup providers

#### Usage Example

```typescript
// Get APIManager instance
const apiManager = APIManager.getInstance();

// Send chat request
const response = await apiManager.sendChatRequest({
  model: 'siliconflow.Qwen/Qwen2.5-7B-Instruct',
  messages: [
    { role: 'user', content: 'Write a Python function for fibonacci' }
  ],
  temperature: 0.7
});

// Send streaming request
await apiManager.sendStreamingChatRequest({
  model: 'gemini.gemini-1.5-flash',
  messages: [
    { role: 'user', content: 'Explain quantum computing' }
  ]
}, (chunk) => {
  console.log('Received:', chunk);
});
```

#### Configuration

```typescript
interface APIManagerConfig {
  defaultProvider: string;
  fallbackProviders: string[];
  loadBalancingStrategy: 'round-robin' | 'weighted' | 'performance-based';
  circuitBreaker: {
    threshold: number;
    timeout: number;
    resetTimeout: number;
  };
  metrics: {
    enabled: boolean;
    samplingRate: number;
  };
}
```

### WebSocketService

#### Overview

`WebSocketService` manages real-time bidirectional communication with the backend server, enabling streaming responses and real-time updates.

#### Architecture

```typescript
/**
 * WebSocket service for real-time communication and streaming responses
 * Manages connection lifecycle, message handling, and error recovery
 */
export class WebSocketService {
  private static instance: WebSocketService;
  private ws: WebSocket | null = null;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;
  private reconnectDelay: number = 1000;
  private messageQueue: any[] = [];
  private eventEmitter: EventEmitter = new EventEmitter();

  private constructor() {
    this.initializeConnection();
    this.setupEventHandlers();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): WebSocketService {
    if (!WebSocketService.instance) {
      WebSocketService.instance = new WebSocketService();
    }
    return WebSocketService.instance;
  }

  /**
   * Connect to WebSocket server
   */
  async connect(): Promise<void> {
    try {
      this.ws = new WebSocket('ws://xx.xx.xx.xx:8080/ws');

      this.ws.onopen = () => {
        this.reconnectAttempts = 0;
        this.processMessageQueue();
        this.eventEmitter.emit('connected');
      };

      this.ws.onmessage = (event) => {
        this.handleMessage(event.data);
      };

      this.ws.onerror = (error) => {
        this.eventEmitter.emit('error', error);
      };

      this.ws.onclose = () => {
        this.eventEmitter.emit('disconnected');
        this.attemptReconnect();
      };

    } catch (error) {
      this.eventEmitter.emit('error', error);
      this.attemptReconnect();
    }
  }

  /**
   * Send message through WebSocket
   */
  sendMessage(message: any): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      this.messageQueue.push(message);
    }
  }

  /**
   * Handle incoming messages
   */
  private handleMessage(data: string): void {
    try {
      const message = JSON.parse(data);

      switch (message.type) {
        case 'chat_chunk':
          this.eventEmitter.emit('chat_chunk', message);
          break;
        case 'status':
          this.eventEmitter.emit('status', message);
          break;
        case 'error':
          this.eventEmitter.emit('error', message);
          break;
        default:
          this.eventEmitter.emit('message', message);
      }
    } catch (error) {
      Logger.error('Failed to parse WebSocket message:', error);
    }
  }

  /**
   * Attempt to reconnect with exponential backoff
   */
  private attemptReconnect(): void {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts);

      setTimeout(() => {
        this.reconnectAttempts++;
        this.connect();
      }, delay);
    } else {
      this.eventEmitter.emit('max_reconnect_attempts_reached');
    }
  }

  /**
   * Process queued messages after reconnection
   */
  private processMessageQueue(): void {
    while (this.messageQueue.length > 0) {
      const message = this.messageQueue.shift();
      this.sendMessage(message);
    }
  }

  /**
   * Add event listener
   */
  on(event: string, callback: Function): void {
    this.eventEmitter.on(event, callback);
  }

  /**
   * Remove event listener
   */
  off(event: string, callback: Function): void {
    this.eventEmitter.off(event, callback);
  }
}
```

#### Key Features

- **Connection Management**: Automatic connection and reconnection
- **Message Queue**: Persistent message delivery during disconnections
- **Event System**: Flexible event handling for different message types
- **Error Recovery**: Exponential backoff for reconnection attempts
- **Streaming Support**: Real-time response streaming

#### Usage Example

```typescript
// Get WebSocket service instance
const wsService = WebSocketService.getInstance();

// Connect to server
await wsService.connect();

// Add event listeners
wsService.on('connected', () => {
  console.log('WebSocket connected');
});

wsService.on('chat_chunk', (chunk) => {
  console.log('Received chat chunk:', chunk);
});

wsService.on('error', (error) => {
  console.error('WebSocket error:', error);
});

// Send message
wsService.sendMessage({
  type: 'chat',
  id: 'chat_123',
  model: 'siliconflow.Qwen/Qwen2.5-7B-Instruct',
  messages: [
    { role: 'user', content: 'Hello, how are you?' }
  ]
});
```

## AI Services

### DeepThinkingService

#### Overview

`DeepThinkingService` implements advanced AI reasoning capabilities, providing multi-step thinking processes, error recovery, and progress tracking for complex problem-solving.

#### Architecture

```typescript
/**
 * Advanced AI reasoning engine with multi-step thinking processes
 * Implements sophisticated reasoning patterns and error recovery mechanisms
 */
export class DeepThinkingService {
  private static instance: DeepThinkingService;
  private thinkingSteps: ThinkingStep[] = [];
  private currentStep: number = 0;
  private progressTracker: ProgressTracker;
  private errorRecovery: ErrorRecoveryManager;
  private reasoningEngine: ReasoningEngine;

  private constructor() {
    this.progressTracker = new ProgressTracker();
    this.errorRecovery = new ErrorRecoveryManager();
    this.reasoningEngine = new ReasoningEngine();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): DeepThinkingService {
    if (!DeepThinkingService.instance) {
      DeepThinkingService.instance = new DeepThinkingService();
    }
    return DeepThinkingService.instance;
  }

  /**
   * Process request with deep thinking
   */
  async processWithDeepThinking(
    request: ChatRequest,
    options: DeepThinkingOptions = {}
  ): Promise<ThinkingResponse> {
    const thinkingSession = this.createThinkingSession(request, options);

    try {
      // Step 1: Analyze and decompose the problem
      const analysis = await this.analyzeProblem(request, thinkingSession);

      // Step 2: Generate reasoning steps
      const reasoningSteps = await this.generateReasoningSteps(analysis, thinkingSession);

      // Step 3: Execute reasoning process
      const result = await this.executeReasoningProcess(reasoningSteps, thinkingSession);

      // Step 4: Synthesize final response
      const response = await this.synthesizeResponse(result, thinkingSession);

      return {
        success: true,
        response: response,
        thinkingProcess: thinkingSession.steps,
        metrics: thinkingSession.metrics,
        duration: thinkingSession.getDuration()
      };

    } catch (error) {
      return await this.errorRecovery.handleThinkingError(error, thinkingSession);
    }
  }

  /**
   * Analyze problem and identify key components
   */
  private async analyzeProblem(
    request: ChatRequest,
    session: ThinkingSession
  ): Promise<ProblemAnalysis> {
    const analysisStep = session.addStep('problem_analysis', {
      description: 'Analyzing problem structure and requirements',
      input: request.messages[request.messages.length - 1].content
    });

    try {
      const analysis = await this.reasoningEngine.analyzeProblem(request);

      analysisStep.complete({
        result: analysis,
        confidence: analysis.confidence,
        complexity: analysis.complexity
      });

      return analysis;

    } catch (error) {
      analysisStep.fail(error);
      throw error;
    }
  }

  /**
   * Generate reasoning steps based on problem analysis
   */
  private async generateReasoningSteps(
    analysis: ProblemAnalysis,
    session: ThinkingSession
  ): Promise<ReasoningStep[]> {
    const stepGenerationStep = session.addStep('step_generation', {
      description: 'Generating reasoning steps',
      analysis: analysis
    });

    try {
      const steps = await this.reasoningEngine.generateReasoningSteps(analysis);

      stepGenerationStep.complete({
        steps: steps,
        estimatedDuration: steps.reduce((total, step) => total + step.estimatedTime, 0)
      });

      return steps;

    } catch (error) {
      stepGenerationStep.fail(error);
      throw error;
    }
  }

  /**
   * Execute reasoning process step by step
   */
  private async executeReasoningProcess(
    steps: ReasoningStep[],
    session: ThinkingSession
  ): Promise<ReasoningResult> {
    const results: StepResult[] = [];

    for (const step of steps) {
      const executionStep = session.addStep('reasoning_execution', {
        description: `Executing reasoning step: ${step.description}`,
        stepId: step.id
      });

      try {
        const result = await this.reasoningEngine.executeStep(step, results);

        executionStep.complete({
          result: result,
          stepCompleted: true,
          timeSpent: result.executionTime
        });

        results.push(result);

        // Update progress
        this.progressTracker.updateProgress(session.id, {
          completedSteps: results.length,
          totalSteps: steps.length,
          currentStep: step.description
        });

      } catch (error) {
        executionStep.fail(error);

        // Attempt to recover from error
        const recoveryResult = await this.errorRecovery.recoverFromStepError(error, step, results);

        if (recoveryResult.success) {
          results.push(recoveryResult.result);
        } else {
          throw error;
        }
      }
    }

    return {
      steps: results,
      overallConfidence: this.calculateOverallConfidence(results),
      synthesisRequired: this.needsSynthesis(results)
    };
  }

  /**
   * Synthesize final response from reasoning results
   */
  private async synthesizeResponse(
    result: ReasoningResult,
    session: ThinkingSession
  ): Promise<string> {
    const synthesisStep = session.addStep('response_synthesis', {
      description: 'Synthesizing final response',
      reasoningResults: result.steps
    });

    try {
      const response = await this.reasoningEngine.synthesizeResponse(result);

      synthesisStep.complete({
        response: response,
        synthesisTime: Date.now(),
        quality: this.assessResponseQuality(response, result)
      });

      return response;

    } catch (error) {
      synthesisStep.fail(error);
      throw error;
    }
  }

  /**
   * Get current thinking progress
   */
  getProgress(sessionId: string): ThinkingProgress {
    return this.progressTracker.getProgress(sessionId);
  }

  /**
   * Cancel thinking process
   */
  cancelThinking(sessionId: string): void {
    this.progressTracker.cancelSession(sessionId);
  }
}
```

#### Key Features

- **Multi-Step Reasoning**: Breaks down complex problems into manageable steps
- **Progress Tracking**: Real-time progress monitoring and updates
- **Error Recovery**: Sophisticated error handling and recovery mechanisms
- **Adaptive Reasoning**: Adjusts reasoning approach based on problem complexity
- **Result Synthesis**: Combines multiple reasoning steps into coherent responses
- **Performance Metrics**: Detailed metrics on reasoning performance

#### Usage Example

```typescript
// Get DeepThinkingService instance
const thinkingService = DeepThinkingService.getInstance();

// Process request with deep thinking
const result = await thinkingService.processWithDeepThinking({
  model: 'siliconflow.Qwen/Qwen2.5-7B-Instruct',
  messages: [
    { role: 'user', content: 'Design a scalable microservices architecture for an e-commerce platform' }
  ]
}, {
  enableStepByStep: true,
  showProgress: true,
  maxThinkingTime: 30000
});

console.log('Response:', result.response);
console.log('Thinking steps:', result.thinkingProcess);
console.log('Metrics:', result.metrics);

// Monitor progress
const progress = thinkingService.getProgress(result.sessionId);
console.log('Progress:', progress);
```

### HybridChatService

#### Overview

`HybridChatService` orchestrates multiple AI models and services to provide intelligent, context-aware conversations with automatic routing and enhancement.

#### Architecture

```typescript
/**
 * Multi-model chat orchestration service with intelligent routing and response enhancement
 * Coordinates between different AI models and services for optimal responses
 */
export class HybridChatService {
  private static instance: HybridChatService;
  private apiManager: APIManager;
  private messageEnhancer: MessageEnhancer;
  private searchDecisionEngine: SearchDecisionEngine;
  private conversationMemory: ConversationMemory;

  private constructor() {
    this.apiManager = APIManager.getInstance();
    this.messageEnhancer = new MessageEnhancer();
    this.searchDecisionEngine = new SearchDecisionEngine();
    this.conversationMemory = new ConversationMemory();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): HybridChatService {
    if (!HybridChatService.instance) {
      HybridChatService.instance = new HybridChatService();
    }
    return HybridChatService.instance;
  }

  /**
   * Send enhanced chat request
   */
  async sendEnhancedChatRequest(
    request: EnhancedChatRequest
  ): Promise<EnhancedChatResponse> {
    const chatSession = this.createChatSession(request);

    try {
      // Step 1: Analyze request characteristics
      const analysis = await this.analyzeRequest(request, chatSession);

      // Step 2: Determine optimal strategy
      const strategy = await this.determineStrategy(analysis, chatSession);

      // Step 3: Execute chat strategy
      const chatResult = await this.executeChatStrategy(strategy, chatSession);

      // Step 4: Enhance response
      const enhancedResponse = await this.messageEnhancer.enhanceResponse(
        chatResult,
        analysis
      );

      // Step 5: Update conversation memory
      this.conversationMemory.update(chatSession, {
        request: request,
        response: enhancedResponse,
        strategy: strategy,
        metrics: chatResult.metrics
      });

      return {
        success: true,
        response: enhancedResponse,
        strategy: strategy,
        enhancements: enhancedResponse.enhancements,
        metadata: {
          sessionId: chatSession.id,
          duration: chatSession.getDuration(),
          modelsUsed: strategy.modelsUsed,
          tokensUsed: chatResult.metrics.totalTokens
        }
      };

    } catch (error) {
      return await this.handleChatError(error, chatSession);
    }
  }

  /**
   * Analyze request to determine best approach
   */
  private async analyzeRequest(
    request: EnhancedChatRequest,
    session: ChatSession
  ): Promise<RequestAnalysis> {
    const analysis = {
      intent: await this.extractIntent(request.messages),
      complexity: this.assessComplexity(request.messages),
      context: this.extractContext(request.messages),
      domain: this.identifyDomain(request.messages),
      language: this.detectLanguage(request.messages),
      needsSearch: await this.searchDecisionEngine.needsSearch(request),
      needsCodeGeneration: this.needsCodeGeneration(request.messages),
      needsDeepThinking: this.needsDeepThinking(request.messages)
    };

    session.analysis = analysis;
    return analysis;
  }

  /**
   * Determine optimal chat strategy based on analysis
   */
  private async determineStrategy(
    analysis: RequestAnalysis,
    session: ChatSession
  ): Promise<ChatStrategy> {
    const strategy = {
      primaryModel: this.selectPrimaryModel(analysis),
      fallbackModels: this.selectFallbackModels(analysis),
      enableSearch: analysis.needsSearch,
      enableDeepThinking: analysis.needsDeepThinking,
      enableCodeExecution: analysis.needsCodeGeneration,
      enhancementLevel: this.determineEnhancementLevel(analysis),
      routingMethod: this.selectRoutingMethod(analysis)
    };

    session.strategy = strategy;
    return strategy;
  }

  /**
   * Execute determined chat strategy
   */
  private async executeChatStrategy(
    strategy: ChatStrategy,
    session: ChatSession
  ): Promise<ChatResult> {
    if (strategy.enableDeepThinking) {
      return await this.executeDeepThinkingStrategy(strategy, session);
    } else if (strategy.enableSearch) {
      return await this.executeSearchEnhancedStrategy(strategy, session);
    } else {
      return await this.executeStandardStrategy(strategy, session);
    }
  }

  /**
   * Execute deep thinking enhanced strategy
   */
  private async executeDeepThinkingStrategy(
    strategy: ChatStrategy,
    session: ChatSession
  ): Promise<ChatResult> {
    const thinkingService = DeepThinkingService.getInstance();

    return await thinkingService.processWithDeepThinking({
      model: strategy.primaryModel,
      messages: session.request.messages,
      tools: this.prepareTools(strategy)
    }, {
      enableStepByStep: true,
      maxThinkingTime: 30000
    });
  }

  /**
   * Execute search enhanced strategy
   */
  private async executeSearchEnhancedStrategy(
    strategy: ChatStrategy,
    session: ChatSession
  ): Promise<ChatResult> {
    // First perform search if needed
    let searchResults: SearchResult[] = [];
    if (strategy.enableSearch) {
      searchResults = await this.performSearch(session.request.messages);
    }

    // Then send chat request with search context
    const enhancedRequest = this.enhanceRequestWithSearch(
      session.request,
      searchResults
    );

    return await this.apiManager.sendChatRequest(enhancedRequest);
  }

  /**
   * Execute standard chat strategy
   */
  private async executeStandardStrategy(
    strategy: ChatStrategy,
    session: ChatSession
  ): Promise<ChatResult> {
    return await this.apiManager.sendChatRequest(session.request);
  }

  /**
   * Get conversation history
   */
  getConversationHistory(sessionId: string): ConversationHistory {
    return this.conversationMemory.getHistory(sessionId);
  }

  /**
   * Clear conversation memory
   */
  clearConversation(sessionId: string): void {
    this.conversationMemory.clear(sessionId);
  }
}
```

#### Key Features

- **Multi-Model Orchestration**: Coordinates between different AI models
- **Intelligent Routing**: Selects optimal model based on request characteristics
- **Search Integration**: Automatically incorporates web search when needed
- **Response Enhancement**: Improves response quality through post-processing
- **Conversation Memory**: Maintains context across multiple interactions
- **Strategy Adaptation**: Adjusts approach based on request complexity

#### Usage Example

```typescript
// Get HybridChatService instance
const chatService = HybridChatService.getInstance();

// Send enhanced chat request
const response = await chatService.sendEnhancedChatRequest({
  model: 'auto',
  messages: [
    { role: 'user', content: 'What are the latest developments in quantum computing?' }
  ],
  options: {
    enableSearch: true,
    enhanceResponse: true,
    includeSources: true
  }
});

console.log('Response:', response.response);
console.log('Strategy used:', response.strategy);
console.log('Enhancements:', response.enhancements);

// Get conversation history
const history = chatService.getConversationHistory(response.metadata.sessionId);
console.log('Conversation history:', history);
```

## Voice Services

### SpeechRecognitionService

#### Overview

`SpeechRecognitionService` integrates with Huawei's speech recognition engine to provide real-time voice-to-text conversion with state management and error handling.

#### Architecture

```typescript
/**
 * Huawei speech recognition service integration
 * Provides real-time voice-to-text conversion with state management
 */
export class SpeechRecognitionService {
  private static instance: SpeechRecognitionService;
  private speechEngine: speech.SpeechRecognitionEngine;
  private audioCapturer: AudioCapturer;
  private recognitionState: RecognitionState = RecognitionState.IDLE;
  private eventEmitter: EventEmitter = new EventEmitter();
  private config: SpeechRecognitionConfig;

  private constructor() {
    this.initializeSpeechEngine();
    this.initializeAudioCapturer();
    this.setupEventHandlers();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): SpeechRecognitionService {
    if (!SpeechRecognitionService.instance) {
      SpeechRecognitionService.instance = new SpeechRecognitionService();
    }
    return SpeechRecognitionService.instance;
  }

  /**
   * Start speech recognition
   */
  async startRecognition(
    options: RecognitionOptions = {}
  ): Promise<void> {
    if (this.recognitionState !== RecognitionState.IDLE) {
      throw new Error('Speech recognition already in progress');
    }

    try {
      this.updateState(RecognitionState.INITIALIZING);

      // Configure recognition parameters
      const config = this.createRecognitionConfig(options);

      // Initialize recognition session
      await this.speechEngine.startListening(config);

      // Start audio capture
      await this.audioCapturer.startCapture();

      this.updateState(RecognitionState.LISTENING);

      this.eventEmitter.emit('recognition_started');

    } catch (error) {
      this.updateState(RecognitionState.ERROR);
      this.eventEmitter.emit('recognition_error', error);
      throw error;
    }
  }

  /**
   * Stop speech recognition
   */
  async stopRecognition(): Promise<string> {
    if (this.recognitionState === RecognitionState.IDLE) {
      return '';
    }

    try {
      this.updateState(RecognitionState.PROCESSING);

      // Stop audio capture
      await this.audioCapturer.stopCapture();

      // Stop recognition and get final result
      const result = await this.speechEngine.stopListening();

      this.updateState(RecognitionState.IDLE);

      this.eventEmitter.emit('recognition_completed', result);

      return result;

    } catch (error) {
      this.updateState(RecognitionState.ERROR);
      this.eventEmitter.emit('recognition_error', error);
      throw error;
    }
  }

  /**
   * Cancel speech recognition
   */
  async cancelRecognition(): Promise<void> {
    if (this.recognitionState === RecognitionState.IDLE) {
      return;
    }

    try {
      await this.audioCapturer.stopCapture();
      await this.speechEngine.cancelListening();

      this.updateState(RecognitionState.IDLE);

      this.eventEmitter.emit('recognition_cancelled');

    } catch (error) {
      this.updateState(RecognitionState.ERROR);
      this.eventEmitter.emit('recognition_error', error);
    }
  }

  /**
   * Initialize speech recognition engine
   */
  private initializeSpeechEngine(): void {
    this.speechEngine = new speech.SpeechRecognitionEngine();

    this.speechEngine.onResult = (result: SpeechRecognitionResult) => {
      this.handleRecognitionResult(result);
    };

    this.speechEngine.onError = (error: SpeechRecognitionError) => {
      this.handleRecognitionError(error);
    };

    this.speechEngine.onVolumeChanged = (volume: number) => {
      this.eventEmitter.emit('volume_changed', volume);
    };
  }

  /**
   * Initialize audio capturer
   */
  private initializeAudioCapturer(): void {
    this.audioCapturer = new AudioCapturer({
      sampleRate: 16000,
      channels: 1,
      bitDepth: 16,
      bufferSize: 4096
    });

    this.audioCapturer.onAudioData = (audioData: ArrayBuffer) => {
      if (this.recognitionState === RecognitionState.LISTENING) {
        this.speechEngine.processAudio(audioData);
      }
    };

    this.audioCapturer.onError = (error: AudioCaptureError) => {
      this.handleAudioError(error);
    };
  }

  /**
   * Handle recognition results
   */
  private handleRecognitionResult(result: SpeechRecognitionResult): void {
    if (result.isFinal) {
      this.updateState(RecognitionState.PROCESSING);
      this.eventEmitter.emit('final_result', result.text);
    } else {
      this.eventEmitter.emit('interim_result', result.text);
    }
  }

  /**
   * Handle recognition errors
   */
  private handleRecognitionError(error: SpeechRecognitionError): void {
    this.updateState(RecognitionState.ERROR);
    this.eventEmitter.emit('recognition_error', error);
  }

  /**
   * Update recognition state
   */
  private updateState(newState: RecognitionState): void {
    const oldState = this.recognitionState;
    this.recognitionState = newState;
    this.eventEmitter.emit('state_changed', { oldState, newState });
  }

  /**
   * Get current recognition state
   */
  getState(): RecognitionState {
    return this.recognitionState;
  }

  /**
   * Add event listener
   */
  on(event: string, callback: Function): void {
    this.eventEmitter.on(event, callback);
  }

  /**
   * Remove event listener
   */
  off(event: string, callback: Function): void {
    this.eventEmitter.off(event, callback);
  }
}
```

#### Key Features

- **Real-time Recognition**: Continuous speech-to-text conversion
- **State Management**: Comprehensive state tracking and transitions
- **Error Handling**: Robust error recovery and user feedback
- **Volume Monitoring**: Real-time audio level monitoring
- **Configuration Support**: Customizable recognition parameters
- **Event System**: Flexible event handling for different states

#### Usage Example

```typescript
// Get SpeechRecognitionService instance
const speechService = SpeechRecognitionService.getInstance();

// Set up event listeners
speechService.on('recognition_started', () => {
  console.log('Speech recognition started');
});

speechService.on('interim_result', (text) => {
  console.log('Interim result:', text);
});

speechService.on('final_result', (text) => {
  console.log('Final result:', text);
});

speechService.on('recognition_error', (error) => {
  console.error('Recognition error:', error);
});

// Start recognition
await speechService.startRecognition({
  language: 'zh-CN',
  enablePunctuation: true,
  enablePartialResults: true
});

// Stop recognition (when user finishes speaking)
const finalText = await speechService.stopRecognition();
console.log('Final recognized text:', finalText);
```

### TTSService

#### Overview

`TTSService` provides text-to-speech functionality using Huawei's TTS engine, supporting multiple languages, voices, and speech parameters.

#### Architecture

```typescript
/**
 * Huawei TTS service integration for text-to-speech conversion
 * Supports multiple languages, voices, and speech parameters
 */
export class TTSService {
  private static instance: TTSService;
  private ttsEngine: speech.TextToSpeechEngine;
  private playbackState: PlaybackState = PlaybackState.IDLE;
  private eventEmitter: EventEmitter = new EventEmitter();
  private config: TTSConfig;

  private constructor() {
    this.initializeTTSEngine();
    this.setupEventHandlers();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): TTTServise {
    if (!TTSService.instance) {
      TTSService.instance = new TTSService();
    }
    return TTSService.instance;
  }

  /**
   * Speak text with specified parameters
   */
  async speak(
    text: string,
    options: SpeakOptions = {}
  ): Promise<void> {
    if (this.playbackState !== PlaybackState.IDLE) {
      throw new Error('TTS playback already in progress');
    }

    try {
      this.updateState(PlaybackState.PREPARING);

      // Configure speech parameters
      const params = this.createSpeechParameters(options);

      // Start speech synthesis
      await this.ttsEngine.speak(text, params);

      this.updateState(PlaybackState.PLAYING);
      this.eventEmitter.emit('speech_started', { text, options });

    } catch (error) {
      this.updateState(PlaybackState.ERROR);
      this.eventEmitter.emit('speech_error', error);
      throw error;
    }
  }

  /**
   * Stop current speech playback
   */
  async stop(): Promise<void> {
    if (this.playbackState === PlaybackState.IDLE) {
      return;
    }

    try {
      await this.ttsEngine.stop();
      this.updateState(PlaybackState.IDLE);
      this.eventEmitter.emit('speech_stopped');

    } catch (error) {
      this.updateState(PlaybackState.ERROR);
      this.eventEmitter.emit('speech_error', error);
      throw error;
    }
  }

  /**
   * Pause current speech playback
   */
  async pause(): Promise<void> {
    if (this.playbackState !== PlaybackState.PLAYING) {
      return;
    }

    try {
      await this.ttsEngine.pause();
      this.updateState(PlaybackState.PAUSED);
      this.eventEmitter.emit('speech_paused');

    } catch (error) {
      this.updateState(PlaybackState.ERROR);
      this.eventEmitter.emit('speech_error', error);
      throw error;
    }
  }

  /**
   * Resume paused speech playback
   */
  async resume(): Promise<void> {
    if (this.playbackState !== PlaybackState.PAUSED) {
      return;
    }

    try {
      await this.ttsEngine.resume();
      this.updateState(PlaybackState.PLAYING);
      this.eventEmitter.emit('speech_resumed');

    } catch (error) {
      this.updateState(PlaybackState.ERROR);
      this.eventEmitter.emit('speech_error', error);
      throw error;
    }
  }

  /**
   * Get available voices
   */
  async getAvailableVoices(): Promise<TTSVoice[]> {
    return await this.ttsEngine.getAvailableVoices();
  }

  /**
   * Set voice
   */
  async setVoice(voice: TTSVoice): Promise<void> {
    await this.ttsEngine.setVoice(voice);
    this.config.voice = voice;
  }

  /**
   * Get current playback state
   */
  getState(): PlaybackState {
    return this.playbackState;
  }

  /**
   * Initialize TTS engine
   */
  private initializeTTSEngine(): void {
    this.ttsEngine = new speech.TextToSpeechEngine();

    this.ttsEngine.onPlaybackStarted = () => {
      this.updateState(PlaybackState.PLAYING);
      this.eventEmitter.emit('playback_started');
    };

    this.ttsEngine.onPlaybackCompleted = () => {
      this.updateState(PlaybackState.IDLE);
      this.eventEmitter.emit('playback_completed');
    };

    this.ttsEngine.onPlaybackError = (error: TTSError) => {
      this.updateState(PlaybackState.ERROR);
      this.eventEmitter.emit('playback_error', error);
    };

    this.ttsEngine.onProgress = (progress: TTSProgress) => {
      this.eventEmitter.emit('playback_progress', progress);
    };
  }

  /**
   * Update playback state
   */
  private updateState(newState: PlaybackState): void {
    const oldState = this.playbackState;
    this.playbackState = newState;
    this.eventEmitter.emit('state_changed', { oldState, newState });
  }

  /**
   * Add event listener
   */
  on(event: string, callback: Function): void {
    this.eventEmitter.on(event, callback);
  }

  /**
   * Remove event listener
   */
  off(event: string, callback: Function): void {
    this.eventEmitter.off(event, callback);
  }
}
```

#### Key Features

- **Multiple Languages**: Support for various languages and voices
- **Speech Parameters**: Customizable pitch, speed, and volume
- **Playback Control**: Play, pause, resume, and stop functionality
- **Progress Tracking**: Real-time playback progress monitoring
- **Voice Management**: Dynamic voice selection and configuration
- **Event System**: Comprehensive event handling for all states

#### Usage Example

```typescript
// Get TTSService instance
const ttsService = TTSService.getInstance();

// Set up event listeners
ttsService.on('speech_started', (data) => {
  console.log('Speech started:', data.text);
});

ttsService.on('playback_progress', (progress) => {
  console.log('Progress:', progress.percentage + '%');
});

ttsService.on('playback_completed', () => {
  console.log('Speech completed');
});

// Speak text
await ttsService.speak('Hello, this is a text-to-speech example.', {
  language: 'en-US',
  voice: 'default',
  speed: 1.0,
  pitch: 1.0,
  volume: 0.8
});

// Get available voices
const voices = await ttsService.getAvailableVoices();
console.log('Available voices:', voices);
```

## Utility Services

### SessionManager

#### Overview

`SessionManager` handles conversation sessions, including history management, state persistence, and session lifecycle management.

#### Architecture

```typescript
/**
 * Conversation session management service
 * Handles session lifecycle, history, and state persistence
 */
export class SessionManager {
  private static instance: SessionManager;
  private sessions: Map<string, ChatSession> = new Map();
  private activeSessionId: string | null = null;
  private storage: AppStorage;
  private eventEmitter: EventEmitter = new EventEmitter();

  private constructor() {
    this.storage = AppStorage.getInstance();
    this.loadSessionsFromStorage();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): SessionManager {
    if (!SessionManager.instance) {
      SessionManager.instance = new SessionManager();
    }
    return SessionManager.instance;
  }

  /**
   * Create new chat session
   */
  async createSession(options: SessionOptions = {}): Promise<string> {
    const sessionId = this.generateSessionId();
    const session: ChatSession = {
      id: sessionId,
      title: options.title || 'New Conversation',
      model: options.model || 'siliconflow.Qwen/Qwen2.5-7B-Instruct',
      systemPrompt: options.systemPrompt,
      messages: [],
      createdAt: Date.now(),
      updatedAt: Date.now(),
      metadata: options.metadata || {}
    };

    this.sessions.set(sessionId, session);
    this.activeSessionId = sessionId;

    // Save to persistent storage
    await this.saveSessionsToStorage();

    this.eventEmitter.emit('session_created', session);

    return sessionId;
  }

  /**
   * Get session by ID
   */
  getSession(sessionId: string): ChatSession | null {
    return this.sessions.get(sessionId) || null;
  }

  /**
   * Get active session
   */
  getActiveSession(): ChatSession | null {
    if (!this.activeSessionId) {
      return null;
    }
    return this.getSession(this.activeSessionId);
  }

  /**
   * Set active session
   */
  async setActiveSession(sessionId: string): Promise<void> {
    if (!this.sessions.has(sessionId)) {
      throw new Error(`Session ${sessionId} not found`);
    }

    const oldSessionId = this.activeSessionId;
    this.activeSessionId = sessionId;

    this.eventEmitter.emit('session_changed', {
      oldSessionId,
      newSessionId: sessionId
    });

    // Update session metadata
    const session = this.sessions.get(sessionId)!;
    session.updatedAt = Date.now();
    await this.saveSessionsToStorage();
  }

  /**
   * Add message to session
   */
  async addMessage(
    sessionId: string,
    message: ChatMessage
  ): Promise<void> {
    const session = this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    session.messages.push({
      ...message,
      timestamp: Date.now()
    });

    session.updatedAt = Date.now();

    // Auto-generate title if this is the first user message
    if (session.messages.length === 1 && message.role === 'user') {
      session.title = await this.generateSessionTitle(message.content);
    }

    await this.saveSessionsToStorage();
    this.eventEmitter.emit('message_added', { sessionId, message });
  }

  /**
   * Delete session
   */
  async deleteSession(sessionId: string): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return;
    }

    this.sessions.delete(sessionId);

    // If deleted session was active, set new active session
    if (this.activeSessionId === sessionId) {
      this.activeSessionId = this.sessions.size > 0
        ? Array.from(this.sessions.keys())[0]
        : null;
    }

    await this.saveSessionsToStorage();
    this.eventEmitter.emit('session_deleted', { sessionId, session });
  }

  /**
   * Get all sessions
   */
  getAllSessions(): ChatSession[] {
    return Array.from(this.sessions.values()).sort((a, b) =>
      b.updatedAt - a.updatedAt
    );
  }

  /**
   * Search sessions
   */
  searchSessions(query: string): ChatSession[] {
    const lowercaseQuery = query.toLowerCase();

    return this.getAllSessions().filter(session =>
      session.title.toLowerCase().includes(lowercaseQuery) ||
      session.messages.some(msg =>
        msg.content.toLowerCase().includes(lowercaseQuery)
      )
    );
  }

  /**
   * Export session data
   */
  exportSession(sessionId: string): string {
    const session = this.getSession(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    return JSON.stringify(session, null, 2);
  }

  /**
   * Import session data
   */
  async importSession(sessionData: string): Promise<string> {
    try {
      const session = JSON.parse(sessionData) as ChatSession;

      // Validate session structure
      if (!this.validateSession(session)) {
        throw new Error('Invalid session data');
      }

      // Generate new ID to avoid conflicts
      session.id = this.generateSessionId();
      session.updatedAt = Date.now();

      this.sessions.set(session.id, session);
      await this.saveSessionsToStorage();

      this.eventEmitter.emit('session_imported', session);

      return session.id;

    } catch (error) {
      throw new Error(`Failed to import session: ${error.message}`);
    }
  }

  /**
   * Clear all sessions
   */
  async clearAllSessions(): Promise<void> {
    const sessionCount = this.sessions.size;
    this.sessions.clear();
    this.activeSessionId = null;

    await this.saveSessionsToStorage();
    this.eventEmitter.emit('all_sessions_cleared', { sessionCount });
  }

  /**
   * Load sessions from persistent storage
   */
  private async loadSessionsFromStorage(): Promise<void> {
    try {
      const sessionsData = await this.storage.get('chat_sessions');
      if (sessionsData) {
        const sessions = JSON.parse(sessionsData) as ChatSession[];
        sessions.forEach(session => {
          this.sessions.set(session.id, session);
        });

        // Restore active session
        const activeSessionId = await this.storage.get('active_session_id');
        if (activeSessionId && this.sessions.has(activeSessionId)) {
          this.activeSessionId = activeSessionId;
        }
      }
    } catch (error) {
      Logger.error('Failed to load sessions from storage:', error);
    }
  }

  /**
   * Save sessions to persistent storage
   */
  private async saveSessionsToStorage(): Promise<void> {
    try {
      const sessionsData = JSON.stringify(Array.from(this.sessions.values()));
      await this.storage.set('chat_sessions', sessionsData);

      if (this.activeSessionId) {
        await this.storage.set('active_session_id', this.activeSessionId);
      }
    } catch (error) {
      Logger.error('Failed to save sessions to storage:', error);
    }
  }

  /**
   * Generate session ID
   */
  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Generate session title from first message
   */
  private async generateSessionTitle(message: string): Promise<string> {
    // Simple title generation - could be enhanced with AI
    const maxLength = 50;
    let title = message.trim();

    if (title.length > maxLength) {
      title = title.substring(0, maxLength) + '...';
    }

    return title;
  }

  /**
   * Validate session structure
   */
  private validateSession(session: any): boolean {
    return session.id &&
           session.title &&
           Array.isArray(session.messages) &&
           session.createdAt &&
           session.updatedAt;
  }

  /**
   * Add event listener
   */
  on(event: string, callback: Function): void {
    this.eventEmitter.on(event, callback);
  }

  /**
   * Remove event listener
   */
  off(event: string, callback: Function): void {
    this.eventEmitter.off(event, callback);
  }
}
```

#### Key Features

- **Session Lifecycle**: Complete session management from creation to deletion
- **State Persistence**: Automatic saving and loading of sessions
- **Message Management**: Add, retrieve, and organize conversation messages
- **Search Functionality**: Find sessions by title or message content
- **Import/Export**: Session data portability and backup
- **Event System**: Real-time notifications for session changes

#### Usage Example

```typescript
// Get SessionManager instance
const sessionManager = SessionManager.getInstance();

// Create new session
const sessionId = await sessionManager.createSession({
  title: 'Python Programming Help',
  model: 'siliconflow.Qwen/Qwen2.5-7B-Instruct',
  systemPrompt: 'You are a Python programming expert...'
});

// Add messages to session
await sessionManager.addMessage(sessionId, {
  role: 'user',
  content: 'How do I create a list comprehension in Python?'
});

await sessionManager.addMessage(sessionId, {
  role: 'assistant',
  content: 'You can create a list comprehension using the following syntax...'
});

// Get all sessions
const allSessions = sessionManager.getAllSessions();
console.log('All sessions:', allSessions);

// Search sessions
const searchResults = sessionManager.searchSessions('Python');
console.log('Python sessions:', searchResults);

// Export session
const sessionData = sessionManager.exportSession(sessionId);
console.log('Session data:', sessionData);
```

## Service Integration Patterns

### Service Dependencies

```
Service Dependencies:
├── APIManager
│   ├── BaseAPIClient implementations
│   └── WebSocketService
├── HybridChatService
│   ├── APIManager
│   ├── DeepThinkingService
│   ├── MessageEnhancer
│   └── SearchDecisionEngine
├── DeepThinkingService
│   ├── APIManager
│   └── ProgressTracker
└── Voice Services
    ├── SpeechRecognitionService
    │   └── AudioCapturer
    ├── TTSService
    └── AutoTTSService
        └── TTSService
```

### Event Communication

```
Service Event Flow:
├── User Actions → Component Events → Service Methods
├── Service Events → State Updates → UI Re-renders
├── External Events → Service Processing → User Feedback
└── Error Events → Error Handling → User Notifications
```

### Error Handling Patterns

```
Error Handling Strategy:
├── Local Error Handling (Service level)
│   ├── Validation errors
│   ├── Network errors
│   └── Business logic errors
├── Global Error Handling (Application level)
│   ├── Uncaught exceptions
│   ├── Service failures
│   └── System errors
├── User-Facing Error Messages
│   ├── Toast notifications
│   ├── Dialog boxes
│   └── Inline error indicators
└── Error Recovery
    ├── Automatic retry
    ├── Fallback mechanisms
    └── User guidance
```

## Performance Considerations

### Service Optimization

```
Performance Strategies:
├── Lazy Initialization
│   ├── Services created on first use
│   └── Resource allocation optimization
├── Connection Pooling
│   ├── HTTP connection reuse
│   └── WebSocket connection management
├── Caching Strategies
│   ├── API response caching
│   ├── Computed result caching
│   └── Session data caching
├── Memory Management
│   ├── Service lifecycle management
│   ├── Resource cleanup
│   └── Memory pressure handling
└── Asynchronous Operations
    ├── Non-blocking operations
    ├── Parallel processing
    └── Background tasks
```

### Monitoring and Metrics

```
Service Monitoring:
├── Performance Metrics
│   ├── Response times
│   ├── Memory usage
│   └── Error rates
├── Usage Statistics
│   ├── API call counts
│   ├── Feature usage
│   └── User engagement
├── Health Checks
│   ├── Service availability
│   ├── Connection status
│   └── Resource status
└── Logging and Debugging
    ├── Detailed request logs
    ├── Error tracking
    └── Performance profiling
```

This comprehensive service layer documentation provides developers with the knowledge needed to understand, use, and extend the Javis service architecture effectively.