/**
 * 搜索详情弹框组件
 * 支持内容选中复制功能
 */
import { Logger } from '../utils/Logger';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';

@ComponentV2
export struct SearchDetailsDialog {
  @Param isVisible: boolean = false;
  @Param content: string = '';
  @Param onClose: () => void = () => {};

  aboutToAppear() {
    Logger.info('SearchDetailsDialog', `弹框状态: ${this.isVisible}, 内容长度: ${this.content?.length || 0}`);
  }

  build() {
    if (this.isVisible) {
      // 半透明背景遮罩
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.5)')
          .onClick(() => {
            this.onClose();
          })

        // 弹框内容
        Column() {
          // 标题栏
          Row() {
            Text('🔍 网络搜索详情')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
            Blank()
            Button() {
              Text('✕')
                .fontSize(14)
                .fontColor('#666666')
            }
            .width(32)
            .height(32)
            .backgroundColor(Color.Transparent)
            .borderRadius(16)
            .onClick(() => {
              this.onClose();
            })
          }
          .width('100%')
          .margin({ bottom: 16 })

          Divider()
            .strokeWidth(1)
            .color('#E0E0E0')
            .margin({ bottom: 16 })

          // 可选中的内容区域
          Scroll() {
            Column() {
              Text(this.content)
                .fontSize(14)
                .fontColor('#333333')
                .textAlign(TextAlign.Start)
                .width('100%')
                .lineHeight(20)
                .padding(12)
                .backgroundColor('#F8F9FA')
                .borderRadius(8)
            }
            .width('100%')
          }
          .scrollBar(BarState.On)
          .scrollBarColor('#999999')
          .scrollBarWidth(8)
          .edgeEffect(EdgeEffect.Spring)
          .constraintSize({ maxHeight: 400 })

          // 按钮区域
          Row() {
            Button() {
              Text('全选复制')
                .fontSize(14)
                .fontColor(Color.White)
            }
            .width(80)
            .height(36)
            .backgroundColor('#4285F4')
            .borderRadius(18)
            .onClick(() => {
              this.copyAllContent();
            })

            Blank()

            Button() {
              Text('关闭')
                .fontSize(14)
                .fontColor('#666666')
            }
            .width(80)
            .height(36)
            .backgroundColor('#F0F0F0')
            .borderRadius(18)
            .onClick(() => {
              this.onClose();
            })
          }
          .width('100%')
          .margin({ top: 16 })
        }
        .width('90%')
        .constraintSize({ maxWidth: 500 })
        .backgroundColor(Color.White)
        .borderRadius(16)
        .padding(20)
        .shadow({
          radius: 12,
          color: 'rgba(0, 0, 0, 0.2)',
          offsetX: 0,
          offsetY: 8
        })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(1000)
    }
  }

  /**
   * 复制全部内容
   */
  private copyAllContent(): void {
    if (this.content) {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.content);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteData);
      
      promptAction.showToast({
        message: '搜索信息已复制',
        duration: 1000
      });
      Logger.info('SearchDetailsDialog', '内容已复制到剪贴板');
    }
  }
}