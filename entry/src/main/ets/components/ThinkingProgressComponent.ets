/**
 * 深度思考进度指示器组件
 */

import { ThinkingStatus, StepStatus, ThinkingStep } from '../models/ChatModels';

@ComponentV2
export struct ThinkingProgressComponent {
  @Param @Require thinkingSteps: ThinkingStep[];
  @Param @Require thinkingStatus: ThinkingStatus;
  @Param progressSize: 'small' | 'medium' | 'large' = 'medium';
  @Param showText: boolean = true;
  @Param showPercentage: boolean = false;
  @Param animated: boolean = true;

  @Local private animationRotation: number = 0;
  private animationTimer: number = -1;

  aboutToAppear() {
    if (this.animated && this.isProcessing()) {
      this.startAnimation();
    }
  }

  aboutToDisappear() {
    this.stopAnimation();
  }

  build() {
    if (this.thinkingStatus === ThinkingStatus.IDLE) {
      Blank();
    } else {
      Column({ space: this.getSpacing() }) {
        // 主要进度指示器
        this.buildMainIndicator()
        
        // 文字描述
        if (this.showText) {
          this.buildTextIndicator()
        }
        
        // 详细步骤进度
        if (this.progressSize !== 'small' && this.thinkingSteps.length > 0) {
          this.buildStepProgress()
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private buildMainIndicator() {
    if (this.thinkingStatus === ThinkingStatus.COMPLETED) {
      // 完成状态 - 显示成功图标
      this.buildSuccessIndicator()
    } else if (this.thinkingStatus === ThinkingStatus.FAILED) {
      // 失败状态 - 显示错误图标
      this.buildErrorIndicator()
    } else if (this.thinkingStatus === ThinkingStatus.CANCELLED) {
      // 取消状态 - 显示取消图标
      this.buildCancelledIndicator()
    } else {
      // 进行中状态 - 显示进度圆环
      this.buildProgressRing()
    }
  }

  @Builder
  private buildProgressRing() {
    Stack() {
      // 背景圆环
      Circle()
        .width(this.getMainSize())
        .height(this.getMainSize())
        .fill(Color.Transparent)
        .stroke('#E5E7EB')
        .strokeWidth(this.getStrokeWidth())
      
      // 进度圆环
      Circle()
        .width(this.getMainSize())
        .height(this.getMainSize())
        .fill(Color.Transparent)
        .stroke(this.getProgressColor())
        .strokeWidth(this.getStrokeWidth())
        .strokeDashArray(this.getProgressDashArray())
        .rotate({ angle: this.animationRotation })
        .animation(this.animated ? {
          duration: 1000,
          curve: Curve.Linear,
          iterations: -1
        } : undefined)
      
      // 中心图标
      Text(this.getCenterIcon())
        .fontSize(this.getIconSize())
        .fontColor(this.getProgressColor())
    }
  }

  @Builder
  private buildSuccessIndicator() {
    Stack() {
      Circle()
        .width(this.getMainSize())
        .height(this.getMainSize())
        .fill('#F0FDF4')
        .border({ width: this.getStrokeWidth(), color: '#10B981' })
      
      Text('✅')
        .fontSize(this.getIconSize())
    }
  }

  @Builder
  private buildErrorIndicator() {
    Stack() {
      Circle()
        .width(this.getMainSize())
        .height(this.getMainSize())
        .fill('#FEF2F2')
        .border({ width: this.getStrokeWidth(), color: '#DC2626' })
      
      Text('❌')
        .fontSize(this.getIconSize())
    }
  }

  @Builder
  private buildCancelledIndicator() {
    Stack() {
      Circle()
        .width(this.getMainSize())
        .height(this.getMainSize())
        .fill('#F9FAFB')
        .border({ width: this.getStrokeWidth(), color: '#6B7280' })
      
      Text('⏹️')
        .fontSize(this.getIconSize())
    }
  }

  @Builder
  private buildTextIndicator() {
    Column({ space: 2 }) {
      Text(this.getStatusText())
        .fontSize(this.getTextSize())
        .fontColor('#2D3142')
        .fontWeight(500)
        .textAlign(TextAlign.Center)
      
      if (this.showPercentage && this.isProcessing()) {
        Text(this.getPercentageText())
          .fontSize(this.getSubTextSize())
          .fontColor('#666')
          .textAlign(TextAlign.Center)
      }
    }
  }

  @Builder
  private buildStepProgress() {
    Row({ space: 4 }) {
      ForEach(this.thinkingSteps, (step: ThinkingStep, index: number) => {
        this.buildStepDot(step, index)
      })
    }
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildStepDot(step: ThinkingStep, index: number) {
    Circle()
      .width(this.getDotSize())
      .height(this.getDotSize())
      .fill(this.getStepDotColor(step.status))
      .border({
        width: 1,
        color: this.getStepDotBorderColor(step.status)
      })
      .animation(this.animated ? {
        duration: 300,
        curve: Curve.EaseInOut
      } : undefined)
  }

  // 工具方法
  private getMainSize(): number {
    switch (this.progressSize) {
      case 'small': return 24;
      case 'medium': return 32;
      case 'large': return 48;
      default: return 32;
    }
  }

  private getStrokeWidth(): number {
    switch (this.progressSize) {
      case 'small': return 2;
      case 'medium': return 3;
      case 'large': return 4;
      default: return 3;
    }
  }

  private getIconSize(): number {
    switch (this.progressSize) {
      case 'small': return 12;
      case 'medium': return 16;
      case 'large': return 24;
      default: return 16;
    }
  }

  private getTextSize(): number {
    switch (this.progressSize) {
      case 'small': return 11;
      case 'medium': return 13;
      case 'large': return 15;
      default: return 13;
    }
  }

  private getSubTextSize(): number {
    switch (this.progressSize) {
      case 'small': return 9;
      case 'medium': return 11;
      case 'large': return 13;
      default: return 11;
    }
  }

  private getDotSize(): number {
    switch (this.progressSize) {
      case 'small': return 6;
      case 'medium': return 8;
      case 'large': return 10;
      default: return 8;
    }
  }

  private getSpacing(): number {
    switch (this.progressSize) {
      case 'small': return 4;
      case 'medium': return 6;
      case 'large': return 8;
      default: return 6;
    }
  }

  private getProgressColor(): string {
    switch (this.thinkingStatus) {
      case ThinkingStatus.ANALYZING: return '#3B82F6';
      case ThinkingStatus.THINKING: return '#8B5CF6';
      case ThinkingStatus.VERIFYING: return '#10B981';
      case ThinkingStatus.INTEGRATING: return '#F59E0B';
      default: return '#4A90E2';
    }
  }

  private getCenterIcon(): string {
    switch (this.thinkingStatus) {
      case ThinkingStatus.ANALYZING: return '🔍';
      case ThinkingStatus.THINKING: return '🧠';
      case ThinkingStatus.VERIFYING: return '✅';
      case ThinkingStatus.INTEGRATING: return '🎯';
      default: return '💭';
    }
  }

  private getStatusText(): string {
    switch (this.thinkingStatus) {
      case ThinkingStatus.ANALYZING: return '深度分析';
      case ThinkingStatus.THINKING: return '多角度思考';
      case ThinkingStatus.VERIFYING: return '批判验证';
      case ThinkingStatus.INTEGRATING: return '综合整合';
      case ThinkingStatus.COMPLETED: return '思考完成';
      case ThinkingStatus.FAILED: return '思考失败';
      case ThinkingStatus.CANCELLED: return '已取消';
      default: return '深度思考';
    }
  }

  private getPercentageText(): string {
    const completed = this.thinkingSteps.filter(s => s.status === StepStatus.COMPLETED).length;
    const total = this.thinkingSteps.length;
    const percentage = total > 0 ? Math.round((completed / total) * 100) : 0;
    return `${percentage}%`;
  }

  private getProgressDashArray(): number[] {
    const completed = this.thinkingSteps.filter(s => s.status === StepStatus.COMPLETED).length;
    const total = this.thinkingSteps.length;
    
    if (total === 0) {
      return [0, 100]; // 显示旋转动画
    }
    
    const circumference = Math.PI * (this.getMainSize() - this.getStrokeWidth());
    const progress = completed / total;
    const dashLength = circumference * progress;
    const gapLength = circumference * (1 - progress);
    
    return [dashLength, gapLength];
  }

  private getStepDotColor(status: StepStatus): string {
    switch (status) {
      case StepStatus.COMPLETED: return '#10B981';
      case StepStatus.PROCESSING: return '#4A90E2';
      case StepStatus.FAILED: return '#DC2626';
      default: return '#E5E7EB';
    }
  }

  private getStepDotBorderColor(status: StepStatus): string {
    switch (status) {
      case StepStatus.COMPLETED: return '#059669';
      case StepStatus.PROCESSING: return '#2563EB';
      case StepStatus.FAILED: return '#B91C1C';
      default: return '#D1D5DB';
    }
  }

  private isProcessing(): boolean {
    return this.thinkingStatus === ThinkingStatus.ANALYZING ||
           this.thinkingStatus === ThinkingStatus.THINKING ||
           this.thinkingStatus === ThinkingStatus.VERIFYING ||
           this.thinkingStatus === ThinkingStatus.INTEGRATING;
  }

  private startAnimation(): void {
    this.stopAnimation();
    this.animationTimer = setInterval(() => {
      this.animationRotation += 90;
      if (this.animationRotation >= 360) {
        this.animationRotation = 0;
      }
    }, 250);
  }

  private stopAnimation(): void {
    if (this.animationTimer !== -1) {
      clearInterval(this.animationTimer);
      this.animationTimer = -1;
    }
  }
}