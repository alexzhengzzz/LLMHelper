import { Session } from '../models/ChatModels';
import { curves } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';
import { vibrator } from '@kit.SensorServiceKit';

interface SwipeAction {
  id: string;
  title: string;
  icon: string;
  color: string;
  backgroundColor: string;
  action: () => void;
}

@ComponentV2
export struct SwipeableSessionItemComponent {
  @Param @Require session: Session;
  @Param systemPromptName: string | null = null; // 系统提示词名称
  @Param @Require isCurrentSession: boolean;
  @Param @Require isLast: boolean;
  @Param @Require onSessionClick: (sessionId: string) => void;
  @Param @Require onDelete: (sessionId: string) => void;
  @Param onSwipeStart?: () => void = undefined; // 滑动开始回调
  @Param onSwipeEnd?: () => void = undefined; // 滑动结束回调
  
  @Local swipeOffset: number = 0; // 滑动偏移量
  @Local isSwipeActive: boolean = false; // 是否处于滑动状态
  @Local isDragging: boolean = false; // 是否正在拖拽
  @Local hasTriggeredHaptic: boolean = false; // 是否已触发触觉反馈
  @Local isProcessingClick: boolean = false; // 防止重复点击状态
  @Local cachedBgColor: string = 'transparent'; // 缓存的背景颜色
  @Local cachedOpacity: number = 1.0; // 缓存的透明度
  
  private readonly DELETE_THRESHOLD = 120; // 滑动删除阈值
  private readonly ANIMATION_DURATION = 200; // 动画持续时间
  private readonly CLICK_DEBOUNCE_TIME = 500; // 点击防抖时间(ms)

  build() {
    // 会话内容层（可滑动）
      Column() {
        Row() {
          // 会话图标
          Text('💬')
            .fontSize(16)
            .margin({ right: 12 })

          // 会话信息
          Column() {
            // 会话名称
            Text(this.session.name)
              .fontSize(15)
              .fontWeight(this.isCurrentSession ? FontWeight.Medium : FontWeight.Normal)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .textAlign(TextAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            // 系统提示词显示
            if (this.systemPromptName) {
              Text(`角色: ${this.systemPromptName}`)
                .fontSize(11)
                .fontColor($r('app.color.primary_color'))
                .width('100%')
                .textAlign(TextAlign.Start)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 })
            }

            // 更新时间和消息数
            Row() {
              Text(this.session.getFormattedTime())
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
              
              if (this.session.messageCount > 0) {
                Text(`·`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 4, right: 4 })
                
                Text(`${this.session.messageCount}条消息`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
            }
            .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // 当前会话标识
          if (this.isCurrentSession) {
            Circle({ width: 6, height: 6 })
              .fill('#4285F4')
          }
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16 })
        .backgroundColor(this.cachedBgColor)
        .borderRadius(8)

        // 分割线
        if (!this.isLast) {
          Divider()
            .color($r('app.color.border_color'))
            .height(0.5)
            .margin({ left: 44, right: 16 })
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.card_background'))
      .translate({ x: this.swipeOffset })
      .opacity(this.cachedOpacity)
      .animation({
        duration: this.isDragging ? 0 : this.ANIMATION_DURATION,
        curve: curves.springMotion(0.8, 0.9)
      })
      .onClick(() => {
        this.handleSessionClick();
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 5 })
          .onActionStart((event) => {
            this.handleSwipeStart(event);
          })
          .onActionUpdate((event) => {
            this.handleSwipeUpdate(event);
          })
          .onActionEnd((event) => {
            this.handleSwipeEnd(event);
          })
      )
    .width('100%')
    .height(this.isLast ? 56 : 64) // 根据是否为最后一项调整高度
    .clip(true)
  }

  /**
   * 处理会话点击事件（带防抖和状态检查）
   */
  private handleSessionClick(): void {
    // 如果正在拖拽或处理点击，忽略此次点击
    if (this.isDragging || this.isProcessingClick) {
      Logger.debug('SwipeableSessionItem', '忽略点击事件：正在拖拽或处理中');
      return;
    }

    // 如果存在滑动偏移，先重置滑动状态
    if (Math.abs(this.swipeOffset) > 0) {
      Logger.debug('SwipeableSessionItem', '重置滑动状态后再处理点击');
      this.resetSwipe();
      return;
    }

    // 设置处理状态，防止重复点击
    this.isProcessingClick = true;
    
    Logger.info('SwipeableSessionItem', `点击会话: ${this.session.name} (${this.session.id})`);
    
    // 调用回调函数
    this.onSessionClick(this.session.id);
    
    // 延迟重置处理状态
    setTimeout(() => {
      this.isProcessingClick = false;
    }, this.CLICK_DEBOUNCE_TIME);
  }

  /**
   * 开始滑动
   */
  private handleSwipeStart(event: GestureEvent): void {
    this.isDragging = true;
    this.hasTriggeredHaptic = false;
    this.cachedBgColor = 'transparent';
    this.cachedOpacity = 1.0;
    Logger.info('SwipeableSessionItem', `开始滑动会话: ${this.session.name}`);
    
    // 通知父组件开始滑动
    this.onSwipeStart?.();
  }

  /**
   * 滑动更新
   */
  private handleSwipeUpdate(event: GestureEvent): void {
    if (!this.isDragging) return;

    const deltaX = event.offsetX;
    
    // 只允许向左滑动
    if (deltaX >= 0) {
      this.swipeOffset = 0;
      this.isSwipeActive = false;
      this.cachedBgColor = 'transparent';
      this.cachedOpacity = 1.0;
      return;
    }

    // 计算滑动距离
    let swipeDistance = Math.abs(deltaX);
    
    // 限制最大滑动距离，添加阻尼效果
    if (swipeDistance > this.DELETE_THRESHOLD * 1.5) {
      const excess = swipeDistance - this.DELETE_THRESHOLD * 1.5;
      swipeDistance = this.DELETE_THRESHOLD * 1.5 + excess * 0.2;
    }
    
    // 使用负值表示向左滑动
    this.swipeOffset = -swipeDistance;
    
    // 判断是否接近删除阈值
    const wasActive = this.isSwipeActive;
    this.isSwipeActive = swipeDistance >= this.DELETE_THRESHOLD * 0.8;
    
    // 更新缓存的背景颜色和透明度
    this.updateCachedStyles(swipeDistance);
    
    // 触发触觉反馈（接近删除阈值时）
    if (this.isSwipeActive && !wasActive && !this.hasTriggeredHaptic) {
      this.triggerHapticFeedback();
      this.hasTriggeredHaptic = true;
    }
  }

  /**
   * 滑动结束
   */
  private handleSwipeEnd(event: GestureEvent): void {
    this.isDragging = false;
    
    const currentOffset = Math.abs(this.swipeOffset);
    
    if (currentOffset >= this.DELETE_THRESHOLD) {
      // 超过删除阈值，直接删除会话
      Logger.info('SwipeableSessionItem', `滑动距离 ${currentOffset} 超过删除阈值 ${this.DELETE_THRESHOLD}，删除会话: ${this.session.name}`);
      this.triggerHapticFeedback();
      this.onDelete(this.session.id);
    } else {
      // 未超过阈值，回弹到原位
      this.resetSwipe();
      Logger.info('SwipeableSessionItem', `滑动距离 ${currentOffset} 未达到删除阈值，回弹到原位`);
    }
    
    // 通知父组件滑动结束
    this.onSwipeEnd?.();
  }

  /**
   * 更新缓存的样式
   */
  private updateCachedStyles(swipeDistance: number): void {
    // 计算滑动进度
    const swipeProgress = swipeDistance / this.DELETE_THRESHOLD;
    
    // 更新背景颜色
    if (this.isCurrentSession) {
      this.cachedBgColor = 'rgba(66, 133, 244, 0.1)';
    } else if (swipeProgress > 0.8) {
      const redIntensity = Math.min((swipeProgress - 0.8) * 5, 1) * 0.2;
      this.cachedBgColor = `rgba(255, 71, 87, ${redIntensity})`;
    } else {
      this.cachedBgColor = 'transparent';
    }
    
    // 更新透明度
    this.cachedOpacity = Math.max(1 - swipeProgress * 0.3, 0.7);
  }


  /**
   * 重置滑动状态
   */
  public resetSwipe(): void {
    animateTo(
      {
        duration: this.ANIMATION_DURATION,
        curve: curves.springMotion(0.8, 0.9)
      },
      () => {
        this.swipeOffset = 0;
        this.isSwipeActive = false;
        this.cachedBgColor = this.isCurrentSession ? 'rgba(66, 133, 244, 0.1)' : 'transparent';
        this.cachedOpacity = 1.0;
      }
    );
  }

  /**
   * 获取当前滑动状态
   */
  public getSwipeState(): boolean {
    return this.isSwipeActive;
  }

  /**
   * 触发触觉反馈
   */
  private triggerHapticFeedback(): void {
    try {
      // 检查是否支持震动
      vibrator.isSupportEffect('haptic.clock.timer').then((isSupported: boolean) => {
        if (isSupported) {
          vibrator.startVibration({
            type: 'time',
            duration: 15
          }, {
            id: 0,
            usage: 'notification'
          });
        }
      }).catch((err: Error) => {
        // 如果检查失败，直接尝试震动
        vibrator.startVibration({
          type: 'time',
          duration: 15
        }, {
          id: 0,
          usage: 'notification'
        });
      });
    } catch (error) {
      Logger.warn('SwipeableSessionItem', `触觉反馈失败: ${error}`);
    }
  }

  /**
   * 强制重置所有状态
   */
  public forceReset(): void {
    this.swipeOffset = 0;
    this.isSwipeActive = false;
    this.isDragging = false;
    this.hasTriggeredHaptic = false;
    this.isProcessingClick = false;
    this.cachedBgColor = this.isCurrentSession ? 'rgba(66, 133, 244, 0.1)' : 'transparent';
    this.cachedOpacity = 1.0;
  }

  /**
   * 获取背景颜色
   */
  private getBackgroundColor(): string {
    if (this.isCurrentSession) {
      return 'rgba(66, 133, 244, 0.1)';
    }
    
    // 滑动时渐变为红色背景，提示即将删除
    const swipeProgress = Math.abs(this.swipeOffset) / this.DELETE_THRESHOLD;
    if (swipeProgress > 0.8) {
      const redIntensity = Math.min((swipeProgress - 0.8) * 5, 1) * 0.2;
      return `rgba(255, 71, 87, ${redIntensity})`;
    }
    
    return 'transparent';
  }

  /**
   * 获取内容透明度
   */
  private getContentOpacity(): number {
    // 滑动时降低透明度，提示即将删除
    const swipeProgress = Math.abs(this.swipeOffset) / this.DELETE_THRESHOLD;
    return Math.max(1 - swipeProgress * 0.3, 0.7);
  }
}