import { ChatPageState, ChatPageStateManager } from './ChatPageStateManager';
import { ChatPageAnimationController } from './ChatPageAnimationController';
import { Logger } from './Logger';

/**
 * 位置坐标接口
 */
interface Position {
  x: number;
  y: number;
}

/**
 * ChatPage手势处理器 - 统一管理页面手势交互
 */
export class ChatPageGestureHandler {
  private stateManager: ChatPageStateManager;
  private animationController: ChatPageAnimationController;

  // 手势配置常量
  private readonly SIDE_DRAWER_SWIPE_THRESHOLD = 80;
  private readonly SIDE_DRAWER_PROGRESS_THRESHOLD = 0.3;
  private readonly SIDE_DRAWER_EDGE_WIDTH = 20;
  private readonly SWIPE_DEBOUNCE_TIME = 150;
  private readonly DIRECTION_CHANGE_THRESHOLD = 100;

  // 手势状态
  private panStartPosition: Position = { x: 0, y: 0 };
  private lastPanPosition: Position = { x: 0, y: 0 };
  private panVelocity: number = 0;
  private isEdgeSwipe: boolean = false;

  constructor(stateManager: ChatPageStateManager, animationController: ChatPageAnimationController) {
    this.stateManager = stateManager;
    this.animationController = animationController;
  }

  /**
   * 处理侧边栏滑动手势开始
   */
  handleSideDrawerPanStart(state: ChatPageState, event: GestureEvent): void {
    this.panStartPosition = { x: event.fingerList[0].globalX, y: event.fingerList[0].globalY };
    this.lastPanPosition = { ...this.panStartPosition };

    // 检查是否是边缘滑动
    this.isEdgeSwipe = this.panStartPosition.x <= this.SIDE_DRAWER_EDGE_WIDTH;

    if (this.isEdgeSwipe || state.showSideDrawer) {
      this.stateManager.updateSideDrawerSwipeActive(state, true);
      this.stateManager.updateSwipeDebouncing(state, false);
      Logger.debug('ChatPageGestureHandler', `侧边栏滑动开始: x=${this.panStartPosition.x}, 边缘滑动=${this.isEdgeSwipe}`);
    }
  }

  /**
   * 处理侧边栏滑动手势更新
   */
  handleSideDrawerPanUpdate(state: ChatPageState, event: GestureEvent): void {
    if (!state.isSideDrawerSwipeActive && !state.showSideDrawer) {
      return;
    }

    const currentPosition = { x: event.fingerList[0].globalX, y: event.fingerList[0].globalY };
    const deltaX = currentPosition.x - this.panStartPosition.x;
    const velocityX = currentPosition.x - this.lastPanPosition.x;

    this.panVelocity = velocityX;
    this.lastPanPosition = currentPosition;

    // 计算滑动进度
    let progress = 0;
    const screenWidth = 360; // 假设屏幕宽度，实际应该动态获取

    if (state.showSideDrawer) {
      // 侧边栏已打开，处理关闭手势
      progress = Math.max(0, Math.min(1, 1 + deltaX / (screenWidth * 0.7)));
    } else {
      // 侧边栏关闭，处理打开手势
      if (deltaX > 0) {
        progress = Math.min(1, deltaX / (screenWidth * 0.7));
      }
    }

    // 更新滑动方向
    const now = Date.now();
    if (now - state.lastSwipeTime > this.DIRECTION_CHANGE_THRESHOLD) {
      if (velocityX > 5) {
        this.stateManager.updateSwipeDirection(state, 'right');
      } else if (velocityX < -5) {
        this.stateManager.updateSwipeDirection(state, 'left');
      }
      state.lastSwipeTime = now;
    }

    // 防抖处理
    if (!state.isSwipeDebouncing) {
      this.animationController.updateSideDrawerProgress(state, progress);
      this.stateManager.updateSwipeDebouncing(state, true);

      setTimeout(() => {
        this.stateManager.updateSwipeDebouncing(state, false);
      }, 16); // 约60fps
    }

    Logger.debug('ChatPageGestureHandler', `侧边栏滑动更新: progress=${progress.toFixed(2)}, velocity=${velocityX.toFixed(1)}`);
  }

  /**
   * 处理侧边栏滑动手势结束
   */
  handleSideDrawerPanEnd(state: ChatPageState, event: GestureEvent): void {
    if (!state.isSideDrawerSwipeActive && !state.showSideDrawer) {
      return;
    }

    const finalPosition = { x: event.fingerList[0].globalX, y: event.fingerList[0].globalY };
    const totalDeltaX = finalPosition.x - this.panStartPosition.x;
    const shouldOpen = this.shouldOpenSideDrawer(state, totalDeltaX, this.panVelocity);

    Logger.info('ChatPageGestureHandler', `侧边栏滑动结束: deltaX=${totalDeltaX.toFixed(1)}, velocity=${this.panVelocity.toFixed(1)}, shouldOpen=${shouldOpen}`);

    // 根据判断结果显示或隐藏侧边栏
    if (shouldOpen) {
      this.animationController.showSideDrawer(state);
    } else {
      this.animationController.hideSideDrawer(state);
    }

    // 重置手势状态
    this.resetGestureState(state);
  }

  /**
   * 判断是否应该打开侧边栏
   */
  private shouldOpenSideDrawer(state: ChatPageState, deltaX: number, velocity: number): boolean {
    const currentProgress = state.sideDrawerSwipeProgress;

    // 基于速度的判断
    if (Math.abs(velocity) > 10) {
      return velocity > 0;
    }

    // 基于位移的判断
    if (state.showSideDrawer) {
      // 侧边栏已打开，判断是否关闭
      return deltaX > -this.SIDE_DRAWER_SWIPE_THRESHOLD;
    } else {
      // 侧边栏关闭，判断是否打开
      return deltaX > this.SIDE_DRAWER_SWIPE_THRESHOLD || currentProgress > this.SIDE_DRAWER_PROGRESS_THRESHOLD;
    }
  }

  /**
   * 处理点击背景关闭侧边栏
   */
  handleBackgroundTap(state: ChatPageState): void {
    if (state.showSideDrawer) {
      this.animationController.hideSideDrawer(state);
      Logger.debug('ChatPageGestureHandler', '点击背景关闭侧边栏');
    }
  }

  /**
   * 处理工具箱面板手势
   */
  handleToolboxPanGesture(state: ChatPageState, event: GestureEvent): void {
    // 工具箱面板的滑动手势处理
    const deltaY = event.fingerList[0].globalY - this.panStartPosition.y;

    if (deltaY > 50 && state.showToolboxPanel) {
      // 向下滑动超过阈值，关闭工具箱
      this.animationController.hideToolboxPanel(state);
      Logger.debug('ChatPageGestureHandler', '向下滑动关闭工具箱面板');
    }
  }

  /**
   * 处理双击手势
   */
  handleDoubleTap(event: GestureEvent): void {
    const tapPosition = { x: event.fingerList[0].globalX, y: event.fingerList[0].globalY };

    // 可以根据双击位置执行不同操作
    Logger.debug('ChatPageGestureHandler', `双击手势: x=${tapPosition.x}, y=${tapPosition.y}`);

    // 例如：双击快速滚动到底部
    this.animationController.animateScrollToBottom();
  }

  /**
   * 处理长按手势
   */
  handleLongPress(event: GestureEvent): void {
    const pressPosition = { x: event.fingerList[0].globalX, y: event.fingerList[0].globalY };

    Logger.debug('ChatPageGestureHandler', `长按手势: x=${pressPosition.x}, y=${pressPosition.y}`);

    // 可以触发上下文菜单或其他长按操作
  }

  /**
   * 处理缩放手势
   */
  handlePinchGesture(event: GestureEvent): void {
    // 可以用于字体大小调整等
    Logger.debug('ChatPageGestureHandler', '缩放手势检测');
  }

  /**
   * 处理键盘弹出/收起手势
   */
  handleKeyboardGesture(state: ChatPageState, height: number): void {
    this.animationController.updateKeyboardHeight(state, height);
    Logger.debug('ChatPageGestureHandler', `键盘高度变化: ${height}px`);
  }

  /**
   * 重置手势状态
   */
  private resetGestureState(state: ChatPageState): void {
    this.stateManager.updateSideDrawerSwipeActive(state, false);
    this.stateManager.updateSwipeDirection(state, 'none');
    this.panVelocity = 0;
    this.isEdgeSwipe = false;

    setTimeout(() => {
      this.stateManager.updateSwipeDebouncing(state, false);
    }, this.SWIPE_DEBOUNCE_TIME);
  }

  /**
   * 启用手势防抖
   */
  enableSwipeDebounce(state: ChatPageState): void {
    this.stateManager.updateSwipeDebouncing(state, true);
    setTimeout(() => {
      this.stateManager.updateSwipeDebouncing(state, false);
    }, this.SWIPE_DEBOUNCE_TIME);
  }

  /**
   * 检查是否是有效的边缘滑动
   */
  isValidEdgeSwipe(startX: number): boolean {
    return startX <= this.SIDE_DRAWER_EDGE_WIDTH;
  }

  /**
   * 获取当前手势状态
   */
  getGestureState(state: ChatPageState): {
    isActive: boolean;
    progress: number;
    direction: 'left' | 'right' | 'none';
    velocity: number;
  } {
    return {
      isActive: state.isSideDrawerSwipeActive,
      progress: state.sideDrawerSwipeProgress,
      direction: state.swipeDirection,
      velocity: this.panVelocity
    };
  }

  /**
   * 清理手势处理器
   */
  destroy(state: ChatPageState): void {
    this.resetGestureState(state);
    Logger.info('ChatPageGestureHandler', '手势处理器已销毁');
  }
}