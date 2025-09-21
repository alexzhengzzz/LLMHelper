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

### 5. UI 组件范式

#### 5.1 动态参数表单

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

#### 5.2 枚举选择器

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

目前项目仅实现了计算器工具，作为 MCP 协议的示范实现。

### 已实现工具

**CalculatorTool** (`calculator`)
- 支持基本数学运算：加、减、乘、除、幂、开方、百分比
- 完整的参数验证和错误处理
- 支持浮点数精度处理
- 单例模式实现，确保资源高效利用

### 工具架构验证

计算器工具完整验证了以下架构设计：

1. **类型系统**: MCPTypes.ets 中的完整类型定义
2. **工具管理**: LocalToolManager.ets 的注册和执行机制
3. **UI组件**: MCPToolsComponent.ets 的动态表单生成
4. **错误处理**: 统一的错误响应格式
5. **JSON Schema**: 参数定义和验证机制

### 扩展指导

基于计算器工具的实现模式，可以按照相同的架构添加新的工具：

1. 继承 `LocalToolExecutor` 接口
2. 实现单例模式的工具类
3. 定义 JSON Schema 参数结构
4. 在 `LocalToolManager` 中注册工具
5. UI 组件会自动支持新工具的参数表单生成

## 总结

我们的 MCP 实现特点：

1. **本地执行**: 不依赖外部 MCP 服务器，工具直接在应用内执行
2. **类型安全**: 完整的 TypeScript 类型定义
3. **插件化**: 易于扩展新工具
4. **UI 自动生成**: 根据 JSON Schema 自动生成参数表单
5. **错误处理**: 统一的错误处理机制
6. **单例模式**: 工具类使用单例模式确保资源高效利用

这种实现方式适合鸿蒙应用场景，提供了高效的本地工具执行能力。