import { curves } from '@kit.ArkUI';
import { ChatPageState, ChatPageStateManager } from './ChatPageStateManager';
import { Logger } from './Logger';
import { BasicAnimations, AnimationConfigManager } from '../animations';

/**
 * ChatPage动画控制器 - 统一管理页面动画效果
 */
export class ChatPageAnimationController {
  private stateManager: ChatPageStateManager;

  // 动画配置常量
  private readonly ANIMATION_DURATION = 300;
  private readonly SPRING_ANIMATION_DURATION = 400;
  private readonly BOUNCE_CURVE = curves.springMotion(0.8, 1.0);
  private readonly EASE_OUT_CURVE = curves.cubicBezier(0.25, 0.8, 0.25, 1);

  constructor(stateManager: ChatPageStateManager) {
    this.stateManager = stateManager;
  }

  /**
   * 初始化动画系统
   */
  initialize(): void {
    AnimationConfigManager.getInstance().initialize();
    Logger.info('ChatPageAnimationController', '动画控制器初始化完成');
  }

  /**
   * 显示模型选择器动画
   */
  showModelSelector(state: ChatPageState): void {
    this.stateManager.showModelSelector(state);

    // 透明度动画
    animateTo({
      duration: this.ANIMATION_DURATION,
      curve: this.EASE_OUT_CURVE,
      onFinish: () => {
        Logger.debug('ChatPageAnimationController', '模型选择器显示动画完成');
      }
    }, () => {
      state.modelSelectorOpacity = 1.0;
    });

    // Y轴位移动画
    animateTo({
      duration: this.SPRING_ANIMATION_DURATION,
      curve: this.BOUNCE_CURVE,
      delay: 50
    }, () => {
      state.modelSelectorTranslateY = 0;
    });
  }

  /**
   * 隐藏模型选择器动画
   */
  hideModelSelector(state: ChatPageState): void {
    // 透明度动画
    animateTo({
      duration: this.ANIMATION_DURATION * 0.8,
      curve: curves.ease,
      onFinish: () => {
        this.stateManager.hideModelSelector(state);
        Logger.debug('ChatPageAnimationController', '模型选择器隐藏动画完成');
      }
    }, () => {
      state.modelSelectorOpacity = 0.0;
    });

    // Y轴位移动画
    animateTo({
      duration: this.ANIMATION_DURATION * 0.8,
      curve: curves.ease
    }, () => {
      state.modelSelectorTranslateY = 400;
    });
  }

  /**
   * 显示工具箱面板动画
   */
  showToolboxPanel(state: ChatPageState): void {
    this.stateManager.toggleToolboxPanel(state);

    // 透明度动画
    animateTo({
      duration: this.ANIMATION_DURATION,
      curve: this.EASE_OUT_CURVE,
      onFinish: () => {
        Logger.debug('ChatPageAnimationController', '工具箱面板显示动画完成');
      }
    }, () => {
      state.toolboxPanelOpacity = 1.0;
    });

    // Y轴位移动画
    animateTo({
      duration: this.SPRING_ANIMATION_DURATION,
      curve: this.BOUNCE_CURVE,
      delay: 50
    }, () => {
      state.toolboxPanelTranslateY = 0;
    });
  }

  /**
   * 隐藏工具箱面板动画
   */
  hideToolboxPanel(state: ChatPageState): void {
    // 透明度动画
    animateTo({
      duration: this.ANIMATION_DURATION * 0.8,
      curve: curves.ease,
      onFinish: () => {
        state.showToolboxPanel = false;
        Logger.debug('ChatPageAnimationController', '工具箱面板隐藏动画完成');
      }
    }, () => {
      state.toolboxPanelOpacity = 0.0;
    });

    // Y轴位移动画
    animateTo({
      duration: this.ANIMATION_DURATION * 0.8,
      curve: curves.ease
    }, () => {
      state.toolboxPanelTranslateY = 400;
    });
  }

  /**
   * 切换工具箱面板动画
   */
  toggleToolboxPanel(state: ChatPageState): void {
    if (state.showToolboxPanel) {
      this.hideToolboxPanel(state);
    } else {
      this.showToolboxPanel(state);
    }
  }

  /**
   * 侧边栏滑动进度动画
   */
  updateSideDrawerProgress(state: ChatPageState, progress: number): void {
    animateTo({
      duration: 100,
      curve: curves.ease
    }, () => {
      this.stateManager.updateSideDrawerSwipeProgress(state, progress);
    });
  }

  /**
   * 侧边栏显示动画
   */
  showSideDrawer(state: ChatPageState): void {
    this.stateManager.showSideDrawer(state);

    animateTo({
      duration: this.ANIMATION_DURATION,
      curve: this.EASE_OUT_CURVE,
      onFinish: () => {
        Logger.debug('ChatPageAnimationController', '侧边栏显示动画完成');
      }
    }, () => {
      this.stateManager.updateSideDrawerSwipeProgress(state, 1.0);
    });
  }

  /**
   * 侧边栏隐藏动画
   */
  hideSideDrawer(state: ChatPageState): void {
    animateTo({
      duration: this.ANIMATION_DURATION * 0.8,
      curve: curves.ease,
      onFinish: () => {
        this.stateManager.hideSideDrawer(state);
        Logger.debug('ChatPageAnimationController', '侧边栏隐藏动画完成');
      }
    }, () => {
      this.stateManager.updateSideDrawerSwipeProgress(state, 0.0);
    });
  }

  /**
   * 输入区域高度变化动画
   */
  updateInputAreaHeight(state: ChatPageState, height: number): void {
    animateTo({
      duration: 200,
      curve: curves.ease
    }, () => {
      this.stateManager.updateInputAreaHeight(state, height);
    });
  }

  /**
   * 键盘高度变化动画
   */
  updateKeyboardHeight(state: ChatPageState, height: number): void {
    animateTo({
      duration: 250,
      curve: this.EASE_OUT_CURVE
    }, () => {
      this.stateManager.updateKeyboardHeight(state, height);
    });
  }

  /**
   * 语音输入状态变化动画
   */
  animateVoiceStateChange(): void {
    // 使用基础动画系统的语音动画
    animateTo({
      duration: 200,
      curve: curves.ease
    }, () => {
      // 触发语音状态相关的UI更新
    });
  }

  /**
   * 消息列表滚动动画
   */
  animateScrollToBottom(): void {
    // 平滑滚动动画
    animateTo({
      duration: 300,
      curve: this.EASE_OUT_CURVE
    }, () => {
      // 滚动逻辑将由调用方处理
    });
  }

  /**
   * 快速命令面板切换动画
   */
  toggleQuickCommands(state: ChatPageState): void {
    const isShowing = state.showQuickCommands;

    animateTo({
      duration: this.ANIMATION_DURATION,
      curve: isShowing ? curves.ease : this.BOUNCE_CURVE,
      onFinish: () => {
        Logger.debug('ChatPageAnimationController', `快速命令面板${isShowing ? '隐藏' : '显示'}动画完成`);
      }
    }, () => {
      this.stateManager.toggleQuickCommands(state);
    });
  }

  /**
   * 整体页面淡入动画
   */
  animatePageIn(): void {
    animateTo({
      duration: 500,
      curve: this.EASE_OUT_CURVE,
      onFinish: () => {
        Logger.debug('ChatPageAnimationController', '页面淡入动画完成');
      }
    }, () => {
      // 页面相关的透明度和位移设置
    });
  }

  /**
   * 错误状态动画
   */
  animateErrorState(): void {
    // 抖动动画效果
    animateTo({
      duration: 100,
      curve: curves.ease,
      iterations: 3,
      playMode: PlayMode.Alternate
    }, () => {
      // 轻微的抖动效果
    });
  }

  /**
   * 成功状态动画
   */
  animateSuccessState(): void {
    // 弹跳动画效果
    animateTo({
      duration: 200,
      curve: this.BOUNCE_CURVE
    }, () => {
      // 成功反馈动画
    });
  }

  /**
   * 清理动画资源
   */
  destroy(): void {
    // 清理任何正在进行的动画
    Logger.info('ChatPageAnimationController', '动画控制器已销毁');
  }
}