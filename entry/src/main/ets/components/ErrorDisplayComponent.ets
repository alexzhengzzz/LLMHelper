/**
 * 用户友好的错误展示组件
 * 提供统一的错误信息展示、操作建议和错误恢复功能
 */

import { ErrorManager } from '../utils/ErrorManager';
import { AppError, UserFriendlyErrorInfo, ErrorLevel, ErrorType } from '../types/ErrorTypes';
import { Logger, LogContext } from '../utils/Logger';

/**
 * 错误展示模式
 */
enum ErrorDisplayMode {
  TOAST = 'toast',           // 吐司提示
  DIALOG = 'dialog',         // 对话框
  INLINE = 'inline',         // 内联显示
  FULL_SCREEN = 'full_screen' // 全屏显示
}

/**
 * 错误操作回调接口
 */
interface ErrorActionCallbacks {
  onRetry?: () => Promise<void>;
  onDismiss?: () => void;
  onReport?: (error: AppError) => void;
  onSettings?: () => void;
}

/**
 * 错误展示属性
 */
interface ErrorDisplayProps {
  error?: AppError;
  visible?: boolean;
  mode?: ErrorDisplayMode;
  showTechnicalDetails?: boolean;
  allowDismiss?: boolean;
  callbacks?: ErrorActionCallbacks;
}

/**
 * 错误统计信息
 */
class ErrorDisplayStats {
  totalShown: number = 0;
  dismissedCount: number = 0;
  retriedCount: number = 0;
  reportedCount: number = 0;
}

/**
 * 错误展示组件
 */
@ComponentV2
export struct ErrorDisplayComponent {
  @Local errorInfo: UserFriendlyErrorInfo | null = null;
  @Local isVisible: boolean = false;
  @Local showDetails: boolean = false;
  @Local isRetrying: boolean = false;
  @Local currentError: AppError | null = null;
  
  private errorManager: ErrorManager = ErrorManager.getInstance();
  private stats: ErrorDisplayStats = new ErrorDisplayStats();
  
  // 属性绑定
  @Param error?: AppError;
  @Param visible?: boolean;
  @Param mode?: ErrorDisplayMode;
  @Param showTechnicalDetails?: boolean;
  @Param allowDismiss?: boolean;
  @Param callbacks?: ErrorActionCallbacks;

  aboutToAppear() {
    // 监听错误事件
    this.errorManager.addErrorListener({
      onError: (error: AppError) => this.handleError(error),
      onRecovery: (error: AppError, result) => this.handleRecovery(error, result)
    });
    
    // 初始化显示状态
    if (this.error && this.visible) {
      this.showError(this.error);
    }
  }

  aboutToDisappear() {
    // 清理监听器
    // 由于ArkTS限制，这里简化处理
    Logger.info('ErrorDisplayComponent', '组件销毁，清理错误监听器');
  }

  /**
   * 处理错误事件
   */
  private handleError(error: AppError): void {
    const context = new LogContext();
    context.module = 'ErrorDisplayComponent';
    context.functionName = 'handleError';
    
    Logger.info('ErrorDisplayComponent', `接收到错误事件: ${error.code}`, undefined, context);
    
    this.stats.totalShown++;
    this.showError(error);
  }

  /**
   * 处理错误恢复事件
   */
  private handleRecovery(error: AppError, result): void {
    if (result.recovered) {
      Logger.info('ErrorDisplayComponent', `错误已恢复: ${error.code}`);
      this.hideError();
    }
  }

  /**
   * 显示错误
   */
  private showError(error: AppError): void {
    this.currentError = error;
    this.errorInfo = this.errorManager.getUserFriendlyErrorInfo(error);
    this.isVisible = true;
    this.showDetails = error.level === ErrorLevel.FATAL || (this.showTechnicalDetails === true);
  }

  /**
   * 隐藏错误
   */
  private hideError(): void {
    this.isVisible = false;
    this.currentError = null;
    this.errorInfo = null;
    this.showDetails = false;
    this.isRetrying = false;
  }

  /**
   * 处理重试操作
   */
  private async handleRetry(): Promise<void> {
    if (!this.currentError || this.isRetrying) {
      return;
    }

    this.isRetrying = true;
    this.stats.retriedCount++;

    try {
      Logger.info('ErrorDisplayComponent', `用户触发重试: ${this.currentError.code}`);
      
      if (this.callbacks?.onRetry) {
        await this.callbacks.onRetry();
      } else {
        // 使用错误管理器的重试功能
        await this.errorManager.retry(this.currentError);
      }
      
      // 重试成功，隐藏错误
      this.hideError();
      
    } catch (retryError) {
      Logger.error('ErrorDisplayComponent', '重试失败', retryError as Error);
      // 更新错误信息但保持显示
      this.isRetrying = false;
    }
  }

  /**
   * 处理忽略操作
   */
  private handleDismiss(): void {
    this.stats.dismissedCount++;
    
    if (this.callbacks?.onDismiss) {
      this.callbacks.onDismiss();
    }
    
    this.hideError();
  }

  /**
   * 处理错误报告
   */
  private handleReport(): void {
    if (!this.currentError) {
      return;
    }

    this.stats.reportedCount++;
    
    if (this.callbacks?.onReport) {
      this.callbacks.onReport(this.currentError);
    } else {
      // 默认报告逻辑：记录详细错误信息
      const reportContext = new LogContext();
      reportContext.module = 'ErrorDisplayComponent';
      reportContext.functionName = 'handleReport';
      reportContext.additionalInfo = `UserReported,ErrorId:${this.currentError.id}`;
      
      Logger.error('ErrorDisplayComponent', 
        `用户报告错误: ${this.currentError.message}`, 
        this.currentError.originalError, 
        reportContext);
    }
  }

  /**
   * 处理设置操作
   */
  private handleSettings(): void {
    if (this.callbacks?.onSettings) {
      this.callbacks.onSettings();
    } else {
      Logger.info('ErrorDisplayComponent', '用户尝试打开设置');
      // 这里可以触发导航到设置页面
    }
  }

  /**
   * 切换技术详情显示
   */
  private toggleDetails(): void {
    this.showDetails = !this.showDetails;
  }

  /**
   * 获取错误图标
   */
  private getErrorIcon(): ResourceStr {
    if (!this.currentError) {
      return $r('sys.symbol.exclamationmark_triangle');
    }

    switch (this.currentError.level) {
      case ErrorLevel.INFO:
        return $r('sys.symbol.info_circle');
      case ErrorLevel.WARNING:
        return $r('sys.symbol.exclamationmark_triangle');
      case ErrorLevel.ERROR:
        return $r('sys.symbol.xmark_circle');
      case ErrorLevel.FATAL:
        return $r('sys.symbol.exclamationmark_octagon');
      default:
        return $r('sys.symbol.questionmark_circle');
    }
  }

  /**
   * 获取错误颜色
   */
  private getErrorColor(): ResourceColor {
    if (!this.currentError) {
      return $r('sys.color.warning');
    }

    switch (this.currentError.level) {
      case ErrorLevel.INFO:
        return $r('sys.color.brand');
      case ErrorLevel.WARNING:
        return $r('sys.color.warning');
      case ErrorLevel.ERROR:
        return $r('sys.color.alert');
      case ErrorLevel.FATAL:
        return Color.Red;
      default:
        return $r('sys.color.warning');
    }
  }

  /**
   * 构建操作按钮
   */
  @Builder
  private buildActionButtons() {
    Row() {
      // 重试按钮
      if (this.errorInfo?.canRetry && !this.isRetrying) {
        Button('重试')
          .type(ButtonType.Capsule)
          .backgroundColor($r('sys.color.brand'))
          .fontColor(Color.White)
          .onClick(() => this.handleRetry())
      }

      if (this.isRetrying) {
        Button() {
          Row() {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(Color.White)
            Text('重试中...')
              .fontColor(Color.White)
              .margin({ left: 8 })
          }
        }
        .type(ButtonType.Capsule)
        .backgroundColor($r('sys.color.brand'))
        .enabled(false)
      }

      // 报告按钮
      if (this.errorInfo?.canReport) {
        Button('报告问题')
          .type(ButtonType.Capsule)
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .border({ width: 1, color: $r('sys.color.brand') })
          .margin({ left: 8 })
          .onClick(() => this.handleReport())
      }

      // 设置按钮（针对配置相关错误）
      if (this.currentError?.type === ErrorType.API || this.currentError?.type === ErrorType.PERMISSION) {
        Button('设置')
          .type(ButtonType.Capsule)
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .border({ width: 1, color: $r('sys.color.brand') })
          .margin({ left: 8 })
          .onClick(() => this.handleSettings())
      }

      Blank()

      // 关闭按钮
      if (this.allowDismiss !== false) {
        Button('忽略')
          .type(ButtonType.Capsule)
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .onClick(() => this.handleDismiss())
      }
    }
    .width('100%')
    .margin({ top: 16 })
  }

  /**
   * 构建建议操作列表
   */
  @Builder
  private buildSuggestions() {
    if (this.errorInfo?.suggestions && this.errorInfo.suggestions.length > 0) {
      Column() {
        Text('建议操作：')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ bottom: 8 })

        ForEach(this.errorInfo.suggestions, (suggestion, index) => {
          Row() {
            Text(`${index + 1}. ${suggestion.description}`)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (suggestion.buttonText) {
              Button(suggestion.buttonText)
                .type(ButtonType.Capsule)
                .height(32)
                .fontSize(12)
                .backgroundColor($r('sys.color.brand'))
                .fontColor(Color.White)
                .onClick(async () => {
                  try {
                    await suggestion.actionHandler();
                  } catch (error) {
                    Logger.error('ErrorDisplayComponent', '执行建议操作失败', error as Error);
                  }
                })
            }
          }
          .width('100%')
          .margin({ bottom: 8 })
        })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 12 })
    }
  }

  /**
   * 构建技术详情
   */
  @Builder
  private buildTechnicalDetails() {
    if (this.showDetails && this.currentError) {
      Column() {
        Divider()
          .margin({ top: 16, bottom: 16 })

        Row() {
          Text('技术详情')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))

          Blank()

          Text(this.showDetails ? '收起' : '展开')
            .fontSize(12)
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.toggleDetails())
        }
        .width('100%')

        if (this.showDetails) {
          Column() {
            // 错误代码
            Row() {
              Text('错误代码：')
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .width(80)
              Text(this.currentError.code)
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 8 })

            // 错误类型
            Row() {
              Text('错误类型：')
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .width(80)
              Text(this.currentError.type)
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 4 })

            // 发生时间
            Row() {
              Text('发生时间：')
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .width(80)
              Text(new Date(this.currentError.timestamp).toLocaleString())
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 4 })

            // 错误上下文
            if (this.currentError.context?.module) {
              Row() {
                Text('相关模块：')
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .width(80)
                Text(`${this.currentError.context.module}.${this.currentError.context.function || 'unknown'}`)
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .layoutWeight(1)
              }
              .width('100%')
              .margin({ top: 4 })
            }

            // 原始错误消息
            if (this.currentError.originalError?.message) {
              Column() {
                Text('原始错误：')
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .alignSelf(ItemAlign.Start)
                  .margin({ top: 8, bottom: 4 })
                
                Text(this.currentError.originalError.message)
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
                  .padding(8)
                  .borderRadius(4)
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
            }
          }
          .alignItems(HorizontalAlign.Start)
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    if (this.isVisible && this.errorInfo) {
      Column() {
        // 错误图标和标题
        Row() {
          Image(this.getErrorIcon())
            .width(24)
            .height(24)
            .fillColor(this.getErrorColor())

          Column() {
            Text(this.errorInfo.title)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.errorInfo.message)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .margin({ top: 4 })
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 12 })
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')

        // 建议操作
        this.buildSuggestions()

        // 操作按钮
        this.buildActionButtons()

        // 技术详情
        this.buildTechnicalDetails()
      }
      .backgroundColor(Color.White)
      .borderRadius(12)
      .padding(16)
      .margin(16)
      .shadow({
        radius: 8,
        color: Color.Black,
        offsetX: 0,
        offsetY: 2
      })
      .width('calc(100% - 32vp)')
    }
  }
}

/**
 * 全局错误显示管理器
 */
export class GlobalErrorDisplay {
  private static instance: GlobalErrorDisplay;
  private currentError: AppError | null = null;
  private isShowing: boolean = false;

  private constructor() {}

  static getInstance(): GlobalErrorDisplay {
    if (!GlobalErrorDisplay.instance) {
      GlobalErrorDisplay.instance = new GlobalErrorDisplay();
    }
    return GlobalErrorDisplay.instance;
  }

  /**
   * 显示全局错误
   */
  showError(error: AppError, callbacks?: ErrorActionCallbacks): void {
    this.currentError = error;
    this.isShowing = true;
    
    Logger.info('GlobalErrorDisplay', `显示全局错误: ${error.code}`);
    
    // 这里可以触发全局错误显示逻辑
    // 由于ArkTS的限制，实际实现需要通过状态管理来处理
  }

  /**
   * 隐藏全局错误
   */
  hideError(): void {
    this.currentError = null;
    this.isShowing = false;
    
    Logger.info('GlobalErrorDisplay', '隐藏全局错误');
  }

  /**
   * 获取当前错误
   */
  getCurrentError(): AppError | null {
    return this.currentError;
  }

  /**
   * 检查是否正在显示错误
   */
  isShowingError(): boolean {
    return this.isShowing;
  }
}