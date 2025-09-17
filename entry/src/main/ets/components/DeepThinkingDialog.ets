/**
 * 深度思考对话框组件
 */

import { ThinkingStep, ThinkingStatus, StepStatus, Message } from '../models/ChatModels';
import { ThinkingProcessComponent } from './ThinkingProcessComponent';
import { Logger } from '../utils/Logger';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';

// 对话框参数
@ObservedV2
class DeepThinkingDialogParams {
  @Trace isShowing: boolean = false;
  @Trace message: Message | null = null;
  @Trace autoScroll: boolean = true;
}

@ComponentV2
export struct DeepThinkingDialog {
  @Param @Require isShowing: boolean;
  @Param message: Message | null = null;
  @Param onClose: () => void = () => {};
  @Param onShowDetails: (step: ThinkingStep) => void = () => {};

  @Local autoScroll: boolean = true;
  @Local lastStepCount: number = 0;

  aboutToAppear() {
    Logger.info('DeepThinkingDialog', `对话框状态: ${this.isShowing}`);
  }

  aboutToDisappear() {
    Logger.info('DeepThinkingDialog', '对话框关闭');
  }

  build() {
    if (this.isShowing && this.message) {
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => {
            this.onClose();
          })

        // 对话框内容
        Column() {
          // 标题栏
          this.buildHeader()

          // 内容区域
          if (this.message?.thinkingSteps && this.message.thinkingSteps.length > 0) {
            this.buildContent()
          } else {
            this.buildEmptyContent()
          }

          // 底部操作栏
          this.buildFooter()
        }
        .width('90%')
        .constraintSize({ maxWidth: 600 })
        .height('70%')
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .shadow({
          radius: 20,
          color: 'rgba(0, 0, 0, 0.1)',
          offsetX: 0,
          offsetY: 8
        })
        .onClick((event: ClickEvent) => {
          // 停止事件传播
        })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(1000)
    }
  }

  @Builder
  private buildHeader() {
    Row() {
      Column() {
        Row() {
          Text('🧠')
            .fontSize(24)
            .margin({ right: 8 })
          
          Column() {
            Text('深度思考过程')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2D3142')
            
            if (this.message?.thinkingStatus !== ThinkingStatus.COMPLETED && 
                this.message?.thinkingStatus !== ThinkingStatus.FAILED) {
              Text('实时更新中...')
                .fontSize(12)
                .fontColor('#666')
                .margin({ top: 2 })
            }
          }
          .alignItems(HorizontalAlign.Start)
        }
        .alignItems(VerticalAlign.Center)
      }
      .alignItems(HorizontalAlign.Start)

      // 关闭按钮
      Button() {
        Text('✕')
          .fontSize(20)
          .fontColor('#666')
      }
      .width(32)
      .height(32)
      .backgroundColor('#F3F4F6')
      .borderRadius(16)
      .onClick(() => {
        this.onClose();
      })
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 20, bottom: 16 })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  private buildContent() {
    Scroll() {
      Column() {
        // 整体状态信息
        this.buildStatusInfo()

        // 思考步骤
        ThinkingProcessComponent({
          thinkingSteps: this.message?.thinkingSteps || [],
          thinkingStatus: this.message?.thinkingStatus || ThinkingStatus.IDLE,
          showDetails: true,
          compact: false,
          onStepTap: (step: ThinkingStep) => {
            this.onShowDetails(step);
          }
        })

        // 如果思考完成，显示最终答案预览
        if (this.message?.thinkingStatus === ThinkingStatus.COMPLETED && 
            this.message?.content) {
          this.buildFinalAnswerPreview()
        }
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private buildEmptyContent() {
    Column() {
      Text('⏳')
        .fontSize(48)
        .margin({ bottom: 16 })
      
      Text('正在准备深度思考过程...')
        .fontSize(16)
        .fontColor('#666')
        .textAlign(TextAlign.Center)
      
      LoadingProgress()
        .width(40)
        .height(40)
        .margin({ top: 20 })
        .color($r('app.color.primary_color'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildStatusInfo() {
    if (this.message?.thinkingStatus) {
      Column() {
        Row() {
          Text(this.getStatusIcon(this.message?.thinkingStatus || ThinkingStatus.IDLE))
            .fontSize(16)
            .margin({ right: 8 })
          
          Text(this.getStatusText(this.message?.thinkingStatus || ThinkingStatus.IDLE))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2D3142')
          
          Blank()
          
          // 步骤进度
          if (this.message?.thinkingSteps && this.message.thinkingSteps.length > 0) {
            Text(`${this.getCompletedStepsCount()}/${this.message.thinkingSteps.length}`)
              .fontSize(12)
              .fontColor('#666')
              .backgroundColor('#F3F4F6')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(12)
          }
        }
        .width('100%')
        
        // 状态描述
        Text(this.getStatusDescription(this.message?.thinkingStatus || ThinkingStatus.IDLE))
          .fontSize(12)
          .fontColor('#666')
          .margin({ top: 4 })
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F8F9FF')
      .borderRadius(8)
      .margin({ bottom: 12 })
    }
  }

  @Builder
  private buildFinalAnswerPreview() {
    Column() {
      Row() {
        Text('✨')
          .fontSize(16)
          .margin({ right: 8 })
        
        Text('最终答案')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2D3142')
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 显示答案的前几行作为预览
      Text(((this.message?.content || '') as string).substring(0, 200) + (((this.message?.content || '') as string).length > 200 ? '...' : ''))
        .fontSize(12)
        .fontColor('#374151')
        .lineHeight(16)
        .width('100%')
        .padding(12)
        .backgroundColor('#F9FAFB')
        .borderRadius(6)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F0FDF4')
    .borderRadius(8)
    .margin({ top: 12 })
  }

  @Builder
  private buildFooter() {
    Row() {
      // 自动滚动开关
      Row() {
        Text('自动滚动')
          .fontSize(12)
          .fontColor('#666')
        
        Toggle({ type: ToggleType.Switch, isOn: this.autoScroll })
          .width(36)
          .height(20)
          .onChange((isOn: boolean) => {
            this.autoScroll = isOn;
          })
      }
      .margin({ left: 16 })

      Blank()

      // 操作按钮
      Row() {
        // 复制思考过程
        Button() {
          Text('📋 复制')
            .fontSize(12)
        }
        .width(80)
        .height(32)
        .fontSize(12)
        .backgroundColor('#F3F4F6')
        .fontColor('#374151')
        .borderRadius(16)
        .onClick(() => {
          this.copyThinkingProcess();
        })

        // 关闭按钮
        Button() {
          Text('关闭')
            .fontSize(12)
        }
        .width(60)
        .height(32)
        .fontSize(12)
        .backgroundColor($r('app.color.primary_color'))
        .fontColor(Color.White)
        .borderRadius(16)
        .onClick(() => {
          this.onClose();
        })
        .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    .backgroundColor('#F9FAFB')
    .borderRadius({ bottomLeft: 16, bottomRight: 16 })
  }

  // 工具方法
  private getCompletedStepsCount(): number {
    if (!this.message?.thinkingSteps || this.message.thinkingSteps.length === 0) return 0;
    return this.message.thinkingSteps.filter(s => s.status === StepStatus.COMPLETED).length;
  }

  private getStatusIcon(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.ANALYZING: return '🔍';
      case ThinkingStatus.THINKING: return '🧠';
      case ThinkingStatus.VERIFYING: return '✅';
      case ThinkingStatus.INTEGRATING: return '🎯';
      case ThinkingStatus.COMPLETED: return '✨';
      case ThinkingStatus.FAILED: return '❌';
      case ThinkingStatus.CANCELLED: return '⏹️';
      default: return '💭';
    }
  }

  private getStatusText(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.ANALYZING: return '深度分析';
      case ThinkingStatus.THINKING: return '多角度思考';
      case ThinkingStatus.VERIFYING: return '批判性验证';
      case ThinkingStatus.INTEGRATING: return '综合整合';
      case ThinkingStatus.COMPLETED: return '思考完成';
      case ThinkingStatus.FAILED: return '思考失败';
      case ThinkingStatus.CANCELLED: return '思考取消';
      default: return '准备思考';
    }
  }

  private getStatusDescription(status: ThinkingStatus): string {
    switch (status) {
      case ThinkingStatus.ANALYZING: return '正在分析问题的核心要点和关键信息';
      case ThinkingStatus.THINKING: return '正在从多个角度深入思考可能的解决方案';
      case ThinkingStatus.VERIFYING: return '正在批判性地验证和反驳前面的思考结果';
      case ThinkingStatus.INTEGRATING: return '正在整合所有思考结果，提供最终答案';
      case ThinkingStatus.COMPLETED: return '深度思考过程已成功完成';
      case ThinkingStatus.FAILED: return '深度思考过程中出现错误';
      case ThinkingStatus.CANCELLED: return '深度思考过程已被用户取消';
      default: return '正在准备深度思考过程';
    }
  }

  private copyThinkingProcess(): void {
    if (!this.message?.thinkingSteps) return;
    
    let processText = '深度思考过程\n';
    processText += '=' .repeat(50) + '\n\n';
    
    for (const step of this.message?.thinkingSteps || []) {
      processText += `${step.title}\n`;
      processText += '-'.repeat(30) + '\n';
      processText += `${step.description}\n\n`;
      
      if (step.content) {
        processText += `思考内容：\n${step.content}\n\n`;
      }
      
      if (step.status === StepStatus.COMPLETED && step.duration) {
        processText += `耗时：${(step.duration / 1000).toFixed(1)}秒\n`;
      }
      
      processText += '\n' + '='.repeat(50) + '\n\n';
    }
    
    if (this.message?.content) {
      processText += `最终答案：\n${this.message.content}`;
    }
    
    // 复制到剪贴板
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, processText);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteData).then(() => {
        Logger.info('DeepThinkingDialog', '思考过程复制成功');
        promptAction.showToast({
          message: '思考过程已复制到剪贴板',
          duration: 2000
        });
      }).catch((error: Error) => {
        Logger.error('DeepThinkingDialog', `复制失败: ${error.message}`);
        promptAction.showToast({
          message: '复制失败，请重试',
          duration: 2000
        });
      });
    } catch (error) {
      const err = error as Error;
      Logger.error('DeepThinkingDialog', `复制异常: ${err.message}`);
      promptAction.showToast({
        message: '复制失败，请重试',
        duration: 2000
      });
    }
  }
}