import { promptAction, curves } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';
import { BasicAnimations } from '../animations';

/**
 * 混合操作按钮组件
 * 根据输入状态动态切换功能：
 * - 无输入时：显示加号 ➕，点击打开工具箱面板
 * - 有输入时：显示发送图标，点击发送消息
 */
@ComponentV2
export struct HybridActionComponent {
  // 组件属性
  @Param inputText: string = '';
  @Param onSend?: () => void = () => {};
  @Param onToolbox?: () => void = () => {};
  @Param isLoading: boolean = false;
  @Param isVoiceRecording: boolean = false;
  
  // 内部状态
  @Local private isPressed: boolean = false;
  @Local private hasContent: boolean = false;
  
  aboutToAppear(): void {
    // 初始化内容状态
    this.updateContentState();
  }
  
  build() {
    this.buildHybridButton();
  }
  
  @Builder
  buildHybridButton() {
    Button() {
      // 根据输入状态显示不同图标，使用平滑过渡动画
      if (this.hasContent) {
        // 有输入时显示发送图标
        Image($r('app.media.ic_send'))
          .width(20)
          .height(20)
          .fillColor(Color.White)
          .transition({
            type: TransitionType.All,
            opacity: 0,
            scale: { x: 0.8, y: 0.8 }
          })
          .animation({
            duration: 200,
            curve: Curve.EaseInOut
          })
      } else {
        // 无输入时显示加号
        Text('➕')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .transition({
            type: TransitionType.All,
            opacity: 0,
            scale: { x: 0.8, y: 0.8 }
          })
          .animation({
            duration: 200,
            curve: Curve.EaseInOut
          })
      }
    }
    .width(44)
    .height(40)
    .backgroundColor(this.getButtonBackgroundColor())
    .borderRadius(20)
    .scale({ 
      x: this.isPressed ? 0.9 : 1.0, 
      y: this.isPressed ? 0.9 : 1.0 
    })
    .enabled(this.isButtonEnabled())
    .animation({
      duration: BasicAnimations.QUICK_DURATION,
      curve: curves.springMotion(0.8, 0.8)
    })
    .onClick(() => {
      this.handleButtonClick();
    })
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
        this.triggerHapticFeedback();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
  }
  
  /**
   * 更新内容状态
   */
  private updateContentState(): void {
    const newHasContent = this.hasInputText();
    if (this.hasContent !== newHasContent) {
      this.hasContent = newHasContent;
      Logger.info('HybridActionComponent', `内容状态更新: ${newHasContent ? '有内容' : '无内容'}`);
    }
  }
  
  /**
   * 判断是否有输入文本
   */
  private hasInputText(): boolean {
    return this.inputText.trim().length > 0;
  }
  
  /**
   * 获取按钮背景颜色
   */
  private getButtonBackgroundColor(): ResourceColor {
    if (this.hasInputText()) {
      // 有输入时使用主色调
      return $r('app.color.primary_color');
    } else {
      // 无输入时使用蓝色
      return '#74B9FF';
    }
  }
  
  /**
   * 判断按钮是否可用
   */
  private isButtonEnabled(): boolean {
    if (this.hasInputText()) {
      // 有输入时：需要检查是否在加载中或语音录音中
      return !this.isLoading && !this.isVoiceRecording;
    } else {
      // 无输入时：工具箱按钮始终可用
      return true;
    }
  }
  
  /**
   * 处理按钮点击
   */
  private handleButtonClick(): void {
    if (this.hasInputText()) {
      // 有输入时执行发送操作
      Logger.info('HybridActionComponent', '执行发送操作');
      if (this.onSend) {
        this.onSend();
      }
    } else {
      // 无输入时执行工具箱操作
      Logger.info('HybridActionComponent', '执行工具箱操作');
      if (this.onToolbox) {
        this.onToolbox();
      }
    }
  }
  
  /**
   * 触发触觉反馈
   */
  private async triggerHapticFeedback(): Promise<void> {
    try {
      // 导入触觉反馈模块
      const vibratorModule = await import('@kit.SensorServiceKit');
      await vibratorModule.vibrator.startVibration({
        type: 'time',
        duration: 30
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (error) {
      Logger.warn('HybridActionComponent', `触觉反馈失败: ${error}`);
    }
  }
}