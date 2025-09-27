import { MemoryItem, MemoryCategory, MemoryImportance } from '../types/MemoryTypes';
import { ThemeManager } from '../utils/ThemeManager';
import { Logger } from '../utils/Logger';

/**
 * 记忆条目组件 - 显示单个记忆碎片
 */
@ComponentV2
export struct MemoryItemComponent {
  @Param @Require memoryItem: MemoryItem;
  @Param isDarkMode: boolean = false;

  // 回调函数
  @Param onDelete: (id: string) => void = () => {};
  @Param onEdit: (item: MemoryItem) => void = () => {};

  // 内部状态
  @Local private isExpanded: boolean = false;

  // 主题相关
  @Local private textColor: string = '#333333';
  @Local private secondaryTextColor: string = '#666666';
  @Local private bgColor: string = '#FFFFFF';
  @Local private bdColor: string = '#E5E5E5';
  @Local private activeColor: string = '#007AFF';
  @Local private inactiveColor: string = '#999999';

  aboutToAppear(): void {
    this.updateThemeColors();
  }

  private updateThemeColors(): void {
    if (this.isDarkMode) {
      this.textColor = '#FFFFFF';
      this.secondaryTextColor = '#CCCCCC';
      this.bgColor = '#2C2C2C';
      this.bdColor = '#444444';
      this.activeColor = '#0A84FF';
      this.inactiveColor = '#8E8E93';
    } else {
      this.textColor = '#333333';
      this.secondaryTextColor = '#666666';
      this.bgColor = '#FFFFFF';
      this.bdColor = '#E5E5E5';
      this.activeColor = '#007AFF';
      this.inactiveColor = '#999999';
    }
  }

  /**
   * 获取分类显示名称
   */
  private getCategoryDisplayName(category: MemoryCategory): string {
    switch (category) {
      case MemoryCategory.PERSONAL:
        return '个人';
      case MemoryCategory.PREFERENCE:
        return '偏好';
      case MemoryCategory.WORK:
        return '工作';
      case MemoryCategory.STUDY:
        return '学习';
      case MemoryCategory.HOBBY:
        return '兴趣';
      case MemoryCategory.FAMILY:
        return '家庭';
      case MemoryCategory.HEALTH:
        return '健康';
      case MemoryCategory.CUSTOM:
        return '自定义';
      default:
        return '其他';
    }
  }

  /**
   * 获取重要性显示名称
   */
  private getImportanceDisplayName(importance: MemoryImportance): string {
    switch (importance) {
      case MemoryImportance.CRITICAL:
        return '关键';
      case MemoryImportance.HIGH:
        return '高';
      case MemoryImportance.MEDIUM:
        return '中';
      case MemoryImportance.LOW:
        return '低';
      default:
        return '中';
    }
  }

  /**
   * 获取重要性颜色
   */
  private getImportanceColor(importance: MemoryImportance): string {
    switch (importance) {
      case MemoryImportance.CRITICAL:
        return '#FF3B30';
      case MemoryImportance.HIGH:
        return '#FF9500';
      case MemoryImportance.MEDIUM:
        return '#007AFF';
      case MemoryImportance.LOW:
        return '#34C759';
      default:
        return '#007AFF';
    }
  }

  /**
   * 格式化时间
   */
  private formatTime(timestamp: number): string {
    if (timestamp === 0) return '从未';

    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - timestamp;

    const minutes = Math.floor(diff / (1000 * 60));
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (minutes < 1) return '刚刚';
    if (minutes < 60) return `${minutes}分钟前`;
    if (hours < 24) return `${hours}小时前`;
    if (days < 30) return `${days}天前`;

    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
  }

  build() {
    Column({ space: 8 }) {
      // 主体内容区
      Row({ space: 12 }) {
        // 记忆内容
        Column({ space: 4 }) {
          // 记忆文本
          Text(this.memoryItem.content)
            .fontSize(16)
            .fontColor(this.textColor)
            .maxLines(this.isExpanded ? 10 : 2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(22)

          // 标签行
          if (this.memoryItem.tags && this.memoryItem.tags.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.memoryItem.tags, (tag: string, index: number) => {
                Text(`#${tag}`)
                  .fontSize(12)
                  .fontColor(this.activeColor)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor(this.activeColor + '20')
                  .borderRadius(4)
              }, (tag: string, index: number) => `tag_${index}_${tag}`)
            }
          }

          // 元信息行
          Row({ space: 12 }) {
            // 分类标签
            Text(this.getCategoryDisplayName(this.memoryItem.category))
              .fontSize(10)
              .fontColor('#FFFFFF')
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .backgroundColor(this.activeColor)
              .borderRadius(2)

            // 重要性标签
            Text(this.getImportanceDisplayName(this.memoryItem.importance))
              .fontSize(10)
              .fontColor('#FFFFFF')
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .backgroundColor(this.getImportanceColor(this.memoryItem.importance))
              .borderRadius(2)

            // 使用次数
            if (this.memoryItem.usageCount > 0) {
              Text(`使用${this.memoryItem.usageCount}次`)
                .fontSize(10)
                .fontColor(this.secondaryTextColor)
            }

            Blank()

            // 最后使用时间
            Text(this.formatTime(this.memoryItem.lastUsedAt))
              .fontSize(10)
              .fontColor(this.secondaryTextColor)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 操作按钮区
        Column({ space: 8 }) {
          // 更多操作按钮
          Row({ space: 4 }) {
            // 编辑按钮
            Button('编辑')
              .fontSize(10)
              .fontColor(this.activeColor)
              .backgroundColor(Color.Transparent)
              .padding(4)
              .onClick(() => {
                this.onEdit(this.memoryItem);
              })

            // 删除按钮
            Button('删除')
              .fontSize(10)
              .fontColor('#FF3B30')
              .backgroundColor(Color.Transparent)
              .padding(4)
              .onClick(() => {
                this.onDelete(this.memoryItem.id);
              })
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      // 展开/收起详情
      if (this.memoryItem.content.length > 50 || this.isExpanded) {
        Row() {
          Button(this.isExpanded ? '收起' : '展开')
            .fontSize(12)
            .fontColor(this.activeColor)
            .backgroundColor(Color.Transparent)
            .padding(4)
            .onClick(() => {
              this.isExpanded = !this.isExpanded;
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }

      // 详细信息（展开时显示）
      if (this.isExpanded) {
        Column({ space: 4 }) {
          Row() {
            Text('创建时间: ')
              .fontSize(12)
              .fontColor(this.secondaryTextColor)
            Text(this.formatTime(this.memoryItem.createdAt))
              .fontSize(12)
              .fontColor(this.textColor)
          }
          .width('100%')

          Row() {
            Text('更新时间: ')
              .fontSize(12)
              .fontColor(this.secondaryTextColor)
            Text(this.formatTime(this.memoryItem.updatedAt))
              .fontSize(12)
              .fontColor(this.textColor)
          }
          .width('100%')

          Row() {
            Text('标题: ')
              .fontSize(12)
              .fontColor(this.secondaryTextColor)
            Text(this.memoryItem.title)
              .fontSize(12)
              .fontColor(this.textColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
        }
        .padding({ top: 8 })
        .borderRadius(4)
        .backgroundColor(this.isDarkMode ? '#1C1C1E' : '#F8F9FA')
        .padding(8)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.bgColor)
    .borderRadius(8)
    .border({
      width: 1,
      color: this.bdColor
    })
    .margin({ bottom: 8 })
    .onClick(() => {
      // 点击整个卡片时展开/收起
      if (this.memoryItem.content.length > 50) {
        this.isExpanded = !this.isExpanded;
      }
    })
  }
}