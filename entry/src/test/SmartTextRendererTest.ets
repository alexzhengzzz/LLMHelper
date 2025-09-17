import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils, TestSuiteBase, AsyncTestUtils } from './TestUtils';
import { SmartTextRenderer } from '../main/ets/components/SmartTextRenderer';
import { RenderConfig, RenderResult } from '../main/ets/types/RenderTypes';

/**
 * 智能文本渲染器测试套件
 * 测试代码高亮、Markdown渲染、富文本处理等功能
 */
export default function smartTextRendererTest() {
  const testSuite = new TestSuiteBase();
  testSuite.setTestTag('SmartTextRendererTest');
  
  describe('SmartTextRendererTest', () => {
    let smartTextRenderer: SmartTextRenderer;
    
    beforeAll(async () => {
      testSuite.beforeAll();
      TestUtils.log('初始化智能文本渲染器测试环境');
      
      // 获取智能文本渲染器实例
      smartTextRenderer = SmartTextRenderer.getInstance();
      
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
      
      const instance1 = SmartTextRenderer.getInstance();
      const instance2 = SmartTextRenderer.getInstance();
      
      expect(instance1).assertEqual(instance2);
      TestUtils.log('单例模式验证通过');
    });
    
    /**
     * 测试Markdown渲染
     */
    it('should_render_markdown', 0, () => {
      TestUtils.log('测试Markdown渲染');
      
      const markdownText = `
# 标题1
## 标题2
**粗体文本**
*斜体文本*
- 列表项1
- 列表项2
[链接](https://example.com)
\`代码\`
`;
      
      const result = smartTextRenderer.renderMarkdown(markdownText);
      
      // 验证渲染结果
      expect(TestUtils.validateObjectStructure(result, ['html', 'metadata', 'renderTime'])).assertTrue();
      expect(result.html.length).assertGreaterThan(0);
      expect(result.html.includes('<h1>')).assertTrue();
      expect(result.html.includes('<strong>')).assertTrue();
      expect(result.html.includes('<em>')).assertTrue();
      expect(result.html.includes('<ul>')).assertTrue();
      expect(result.html.includes('<a href=')).assertTrue();
      expect(result.html.includes('<code>')).assertTrue();
      
      TestUtils.log('Markdown渲染测试通过');
    });
    
    /**
     * 测试代码高亮
     */
    it('should_highlight_code', 0, () => {
      TestUtils.log('测试代码高亮');
      
      const pythonCode = `
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)

# 计算斐波那契数列
result = fibonacci(10)
print(f"结果: {result}")
`;
      
      const result = smartTextRenderer.highlightCode(pythonCode, 'python');
      
      // 验证代码高亮结果
      expect(TestUtils.validateObjectStructure(result, ['html', 'language', 'lineCount', 'highlightTime'])).assertTrue();
      expect(result.language).assertEqual('python');
      expect(result.lineCount).assertEqual(7);
      expect(result.html.includes('<span class="keyword">')).assertTrue();
      expect(result.html.includes('<span class="function">')).assertTrue();
      expect(result.html.includes('<span class="comment">')).assertTrue();
      
      TestUtils.log('代码高亮测试通过');
    });
    
    /**
     * 测试多语言代码高亮
     */
    it('should_highlight_multiple_languages', 0, () => {
      TestUtils.log('测试多语言代码高亮');
      
      const languages = [
        { code: 'const x = 10;', lang: 'javascript' },
        { code: 'int x = 10;', lang: 'java' },
        { code: 'x := 10', lang: 'go' },
        { code: 'x = 10', lang: 'python' },
        { code: '$x = 10', lang: 'php' }
      ];
      
      languages.forEach(({ code, lang }) => {
        const result = smartTextRenderer.highlightCode(code, lang);
        expect(result.language).assertEqual(lang);
        expect(result.html.length).assertGreaterThan(0);
      });
      
      TestUtils.log('多语言代码高亮测试通过');
    });
    
    /**
     * 测试富文本处理
     */
    it('should_process_rich_text', 0, () => {
      TestUtils.log('测试富文本处理');
      
      const richText = `
<div>
  <p>这是一个段落</p>
  <ul>
    <li>列表项1</li>
    <li>列表项2</li>
  </ul>
  <table>
    <tr><th>表头1</th><th>表头2</th></tr>
    <tr><td>数据1</td><td>数据2</td></tr>
  </table>
</div>
`;
      
      const result = smartTextRenderer.processRichText(richText);
      
      // 验证富文本处理结果
      expect(TestUtils.validateObjectStructure(result, ['processed', 'sanitized', 'styles'])).assertTrue();
      expect(result.processed.length).assertGreaterThan(0);
      expect(result.sanitized).assertTrue();
      
      TestUtils.log('富文本处理测试通过');
    });
    
    /**
     * 测试表情符号处理
     */
    it('should_handle_emojis', 0, () => {
      TestUtils.log('测试表情符号处理');
      
      const textWithEmojis = '你好！😊 这是一个测试 🚀 很有趣！🎉';
      const result = smartTextRenderer.processEmojis(textWithEmojis);
      
      // 验证表情符号处理
      expect(TestUtils.validateObjectStructure(result, ['processed', 'emojiCount', 'replacements'])).assertTrue();
      expect(result.emojiCount).assertEqual(3);
      expect(result.replacements.length).assertEqual(3);
      expect(result.processed.includes('<img')).assertTrue();
      
      TestUtils.log('表情符号处理测试通过');
    });
    
    /**
     * 测试链接自动检测和转换
     */
    it('should_detect_and_convert_links', 0, () => {
      TestUtils.log('测试链接自动检测和转换');
      
      const textWithLinks = '访问 https://www.example.com 查看更多信息，或者发送邮件到 user@example.com';
      const result = smartTextRenderer.processLinks(textWithLinks);
      
      // 验证链接处理
      expect(TestUtils.validateObjectStructure(result, ['processed', 'linksFound', 'linkTypes'])).assertTrue();
      expect(result.linksFound).assertEqual(2);
      expect(result.linkTypes).assertEqual(['url', 'email']);
      expect(result.processed.includes('<a href="https://www.example.com"')).assertTrue();
      expect(result.processed.includes('<a href="mailto:user@example.com"')).assertTrue();
      
      TestUtils.log('链接自动检测和转换测试通过');
    });
    
    /**
     * 测试文本截断和省略
     */
    it('should_truncate_and_ellipsize_text', 0, () => {
      TestUtils.log('测试文本截断和省略');
      
      const longText = '这是一个很长的文本，需要被截断以适应显示区域的要求。这个测试确保文本截断功能正常工作。';
      
      // 测试字符截断
      const charTruncated = smartTextRenderer.truncateText(longText, 20);
      expect(charTruncated.length).assertLessThanOrEqual(20 + 3); // +3 for ellipsis
      expect(charTruncated.includes('...')).assertTrue();
      
      // 测试单词截断
      const wordTruncated = smartTextRenderer.truncateText(longText, 25, 'word');
      expect(wordTruncated.length).assertLessThanOrEqual(25 + 3);
      expect(wordTruncated.includes('...')).assertTrue();
      
      // 测试句子截断
      const sentenceTruncated = smartTextRenderer.truncateText(longText, 30, 'sentence');
      expect(sentenceTruncated.length).assertLessThanOrEqual(30 + 3);
      
      TestUtils.log('文本截断和省略测试通过');
    });
    
    /**
     * 测试文本搜索和高亮
     */
    it('should_search_and_highlight_text', 0, () => {
      TestUtils.log('测试文本搜索和高亮');
      
      const text = '这是一个测试文本，用于测试搜索功能。搜索功能应该能够正确匹配和高亮文本。';
      const searchTerm = '搜索';
      
      const result = smartTextRenderer.searchAndHighlight(text, searchTerm);
      
      // 验证搜索结果
      expect(TestUtils.validateObjectStructure(result, ['highlighted', 'matches', 'positions'])).assertTrue();
      expect(result.matches).assertEqual(2);
      expect(result.positions.length).assertEqual(2);
      expect(result.highlighted.includes('<mark>')).assertTrue();
      expect(result.highlighted.includes('</mark>')).assertTrue();
      
      TestUtils.log('文本搜索和高亮测试通过');
    });
    
    /**
     * 测试文本方向和对齐
     */
    it('should_handle_text_direction_and_alignment', 0, () => {
      TestUtils.log('测试文本方向和对齐');
      
      const englishText = 'Hello World';
      const arabicText = 'مرحبا بالعالم';
      const mixedText = 'Hello مرحبا';
      
      // 测试文本方向检测
      const englishDirection = smartTextRenderer.detectTextDirection(englishText);
      const arabicDirection = smartTextRenderer.detectTextDirection(arabicText);
      const mixedDirection = smartTextRenderer.detectTextDirection(mixedText);
      
      expect(englishDirection).assertEqual('ltr');
      expect(arabicDirection).assertEqual('rtl');
      expect(mixedDirection).assertEqual('mixed');
      
      // 测试文本对齐
      const alignedText = smartTextRenderer.alignText(englishText, 'center');
      expect(alignedText.includes('text-align: center')).assertTrue();
      
      TestUtils.log('文本方向和对齐测试通过');
    });
    
    /**
     * 测试渲染性能优化
     */
    it('should_optimize_rendering_performance', 0, async () => {
      TestUtils.log('测试渲染性能优化');
      
      // 创建大量文本
      const largeText = '测试文本\n'.repeat(1000);
      
      // 测试分块渲染
      const chunkedResult = await smartTextRenderer.renderInChunks(largeText, 100);
      
      // 验证分块渲染结果
      expect(TestUtils.validateObjectStructure(chunkedResult, ['chunks', 'totalTime', 'averageChunkTime'])).assertTrue();
      expect(chunkedResult.chunks.length).assertEqual(10);
      expect(chunkedResult.totalTime).assertGreaterThan(0);
      expect(chunkedResult.averageChunkTime).assertGreaterThan(0);
      
      // 测试虚拟滚动优化
      const virtualScrollConfig = {
        itemHeight: 20,
        containerHeight: 200,
        totalItems: 1000,
        startIndex: 100
      };
      
      const virtualResult = smartTextRenderer.renderVirtualScroll(virtualScrollConfig);
      expect(TestUtils.validateObjectStructure(virtualResult, ['visibleItems', 'startIndex', 'endIndex', 'offset'])).assertTrue();
      expect(virtualResult.visibleItems.length).assertEqual(10);
      
      TestUtils.log('渲染性能优化测试通过');
    });
    
    /**
     * 测试配置管理
     */
    it('should_manage_configuration', 0, () => {
      TestUtils.log('测试配置管理');
      
      // 获取默认配置
      const defaultConfig = smartTextRenderer.getDefaultConfig();
      expect(TestUtils.validateObjectStructure(defaultConfig, ['theme', 'fontSize', 'lineHeight', 'codeHighlight', 'enableEmojis'])).assertTrue();
      
      // 测试配置更新
      const customConfig: RenderConfig = {
        theme: 'dark',
        fontSize: 16,
        lineHeight: 1.6,
        codeHighlight: true,
        enableEmojis: true,
        customStyles: {
          backgroundColor: '#1e1e1e',
          textColor: '#ffffff'
        }
      };
      
      smartTextRenderer.updateConfiguration(customConfig);
      
      // 验证配置更新
      const currentConfig = smartTextRenderer.getCurrentConfig();
      expect(currentConfig.theme).assertEqual('dark');
      expect(currentConfig.fontSize).assertEqual(16);
      expect(currentConfig.lineHeight).assertEqual(1.6);
      
      TestUtils.log('配置管理测试通过');
    });
    
    /**
     * 测试错误处理和容错
     */
    it('should_handle_errors_and_fault_tolerance', 0, () => {
      TestUtils.log('测试错误处理和容错');
      
      // 测试无效Markdown
      const invalidMarkdown = '# 标题\n**粗体\n*斜体';
      const result = smartTextRenderer.renderMarkdown(invalidMarkdown);
      expect(result.html.length).assertGreaterThan(0);
      
      // 测试无效代码语言
      const invalidLanguageCode = 'invalid code syntax';
      const invalidResult = smartTextRenderer.highlightCode(invalidLanguageCode, 'nonexistent');
      expect(invalidResult.html.length).assertGreaterThan(0);
      
      // 测试空输入
      const emptyResult = smartTextRenderer.renderMarkdown('');
      expect(emptyResult.html).assertEqual('');
      
      // 测试null输入
      const nullResult = smartTextRenderer.renderMarkdown(null as any);
      expect(nullResult.html).assertEqual('');
      
      TestUtils.log('错误处理和容错测试通过');
    });
    
    /**
     * 测试渲染缓存机制
     */
    it('should_cache_rendering_results', 0, async () => {
      TestUtils.log('测试渲染缓存机制');
      
      const testText = '# 测试标题\n这是测试内容';
      
      // 第一次渲染
      const result1 = await smartTextRenderer.renderWithCache(testText, 'markdown');
      const renderTime1 = result1.renderTime;
      
      // 第二次渲染（应该使用缓存）
      const result2 = await smartTextRenderer.renderWithCache(testText, 'markdown');
      const renderTime2 = result2.renderTime;
      
      // 验证缓存效果
      expect(result2.fromCache).assertTrue();
      expect(renderTime2).assertLessThan(renderTime1);
      expect(result1.html).assertEqual(result2.html);
      
      // 测试缓存统计
      const cacheStats = smartTextRenderer.getCacheStatistics();
      expect(TestUtils.validateObjectStructure(cacheStats, ['hits', 'misses', 'size', 'hitRate'])).assertTrue();
      expect(cacheStats.hits).assertGreaterThan(0);
      expect(cacheStats.misses).assertGreaterThan(0);
      
      TestUtils.log('渲染缓存机制测试通过');
    });
    
    /**
     * 测试自定义样式和主题
     */
    it('should_handle_custom_styles_and_themes', 0, () => {
      TestUtils.log('测试自定义样式和主题');
      
      const customTheme = {
        name: 'custom',
        colors: {
          primary: '#ff6b6b',
          secondary: '#4ecdc4',
          background: '#f7f7f7',
          text: '#2d3436',
          code: '#dfe6e9'
        },
        fonts: {
          heading: 'Arial',
          body: 'Georgia',
          code: 'Courier New'
        }
      };
      
      // 应用自定义主题
      smartTextRenderer.applyCustomTheme(customTheme);
      
      // 渲染测试文本
      const testText = '# 标题\n**粗体** `代码`';
      const result = smartTextRenderer.renderMarkdown(testText);
      
      // 验证自定义主题应用
      expect(result.html.includes(customTheme.colors.primary)).assertTrue();
      expect(result.html.includes(customTheme.fonts.heading)).assertTrue();
      
      TestUtils.log('自定义样式和主题测试通过');
    });
  });
}