import { curves } from '@kit.ArkUI';
import { ThemeManager } from '../utils/ThemeManager';
import { Logger } from '../utils/Logger';

/**
 * 动画类型枚举
 */
export enum AnimationType {
  // 页面过渡
  PAGE_ENTER = 'page_enter',
  PAGE_EXIT = 'page_exit',
  
  // 组件交互
  BUTTON_PRESS = 'button_press',
  BUTTON_RELEASE = 'button_release',
  LIST_ITEM_APPEAR = 'list_item_appear',
  
  // 语音交互
  VOICE_RECORDING = 'voice_recording',
  VOICE_PROCESSING = 'voice_processing',
  VOICE_WAVE = 'voice_wave',
  
  // 状态变化
  LOADING = 'loading',
  SUCCESS = 'success',
  ERROR = 'error',
  
  // 模态框
  MODAL_ENTER = 'modal_enter',
  MODAL_EXIT = 'modal_exit',
  
  // 侧边栏
  DRAWER_SLIDE_IN = 'drawer_slide_in',
  DRAWER_SLIDE_OUT = 'drawer_slide_out'
}

/**
 * 动画配置接口
 */
export interface AnimationConfig {
  duration: number;
  curve: Curve | ICurve;
  delay?: number;
  iterations?: number;
  playMode?: PlayMode;
  tempo?: number;
}

/**
 * 弹性动画配置
 */
export interface SpringConfig {
  stiffness: number;
  damping: number;
  mass?: number;
}

/**
 * SpringMotion 配置
 */
export interface SpringMotionConfig {
  response: number;
  dampingFraction: number;
  overlapDuration?: number;
}

/**
 * 动画预设配置
 */
export class AnimationPresets {
  // 快速动画 - 适用于微交互
  static readonly QUICK: AnimationConfig = {
    duration: 150,
    curve: curves.springMotion(0.85, 0.8), // 快速响应，高阻尼
    delay: 0
  };

  // 标准动画 - 适用于一般交互
  static readonly STANDARD: AnimationConfig = {
    duration: 300,
    curve: curves.springMotion(0.75, 0.85), // 标准弹性，自然感
    delay: 0
  };

  // 流畅动画 - 适用于页面过渡
  static readonly SMOOTH: AnimationConfig = {
    duration: 450,
    curve: curves.springMotion(0.65, 0.9), // 平滑响应，高阻尼
    delay: 0
  };

  // 优雅动画 - 适用于重要操作
  static readonly ELEGANT: AnimationConfig = {
    duration: 600,
    curve: curves.springMotion(0.55, 0.95), // 最优雅，接近临界阻尼
    delay: 0
  };

  // 强调动画 - 适用于错误或警告
  static readonly EMPHASIS: AnimationConfig = {
    duration: 200,
    curve: Curve.Sharp,
    delay: 0,
    iterations: 2,
    playMode: PlayMode.Alternate
  };

  // 脉冲动画 - 适用于加载状态
  static readonly PULSE: AnimationConfig = {
    duration: 1000,
    curve: Curve.EaseInOut,
    delay: 0,
    iterations: -1,
    playMode: PlayMode.Alternate
  };

  // 呼吸动画 - 适用于语音录音
  static readonly BREATHING: AnimationConfig = {
    duration: 1500,
    curve: curves.springCurve(200, 25),
    delay: 0,
    iterations: -1,
    playMode: PlayMode.Alternate
  };
}

/**
 * 核心动画管理器
 * 提供统一的动画配置、执行和管理功能
 */
export class AnimationManager {
  private static instance: AnimationManager | null = null;
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private isReducedMotion: boolean = false;
  private performanceMode: 'high' | 'balanced' | 'power_save' = 'balanced';
  
  // 动画状态管理
  private activeAnimations: Map<string, object> = new Map();
  private animationQueue: Array<() => void> = [];
  private isProcessingQueue: boolean = false;

  private constructor() {
    this.initializePerformanceSettings();
  }

  static getInstance(): AnimationManager {
    if (!AnimationManager.instance) {
      AnimationManager.instance = new AnimationManager();
    }
    return AnimationManager.instance;
  }

  /**
   * 初始化性能设置
   */
  private initializePerformanceSettings(): void {
    // 可以根据设备性能或用户设置调整
    // 这里设置为默认的平衡模式
    Logger.info('AnimationManager', '动画管理器初始化完成');
  }

  /**
   * 获取动画配置
   */
  getAnimationConfig(type: AnimationType): AnimationConfig {
    if (this.isReducedMotion) {
      return {
        duration: 0,
        curve: Curve.Linear,
        delay: 0
      };
    }

    // 根据性能模式调整动画配置
    const baseConfig = this.getBaseConfig(type);
    return this.adjustForPerformance(baseConfig);
  }

  /**
   * 获取基础动画配置
   */
  private getBaseConfig(type: AnimationType): AnimationConfig {
    switch (type) {
      case AnimationType.PAGE_ENTER:
      case AnimationType.PAGE_EXIT:
        return AnimationPresets.SMOOTH;
        
      case AnimationType.BUTTON_PRESS:
      case AnimationType.BUTTON_RELEASE:
        return AnimationPresets.QUICK;
        
      case AnimationType.LIST_ITEM_APPEAR:
        return AnimationPresets.STANDARD;
        
      case AnimationType.VOICE_RECORDING:
      case AnimationType.VOICE_WAVE:
        return AnimationPresets.BREATHING;
        
      case AnimationType.VOICE_PROCESSING:
        return AnimationPresets.PULSE;
        
      case AnimationType.LOADING:
        return AnimationPresets.PULSE;
        
      case AnimationType.SUCCESS:
        return AnimationPresets.ELEGANT;
        
      case AnimationType.ERROR:
        return AnimationPresets.EMPHASIS;
        
      case AnimationType.MODAL_ENTER:
      case AnimationType.MODAL_EXIT:
        return AnimationPresets.STANDARD;
        
      case AnimationType.DRAWER_SLIDE_IN:
      case AnimationType.DRAWER_SLIDE_OUT:
        return AnimationPresets.SMOOTH;
        
      default:
        return AnimationPresets.STANDARD;
    }
  }

  /**
   * 根据性能模式调整动画配置
   */
  private adjustForPerformance(config: AnimationConfig): AnimationConfig {
    switch (this.performanceMode) {
      case 'high':
        return config; // 高性能模式，使用原始配置
        
      case 'power_save':
        return {
          ...config,
          duration: Math.min(config.duration * 0.7, 200), // 缩短动画时长
          curve: Curve.FastOutSlowIn // 使用简单曲线
        };
        
      case 'balanced':
      default:
        return {
          ...config,
          duration: config.duration * 0.85 // 略微缩短时长
        };
    }
  }

  /**
   * 创建春天曲线
   */
  createSpringCurve(config: SpringConfig): ICurve {
    return curves.springCurve(config.stiffness, config.damping, config.mass);
  }

  /**
   * 创建 SpringMotion 曲线
   */
  createSpringMotion(config: SpringMotionConfig): ICurve {
    return curves.springMotion(config.response, config.dampingFraction, config.overlapDuration);
  }

  /**
   * 创建响应式春天动作
   */
  createResponsiveSpring(config: SpringConfig): ICurve {
    return curves.responsiveSpringMotion(config.stiffness, config.damping, config.mass);
  }

  /**
   * 设置减少动画模式
   */
  setReducedMotion(enabled: boolean): void {
    this.isReducedMotion = enabled;
    Logger.info('AnimationManager', `减少动画模式: ${enabled ? '启用' : '禁用'}`);
  }

  /**
   * 设置性能模式
   */
  setPerformanceMode(mode: 'high' | 'balanced' | 'power_save'): void {
    this.performanceMode = mode;
    Logger.info('AnimationManager', `性能模式设置为: ${mode}`);
  }

  /**
   * 注册动画
   */
  registerAnimation(id: string, animation: object): void {
    this.activeAnimations.set(id, animation);
  }

  /**
   * 取消动画
   */
  cancelAnimation(id: string): void {
    const animation = this.activeAnimations.get(id);
    if (animation) {
      this.activeAnimations.delete(id);
    }
  }

  /**
   * 取消所有动画
   */
  cancelAllAnimations(): void {
    this.activeAnimations.clear();
  }

  /**
   * 添加动画到队列
   */
  queueAnimation(animationFn: () => void): void {
    this.animationQueue.push(animationFn);
    this.processQueue();
  }

  /**
   * 处理动画队列
   */
  private async processQueue(): Promise<void> {
    if (this.isProcessingQueue || this.animationQueue.length === 0) {
      return;
    }

    this.isProcessingQueue = true;
    
    while (this.animationQueue.length > 0) {
      const animation = this.animationQueue.shift();
      if (animation) {
        try {
          animation();
          // 等待一小段时间，避免动画冲突
          await new Promise(resolve => setTimeout(resolve, 16)); // 约一帧的时间
        } catch (error) {
          Logger.error('AnimationManager', `动画执行错误: ${error}`);
        }
      }
    }
    
    this.isProcessingQueue = false;
  }

  /**
   * 获取主题适配的动画参数
   */
  getThemeAdaptedParams<T>(lightValue: T, darkValue: T): T {
    return this.themeManager.getDarkMode() ? darkValue : lightValue;
  }

  /**
   * 清理资源
   */
  destroy(): void {
    this.cancelAllAnimations();
    this.animationQueue = [];
    Logger.info('AnimationManager', '动画管理器已销毁');
  }
}