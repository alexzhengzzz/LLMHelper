/**
 * 极简版动画系统 - 完全符合ArkTS规范
 * 专为鸿蒙设计的高端精致动画
 */

/**
 * 基础动画类
 */
export class BasicAnimations {
  
  /**
   * 快速动画时长
   */
  static readonly QUICK_DURATION = 150;
  
  /**
   * 标准动画时长
   */
  static readonly STANDARD_DURATION = 300;
  
  /**
   * 流畅动画时长
   */
  static readonly SMOOTH_DURATION = 450;
  
  /**
   * 优雅动画时长
   */
  static readonly ELEGANT_DURATION = 600;
  
  /**
   * 按钮按下缩放比例
   */
  static readonly BUTTON_PRESS_SCALE = 0.95;
  
  /**
   * 按钮正常缩放比例
   */
  static readonly BUTTON_NORMAL_SCALE = 1.0;
  
  /**
   * 语音呼吸缩放比例
   */
  static readonly VOICE_BREATHING_SCALE = 1.1;
  
  /**
   * 成功动画缩放比例
   */
  static readonly SUCCESS_SCALE = 1.2;
  
  /**
   * 错误抖动偏移量
   */
  static readonly ERROR_SHAKE_OFFSET = 5;
  
  /**
   * 消息进入偏移量
   */
  static readonly MESSAGE_ENTER_OFFSET = 50;
  
  /**
   * 标准透明度
   */
  static readonly STANDARD_OPACITY = 1.0;
  
  /**
   * 隐藏透明度
   */
  static readonly HIDDEN_OPACITY = 0.0;
  
  /**
   * 半透明度
   */
  static readonly SEMI_OPACITY = 0.5;
}

/**
 * 动画配置管理器
 */
export class AnimationConfigManager {
  private static instance: AnimationConfigManager | null = null;
  private isReducedMotion: boolean = false;

  private constructor() {}

  static getInstance(): AnimationConfigManager {
    if (!AnimationConfigManager.instance) {
      AnimationConfigManager.instance = new AnimationConfigManager();
    }
    return AnimationConfigManager.instance;
  }

  /**
   * 初始化
   */
  initialize(): void {
    // 简单初始化
  }

  /**
   * 设置减少动画
   */
  setReducedMotion(enabled: boolean): void {
    this.isReducedMotion = enabled;
  }

  /**
   * 获取动画时长
   */
  getDuration(baseDuration: number): number {
    return this.isReducedMotion ? 0 : baseDuration;
  }

  /**
   * 获取动画曲线
   */
  getCurve(): Curve {
    return this.isReducedMotion ? Curve.Linear : Curve.EaseInOut;
  }
}