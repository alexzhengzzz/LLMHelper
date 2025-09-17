import { AnimationManager, AnimationType } from './AnimationManager';
import { Logger } from '../utils/Logger';

/**
 * 过渡效果配置接口
 */
interface TransitionConfig {
  type: TransitionType;
  translate?: { x: number; y: number };
  opacity?: number;
  scale?: { x: number; y: number };
}

/**
 * 动画项配置接口
 */
interface AnimationItem {
  index: number;
  delay: number;
  transition: TransitionConfig;
  animation: {
    duration: number;
    curve: Curve | ICurve;
    delay: number;
  };
}

/**
 * 页面过渡方向
 */
export enum TransitionDirection {
  LEFT_TO_RIGHT = 'left_to_right',
  RIGHT_TO_LEFT = 'right_to_left',
  TOP_TO_BOTTOM = 'top_to_bottom',
  BOTTOM_TO_TOP = 'bottom_to_top',
  FADE = 'fade',
  SCALE = 'scale'
}

/**
 * 页面过渡动画类
 */
export class TransitionAnimations {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 页面进入动画
   */
  static pageEnterTransition(direction: TransitionDirection = TransitionDirection.RIGHT_TO_LEFT): TransitionConfig {
    const config = TransitionAnimations.animationManager.getAnimationConfig(AnimationType.PAGE_ENTER);
    
    switch (direction) {
      case TransitionDirection.LEFT_TO_RIGHT:
        return {
          type: TransitionType.Insert,
          translate: { x: -100, y: 0 },
          opacity: 0,
          scale: { x: 0.95, y: 0.95 }
        } as TransitionConfig;
        
      case TransitionDirection.RIGHT_TO_LEFT:
        return {
          type: TransitionType.Insert,
          translate: { x: 100, y: 0 },
          opacity: 0,
          scale: { x: 0.95, y: 0.95 }
        };
        
      case TransitionDirection.TOP_TO_BOTTOM:
        return {
          type: TransitionType.Insert,
          translate: { x: 0, y: -100 },
          opacity: 0,
          scale: { x: 0.95, y: 0.95 }
        };
        
      case TransitionDirection.BOTTOM_TO_TOP:
        return {
          type: TransitionType.Insert,
          translate: { x: 0, y: 100 },
          opacity: 0,
          scale: { x: 0.95, y: 0.95 }
        };
        
      case TransitionDirection.FADE:
        return {
          type: TransitionType.Insert,
          opacity: 0,
          scale: { x: 1.05, y: 1.05 }
        };
        
      case TransitionDirection.SCALE:
        return {
          type: TransitionType.Insert,
          opacity: 0,
          scale: { x: 0.8, y: 0.8 }
        };
        
      default:
        return {
          type: TransitionType.Insert,
          translate: { x: 100, y: 0 },
          opacity: 0
        };
    }
  }

  /**
   * 页面退出动画
   */
  static pageExitTransition(direction: TransitionDirection = TransitionDirection.RIGHT_TO_LEFT) {
    const config = this.animationManager.getAnimationConfig(AnimationType.PAGE_EXIT);
    
    switch (direction) {
      case TransitionDirection.LEFT_TO_RIGHT:
        return {
          type: TransitionType.Delete,
          translate: { x: 100, y: 0 },
          opacity: 0,
          scale: { x: 0.95, y: 0.95 }
        };
        
      case TransitionDirection.RIGHT_TO_LEFT:
        return {
          type: TransitionType.Delete,
          translate: { x: -100, y: 0 },
          opacity: 0,
          scale: { x: 0.95, y: 0.95 }
        };
        
      case TransitionDirection.TOP_TO_BOTTOM:
        return {
          type: TransitionType.Delete,
          translate: { x: 0, y: 100 },
          opacity: 0,
          scale: { x: 0.95, y: 0.95 }
        };
        
      case TransitionDirection.BOTTOM_TO_TOP:
        return {
          type: TransitionType.Delete,
          translate: { x: 0, y: -100 },
          opacity: 0,
          scale: { x: 0.95, y: 0.95 }
        };
        
      case TransitionDirection.FADE:
        return {
          type: TransitionType.Delete,
          opacity: 0,
          scale: { x: 0.95, y: 0.95 }
        };
        
      case TransitionDirection.SCALE:
        return {
          type: TransitionType.Delete,
          opacity: 0,
          scale: { x: 1.2, y: 1.2 }
        };
        
      default:
        return {
          type: TransitionType.Delete,
          translate: { x: -100, y: 0 },
          opacity: 0
        };
    }
  }

  /**
   * 模态框进入动画
   */
  static modalEnterTransition() {
    return {
      type: TransitionType.Insert,
      translate: { x: 0, y: 50 },
      opacity: 0,
      scale: { x: 0.9, y: 0.9 }
    };
  }

  /**
   * 模态框退出动画
   */
  static modalExitTransition() {
    return {
      type: TransitionType.Delete,
      translate: { x: 0, y: 30 },
      opacity: 0,
      scale: { x: 0.95, y: 0.95 }
    };
  }

  /**
   * 侧边栏滑入动画
   */
  static drawerSlideInTransition() {
    return {
      type: TransitionType.Insert,
      translate: { x: -100, y: 0 },
      opacity: 0
    };
  }

  /**
   * 侧边栏滑出动画
   */
  static drawerSlideOutTransition() {
    return {
      type: TransitionType.Delete,
      translate: { x: -100, y: 0 },
      opacity: 0
    };
  }

  /**
   * 列表项出现动画
   */
  static listItemAppearTransition(index: number = 0) {
    return {
      type: TransitionType.Insert,
      translate: { x: 30, y: 0 },
      opacity: 0,
      scale: { x: 0.95, y: 0.95 }
    };
  }

  /**
   * 列表项消失动画
   */
  static listItemDisappearTransition(index: number = 0) {
    return {
      type: TransitionType.Delete,
      translate: { x: -30, y: 0 },
      opacity: 0,
      scale: { x: 0.95, y: 0.95 }
    };
  }

  /**
   * 共享元素过渡
   */
  static sharedElementTransition(elementId: string) {
    const config = this.animationManager.getAnimationConfig(AnimationType.PAGE_ENTER);
    
    return {
      id: elementId,
      type: TransitionType.Insert,
      scale: { x: 1, y: 1 },
      opacity: 1
    };
  }

  /**
   * 创建自定义页面转场动画
   */
  static createCustomPageTransition(
    enterTransition: any,
    exitTransition: any,
    duration?: number
  ) {
    return {
      enter: enterTransition,
      exit: exitTransition,
      duration: duration || this.animationManager.getAnimationConfig(AnimationType.PAGE_ENTER).duration
    };
  }
}

/**
 * 过渡动画工具类
 */
export class TransitionUtils {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 应用进入动画到组件
   */
  static applyEnterAnimation(
    component: any, 
    direction: TransitionDirection = TransitionDirection.FADE,
    delay: number = 0
  ) {
    const config = this.animationManager.getAnimationConfig(AnimationType.PAGE_ENTER);
    const transition = TransitionAnimations.pageEnterTransition(direction);
    
    if (component && typeof component.transition === 'function') {
      component.transition({
        ...transition,
        animation: {
          duration: config.duration,
          curve: config.curve,
          delay: delay
        }
      });
    }
  }

  /**
   * 应用退出动画到组件
   */
  static applyExitAnimation(
    component: any, 
    direction: TransitionDirection = TransitionDirection.FADE,
    onComplete?: () => void
  ) {
    const config = this.animationManager.getAnimationConfig(AnimationType.PAGE_EXIT);
    const transition = TransitionAnimations.pageExitTransition(direction);
    
    if (component && typeof component.transition === 'function') {
      component.transition({
        ...transition,
        animation: {
          duration: config.duration,
          curve: config.curve,
          onFinish: onComplete
        }
      });
    }
  }

  /**
   * 创建渐进式列表动画
   */
  static createStaggeredListAnimation(itemCount: number, staggerDelay: number = 50) {
    const animations = [];
    const config = this.animationManager.getAnimationConfig(AnimationType.LIST_ITEM_APPEAR);
    
    for (let i = 0; i < itemCount; i++) {
      animations.push({
        index: i,
        delay: i * staggerDelay,
        transition: TransitionAnimations.listItemAppearTransition(i),
        animation: {
          duration: config.duration,
          curve: config.curve,
          delay: i * staggerDelay
        }
      });
    }
    
    return animations;
  }

  /**
   * 页面路由转场动画配置
   */
  static getRouteTransition(fromPage: string, toPage: string): any {
    // 根据页面类型决定转场方向
    const pageHierarchy = {
      'ChatPage': 0,
      'SettingsPage': 1,
      'SystemPromptManagerPage': 2
    };

    const fromLevel = pageHierarchy[fromPage] ?? 0;
    const toLevel = pageHierarchy[toPage] ?? 0;
    
    const direction = toLevel > fromLevel 
      ? TransitionDirection.RIGHT_TO_LEFT 
      : TransitionDirection.LEFT_TO_RIGHT;

    return TransitionAnimations.createCustomPageTransition(
      TransitionAnimations.pageEnterTransition(direction),
      TransitionAnimations.pageExitTransition(direction)
    );
  }

  /**
   * 获取弹性返回动画
   */
  static getBouncBackAnimation() {
    return {
      scale: { x: 1.05, y: 1.05 },
      animation: {
        duration: 100,
        curve: this.animationManager.createSpringCurve({
          stiffness: 500,
          damping: 30
        }),
        playMode: PlayMode.Alternate,
        iterations: 2
      }
    };
  }
}