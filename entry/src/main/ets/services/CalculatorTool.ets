import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  JSONSchema,
  ParamType
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';

interface CalculatorJSONSchema extends JSONSchema {
  type: string;
  required: Array<string>;
}

/**
 * 计算器工具类
 * 提供基本的数学运算功能
 */
export class CalculatorTool {
  private static instance: CalculatorTool | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): CalculatorTool {
    if (!CalculatorTool.instance) {
      CalculatorTool.instance = new CalculatorTool();
    }
    return CalculatorTool.instance;
  }

  /**
   * 获取计算器工具定义
   */
  getToolDefinition(): MCPTool {
    const operationSchema: JSONSchema = {
      type: 'string',
      description: '运算类型：add(加), subtract(减), multiply(乘), divide(除), power(幂), sqrt(开方), percent(百分比)',
      enum: ['add', 'subtract', 'multiply', 'divide', 'power', 'sqrt', 'percent']
    };

    const aSchema: JSONSchema = {
      type: 'number',
      description: '第一个数字'
    };

    const bSchema: JSONSchema = {
      type: 'number',
      description: '第二个数字（开方运算不需要）'
    };

    const properties: Record<string, JSONSchema> = {} as Record<string, JSONSchema>;
    properties.operation = operationSchema;
    properties.a = aSchema;
    properties.b = bSchema;

    const schema: CalculatorJSONSchema = {
      type: 'object',
      properties: properties,
      required: ['operation', 'a']
    };

    const toolDefinition: MCPTool = {
      name: 'calculator',
      description: '基本数学计算器，支持加减乘除等运算',
      inputSchema: schema
    };
    return toolDefinition;
  }

  /**
   * 执行计算器运算
   */
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

  /**
   * 格式化数字，避免过长小数
   */
  private formatNumber(num: number): string {
    if (Number.isInteger(num)) {
      return num.toString();
    }

    // 限制小数点后最多10位
    const rounded = Math.round(num * 1e10) / 1e10;

    // 移除末尾的零
    return rounded.toString().replace(/\.?0+$/, '');
  }
}

export default CalculatorTool;