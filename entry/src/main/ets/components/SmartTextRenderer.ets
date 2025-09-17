/**
 * 智能文本渲染器
 * 支持AI助手消息的结构化显示，包括段落分离、代码块检测等
 */
import { Logger } from '../utils/Logger';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { ThinkingStep, ThinkingStatus } from '../models/ChatModels';
import { ThinkingProcessComponent } from './ThinkingProcessComponent';

const TAG = 'SmartTextRenderer';

/**
 * 文本块类型枚举
 */
enum TextBlockType {
  PARAGRAPH = 'paragraph',    // 普通段落
  CODE_BLOCK = 'code_block',  // 代码块
  LIST_ITEM = 'list_item',    // 列表项
  LIST_GROUP = 'list_group',  // 列表组（多个连续列表项）
  HIGHLIGHT = 'highlight',    // 高亮文本
  HEADING = 'heading'         // 标题
}

/**
 * 行内格式类型
 */
interface InlineFormat {
  type: 'bold' | 'italic';
  start: number;
  end: number;
}

/**
 * 标题样式接口
 */
interface HeadingStyle {
  fontSize: number;
  fontWeight: FontWeight;
  marginTop: number;
  marginBottom: number;
}

/**
 * 文本块接口
 */
interface TextBlock {
  type: TextBlockType;
  content: string;
  indent?: number;
  language?: string; // 代码块的语言类型
  level?: number; // 标题级别 (1-4)
  inlineFormats?: InlineFormat[]; // 行内格式
  listItems?: TextBlock[]; // 列表组的子项
}

/**
 * 代码块解析结果接口
 */
interface CodeBlockResult {
  block: TextBlock | null;
  nextIndex: number;
}

/**
 * 智能文本解析器
 */
class SmartTextParser {
  // 缓存常用正则表达式，避免重复创建
  private static readonly CODE_BLOCK_REGEX = /^```/;
  private static readonly HEADING_REGEX = /^#{1,4}\s/;
  private static readonly LIST_ITEM_REGEX = /^\d+\.\s/;
  private static readonly LIST_BULLET_REGEX = /^[-•*]\s/;
  private static readonly EMPTY_LINE_REGEX = /^\s*$/;
  
  /**
   * 解析文本为结构化块
   */
  static parseText(text: string): TextBlock[] {
    if (!text || typeof text !== 'string' || text.trim() === '') {
      return [];
    }
    
    const blocks: TextBlock[] = [];
    const lines = text.split('\n');
    const lineCount = lines.length;
    let i = 0;
    
    while (i < lines.length) {
      const line = lines[i];
      
      // 检测代码块开始
      if (SmartTextParser.CODE_BLOCK_REGEX.test(line.trim())) {
        const codeBlock = SmartTextParser.parseCodeBlock(lines, i);
        if (codeBlock.block) {
          blocks.push(codeBlock.block);
          i = codeBlock.nextIndex;
          continue;
        }
      }
      
      // 跳过空行
      if (SmartTextParser.EMPTY_LINE_REGEX.test(line)) {
        i++;
        continue;
      }
      
      // 检测标题
      if (SmartTextParser.HEADING_REGEX.test(line.trim())) {
        const heading = SmartTextParser.parseHeading(line);
        blocks.push(heading);
        i++;
        continue;
      }
      
      // 检测列表项 - 收集连续的列表项合并为列表组
      const trimmedLine = line.trim();
      if (SmartTextParser.LIST_ITEM_REGEX.test(trimmedLine) || SmartTextParser.LIST_BULLET_REGEX.test(trimmedLine)) {
        const listItems: TextBlock[] = [];
        
        // 收集连续的列表项
        while (i < lines.length) {
          const currentLine = lines[i].trim();
          if (!SmartTextParser.LIST_ITEM_REGEX.test(currentLine) && !SmartTextParser.LIST_BULLET_REGEX.test(currentLine)) {
            break;
          }
          const listItem = SmartTextParser.parseListItem(lines[i]);
          listItems.push(listItem);
          i++;
        }
        
        // 创建列表组
        const listGroup: TextBlock = {
          type: TextBlockType.LIST_GROUP,
          content: '', // 列表组不需要content
          listItems: listItems
        };
        blocks.push(listGroup);
        continue;
      }
      
      // 普通段落 - 合并连续的非空行（但排除列表项和标题）
      let paragraphLines: string[] = [];
      while (i < lines.length) {
        const currentLine = lines[i];
        const trimmedCurrent = currentLine.trim();
        
        if (trimmedCurrent === '' || 
            SmartTextParser.CODE_BLOCK_REGEX.test(trimmedCurrent) ||
            SmartTextParser.LIST_ITEM_REGEX.test(trimmedCurrent) || 
            SmartTextParser.LIST_BULLET_REGEX.test(trimmedCurrent) ||
            SmartTextParser.HEADING_REGEX.test(trimmedCurrent)) {
          break;
        }
        paragraphLines.push(lines[i]);
        i++;
      }
      
      if (paragraphLines.length > 0) {
        const content = paragraphLines.join('\n').trim();
        // 解析行内格式
        const inlineFormats = SmartTextParser.parseInlineFormats(content);
        
        // 检查是否包含关键词，如果包含则标记为高亮类型
        if (SmartTextParser.containsKeywords(content)) {
          blocks.push({
            type: TextBlockType.HIGHLIGHT,
            content: content,
            inlineFormats: inlineFormats
          });
        } else {
          blocks.push({
            type: TextBlockType.PARAGRAPH,
            content: content,
            inlineFormats: inlineFormats
          });
        }
      }
    }
    
    return blocks;
  }
  
  /**
   * 解析代码块
   */
  private static parseCodeBlock(lines: string[], startIndex: number): CodeBlockResult {
    const startLine = lines[startIndex].trim();
    let language = '';
    
    // 提取语言信息
    if (startLine.length > 3) {
      language = startLine.substring(3).trim();
    }
    
    const codeLines: string[] = [];
    let i = startIndex + 1;
    
    // 查找代码块结束
    while (i < lines.length) {
      if (lines[i].trim() === '```') {
        // 找到结束标记
        const block: TextBlock = {
          type: TextBlockType.CODE_BLOCK,
          content: codeLines.join('\n'),
          language: language
        };
        const result: CodeBlockResult = {
          block: block,
          nextIndex: i + 1
        };
        return result;
      }
      codeLines.push(lines[i]);
      i++;
    }
    
    // 没有找到结束标记，当作普通文本处理
    const result: CodeBlockResult = {
      block: null,
      nextIndex: startIndex + 1
    };
    return result;
  }
  
  /**
   * 检测是否为标题
   */
  private static isHeading(line: string): boolean {
    const trimmed = line.trim();
    // 检测1-4级标题：# ## ### ####
    return /^#{1,4}\s/.test(trimmed);
  }
  
  /**
   * 解析标题
   */
  private static parseHeading(line: string): TextBlock {
    const trimmed = line.trim();
    const match = trimmed.match(/^(#{1,4})\s(.+)$/);
    
    if (!match) {
      // 如果不匹配，当作普通段落处理
      const result: TextBlock = {
        type: TextBlockType.PARAGRAPH,
        content: trimmed
      };
      return result;
    }
    
    const level = match[1].length; // # 的数量
    const content = match[2]; // 标题内容
    
    // 解析行内格式
    const inlineFormats = SmartTextParser.parseInlineFormats(content);
    
    const result: TextBlock = {
      type: TextBlockType.HEADING,
      content: content,
      level: level,
      inlineFormats: inlineFormats
    };
    return result;
  }

  /**
   * 检测是否为列表项
   */
  private static isListItem(line: string): boolean {
    const trimmed = line.trim();
    
    // 数字编号列表：1. 2. 3. 等
    if (/^\d+\.\s/.test(trimmed)) {
      return true;
    }
    
    // 符号列表：- • * 等
    if (/^[-•*]\s/.test(trimmed)) {
      return true;
    }
    
    return false;
  }
  
  /**
   * 解析列表项
   */
  private static parseListItem(line: string): TextBlock {
    const trimmed = line.trim();
    let content = '';
    let indent = 0;
    
    // 计算缩进级别（每2个空格为一级）
    const leadingSpaces = line.length - line.trimLeft().length;
    indent = Math.floor(leadingSpaces / 2);
    
    // 提取列表内容（去掉列表标记）
    if (/^\d+\.\s/.test(trimmed)) {
      // 数字列表：移除 "1. " 部分
      content = trimmed.replace(/^\d+\.\s/, '');
    } else if (/^[-•*]\s/.test(trimmed)) {
      // 符号列表：移除 "- " 部分
      content = trimmed.replace(/^[-•*]\s/, '');
    }
    
    // 解析行内格式
    const inlineFormats = SmartTextParser.parseInlineFormats(content);
    
    const result: TextBlock = {
      type: TextBlockType.LIST_ITEM,
      content: content,
      indent: indent,
      inlineFormats: inlineFormats
    };
    return result;
  }
  
  // 缓存行内解析正则表达式
  private static readonly BOLD_REGEX = /\*\*([^*]+)\*\*/g;
  private static readonly ITALIC_REGEX = /(?<!\*)\*([^*]+)\*(?!\*)/g;
  
  /**
   * 解析行内格式（粗体、斜体）
   */
  private static parseInlineFormats(text: string): InlineFormat[] {
    if (!text || text.length < 3) {
      return [];
    }
    
    const formats: InlineFormat[] = [];
    
    // 解析粗体 **文本**
    let boldMatch: RegExpExecArray | null;
    while ((boldMatch = SmartTextParser.BOLD_REGEX.exec(text)) !== null) {
      const format: InlineFormat = {
        type: 'bold',
        start: boldMatch.index,
        end: boldMatch.index + boldMatch[0].length
      };
      formats.push(format);
    }
    
    // 解析斜体 *文本* (但不包括已经被粗体匹配的部分)
    let italicMatch: RegExpExecArray | null;
    while ((italicMatch = SmartTextParser.ITALIC_REGEX.exec(text)) !== null) {
      // 检查是否与已存在的格式重叠
      const overlapping = formats.some(f => 
        (italicMatch!.index >= f.start && italicMatch!.index < f.end) ||
        (italicMatch!.index + italicMatch![0].length > f.start && italicMatch!.index + italicMatch![0].length <= f.end)
      );
      
      if (!overlapping) {
        const format: InlineFormat = {
          type: 'italic',
          start: italicMatch.index,
          end: italicMatch.index + italicMatch[0].length
        };
        formats.push(format);
      }
    }
    
    // 按位置排序
    formats.sort((a, b) => a.start - b.start);
    
    return formats;
  }

  // 缓存关键词列表，避免重复创建
  private static readonly KEYWORDS = [
    '重要', '注意', '警告', '错误', '失败', '成功', 
    'IMPORTANT', 'NOTE', 'WARNING', 'ERROR', 'FAIL', 'SUCCESS',
    '提示', '建议', 'TIP', 'SUGGESTION'
  ];
  
  /**
   * 检测文本是否包含关键词
   */
  private static containsKeywords(content: string): boolean {
    if (!content || content.length < 2) {
      return false;
    }
    
    const lowerContent = content.toLowerCase();
    return SmartTextParser.KEYWORDS.some(keyword => 
      content.includes(keyword) || lowerContent.includes(keyword.toLowerCase())
    );
  }
}

/**
 * 智能文本渲染器组件
 */
@ComponentV2
export struct SmartTextRenderer {
  @Param content: string = '';
  @Param thinkingSteps?: ThinkingStep[] = [];
  @Param thinkingStatus?: ThinkingStatus = ThinkingStatus.IDLE;
  @Local textBlocks: TextBlock[] = [];
  @Local contentHash: string = '';
  
  aboutToAppear(): void {
    this.updateTextBlocks();
  }
  
  aboutToRecycle(): void {
    // 清理缓存，避免内存泄漏
    this.textBlocks = [];
    this.contentHash = '';
  }
  
  /**
   * 计算内容哈希值，用于判断内容是否变化
   */
  private calculateContentHash(content: string): string {
    // 使用简单但有效的哈希算法
    let hash = 0;
    for (let i = 0; i < content.length; i++) {
      const char = content.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 转换为32位整数
    }
    return hash.toString(36);
  }
  
  /**
   * 更新文本块，使用缓存避免重复解析
   */
  private updateTextBlocks(): void {
    const newHash = this.calculateContentHash(this.content);
    
    if (newHash !== this.contentHash) {
      Logger.info(TAG, `内容发生变化，重新解析文本, 长度: ${this.content.length}`);
      this.textBlocks = SmartTextParser.parseText(this.content);
      this.contentHash = newHash;
      Logger.info(TAG, `解析完成, 生成了 ${this.textBlocks.length} 个文本块`);
    } else {
      Logger.debug(TAG, `内容未变化，使用缓存文本块, 数量: ${this.textBlocks.length}`);
    }
  }
  
  build() {
    Column({ space: 8 }) {
      // 首先显示思考过程（如果存在）
      if (this.thinkingSteps && this.thinkingSteps.length > 0 && this.thinkingStatus) {
        ThinkingProcessComponent({
          thinkingSteps: this.thinkingSteps,
          thinkingStatus: this.thinkingStatus,
          showDetails: true,
          compact: false,
          onStepTap: (step: ThinkingStep) => {
            // 可以添加步骤点击的交互逻辑
            Logger.info('SmartTextRenderer', `点击思考步骤: ${step.title}`);
          }
        })
      }
      
      // 然后显示文本内容
      if (this.content) {
        ForEach(this.textBlocks, (block: TextBlock, index: number) => {
          if (block.type === TextBlockType.CODE_BLOCK) {
            this.buildCodeBlock(block);
          } else if (block.type === TextBlockType.HEADING) {
            this.buildHeading(block);
          } else if (block.type === TextBlockType.LIST_GROUP) {
            this.buildListGroup(block);
          } else if (block.type === TextBlockType.LIST_ITEM) {
            this.buildListItem(block);
          } else if (block.type === TextBlockType.HIGHLIGHT) {
            this.buildHighlightText(block);
          } else {
            this.buildParagraph(block);
          }
        }, (block: TextBlock, index: number) => `${block.type}_${index}`)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          // 长按复制全文
          this.copyFullText();
        })
    )
  }
  
  /**
   * 复制完整文本内容
   */
  private copyFullText(): void {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.content);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteData).then(() => {
        Logger.info(TAG, '全文复制成功');
        promptAction.showToast({
          message: '已复制全文',
          duration: 1500
        });
      }).catch((error: Error) => {
        Logger.error(TAG, `全文复制失败: ${error.message}`);
      });
    } catch (error) {
      Logger.error(TAG, `复制全文时发生错误: ${JSON.stringify(error)}`);
    }
  }
  
  /**
   * 获取标题样式
   */
  private getHeadingStyle(level: number): HeadingStyle {
    switch (level) {
      case 1:
        return {fontSize: 20, fontWeight: FontWeight.Bold, marginTop: 8, marginBottom: 4} as HeadingStyle;
      case 2:
        return {fontSize: 18, fontWeight: FontWeight.Bold, marginTop: 6, marginBottom: 3} as HeadingStyle;
      case 3:
        return {fontSize: 17, fontWeight: FontWeight.Medium, marginTop: 4, marginBottom: 2} as HeadingStyle;
      case 4:
      default:
        return {fontSize: 16, fontWeight: FontWeight.Medium, marginTop: 2, marginBottom: 1} as HeadingStyle;
    }
  }

  /**
   * 构建标题（内部调用，传入样式参数）
   */
  @Builder
  buildHeadingWithStyle(block: TextBlock, fontSize: number, fontWeight: FontWeight, marginTop: number, marginBottom: number) {
    Column() {
      // 如果有行内格式，使用RichText，否则使用普通Text
      if (block.inlineFormats && block.inlineFormats.length > 0) {
        this.buildRichText(block.content, block.inlineFormats, fontSize, fontWeight);
      } else {
        Text(block.content)
          .fontSize(fontSize)
          .fontWeight(fontWeight)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start)
          .copyOption(CopyOptions.InApp)
          .wordBreak(WordBreak.BREAK_WORD)
          .lineHeight(fontSize * 1.3)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .margin({ top: marginTop, bottom: marginBottom })
  }
  
  /**
   * 构建标题
   */
  @Builder
  buildHeading(block: TextBlock) {
    // 根据标题级别直接构建
    if ((block.level ?? 1) === 1) {
      this.buildHeadingWithStyle(block, 20, FontWeight.Bold, 8, 4);
    } else if ((block.level ?? 1) === 2) {
      this.buildHeadingWithStyle(block, 18, FontWeight.Bold, 6, 3);
    } else if ((block.level ?? 1) === 3) {
      this.buildHeadingWithStyle(block, 17, FontWeight.Medium, 4, 2);
    } else {
      this.buildHeadingWithStyle(block, 16, FontWeight.Medium, 2, 1);
    }
  }

  /**
   * 构建代码块
   */
  @Builder
  buildCodeBlock(block: TextBlock) {
    Column({ space: 4 }) {
      // 语言标签（如果有）
      if (block.language && block.language.length > 0) {
        Text(block.language)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .fontFamily('Monaco, Consolas, monospace')
          .margin({ left: 8, bottom: 2 })
      }
      
      // 代码内容
      Text(block.content)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .fontFamily('Monaco, Consolas, monospace')
        .textAlign(TextAlign.Start)
        .copyOption(CopyOptions.InApp)
        .wordBreak(WordBreak.BREAK_WORD)
        .padding(12)
        .backgroundColor($r('app.color.code_background'))
        .borderRadius(8)
        .border({
          width: 1,
          color: $r('app.color.border_color')
        })
    }
    .alignItems(HorizontalAlign.Start)
  }
  
  /**
   * 构建列表组（多个连续列表项）
   */
  @Builder
  buildListGroup(block: TextBlock) {
    Column({ space: 2 }) { // 列表项之间很小的间距
      ForEach(block.listItems || [], (listItem: TextBlock, index: number) => {
        this.buildSingleListItem(listItem);
      }, (listItem: TextBlock, index: number) => `list_item_${index}`)
    }
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 构建单个列表项（简化版本，减少嵌套）
   */
  @Builder
  buildSingleListItem(block: TextBlock) {
    Row({ space: 8 }) {
      // 列表项目符号
      Text('•')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 2 })
      
      // 列表项内容 - 暂时强制使用Text测试间距问题
      Text(this.stripMarkdownFormats(block.content))
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Start)
        .copyOption(CopyOptions.InApp)
        .wordBreak(WordBreak.BREAK_WORD)
        .lineHeight(24)
        .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .margin({ 
      left: (block.indent ?? 0) * 16  // 根据缩进级别调整左边距
    })
  }

  /**
   * 构建列表项（保留用于兼容性）
   */
  @Builder
  buildListItem(block: TextBlock) {
    Row() {
      // 列表项目符号
      Text('•')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ right: 8, top: 2 })
      
      // 列表项内容
      Column() {
        if (block.inlineFormats && block.inlineFormats.length > 0) {
          this.buildRichText(block.content, block.inlineFormats, 16, FontWeight.Normal);
        } else {
          Text(block.content)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Start)
            .copyOption(CopyOptions.InApp)
            .wordBreak(WordBreak.BREAK_WORD)
            .lineHeight(24)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Top)
    .margin({ 
      left: (block.indent ?? 0) * 16  // 根据缩进级别调整左边距
    })
  }
  
  /**
   * 构建高亮文本
   */
  @Builder
  buildHighlightText(block: TextBlock) {
    Column() {
      if (block.inlineFormats && block.inlineFormats.length > 0) {
        this.buildRichText(block.content, block.inlineFormats, 16, FontWeight.Normal);
      } else {
        Text(block.content)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start)
          .copyOption(CopyOptions.InApp)
          .wordBreak(WordBreak.BREAK_WORD)
          .lineHeight(24)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.warning_color_10'))
    .borderRadius(8)
    .border({
      width: 1,
      color: $r('app.color.warning_color')
    })
  }
  
  /**
   * 移除Markdown格式标记（用于测试）
   */
  private stripMarkdownFormats(content: string): string {
    return content
      .replace(/\*\*(.*?)\*\*/g, '$1')  // 移除粗体标记
      .replace(/\*(.*?)\*/g, '$1');     // 移除斜体标记
  }

  /**
   * 构建带行内格式的富文本
   */
  @Builder
  buildRichText(content: string, formats: InlineFormat[], fontSize: number = 16, fontWeight: FontWeight = FontWeight.Normal) {
    RichText(this.processInlineFormats(content, formats))
      .width('100%')
      .layoutWeight(1)
      .onStart(() => {
        Logger.info(TAG, '富文本开始渲染');
      })
      .onComplete(() => {
        Logger.info(TAG, '富文本渲染完成');
      })
  }
  
  /**
   * 处理行内格式，生成HTML
   */
  private processInlineFormats(content: string, formats: InlineFormat[]): string {
    if (!formats || formats.length === 0) {
      return content;
    }
    
    let result = '';
    let lastIndex = 0;
    
    for (const format of formats) {
      // 添加格式前的普通文本
      result += content.substring(lastIndex, format.start);
      
      // 提取格式内容
      const formatContent = content.substring(format.start, format.end);
      
      // 根据格式类型包装内容
      switch (format.type) {
        case 'bold':
          // 移除Markdown标记 **text** -> text
          const boldText = formatContent.replace(/\*\*(.*?)\*\*/g, '$1');
          result += `<b>${boldText}</b>`;
          break;
        case 'italic':
          // 移除Markdown标记 *text* -> text
          const italicText = formatContent.replace(/\*(.*?)\*/g, '$1');
          result += `<i>${italicText}</i>`;
          break;
      }
      
      lastIndex = format.end;
    }
    
    // 添加剩余的普通文本
    result += content.substring(lastIndex);
    
    return result;
  }

  /**
   * 构建普通段落
   */
  @Builder
  buildParagraph(block: TextBlock) {
    if (block.inlineFormats && block.inlineFormats.length > 0) {
      this.buildRichText(block.content, block.inlineFormats, 16, FontWeight.Normal);
    } else {
      Text(block.content)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Start)
        .copyOption(CopyOptions.InApp)
        .wordBreak(WordBreak.BREAK_WORD)
        .lineHeight(24)
    }
  }
}