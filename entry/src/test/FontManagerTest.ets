import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { FontManager } from '../main/ets/utils/FontManager';
import { FontSettings, AppStorage as StorageManager } from '../main/ets/utils/AppStorage';

/**
 * 字体管理器测试套件
 * 测试字体设置的存储、加载、更新和监听等功能
 */
export default function fontManagerTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('FontManagerTest');

  describe('FontManagerTest', () => {
    let fontManager: FontManager;

    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化字体管理器测试环境');

      // 获取字体管理器实例
      fontManager = FontManager.getInstance();

      // 等待初始化完成
      await fontManager.initialize();
      await TestUtils.sleep(1000);
    });

    afterAll(async () => {
      // 清理测试数据
      try {
        await StorageManager.resetFontSettings();
      } catch (error) {
        TestUtils.log(`清理字体设置失败: ${error}`);
      }

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

      const instance1 = FontManager.getInstance();
      const instance2 = FontManager.getInstance();

      expect(instance1).assertEqual(instance2);
      TestUtils.log('✅ 单例模式测试通过');
    });

    /**
     * 测试默认字体设置
     */
    it('should_have_default_font_settings', 0, () => {
      TestUtils.log('测试默认字体设置');

      const settings = fontManager.getFontSettings();

      expect(settings.chatFontSize).assertInstanceOf('number');
      expect(settings.codeFontSize).assertInstanceOf('number');
      expect(settings.fontFamily).assertInstanceOf('string');
      expect(settings.updatedAt).assertInstanceOf('number');

      // 验证默认值范围
      expect(settings.chatFontSize >= 12 && settings.chatFontSize <= 20).assertTrue();
      expect(settings.codeFontSize >= 10 && settings.codeFontSize <= 18).assertTrue();
      expect(['system', 'monospace'].includes(settings.fontFamily)).assertTrue();

      TestUtils.log(`✅ 默认字体设置: ${JSON.stringify(settings)}`);
    });

    /**
     * 测试聊天字体大小更新
     */
    it('should_update_chat_font_size', 0, async () => {
      TestUtils.log('测试聊天字体大小更新');

      const originalSize = fontManager.getChatFontSize();
      const newSize = 18;

      await fontManager.updateChatFontSize(newSize);

      const updatedSize = fontManager.getChatFontSize();
      expect(updatedSize).assertEqual(newSize);

      TestUtils.log(`✅ 聊天字体大小更新: ${originalSize} -> ${updatedSize}`);
    });

    /**
     * 测试代码字体大小更新
     */
    it('should_update_code_font_size', 0, async () => {
      TestUtils.log('测试代码字体大小更新');

      const originalSize = fontManager.getCodeFontSize();
      const newSize = 16;

      await fontManager.updateCodeFontSize(newSize);

      const updatedSize = fontManager.getCodeFontSize();
      expect(updatedSize).assertEqual(newSize);

      TestUtils.log(`✅ 代码字体大小更新: ${originalSize} -> ${updatedSize}`);
    });

    /**
     * 测试字体家族更新
     */
    it('should_update_font_family', 0, async () => {
      TestUtils.log('测试字体家族更新');

      const originalFamily = fontManager.getFontFamily();
      const newFamily = originalFamily === 'system' ? 'monospace' : 'system';

      await fontManager.updateFontFamily(newFamily);

      const updatedFamily = fontManager.getFontFamily();
      expect(updatedFamily).assertEqual(newFamily);

      TestUtils.log(`✅ 字体家族更新: ${originalFamily} -> ${updatedFamily}`);
    });

    /**
     * 测试字体大小边界值
     */
    it('should_clamp_font_size_within_bounds', 0, async () => {
      TestUtils.log('测试字体大小边界值');

      // 测试聊天字体大小边界
      await fontManager.updateChatFontSize(25); // 超出上限
      expect(fontManager.getChatFontSize()).assertEqual(20);

      await fontManager.updateChatFontSize(8); // 低于下限
      expect(fontManager.getChatFontSize()).assertEqual(12);

      // 测试代码字体大小边界
      await fontManager.updateCodeFontSize(25); // 超出上限
      expect(fontManager.getCodeFontSize()).assertEqual(18);

      await fontManager.updateCodeFontSize(5); // 低于下限
      expect(fontManager.getCodeFontSize()).assertEqual(10);

      TestUtils.log('✅ 字体大小边界值测试通过');
    });

    /**
     * 测试批量更新字体设置
     */
    it('should_batch_update_font_settings', 0, async () => {
      TestUtils.log('测试批量更新字体设置');

      const updates: Partial<FontSettings> = {
        chatFontSize: 15,
        codeFontSize: 13,
        fontFamily: 'monospace'
      };

      await fontManager.updateFontSettings(updates);

      const settings = fontManager.getFontSettings();
      expect(settings.chatFontSize).assertEqual(15);
      expect(settings.codeFontSize).assertEqual(13);
      expect(settings.fontFamily).assertEqual('monospace');

      TestUtils.log(`✅ 批量更新成功: ${JSON.stringify(updates)}`);
    });

    /**
     * 测试字体设置监听器
     */
    it('should_notify_listeners_on_font_change', 0, async () => {
      TestUtils.log('测试字体设置监听器');

      let listenerCalled = false;
      let receivedSettings: FontSettings | null = null;

      const listener = (settings: FontSettings) => {
        listenerCalled = true;
        receivedSettings = settings;
      };

      // 添加监听器
      fontManager.addListener(listener);

      // 更新字体设置
      const newSize = 17;
      await fontManager.updateChatFontSize(newSize);

      // 等待监听器执行
      await TestUtils.sleep(100);

      expect(listenerCalled).assertTrue();
      expect(receivedSettings).assertInstanceOf('object');
      expect(receivedSettings!.chatFontSize).assertEqual(newSize);

      // 移除监听器
      fontManager.removeListener(listener);

      TestUtils.log('✅ 字体设置监听器测试通过');
    });

    /**
     * 测试字体设置持久化
     */
    it('should_persist_font_settings', 0, async () => {
      TestUtils.log('测试字体设置持久化');

      const testSettings: Partial<FontSettings> = {
        chatFontSize: 19,
        codeFontSize: 15,
        fontFamily: 'system'
      };

      // 更新设置
      await fontManager.updateFontSettings(testSettings);

      // 重新获取设置，验证持久化
      const savedSettings = await StorageManager.getFontSettings();
      expect(savedSettings.chatFontSize).assertEqual(19);
      expect(savedSettings.codeFontSize).assertEqual(15);
      expect(savedSettings.fontFamily).assertEqual('system');

      TestUtils.log('✅ 字体设置持久化测试通过');
    });

    /**
     * 测试字体设置重置
     */
    it('should_reset_to_default_settings', 0, async () => {
      TestUtils.log('测试字体设置重置');

      // 先修改设置
      await fontManager.updateFontSettings({
        chatFontSize: 20,
        codeFontSize: 18,
        fontFamily: 'monospace'
      });

      // 重置设置
      await fontManager.resetFontSettings();

      // 验证重置结果
      const settings = fontManager.getFontSettings();
      const defaultSettings = StorageManager.getDefaultFontSettings();

      expect(settings.chatFontSize).assertEqual(defaultSettings.chatFontSize);
      expect(settings.codeFontSize).assertEqual(defaultSettings.codeFontSize);
      expect(settings.fontFamily).assertEqual(defaultSettings.fontFamily);

      TestUtils.log('✅ 字体设置重置测试通过');
    });

    /**
     * 测试字体CSS值生成
     */
    it('should_generate_correct_font_family_css', 0, () => {
      TestUtils.log('测试字体CSS值生成');

      // 测试系统字体
      fontManager.updateFontFamily('system');
      let css = fontManager.getFontFamilyCss();
      expect(css.includes('system-ui')).assertTrue();

      // 测试等宽字体
      fontManager.updateFontFamily('monospace');
      css = fontManager.getFontFamilyCss();
      expect(css.includes('Monaco') || css.includes('monospace')).assertTrue();

      TestUtils.log('✅ 字体CSS值生成测试通过');
    });

    /**
     * 测试静态工具方法
     */
    it('should_provide_static_utility_methods', 0, () => {
      TestUtils.log('测试静态工具方法');

      // 测试字体大小显示文本
      const sizeText = FontManager.getFontSizeDisplayText(16);
      expect(sizeText).assertEqual('16px');

      // 测试字体家族显示文本
      const systemText = FontManager.getFontFamilyDisplayText('system');
      expect(systemText).assertEqual('系统默认');

      const monospaceText = FontManager.getFontFamilyDisplayText('monospace');
      expect(monospaceText).assertEqual('等宽字体');

      // 测试字体大小验证
      expect(FontManager.isValidChatFontSize(16)).assertTrue();
      expect(FontManager.isValidChatFontSize(10)).assertFalse();
      expect(FontManager.isValidChatFontSize(25)).assertFalse();

      expect(FontManager.isValidCodeFontSize(14)).assertTrue();
      expect(FontManager.isValidCodeFontSize(8)).assertFalse();
      expect(FontManager.isValidCodeFontSize(20)).assertFalse();

      TestUtils.log('✅ 静态工具方法测试通过');
    });

    /**
     * 测试错误处理
     */
    it('should_handle_errors_gracefully', 0, async () => {
      TestUtils.log('测试错误处理');

      try {
        // 测试无效的字体家族（这应该被处理为system）
        await fontManager.updateFontFamily('invalid' as any);

        // 应该回退到system字体
        const family = fontManager.getFontFamily();
        expect(['system', 'monospace'].includes(family)).assertTrue();

        TestUtils.log('✅ 错误处理测试通过');
      } catch (error) {
        TestUtils.log(`错误处理测试中发生异常: ${error}`);
        expect(false).assertTrue(); // 不应该抛出异常
      }
    });
  });
}