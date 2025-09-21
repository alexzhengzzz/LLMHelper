/**
 * 深度思考指示器组件 - 在聊天界面中简洁显示
 */

import { ThinkingStep, ThinkingStatus, StepStatus, Message } from '../models/ChatModels';
import { ThinkingProgressComponent } from './ThinkingProgressComponent';

// 指示器参数
@ObservedV2
class ThinkingIndicatorParams {
  @Trace message: Message | null = null;
  @Trace compact: boolean = true;
}

@ComponentV2
export struct DeepThinkingIndicator {
  @Param @Require message: Message;
  @Param compact: boolean = true;
  @Param onTap: () => void = () => {};
  @Param onStop: () => void = () => {};

  @Local currentStatus: ThinkingStatus = ThinkingStatus.IDLE;
  @Local progressText: string = '';

  aboutToAppear() {
    this.updateStatus();
  }

  build() {
    if (this.message.isDeepThinking && this.message.thinkingStatus !== ThinkingStatus.IDLE) {
      Row() {
        // 主要内容
        Row() {
          // 状态图标和进度
          this.buildStatusSection()
          
          // 进度文本
          if (!this.compact) {
            Text(this.progressText)
              .fontSize(11)
              .fontColor('#666')
              .margin({ left: 6 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .constraintSize({ maxWidth: '100%' })

        // 操作按钮
        if (!this.compact) {
          this.buildActionButtons()
        }
      }
      .width('100%')
      .constraintSize({ 
        maxWidth: '100%',
        minHeight: this.compact ? 32 : 40
      })
      .padding({
        left: this.compact ? 6 : 8,
        right: this.compact ? 6 : 8,
        top: this.compact ? 4 : 6,
        bottom: this.compact ? 4 : 6
      })
      .backgroundColor(this.getBackgroundColor())
      .borderRadius(this.compact ? 6 : 8)
      .border({
        width: 1,
        color: this.getBorderColor()
      })
      .clip(true)
      .onClick(() => {
        this.onTap();
      })
    }
  }

  @Builder
  private buildStatusSection() {
    Row() {
      // 进度指示器
      if (this.compact) {
        ThinkingProgressComponent({
          thinkingSteps: this.message.thinkingSteps || [],
          thinkingStatus: this.message.thinkingStatus,
          progressSize: 'small',
          showText: false
        })
          .margin({ right: 4 })
          .width('100%')
          .height(24)
      } else {
        ThinkingProgressComponent({
          thinkingSteps: this.message.thinkingSteps || [],
          thinkingStatus: this.message.thinkingStatus,
          progressSize: 'medium',
          showText: false
        })
          .margin({ right: 6 })
          .width(32)
          .height(32)
      }

      // 状态文本
      Column() {
        Text(this.getStatusTitle())
          .fontSize(this.compact ? 10 : 11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '100%' })

        // 步骤进度
        if (this.message.thinkingSteps && this.message.thinkingSteps.length > 0) {
          Text(`${this.getCompletedStepsCount()}/${this.message.thinkingSteps.length}`)
            .fontSize(this.compact ? 8 : 9)
            .fontColor('#666')
            .margin({ top: 1 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ maxWidth: '100%' })
      .layoutWeight(1)
    }
    .constraintSize({ maxWidth: '100%' })
  }

  @Builder
  private buildActionButtons() {
    Row() {
      // 停止按钮（仅在思考进行中显示）
      if (this.message.thinkingStatus !== ThinkingStatus.COMPLETED && 
          this.message.thinkingStatus !== ThinkingStatus.FAILED &&
          this.message.thinkingStatus !== ThinkingStatus.CANCELLED) {
        Button() {
          Text('⏹️')
            .fontSize(10)
        }
        .width(20)
        .height(20)
        .backgroundColor('#FEE2E2')
        .borderRadius(10)
        .onClick(() => {
          this.onStop();
        })
        .margin({ right: 4 })
      }

      // 查看详情按钮
      Button() {
        Text('详情')
          .fontSize(9)
          .fontColor($r('app.color.primary_color'))
      }
        .width(40)
        .height(20)
        .backgroundColor('#EFF6FF')
        .borderRadius(10)
        .onClick(() => {
          this.onTap();
        })
    }
    .constraintSize({ maxWidth: '100%' })
  }

  // 工具方法
  private updateStatus(): void {
    this.currentStatus = this.message.thinkingStatus || ThinkingStatus.IDLE;
    this.progressText = this.getProgressText();
  }

  private getCompletedStepsCount(): number {
    if (!this.message.thinkingSteps) return 0;
    return this.message.thinkingSteps.filter(s => s.status === StepStatus.COMPLETED).length;
  }

  private getStatusTitle(): string {
    switch (this.currentStatus) {
      case ThinkingStatus.PLANNING: return '🗺️ 思路规划中';
      case ThinkingStatus.ANALYZING: return '🔍 深度分析中';
      case ThinkingStatus.RESEARCHING: return '🌐 资料检索中';
      case ThinkingStatus.THINKING: return '🧠 多角度思考中';
      case ThinkingStatus.VERIFYING: return '✅ 批判性验证中';
      case ThinkingStatus.INTEGRATING: return '🎯 综合整合中';
      case ThinkingStatus.REFINING: return '🔁 质量复盘中';
      case ThinkingStatus.COMPLETED: return '✨ 思考完成';
      case ThinkingStatus.FAILED: return '❌ 思考失败';
      case ThinkingStatus.CANCELLED: return '⏹️ 思考取消';
      default: return '💭 准备思考';
    }
  }

  private getProgressText(): string {
    if (!this.message.thinkingSteps || this.message.thinkingSteps.length === 0) {
      return '正在准备深度思考...';
    }

    const completedSteps = this.message.thinkingSteps.filter(s => s.status === StepStatus.COMPLETED).length;
    const totalSteps = this.message.thinkingSteps.length;
    
    if (this.currentStatus === ThinkingStatus.COMPLETED) {
      return `深度思考完成，耗时 ${this.getTotalDuration().toFixed(1)}s`;
    } else if (this.currentStatus === ThinkingStatus.FAILED) {
      return `深度思考失败，完成 ${completedSteps}/${totalSteps} 步`;
    } else {
      return `正在进行深度思考 (${completedSteps}/${totalSteps})`;
    }
  }

  private getTotalDuration(): number {
    if (!this.message.thinkingSteps) return 0;
    
    return this.message.thinkingSteps
      .filter(s => s.duration)
      .reduce((total, step) => total + (step.duration || 0), 0) / 1000;
  }

  private getBackgroundColor(): string {
    switch (this.currentStatus) {
      case ThinkingStatus.COMPLETED:
        return '#F0FDF4'; // 绿色背景
      case ThinkingStatus.FAILED:
      case ThinkingStatus.CANCELLED:
        return '#FEF2F2'; // 红色背景
      default:
        return '#F8F9FF'; // 蓝色背景
    }
  }

  private getBorderColor(): string {
    switch (this.currentStatus) {
      case ThinkingStatus.COMPLETED:
        return '#86EFAC'; // 绿色边框
      case ThinkingStatus.FAILED:
      case ThinkingStatus.CANCELLED:
        return '#FECACA'; // 红色边框
      default:
        return '#C7D2FE'; // 蓝色边框
    }
  }

  private getTextColor(): string {
    switch (this.currentStatus) {
      case ThinkingStatus.COMPLETED:
        return '#166534'; // 绿色文字
      case ThinkingStatus.FAILED:
      case ThinkingStatus.CANCELLED:
        return '#991B1B'; // 红色文字
      default:
        return '#3730A3'; // 蓝色文字
    }
  }

}
