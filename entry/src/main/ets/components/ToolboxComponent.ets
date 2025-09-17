import { promptAction, curves } from '@kit.ArkUI';
import { ThemeManager } from '../utils/ThemeManager';
import { Logger } from '../utils/Logger';
import { BasicAnimations, AnimationConfigManager } from '../animations';
import { 
  ToolType, 
  ToolItem, 
  ToolboxComponentProps, 
  ToolboxConfig 
} from '../types/ToolboxTypes';

/**
 * 工具箱按钮组件 (简化版)
 * 只包含按钮部分，面板由ChatPage独立管理
 */
@ComponentV2
export struct ToolboxComponent {
  // 组件属性
  @Param onButtonClick?: () => void = () => {};
  
  // 内部状态
  @Local private isPressed: boolean = false;
  
  build() {
    // 只构建工具箱按钮
    this.buildToolboxButton();
  }
  
  @Builder
  buildToolboxButton() {
    Button() {
      Text('➕')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
    }
    .width(40)
    .height(40)
    .backgroundColor('#74B9FF')
    .borderRadius(20)
    .scale({ 
      x: this.isPressed ? 0.9 : 1.0, 
      y: this.isPressed ? 0.9 : 1.0 
    })
    .animation({
      duration: BasicAnimations.QUICK_DURATION,
      curve: curves.springMotion(0.8, 0.8)
    })
    .onClick(() => {
      if (this.onButtonClick) {
        this.onButtonClick();
      }
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
      Logger.warn('ToolboxComponent', `触觉反馈失败: ${error}`);
    }
  }
  
}