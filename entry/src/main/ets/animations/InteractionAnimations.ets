import { AnimationManager, AnimationType } from './AnimationManager';
import { Logger } from '../utils/Logger';
import { curves } from '@kit.ArkUI';

/**
 * 交互动画效果类型
 */
export enum InteractionEffect {
  PRESS = 'press',
  RELEASE = 'release',
  HOVER = 'hover',
  FOCUS = 'focus',
  BLUR = 'blur',
  SUCCESS = 'success',
  ERROR = 'error',
  LOADING = 'loading'
}

/**
 * 组件交互动画类
 */
export class InteractionAnimations {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 按钮按下动画
   */
  static buttonPressAnimation() {
    const config = this.animationManager.getAnimationConfig(AnimationType.BUTTON_PRESS);
    
    return {
      scale: { x: 0.95, y: 0.95 },
      animation: {
        duration: config.duration,
        curve: config.curve
      }
    };
  }

  /**
   * 按钮释放动画
   */
  static buttonReleaseAnimation() {
    const config = this.animationManager.getAnimationConfig(AnimationType.BUTTON_RELEASE);
    
    return {
      scale: { x: 1.0, y: 1.0 },
      animation: {
        duration: config.duration,
        curve: this.animationManager.createSpringMotion({
          response: 0.8,
          dampingFraction: 0.75
        })
      }
    };
  }

  /**
   * 按钮悬停动画
   */
  static buttonHoverAnimation() {
    return {
      scale: { x: 1.02, y: 1.02 },
      animation: {
        duration: 200,
        curve: curves.springMotion(0.8, 0.85)
      }
    };
  }

  /**
   * 涟漪点击效果
   */
  static rippleEffect(centerX: number, centerY: number) {
    return {
      centerX,
      centerY,
      scale: { x: 0, y: 0 },
      opacity: 0.6,
      animation: {
        duration: 300,
        curve: Curve.FastOutSlowIn
      }
    };
  }

  /**
   * 输入框焦点动画
   */
  static inputFocusAnimation() {
    return {
      borderWidth: 2,
      scale: { x: 1.01, y: 1.01 },
      animation: {
        duration: 200,
        curve: curves.springMotion(0.75, 0.8)
      }
    };
  }

  /**
   * 输入框失去焦点动画
   */
  static inputBlurAnimation() {
    return {
      borderWidth: 1,
      scale: { x: 1.0, y: 1.0 },
      animation: {
        duration: 200,
        curve: curves.springMotion(0.75, 0.9)
      }
    };
  }

  /**
   * 成功状态动画
   */
  static successAnimation() {
    const config = this.animationManager.getAnimationConfig(AnimationType.SUCCESS);
    
    return {
      scale: { x: 1.1, y: 1.1 },
      animation: {
        duration: config.duration,
        curve: config.curve,
        playMode: PlayMode.Alternate,
        iterations: 2
      }
    };
  }

  /**
   * 错误状态动画
   */
  static errorAnimation() {
    const config = this.animationManager.getAnimationConfig(AnimationType.ERROR);
    
    return {
      translate: { x: 5, y: 0 },
      animation: {
        duration: 100,
        curve: Curve.Sharp,
        playMode: PlayMode.Alternate,
        iterations: 6
      }
    };
  }

  /**
   * 卡片悬停动画
   */
  static cardHoverAnimation() {
    return {
      translate: { x: 0, y: -2 },
      scale: { x: 1.02, y: 1.02 },
      animation: {
        duration: 300,
        curve: curves.springMotion(0.7, 0.85)
      }
    };
  }

  /**
   * 卡片点击动画
   */
  static cardPressAnimation() {
    return {
      scale: { x: 0.98, y: 0.98 },
      animation: {
        duration: 150,
        curve: curves.springMotion(0.85, 0.8)
      }
    };
  }

  /**
   * 列表项滑动显示动画
   */
  static listItemSlideInAnimation(delay: number = 0) {
    const config = this.animationManager.getAnimationConfig(AnimationType.LIST_ITEM_APPEAR);
    
    return {
      translate: { x: 50, y: 0 },
      opacity: 0,
      animation: {
        duration: config.duration,
        curve: config.curve,
        delay: delay
      }
    };
  }

  /**
   * 开关切换动画
   */
  static switchToggleAnimation(isOn: boolean) {
    return {
      translate: { x: isOn ? 20 : 0, y: 0 },
      animation: {
        duration: 200,
        curve: curves.springMotion(0.8, 0.75)
      }
    };
  }

  /**
   * 标签页切换动画
   */
  static tabSwitchAnimation(direction: 'left' | 'right') {
    const translateX = direction === 'left' ? -30 : 30;
    
    return {
      translate: { x: translateX, y: 0 },
      opacity: 0,
      animation: {
        duration: 250,
        curve: curves.springMotion(0.75, 0.88)
      }
    };
  }

  /**
   * 通知弹出动画
   */
  static notificationPopupAnimation() {
    return {
      translate: { x: 0, y: -50 },
      opacity: 0,
      scale: { x: 0.9, y: 0.9 },
      animation: {
        duration: 400,
        curve: curves.springMotion(0.65, 0.9)
      }
    };
  }

  /**
   * 通知消失动画
   */
  static notificationDismissAnimation() {
    return {
      translate: { x: 100, y: 0 },
      opacity: 0,
      animation: {
        duration: 300,
        curve: Curve.FastOutSlowIn
      }
    };
  }

  /**
   * 下拉刷新动画
   */
  static pullRefreshAnimation(progress: number) {
    const rotation = progress * 360;
    
    return {
      rotate: { angle: rotation },
      scale: { x: Math.min(progress + 0.5, 1), y: Math.min(progress + 0.5, 1) },
      animation: {
        duration: 100,
        curve: Curve.Linear
      }
    };
  }

  /**
   * 加载更多动画
   */
  static loadMoreAnimation() {
    return {
      opacity: 0,
      scale: { x: 0.8, y: 0.8 },
      animation: {
        duration: 300,
        curve: curves.springMotion(0.75, 0.85)
      }
    };
  }
}

/**
 * 交互动画工具类
 */
export class InteractionUtils {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 创建触觉反馈动画
   */
  static createHapticFeedbackAnimation() {
    return {
      scale: { x: 0.98, y: 0.98 },
      animation: {
        duration: 50,
        curve: Curve.Sharp,
        playMode: PlayMode.Alternate,
        iterations: 2
      }
    };
  }

  /**
   * 创建弹性点击效果
   */
  static createElasticClickEffect() {
    return {
      scale: { x: 0.95, y: 0.95 },
      animation: {
        duration: 100,
        curve: this.animationManager.createSpringMotion({
          response: 0.9,
          dampingFraction: 0.7
        }),
        onFinish: () => {
          // 释放时的弹回动画
          return {
            scale: { x: 1.05, y: 1.05 },
            animation: {
              duration: 200,
              curve: this.animationManager.createSpringMotion({
                response: 0.8,
                dampingFraction: 0.75,
                overlapDuration: 200
              }),
              playMode: PlayMode.Alternate,
              iterations: 2
            }
          };
        }
      }
    };
  }

  /**
   * 创建呼吸光效动画
   */
  static createBreathingGlowEffect(color: string = '#007AFF') {
    return {
      shadowColor: color,
      shadowRadius: 0,
      animation: {
        duration: 2000,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate,
        keyframes: [
          { shadowRadius: 0, time: 0 },
          { shadowRadius: 10, time: 0.5 },
          { shadowRadius: 0, time: 1 }
        ]
      }
    };
  }

  /**
   * 创建粒子爆炸效果（模拟）
   */
  static createParticleExplosion(centerX: number, centerY: number) {
    const particles = [];
    const particleCount = 8;
    
    for (let i = 0; i < particleCount; i++) {
      const angle = (i / particleCount) * 2 * Math.PI;
      const distance = 50;
      const x = Math.cos(angle) * distance;
      const y = Math.sin(angle) * distance;
      
      particles.push({
        translate: { x, y },
        opacity: 0,
        scale: { x: 0, y: 0 },
        animation: {
          duration: 600,
          curve: Curve.FastOutSlowIn,
          delay: i * 20
        }
      });
    }
    
    return particles;
  }

  /**
   * 创建磁吸效果动画
   */
  static createMagneticSnapAnimation(targetX: number, targetY: number) {
    return {
      translate: { x: targetX, y: targetY },
      animation: {
        duration: 300,
        curve: this.animationManager.createSpringMotion({
          response: 0.7,
          dampingFraction: 0.75
        })
      }
    };
  }

  /**
   * 创建摆动动画
   */
  static createWiggleAnimation() {
    return {
      rotate: { angle: 5 },
      animation: {
        duration: 100,
        curve: Curve.Sharp,
        playMode: PlayMode.Alternate,
        iterations: 6
      }
    };
  }

  /**
   * 创建脉冲扩散动画
   */
  static createPulseRippleAnimation() {
    return {
      scale: { x: 3, y: 3 },
      opacity: 0,
      animation: {
        duration: 1500,
        curve: Curve.FastOutSlowIn,
        iterations: -1
      }
    };
  }

  /**
   * 应用交互动画到组件
   */
  static applyInteractionAnimation(
    component: any,
    effect: InteractionEffect,
    params?: any
  ) {
    let animation;
    
    switch (effect) {
      case InteractionEffect.PRESS:
        animation = InteractionAnimations.buttonPressAnimation();
        break;
      case InteractionEffect.RELEASE:
        animation = InteractionAnimations.buttonReleaseAnimation();
        break;
      case InteractionEffect.SUCCESS:
        animation = InteractionAnimations.successAnimation();
        break;
      case InteractionEffect.ERROR:
        animation = InteractionAnimations.errorAnimation();
        break;
      default:
        return;
    }
    
    if (component && animation) {
      // 应用动画到组件
      Logger.info('InteractionUtils', `应用${effect}动画效果`);
    }
  }
}