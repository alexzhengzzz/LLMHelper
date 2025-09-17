import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { ThemeManager } from '../main/ets/utils/ThemeManager';
import { ThemeConfig, ThemeMode, ColorScheme } from '../main/ets/types/ThemeTypes';

/**
 * 主题管理器测试套件
 * 测试主题切换、颜色管理、样式应用等功能
 */
export default function themeManagerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('ThemeManagerTest');
  
  describe('ThemeManagerTest', () => {
    let themeManager: ThemeManager;
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化主题管理器测试环境');
      
      // 获取主题管理器实例
      themeManager = ThemeManager.getInstance();
      
      // 等待初始化完成
      await TestUtils.sleep(1000);
    });
    
    afterAll(async () => {
      await TestUtils.cleanupTestData();
      testSuite.afterAll();
    });
    
    beforeEach(() => {
      testSuite.beforeEach();
    });
    
    afterEach(() => {
      testSuite.afterEach();
    });
    
    /**
     * 测试单例模式
     */
    it('should_be_singleton_instance', 0, () => {
      TestUtils.log('测试单例模式');
      
      const instance1 = ThemeManager.getInstance();
      const instance2 = ThemeManager.getInstance();
      
      expect(instance1).assertEqual(instance2);
      TestUtils.log('单例模式验证通过');
    });
    
    /**
     * 测试主题模式切换
     */
    it('should_switch_theme_modes', 0, async () => {
      TestUtils.log('测试主题模式切换');
      
      // 测试浅色模式
      await themeManager.setThemeMode(ThemeMode.LIGHT);
      let currentMode = themeManager.getCurrentThemeMode();
      expect(currentMode).assertEqual(ThemeMode.LIGHT);
      
      // 测试深色模式
      await themeManager.setThemeMode(ThemeMode.DARK);
      currentMode = themeManager.getCurrentThemeMode();
      expect(currentMode).assertEqual(ThemeMode.DARK);
      
      // 测试跟随系统
      await themeManager.setThemeMode(ThemeMode.SYSTEM);
      currentMode = themeManager.getCurrentThemeMode();
      expect(currentMode).assertEqual(ThemeMode.SYSTEM);
      
      TestUtils.log('主题模式切换测试通过');
    });
    
    /**
     * 测试主题配置管理
     */
    it('should_manage_theme_configurations', 0, async () => {
      TestUtils.log('测试主题配置管理');
      
      // 获取默认配置
      const defaultConfig = themeManager.getDefaultConfig();
      expect(TestUtils.validateObjectStructure(defaultConfig, ['mode', 'colors', 'fonts', 'sizes'])).assertTrue();
      
      // 创建自定义配置
      const customConfig: ThemeConfig = {
        mode: ThemeMode.DARK,
        colors: {
          primary: '#ff6b6b',
          secondary: '#4ecdc4',
          background: '#1a1a1a',
          surface: '#2d2d2d',
          text: '#ffffff',
          textSecondary: '#b0b0b0',
          border: '#404040',
          error: '#ff4757',
          success: '#2ed573',
          warning: '#ffa502',
          info: '#3742fa'
        },
        fonts: {
          primary: 'HarmonyOS Sans',
          secondary: 'HarmonyOS Sans',
          mono: 'HarmonyOS Sans Mono'
        },
        sizes: {
          fontSize: 16,
          lineHeight: 1.6,
          borderRadius: 8,
          spacing: 16
        }
      };
      
      // 应用自定义配置
      await themeManager.applyConfig(customConfig);
      
      // 验证配置应用
      const currentConfig = themeManager.getCurrentConfig();
      expect(currentConfig.colors.primary).assertEqual('#ff6b6b');
      expect(currentConfig.colors.background).assertEqual('#1a1a1a');
      expect(currentConfig.fonts.primary).assertEqual('HarmonyOS Sans');
      expect(currentConfig.sizes.fontSize).assertEqual(16);
      
      TestUtils.log('主题配置管理测试通过');
    });
    
    /**
     * 测试颜色方案管理
     */
    it('should_manage_color_schemes', 0, async () => {
      TestUtils.log('测试颜色方案管理');
      
      // 测试预设颜色方案
      const schemes = themeManager.getPresetSchemes();
      expect(Array.isArray(schemes)).assertTrue();
      expect(schemes.length).assertGreaterThan(0);
      
      // 测试颜色方案应用
      const blueScheme = schemes.find(s => s.name === 'Blue');
      if (blueScheme) {
        await themeManager.applyColorScheme(blueScheme);
        
        const currentColors = themeManager.getCurrentColors();
        expect(currentColors.primary).assertEqual(blueScheme.colors.primary);
      }
      
      // 测试自定义颜色方案
      const customScheme: ColorScheme = {
        name: 'Custom',
        colors: {
          primary: '#e74c3c',
          secondary: '#3498db',
          background: '#2c3e50',
          surface: '#34495e',
          text: '#ecf0f1',
          textSecondary: '#bdc3c7',
          border: '#7f8c8d',
          error: '#e74c3c',
          success: '#27ae60',
          warning: '#f39c12',
          info: '#3498db'
        }
      };
      
      await themeManager.addCustomScheme(customScheme);
      
      // 验证自定义方案添加
      const customSchemes = themeManager.getCustomSchemes();
      expect(customSchemes.some(s => s.name === 'Custom')).assertTrue();
      
      TestUtils.log('颜色方案管理测试通过');
    });
    
    /**
     * 测试主题切换动画
     */
    it('should_handle_theme_switching_animations', 0, async () => {
      TestUtils.log('测试主题切换动画');
      
      // 启用动画
      themeManager.enableAnimations(true);
      expect(themeManager.isAnimationEnabled()).assertTrue();
      
      // 测试主题切换动画
      const animationDuration = 300;
      themeManager.setAnimationDuration(animationDuration);
      expect(themeManager.getAnimationDuration()).assertEqual(animationDuration);
      
      // 执行主题切换
      const startTime = Date.now();
      await themeManager.setThemeMode(ThemeMode.DARK);
      
      // 验证动画执行
      const endTime = Date.now();
      expect(endTime - startTime).assertLessThanOrEqual(animationDuration + 100);
      
      // 测试动画类型
      const animationTypes = ['fade', 'slide', 'scale'];
      for (const type of animationTypes) {
        themeManager.setAnimationType(type);
        expect(themeManager.getAnimationType()).assertEqual(type);
      }
      
      TestUtils.log('主题切换动画测试通过');
    });
    
    /**
     * 测试主题持久化
     */
    it('should_persist_theme_settings', 0, async () => {
      TestUtils.log('测试主题持久化');
      
      // 设置主题配置
      await themeManager.setThemeMode(ThemeMode.DARK);
      await themeManager.applyConfig({
        colors: {
          primary: '#9b59b6',
          background: '#2c3e50',
          text: '#ecf0f1'
        } as any
      });
      
      // 保存设置
      await themeManager.saveSettings();
      
      // 模拟应用重启
      const newThemeManager = ThemeManager.getInstance();
      
      // 验证设置恢复
      const restoredMode = newThemeManager.getCurrentThemeMode();
      expect(restoredMode).assertEqual(ThemeMode.DARK);
      
      const restoredColors = newThemeManager.getCurrentColors();
      expect(restoredColors.primary).assertEqual('#9b59b6');
      expect(restoredColors.background).assertEqual('#2c3e50');
      
      TestUtils.log('主题持久化测试通过');
    });
    
    /**
     * 测试主题颜色动态计算
     */
    it('should_calculate_dynamic_colors', 0, async () => {
      TestUtils.log('测试主题颜色动态计算');
      
      const baseColor = '#3498db';
      
      // 测试颜色变体计算
      const lighter = themeManager.getLighterVariant(baseColor, 20);
      const darker = themeManager.getDarkerVariant(baseColor, 20);
      
      expect(lighter).assertNotEqual(baseColor);
      expect(darker).assertNotEqual(baseColor);
      expect(lighter).assertNotEqual(darker);
      
      // 测试对比度计算
      const contrastRatio = themeManager.getContrastRatio('#000000', '#ffffff');
      expect(contrastRatio).assertGreaterThan(10);
      
      // 测试可读性验证
      const isReadable = themeManager.isReadable('#000000', '#ffffff', 4.5);
      expect(isReadable).assertTrue();
      
      // 测试自动调整
      const adjustedColor = themeManager.adjustForReadability('#cccccc', '#ffffff');
      expect(adjustedColor).assertNotEqual('#cccccc');
      
      TestUtils.log('主题颜色动态计算测试通过');
    });
    
    /**
     * 测试主题监听器
     */
    it('should_handle_theme_listeners', 0, async () => {
      TestUtils.log('测试主题监听器');
      
      let changeCount = 0;
      let lastMode: ThemeMode | null = null;
      
      // 添加主题变更监听器
      const listenerId = themeManager.addThemeChangeListener((mode, config) => {
        changeCount++;
        lastMode = mode;
      });
      
      // 触发主题变更
      await themeManager.setThemeMode(ThemeMode.LIGHT);
      await themeManager.setThemeMode(ThemeMode.DARK);
      await themeManager.setThemeMode(ThemeMode.LIGHT);
      
      // 验证监听器触发
      expect(changeCount).assertEqual(3);
      expect(lastMode).assertEqual(ThemeMode.LIGHT);
      
      // 移除监听器
      themeManager.removeThemeChangeListener(listenerId);
      
      // 再次触发变更
      await themeManager.setThemeMode(ThemeMode.DARK);
      
      // 验证监听器已移除
      expect(changeCount).assertEqual(3); // 不应该增加
      
      TestUtils.log('主题监听器测试通过');
    });
    
    /**
     * 测试主题性能优化
     */
    it('should_optimize_theme_performance', 0, async () => {
      TestUtils.log('测试主题性能优化');
      
      // 测试批量主题更新
      const updates = [
        { mode: ThemeMode.LIGHT },
        { mode: ThemeMode.DARK },
        { mode: ThemeMode.SYSTEM },
        { mode: ThemeMode.LIGHT }
      ];
      
      const startTime = Date.now();
      await themeManager.batchUpdate(updates);
      const endTime = Date.now();
      
      // 验证批量更新性能
      expect(endTime - startTime).assertLessThan(1000);
      
      // 测试主题缓存
      const cacheStats = themeManager.getCacheStatistics();
      expect(TestUtils.validateObjectStructure(cacheStats, ['hits', 'misses', 'size', 'hitRate'])).assertTrue();
      expect(cacheStats.hits).assertGreaterThan(0);
      
      // 测试内存使用
      const memoryUsage = themeManager.getMemoryUsage();
      expect(memoryUsage.totalSize).assertGreaterThan(0);
      
      TestUtils.log('主题性能优化测试通过');
    });
    
    /**
     * 测试主题错误处理
     */
    it('should_handle_theme_errors', 0, async () => {
      TestUtils.log('测试主题错误处理');
      
      // 测试无效配置
      const invalidConfig = {
        mode: 'invalid_mode' as any,
        colors: null as any
      };
      
      try {
        await themeManager.applyConfig(invalidConfig);
        // 应该抛出错误
        expect(false).assertTrue();
      } catch (error) {
        expect(error !== null).assertTrue();
      }
      
      // 测试无效颜色值
      const invalidColor = 'not_a_color';
      const fallbackColor = themeManager.parseColor(invalidColor, '#000000');
      expect(fallbackColor).assertEqual('#000000');
      
      // 测试空配置处理
      const emptyConfig = {} as ThemeConfig;
      await themeManager.applyConfig(emptyConfig);
      
      // 应该使用默认值
      const currentConfig = themeManager.getCurrentConfig();
      expect(currentConfig.mode).assertNotEqual(undefined);
      
      TestUtils.log('主题错误处理测试通过');
    });
    
    /**
     * 测试主题兼容性
     */
    it('should_handle_theme_compatibility', 0, async () => {
      TestUtils.log('测试主题兼容性');
      
      // 测试旧版本配置兼容性
      const legacyConfig = {
        theme: 'dark',
        primaryColor: '#ff0000',
        backgroundColor: '#000000',
        fontSize: 14
      };
      
      await themeManager.applyLegacyConfig(legacyConfig);
      
      const currentConfig = themeManager.getCurrentConfig();
      expect(currentConfig.mode).assertEqual(ThemeMode.DARK);
      expect(currentConfig.colors.primary).assertEqual('#ff0000');
      expect(currentConfig.colors.background).assertEqual('#000000');
      expect(currentConfig.sizes.fontSize).assertEqual(14);
      
      // 测试版本升级
      const version = themeManager.getConfigVersion();
      expect(version.major).assertGreaterThanOrEqual(1);
      
      TestUtils.log('主题兼容性测试通过');
    });
    
    /**
     * 测试主题导出和导入
     */
    it('should_export_and_import_themes', 0, async () => {
      TestUtils.log('测试主题导出和导入');
      
      // 创建复杂主题配置
      const complexConfig: ThemeConfig = {
        mode: ThemeMode.DARK,
        colors: {
          primary: '#8e44ad',
          secondary: '#3498db',
          background: '#2c3e50',
          surface: '#34495e',
          text: '#ecf0f1',
          textSecondary: '#bdc3c7',
          border: '#7f8c8d',
          error: '#e74c3c',
          success: '#27ae60',
          warning: '#f39c12',
          info: '#3498db'
        },
        fonts: {
          primary: 'Custom Font',
          secondary: 'Custom Font',
          mono: 'Custom Mono'
        },
        sizes: {
          fontSize: 18,
          lineHeight: 1.8,
          borderRadius: 12,
          spacing: 20
        }
      };
      
      await themeManager.applyConfig(complexConfig);
      
      // 导出主题
      const exportedTheme = themeManager.exportTheme();
      expect(typeof exportedTheme).assertEqual('string');
      
      // 验证导出的JSON
      const parsedTheme = JSON.parse(exportedTheme);
      expect(TestUtils.validateObjectStructure(parsedTheme, ['version', 'config', 'timestamp'])).assertTrue();
      
      // 导入主题
      await themeManager.importTheme(exportedTheme);
      
      // 验证导入结果
      const importedConfig = themeManager.getCurrentConfig();
      expect(importedConfig.colors.primary).assertEqual('#8e44ad');
      expect(importedConfig.fonts.primary).assertEqual('Custom Font');
      expect(importedConfig.sizes.fontSize).assertEqual(18);
      
      TestUtils.log('主题导出和导入测试通过');
    });
    
    /**
     * 测试主题统计信息
     */
    it('should_track_theme_statistics', 0, async () => {
      TestUtils.log('测试主题统计信息');
      
      // 执行多个主题操作
      await themeManager.setThemeMode(ThemeMode.LIGHT);
      await themeManager.setThemeMode(ThemeMode.DARK);
      await themeManager.setThemeMode(ThemeMode.LIGHT);
      
      // 获取统计信息
      const stats = themeManager.getStatistics();
      
      // 验证统计信息
      expect(TestUtils.validateObjectStructure(stats, ['totalChanges', 'modeChanges', 'configUpdates', 'animationUsage'])).assertTrue();
      expect(stats.totalChanges).assertEqual(3);
      expect(stats.modeChanges).assertEqual(3);
      expect(stats.configUpdates).assertGreaterThan(0);
      
      // 测试最常用模式
      const popularMode = themeManager.getMostUsedMode();
      expect(popularMode).assertEqual(ThemeMode.LIGHT);
      
      TestUtils.log('主题统计信息测试通过');
    });
  });
}