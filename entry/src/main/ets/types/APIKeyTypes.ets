/**
 * API密钥管理相关类型定义
 */

import { AIProvider } from '../types/APITypes';

/**
 * 单个厂商的API密钥配置
 */
export interface APIKeyConfig {
  provider: AIProvider;
  displayName: string;
  description: string;
  apiKey: string;
  baseUrl: string;
  enabled: boolean;
  lastTestTime?: number;
  lastTestResult?: boolean;
  testError?: string;
}

/**
 * API密钥管理状态
 */
export interface APIKeyManagerState {
  configs: Map<AIProvider, APIKeyConfig>;
  isInitialized: boolean;
  testingProvider: AIProvider | null;
}

/**
 * API密钥存储数据结构
 */
export type APIKeyStorageData = Record<string, APIKeyConfig>;

/**
 * 连接测试结果
 */
export interface ConnectionTestResult {
  provider: AIProvider;
  success: boolean;
  error?: string;
  responseTime?: number;
}

/**
 * API密钥验证结果
 */
export interface APIKeyValidationResult {
  isValid: boolean;
  error?: string;
  suggestions?: string[];
}

/**
 * 厂商信息
 */
export interface ProviderInfo {
  provider: AIProvider;
  name: string;
  description: string;
  website: string;
  keyFormat: string;
  keyExample: string;
  documentation: string;
}

/**
 * 支持的厂商信息
 */
export const SUPPORTED_PROVIDERS: ProviderInfo[] = [
  {
    provider: AIProvider.GLM,
    name: '智谱GLM',
    description: '智谱AI大语言模型，支持GLM-4系列',
    website: 'https://open.bigmodel.cn',
    keyFormat: '以小数点分隔的64位字符串',
    keyExample: 'xxxxxxxxxxxxxxxx.xxxxxxxxxxxxxx',
    documentation: 'https://open.bigmodel.cn/dev/api'
  } as ProviderInfo,
  {
    provider: AIProvider.SILICONFLOW,
    name: '硅基流动',
    description: '支持Qwen、DeepSeek等多种开源模型',
    website: 'https://siliconflow.cn',
    keyFormat: '以sk-开头的字符串',
    keyExample: 'sk-xxxxxxxxxxxxxxxxxxxxxxxx',
    documentation: 'https://docs.siliconflow.cn'
  } as ProviderInfo
];

/**
 * 连接状态枚举
 */
export enum ConnectionStatus {
  UNKNOWN = 'unknown',
  CONNECTED = 'connected',
  DISCONNECTED = 'disconnected',
  ERROR = 'error',
  TESTING = 'testing'
}

/**
 * API密钥管理事件类型
 */
export interface APIKeyManagerEventBase {
  type: string;
}

export interface ConfigUpdatedEvent extends APIKeyManagerEventBase {
  type: 'config_updated';
  provider: AIProvider;
}

export interface ConnectionTestedEvent extends APIKeyManagerEventBase {
  type: 'connection_tested';
  provider: AIProvider;
  result: ConnectionTestResult;
}

export interface ProviderEnabledEvent extends APIKeyManagerEventBase {
  type: 'provider_enabled';
  provider: AIProvider;
}

export interface ProviderDisabledEvent extends APIKeyManagerEventBase {
  type: 'provider_disabled';
  provider: AIProvider;
}

export interface AllConfigsLoadedEvent extends APIKeyManagerEventBase {
  type: 'all_configs_loaded';
}

export type APIKeyManagerEvent = 
  | ConfigUpdatedEvent
  | ConnectionTestedEvent
  | ProviderEnabledEvent
  | ProviderDisabledEvent
  | AllConfigsLoadedEvent;