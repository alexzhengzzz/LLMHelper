import { describe, it, expect } from '@ohos/hypium';
import Constants from '../../main/ets/utils/Constants';

export default function ConstantsTest() {
  describe('ConstantsTest', () => {
    it('should have DEFAULT_MODEL defined', () => {
      expect(Constants.DEFAULT_MODEL).assertEqual('siliconflow.Qwen/Qwen2.5-7B-Instruct');
    });

    it('should have MAX_TOKENS defined', () => {
      expect(Constants.MAX_TOKENS).assertEqual(4000);
    });

    it('should have DEFAULT_TEMPERATURE defined', () => {
      expect(Constants.DEFAULT_TEMPERATURE).assertEqual(0.7);
    });

    it('should have MESSAGE_TIMEOUT defined', () => {
      expect(Constants.MESSAGE_TIMEOUT).assertEqual(30000);
    });

    it('should have MAX_RETRIES defined', () => {
      expect(Constants.MAX_RETRIES).assertEqual(3);
    });

    it('should have DEEP_THINKING_STEPS defined', () => {
      expect(Constants.DEEP_THINKING_STEPS.length).assertEqual(7);
      expect(Constants.DEEP_THINKING_STEPS[0]).assertEqual('规划');
      expect(Constants.DEEP_THINKING_STEPS[6]).assertEqual('复盘');
    });

    it('should have VOICE_RECOGNITION_CONFIG defined', () => {
      const config = Constants.VOICE_RECOGNITION_CONFIG;
      expect(config.engine).assertEqual('huawei');
      expect(config.language).assertEqual('zh-CN');
      expect(config.enablePunctuation).assertTrue();
      expect(config.timeout).assertEqual(5000);
    });

    it('should have TTS_CONFIG defined', () => {
      const config = Constants.TTS_CONFIG;
      expect(config.engine).assertEqual('huawei');
      expect(config.language).assertEqual('zh-CN');
      expect(config.voice).assertEqual('female');
      expect(config.speed).assertEqual(1.0);
      expect(config.pitch).assertEqual(1.0);
      expect(config.volume).assertEqual(1.0);
    });

    it('should have ANIMATION_CONFIG defined', () => {
      const config = Constants.ANIMATION_CONFIG;
      expect(config.duration).assertEqual(300);
      expect(config.easing).assertEqual('ease-in-out');
      expect(config.enableHardwareAcceleration).assertTrue();
      expect(config.targetFPS).assertEqual(60);
    });

    it('should have THEME_CONFIG defined', () => {
      const config = Constants.THEME_CONFIG;
      expect(config.defaultTheme).assertEqual('system');
      expect(config.supportedThemes.length).assertEqual(3);
      expect(config.supportedThemes).toContain('light');
      expect(config.supportedThemes).toContain('dark');
      expect(config.supportedThemes).toContain('system');
    });

    it('should have STORAGE_CONFIG defined', () => {
      const config = Constants.STORAGE_CONFIG;
      expect(config.maxSessions).assertEqual(100);
      expect(config.maxMessagesPerSession).assertEqual(1000);
      expect(config.cacheSize).assertEqual(50 * 1024 * 1024); // 50MB
    });

    it('should have PROVIDERS defined', () => {
      expect(Constants.PROVIDERS.length).assertGreaterThan(0);
      expect(Constants.PROVIDERS.some(p => p.id === 'siliconflow')).assertTrue();
      expect(Constants.PROVIDERS.some(p => p.id === 'google')).assertTrue();
      expect(Constants.PROVIDERS.some(p => p.id === 'zhipu')).assertTrue();
    });

    it('should have SEARCH_PROVIDERS defined', () => {
      expect(Constants.SEARCH_PROVIDERS.length).assertGreaterThan(0);
      expect(Constants.SEARCH_PROVIDERS.some(p => p.id === 'bing')).assertTrue();
      expect(Constants.SEARCH_PROVIDERS.some(p => p.id === 'google')).assertTrue();
      expect(Constants.SEARCH_PROVIDERS.some(p => p.id === 'duckduckgo')).assertTrue();
    });

    it('should have QUICK_COMMANDS defined', () => {
      expect(Constants.QUICK_COMMANDS.length).assertGreaterThan(0);
      expect(Constants.QUICK_COMMANDS.some(c => c.category === 'development')).assertTrue();
      expect(Constants.QUICK_COMMANDS.some(c => c.category === 'system')).assertTrue();
      expect(Constants.QUICK_COMMANDS.some(c => c.category === 'learning')).assertTrue();
    });

    it('should have ERROR_CODES defined', () => {
      const codes = Constants.ERROR_CODES;
      expect(codes.NETWORK_ERROR).assertEqual('NETWORK_ERROR');
      expect(codes.TIMEOUT_ERROR).assertEqual('TIMEOUT_ERROR');
      expect(codes.AUTH_ERROR).assertEqual('AUTH_ERROR');
      expect(codes.VALIDATION_ERROR).assertEqual('VALIDATION_ERROR');
      expect(codes.UNKNOWN_ERROR).assertEqual('UNKNOWN_ERROR');
    });

    it('should have LOG_LEVELS defined', () => {
      const levels = Constants.LOG_LEVELS;
      expect(levels.DEBUG).assertEqual(0);
      expect(levels.INFO).assertEqual(1);
      expect(levels.WARN).assertEqual(2);
      expect(levels.ERROR).assertEqual(3);
    });

    it('should have VALIDATION_RULES defined', () => {
      const rules = Constants.VALIDATION_RULES;
      expect(rules.maxSessionNameLength).assertEqual(50);
      expect(rules.maxPromptLength).assertEqual(4000);
      expect(rules.maxMessageLength).assertEqual(10000);
      expect(rules.allowedFileTypes.length).assertGreaterThan(0);
      expect(rules.allowedFileTypes).toContain('.txt');
      expect(rules.allowedFileTypes).toContain('.md');
    });

    it('should have PERFORMANCE_METRICS defined', () => {
      const metrics = Constants.PERFORMANCE_METRICS;
      expect(metrics.maxConcurrentRequests).assertEqual(5);
      expect(metrics.cacheTTL).assertEqual(3600000); // 1 hour
      expect(metrics.responseTimeout).assertEqual(30000);
      expect(metrics.memoryLimit).assertEqual(100 * 1024 * 1024); // 100MB
    });

    it('should have FEATURE_FLAGS defined', () => {
      const flags = Constants.FEATURE_FLAGS;
      expect(flags.enableVoiceInput).assertTrue();
      expect(flags.enableTTS).assertTrue();
      expect(flags.enableDeepThinking).assertTrue();
      expect(flags.enableNetworkSearch).assertTrue();
      expect(flags.enableCodeExecution).assertTrue();
      expect(flags.enableAnimations).assertTrue();
    });

    it('should have DEFAULT_PROMPTS defined', () => {
      expect(Constants.DEFAULT_PROMPTS.length).assertGreaterThan(0);
      expect(Constants.DEFAULT_PROMPTS.some(p => p.category === 'programming')).assertTrue();
      expect(Constants.DEFAULT_PROMPTS.some(p => p.category === 'system')).assertTrue();
      expect(Constants.DEFAULT_PROMPTS.some(p => p.category === 'learning')).assertTrue();
    });

    it('should have valid API URL format', () => {
      expect(Constants.API_BASE_URL.startsWith('http')).assertTrue();
      expect(Constants.API_BASE_URL.endsWith('/api')).assertTrue();
    });

    it('should have valid WebSocket URL format', () => {
      expect(Constants.WS_BASE_URL.startsWith('ws')).assertTrue();
      expect(Constants.WS_BASE_URL.endsWith('/ws')).assertTrue();
    });

    it('should have reasonable timeout values', () => {
      expect(Constants.MESSAGE_TIMEOUT).assertGreater(0);
      expect(Constants.MESSAGE_TIMEOUT).assertLess(60000); // 1 minute
      expect(Constants.MAX_RETRIES).assertGreater(0);
      expect(Constants.MAX_RETRIES).assertLess(10);
    });

    it('should have valid model configuration', () => {
      expect(Constants.DEFAULT_MODEL.length).assertGreater(0);
      expect(Constants.MAX_TOKENS).assertGreater(0);
      expect(Constants.DEFAULT_TEMPERATURE).assertGreater(0);
      expect(Constants.DEFAULT_TEMPERATURE).assertLess(2);
    });

    it('should have valid animation configuration', () => {
      expect(Constants.ANIMATION_CONFIG.duration).assertGreater(0);
      expect(Constants.ANIMATION_CONFIG.targetFPS).assertGreater(0);
      expect(Constants.ANIMATION_CONFIG.targetFPS).assertLessEqual(120);
    });

    it('should have valid storage configuration', () => {
      expect(Constants.STORAGE_CONFIG.maxSessions).assertGreater(0);
      expect(Constants.STORAGE_CONFIG.maxMessagesPerSession).assertGreater(0);
      expect(Constants.STORAGE_CONFIG.cacheSize).assertGreater(0);
    });
  });
}