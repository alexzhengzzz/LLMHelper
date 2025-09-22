# MCP (Model Context Protocol) 开发范式

## 概述

本项目实现了基于 JSON-RPC 2.0 的 MCP 协议支持，重点在于**本地工具执行器**的实现。与标准 MCP 不同，我们的实现专注于在鸿蒙应用内直接执行工具，而不是通过外部 MCP 服务器。

## 架构设计

### 核心组件

1. **类型系统** (`MCPTypes.ets`)
   - 完整的 MCP 协议类型定义
   - JSON-RPC 2.0 消息格式
   - 工具、资源、提示词的数据结构

2. **本地工具管理器** (`LocalToolManager.ets`)
   - 本地工具注册和执行
   - 单例模式管理
   - 统一的错误处理

3. **UI 组件** (`MCPToolsComponent.ets`)
   - 工具可视化界面
   - 参数动态表单生成
   - 实时执行反馈

## 开发范式

### 1. 工具开发范式

基于已实现的 `CalculatorTool`，我们的开发范式如下：

#### 1.1 工具类结构

```typescript
export class CalculatorTool {
  private static instance: CalculatorTool | null = null;

  private constructor() {}

  // 单例模式获取实例
  static getInstance(): CalculatorTool {
    if (!CalculatorTool.instance) {
      CalculatorTool.instance = new CalculatorTool();
    }
    return CalculatorTool.instance;
  }

  // 获取工具定义
  getToolDefinition(): MCPTool {
    const schema: JSONSchema = {
      type: 'object',
      properties: {
        operation: {
          type: 'string',
          description: '运算类型：add(加), subtract(减), multiply(乘), divide(除), power(幂), sqrt(开方), percent(百分比)',
          enum: ['add', 'subtract', 'multiply', 'divide', 'power', 'sqrt', 'percent']
        },
        a: {
          type: 'number',
          description: '第一个数字'
        },
        b: {
          type: 'number',
          description: '第二个数字（开方运算不需要）'
        }
      },
      required: ['operation', 'a']
    };

    return {
      name: 'calculator',
      description: '基本数学计算器，支持加减乘除等运算',
      inputSchema: schema
    };
  }
}
```

#### 1.2 工具执行逻辑

```typescript
async execute(request: ToolCallRequest): Promise<ToolCallResult> {
  try {
    const args = request.arguments as ParamType;
    const operation = args.operation as string;
    const a = args.a as number;
    const b = args.b as number;

    Logger.info('CalculatorTool', `Executing calculation: ${operation}`, JSON.stringify({ a, b }));

    let result: number;
    let description: string;

    switch (operation) {
      case 'add':
        if (b === undefined) {
          throw new Error('加法运算需要两个数字');
        }
        result = a + b;
        description = `${a} + ${b} = ${result}`;
        break;

      case 'subtract':
        if (b === undefined) {
          throw new Error('减法运算需要两个数字');
        }
        result = a - b;
        description = `${a} - ${b} = ${result}`;
        break;

      case 'multiply':
        if (b === undefined) {
          throw new Error('乘法运算需要两个数字');
        }
        result = a * b;
        description = `${a} × ${b} = ${result}`;
        break;

      case 'divide':
        if (b === undefined) {
          throw new Error('除法运算需要两个数字');
        }
        if (b === 0) {
          throw new Error('除数不能为零');
        }
        result = a / b;
        description = `${a} ÷ ${b} = ${result}`;
        break;

      case 'power':
        if (b === undefined) {
          throw new Error('幂运算需要两个数字');
        }
        result = Math.pow(a, b);
        description = `${a}^${b} = ${result}`;
        break;

      case 'sqrt':
        if (a < 0) {
          throw new Error('不能对负数开方');
        }
        result = Math.sqrt(a);
        description = `√${a} = ${result}`;
        break;

      case 'percent':
        if (b === undefined) {
          throw new Error('百分比运算需要两个数字');
        }
        result = (a / b) * 100;
        description = `${a} 是 ${b} 的 ${result.toFixed(2)}%`;
        break;

      default:
        throw new Error(`不支持的运算类型: ${operation}`);
    }

    // 格式化结果，避免过长小数
    const formattedResult = this.formatNumber(result);

    const successResult: ToolCallResult = {
      content: [{
        type: 'text',
        text: `计算结果：${description}\n精确值：${formattedResult}`
      }]
    };
    return successResult;

  } catch (error) {
    Logger.error('CalculatorTool', 'Calculation failed', error);
    const errorResult: ToolCallResult = {
      content: [{
        type: 'text',
        text: `计算失败：${error instanceof Error ? error.message : '未知错误'}`
      }],
      isError: true
    };
    return errorResult;
  }
}
```

#### 1.3 工具注册模式

在 `LocalToolManager` 中：

```typescript
/**
 * 本地工具执行器接口
 */
interface LocalToolExecutor {
  execute(request: ToolCallRequest): Promise<ToolCallResult>;
}

/**
 * 计算器工具执行器
 */
class CalculatorToolExecutor implements LocalToolExecutor {
  private calculatorTool: CalculatorTool;

  constructor(calculatorTool: CalculatorTool) {
    this.calculatorTool = calculatorTool;
  }

  async execute(request: ToolCallRequest): Promise<ToolCallResult> {
    return this.calculatorTool.execute(request);
  }
}

/**
 * 注册计算器工具
 */
private registerCalculatorTool(): void {
  const calculatorTool = CalculatorTool.getInstance();
  const toolDefinition = calculatorTool.getToolDefinition();

  this.registeredTools.set(toolDefinition.name, toolDefinition);
  const executor: LocalToolExecutor = new CalculatorToolExecutor(calculatorTool);
  this.toolExecutors.set(toolDefinition.name, executor);

  Logger.info('LocalToolManager', `Calculator tool registered: ${toolDefinition.name}`);
}
```

### 2. JSON Schema 设计范式

基于 `CalculatorTool` 的实际实现：

#### 2.1 枚举类型参数

```typescript
const operationSchema: JSONSchema = {
  type: 'string',
  description: '运算类型：add(加), subtract(减), multiply(乘), divide(除), power(幂), sqrt(开方), percent(百分比)',
  enum: ['add', 'subtract', 'multiply', 'divide', 'power', 'sqrt', 'percent']
};
```

#### 2.2 数字类型参数

```typescript
const aSchema: JSONSchema = {
  type: 'number',
  description: '第一个数字'
};

const bSchema: JSONSchema = {
  type: 'number',
  description: '第二个数字（开方运算不需要）'
};
```

#### 2.3 组合参数结构

```typescript
const properties: Record<string, JSONSchema> = {} as Record<string, JSONSchema>;
properties.operation = operationSchema;
properties.a = aSchema;
properties.b = bSchema;

const schema: CalculatorJSONSchema = {
  type: 'object',
  properties: properties,
  required: ['operation', 'a']  // b 参数在开方运算时不是必需的
};
```

### 3. 错误处理范式

#### 3.1 参数验证

```typescript
switch (operation) {
  case 'add':
    if (b === undefined) {
      throw new Error('加法运算需要两个数字');
    }
    result = a + b;
    break;

  case 'divide':
    if (b === undefined) {
      throw new Error('除法运算需要两个数字');
    }
    if (b === 0) {
      throw new Error('除数不能为零');
    }
    result = a / b;
    break;
}
```

#### 3.2 标准错误响应

```typescript
catch (error) {
  Logger.error('CalculatorTool', 'Calculation failed', error);
  const errorResult: ToolCallResult = {
    content: [{
      type: 'text',
      text: `计算失败：${error instanceof Error ? error.message : '未知错误'}`
    }],
    isError: true
  };
  return errorResult;
}
```

### 4. 工具管理范式

#### 4.1 工具获取

```typescript
/**
 * 获取所有可用工具
 */
getAvailableTools(): Array<MCPTool> {
  return Array.from(this.registeredTools.values());
}

/**
 * 根据名称获取工具
 */
getTool(name: string): MCPTool | undefined {
  return this.registeredTools.get(name);
}

/**
 * 检查工具是否存在
 */
hasTool(name: string): boolean {
  return this.registeredTools.has(name);
}
```

#### 4.2 工具执行

```typescript
/**
 * 执行工具调用
 */
async executeTool(request: ToolCallRequest): Promise<ToolCallResult> {
  const executor = this.toolExecutors.get(request.name);
  if (!executor) {
    const notFoundResult: ToolCallResult = {
      content: [{
        type: 'text',
        text: `工具不存在: ${request.name}`
      }],
      isError: true
    };
    return notFoundResult;
  }

  Logger.info('LocalToolManager', `Executing local tool: ${request.name}`, JSON.stringify(request.arguments));

  try {
    const result = await executor.execute(request);
    Logger.debug('LocalToolManager', `Tool executed successfully: ${request.name}`);
    return result;
  } catch (error) {
    Logger.error('LocalToolManager', `Tool execution failed: ${request.name}`, error);
    const errorResult: ToolCallResult = {
      content: [{
        type: 'text',
        text: `工具执行失败: ${error instanceof Error ? error.message : '未知错误'}`
      }],
      isError: true
    };
    return errorResult;
  }
}
```

### 5. 复杂工具开发范式 (基于AppLauncherTool)

AppLauncherTool展示了如何实现需要系统权限和上下文依赖的复杂工具。

#### 5.1 上下文依赖的单例模式

```typescript
export class AppLauncherTool {
  private static instance: AppLauncherTool | null = null;
  private context: common.UIAbilityContext;
  private permissionManager: abilityAccessCtrl.AtManager;

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.permissionManager = abilityAccessCtrl.createAtManager();
  }

  /**
   * 需要上下文的单例实现
   */
  static getInstance(context: common.UIAbilityContext): AppLauncherTool {
    if (!AppLauncherTool.instance) {
      AppLauncherTool.instance = new AppLauncherTool(context);
    }
    return AppLauncherTool.instance;
  }
}
```

#### 5.2 复杂JSON Schema设计

```typescript
getToolDefinition(): MCPTool {
  const bundleNameSchema: JSONSchema = {
    type: 'string',
    description: '应用包名，例如：com.huawei.hms.app',
    pattern: '^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z][a-zA-Z0-9_]*)+$',
    minLength: 1,
    maxLength: 255
  };

  const abilityNameSchema: JSONSchema = {
    type: 'string',
    description: 'Ability名称，可选参数，例如：MainAbility',
    pattern: '^[a-zA-Z][a-zA-Z0-9_]*$',
    minLength: 1,
    maxLength: 100
  };

  const parametersSchema: JSONSchema = {
    type: 'object',
    description: '启动参数，可选参数，例如：{"action": "view", "data": "https://example.com"}'
  };

  return {
    name: 'app_launcher',
    description: '通过包名启动其他鸿蒙应用，支持传递启动参数',
    inputSchema: {
      type: 'object',
      properties: { bundleName: bundleNameSchema, abilityName: abilityNameSchema, parameters: parametersSchema },
      required: ['bundleName']
    }
  };
}
```

#### 5.3 分层验证体系

```typescript
async execute(request: ToolCallRequest): Promise<ToolCallResult> {
  try {
    const launchParams: AppLaunchParameters = { /* 解析参数 */ };

    // 第一层：参数验证
    const validationResult = this.validateParameters(launchParams);
    if (!validationResult.isValid) {
      return this.createErrorResult(`参数验证失败: ${validationResult.error}`);
    }

    // 第二层：权限检查
    const permissionCheck = await this.checkPermissions();
    if (!permissionCheck.hasPermissions) {
      return this.createErrorResult(`权限检查失败: ${permissionCheck.error}`);
    }

    // 第三层：应用存在性检查
    const appCheck = await this.checkAppExists(launchParams.bundleName);
    if (!appCheck.exists) {
      return this.createErrorResult(`应用不存在: ${launchParams.bundleName}`);
    }

    // 第四层：执行操作
    const launchResult = await this.launchApplication(launchParams);
    return this.processLaunchResult(launchResult, launchParams);

  } catch (error) {
    return this.createErrorResult(`应用启动失败: ${error instanceof Error ? error.message : '未知错误'}`);
  }
}
```

#### 5.4 专用验证方法

```typescript
private validateParameters(params: AppLaunchParameters): AppLaunchValidationResult {
  // 必填参数验证
  if (!params.bundleName || typeof params.bundleName !== 'string') {
    return { isValid: false, error: 'bundleName参数缺失或类型错误' };
  }

  // 格式验证（正则表达式）
  const bundleNamePattern = /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/;
  if (!bundleNamePattern.test(params.bundleName)) {
    return { isValid: false, error: 'bundleName格式错误，应为有效的包名格式' };
  }

  // 可选参数验证
  if (params.abilityName) {
    const abilityNamePattern = /^[a-zA-Z][a-zA-Z0-9_]*$/;
    if (!abilityNamePattern.test(params.abilityName)) {
      return { isValid: false, error: 'abilityName格式错误' };
    }
  }

  return { isValid: true };
}
```

#### 5.5 系统API权限处理

```typescript
private async checkPermissions(): Promise<AppLaunchPermissionCheck> {
  try {
    const requiredPermissions = [
      AppLaunchPermission.START_ABILITIES_FROM_BACKGROUND,
      AppLaunchPermission.GET_BUNDLE_INFO
    ];

    for (const permission of requiredPermissions) {
      const status = await this.permissionManager.checkAccessTokenSync(
        this.context.applicationInfo.accessTokenId,
        permission
      );
      if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        Logger.warn('AppLauncherTool', `Permission not granted: ${permission}`);
      }
    }

    return { hasPermissions: true };
  } catch (error) {
    return { hasPermissions: false, error: error instanceof Error ? error.message : '权限检查失败' };
  }
}
```

#### 5.6 错误分类处理

```typescript
private async launchApplication(params: AppLaunchParameters): Promise<AppLaunchExecutionResult> {
  try {
    const want: Want = {
      bundleName: params.bundleName,
      abilityName: params.abilityName,
      parameters: params.parameters
    };

    // 清理undefined属性
    const cleanWant: Want = { bundleName: want.bundleName };
    if (want.abilityName !== undefined) cleanWant.abilityName = want.abilityName;
    if (want.parameters !== undefined) cleanWant.parameters = want.parameters;

    await this.context.startAbility(cleanWant);
    return { result: AppLaunchResult.SUCCESS };

  } catch (error) {
    let errorType = AppLaunchResult.LAUNCH_FAILED;
    let errorMessage = error instanceof Error ? error.message : '启动失败';

    // 错误分类
    if (errorMessage.includes('permission')) {
      errorType = AppLaunchResult.PERMISSION_DENIED;
      errorMessage = '缺少必要权限，无法启动应用';
    } else if (errorMessage.includes('not found')) {
      errorType = AppLaunchResult.APP_NOT_FOUND;
      errorMessage = '应用未找到，请检查包名是否正确';
    }

    return { result: errorType, error: errorMessage };
  }
}
```

### 6. UI 组件范式

#### 6.1 动态参数表单

```typescript
@Builder
buildParameterInput(paramName: string, schema: JSONSchema | undefined) {
  if (schema) {
    Column({ space: 8 }) {
      Row() {
        Text(paramName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))

        if (this.selectedTool?.inputSchema.required?.includes(paramName)) {
          Text(' *')
            .fontSize(14)
            .fontColor('#F44336')
        }

        Blank()

        if (schema.description) {
          Text(schema.description)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')

      if (schema.type === 'string' && schema.enum) {
        // 枚举选择
        this.buildEnumSelector(paramName, schema.enum as Array<string>);
      } else if (schema.type === 'boolean') {
        // 布尔开关
        this.buildBooleanToggle(paramName);
      } else if (schema.type === 'number') {
        // 数字输入
        this.buildNumberInput(paramName, schema);
      } else {
        // 文本输入
        this.buildTextInput(paramName, schema);
      }
    }
    .width('100%')
  }
}
```

#### 6.2 枚举选择器

```typescript
@Builder
buildEnumSelector(paramName: string, options: Array<string>) {
  Row({ space: 8 }) {
    ForEach(options, (option: string) => {
      Button(option)
        .type(ButtonType.Normal)
        .backgroundColor(this.toolParams[paramName] === option ?
          $r('app.color.primary_color') : Color.Transparent)
        .fontColor(this.toolParams[paramName] === option ?
          Color.White : $r('app.color.text_secondary'))
        .borderWidth(1)
        .borderColor(this.toolParams[paramName] === option ?
          $r('app.color.primary_color') : $r('app.color.border_color'))
        .borderRadius(6)
        .fontSize(12)
        .height(32)
        .onClick(() => {
          this.toolParams[paramName] = option;
        })
    });
  }
  .width('100%')
}
```

## 当前实现状态

项目已实现两个完整的MCP工具，作为不同类型的示范实现。

### 已实现工具

**CalculatorTool** (`calculator`)
- **功能**: 支持基本数学运算：加、减、乘、除、幂、开方、百分比
- **特点**: 完整的参数验证和错误处理，支持浮点数精度处理
- **架构**: 单例模式实现，确保资源高效利用
- **复杂度**: 简单工具示例，无依赖外部API或权限

**AppLauncherTool** (`app_launcher`)
- **功能**: 通过包名启动其他鸿蒙应用，支持传递启动参数
- **特点**: 权限检查、应用存在性验证、复杂参数处理
- **架构**: 单例模式+上下文依赖，需要UIAbilityContext支持
- **复杂度**: 复杂工具示例，涉及系统权限和应用间通信

### 工具架构验证

两个工具完整验证了以下架构设计：

1. **类型系统**: MCPTypes.ets 中的完整类型定义
2. **工具管理**: LocalToolManager.ets 的注册和执行机制
3. **UI组件**: MCPToolsComponent.ets 的动态表单生成
4. **错误处理**: 统一的错误响应格式
5. **JSON Schema**: 参数定义和验证机制
6. **权限管理**: 复杂工具的权限检查和处理
7. **上下文依赖**: 需要系统资源的工具实现模式

### 扩展指导

基于已实现工具的模式，可以按照相同的架构添加新的工具：

**简单工具扩展** (参考CalculatorTool):
1. 继承 `LocalToolExecutor` 接口
2. 实现单例模式的工具类
3. 定义 JSON Schema 参数结构
4. 在 `LocalToolManager` 中注册工具
5. UI 组件会自动支持新工具的参数表单生成

**复杂工具扩展** (参考AppLauncherTool):
1. 实现带上下文依赖的单例模式
2. 添加权限检查和验证逻辑
3. 实现复杂的参数验证机制
4. 处理异步操作和错误分类
5. 支持系统级API调用

### 7. ArkTS严格类型要求

#### 7.1 类型定义的严格性

ArkTS对MCP工具的类型要求极其严格，必须为所有接口和参数提供详细的类型定义：

```typescript
// 扩展的JSON Schema接口，必须明确指定所有属性类型
interface CalculatorJSONSchema extends JSONSchema {
  type: string;
  required: Array<string>;
}

interface AppLauncherToolJSONSchema extends JSONSchema {
  type: string;
  properties: Record<string, JSONSchema>;
  required: Array<string>;
}

// 验证结果接口，每个可能的返回值都需要明确类型
interface AppLaunchValidationResult {
  isValid: boolean;
  error?: string;
}

interface AppLaunchPermissionCheck {
  hasPermissions: boolean;
  error?: string;
}
```

#### 7.2 参数类型转换

在处理工具参数时，必须进行严格的类型转换和验证：

```typescript
async execute(request: ToolCallRequest): Promise<ToolCallResult> {
  const args = request.arguments as ParamType;

  // 严格类型转换，确保类型安全
  const operation = args.operation as string;
  const a = args.a as number;
  const b = args.b as number;

  // 或者对于复杂对象
  const launchParams: AppLaunchParameters = {
    bundleName: args.bundleName as string,
    abilityName: args.abilityName as string,
    parameters: args.parameters as Record<string, string | number | boolean>
  };
}
```

#### 7.3 Schema属性构建

JSON Schema的构建必须使用明确的类型声明，避免类型推断：

```typescript
getToolDefinition(): MCPTool {
  // 每个schema都需要明确的类型声明
  const operationSchema: JSONSchema = {
    type: 'string',
    description: '运算类型：add(加), subtract(减), multiply(乘), divide(除), power(幂), sqrt(开方), percent(百分比)',
    enum: ['add', 'subtract', 'multiply', 'divide', 'power', 'sqrt', 'percent']
  };

  // 使用Record类型确保类型安全
  const properties: Record<string, JSONSchema> = {} as Record<string, JSONSchema>;
  properties.operation = operationSchema;
  properties.a = aSchema;
  properties.b = bSchema;

  // 最终schema需要明确的接口类型
  const schema: CalculatorJSONSchema = {
    type: 'object',
    properties: properties,
    required: ['operation', 'a']
  };
}
```

#### 7.4 错误处理类型规范

所有错误处理都必须遵循严格的类型定义：

```typescript
// 错误结果必须符合ToolCallResult类型
const errorResult: ToolCallResult = {
  content: [{
    type: 'text',
    text: `计算失败：${error instanceof Error ? error.message : '未知错误'}`
  }],
  isError: true
};

// 成功结果同样需要明确类型
const successResult: ToolCallResult = {
  content: [{
    type: 'text',
    text: `计算结果：${description}\n精确值：${formattedResult}`
  }]
};
```

#### 7.5 接口实现规范

工具执行器必须严格实现LocalToolExecutor接口：

```typescript
/**
 * 本地工具执行器接口
 */
interface LocalToolExecutor {
  execute(request: ToolCallRequest): Promise<ToolCallResult>;
}

/**
 * 计算器工具执行器 - 必须明确实现接口
 */
class CalculatorToolExecutor implements LocalToolExecutor {
  private calculatorTool: CalculatorTool;

  constructor(calculatorTool: CalculatorTool) {
    this.calculatorTool = calculatorTool;
  }

  // 必须严格按照接口签名实现
  async execute(request: ToolCallRequest): Promise<ToolCallResult> {
    return this.calculatorTool.execute(request);
  }
}
```

## 总结

我们的 MCP 实现特点：

1. **本地执行**: 不依赖外部 MCP 服务器，工具直接在应用内执行
2. **严格类型安全**: 完整的 TypeScript 类型定义，100%符合ArkTS严格模式
3. **插件化**: 易于扩展新工具，支持简单和复杂工具两种模式
4. **UI 自动生成**: 根据 JSON Schema 自动生成参数表单
5. **统一错误处理**: 分层验证和错误分类处理机制
6. **单例模式**: 工具类使用单例模式确保资源高效利用
7. **权限管理**: 支持系统级权限检查和上下文依赖

**ArkTS特殊要求**:
- 禁用any、unknown、ESObject类型
- 所有接口必须明确类型定义
- 参数转换必须使用严格的类型断言
- JSON Schema构建需要详细的类型声明
- 100%类型安全，无类型推断依赖

这种实现方式完全适合鸿蒙应用场景，提供了高效且类型安全的本地工具执行能力。