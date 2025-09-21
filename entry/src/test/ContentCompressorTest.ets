import { describe, beforeAll, afterAll, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import ContentCompressor from '../../main/ets/services/ContentCompressor';

export default function ContentCompressorTest() {
  describe('ContentCompressorTest', () => {
    let compressor: ContentCompressor;

    beforeAll(() => {
      // 初始化测试环境
      compressor = new ContentCompressor();
    });

    afterAll(() => {
      // 清理测试环境
      compressor = null;
    });

    beforeEach(() => {
      // 重置压缩器状态
      if (compressor) {
        compressor.reset();
      }
    });

    afterEach(() => {
      // 清理测试数据
    });

    it('should initialize with default configuration', () => {
      const config = compressor.getConfig();
      expect(config.maxInputLength).assertEqual(10000);
      expect(config.compressionRatio).assertEqual(0.7);
      expect(config.enableSmartCompression).assertTrue();
      expect(config.preserveKeywords).assertEqual(true);
    });

    it('should compress short text without changes', () => {
      const shortText = 'Hello, world!';
      const compressed = compressor.compress(shortText);

      expect(compressed).assertEqual(shortText);
      expect(compressed.length).assertEqual(shortText.length);
    });

    it('should compress long text', () => {
      const longText = 'a'.repeat(5000);
      const compressed = compressor.compress(longText);

      expect(compressed.length).assertLess(longText.length);
      expect(compressed.length).assertLess(longText.length * 0.8);
    });

    it('should preserve important keywords', () => {
      const textWithKeywords = 'This is important information about ERROR handling and API calls. The ERROR should be logged properly.';
      const compressed = compressor.compress(textWithKeywords);

      expect(compressed).assertContain('ERROR');
      expect(compressed).assertContain('API');
    });

    it('should handle empty input', () => {
      const compressed = compressor.compress('');
      expect(compressed).assertEqual('');
    });

    it('should handle null input', () => {
      const compressed = compressor.compress(null);
      expect(compressed).assertEqual('');
    });

    it('should handle undefined input', () => {
      const compressed = compressor.compress(undefined);
      expect(compressed).assertEqual('');
    });

    it('should remove redundant whitespace', () => {
      const textWithExtraSpaces = 'This    has    extra    spaces';
      const compressed = compressor.compress(textWithExtraSpaces);

      expect(compressed).assertEqual('This has extra spaces');
    });

    it('should remove duplicate lines', () => {
      const textWithDuplicates = 'Line 1\nLine 2\nLine 1\nLine 3\nLine 2';
      const compressed = compressor.compress(textWithDuplicates);

      const lines = compressed.split('\n');
      expect(lines.length).assertLess(5);
    });

    it('should preserve code blocks', () => {
      const textWithCode = 'Here is some code:\n```javascript\nfunction test() {\n  return true;\n}\n```\nAnd some explanation.';
      const compressed = compressor.compress(textWithCode);

      expect(compressed).assertContain('```javascript');
      expect(compressed).assertContain('function test()');
      expect(compressed).assertContain('return true');
    });

    it('should compress repetitive content', () => {
      const repetitiveText = 'Important message: ' + 'repeated '.repeat(100) + ' end';
      const compressed = compressor.compress(repetitiveText);

      expect(compressed.length).assertLess(repetitiveText.length * 0.5);
      expect(compressed).assertContain('Important message');
      expect(compressed).assertContain('end');
    });

    it('should handle mixed content types', () => {
      const mixedContent = 'Title\n\nSubtitle\n\nParagraph with some text.\n\n* List item 1\n* List item 2\n\nCode:\n```python\nprint("hello")\n```';
      const compressed = compressor.compress(mixedContent);

      expect(compressed).assertContain('Title');
      expect(compressed).assertContain('List item');
      expect(compressed).assertContain('print("hello")');
    });

    it('should preserve URLs and links', () => {
      const textWithURLs = 'Visit https://example.com for more info. Also check http://test.org.';
      const compressed = compressor.compress(textWithURLs);

      expect(compressed).assertContain('https://example.com');
      expect(compressed).assertContain('http://test.org');
    });

    it('should handle markdown formatting', () => {
      const markdownText = '# Header\n## Subheader\n**Bold text** *Italic text*\n- List item\n- Another item';
      const compressed = compressor.compress(markdownText);

      expect(compressed).assertContain('# Header');
      expect(compressed).assertContain('**Bold text**');
      expect(compressed).assertContain('*Italic text*');
    });

    it('should compress while preserving structure', () => {
      const structuredText = 'Section 1\n\nContent for section 1.\n\nSection 2\n\nContent for section 2.\n\nSection 3\n\nContent for section 3.';
      const compressed = compressor.compress(structuredText);

      expect(compressed).assertContain('Section 1');
      expect(compressed).assertContain('Section 2');
      expect(compressed).assertContain('Section 3');
    });

    it('should handle very long text', () => {
      const veryLongText = 'a'.repeat(20000);
      const compressed = compressor.compress(veryLongText);

      expect(compressed.length).assertLess(veryLongText.length);
      expect(compressed.length).assertLess(veryLongText.length * 0.3);
    });

    it('should respect maximum input length', () => {
      const excessiveText = 'a'.repeat(15000);
      const compressed = compressor.compress(excessiveText);

      expect(compressed.length).assertLessEqual(10000);
    });

    it('should provide compression statistics', () => {
      const originalText = 'This is a test text for compression. ' + 'repeated '.repeat(50) + ' end';
      const compressed = compressor.compress(originalText);

      const stats = compressor.getCompressionStats(originalText, compressed);
      expect(stats.originalLength).assertEqual(originalText.length);
      expect(stats.compressedLength).assertEqual(compressed.length);
      expect(stats.compressionRatio).assertGreaterThan(0);
      expect(stats.compressionRatio).assertLess(1);
    });

    it('should handle custom compression configuration', () => {
      const customConfig = {
        maxInputLength: 5000,
        compressionRatio: 0.5,
        enableSmartCompression: false,
        preserveKeywords: false
      };

      compressor.configure(customConfig);
      const config = compressor.getConfig();

      expect(config.maxInputLength).assertEqual(5000);
      expect(config.compressionRatio).assertEqual(0.5);
      expect(config.enableSmartCompression).assertFalse();
      expect(config.preserveKeywords).assertFalse();
    });

    it('should batch compress multiple texts', () => {
      const texts = [
        'First text content',
        'Second text content with more words',
        'Third text content that is longer than the others'
      ];

      const compressed = compressor.batchCompress(texts);
      expect(compressed.length).assertEqual(texts.length);

      compressed.forEach((text, index) => {
        expect(text.length).assertLessEqual(texts[index].length);
      });
    });

    it('should handle special characters and Unicode', () => {
      const unicodeText = 'Hello 世界! 🌟 Special chars: @#$%^&*()';
      const compressed = compressor.compress(unicodeText);

      expect(compressed).assertContain('Hello 世界');
      expect(compressed).assertContain('🌟');
    });

    it('should handle JSON content', () => {
      const jsonText = JSON.stringify({
        key1: 'value1',
        key2: 'value2',
        nested: {
          inner: 'value'
        }
      });

      const compressed = compressor.compress(jsonText);
      expect(compressed).assertContain('key1');
      expect(compressed).assertContain('value1');
      expect(compressed).assertContain('nested');
    });

    it('should handle XML/HTML content', () => {
      const xmlText = '<root><item>Value 1</item><item>Value 2</item></root>';
      const compressed = compressor.compress(xmlText);

      expect(compressed).assertContain('<root>');
      expect(compressed).assertContain('<item>');
      expect(compressed).assertContain('Value 1');
    });

    it('should preserve error messages and stack traces', () => {
      const errorText = 'Error: Something went wrong\n    at Function.test (/path/to/file.js:10:5)\n    at Module.runMain (internal/modules/run_main.js:17:47)';
      const compressed = compressor.compress(errorText);

      expect(compressed).assertContain('Error: Something went wrong');
      expect(compressed).assertContain('file.js:10:5');
    });

    it('should handle performance metrics', () => {
      const performanceMetrics = compressor.getPerformanceMetrics();
      expect(performanceMetrics).hasOwnProperty('compressionTime');
      expect(performanceMetrics).hasOwnProperty('memoryUsage');
      expect(performanceMetrics).hasOwnProperty('totalCompressed');
    });

    it('should reset compressor state', () => {
      compressor.configure({
        maxInputLength: 2000,
        compressionRatio: 0.3,
        enableSmartCompression: false
      });

      compressor.reset();
      const config = compressor.getConfig();

      expect(config.maxInputLength).assertEqual(10000);
      expect(config.compressionRatio).assertEqual(0.7);
      expect(config.enableSmartCompression).assertTrue();
    });

    it('should handle edge cases', () => {
      // 测试只有空白字符的输入
      expect(compressor.compress('   ')).assertEqual('');

      // 测试只有换行符的输入
      expect(compressor.compress('\n\n\n')).assertEqual('');

      // 测试混合空白字符
      expect(compressor.compress('  \n  \t  \n  ')).assertEqual('');

      // 测试单个字符
      expect(compressor.compress('a')).assertEqual('a');
    });

    it('should validate input parameters', () => {
      // 测试无效的压缩比例
      compressor.configure({ compressionRatio: -0.5 });
      expect(compressor.getConfig().compressionRatio).assertEqual(0.1); // 应该回退到最小值

      compressor.configure({ compressionRatio: 2.0 });
      expect(compressor.getConfig().compressionRatio).assertEqual(0.9); // 应该回退到最大值
    });
  });
}