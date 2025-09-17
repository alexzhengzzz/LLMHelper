# Javis Developer Setup and Integration Guide

## Overview

This comprehensive guide provides everything developers need to set up, develop, test, and integrate with the Javis HarmonyOS AI programming assistant. Follow these instructions to get your development environment running smoothly.

## Quick Start

### Prerequisites

Before you begin, ensure your system meets these requirements:

**System Requirements:**
- **OS**: macOS, Windows, or Linux
- **Memory**: 8GB RAM minimum, 16GB recommended
- **Storage**: 20GB free space for development tools and project files

**Required Software:**
- **Node.js**: Version 16.0 or higher
- **HarmonyOS SDK**: Version 5.0.5(17) or later
- **DevEco Studio**: Latest version for HarmonyOS development
- **Git**: For version control operations

### Initial Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-repo/javis.git
   cd javis
   ```

2. **Install Dependencies**
   ```bash
   # Install Node.js dependencies
   npm install

   # Install HarmonyOS dependencies (in DevEco Studio)
   # Open the project in DevEco Studio and let it sync dependencies
   ```

3. **Configure Environment**
   ```bash
   # Copy environment configuration
   cp .env.example .env

   # Edit the configuration file with your settings
   # API keys, server URLs, etc.
   ```

## Development Environment Setup

### HarmonyOS Development Environment

#### Install DevEco Studio

1. **Download DevEco Studio**
   - Visit the official HarmonyOS developer website
   - Download the latest version for your operating system
   - Follow the installation instructions

2. **Configure SDK**
   ```bash
   # After installing DevEco Studio, configure the HarmonyOS SDK
   # Navigate to: Tools > SDK Manager
   # Ensure API Version 5.0.5(17) or later is installed
   ```

3. **Set Up Emulator or Device**
   ```bash
   # Create a virtual device in DevEco Studio
   # or connect a physical HarmonyOS device
   # Ensure USB debugging is enabled
   ```

#### Project Configuration

1. **Open Project in DevEco Studio**
   ```bash
   # Launch DevEco Studio
   # File > Open > Select the javis/ohosllm directory
   ```

2. **Configure Build Settings**
   ```bash
   # Verify build.gradle configuration
   # Ensure correct API level and target device settings
   # Configure signing certificates for debug builds
   ```

3. **Sync Dependencies**
   ```bash
   # Click "Sync Project with Gradle Files" in DevEco Studio
   # This will download all required HarmonyOS dependencies
   ```

### Backend Server Setup

#### Go Environment Setup

1. **Install Go**
   ```bash
   # For macOS
   brew install go

   # For Windows
   # Download from https://golang.org/dl/

   # For Linux
   sudo apt update
   sudo apt install golang-go
   ```

2. **Configure Go Environment**
   ```bash
   # Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
   export GOPATH=$HOME/go
   export PATH=$PATH:$GOPATH/bin
   export PATH=$PATH:/usr/local/go/bin
   ```

3. **Set Up Backend Server**
   ```bash
   # Navigate to server directory
   cd server

   # Install Go dependencies
   go mod download
   go mod tidy

   # Run the server locally
   go run main.go

   # Or deploy to VPS
   ./dev-deploy.sh
   ```

### API Configuration

#### Environment Variables

Create a `.env` file in the project root:

```env
# Server Configuration
SERVER_URL=http://localhost:8080
WS_URL=ws://localhost:8080/ws

# API Keys (for development)
SILICONFLOW_API_KEY=your_siliconflow_key
GOOGLE_GEMINI_API_KEY=your_gemini_key
ZHIPU_GLM_API_KEY=your_glm_key

# Development Settings
DEBUG=true
LOG_LEVEL=debug
ENABLE_MOCK_SERVICES=false
```

#### API Key Management

1. **SiliconFlow API**
   - Visit https://siliconflow.cn/
   - Create an account and generate API key
   - Add key to your `.env` file

2. **Google Gemini API**
   - Visit https://makersuite.google.com/app/apikey
   - Create API key for Gemini access
   - Add key to your `.env` file

3. **智谱GLM API**
   - Visit https://open.bigmodel.cn/
   - Register and create API key
   - Add key to your `.env` file

## Development Workflow

### Building the Application

#### HarmonyOS App Build

```bash
# Navigate to HarmonyOS app directory
cd ohosllm

# Build using Gradle (through DevEco Studio)
# In DevEco Studio: Build > Build Bundle(s) / APK(s) > Build Bundle(s)

# Or using command line
./build.sh
```

#### Build Script Options

The build script supports various options:

```bash
# Usage: ./build.sh [options]

# Options:
#   --debug     Build debug version
#   --release   Build release version
#   --clean     Clean build cache
#   --test      Run tests after build
#   --help      Show help information

# Examples:
./build.sh --debug          # Debug build
./build.sh --release        # Release build
./build.sh --clean --debug  # Clean debug build
```

### Testing

#### Running Tests

```bash
# Run all tests
./test.sh

# Run single test file
./test-single.sh APIManagerTest

# Run tests with coverage
./test.sh --coverage

# Run performance tests
./test.sh --performance
```

#### Test Categories

**Unit Tests:**
- Service layer testing
- Utility function testing
- Component logic testing

**Integration Tests:**
- API integration testing
- Service integration testing
- Database integration testing

**UI Tests:**
- Component rendering testing
- User interaction testing
- Animation performance testing

**Performance Tests:**
- Memory usage testing
- Response time testing
- Battery impact testing

### Debugging

#### Enable Debug Mode

```bash
# In your .env file
DEBUG=true
LOG_LEVEL=debug

# Or programmatically
Logger.setLogLevel(LogLevel.DEBUG)
```

#### Debug Tools

**DevEco Studio Debugger:**
- Set breakpoints in ArkTS code
- Inspect variables and call stack
- Step through code execution

**Network Debugging:**
```bash
# Enable network request logging
Logger.info('Network', `Request: ${JSON.stringify(request)}`)
Logger.info('Network', `Response: ${JSON.stringify(response)}`)
```

**Performance Profiling:**
```bash
# Use built-in performance monitoring
const perfId = Logger.startPerformanceMonitoring('Module', 'Function', 'Context')
// ... code to measure ...
Logger.endPerformanceMonitoring(perfId)
```

## Architecture Understanding

### Project Structure

```
javis/
├── ohosllm/                    # HarmonyOS client application
│   ├── entry/
│   │   └── src/main/ets/        # Main source code
│   │       ├── entryability/    # Application entry
│   │       ├── pages/           # UI pages
│   │       ├── components/      # Reusable components
│   │       ├── services/        # Business logic
│   │       ├── clients/         # API clients
│   │       ├── utils/           # Utility functions
│   │       └── types/           # Type definitions
│   ├── build.sh                 # Build script
│   └── deploy.sh                # Deploy script
├── server/                      # Go backend server
│   ├── main.go                  # Server entry
│   ├── handlers/                # API handlers
│   ├── models/                  # AI model adapters
│   ├── utils/                   # Server utilities
│   └── deploy/                  # Deployment scripts
└── docs/                        # Documentation
    ├── API-REFERENCE.md         # API documentation
    ├── ARCHITECTURE.md          # Architecture guide
    └── DEVELOPER-GUIDE.md       # This guide
```

### Key Architectural Patterns

**MVVM Pattern:**
- **Model**: Data structures and business logic
- **View**: UI components and layout
- **ViewModel**: State management and user interactions

**Service Layer:**
- **APIManager**: Central API orchestration
- **WebSocketService**: Real-time communication
- **Voice Services**: Speech recognition and synthesis

**Component Architecture:**
- **Page Components**: Main screens (Chat, Settings, etc.)
- **Reusable Components**: Modular UI elements
- **Utility Components**: Loading indicators, dialogs, etc.

### State Management

**ArkTS V2 State Variables:**
```typescript
// Local state (component-specific)
@Local private messages: ChatMessage[] = []

// Shared state (parent-child communication)
@Param @Watch('onModelChange') private currentModel: string

// Global state (application-wide)
@StorageProp('theme') private isDarkMode: boolean
```

**AppStorage for Persistence:**
```typescript
// Save data to persistent storage
await AppStorage.set('user_preferences', preferences)

// Load data from persistent storage
const preferences = await AppStorage.get('user_preferences')
```

## Customization and Extension

### Adding New AI Models

#### 1. Create New API Client

```typescript
// entry/src/main/ets/clients/NewModelClient.ets
export class NewModelClient extends BaseAPIClient {
  constructor(config: APIConfig) {
    super(config);
  }

  async sendChatRequest(request: ChatRequest): Promise<ChatResponse> {
    // Implement model-specific API call
  }

  protected getHeaders(): Map<string, string> {
    // Return model-specific headers
  }

  protected formatRequestBody(request: ChatRequest): string {
    // Format request for this model
  }

  protected parseResponse(responseData: string): ChatResponse {
    // Parse model-specific response
  }
}
```

#### 2. Register with APIManager

```typescript
// In APIManager.ets
private initializeClients(): void {
  this.clients.set('newmodel', new NewModelClient(config));
}
```

### Adding New UI Components

#### 1. Create Component

```typescript
// entry/src/main/ets/components/NewComponent.ets
@Component
export struct NewComponent {
  @Prop data: ComponentData
  @Prop onEvent: (event: ComponentEvent) => void

  build() {
    // Component UI implementation
  }

  private handleClick(): void {
    this.onEvent({ type: 'click', data: this.data });
  }
}
```

#### 2. Use Component in Page

```typescript
// In page component
NewComponent({
  data: this.componentData,
  onEvent: (event) => this.handleComponentEvent(event)
})
```

### Adding New Services

#### 1. Create Service Class

```typescript
// entry/src/main/ets/services/NewService.ets
export class NewService {
  private static instance: NewService;

  private constructor() {
    // Initialize service
  }

  static getInstance(): NewService {
    if (!NewService.instance) {
      NewService.instance = new NewService();
    }
    return NewService.instance;
  }

  async performOperation(input: OperationInput): Promise<OperationResult> {
    // Service implementation
  }
}
```

#### 2. Integrate with Application

```typescript
// In ViewModel or other services
private newService: NewService = NewService.getInstance();

async useService(): Promise<void> {
  const result = await this.newService.performOperation(input);
  // Handle result
}
```

## Integration Guide

### Third-Party Integration

#### API Integration

```typescript
// Example of integrating with external API
class ExternalAPIIntegration {
  private client: http.HttpClient;

  constructor(config: ExternalAPIConfig) {
    this.client = http.createHttp({
      baseUrl: config.baseUrl,
      timeout: config.timeout,
      headers: config.headers
    });
  }

  async callExternalAPI(request: ExternalRequest): Promise<ExternalResponse> {
    try {
      const response = await this.client.request({
        method: 'POST',
        url: '/endpoint',
        body: JSON.stringify(request),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.config.apiKey}`
        }
      });

      return JSON.parse(response.body);
    } catch (error) {
      Logger.error('ExternalAPI', 'API call failed', error);
      throw error;
    }
  }
}
```

#### Database Integration

```typescript
// Example of local database integration
class LocalDatabase {
  private database: relational.RdbStore;

  constructor() {
    this.initializeDatabase();
  }

  private async initializeDatabase(): Promise<void> {
    try {
      this.database = await data_rdb.getRdbStore({
        name: 'javis.db',
        securityLevel: data_rdb.SecurityLevel.S1
      });

      await this.database.executeSql(`
        CREATE TABLE IF NOT EXISTS sessions (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      `);
    } catch (error) {
      Logger.error('Database', 'Initialization failed', error);
    }
  }

  async saveSession(session: ChatSession): Promise<void> {
    try {
      const values = {
        id: session.id,
        title: session.title,
        created_at: session.createdAt,
        updated_at: session.updatedAt
      };

      await this.database.insert('sessions', values);
    } catch (error) {
      Logger.error('Database', 'Save session failed', error);
    }
  }
}
```

### Plugin Development

#### Creating Plugins

```typescript
// Example plugin structure
interface JavisPlugin {
  name: string;
  version: string;
  initialize(): Promise<void>;
  execute(input: any): Promise<any>;
  cleanup(): Promise<void>;
}

class ExamplePlugin implements JavisPlugin {
  name = 'example-plugin';
  version = '1.0.0';

  async initialize(): Promise<void> {
    // Plugin initialization
  }

  async execute(input: any): Promise<any> {
    // Plugin execution logic
    return { success: true, result: 'Plugin executed' };
  }

  async cleanup(): Promise<void> {
    // Plugin cleanup
  }
}
```

#### Plugin Registration

```typescript
// Plugin manager
class PluginManager {
  private plugins: Map<string, JavisPlugin> = new Map();

  registerPlugin(plugin: JavisPlugin): void {
    this.plugins.set(plugin.name, plugin);
  }

  async executePlugin(name: string, input: any): Promise<any> {
    const plugin = this.plugins.get(name);
    if (!plugin) {
      throw new Error(`Plugin ${name} not found`);
    }
    return await plugin.execute(input);
  }
}
```

## Deployment

### HarmonyOS App Deployment

#### Build for Production

```bash
# Build release version
./build.sh --release

# Sign the build (required for HarmonyOS)
# In DevEco Studio: Build > Generate Signed Bundle / APK

# Deploy to device
./deploy.sh
```

#### App Store Submission

1. **Prepare App Assets**
   ```bash
   # Generate app icons and screenshots
   # Create app store description
   # Prepare privacy policy and terms of service
   ```

2. **Upload to App Store**
   ```bash
   # Use HarmonyOS App Store console
   # Upload HAP file
   # Fill app metadata
   # Submit for review
   ```

### Backend Server Deployment

#### VPS Deployment

```bash
# Deploy to VPS
cd server
./dev-deploy.sh

# The script will:
# 1. Build the Go binary
# 2. Upload to VPS
# 3. Configure systemd service
# 4. Start the service
# 5. Set up reverse proxy (nginx)
```

#### Docker Deployment

```bash
# Build Docker image
docker build -t javis-server .

# Run container
docker run -d \
  --name javis-server \
  -p 8080:8080 \
  -v $(pwd)/config:/app/config \
  javis-server
```

#### Cloud Deployment

**AWS ECS:**
```bash
# Build and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
docker build -t javis-server .
docker tag javis-server:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/javis-server:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/javis-server:latest
```

**Google Cloud Run:**
```bash
# Deploy to Cloud Run
gcloud run deploy javis-server \
  --image gcr.io/your-project/javis-server \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

## Performance Optimization

### Client-Side Optimization

#### Memory Management

```typescript
// Implement proper cleanup
class OptimizedComponent {
  private disposables: Disposable[] = [];

  aboutToDisappear(): void {
    // Clean up resources
    this.disposables.forEach(disposable => disposable.dispose());
    this.disposables = [];
  }

  private addDisposable(disposable: Disposable): void {
    this.disposables.push(disposable);
  }
}
```

#### Rendering Optimization

```typescript
// Use lazy loading for large lists
LazyForEach({ data: this.largeDataset }, (item: DataType) => {
  ListItem() {
    // Item content
  }
}, (item: DataType) => item.id.toString())
```

### Server-Side Optimization

#### Connection Pooling

```go
// Implement connection pooling in Go server
type ConnectionPool struct {
    pool chan *sql.DB
}

func NewConnectionPool(maxSize int) *ConnectionPool {
    pool := make(chan *sql.DB, maxSize)
    for i := 0; i < maxSize; i++ {
        pool <- createDatabaseConnection()
    }
    return &ConnectionPool{pool: pool}
}

func (p *ConnectionPool) Get() *sql.DB {
    return <-p.pool
}

func (p *ConnectionPool) Put(conn *sql.DB) {
    p.pool <- conn
}
```

#### Caching Strategy

```go
// Implement Redis caching
type CacheService struct {
    client *redis.Client
}

func (c *CacheService) Set(key string, value interface{}, expiration time.Duration) error {
    return c.client.Set(ctx, key, value, expiration).Err()
}

func (c *CacheService) Get(key string) (string, error) {
    return c.client.Get(ctx, key).Result()
}
```

## Monitoring and Analytics

### Application Monitoring

#### Performance Monitoring

```typescript
// Implement performance monitoring
class PerformanceMonitor {
  private metrics: Map<string, MetricData> = new Map();

  startTiming(operation: string): string {
    const id = `${operation}_${Date.now()}`;
    this.metrics.set(id, {
      operation,
      startTime: Date.now(),
      metadata: {}
    });
    return id;
  }

  endTiming(id: string): void {
    const metric = this.metrics.get(id);
    if (metric) {
      metric.duration = Date.now() - metric.startTime;
      this.logMetric(metric);
      this.metrics.delete(id);
    }
  }
}
```

#### Error Tracking

```typescript
// Implement error tracking
class ErrorTracker {
  private errors: ErrorData[] = [];

  trackError(error: Error, context: ErrorContext): void {
    const errorData: ErrorData = {
      message: error.message,
      stack: error.stack,
      context: context,
      timestamp: Date.now(),
      userAgent: navigator.userAgent
    };

    this.errors.push(errorData);
    this.reportError(errorData);
  }

  private reportError(errorData: ErrorData): void {
    // Send to error tracking service
    Logger.error('ErrorTracker', JSON.stringify(errorData));
  }
}
```

### Server Monitoring

#### Health Checks

```go
// Implement health checks
func (s *Server) healthCheck(w http.ResponseWriter, r *http.Request) {
    health := struct {
        Status    string            `json:"status"`
        Timestamp time.Time         `json:"timestamp"`
        Checks    map[string]bool   `json:"checks"`
        Metrics   map[string]interface{} `json:"metrics"`
    }{
        Status:    "healthy",
        Timestamp: time.Now(),
        Checks:    make(map[string]bool),
        Metrics:   make(map[string]interface{}),
    }

    // Check database
    health.Checks["database"] = s.checkDatabase()

    // Check external APIs
    health.Checks["siliconflow"] = s.checkSiliconFlow()
    health.Checks["gemini"] = s.checkGemini()
    health.Checks["zhipu"] = s.checkZhipu()

    // Add metrics
    health.Metrics["uptime"] = time.Since(s.startTime).String()
    health.Metrics["requests"] = atomic.LoadInt64(&s.requestCount)
    health.Metrics["memory"] = s.getMemoryUsage()

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(health)
}
```

## Troubleshooting

### Common Issues

#### Build Issues

**Problem:** Build fails with missing dependencies
```bash
# Solution: Clean and rebuild
cd ohosllm
./build.sh --clean --debug

# Or in DevEco Studio:
# File > Invalidate Caches / Restart
# Then sync project again
```

**Problem:** API key authentication fails
```bash
# Solution: Verify API keys and configuration
# Check .env file
# Verify API keys are valid and not expired
# Check network connectivity
```

#### Runtime Issues

**Problem:** App crashes on startup
```typescript
// Solution: Check error logs and initialization
// Look for errors in Logger output
// Verify all required services are initialized
// Check for missing dependencies
```

**Problem:** Network requests fail
```typescript
// Solution: Enable debug logging and check network
Logger.setLogLevel(LogLevel.DEBUG);
// Check server URL and connectivity
// Verify API endpoints are accessible
```

### Debug Techniques

#### Logging

```typescript
// Use comprehensive logging
Logger.debug('Component', 'Initializing component', { component: 'ChatPage' });
Logger.info('API', 'Sending request', { url: request.url, method: request.method });
Logger.warn('Cache', 'Cache miss', { key: cacheKey });
Logger.error('Service', 'Operation failed', { error: error.message, stack: error.stack });
```

#### Breakpoint Debugging

```typescript
// Set strategic breakpoints
// 1. Service initialization
// 2. API request/response handling
// 3. State changes
// 4. User interaction handlers
// 5. Error handling code
```

#### Performance Profiling

```typescript
// Profile critical operations
const startId = Logger.startPerformanceMonitoring('ChatService', 'sendRequest', request.model);
// ... operation ...
Logger.endPerformanceMonitoring(startId);
```

## Best Practices

### Code Quality

#### TypeScript/ArkTS Best Practices

```typescript
// Use strict typing
interface UserMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: number;
  metadata?: Record<string, unknown>;
}

// Avoid any type
function processMessage(message: UserMessage): void {
  // Type-safe processing
}
```

#### Error Handling

```typescript
// Implement comprehensive error handling
class ErrorHandler {
  static handle(error: unknown, context: string): void {
    if (error instanceof NetworkError) {
      // Handle network errors
    } else if (error instanceof ValidationError) {
      // Handle validation errors
    } else {
      // Handle unexpected errors
      Logger.error(context, 'Unexpected error', error);
    }
  }
}
```

### Performance Best Practices

#### Memory Management

```typescript
// Implement proper cleanup
class ResourceHandler {
  private resources: Resource[] = [];

  addResource(resource: Resource): void {
    this.resources.push(resource);
  }

  cleanup(): void {
    this.resources.forEach(resource => resource.dispose());
    this.resources = [];
  }
}
```

#### Network Optimization

```typescript
// Implement request optimization
class OptimizedAPIClient {
  private cache: Map<string, CachedResponse> = new Map();
  private pendingRequests: Map<string, Promise<Response>> = new Map();

  async request(url: string): Promise<Response> {
    // Check cache
    const cached = this.cache.get(url);
    if (cached && !this.isExpired(cached)) {
      return cached.data;
    }

    // Check for pending request
    const pending = this.pendingRequests.get(url);
    if (pending) {
      return pending;
    }

    // Make new request
    const request = this.makeRequest(url);
    this.pendingRequests.set(url, request);

    try {
      const response = await request;
      this.cacheResponse(url, response);
      return response;
    } finally {
      this.pendingRequests.delete(url);
    }
  }
}
```

## Community and Support

### Getting Help

**Documentation:**
- API Reference: `docs/API-REFERENCE.md`
- Architecture Guide: `docs/ARCHITECTURE.md`
- Component Documentation: `docs/COMPONENTS.md`

**Community Resources:**
- GitHub Issues: Report bugs and request features
- Discussions: Ask questions and share ideas
- Wiki: Community-contributed documentation

### Contributing

#### Development Workflow

1. **Fork the Repository**
2. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Changes**
4. **Add Tests**
5. **Update Documentation**
6. **Submit Pull Request**

#### Code Standards

- Follow existing code style and patterns
- Use TypeScript/ArkTS strict mode
- Add comprehensive documentation
- Include unit tests for new features
- Ensure all tests pass before submitting

## Conclusion

This guide provides a comprehensive foundation for developing with and extending the Javis platform. By following these guidelines, you'll be able to:

- Set up a complete development environment
- Understand the architecture and design patterns
- Customize and extend the platform
- Integrate with third-party services
- Deploy and monitor applications
- Troubleshoot common issues

For additional information, refer to the other documentation files in the `docs/` directory or reach out to the development community through GitHub Issues and Discussions.

Happy coding! 🚀