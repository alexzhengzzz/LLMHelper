/**
 * 增强版日志工具类
 * ArkTS兼容版本，支持错误追踪和性能监控
 */

import { ErrorLevel, ErrorType, ErrorCode } from '../types/ErrorTypes';

/**
 * 日志级别
 */
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  FATAL = 4
}

/**
 * 日志上下文信息
 */
export class LogContext {
  module?: string = '';
  functionName?: string = '';
  userId?: string = '';
  sessionId?: string = '';
  requestId?: string = '';
  additionalInfo?: string = '';

  constructor(init?: LogContext) {
    if (init) {
      this.module = init.module;
      this.functionName = init.functionName;
      this.userId = init.userId;
      this.sessionId = init.sessionId;
      this.requestId = init.requestId;
      this.additionalInfo = init.additionalInfo;
    }
  }
}

/**
 * 结构化日志条目
 */
export class LogEntry {
  timestamp: number = 0;
  level: LogLevel = LogLevel.INFO;
  tag: string = '';
  message: string = '';
  data?: string;
  errorMessage?: string;
  context?: LogContext;
  stackTrace?: string;

  constructor() {
    this.timestamp = Date.now();
  }
}

/**
 * 日志配置
 */
export class LoggerConfig {
  enableDebug: boolean = false;
  enableConsoleOutput: boolean = true;
  enableErrorTracking: boolean = true;
  enablePerformanceMonitoring: boolean = true;
  maxLogHistorySize: number = 1000;
  minLogLevel: LogLevel = LogLevel.INFO;
  logFormat: string = 'simple';
}

/**
 * 性能监控条目
 */
class PerformanceEntry {
  tag: string = '';
  operation: string = '';
  startTime: number = 0;
  endTime?: number;
  duration?: number;
  data?: string;

  constructor(tag: string, operation: string, data?: string) {
    this.tag = tag;
    this.operation = operation;
    this.startTime = Date.now();
    this.data = data;
  }
}

/**
 * 错误统计信息
 */
export class ErrorStats {
  errorCount: number = 0;
  warningCount: number = 0;
  fatalCount: number = 0;
  recentErrors: LogEntry[] = [];
}

/**
 * 日志工具类
 */
export class Logger {
  private static readonly TAG = 'Javis';
  private static instance: Logger;
  private config: LoggerConfig = new LoggerConfig();
  private logHistory: LogEntry[] = [];
  private performanceEntries: Map<string, PerformanceEntry> = new Map();
  
  private constructor() {
    // 私有构造函数，确保单例
  }

  /**
   * 获取Logger单例
   */
  static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }

  /**
   * 配置日志行为
   */
  static configure(enableDebug?: boolean, enablePerformanceMonitoring?: boolean): void {
    const instance = Logger.getInstance();
    if (enableDebug !== undefined) {
      instance.config.enableDebug = enableDebug;
    }
    if (enablePerformanceMonitoring !== undefined) {
      instance.config.enablePerformanceMonitoring = enablePerformanceMonitoring;
    }
  }

  /**
   * 获取当前配置
   */
  static getConfig(): LoggerConfig {
    return Logger.getInstance().config;
  }

  /**
   * 调试日志
   */
  static debug(tag: string, message: string, data?: string, context?: LogContext): void {
    Logger.getInstance().log(LogLevel.DEBUG, tag, message, data, undefined, context);
  }

  /**
   * 信息日志
   */
  static info(tag: string, message: string, data?: string, context?: LogContext): void {
    Logger.getInstance().log(LogLevel.INFO, tag, message, data, undefined, context);
  }

  /**
   * 警告日志
   */
  static warn(tag: string, message: string, data?: string, context?: LogContext): void {
    Logger.getInstance().log(LogLevel.WARN, tag, message, data, undefined, context);
  }

  /**
   * 错误日志
   */
  static error(tag: string, message: string, error?: Error | string, context?: LogContext): void {
    const errorMessage = typeof error === 'string' ? error : error?.message;
    const stackTrace = error instanceof Error ? error.stack : undefined;
    Logger.getInstance().log(LogLevel.ERROR, tag, message, errorMessage, stackTrace, context);
  }

  /**
   * 致命错误日志
   */
  static fatal(tag: string, message: string, error?: Error | string, context?: LogContext): void {
    const errorMessage = typeof error === 'string' ? error : error?.message;
    const stackTrace = error instanceof Error ? error.stack : undefined;
    Logger.getInstance().log(LogLevel.FATAL, tag, message, errorMessage, stackTrace, context);
  }

  /**
   * 结构化错误日志
   */
  static logError(
    tag: string,
    errorType: ErrorType,
    errorCode: ErrorCode,
    message: string,
    error?: Error,
    context?: LogContext
  ): void {
    const structuredContext = context || new LogContext();
    structuredContext.additionalInfo = `ErrorType:${errorType},ErrorCode:${errorCode}`;
    
    Logger.error(tag, message, error, structuredContext);
  }

  /**
   * 性能监控 - 开始计时
   */
  static startPerformanceMonitoring(tag: string, operation: string, data?: string): string {
    const instance = Logger.getInstance();
    if (!instance.config.enablePerformanceMonitoring) {
      return '';
    }

    const perfId = `${tag}_${operation}_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const entry = new PerformanceEntry(tag, operation, data);
    
    instance.performanceEntries.set(perfId, entry);
    return perfId;
  }

  /**
   * 性能监控 - 结束计时
   */
  static endPerformanceMonitoring(perfId: string, additionalData?: string): void {
    const instance = Logger.getInstance();
    if (!instance.config.enablePerformanceMonitoring || !perfId) {
      return;
    }

    const entry = instance.performanceEntries.get(perfId);
    if (!entry) {
      return;
    }

    entry.endTime = Date.now();
    entry.duration = entry.endTime - entry.startTime;
    
    const message = `性能监控: ${entry.operation} 耗时 ${entry.duration.toFixed(2)}ms`;
    const data = additionalData ? `${entry.data || ''} ${additionalData}` : entry.data;

    // 记录性能日志
    if (entry.duration > 1000) { // 超过1秒的操作记录为警告
      Logger.warn(entry.tag, message, data);
    } else {
      Logger.debug(entry.tag, message, data);
    }

    // 清理条目
    instance.performanceEntries.delete(perfId);
  }

  /**
   * 便捷方法：带性能监控的异步函数执行
   */
  static async withPerformanceMonitoring<T>(
    tag: string,
    operation: string,
    fn: () => Promise<T>,
    data?: string
  ): Promise<T> {
    const perfId = Logger.startPerformanceMonitoring(tag, operation, data);
    
    try {
      const result = await fn();
      Logger.endPerformanceMonitoring(perfId, 'success:true');
      return result;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      Logger.endPerformanceMonitoring(perfId, `success:false,error:${errorMessage}`);
      throw new Error(errorMessage);
    }
  }

  /**
   * 获取日志历史
   */
  static getLogHistory(level?: LogLevel, limit?: number): LogEntry[] {
    const instance = Logger.getInstance();
    let history = instance.logHistory.slice(); // 复制数组
    
    if (level !== undefined) {
      history = history.filter(entry => entry.level >= level);
    }
    
    if (limit && limit > 0) {
      const startIndex = Math.max(0, history.length - limit);
      history = history.slice(startIndex);
    }
    
    return history;
  }

  /**
   * 清理日志历史
   */
  static clearLogHistory(): void {
    Logger.getInstance().logHistory = [];
  }

  /**
   * 获取错误统计
   */
  static getErrorStats(): ErrorStats {
    const instance = Logger.getInstance();
    const history = instance.logHistory;
    const stats = new ErrorStats();
    
    for (const entry of history) {
      switch (entry.level) {
        case LogLevel.ERROR:
          stats.errorCount++;
          break;
        case LogLevel.WARN:
          stats.warningCount++;
          break;
        case LogLevel.FATAL:
          stats.fatalCount++;
          break;
      }
      
      // 收集最近的错误
      if (entry.level >= LogLevel.WARN && stats.recentErrors.length < 10) {
        stats.recentErrors.push(entry);
      }
    }
    
    return stats;
  }

  /**
   * 导出日志（JSON格式）
   */
  static exportLogs(): string {
    const instance = Logger.getInstance();
    const stats = Logger.getErrorStats();
    
    class ExportData {
      timestamp: number = 0;
      logCount: number = 0;
      errorCount: number = 0;
      warningCount: number = 0;
      fatalCount: number = 0;
    }
    
    const exportData = new ExportData();
    exportData.timestamp = Date.now();
    exportData.logCount = instance.logHistory.length;
    exportData.errorCount = stats.errorCount;
    exportData.warningCount = stats.warningCount;
    exportData.fatalCount = stats.fatalCount;
    
    return JSON.stringify(exportData);
  }

  /**
   * 核心日志方法
   */
  private log(
    level: LogLevel,
    tag: string,
    message: string,
    data?: string,
    stackTrace?: string,
    context?: LogContext
  ): void {
    // 检查是否应该记录此级别的日志
    if (level < this.config.minLogLevel) {
      return;
    }

    if (level === LogLevel.DEBUG && !this.config.enableDebug) {
      return;
    }

    // 创建日志条目
    const logEntry = new LogEntry();
    logEntry.timestamp = Date.now();
    logEntry.level = level;
    logEntry.tag = tag;
    logEntry.message = message;
    logEntry.data = data;
    logEntry.context = context;
    logEntry.stackTrace = stackTrace;

    // 添加到历史记录
    this.addToHistory(logEntry);

    // 控制台输出
    if (this.config.enableConsoleOutput) {
      this.outputToConsole(logEntry);
    }
  }

  /**
   * 添加到历史记录
   */
  private addToHistory(entry: LogEntry): void {
    this.logHistory.push(entry);
    
    // 限制历史记录大小
    if (this.logHistory.length > this.config.maxLogHistorySize) {
      this.logHistory.shift();
    }
  }

  /**
   * 控制台输出
   */
  private outputToConsole(entry: LogEntry): void {
    const contextInfo = entry.context ? 
      `[${entry.context.module || 'Unknown'}]` : '';
    const prefix = `[${entry.tag}]${contextInfo} ${entry.message}`;
    const output = entry.data ? `${prefix} ${entry.data}` : prefix;
    
    switch (entry.level) {
      case LogLevel.DEBUG:
        console.debug(output);
        break;
      case LogLevel.INFO:
        console.info(output);
        break;
      case LogLevel.WARN:
        console.warn(output);
        break;
      case LogLevel.ERROR:
        console.error(output);
        if (entry.stackTrace) {
          console.error(`Stack trace: ${entry.stackTrace}`);
        }
        break;
      case LogLevel.FATAL:
        console.error(`[FATAL] ${output}`);
        if (entry.stackTrace) {
          console.error(`Stack trace: ${entry.stackTrace}`);
        }
        break;
    }
  }
}