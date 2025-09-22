/**
 * AI服务状态管理类型定义
 * 遵循ArkTS V2严格类型规范
 */

/**
 * AI服务模式枚举
 */
export enum AIServiceMode {
  DIRECT = 0,        // 直连模式
  SERVER_PROXY = 1   // 服务器代理模式
}

/**
 * AI服务功能开关状态
 */
export interface AIServiceFeatures {
  enableWebSearch: boolean;     // 联网搜索开关
  enableDeepThinking: boolean;  // 深度思考开关
  enableMCPTools: boolean;      // MCP工具调用开关
  mcpToolsConfig?: MCPServiceFeatures; // MCP工具详细配置
}

/**
 * MCP服务功能配置
 */
export interface MCPServiceFeatures {
  globalEnabled: boolean;              // 全局MCP开关
  enabledTools: Record<string, boolean>; // 工具启用状态映射
  toolUsageTracking: boolean;         // 工具使用统计开关
  toolConfigVersion: number;          // 配置版本号
}

/**
 * AI服务完整状态
 */
export interface AIServiceState {
  mode: AIServiceMode;          // 当前API模式
  features: AIServiceFeatures;  // 功能开关状态
  lastUpdated: number;          // 最后更新时间戳
}

/**
 * 状态验证结果
 */
export interface StateValidationResult {
  isValid: boolean;             // 状态是否有效
  errorMessage: string | null;  // 错误信息（如果无效）
  supportedFeatures: AIServiceFeatures; // 当前模式支持的功能
}

/**
 * 状态变更事件
 */
export interface StateChangeEvent {
  previousState: AIServiceState;
  newState: AIServiceState;
  timestamp: number;
}

/**
 * 状态变更监听器类型
 */
export type StateChangeListener = (event: StateChangeEvent) => void;

/**
 * 预定义的状态组合
 */
export class StatePresets {
  // 基础直连模式 - 所有功能关闭
  static readonly BASIC_DIRECT: AIServiceState = {
    mode: AIServiceMode.DIRECT,
    features: {
      enableWebSearch: false,
      enableDeepThinking: false,
      enableMCPTools: true
    },
    lastUpdated: 0
  };

  // 高级直连模式 - 启用联网搜索和工具
  static readonly ADVANCED_DIRECT: AIServiceState = {
    mode: AIServiceMode.DIRECT,
    features: {
      enableWebSearch: true,
      enableDeepThinking: false,
      enableMCPTools: true
    },
    lastUpdated: 0
  };

  // 专家直连模式 - 所有功能启用
  static readonly EXPERT_DIRECT: AIServiceState = {
    mode: AIServiceMode.DIRECT,
    features: {
      enableWebSearch: true,
      enableDeepThinking: true,
      enableMCPTools: true
    },
    lastUpdated: 0
  };

  // 基础服务器代理模式 - 仅基础功能
  static readonly BASIC_SERVER: AIServiceState = {
    mode: AIServiceMode.SERVER_PROXY,
    features: {
      enableWebSearch: false,
      enableDeepThinking: false,
      enableMCPTools: false
    },
    lastUpdated: 0
  };

  // 服务器代理联网模式 - 仅启用联网搜索
  static readonly SERVER_WITH_SEARCH: AIServiceState = {
    mode: AIServiceMode.SERVER_PROXY,
    features: {
      enableWebSearch: true,
      enableDeepThinking: false,
      enableMCPTools: false
    },
    lastUpdated: 0
  };
}

/**
 * 状态编码工具类 - 使用位运算进行高效状态管理
 */
export class StateEncoder {
  // 状态位定义
  private static readonly MODE_BIT = 0b1000;        // 模式位
  private static readonly WEB_SEARCH_BIT = 0b0100;  // 联网搜索位
  private static readonly DEEP_THINKING_BIT = 0b0010; // 深度思考位
  private static readonly MCP_TOOLS_BIT = 0b0001;   // MCP工具位

  /**
   * 将状态对象编码为4位二进制数字
   */
  static encodeState(state: AIServiceState): number {
    let encoded = 0;

    if (state.mode === AIServiceMode.SERVER_PROXY) {
      encoded |= StateEncoder.MODE_BIT;
    }

    if (state.features.enableWebSearch) {
      encoded |= StateEncoder.WEB_SEARCH_BIT;
    }

    if (state.features.enableDeepThinking) {
      encoded |= StateEncoder.DEEP_THINKING_BIT;
    }

    if (state.features.enableMCPTools) {
      encoded |= StateEncoder.MCP_TOOLS_BIT;
    }

    return encoded;
  }

  /**
   * 将4位二进制数字解码为状态对象
   */
  static decodeState(encoded: number): AIServiceState {
    const mode = (encoded & StateEncoder.MODE_BIT) ?
      AIServiceMode.SERVER_PROXY : AIServiceMode.DIRECT;

    const features: AIServiceFeatures = {
      enableWebSearch: Boolean(encoded & StateEncoder.WEB_SEARCH_BIT),
      enableDeepThinking: Boolean(encoded & StateEncoder.DEEP_THINKING_BIT),
      enableMCPTools: Boolean(encoded & StateEncoder.MCP_TOOLS_BIT)
    };

    return {
      mode,
      features,
      lastUpdated: Date.now()
    };
  }

  /**
   * 获取状态的字符串表示
   */
  static getStateString(state: AIServiceState): string {
    const encoded = StateEncoder.encodeState(state);
    return encoded.toString(2).padStart(4, '0');
  }
}