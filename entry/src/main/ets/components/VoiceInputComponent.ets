import { SpeechRecognitionService } from '../services/SpeechRecognitionService';
import { AppContext } from '../utils/AppContext';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { vibrator } from '@kit.SensorServiceKit';
import { audio } from '@kit.AudioKit';
import { ThemeManager } from '../utils/ThemeManager';
import { Logger } from '../utils/Logger';
import { Constants, PromptTemplate } from '../utils/Constants';
import { PromptRecommendationManager } from '../utils/PromptRecommendationManager';

// 导入基础动画系统
import { 
  BasicAnimations, 
  AnimationConfigManager
} from '../animations';

/**
 * 语音识别状态
 */
export enum VoiceRecognitionState {
  IDLE = 'idle',           // 空闲状态
  RECORDING = 'recording', // 录音中
  PROCESSING = 'processing', // 处理中
  ERROR = 'error'         // 错误状态
}

/**
 * 输入模式
 */
export enum InputMode {
  TEXT = 'text',
  VOICE = 'voice'
}

export interface VoiceOverlayHint {
  text: string;
  tone: 'default' | 'warning' | 'processing';
}

/**
 * 触摸点信息接口
 */
interface TouchInfo {
  globalY?: number;
  screenY?: number;
  windowY?: number;
  y?: number;
}

/**
 * 触摸事件扩展接口
 */
interface ExtendedTouchEvent {
  touches?: Array<TouchInfo>;
  changedTouches?: Array<TouchInfo>;
}

const DEFAULT_WAVEFORM: number[] = [0.3, 0.5, 0.8, 0.4, 0.7, 0.2, 0.9, 0.6];

/**
 * 语音输入组件属性
 */
@ComponentV2
export struct VoiceInputComponent {
  @Param onVoiceResult: (text: string) => void = () => {};  // 语音识别结果回调
  @Param onStateChange: (state: VoiceRecognitionState) => void = () => {}; // 状态变化回调
  @Param onSmartPromptTriggered?: (prompt: string) => void = () => {}; // 智能prompt触发回调
  @Param onInputModeChange: (mode: InputMode) => void = () => {}; // 输入模式变化回调
  @Param onHintChange: (hint: VoiceOverlayHint | null) => void = () => {}; // 中央提示回调
  
  @Local private currentInputMode: InputMode = InputMode.TEXT;
  @Local private isRecording: boolean = false;
  @Local private showCancelHint: boolean = false;
  @Local private recognitionState: VoiceRecognitionState = VoiceRecognitionState.IDLE;
  @Local private errorText: string = '';
  @Local private animationScale: number = 1.0;
  @Local private pulseOpacity: number = 0.3;
  @Local private rotationAngle: number = 0;
  @Local private isPressed: boolean = false;
  @Local private waveAmplitudes: number[] = [...DEFAULT_WAVEFORM];
  @Local private isDarkMode: boolean = false;
  @Local private speechService: SpeechRecognitionService = new SpeechRecognitionService();
  @Local private isGestureRecording: boolean = false;
  @Local private isSwipeToCancel: boolean = false;
  @Local private dragDistance: number = 0;
  private themeManager: ThemeManager = ThemeManager.getInstance();
  
  // 简化动画状态
  @Local private breathingScale: number = 1.0;
  @Local private energyLevel: number = 0.0;
  
  // 语音提示相关
  @Local private showVoiceTips: boolean = false;
  @Local private voiceTipText: string = '';
  @Local private tipRotationIndex: number = 0;
  private longPressTimer: number = 0;
  private tipRotationTimer: number = 0;
  private tipAutoHideTimer: number = 0;
  private touchStartY: number = 0;
  private isLongPressTriggered: boolean = false;
  private readonly longPressTriggerMs: number = 220;
  private readonly swipeCancelThreshold: number = 80;
  private recommendationManager: PromptRecommendationManager = PromptRecommendationManager.getInstance();
  private waveAnimationTimer: number = 0;
  private currentOverlayHint: VoiceOverlayHint | null = null;
  
  async aboutToAppear(): Promise<void> {
    hilog.info(0x0000, 'VoiceInputComponent', '组件初始化开始');
    
    // 初始化动画系统
    AnimationConfigManager.getInstance().initialize();
    
    await this.themeManager.initialize();
    this.isDarkMode = this.themeManager.getDarkMode();
    
    // 初始化推荐管理器
    await this.recommendationManager.initialize();
    
    // 添加主题变更监听器
    this.themeManager.addThemeListener((isDark: boolean) => {
      this.isDarkMode = isDark;
    });
    
    this.initializeSpeechService();
    this.startVoiceTipRotation();
    this.onInputModeChange(this.currentInputMode);
    this.notifyHintUpdate();
    hilog.info(0x0000, 'VoiceInputComponent', '组件初始化完成');
  }

  aboutToDisappear(): void {
    hilog.info(0x0000, 'VoiceInputComponent', '组件销毁开始，当前状态: %{public}s', this.recognitionState);
    this.speechService.destroy();
    
    // 清理定时器
    if (this.longPressTimer > 0) {
      clearTimeout(this.longPressTimer);
    }
    if (this.tipRotationTimer > 0) {
      clearInterval(this.tipRotationTimer);
    }
    if (this.tipAutoHideTimer > 0) {
      clearTimeout(this.tipAutoHideTimer);
    }

    if (this.waveAnimationTimer > 0) {
      clearInterval(this.waveAnimationTimer);
      this.waveAnimationTimer = 0;
    }

    // 移除主题监听器
    this.themeManager.removeThemeListener((isDark: boolean) => {
      this.isDarkMode = isDark;
    });
    this.onHintChange(null);
    this.currentOverlayHint = null;
    hilog.info(0x0000, 'VoiceInputComponent', '组件销毁完成');
  }

  /**
   * 初始化语音服务
   */
  private async initializeSpeechService(): Promise<void> {
    hilog.info(0x0000, 'VoiceInputComponent', '开始初始化语音服务');
    
    try {
      // 获取应用上下文
      const context = AppContext.getInstance().getContext();
      hilog.info(0x0000, 'VoiceInputComponent', '应用上下文获取: %{public}s', context ? '成功' : '失败');
      
      // 设置回调
      this.speechService.setOnResult((text: string) => {
        hilog.info(0x0000, 'VoiceInputComponent', '收到语音识别结果: %{public}s', text);
        this.handleVoiceResultInternal(text);
      });

      this.speechService.setOnError((error: string) => {
        hilog.error(0x0000, 'VoiceInputComponent', '收到语音识别错误: %{public}s', error);
        // 不直接显示错误信息，而是显示友好的提示
        Logger.error('VoiceInputComponent', `语音识别错误: ${error}`);
        // 提供轻微的触觉反馈，让用户知道有问题发生
        this.triggerHapticFeedback();
        // 不设置errorText，让错误卡片不显示
        this.updateState(VoiceRecognitionState.IDLE); // 直接回到空闲状态
      });

      this.speechService.setOnStateChange((state: VoiceRecognitionState) => {
        hilog.info(0x0000, 'VoiceInputComponent', '收到状态变化: %{public}s -> %{public}s', this.recognitionState, state);
        this.updateState(state);
      });

      // 初始化服务
      const initialized = await this.speechService.init(context);
      if (initialized) {
        hilog.info(0x0000, 'VoiceInputComponent', '语音服务初始化成功');
      } else {
        hilog.error(0x0000, 'VoiceInputComponent', '语音服务初始化失败');
        Logger.error('VoiceInputComponent', '语音服务初始化失败');
        // 不显示错误卡片，静默处理
      }
    } catch (error) {
      hilog.error(0x0000, 'VoiceInputComponent', '语音服务初始化异常: %{public}s', JSON.stringify(error));
      Logger.error('VoiceInputComponent', `语音服务初始化异常: ${JSON.stringify(error)}`);
      // 不显示错误卡片，静默处理
    }
  }
  
  build() {
    Column({ space: 8 }) {
      this.buildInputArea()
      if (this.recognitionState === VoiceRecognitionState.IDLE && this.showVoiceTips && this.voiceTipText) {
        this.buildVoiceTipCard()
      }
    }
    .width('100%')
    .alignItems(this.currentInputMode === InputMode.TEXT ? HorizontalAlign.End : HorizontalAlign.Center)
  }

  @Builder
  private buildInputArea() {
    if (this.currentInputMode === InputMode.TEXT) {
      this.buildTextModeTrigger()
    } else {
      this.buildVoiceModeContainer()
    }
  }

  @Builder
  private buildTextModeTrigger() {
    Button() {
      if (this.recognitionState === VoiceRecognitionState.PROCESSING) {
        this.buildProcessingIcon()
      } else {
        this.buildMicrophoneIcon()
      }
    }
    .width(this.getButtonWidth())
    .height(this.getButtonHeight())
    .backgroundColor(this.getButtonBackgroundColor())
    .fontColor(Color.White)
    .borderRadius(this.getButtonRadius())
    .scale({
      x: this.isPressed ? 0.95 : this.breathingScale,
      y: this.isPressed ? 0.95 : this.breathingScale
    })
    .animation({
      duration: BasicAnimations.QUICK_DURATION,
      curve: Curve.EaseInOut
    })
    .onClick(() => {
      this.handleMicButtonTap();
    })
  }

  @Builder
  private buildVoiceModeContainer() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        this.buildKeyboardToggleButton()
        this.buildVoiceHoldButton()
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private buildKeyboardToggleButton() {
    Button() {
      this.buildKeyboardIcon()
    }
      .width(this.getButtonWidth())
      .height(this.getButtonHeight())
      .backgroundColor(this.getKeyboardButtonBackground())
      .borderRadius(this.getButtonRadius())
      .onClick(() => {
        this.switchToTextMode();
      })
  }

  @Builder
  private buildVoiceHoldButton() {
    Stack() {
      // 背景
      Rect()
        .width('100%')
        .height(this.getVoiceHoldButtonHeight())
        .fill(this.getVoiceHoldBackgroundColor())
        .borderRadius(16)
        .border({
          width: 1,
          color: this.getVoiceHoldBorderColor()
        })

      // 内部内容
      Column({ space: 6 }) {
        if (this.shouldShowWaveform()) {
          this.buildVoiceWaveform()
        }

        Text(this.getVoiceHoldMainText())
          .fontSize(14)
          .fontColor(this.getVoiceHoldTextColor())
          .fontWeight(FontWeight.Medium)

        if (this.shouldShowSubHint()) {
          Text(this.getVoiceHoldSubText())
            .fontSize(10)
            .fontColor(this.getVoiceHoldSubTextColor())
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .height(this.getVoiceHoldButtonHeight())
    }
    .width('100%')
    .height(this.getVoiceHoldButtonHeight())
    .onTouch((event: TouchEvent) => {
      switch (event.type) {
        case TouchType.Down:
          this.handleGesturePressDown(event);
          break;
        case TouchType.Move:
          this.handleGestureMove(event);
          break;
        case TouchType.Up:
          this.handleGestureRelease(false);
          break;
        case TouchType.Cancel:
          this.handleGestureRelease(true);
          break;
        default:
          break;
      }
    })
  }

  @Builder
  private buildKeyboardIcon() {
    Column({ space: 2 }) {
      Rect()
        .width(18)
        .height(5)
        .borderRadius(2)
        .fill(this.getIconColor())

      Row({ space: 2 }) {
        ForEach([0, 1, 2, 3], (index: number) => {
          Rect()
            .width(3)
            .height(3)
            .borderRadius(1.5)
            .fill(this.getIconColor())
            .key(`key-${index}`)
        })
      }

      Rect()
        .width(18)
        .height(4)
        .borderRadius(2)
        .fill(this.getIconColor())
    }
  }

  @Builder
  private buildVoiceWaveform() {
    Row({ space: 3 }) {
      ForEach(this.waveAmplitudes, (amplitude: number, index: number) => {
        Rect()
          .width(4)
          .height(this.getWaveformBarHeight(amplitude, this.getWaveformMaxHeight()))
          .borderRadius(2)
          .fill(this.getWaveformColor())
          .opacity(this.showCancelHint ? 0.9 : 0.6 + amplitude * 0.4)
          .animation({
            duration: 240,
            curve: Curve.EaseInOut,
            iterations: -1,
            playMode: PlayMode.Alternate,
            delay: index * 40
          })
      })
    }
    .width('80%')
    .justifyContent(FlexAlign.Center)
    .height(this.getWaveformMaxHeight())
    .clip(true)
  }

  private getKeyboardButtonBackground(): string {
    return this.isDarkMode ? 'rgba(255, 255, 255, 0.08)' : '#F7F9FC';
  }

  private getVoiceHoldButtonHeight(): number {
    return 44;
  }

  private getVoiceHoldBackgroundColor(): string {
    if (this.showCancelHint) {
      return this.isDarkMode ? 'rgba(255, 77, 79, 0.18)' : '#FFECEC';
    }
    if (this.isRecording) {
      return this.isDarkMode ? 'rgba(116, 185, 255, 0.18)' : '#EEF6FF';
    }
    return this.isDarkMode ? 'rgba(255, 255, 255, 0.08)' : '#FFFFFF';
  }

  private getVoiceHoldBorderColor(): string {
    if (this.showCancelHint) {
      return this.isDarkMode ? 'rgba(255, 77, 79, 0.4)' : 'rgba(255, 77, 79, 0.5)';
    }
    if (this.isRecording) {
      return this.isDarkMode ? 'rgba(116, 185, 255, 0.5)' : 'rgba(116, 185, 255, 0.6)';
    }
    return this.isDarkMode ? 'rgba(255, 255, 255, 0.16)' : 'rgba(0, 0, 0, 0.08)';
  }

  private shouldShowWaveform(): boolean {
    return this.isRecording && !this.showCancelHint;
  }

  private getVoiceHoldMainText(): string {
    if (this.recognitionState === VoiceRecognitionState.PROCESSING) {
      return '正在识别...';
    }
    if (this.showCancelHint) {
      return '松开手指取消发送';
    }
    if (this.isGestureRecording) {
      return '松开 发送';
    }
    return '按住 说话';
  }

  private shouldShowSubHint(): boolean {
    return this.recognitionState === VoiceRecognitionState.IDLE && !this.isGestureRecording && !this.isRecording;
  }

  private getVoiceHoldSubText(): string {
    if (this.showCancelHint) {
      return '拖动到上方取消录音';
    }
    if (this.isGestureRecording) {
      return '上滑取消';
    }
    return '松开发送，上滑取消';
  }

  private getVoiceHoldTextColor(): string {
    if (this.showCancelHint) {
      return '#FF4D4F';
    }
    if (this.recognitionState === VoiceRecognitionState.PROCESSING) {
      return this.isDarkMode ? '#CCCCCC' : '#666666';
    }
    return this.isDarkMode ? '#FFFFFF' : '#333333';
  }

  private getVoiceHoldSubTextColor(): string {
    if (this.showCancelHint) {
      return this.isDarkMode ? 'rgba(255, 77, 79, 0.8)' : '#FF6B6B';
    }
    return this.isDarkMode ? 'rgba(255, 255, 255, 0.7)' : '#888888';
  }

  private getWaveformColor(): string {
    if (this.showCancelHint) {
      return '#FF4D4F';
    }
    return this.isDarkMode ? '#74B9FF' : '#3498DB';
  }

  private getWaveformMaxHeight(): number {
    const buttonHeight = this.getVoiceHoldButtonHeight();
    const reservedSpace = 32; // 预留文本区域高度
    return Math.max(28, buttonHeight - reservedSpace);
  }

  private getWaveformBarHeight(amplitude: number, maxHeight: number): number {
    const minHeight = 6;
    const dynamicHeight = minHeight + amplitude * (maxHeight - minHeight);
    return Math.min(dynamicHeight, maxHeight);
  }

  private handleMicButtonTap(): void {
    if (this.currentInputMode === InputMode.VOICE) {
      return;
    }
    this.switchToVoiceMode();
  }

  private switchToVoiceMode(): void {
    if (this.currentInputMode === InputMode.VOICE) {
      return;
    }
    this.currentInputMode = InputMode.VOICE;
    this.onInputModeChange(InputMode.VOICE);
    void this.triggerHapticFeedback();
  }

  private switchToTextMode(): void {
    if (this.currentInputMode === InputMode.TEXT) {
      return;
    }

    if (this.isGestureRecording || this.recognitionState === VoiceRecognitionState.RECORDING) {
      void this.completeGestureRecording(true);
    }

    if (this.recognitionState === VoiceRecognitionState.PROCESSING) {
      void this.speechService.cancelRecognition();
    }

    if (this.recognitionState !== VoiceRecognitionState.IDLE) {
      this.updateState(VoiceRecognitionState.IDLE);
    }

    this.currentInputMode = InputMode.TEXT;
    this.onInputModeChange(InputMode.TEXT);
    this.showVoiceTips = false;
    this.resetGestureState();
  }

  
  @Builder
  buildMicrophoneIcon() {
    // 简洁的麦克风图标
    Column() {
      // 麦克风主体
      Rect()
        .width(8)
        .height(12)
        .radius(4)
        .fill('transparent')
        .border({ width: 1.5, color: this.getIconColor() })
      
      // 支架和底座
      Column() {
        Rect()
          .width(1)
          .height(4)
          .fill(this.getIconColor())
        
        Rect()
          .width(8)
          .height(1)
          .fill(this.getIconColor())
      }
      .margin({ top: 1 })
    }
    .opacity(this.recognitionState === VoiceRecognitionState.ERROR ? 0.6 : 1.0)
  }
  
  @Builder
  buildProcessingIcon() {
    // 处理中动画 - 三个小点
    Row() {
      Circle()
        .width(3)
        .height(3)
        .fill(this.getIconColor())
        .opacity(0.4 + this.pulseOpacity * 0.6)
        .animation({
          duration: 600,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate,
          delay: 0
        })
      
      Circle()
        .width(3)
        .height(3)
        .fill(this.getIconColor())
        .margin({ left: 2 })
        .opacity(0.4 + this.pulseOpacity * 0.6)
        .animation({
          duration: 600,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate,
          delay: 200
        })
      
      Circle()
        .width(3)
        .height(3)
        .fill(this.getIconColor())
        .margin({ left: 2 })
        .opacity(0.4 + this.pulseOpacity * 0.6)
        .animation({
          duration: 600,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate,
          delay: 400
        })
    }
  }
  
  
  @Builder
  buildErrorCard() {
    Column() {
      Row() {
        Path()
          .commands('M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z')
          .width(16)
          .height(16)
          .fill('#FF4757')
        
        Text('识别失败')
          .fontSize(12)
          .fontColor('#FF4757')
          .fontWeight(FontWeight.Medium)
          .margin({ left: 6 })
      }
      .margin({ bottom: 4 })
      
      Text(this.errorText)
        .fontSize(11)
        .fontColor(this.getErrorTextColor())
        .maxLines(2)
        .textAlign(TextAlign.Center)
        .lineHeight(16)
    }
    .padding(12)
    .margin({ top: 8 })
    .backgroundColor(this.getErrorCardBackground())
    .borderRadius(8)
    .border({ width: 1, color: this.getErrorCardBorder() })
    .shadow({
      radius: 4,
      color: this.getErrorCardShadow(),
      offsetX: 0,
      offsetY: 2
    })
  }
  
  /**
   * 主题已通过ThemeManager管理，此方法保留用于兼容性
   */
  private detectColorMode(): void {
    // 主题状态现在通过ThemeManager管理
    // 此方法保留用于向后兼容
  }
  
  /**
   * 触发触觉反馈
   */
  private async triggerHapticFeedback(): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: 50
      }, {
        id: 0,
        usage: 'alarm'
      });
    } catch (error) {
      hilog.warn(0x0000, 'VoiceInputComponent', '触觉反馈失败: %{public}s', JSON.stringify(error));
    }
  }

  private handleGesturePressDown(event: TouchEvent): void {
    if (this.currentInputMode !== InputMode.VOICE) {
      return;
    }

    this.isPressed = true;
    this.dragDistance = 0;
    this.isSwipeToCancel = false;
    this.isLongPressTriggered = false;
    this.touchStartY = this.getTouchPositionY(event);
    void this.triggerHapticFeedback();
    this.showCancelHint = false;
    this.showVoiceTips = false;
    this.notifyHintUpdate();

    if (this.recognitionState === VoiceRecognitionState.IDLE) {
      this.clearLongPressTimer();
      this.longPressTimer = setTimeout(() => {
        this.isLongPressTriggered = true;
        void this.beginGestureRecording();
      }, this.longPressTriggerMs);
    }
  }

  private handleGestureMove(event: TouchEvent): void {
    if (this.currentInputMode !== InputMode.VOICE) {
      return;
    }

    if (!this.isPressed) {
      return;
    }

    const currentY = this.getTouchPositionY(event);
    if (currentY <= 0) {
      return;
    }

    this.dragDistance = Math.max(0, this.touchStartY - currentY);

    if (!this.isGestureRecording) {
      return;
    }

    const shouldCancel = this.dragDistance >= this.swipeCancelThreshold;
    if (shouldCancel !== this.isSwipeToCancel) {
      this.isSwipeToCancel = shouldCancel;
      void this.triggerHapticFeedback();
    }

    this.showCancelHint = this.isSwipeToCancel;
    this.notifyHintUpdate();
  }

  private handleGestureRelease(forceCancel: boolean): void {
    if (this.currentInputMode !== InputMode.VOICE) {
      return;
    }

    const startedRecording = this.isGestureRecording;
    const shouldCancel = forceCancel || this.isSwipeToCancel;

    this.isPressed = false;
    this.clearLongPressTimer();
    this.showCancelHint = false;
    this.notifyHintUpdate();

    if (!startedRecording) {
      this.resetGestureState();
      return;
    }

    void this.completeGestureRecording(shouldCancel);
  }

  private async beginGestureRecording(): Promise<void> {
    if (this.currentInputMode !== InputMode.VOICE) {
      return;
    }

    if (this.isGestureRecording || this.recognitionState !== VoiceRecognitionState.IDLE) {
      return;
    }

    this.clearLongPressTimer();
    this.isGestureRecording = true;
    this.isSwipeToCancel = false;
    this.dragDistance = 0;
    this.showVoiceTips = false;
    this.isRecording = true;
    this.showCancelHint = false;
    this.notifyHintUpdate();
    if (this.waveAnimationTimer === 0) {
      this.startWaveAnimation();
    }

    await this.triggerHapticFeedback();
    await this.startRealSpeechRecognition();
  }

  private async completeGestureRecording(cancelled: boolean): Promise<void> {
    try {
      if (cancelled) {
        await this.speechService.cancelRecognition();
      } else {
        await this.speechService.stopRecognition();
      }
    } catch (error) {
      Logger.error('VoiceInputComponent', `完成语音手势时异常: ${JSON.stringify(error)}`);
    } finally {
      this.resetGestureState();
      this.isRecording = false;
      this.stopWaveAnimation();
    }
  }

  private resetGestureState(): void {
    this.isGestureRecording = false;
    this.isSwipeToCancel = false;
    this.isLongPressTriggered = false;
    this.dragDistance = 0;
    this.clearLongPressTimer();
    this.showCancelHint = false;
    this.notifyHintUpdate();
  }

  private getTouchPositionY(event: TouchEvent): number {
    const extendedEvent: ExtendedTouchEvent = event as ExtendedTouchEvent;
    const touch = extendedEvent?.touches?.[0] ?? extendedEvent?.changedTouches?.[0];
    if (!touch) {
      return this.touchStartY;
    }
    return touch.globalY ?? touch.screenY ?? touch.windowY ?? touch.y ?? this.touchStartY;
  }

  private clearLongPressTimer(): void {
    if (this.longPressTimer > 0) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = 0;
    }
  }

  private notifyHintUpdate(): void {
    const nextHint = this.computeOverlayHint();
    if (this.areHintsEqual(nextHint, this.currentOverlayHint)) {
      return;
    }
    this.currentOverlayHint = nextHint;
    this.onHintChange(nextHint);
  }

  private computeOverlayHint(): VoiceOverlayHint | null {
    if (this.recognitionState === VoiceRecognitionState.PROCESSING) {
      return { text: '正在识别中...', tone: 'processing' };
    }
    if (this.isGestureRecording) {
      if (this.showCancelHint) {
        return { text: '松开手指取消发送', tone: 'warning' };
      }
      return { text: '松开手指发送，上滑取消', tone: 'default' };
    }
    return null;
  }

  private areHintsEqual(nextHint: VoiceOverlayHint | null, currentHint: VoiceOverlayHint | null): boolean {
    if (!nextHint && !currentHint) {
      return true;
    }
    if (!nextHint || !currentHint) {
      return false;
    }
    return nextHint.text === currentHint.text && nextHint.tone === currentHint.tone;
  }

  /**
   * 真实语音识别
   */
  private async startRealSpeechRecognition(): Promise<void> {
    Logger.info('VoiceInputComponent', '开始真实语音识别');

    try {
      // 开始语音识别
      const success = await this.speechService.startRecognition();
      if (!success) {
        Logger.error('VoiceInputComponent', '启动语音识别失败');
        // 不显示错误，直接回到空闲状态
        this.updateState(VoiceRecognitionState.IDLE);
        return;
      }

      Logger.info('VoiceInputComponent', '语音识别已启动');
    } catch (error) {
      Logger.error('VoiceInputComponent', `语音识别启动异常: ${error}`);
      // 不显示错误，直接回到空闲状态
      this.updateState(VoiceRecognitionState.IDLE);
    }
  }
  
  /**
   * 更新状态
   */
  private updateState(state: VoiceRecognitionState): void {
    hilog.info(0x0000, 'VoiceInputComponent', '更新状态: %{public}s -> %{public}s', this.recognitionState, state);
    
    this.recognitionState = state;
    this.onStateChange(state);
    
    // 更新动画状态
    switch (state) {
      case VoiceRecognitionState.RECORDING:
        this.animationScale = 1.1;
        this.pulseOpacity = 0.8;
        this.startWaveAnimation();
        hilog.info(0x0000, 'VoiceInputComponent', '启动录音动画');
        this.isGestureRecording = true;
        this.isSwipeToCancel = false;
        this.isLongPressTriggered = false;
        this.dragDistance = 0;
        this.isRecording = true;
        this.showCancelHint = false;
        break;
      case VoiceRecognitionState.PROCESSING:
        this.animationScale = 1.0;
        this.pulseOpacity = 0.3;
        this.startRotationAnimation();
        hilog.info(0x0000, 'VoiceInputComponent', '启动处理动画');
        if (!this.isPressed) {
          this.isGestureRecording = false;
          this.isSwipeToCancel = false;
          this.isLongPressTriggered = false;
          this.dragDistance = 0;
        }
        this.isRecording = false;
        this.showCancelHint = false;
        this.stopWaveAnimation();
        break;
      case VoiceRecognitionState.ERROR:
        // 错误状态立即转为空闲状态，不显示错误信息
        this.animationScale = 0.9; // 稍微缩小一下，提供视觉反馈
        this.pulseOpacity = 0.3;
        this.rotationAngle = 0;
        hilog.warn(0x0000, 'VoiceInputComponent', '进入错误状态，自动转为空闲状态');
        this.resetGestureState();
        this.isRecording = false;
        this.showCancelHint = false;
        this.stopWaveAnimation();
        // 短暂延迟后转为空闲状态，让用户能感知到状态变化
        setTimeout(() => {
          this.animationScale = 1.0; // 恢复正常大小
          this.recognitionState = VoiceRecognitionState.IDLE;
          this.notifyHintUpdate();
        }, 300);
        break;
      case VoiceRecognitionState.IDLE:
      default:
        this.animationScale = 1.0;
        this.pulseOpacity = 0.3;
        this.rotationAngle = 0;
        hilog.info(0x0000, 'VoiceInputComponent', '进入空闲状态');
        this.resetGestureState();
        this.isRecording = false;
        this.showCancelHint = false;
        this.stopWaveAnimation();
        break;
    }
    this.notifyHintUpdate();
  }
  
  /**
   * 启动波形动画
   */
  private startWaveAnimation(): void {
    if (this.waveAnimationTimer !== 0) {
      return;
    }

    this.waveAmplitudes = this.waveAmplitudes.map(() => Math.random() * 0.8 + 0.2);
    this.waveAnimationTimer = setInterval(() => {
      this.waveAmplitudes = this.waveAmplitudes.map(() => Math.random() * 0.8 + 0.2);
    }, 180);
  }
  
  /**
   * 启动旋转动画
   */
  private startRotationAnimation(): void {
    this.rotationAngle = 360;
  }

  private stopWaveAnimation(): void {
    if (this.waveAnimationTimer > 0) {
      clearInterval(this.waveAnimationTimer);
      this.waveAnimationTimer = 0;
    }
    this.waveAmplitudes = [...DEFAULT_WAVEFORM];
  }
  
  /**
   * 处理语音识别结果
   */
  private async handleVoiceResultInternal(text: string): Promise<void> {
    hilog.info(0x0000, 'VoiceInputComponent', '处理语音识别结果: %{public}s', text);
    
    // 检测是否匹配语音触发词
    await this.checkVoiceTriggerMatch(text);
    
    this.onVoiceResult(text);
  }

  /**
   * 检测语音触发词匹配
   */
  private async checkVoiceTriggerMatch(recognizedText: string): Promise<void> {
    const lowerText = recognizedText.toLowerCase();
    
    // 遍历所有prompt模板，检查语音触发词匹配
    for (const template of Constants.PROMPT_TEMPLATES) {
      if (template.voiceTriggers) {
        for (const trigger of template.voiceTriggers) {
          if (lowerText.includes(trigger.toLowerCase())) {
            // 记录语音触发的使用
            await this.recommendationManager.recordPromptUsage(template.id, true);
            hilog.info(0x0000, 'VoiceInputComponent', `检测到语音触发词匹配: "${trigger}" -> ${template.title}`);
            
            // 如果识别文本主要是触发词（相似度高），则自动应用对应prompt
            if (this.shouldAutoApplyPrompt(recognizedText, trigger)) {
              hilog.info(0x0000, 'VoiceInputComponent', `自动应用智能prompt: ${template.prompt}`);
              if (this.onSmartPromptTriggered) {
                this.onSmartPromptTriggered(template.prompt);
              }
            }
            
            return; // 只处理第一个匹配的
          }
        }
      }
    }
  }

  /**
   * 判断是否应该自动应用prompt（当语音主要内容就是触发词时）
   */
  private shouldAutoApplyPrompt(recognizedText: string, trigger: string): boolean {
    const cleanText = recognizedText.toLowerCase().trim();
    const cleanTrigger = trigger.toLowerCase().trim();
    
    // 如果识别文本就是触发词或者包含触发词且文本较短，则自动应用
    return cleanText === cleanTrigger || 
           (cleanText.includes(cleanTrigger) && cleanText.length <= cleanTrigger.length + 5);
  }
  
  /**
   * 获取按钮背景颜色 - 与发送按钮风格一致
   */
  private getButtonBackgroundColor(): string {
    switch (this.recognitionState) {
      case VoiceRecognitionState.PROCESSING:
        return '#74B9FF';  // 处理状态使用蓝色
      case VoiceRecognitionState.ERROR:
        return '#FF7675';  // 错误状态使用淡红色
      default:
        return '#74B9FF';  // 默认状态使用蓝色，与主题色一致
    }
  }
  
  
  
  /**
   * 获取状态指示器颜色
   */
  /**
   * 获取图标颜色
   */
  private getIconColor(): string {
    switch (this.recognitionState) {
      case VoiceRecognitionState.RECORDING:
        return '#FFFFFF';
      case VoiceRecognitionState.PROCESSING:
        return '#FFFFFF';
      case VoiceRecognitionState.ERROR:
        return '#FFFFFF';
      default:
        return '#FFFFFF';
    }
  }
  
  /**
   * 获取按钮宽度 - 与发送按钮保持一致
   */
  private getButtonWidth(): number {
    return 40;
  }
  
  /**
   * 获取按钮高度 - 与发送按钮保持一致
   */
  private getButtonHeight(): number {
    return 40;
  }
  
  /**
   * 获取按钮圆角 - 与发送按钮保持一致
   */
  private getButtonRadius(): number {
    return 20;
  }
  
  /**
   * 响应式设计 - 获取图标尺寸
   */
  private getIconSize(): number {
    return 24;
  }

  /**
   * 暗色主题 - 获取错误卡片背景
   */
  private getErrorCardBackground(): string {
    return this.isDarkMode ? 'rgba(139, 69, 19, 0.2)' : '#FFF5F5';
  }
  
  /**
   * 暗色主题 - 获取错误卡片边框
   */
  private getErrorCardBorder(): string {
    return this.isDarkMode ? 'rgba(255, 71, 87, 0.4)' : 'rgba(255, 71, 87, 0.2)';
  }
  
  /**
   * 暗色主题 - 获取错误卡片阴影
   */
  private getErrorCardShadow(): string {
    return this.isDarkMode ? 'rgba(255, 71, 87, 0.2)' : 'rgba(255, 71, 87, 0.1)';
  }
  
  /**
   * 暗色主题 - 获取错误文本颜色
   */
  private getErrorTextColor(): string {
    return this.isDarkMode ? '#CCCCCC' : '#666666';
  }

  @Builder
  buildVoiceTipCard() {
    Column({ space: 4 }) {
      Row() {
        Text('💡')
          .fontSize(14)
        
        Text('语音提示')
          .fontSize(12)
          .fontColor('#74B9FF')
          .fontWeight(FontWeight.Medium)
          .margin({ left: 4 })
      }
      
      Text(`试试说: "${this.voiceTipText}"`)
        .fontSize(11)
        .fontColor(this.getTipTextColor())
        .textAlign(TextAlign.Center)
        .lineHeight(16)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 2 })
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .margin({ top: 8 })
    .backgroundColor(this.getTipCardBackground())
    .borderRadius(12)
    .border({ width: 1, color: this.getTipCardBorder() })
    .shadow({
      radius: 4,
      color: this.getTipCardShadow(),
      offsetX: 0,
      offsetY: 2
    })
    .opacity(0.9)
    .animation({
      duration: 300,
      curve: Curve.EaseInOut
    })
    .onClick(() => {
      // 点击提示卡片时隐藏提示
      this.showVoiceTips = false;
    })
  }

  /**
   * 启动语音提示轮换
   */
  private startVoiceTipRotation(): void {
    // 立即显示第一个提示
    this.updateVoiceTip();
    
    // 设置定期轮换
    this.tipRotationTimer = setInterval(() => {
      if (this.recognitionState === VoiceRecognitionState.IDLE && !this.showVoiceTips) {
        this.updateVoiceTip();
      }
    }, 5000); // 每5秒轮换一次
  }

  /**
   * 更新语音提示文本
   */
  private updateVoiceTip(): void {
    const allTriggers: string[] = [];
    
    // 收集所有语音触发词
    Constants.PROMPT_TEMPLATES.forEach(template => {
      if (template.voiceTriggers) {
        allTriggers.push(...template.voiceTriggers);
      }
    });
    
    if (allTriggers.length > 0) {
      // 循环选择不同的触发词
      this.voiceTipText = allTriggers[this.tipRotationIndex % allTriggers.length];
      this.tipRotationIndex++;
    }
  }

  /**
   * 获取提示卡片背景色
   */
  private getTipCardBackground(): string {
    return this.isDarkMode ? 'rgba(0, 0, 0, 0.8)' : 'rgba(255, 255, 255, 0.95)';
  }

  /**
   * 获取提示卡片边框色
   */
  private getTipCardBorder(): string {
    return this.isDarkMode ? 'rgba(116, 185, 255, 0.3)' : 'rgba(116, 185, 255, 0.2)';
  }

  /**
   * 获取提示卡片阴影
   */
  private getTipCardShadow(): string {
    return this.isDarkMode ? 'rgba(116, 185, 255, 0.2)' : 'rgba(116, 185, 255, 0.1)';
  }

  /**
   * 获取提示文本颜色
   */
  private getTipTextColor(): string {
    return this.isDarkMode ? '#CCCCCC' : '#666666';
  }
}
