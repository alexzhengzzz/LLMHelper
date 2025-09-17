import { AnimationManager, AnimationType } from './AnimationManager';
import { Logger } from '../utils/Logger';
import { curves } from '@kit.ArkUI';

/**
 * 应用状态枚举
 */
export enum AppState {
  LOADING = 'loading',
  LOADED = 'loaded',
  ERROR = 'error',
  SUCCESS = 'success',
  UPDATING = 'updating',
  SYNCING = 'syncing',
  OFFLINE = 'offline',
  ONLINE = 'online'
}

/**
 * 数据状态枚举
 */
export enum DataState {
  FETCHING = 'fetching',
  REFRESHING = 'refreshing',
  PAGINATING = 'paginating',
  SEARCHING = 'searching',
  FILTERING = 'filtering',
  SORTING = 'sorting'
}

/**
 * 状态变化动画类
 */
export class StateAnimations {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 通用加载动画
   */
  static loadingAnimation() {
    const config = this.animationManager.getAnimationConfig(AnimationType.LOADING);
    
    return {
      rotate: { angle: 360 },
      animation: {
        duration: 1000,
        curve: Curve.Linear,
        iterations: -1
      }
    };
  }

  /**
   * 骨架屏加载动画
   */
  static skeletonLoadingAnimation() {
    return {
      opacity: 0.3,
      animation: {
        duration: 1200,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate
      }
    };
  }

  /**
   * 进度条动画
   */
  static progressBarAnimation(progress: number) {
    const normalizedProgress = Math.max(0, Math.min(1, progress));
    
    return {
      scale: { x: normalizedProgress, y: 1 },
      animation: {
        duration: 300,
        curve: curves.springMotion(0.75, 0.85)
      }
    };
  }

  /**
   * 成功状态动画
   */
  static successAnimation() {
    const config = this.animationManager.getAnimationConfig(AnimationType.SUCCESS);
    
    return {
      scale: { x: 1.2, y: 1.2 },
      opacity: 1,
      animation: {
        duration: config.duration,
        curve: config.curve,
        keyframes: [
          { scale: { x: 0, y: 0 }, opacity: 0, time: 0 },
          { scale: { x: 1.3, y: 1.3 }, opacity: 1, time: 0.7 },
          { scale: { x: 1, y: 1 }, opacity: 1, time: 1 }
        ]
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
      backgroundColor: '#FFEBEE',
      animation: {
        duration: config.duration,
        curve: config.curve,
        playMode: config.playMode,
        iterations: config.iterations
      }
    };
  }

  /**
   * 网络状态切换动画
   */
  static networkStateAnimation(isOnline: boolean) {
    return {
      opacity: isOnline ? 1 : 0.5,
      scale: { x: isOnline ? 1 : 0.9, y: isOnline ? 1 : 0.9 },
      animation: {
        duration: 400,
        curve: curves.springMotion(0.7, 0.9)
      }
    };
  }

  /**
   * 主题切换动画
   */
  static themeTransitionAnimation() {
    return {
      opacity: 0,
      animation: {
        duration: 300,
        curve: Curve.EaseInOut,
        onFinish: () => {
          return {
            opacity: 1,
            animation: {
              duration: 300,
              curve: Curve.EaseInOut
            }
          };
        }
      }
    };
  }

  /**
   * 数据刷新动画
   */
  static refreshAnimation() {
    return {
      rotate: { angle: 360 },
      scale: { x: 1.1, y: 1.1 },
      animation: {
        duration: 800,
        curve: curves.springMotion(0.6, 0.8),
        iterations: 2
      }
    };
  }

  /**
   * 数据同步动画
   */
  static syncAnimation() {
    return {
      translate: { x: 0, y: -5 },
      opacity: 0.8,
      animation: {
        duration: 600,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate
      }
    };
  }

  /**
   * 搜索状态动画
   */
  static searchAnimation() {
    return {
      scale: { x: 1.05, y: 1.05 },
      borderWidth: 2,
      animation: {
        duration: 200,
        curve: curves.springMotion(0.8, 0.75)
      }
    };
  }

  /**
   * 过滤状态动画
   */
  static filterAnimation() {
    return {
      opacity: 0.7,
      scale: { x: 0.98, y: 0.98 },
      animation: {
        duration: 250,
        curve: Curve.EaseOut
      }
    };
  }

  /**
   * 排序状态动画
   */
  static sortAnimation(direction: 'asc' | 'desc') {
    const rotateAngle = direction === 'asc' ? 0 : 180;
    
    return {
      rotate: { angle: rotateAngle },
      animation: {
        duration: 300,
        curve: curves.springMotion(0.75, 0.85)
      }
    };
  }

  /**
   * 连接状态动画
   */
  static connectionAnimation(isConnected: boolean) {
    return {
      opacity: isConnected ? 1 : 0.4,
      scale: { x: isConnected ? 1 : 0.9, y: isConnected ? 1 : 0.9 },
      animation: {
        duration: 400,
        curve: curves.springMotion(0.7, 0.9)
      }
    };
  }

  /**
   * 电池状态动画
   */
  static batteryLevelAnimation(level: number) {
    const normalizedLevel = Math.max(0, Math.min(1, level));
    const color = normalizedLevel > 0.2 ? '#4CAF50' : '#F44336';
    
    return {
      scale: { x: normalizedLevel, y: 1 },
      backgroundColor: color,
      animation: {
        duration: 500,
        curve: Curve.EaseOut
      }
    };
  }
}

/**
 * 复杂状态动画类
 */
export class ComplexStateAnimations {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 多步骤加载动画
   */
  static multiStepLoadingAnimation(steps: string[], currentStep: number) {
    const animations = [];
    
    steps.forEach((step, index) => {
      const isActive = index === currentStep;
      const isCompleted = index < currentStep;
      
      let animation;
      if (isCompleted) {
        animation = {
          opacity: 1,
          backgroundColor: '#4CAF50',
          scale: { x: 1, y: 1 }
        };
      } else if (isActive) {
        animation = {
          opacity: 1,
          backgroundColor: '#2196F3',
          scale: { x: 1.1, y: 1.1 },
          animation: {
            duration: 1000,
            curve: Curve.EaseInOut,
            iterations: -1,
            playMode: PlayMode.Alternate
          }
        };
      } else {
        animation = {
          opacity: 0.3,
          backgroundColor: '#E0E0E0',
          scale: { x: 0.9, y: 0.9 }
        };
      }
      
      animations.push(animation);
    });
    
    return animations;
  }

  /**
   * 状态机过渡动画
   */
  static stateMachineTransition(fromState: string, toState: string) {
    const transitions = {
      'loading_to_success': {
        duration: 600,
        keyframes: [
          { scale: { x: 1, y: 1 }, rotate: { angle: 0 }, time: 0 },
          { scale: { x: 0.8, y: 0.8 }, rotate: { angle: 180 }, time: 0.5 },
          { scale: { x: 1.2, y: 1.2 }, rotate: { angle: 360 }, time: 0.8 },
          { scale: { x: 1, y: 1 }, rotate: { angle: 360 }, time: 1 }
        ]
      },
      'loading_to_error': {
        duration: 400,
        keyframes: [
          { scale: { x: 1, y: 1 }, translate: { x: 0, y: 0 }, time: 0 },
          { scale: { x: 1.1, y: 1.1 }, translate: { x: 5, y: 0 }, time: 0.3 },
          { scale: { x: 0.9, y: 0.9 }, translate: { x: -5, y: 0 }, time: 0.6 },
          { scale: { x: 1, y: 1 }, translate: { x: 0, y: 0 }, time: 1 }
        ]
      },
      'error_to_retry': {
        duration: 500,
        keyframes: [
          { opacity: 1, scale: { x: 1, y: 1 }, time: 0 },
          { opacity: 0.5, scale: { x: 0.8, y: 0.8 }, time: 0.4 },
          { opacity: 1, scale: { x: 1.1, y: 1.1 }, time: 0.7 },
          { opacity: 1, scale: { x: 1, y: 1 }, time: 1 }
        ]
      }
    };
    
    const transitionKey = `${fromState}_to_${toState}`;
    return transitions[transitionKey] || {
      duration: 300,
      curve: Curve.EaseInOut
    };
  }

  /**
   * 级联状态更新动画
   */
  static cascadingStateUpdate(items: any[], delay: number = 50) {
    const animations = [];
    
    items.forEach((item, index) => {
      animations.push({
        opacity: 0,
        scale: { x: 0.8, y: 0.8 },
        translate: { x: 0, y: 20 },
        animation: {
          duration: 400,
          curve: curves.springMotion(0.75, 0.85),
          delay: index * delay
        }
      });
    });
    
    return animations;
  }

  /**
   * 状态回滚动画
   */
  static stateRollbackAnimation() {
    return {
      rotate: { angle: -360 },
      scale: { x: 0.9, y: 0.9 },
      animation: {
        duration: 800,
        curve: curves.springMotion(0.6, 0.8),
        keyframes: [
          { rotate: { angle: 0 }, scale: { x: 1, y: 1 }, time: 0 },
          { rotate: { angle: -180 }, scale: { x: 0.7, y: 0.7 }, time: 0.5 },
          { rotate: { angle: -360 }, scale: { x: 1, y: 1 }, time: 1 }
        ]
      }
    };
  }

  /**
   * 实时状态监控动画
   */
  static realtimeStatusAnimation(status: 'active' | 'warning' | 'critical') {
    const statusConfigs = {
      active: {
        color: '#4CAF50',
        scale: { x: 1, y: 1 },
        duration: 2000
      },
      warning: {
        color: '#FF9800',
        scale: { x: 1.1, y: 1.1 },
        duration: 1000
      },
      critical: {
        color: '#F44336',
        scale: { x: 1.2, y: 1.2 },
        duration: 500
      }
    };
    
    const config = statusConfigs[status];
    
    return {
      backgroundColor: config.color,
      scale: config.scale,
      animation: {
        duration: config.duration,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate
      }
    };
  }
}

/**
 * 状态动画工具类
 */
export class StateAnimationUtils {
  private static animationManager = AnimationManager.getInstance();

  /**
   * 应用状态变化动画
   */
  static applyStateAnimation(
    component: any,
    fromState: AppState,
    toState: AppState,
    params?: any
  ) {
    const transition = ComplexStateAnimations.stateMachineTransition(fromState, toState);
    
    if (component && transition) {
      Logger.info('StateAnimationUtils', `应用状态动画: ${fromState} -> ${toState}`);
    }
  }

  /**
   * 创建状态指示器动画
   */
  static createStatusIndicator(status: 'online' | 'offline' | 'away' | 'busy') {
    const statusConfigs = {
      online: { color: '#4CAF50', opacity: 1 },
      offline: { color: '#9E9E9E', opacity: 0.5 },
      away: { color: '#FF9800', opacity: 0.8 },
      busy: { color: '#F44336', opacity: 1 }
    };
    
    const config = statusConfigs[status];
    
    return {
      backgroundColor: config.color,
      opacity: config.opacity,
      animation: {
        duration: 300,
        curve: curves.springMotion(0.75, 0.85)
      }
    };
  }

  /**
   * 创建进度环动画
   */
  static createProgressRing(progress: number, total: number) {
    const percentage = Math.min(100, (progress / total) * 100);
    const circumference = 2 * Math.PI * 50; // 假设半径为50
    const strokeDashoffset = circumference - (percentage / 100) * circumference;
    
    return {
      strokeDasharray: circumference,
      strokeDashoffset: strokeDashoffset,
      animation: {
        duration: 500,
        curve: Curve.EaseOut
      }
    };
  }

  /**
   * 创建状态切换过渡效果
   */
  static createStateTransition(duration: number = 300) {
    return {
      opacity: 0,
      scale: { x: 0.9, y: 0.9 },
      animation: {
        duration: duration / 2,
        curve: Curve.EaseIn,
        onFinish: () => {
          return {
            opacity: 1,
            scale: { x: 1, y: 1 },
            animation: {
              duration: duration / 2,
              curve: Curve.EaseOut
            }
          };
        }
      }
    };
  }

  /**
   * 获取自适应状态动画
   */
  static getAdaptiveStateAnimation(complexity: 'simple' | 'standard' | 'complex') {
    const complexityConfigs = {
      simple: { duration: 200, curve: curves.springMotion(0.9, 0.8) },
      standard: { duration: 300, curve: curves.springMotion(0.75, 0.85) },
      complex: { duration: 500, curve: curves.springMotion(0.6, 0.9) }
    };
    
    return complexityConfigs[complexity];
  }
}