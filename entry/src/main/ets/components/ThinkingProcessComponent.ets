/**
 * 深度思考过程可视化组件
 */

import { ThinkingStep, ThinkingStatus, StepStatus } from '../models/ChatModels';

// 思考过程展示参数
@ObservedV2
class ThinkingProcessParams {
  @Trace thinkingSteps: ThinkingStep[] = [];
  @Trace thinkingStatus: ThinkingStatus = ThinkingStatus.IDLE;
  @Trace showDetails: boolean = true;
  @Trace compact: boolean = false;
}

@ComponentV2
export struct ThinkingProcessComponent {
  @Param @Require thinkingSteps: ThinkingStep[];
  @Param @Require thinkingStatus: ThinkingStatus;
  @Param showDetails: boolean = true;
  @Param compact: boolean = false;
  @Param onStepTap: (step: ThinkingStep) => void = () => {};

  @Local expandedSteps: Set<string> = new Set();

  build() {
    Column({ space: this.compact ? 8 : 12 }) {
      if (this.thinkingSteps.length === 0) {
        Blank();
      } else {
      // 整体状态指示器
      this.buildOverallStatus()
      
      // 步骤列表
      ForEach(this.thinkingSteps, (step: ThinkingStep, index: number) => {
        this.buildStepItem(step, index)
      })
      
      // 底部进度信息
      if (!this.compact) {
        this.buildProgressInfo()
      }
      }
    }
    .width('100%')
    .padding({ 
      left: this.compact ? 8 : 12, 
      right: this.compact ? 8 : 12, 
      top: 8, 
      bottom: 8 
    })
    .backgroundColor('#F8F9FF')
    .borderRadius(this.compact ? 6 : 8)
    .border({
      width: 1,
      color: this.getBorderColor()
    })
  }

  @Builder
  private buildOverallStatus() {
    Row({ space: 8 }) {
      // 状态图标
      Text(this.getStatusIcon())
        .fontSize(this.compact ? 14 : 16)
        .animation({ duration: 600, curve: Curve.EaseInOut })
      
      // 状态文字
      Text(this.getStatusText())
        .fontSize(this.compact ? 12 : 14)
        .fontColor('#2D3142')
        .fontWeight(500)
      
      Blank()
      
      // 总体进度
      if (this.thinkingStatus !== ThinkingStatus.IDLE) {
        Text(this.getProgressText())
          .fontSize(this.compact ? 10 : 12)
          .fontColor('#666')
      }
    }
    .width('100%')
    .height(this.compact ? 28 : 32)
  }

  @Builder
  private buildStepItem(step: ThinkingStep, index: number) {
    Column({ space: 6 }) {
      // 步骤标题行
      Row({ space: 8 }) {
        // 步骤序号和状态图标
        Row({ space: 4 }) {
          Text(`${index + 1}`)
            .fontSize(this.compact ? 10 : 12)
            .fontColor('#fff')
            .width(this.compact ? 16 : 20)
            .height(this.compact ? 16 : 20)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.getStepColor(step.status))
            .borderRadius(this.compact ? 8 : 10)
            .scale({
              x: step.status === StepStatus.PROCESSING ? 1.1 : 1.0,
              y: step.status === StepStatus.PROCESSING ? 1.1 : 1.0
            })
            .animation({
              duration: 800,
              curve: Curve.EaseInOut,
              iterations: -1
            })
          
          Text(this.getStepStatusIcon(step.status))
            .fontSize(this.compact ? 12 : 14)
            .animation({ duration: 500, curve: Curve.EaseInOut })
        }
        
        // 步骤标题
        Text(step.title)
          .fontSize(this.compact ? 12 : 14)
          .fontColor('#2D3142')
          .fontWeight(500)
          .flexGrow(1)
        
        // 耗时信息
        if (step.duration) {
          Text(`${(step.duration / 1000).toFixed(1)}s`)
            .fontSize(this.compact ? 10 : 11)
            .fontColor('#999')
        }
        
        // 展开/折叠按钮
        if (this.showDetails && step.content && !this.compact) {
          Text(this.expandedSteps.has(step.id) ? '📖' : '📑')
            .fontSize(12)
            .padding(4)
            .onClick(() => this.toggleStepExpansion(step.id))
        }
      }
      .width('100%')
      .onClick(() => {
        if (this.onStepTap) {
          this.onStepTap(step);
        } else if (this.showDetails && step.content) {
          this.toggleStepExpansion(step.id);
        }
      })
      
      // 步骤描述
      if (!this.compact) {
        Text(step.description)
          .fontSize(11)
          .fontColor('#666')
          .margin({ left: 28 })
      }
      
      // 步骤内容（可展开）
      if (this.showDetails && step.content && this.expandedSteps.has(step.id) && !this.compact) {
        this.buildStepContent(step)
      }
      
      // 错误信息
      if (step.error && step.status === StepStatus.FAILED) {
        this.buildErrorInfo(step.error)
      }
    }
    .width('100%')
    .padding({ 
      left: this.compact ? 6 : 8, 
      right: this.compact ? 6 : 8, 
      top: this.compact ? 4 : 6, 
      bottom: this.compact ? 4 : 6 
    })
    .backgroundColor('#fff')
    .borderRadius(this.compact ? 4 : 6)
    .border({
      width: 1,
      color: step.status === StepStatus.PROCESSING ? '#4A90E2' : '#E5E7EB'
    })
  }

  @Builder
  private buildStepContent(step: ThinkingStep) {
    Column({ space: 4 }) {
      Divider()
        .color('#E5E7EB')
        .margin({ left: 28, right: 8 })
      
      Text(step.content)
        .fontSize(12)
        .fontColor('#374151')
        .lineHeight(18)
        .margin({ left: 28, right: 8, top: 4, bottom: 4 })
        .maxLines(this.compact ? 3 : -1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  @Builder
  private buildErrorInfo(error: string) {
    Row({ space: 6 }) {
      Text('⚠️')
        .fontSize(12)
      
      Text(error)
        .fontSize(11)
        .fontColor('#DC2626')
        .flexGrow(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(8)
    .margin({ left: 28 })
    .backgroundColor('#FEF2F2')
    .borderRadius(4)
    .border({
      width: 1,
      color: '#FECACA'
    })
  }

  @Builder
  private buildProgressInfo() {
    if (this.thinkingStatus !== ThinkingStatus.IDLE && this.thinkingStatus !== ThinkingStatus.COMPLETED) {
      Row({ space: 8 }) {
      // 进度条
      Row() {
        ForEach(this.thinkingSteps, (step: ThinkingStep, index: number) => {
          Row()
            .width(20)
            .height(3)
            .backgroundColor(this.getProgressBarColor(step.status))
            .borderRadius(1.5)
            .margin({ right: index < this.thinkingSteps.length - 1 ? 2 : 0 })
        })
      }
      .flexGrow(1)
      
      // 进度文字
      Text(this.getDetailedProgressText())
        .fontSize(10)
        .fontColor('#666')
      }
      .width('100%')
      .padding({ top: 4 })
    }
  }

  // 工具方法
  private getStatusIcon(): string {
    switch (this.thinkingStatus) {
      case ThinkingStatus.PLANNING: return '🗺️';
      case ThinkingStatus.ANALYZING: return '🔍';
      case ThinkingStatus.RESEARCHING: return '🌐';
      case ThinkingStatus.THINKING: return '🧠';
      case ThinkingStatus.VERIFYING: return '✅';
      case ThinkingStatus.INTEGRATING: return '🎯';
      case ThinkingStatus.REFINING: return '🔁';
      case ThinkingStatus.COMPLETED: return '✨';
      case ThinkingStatus.FAILED: return '❌';
      case ThinkingStatus.CANCELLED: return '⏹️';
      default: return '💭';
    }
  }

  private getStatusText(): string {
    switch (this.thinkingStatus) {
      case ThinkingStatus.PLANNING: return '正在规划推理路径...';
      case ThinkingStatus.ANALYZING: return '深度分析中...';
      case ThinkingStatus.RESEARCHING: return '资料检索中...';
      case ThinkingStatus.THINKING: return '多角度思考中...';
      case ThinkingStatus.VERIFYING: return '批判性验证中...';
      case ThinkingStatus.INTEGRATING: return '综合整合中...';
      case ThinkingStatus.REFINING: return '质量复盘中...';
      case ThinkingStatus.COMPLETED: return '深度思考完成';
      case ThinkingStatus.FAILED: return '思考过程失败';
      case ThinkingStatus.CANCELLED: return '思考过程已取消';
      default: return '深度思考准备中';
    }
  }

  private getBorderColor(): string {
    switch (this.thinkingStatus) {
      case ThinkingStatus.PLANNING:
      case ThinkingStatus.ANALYZING:
      case ThinkingStatus.RESEARCHING:
      case ThinkingStatus.THINKING:
      case ThinkingStatus.VERIFYING:
      case ThinkingStatus.INTEGRATING:
      case ThinkingStatus.REFINING:
        return '#4A90E2';
      case ThinkingStatus.COMPLETED:
        return '#10B981';
      case ThinkingStatus.FAILED:
        return '#DC2626';
      case ThinkingStatus.CANCELLED:
        return '#6B7280';
      default:
        return '#E5E7EB';
    }
  }

  private getStepStatusIcon(status: StepStatus): string {
    switch (status) {
      case StepStatus.PENDING: return '⏳';
      case StepStatus.PROCESSING: return '⚡';
      case StepStatus.COMPLETED: return '✅';
      case StepStatus.FAILED: return '❌';
      default: return '⏳';
    }
  }

  private getStepColor(status: StepStatus): string {
    switch (status) {
      case StepStatus.PENDING: return '#9CA3AF';
      case StepStatus.PROCESSING: return '#4A90E2';
      case StepStatus.COMPLETED: return '#10B981';
      case StepStatus.FAILED: return '#DC2626';
      default: return '#9CA3AF';
    }
  }

  private getProgressBarColor(status: StepStatus): string {
    switch (status) {
      case StepStatus.COMPLETED: return '#10B981';
      case StepStatus.PROCESSING: return '#4A90E2';
      case StepStatus.FAILED: return '#DC2626';
      default: return '#E5E7EB';
    }
  }

  private getProgressText(): string {
    const completed = this.thinkingSteps.filter(s => s.status === StepStatus.COMPLETED).length;
    const total = this.thinkingSteps.length;
    return `${completed}/${total}`;
  }

  private getDetailedProgressText(): string {
    const completed = this.thinkingSteps.filter(s => s.status === StepStatus.COMPLETED).length;
    const processing = this.thinkingSteps.filter(s => s.status === StepStatus.PROCESSING).length;
    const failed = this.thinkingSteps.filter(s => s.status === StepStatus.FAILED).length;
    const total = this.thinkingSteps.length;
    
    if (failed > 0) {
      return `已完成 ${completed}/${total}，失败 ${failed} 个`;
    } else if (processing > 0) {
      return `已完成 ${completed}/${total}，进行中 ${processing} 个`;
    } else {
      return `已完成 ${completed}/${total}`;
    }
  }

  private toggleStepExpansion(stepId: string): void {
    if (this.expandedSteps.has(stepId)) {
      this.expandedSteps.delete(stepId);
    } else {
      this.expandedSteps.add(stepId);
    }
    // 触发重新渲染
    this.expandedSteps = new Set(this.expandedSteps);
  }
}
