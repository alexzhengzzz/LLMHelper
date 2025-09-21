import { describe, beforeAll, afterAll, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import Logger from '../../main/ets/utils/Logger';
import { LoggerConfig, LogLevel } from '../../main/ets/utils/Logger';

export default function LoggerTest() {
  describe('LoggerTest', () => {
    let originalConsoleLog: any;
    let originalConsoleInfo: any;
    let originalConsoleWarn: any;
    let originalConsoleError: any;

    beforeAll(() => {
      // 保存原始console方法
      originalConsoleLog = console.log;
      originalConsoleInfo = console.info;
      originalConsoleWarn = console.warn;
      originalConsoleError = console.error;
    });

    afterAll(() => {
      // 恢复原始console方法
      console.log = originalConsoleLog;
      console.info = originalConsoleInfo;
      console.warn = originalConsoleWarn;
      console.error = originalConsoleError;
    });

    beforeEach(() => {
      // 重置Logger配置
      Logger.resetConfig();
    });

    afterEach(() => {
      // 清理测试输出
      Logger.resetConfig();
    });

    it('should initialize with default configuration', () => {
      const config = Logger.getConfig();
      expect(config.level).assertEqual(LogLevel.DEBUG);
      expect(config.enableConsole).assertTrue();
      expect(config.enableFile).assertFalse();
      expect(config.maxFileSize).assertEqual(1024 * 1024);
      expect(config.maxFiles).assertEqual(5);
    });

    it('should configure logger correctly', () => {
      const newConfig: LoggerConfig = {
        level: LogLevel.INFO,
        enableConsole: false,
        enableFile: true,
        maxFileSize: 2048,
        maxFiles: 3,
        logDirectory: '/test/logs'
      };

      Logger.configure(newConfig);
      const config = Logger.getConfig();

      expect(config.level).assertEqual(LogLevel.INFO);
      expect(config.enableConsole).assertFalse();
      expect(config.enableFile).assertTrue();
      expect(config.maxFileSize).assertEqual(2048);
      expect(config.maxFiles).assertEqual(3);
      expect(config.logDirectory).assertEqual('/test/logs');
    });

    it('should log debug messages', () => {
      let capturedMessage = '';
      console.log = (message: string) => {
        capturedMessage = message;
      };

      Logger.debug('Debug test message');
      expect(capturedMessage).assertContain('[DEBUG]');
      expect(capturedMessage).assertContain('Debug test message');
    });

    it('should log info messages', () => {
      let capturedMessage = '';
      console.info = (message: string) => {
        capturedMessage = message;
      };

      Logger.info('Info test message');
      expect(capturedMessage).assertContain('[INFO]');
      expect(capturedMessage).assertContain('Info test message');
    });

    it('should log warning messages', () => {
      let capturedMessage = '';
      console.warn = (message: string) => {
        capturedMessage = message;
      };

      Logger.warn('Warning test message');
      expect(capturedMessage).assertContain('[WARN]');
      expect(capturedMessage).assertContain('Warning test message');
    });

    it('should log error messages', () => {
      let capturedMessage = '';
      console.error = (message: string) => {
        capturedMessage = message;
      };

      Logger.error('Error test message');
      expect(capturedMessage).assertContain('[ERROR]');
      expect(capturedMessage).assertContain('Error test message');
    });

    it('should respect log level configuration', () => {
      let capturedMessage = '';
      console.log = (message: string) => {
        capturedMessage = message;
      };

      // 设置日志级别为INFO
      Logger.configure({ level: LogLevel.INFO });

      // DEBUG消息不应该被记录
      capturedMessage = '';
      Logger.debug('This should not appear');
      expect(capturedMessage).assertEqual('');

      // INFO消息应该被记录
      Logger.info('This should appear');
      expect(capturedMessage).assertContain('This should appear');
    });

    it('should format log messages with timestamp', () => {
      let capturedMessage = '';
      console.info = (message: string) => {
        capturedMessage = message;
      };

      Logger.info('Test message');
      expect(capturedMessage).assertContain('[INFO]');
      expect(capturedMessage).assertContain('Test message');

      // 验证时间戳格式 (YYYY-MM-DD HH:mm:ss)
      const timestampPattern = /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/;
      expect(timestampPattern.test(capturedMessage)).assertTrue();
    });

    it('should handle object parameters', () => {
      let capturedMessage = '';
      console.info = (message: string) => {
        capturedMessage = message;
      };

      const testObject = { key: 'value', number: 123 };
      Logger.info('Object test:', testObject);
      expect(capturedMessage).assertContain('Object test:');
      expect(capturedMessage).assertContain('{"key":"value","number":123}');
    });

    it('should handle error objects', () => {
      let capturedMessage = '';
      console.error = (message: string) => {
        capturedMessage = message;
      };

      const testError = new Error('Test error');
      Logger.error('Error test:', testError);
      expect(capturedMessage).assertContain('Error test:');
      expect(capturedMessage).assertContain('Test error');
    });

    it('should handle multiple parameters', () => {
      let capturedMessage = '';
      console.info = (message: string) => {
        capturedMessage = message;
      };

      Logger.info('Multiple', 'parameters', 123, true);
      expect(capturedMessage).assertContain('Multiple parameters 123 true');
    });

    it('should disable console output when configured', () => {
      let capturedMessage = '';
      console.info = (message: string) => {
        capturedMessage = message;
      };

      Logger.configure({ enableConsole: false });
      Logger.info('This should not appear');
      expect(capturedMessage).assertEqual('');
    });

    it('should reset configuration to defaults', () => {
      const customConfig: LoggerConfig = {
        level: LogLevel.ERROR,
        enableConsole: false,
        enableFile: true
      };

      Logger.configure(customConfig);
      Logger.resetConfig();

      const config = Logger.getConfig();
      expect(config.level).assertEqual(LogLevel.DEBUG);
      expect(config.enableConsole).assertTrue();
      expect(config.enableFile).assertFalse();
    });

    it('should handle invalid log levels gracefully', () => {
      const invalidConfig = {
        level: 'INVALID_LEVEL' as LogLevel
      };

      Logger.configure(invalidConfig);
      const config = Logger.getConfig();
      expect(config.level).assertEqual(LogLevel.DEBUG); // 应该回退到默认值
    });

    it('should create context logger', () => {
      let capturedMessage = '';
      console.info = (message: string) => {
        capturedMessage = message;
      };

      const contextLogger = Logger.createContext('TestContext');
      contextLogger.info('Context message');
      expect(capturedMessage).assertContain('[TestContext]');
      expect(capturedMessage).assertContain('Context message');
    });
  });
}