/**
 * 工具调用状态展示组件
 * 用于显示AI消息中的工具调用状态信息
 */

import { Message, MessageRole } from '../models/ChatModels';
import { Logger } from '../utils/Logger';

/**
 * 工具调用状态组件
 */
@ComponentV2
export struct ToolCallStatusComponent {
  @Param message: Message = new Message(MessageRole.ASSISTANT, '');
  @Param onSearchDetailsClick: ((searchDetails: string) => void) | undefined = undefined;

  /**
   * 获取工具调用状态文本
   */
  private getToolStatusText(): string {
    const toolNames = this.getMCPToolNamesText();

    switch (this.message.toolStatus) {
      case 'calling':
        return this.getCallingStatusText() + toolNames;
      case 'completed':
        return this.getCompletedStatusText() + toolNames;
      case 'failed':
        return this.getFailedStatusText() + toolNames;
      default:
        return '';
    }
  }

  /**
   * 获取MCP工具名称文本
   */
  private getMCPToolNamesText(): string {
    if (this.message.mcpToolNames && this.message.mcpToolNames.length > 0) {
      // 最多显示前3个工具名称，每个名称最多30字符（足够显示calculator、app_launcher等）
      const toolsToShow = this.message.mcpToolNames.slice(0, 3).map(name => {
        return name.length > 30 ? name.substring(0, 27) + '...' : name;
      });
      const hasMore = this.message.mcpToolNames.length > 3;
      const toolNamesStr = toolsToShow.join(', ');
      const moreText = hasMore ? ` +${this.message.mcpToolNames.length - 3}` : '';
      return `: ${toolNamesStr}${moreText}`;
    }
    // 在调用状态下，如果还没有实际执行的工具，不显示工具名称
    if (this.message.toolStatus === 'calling') {
      return '';
    }
    // 向后兼容，如果没有mcpToolNames，使用原有的toolName
    return this.message.toolName ? `: ${this.message.toolName}` : '';
  }

  /**
   * 获取调用中状态文本
   */
  private getCallingStatusText(): string {
    // 只处理MCP工具类型
    if (this.message.toolType === 'mcp') {
      return '🔧 正在执行MCP工具';
    }
    return '';
  }

  /**
   * 获取完成状态文本
   */
  private getCompletedStatusText(): string {
    // 只处理MCP工具类型（图标已经显示✅，文本不需要重复显示）
    if (this.message.toolType === 'mcp') {
      return 'MCP';
    }
    return '';
  }

  /**
   * 获取失败状态文本
   */
  private getFailedStatusText(): string {
    // 只处理MCP工具类型（图标已经显示❌，文本不需要重复显示）
    if (this.message.toolType === 'mcp') {
      return 'MCP';
    }
    return '';
  }

  /**
   * 获取工具调用状态图标
   */
  private getToolStatusIcon(): string {
    switch (this.message.toolStatus) {
      case 'calling':
        return this.getCallingIcon();
      case 'completed':
        return '✅';
      case 'failed':
        return '❌';
      default:
        return '';
    }
  }

  /**
   * 获取调用中状态图标
   */
  private getCallingIcon(): string {
    // 只处理MCP工具类型
    if (this.message.toolType === 'mcp') {
      return '🔧';
    }
    return '';
  }

  /**
   * 获取工具调用状态颜色
   */
  private getToolStatusColor(): ResourceStr {
    switch (this.message.toolStatus) {
      case 'calling':
        return $r('app.color.primary_color');
      case 'completed':
        return '#4CAF50'; // 绿色
      case 'failed':
        return $r('app.color.error_color');
      default:
        return $r('app.color.text_secondary');
    }
  }

  /**
   * 是否应该显示动画
   */
  private shouldShowAnimation(): boolean {
    return this.message.toolStatus === 'calling';
  }

  /**
   * 构建工具调用状态卡片
   */
  @Builder
  buildToolStatusCard() {
    // 只显示MCP工具调用状态
    if (this.shouldShowToolStatus()) {
      Column({ space: 4 }) {
        // MCP工具调用状态行
        Row({ space: 8 }) {
          // 状态图标
          Text(this.getToolStatusIcon())
            .fontSize(14)
            .animation({
              duration: this.shouldShowAnimation() ? 1000 : 0,
              curve: Curve.EaseInOut,
              iterations: this.shouldShowAnimation() ? -1 : 1,
              playMode: PlayMode.Alternate
            })
            .scale({
              x: this.shouldShowAnimation() ? 1.2 : 1.0,
              y: this.shouldShowAnimation() ? 1.2 : 1.0
            })

          // 状态文本
          Text(this.getToolStatusText())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getToolStatusColor())
            .opacity(this.shouldShowAnimation() ? 0.8 : 1.0)
            .animation({
              duration: this.shouldShowAnimation() ? 1500 : 0,
              curve: Curve.EaseInOut,
              iterations: this.shouldShowAnimation() ? -1 : 1,
              playMode: PlayMode.Alternate
            })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
      }
      .padding({ top: 6, bottom: 6, left: 12, right: 12 })
      .backgroundColor(this.getToolStatusBackgroundColor())
      .borderRadius(16)
      .border({
        width: 1,
        color: this.getToolStatusColor()
      })
      .margin({ top: 8, bottom: 4 })
      .onClick(() => {
        this.handleToolStatusClick();
      })
      .gesture(
        TapGesture({ count: 1 })
          .onAction(() => {
            this.handleToolStatusClick();
          })
      )
    } else {
      Blank()
        .width(0)
        .height(0)
    }
  }

  /**
   * 是否应该显示工具调用状态
   */
  private shouldShowToolStatus(): boolean {
    // 只显示MCP工具调用状态，排除网络搜索和其他工具类型
    return !!(this.message.toolStatus &&
              this.message.toolStatus !== 'idle' &&
              this.message.toolType === 'mcp');
  }


  /**
   * 获取工具调用状态背景色
   */
  private getToolStatusBackgroundColor(): ResourceStr {
    switch (this.message.toolStatus) {
      case 'calling':
        return 'rgba(33, 150, 243, 0.1)'; // 蓝色背景
      case 'completed':
        return 'rgba(76, 175, 80, 0.1)'; // 绿色背景
      case 'failed':
        return 'rgba(244, 67, 54, 0.1)'; // 红色背景
      default:
        return $r('app.color.card_background');
    }
  }

  /**
   * 处理工具状态点击事件
   */
  private handleToolStatusClick(): void {
    if (this.message.mcpToolNames && this.message.mcpToolNames.length > 0) {
      const toolsList = this.message.mcpToolNames.join(', ');
      Logger.info('ToolCallStatusComponent', `MCP工具状态被点击: ${this.message.toolStatus}, 工具列表: ${toolsList}`);

      // 可以在未来添加详细信息显示，比如弹出对话框显示所有工具名称和执行结果
      // 目前仅记录日志以供调试
    } else {
      Logger.info('ToolCallStatusComponent', `MCP工具状态被点击: ${this.message.toolStatus}`);
    }
  }

  build() {
    this.buildToolStatusCard()
  }
}