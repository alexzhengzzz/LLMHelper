/**
 * 工具调用状态展示组件
 * 用于显示AI消息中的工具调用状态信息
 */

import { Message, MessageRole } from '../models/ChatModels';
import { Logger } from '../utils/Logger';

/**
 * 工具调用状态枚举
 */
export enum ToolCallStatus {
  IDLE = 'idle',        // 空闲状态
  CALLING = 'calling',  // 调用中
  COMPLETED = 'completed', // 调用完成
  FAILED = 'failed'     // 调用失败
}

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
    switch (this.message.toolStatus) {
      case ToolCallStatus.CALLING:
        if (this.message.webUsed) {
          return '🔍 正在搜索网络信息...';
        }
        return '⚙️ 正在调用工具...';
      case ToolCallStatus.COMPLETED:
        if (this.message.webUsed) {
          return '✅ 搜索完成';
        }
        return '✅ 工具调用完成';
      case ToolCallStatus.FAILED:
        return '❌ 工具调用失败';
      default:
        return '';
    }
  }

  /**
   * 获取工具调用状态图标
   */
  private getToolStatusIcon(): string {
    switch (this.message.toolStatus) {
      case ToolCallStatus.CALLING:
        return this.message.webUsed ? '🔍' : '⚙️';
      case ToolCallStatus.COMPLETED:
        return '✅';
      case ToolCallStatus.FAILED:
        return '❌';
      default:
        return '';
    }
  }

  /**
   * 获取工具调用状态颜色
   */
  private getToolStatusColor(): ResourceStr {
    switch (this.message.toolStatus) {
      case ToolCallStatus.CALLING:
        return $r('app.color.primary_color');
      case ToolCallStatus.COMPLETED:
        return '#4CAF50'; // 绿色
      case ToolCallStatus.FAILED:
        return $r('app.color.error_color');
      default:
        return $r('app.color.text_secondary');
    }
  }

  /**
   * 是否应该显示动画
   */
  private shouldShowAnimation(): boolean {
    return this.message.toolStatus === ToolCallStatus.CALLING;
  }

  /**
   * 构建工具调用状态卡片
   */
  @Builder
  buildToolStatusCard() {
    // 显示工具调用状态或网络搜索信息
    if (this.shouldShowToolStatus() || this.shouldShowSearchInfo()) {
      Column({ space: 4 }) {
        // 工具调用状态行
        if (this.shouldShowToolStatus()) {
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
          }
        }

        // 搜索信息行（在完成状态时显示）
        if (this.shouldShowSearchInfo()) {
          Row({ space: 6 }) {
            Text('🔍')
              .fontSize(12)
            Text(this.truncateSearchInfo(this.message.searchInfo || ''))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
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
    return !!(this.message.toolStatus && this.message.toolStatus !== ToolCallStatus.IDLE);
  }

  /**
   * 是否应该显示搜索信息
   */
  private shouldShowSearchInfo(): boolean {
    return !!(this.message.webUsed && this.message.searchInfo &&
      this.message.toolStatus === ToolCallStatus.COMPLETED);
  }

  /**
   * 截断搜索信息以适合显示
   */
  private truncateSearchInfo(searchInfo: string): string {
    if (!searchInfo) return '';
    const maxLength = 60;
    return searchInfo.length > maxLength ?
      searchInfo.substring(0, maxLength) + '...' : searchInfo;
  }

  /**
   * 获取工具调用状态背景色
   */
  private getToolStatusBackgroundColor(): ResourceStr {
    switch (this.message.toolStatus) {
      case ToolCallStatus.CALLING:
        return 'rgba(33, 150, 243, 0.1)'; // 蓝色背景
      case ToolCallStatus.COMPLETED:
        return 'rgba(76, 175, 80, 0.1)'; // 绿色背景
      case ToolCallStatus.FAILED:
        return 'rgba(244, 67, 54, 0.1)'; // 红色背景
      default:
        return $r('app.color.card_background');
    }
  }

  /**
   * 处理工具状态点击事件
   */
  private handleToolStatusClick(): void {
    Logger.info('ToolCallStatusComponent', `工具状态被点击: ${this.message.toolStatus}`);

    // 如果是网络搜索相关，显示搜索详情
    if (this.message.webUsed && (this.message.searchDetails || this.message.searchInfo)) {
      Logger.info('ToolCallStatusComponent', '显示搜索详情');

      // 优先使用详细信息，否则使用简化信息
      const detailsToShow = this.message.searchDetails || this.message.searchInfo || '';

      if (detailsToShow && this.onSearchDetailsClick) {
        this.onSearchDetailsClick(detailsToShow);
      }
    }
  }

  build() {
    this.buildToolStatusCard()
  }
}