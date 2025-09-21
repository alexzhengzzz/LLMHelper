/**
 * 深度思考过程内嵌状态卡片
 */

import { Message, ThinkingStatus, ThinkingStep, StepStatus } from '../models/ChatModels';
import { ThinkingProgressComponent } from './ThinkingProgressComponent';
import { Logger } from '../utils/Logger';

@ComponentV2
export struct DeepThinkingStatusCard {
  @Param @Require message: Message;
  @Param onShowDetails: () => void = () => {};
  @Param onStop: () => void = () => {};

  build() {
    if (!this.message.isDeepThinking) {
      Blank();
    } else {
      Column({ space: 12 }) {
        this.buildHeader()
        this.buildStepsSection()
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .backgroundColor(this.getCardBackground(this.message.thinkingStatus || ThinkingStatus.IDLE))
      .borderRadius(12)
      .border({
        width: 1,
        color: this.getCardBorder(this.message.thinkingStatus || ThinkingStatus.IDLE)
      })
    }
  }

  @Builder
  private buildHeader() {
    Row({ space: 12 }) {
      if ((this.message.thinkingStatus || ThinkingStatus.IDLE) === ThinkingStatus.IDLE) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color('#6366F1')
      } else {
        ThinkingProgressComponent({
          thinkingSteps: this.getSteps(),
          thinkingStatus: this.message.thinkingStatus || ThinkingStatus.IDLE,
          progressSize: 'medium',
          showText: false,
          showPercentage: false,
          animated: true
        })
          .width(36)
          .height(36)
      }

      Column({ space: 2 }) {
        Text(this.getStatusTitle(this.message.thinkingStatus || ThinkingStatus.IDLE))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getStatusColor(this.message.thinkingStatus || ThinkingStatus.IDLE))

        Text(this.getStatusSummary())
          .fontSize(11)
          .fontColor('#6B7280')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 6 }) {
        if (this.message.thinkingStatus !== ThinkingStatus.COMPLETED &&
            this.message.thinkingStatus !== ThinkingStatus.FAILED &&
            this.message.thinkingStatus !== ThinkingStatus.CANCELLED) {
          Button() {
            Text('停止')
              .fontSize(11)
              .fontColor('#B91C1C')
          }
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor('#FEE2E2')
          .borderRadius(14)
          .border({ width: 1, color: '#FCA5A5' })
          .onClick(() => {
            this.onStop();
          })
        }

        Button() {
          Text('详情')
            .fontSize(11)
            .fontColor(this.getDetailButtonColor(this.message.thinkingStatus || ThinkingStatus.IDLE))
        }
        .height(28)
        .padding({ left: 12, right: 12 })
        .backgroundColor(this.getDetailButtonBackground(this.message.thinkingStatus || ThinkingStatus.IDLE))
        .borderRadius(14)
        .border({ width: 1, color: this.getDetailButtonBorder(this.message.thinkingStatus || ThinkingStatus.IDLE) })
        .onClick(() => {
          this.onShowDetails();
        })
      }
    }
  }

  @Builder
  private buildStepsSection() {
    Column({ space: 8 }) {
      ForEach(this.getSteps(), (step: ThinkingStep, index: number) => {
        this.buildStepItem(step, index)
      })
      if (this.getSteps().length === 0) {
        this.buildEmptyStepsPlaceholder()
      }
    }
  }

  @Builder
  private buildEmptyStepsPlaceholder() {
    Row({ space: 8 }) {
      LoadingProgress()
        .width(18)
        .height(18)

      Text('正在生成推理步骤...')
        .fontSize(12)
        .fontColor('#4B5563')
    }
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor('rgba(79, 70, 229, 0.08)')
    .borderRadius(8)
  }

  @Builder
  private buildStepItem(step: ThinkingStep, index: number) {
    Row({ space: 10 }) {
      Text(`${index + 1}`)
        .fontSize(10)
        .fontColor('#FFFFFF')
        .width(18)
        .height(18)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.getStepAccentColor(step.status))
        .borderRadius(9)

      Column({ space: 4 }) {
        Row({ space: 4 }) {
          Text(this.getStepStatusIcon(step.status))
            .fontSize(12)

          Text(step.title)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2937')
            .flexGrow(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (step.duration) {
            Text(`${(step.duration / 1000).toFixed(1)}s`)
              .fontSize(11)
              .fontColor('#9CA3AF')
          }
        }
        .width('100%')

        if (step.status === StepStatus.PROCESSING) {
          Text('进行中，正在生成内容...')
            .fontSize(11)
            .fontColor('#4338CA')
        } else if (step.status === StepStatus.COMPLETED && step.content) {
          Text(step.content)
            .fontSize(11)
            .fontColor('#4B5563')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (step.status === StepStatus.FAILED && step.error) {
          Text(`失败：${step.error}`)
            .fontSize(11)
            .fontColor('#B91C1C')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (step.description) {
          Text(step.description)
            .fontSize(11)
            .fontColor('#6B7280')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
    }
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .backgroundColor(this.getStepBackground(step.status))
    .borderRadius(10)
    .border({ width: 1, color: this.getStepBorder(step.status) })
  }

  
  private getSteps(): ThinkingStep[] {
    return this.message.thinkingSteps || [];
  }

  
  private getStatusTitle(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.PLANNING: return '🗺️ 思路规划';
      case ThinkingStatus.ANALYZING: return '🔍 深度分析';
      case ThinkingStatus.RESEARCHING: return '🌐 资料检索';
      case ThinkingStatus.THINKING: return '🧠 多角度思考';
      case ThinkingStatus.VERIFYING: return '✅ 批判性验证';
      case ThinkingStatus.INTEGRATING: return '🎯 综合整合';
      case ThinkingStatus.REFINING: return '🔁 质量复盘';
      case ThinkingStatus.COMPLETED: return '✨ 深度思考完成';
      case ThinkingStatus.FAILED: return '❌ 思考失败';
      case ThinkingStatus.CANCELLED: return '⏹️ 思考已取消';
      default: return '💭 准备深度思考';
    }
  }

  private getStatusSummary(): string {
    const steps = this.getSteps();
    if (steps.length === 0) {
      return '正在初始化推理链路';
    }

    const completed = steps.filter(step => step.status === StepStatus.COMPLETED).length;
    const failed = steps.filter(step => step.status === StepStatus.FAILED).length;
    const totalDuration = steps
      .filter(step => step.duration)
      .reduce((sum, step) => sum + (step.duration || 0), 0);

    const durationText = totalDuration > 0 ? ` | 耗时 ${(totalDuration / 1000).toFixed(1)}s` : '';
    const failureText = failed > 0 ? ` | 失败 ${failed}` : '';
    return `完成 ${completed}/${steps.length}${failureText}${durationText}`;
  }

  private getStatusColor(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.COMPLETED: return '#047857';
      case ThinkingStatus.FAILED:
      case ThinkingStatus.CANCELLED: return '#B91C1C';
      default: return '#3730A3';
    }
  }

  private getCardBackground(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.COMPLETED: return '#F0FDF4';
      case ThinkingStatus.FAILED:
      case ThinkingStatus.CANCELLED: return '#FEF2F2';
      default: return '#F8F9FF';
    }
  }

  private getCardBorder(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.COMPLETED: return '#86EFAC';
      case ThinkingStatus.FAILED:
      case ThinkingStatus.CANCELLED: return '#FECACA';
      default: return '#C7D2FE';
    }
  }

  private getDetailButtonColor(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.COMPLETED: return '#047857';
      case ThinkingStatus.FAILED:
      case ThinkingStatus.CANCELLED: return '#B91C1C';
      default: return '#3730A3';
    }
  }

  private getDetailButtonBackground(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.COMPLETED: return '#DCFCE7';
      case ThinkingStatus.FAILED:
      case ThinkingStatus.CANCELLED: return '#FEE2E2';
      default: return '#EEF2FF';
    }
  }

  private getDetailButtonBorder(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.COMPLETED: return '#34D399';
      case ThinkingStatus.FAILED:
      case ThinkingStatus.CANCELLED: return '#FCA5A5';
      default: return '#C7D2FE';
    }
  }

  private getStepAccentColor(status: StepStatus): string {
    switch (status) {
      case StepStatus.PROCESSING: return '#4C51BF';
      case StepStatus.COMPLETED: return '#059669';
      case StepStatus.FAILED: return '#DC2626';
      default: return '#6B7280';
    }
  }

  private getStepBackground(status: StepStatus): string {
    switch (status) {
      case StepStatus.PROCESSING: return 'rgba(79, 70, 229, 0.08)';
      case StepStatus.COMPLETED: return 'rgba(16, 185, 129, 0.08)';
      case StepStatus.FAILED: return 'rgba(220, 38, 38, 0.08)';
      default: return '#FFFFFF';
    }
  }

  private getStepBorder(status: StepStatus): string {
    switch (status) {
      case StepStatus.PROCESSING: return '#A5B4FC';
      case StepStatus.COMPLETED: return '#6EE7B7';
      case StepStatus.FAILED: return '#FCA5A5';
      default: return '#E5E7EB';
    }
  }

  private getStepStatusIcon(status: StepStatus): string {
    switch (status) {
      case StepStatus.PROCESSING: return '⚡';
      case StepStatus.COMPLETED: return '✅';
      case StepStatus.FAILED: return '❌';
      default: return '⏳';
    }
  }
}
