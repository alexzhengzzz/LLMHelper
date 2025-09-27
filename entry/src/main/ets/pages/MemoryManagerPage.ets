import { router } from '@kit.ArkUI';
import { MemoryManager, MemoryItemWithoutId } from '../utils/MemoryManager';
import { MemoryItem, MemoryStats, MemoryCategory, MemoryImportance, ObservableMemoryStats, ObservableMemoryCategoryCounts, ObservableMemoryImportanceCounts } from '../types/MemoryTypes';
import { MemoryItemComponent } from '../components/MemoryItemComponent';
import { Logger } from '../utils/Logger';
import { BasicAnimations, AnimationConfigManager } from '../animations';

interface MemoryItemWithId extends MemoryItem {
  id: string;
}



/**
 * 记忆中心页面
 * 管理用户的记忆碎片，支持查看、添加、编辑、删除记忆
 */
@Entry
@ComponentV2
struct MemoryManagerPage {
  @Local private memoryItems: MemoryItemWithId[] = [];
  @Local private memoryStats: ObservableMemoryStats = new ObservableMemoryStats();
  @Local private selectedCategory: MemoryCategory | 'all' = 'all';
  @Local private selectedImportance: MemoryImportance | 'all' = 'all';
  @Local private searchQuery: string = '';
  @Local private isLoading: boolean = true;
  @Local private showAddDialog: boolean = false;
  @Local private showDeleteDialog: boolean = false;
  @Local private deleteTargetId: string = '';
  @Local private deleteTargetTitle: string = '';
  @Local private statusBarHeight: number = 44;

  // 新建记忆表单
  @Local private newMemoryTitle: string = '';
  @Local private newMemoryContent: string = '';
  @Local private newMemoryCategory: MemoryCategory = MemoryCategory.PERSONAL;
  @Local private newMemoryImportance: MemoryImportance = MemoryImportance.MEDIUM;
  @Local private newMemoryTags: string = '';

  // 编辑记忆表单
  @Local private showEditDialog: boolean = false;
  @Local private editMemoryId: string = '';
  @Local private editMemoryTitle: string = '';
  @Local private editMemoryContent: string = '';
  @Local private editMemoryCategory: MemoryCategory = MemoryCategory.PERSONAL;
  @Local private editMemoryImportance: MemoryImportance = MemoryImportance.MEDIUM;
  @Local private editMemoryTags: string = '';

  private readonly PAGE_ENTER_OFFSET: number = 96;
  @Local private pageTranslateX: number = this.PAGE_ENTER_OFFSET;
  @Local private pageOpacity: number = BasicAnimations.HIDDEN_OPACITY;
  private hasPlayedEnterAnimation: boolean = false;
  private animationConfigManager: AnimationConfigManager = AnimationConfigManager.getInstance();
  private memoryManager: MemoryManager = MemoryManager.getInstance();

  async aboutToAppear(): Promise<void> {
    Logger.info('MemoryManagerPage', '页面初始化开始');
    this.resetEnterAnimationState();

    try {
      await this.loadMemoryData();
    } catch (error) {
      Logger.error('MemoryManagerPage', `页面初始化失败: ${error}`);
    }
  }

  onPageShow(): void {
    Logger.info('MemoryManagerPage', '页面显示');
    this.playEnterTransition();

    // 页面显示时重新加载数据
    this.loadMemoryData();
  }

  private resetEnterAnimationState(): void {
    this.pageTranslateX = this.PAGE_ENTER_OFFSET;
    this.pageOpacity = BasicAnimations.HIDDEN_OPACITY;
    this.hasPlayedEnterAnimation = false;
  }

  private playEnterTransition(): void {
    if (this.hasPlayedEnterAnimation) {
      return;
    }

    this.hasPlayedEnterAnimation = true;
    const duration = this.animationConfigManager.getDuration(BasicAnimations.STANDARD_DURATION);
    const curve = this.animationConfigManager.getCurve();

    animateTo({
      duration,
      curve
    }, () => {
      this.pageTranslateX = 0;
      this.pageOpacity = BasicAnimations.STANDARD_OPACITY;
    });
  }

  private async loadMemoryData(): Promise<void> {
    try {
      this.isLoading = true;

      // 加载记忆统计信息
      const stats = await this.memoryManager.getMemoryStats();
      this.memoryStats.updateFromStats(stats);
      Logger.info('MemoryManagerPage', `记忆统计信息加载成功: 总计${this.memoryStats.totalFragments}个`);

      // 加载记忆列表
      await this.loadMemoryItems();

    } catch (error) {
      Logger.error('MemoryManagerPage', `加载记忆数据失败: ${error}`);
    } finally {
      this.isLoading = false;
    }
  }

  private async loadMemoryItems(): Promise<void> {
    try {
      const items: MemoryItem[] = await this.memoryManager.getMemoryItems();

      // 转换为带ID的数组，保持原始ID
      const memoryItemsWithId: MemoryItemWithId[] = items.map((item: MemoryItem) => {
        const memoryItem: MemoryItemWithId = {
          id: item.id, // 🔧 修复：使用原始ID而不是生成新ID
          title: item.title,
          content: item.content,
          tags: item.tags,
          category: item.category,
          importance: item.importance,
          isActive: item.isActive,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
          usageCount: item.usageCount,
          lastUsedAt: item.lastUsedAt
        };
        return memoryItem;
      });

      this.memoryItems = memoryItemsWithId;

      Logger.info('MemoryManagerPage', `记忆列表加载成功: ${this.memoryItems.length}个，ID示例: ${this.memoryItems.length > 0 ? this.memoryItems[0].id : 'none'}`);

    } catch (error) {
      Logger.error('MemoryManagerPage', `加载记忆列表失败: ${error}`);
      this.memoryItems = [];
    }
  }

  private getFilteredMemoryItems(): MemoryItemWithId[] {
    let filtered: MemoryItemWithId[] = [...this.memoryItems];

    // 按分类筛选
    if (this.selectedCategory !== 'all') {
      filtered = filtered.filter(item => item.category === this.selectedCategory);
    }

    // 按重要性筛选
    if (this.selectedImportance !== 'all') {
      filtered = filtered.filter(item => item.importance === this.selectedImportance);
    }

    // 按搜索关键词筛选
    if (this.searchQuery.trim()) {
      const query = this.searchQuery.toLowerCase();
      filtered = filtered.filter(item =>
        item.title.toLowerCase().includes(query) ||
        item.content.toLowerCase().includes(query) ||
        item.tags.some(tag => tag.toLowerCase().includes(query))
      );
    }

    return filtered;
  }

  private showAddMemoryDialog(): void {
    this.resetNewMemoryForm();
    this.showAddDialog = true;
  }

  private resetNewMemoryForm(): void {
    this.newMemoryTitle = '';
    this.newMemoryContent = '';
    this.newMemoryCategory = MemoryCategory.PERSONAL;
    this.newMemoryImportance = MemoryImportance.MEDIUM;
    this.newMemoryTags = '';
  }

  private showEditMemoryDialog(item: MemoryItem): void {
    this.editMemoryId = item.id;
    this.editMemoryTitle = item.title;
    this.editMemoryContent = item.content;
    this.editMemoryCategory = item.category;
    this.editMemoryImportance = item.importance;
    this.editMemoryTags = item.tags.join(', ');
    this.showEditDialog = true;
  }

  private resetEditMemoryForm(): void {
    this.editMemoryId = '';
    this.editMemoryTitle = '';
    this.editMemoryContent = '';
    this.editMemoryCategory = MemoryCategory.PERSONAL;
    this.editMemoryImportance = MemoryImportance.MEDIUM;
    this.editMemoryTags = '';
  }

  private async addNewMemory(): Promise<void> {
    try {
      if (!this.newMemoryContent.trim()) {
        AlertDialog.show({
          title: '提示',
          message: '请填写记忆内容',
          confirm: {
            value: '确定',
            action: () => {}
          }
        });
        return;
      }

      const tags: string[] = this.newMemoryTags.split(',').map(tag => tag.trim()).filter(tag => tag);

      const newMemory: MemoryItemWithoutId = {
        title: '', // 🔧 title将由MemoryManager自动生成
        content: this.newMemoryContent.trim(),
        category: this.newMemoryCategory,
        importance: this.newMemoryImportance,
        tags: tags,
        createdAt: Date.now(),
        updatedAt: Date.now(),
        isActive: true,
        usageCount: 0,
        lastUsedAt: 0
      };

      Logger.info('MemoryManagerPage', `准备添加记忆: ${newMemory.title}`);
      const result = await this.memoryManager.addMemoryItem(newMemory);
      Logger.info('MemoryManagerPage', `添加记忆结果: ${JSON.stringify(result)}`);

      // 重新加载数据
      Logger.info('MemoryManagerPage', `开始重新加载记忆数据`);
      await this.loadMemoryData();
      Logger.info('MemoryManagerPage', `重新加载完成，当前记忆统计: 总计${this.memoryStats.totalFragments}个，激活${this.memoryStats.activeFragments}个`);

      // 关闭对话框
      this.showAddDialog = false;

      AlertDialog.show({
        title: '添加成功',
        message: '记忆碎片已成功添加',
        confirm: {
          value: '确定',
          action: () => {}
        }
      });

    } catch (error) {
      Logger.error('MemoryManagerPage', `添加记忆失败: ${error}`);
      AlertDialog.show({
        title: '添加失败',
        message: `添加记忆时发生错误: ${(error as Error).message}`,
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
    }
  }

  private showDeleteConfirmDialog(itemId: string, title: string): void {
    this.deleteTargetId = itemId;
    this.deleteTargetTitle = title;
    this.showDeleteDialog = true;
  }

  private async deleteMemory(): Promise<void> {
    try {
      // 🔧 增强日志：记录删除ID和现有记忆列表
      Logger.info('MemoryManagerPage', `准备删除记忆，ID: ${this.deleteTargetId}，标题: ${this.deleteTargetTitle}`);
      Logger.debug('MemoryManagerPage', `当前记忆列表长度: ${this.memoryItems.length}`);
      if (this.memoryItems.length > 0) {
        Logger.debug('MemoryManagerPage', `现有记忆ID列表: ${this.memoryItems.map(item => item.id).slice(0, 3).join(', ')}...`);
      }

      const result = await this.memoryManager.deleteMemoryItem(this.deleteTargetId);
      Logger.info('MemoryManagerPage', `删除记忆操作完成，成功: ${result ? 'true' : 'false'}`);

      // 重新加载数据
      Logger.info('MemoryManagerPage', `开始重新加载记忆数据`);
      await this.loadMemoryData();
      Logger.info('MemoryManagerPage', `重新加载完成，当前记忆统计: 总计${this.memoryStats.totalFragments}个，激活${this.memoryStats.activeFragments}个`);

      // 关闭对话框
      this.showDeleteDialog = false;

      AlertDialog.show({
        title: '删除成功',
        message: '记忆碎片已成功删除',
        confirm: {
          value: '确定',
          action: () => {}
        }
      });

    } catch (error) {
      Logger.error('MemoryManagerPage', `删除记忆失败，ID: ${this.deleteTargetId}, 错误: ${error}`);
      AlertDialog.show({
        title: '删除失败',
        message: `删除记忆时发生错误: ${(error as Error).message}`,
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
    }
  }

  private async editMemory(): Promise<void> {
    try {
      if (!this.editMemoryContent.trim()) {
        AlertDialog.show({
          title: '提示',
          message: '请填写记忆内容',
          confirm: {
            value: '确定',
            action: () => {}
          }
        });
        return;
      }

      // 🔧 增强日志：记录编辑ID和现有记忆列表
      Logger.info('MemoryManagerPage', `准备编辑记忆，ID: ${this.editMemoryId}`);
      Logger.debug('MemoryManagerPage', `当前记忆列表长度: ${this.memoryItems.length}`);
      if (this.memoryItems.length > 0) {
        Logger.debug('MemoryManagerPage', `现有记忆ID列表: ${this.memoryItems.map(item => item.id).slice(0, 3).join(', ')}...`);
      }

      const tags: string[] = this.editMemoryTags.split(',').map(tag => tag.trim()).filter(tag => tag);

      const updatedMemory: MemoryItemWithoutId = {
        title: '', // 🔧 title将由MemoryManager自动生成
        content: this.editMemoryContent.trim(),
        category: this.editMemoryCategory,
        importance: this.editMemoryImportance,
        tags: tags,
        createdAt: 0, // 保持原有创建时间
        updatedAt: Date.now(),
        isActive: true,
        usageCount: 0, // 保持原有使用次数
        lastUsedAt: 0 // 保持原有最后使用时间
      };

      Logger.info('MemoryManagerPage', `准备编辑记忆: ${updatedMemory.title}，ID: ${this.editMemoryId}`);
      const result = await this.memoryManager.updateMemoryItem(this.editMemoryId, updatedMemory);
      Logger.info('MemoryManagerPage', `编辑记忆操作完成，成功: ${result ? 'true' : 'false'}`);

      // 重新加载数据
      Logger.info('MemoryManagerPage', `开始重新加载记忆数据`);
      await this.loadMemoryData();
      Logger.info('MemoryManagerPage', `重新加载完成，当前记忆统计: 总计${this.memoryStats.totalFragments}个，激活${this.memoryStats.activeFragments}个`);

      // 关闭对话框
      this.showEditDialog = false;
      this.resetEditMemoryForm();

      AlertDialog.show({
        title: '编辑成功',
        message: '记忆碎片已成功更新',
        confirm: {
          value: '确定',
          action: () => {}
        }
      });

    } catch (error) {
      Logger.error('MemoryManagerPage', `编辑记忆失败，ID: ${this.editMemoryId}, 错误: ${error}`);
      AlertDialog.show({
        title: '编辑失败',
        message: `编辑记忆时发生错误: ${(error as Error).message}`,
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
    }
  }

  private getCategoryDisplayName(category: MemoryCategory | 'all'): string {
    switch (category) {
      case 'all':
        return '全部分类';
      case MemoryCategory.PERSONAL:
        return '个人';
      case MemoryCategory.PREFERENCE:
        return '偏好';
      case MemoryCategory.WORK:
        return '工作';
      case MemoryCategory.STUDY:
        return '学习';
      case MemoryCategory.HOBBY:
        return '爱好';
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

  private getImportanceDisplayName(importance: MemoryImportance | 'all'): string {
    switch (importance) {
      case 'all':
        return '全部重要性';
      case MemoryImportance.LOW:
        return '低';
      case MemoryImportance.MEDIUM:
        return '中';
      case MemoryImportance.HIGH:
        return '高';
      case MemoryImportance.CRITICAL:
        return '关键';
      default:
        return '中';
    }
  }

  private getImportanceColor(importance: MemoryImportance | 'all'): string {
    switch (importance) {
      case 'all':
        return '#666666';
      case MemoryImportance.LOW:
        return '#4CAF50';
      case MemoryImportance.MEDIUM:
        return '#2196F3';
      case MemoryImportance.HIGH:
        return '#FF9800';
      case MemoryImportance.CRITICAL:
        return '#F44336';
      default:
        return '#2196F3';
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏
        Column() {
          this.buildNavigationBar()
        }
        .margin({ top: this.statusBarHeight })

        // 主内容区域
        if (this.isLoading) {
          this.buildLoadingView()
        } else {
          this.buildMainContent()
        }
      }
      .translate({ x: this.pageTranslateX, y: 0 })
      .opacity(this.pageOpacity)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_color'))

      // 添加记忆对话框
      if (this.showAddDialog) {
        this.buildAddMemoryDialog()
      }

      // 删除确认对话框
      if (this.showDeleteDialog) {
        this.buildDeleteConfirmDialog()
      }

      // 编辑记忆对话框
      if (this.showEditDialog) {
        this.buildEditMemoryDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildNavigationBar() {
    Row() {
      Button('返回')
        .fontSize(15)
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.primary_color'))
        .padding({ left: 0, right: 0 })
        .onClick(() => {
          router.back();
        })

      Text('记忆中心')
        .fontSize(18)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Button('添加')
        .fontSize(15)
        .backgroundColor(Color.Transparent)
        .fontColor($r('app.color.primary_color'))
        .padding({ left: 0, right: 0 })
        .onClick(() => {
          this.showAddMemoryDialog();
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 20, right: 20 })
    .backgroundColor($r('app.color.surface_color'))
    .shadow({
      radius: 2,
      color: '#0D000000',
      offsetY: 1
    })
  }

  @Builder
  buildLoadingView() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
        .color($r('app.color.primary_color'))

      Text('加载中...')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildMainContent() {
    Column() {
      // 统计信息卡片
      this.buildStatsCard()

      // 筛选区域
      this.buildFilterSection()

      // 记忆列表
      Scroll() {
        Column() {
          if (this.getFilteredMemoryItems().length === 0) {
            this.buildEmptyView()
          } else {
            ForEach(this.getFilteredMemoryItems(), (item: MemoryItemWithId) => {
              MemoryItemComponent({
                memoryItem: item,
                onEdit: (editItem: MemoryItem) => {
                  this.showEditMemoryDialog(editItem);
                },
                onDelete: (itemId: string) => {
                  const item = this.memoryItems.find(i => i.id === itemId);
                  if (item) {
                    this.showDeleteConfirmDialog(itemId, item.title);
                  }
                }
              })
            })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 32 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildStatsCard() {
    Column() {
      Row() {
        Column() {
          Text(this.memoryStats.totalFragments.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text('总计')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(this.memoryStats.activeFragments.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_color'))

          Text('激活')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(this.memoryStats.totalUsageCount.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4CAF50')

          Text('使用次数')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height(80)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .margin({ left: 16, right: 16, top: 16 })
    .padding(16)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
  }

  @Builder
  buildFilterSection() {
    Column() {
      // 搜索框
      Row() {
        TextInput({ placeholder: '搜索记忆...' })
          .width('100%')
          .height(40)
          .backgroundColor($r('app.color.input_background'))
          .borderRadius(8)
          .placeholderColor($r('app.color.text_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onChange((value: string) => {
            this.searchQuery = value;
          })
      }
      .margin({ bottom: 12 })

      // 分类和重要性筛选
      Row() {
        // 分类筛选
        Row() {
          Select([
            { value: '全部分类' },
            { value: '个人' },
            { value: '偏好' },
            { value: '工作' },
            { value: '学习' },
            { value: '爱好' },
            { value: '家庭' },
            { value: '健康' },
            { value: '自定义' }
          ])
            .selected(this.getCategoryIndex(this.selectedCategory))
            .value(this.getCategoryDisplayName(this.selectedCategory))
            .font({ size: 14 })
            .fontColor($r('app.color.text_primary'))
            .selectedOptionFontColor(Color.White)
            .selectedOptionBgColor($r('app.color.primary_color'))
            .onSelect((index: number) => {
              this.selectedCategory = this.getCategoryByIndex(index);
            })
            .width('100%')
            .height(36)
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(6)
        }
        .layoutWeight(1)
        .margin({ right: 8 })

        // 重要性筛选
        Row() {
          Select([
            { value: '全部重要性' },
            { value: '低' },
            { value: '中' },
            { value: '高' },
            { value: '关键' }
          ])
            .selected(this.getImportanceIndex(this.selectedImportance))
            .value(this.getImportanceDisplayName(this.selectedImportance))
            .font({ size: 14 })
            .fontColor($r('app.color.text_primary'))
            .selectedOptionFontColor(Color.White)
            .selectedOptionBgColor($r('app.color.primary_color'))
            .onSelect((index: number) => {
              this.selectedImportance = this.getImportanceByIndex(index);
            })
            .width('100%')
            .height(36)
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(6)
        }
        .layoutWeight(1)
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .margin({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  buildEmptyView() {
    Column() {
      Image($r('app.media.empty_state'))
        .width(120)
        .height(120)
        .objectFit(ImageFit.Contain)
        .margin({ bottom: 16 })

      Text('暂无记忆碎片')
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Text('点击右上角添加按钮创建您的第一个记忆')
        .fontSize(14)
        .fontColor($r('app.color.text_tertiary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .margin({ top: 64, bottom: 64 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildAddMemoryDialog() {
    Column() {
      // 背景遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.showAddDialog = false;
        })

      // 对话框内容
      Column() {
        Text('添加记忆碎片')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 20 })

        Scroll() {
          Column() {
            // 标题显示（只读）
            Column() {
              Row() {
                Text('标题')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                Text('(自动生成)')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 8 })
              }
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })

              TextInput({ placeholder: '标题将基于创建时间自动生成...' })
                .width('100%')
                .height(44)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
                .placeholderColor($r('app.color.text_secondary'))
                .fontColor($r('app.color.text_secondary'))
                .enabled(false) // 🔧 禁用标题编辑
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 16 })

            // 内容输入
            Column() {
              Text('内容')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              TextArea({ placeholder: '输入记忆内容...' })
                .width('100%')
                .height(100)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
                .placeholderColor($r('app.color.text_secondary'))
                .fontColor($r('app.color.text_primary'))
                .onChange((value: string) => {
                  this.newMemoryContent = value;
                })
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 16 })

            // 分类选择
            Column() {
              Text('分类')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              Select([
                { value: '个人' },
                { value: '偏好' },
                { value: '工作' },
                { value: '学习' },
                { value: '爱好' },
                { value: '家庭' },
                { value: '健康' },
                { value: '自定义' }
              ])
                .selected(this.getCategoryIndex(this.newMemoryCategory) - 1)
                .value(this.getCategoryDisplayName(this.newMemoryCategory))
                .font({ size: 14 })
                .fontColor($r('app.color.text_primary'))
                .selectedOptionFontColor(Color.White)
                .selectedOptionBgColor($r('app.color.primary_color'))
                .onSelect((index: number) => {
                  const category = this.getCategoryByIndex(index + 1);
                  if (category !== 'all') {
                    this.newMemoryCategory = category;
                  }
                })
                .width('100%')
                .height(40)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 16 })

            // 重要性选择
            Column() {
              Text('重要性')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              Select([
                { value: '低' },
                { value: '中' },
                { value: '高' },
                { value: '关键' }
              ])
                .selected(this.getImportanceIndex(this.newMemoryImportance) - 1)
                .value(this.getImportanceDisplayName(this.newMemoryImportance))
                .font({ size: 14 })
                .fontColor($r('app.color.text_primary'))
                .selectedOptionFontColor(Color.White)
                .selectedOptionBgColor($r('app.color.primary_color'))
                .onSelect((index: number) => {
                  const importance = this.getImportanceByIndex(index + 1);
                  if (importance !== 'all') {
                    this.newMemoryImportance = importance;
                  }
                })
                .width('100%')
                .height(40)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 16 })

            // 标签输入
            Column() {
              Text('标签')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              TextInput({ placeholder: '输入标签，用逗号分隔...' })
                .width('100%')
                .height(44)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
                .placeholderColor($r('app.color.text_secondary'))
                .fontColor($r('app.color.text_primary'))
                .onChange((value: string) => {
                  this.newMemoryTags = value;
                })
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }
        .height(400)

        // 按钮行
        Row() {
          Button('取消')
            .fontSize(16)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.text_secondary'))
            .borderWidth(1)
            .borderColor($r('app.color.text_secondary'))
            .borderRadius(8)
            .layoutWeight(1)
            .height(44)
            .onClick(() => {
              this.showAddDialog = false;
            })

          Button('添加')
            .fontSize(16)
            .backgroundColor($r('app.color.primary_color'))
            .fontColor(Color.White)
            .borderRadius(8)
            .layoutWeight(1)
            .height(44)
            .margin({ left: 12 })
            .onClick(() => this.addNewMemory())
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('90%')
      .height('80%')
      .padding(20)
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius(16)
      .position({ x: '50%', y: '50%' })
      .translate({ x: '-50%', y: '-50%' })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildDeleteConfirmDialog() {
    Column() {
      // 背景遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.showDeleteDialog = false;
        })

      // 对话框内容
      Column() {
        Text('确认删除')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 16 })

        Text(`确定要删除记忆碎片"${this.deleteTargetTitle}"吗？此操作不可恢复。`)
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: 24 })

        // 按钮行
        Row() {
          Button('取消')
            .fontSize(16)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.text_secondary'))
            .borderWidth(1)
            .borderColor($r('app.color.text_secondary'))
            .borderRadius(8)
            .layoutWeight(1)
            .height(44)
            .onClick(() => {
              this.showDeleteDialog = false;
            })

          Button('删除')
            .fontSize(16)
            .backgroundColor('#F44336')
            .fontColor(Color.White)
            .borderRadius(8)
            .layoutWeight(1)
            .height(44)
            .margin({ left: 12 })
            .onClick(() => this.deleteMemory())
        }
        .width('100%')
      }
      .width('85%')
      .padding(24)
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius(16)
      .position({ x: '50%', y: '50%' })
      .translate({ x: '-50%', y: '-50%' })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildEditMemoryDialog() {
    Column() {
      // 背景遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .onClick(() => {
          this.showEditDialog = false;
          this.resetEditMemoryForm();
        })

      // 对话框内容
      Column() {
        Text('编辑记忆碎片')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 20 })

        Scroll() {
          Column() {
            // 标题显示（只读）
            Column() {
              Row() {
                Text('标题')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                Text('(自动生成)')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 8 })
              }
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })

              TextInput({ text: this.editMemoryTitle, placeholder: '标题将自动生成...' })
                .width('100%')
                .height(44)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
                .placeholderColor($r('app.color.text_secondary'))
                .fontColor($r('app.color.text_secondary'))
                .enabled(false) // 🔧 禁用标题编辑
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 16 })

            // 内容输入
            Column() {
              Text('内容')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              TextArea({ text: this.editMemoryContent, placeholder: '输入记忆内容...' })
                .width('100%')
                .height(100)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
                .placeholderColor($r('app.color.text_secondary'))
                .fontColor($r('app.color.text_primary'))
                .onChange((value: string) => {
                  this.editMemoryContent = value;
                })
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 16 })

            // 分类选择
            Column() {
              Text('分类')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              Select([
                { value: '个人' },
                { value: '偏好' },
                { value: '工作' },
                { value: '学习' },
                { value: '爱好' },
                { value: '家庭' },
                { value: '健康' },
                { value: '自定义' }
              ])
                .selected(this.getCategoryIndex(this.editMemoryCategory) - 1)
                .value(this.getCategoryDisplayName(this.editMemoryCategory))
                .font({ size: 14 })
                .fontColor($r('app.color.text_primary'))
                .selectedOptionFontColor(Color.White)
                .selectedOptionBgColor($r('app.color.primary_color'))
                .onSelect((index: number) => {
                  const category = this.getCategoryByIndex(index + 1);
                  if (category !== 'all') {
                    this.editMemoryCategory = category;
                  }
                })
                .width('100%')
                .height(40)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 16 })

            // 重要性选择
            Column() {
              Text('重要性')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              Select([
                { value: '低' },
                { value: '中' },
                { value: '高' },
                { value: '关键' }
              ])
                .selected(this.getImportanceIndex(this.editMemoryImportance) - 1)
                .value(this.getImportanceDisplayName(this.editMemoryImportance))
                .font({ size: 14 })
                .fontColor($r('app.color.text_primary'))
                .selectedOptionFontColor(Color.White)
                .selectedOptionBgColor($r('app.color.primary_color'))
                .onSelect((index: number) => {
                  const importance = this.getImportanceByIndex(index + 1);
                  if (importance !== 'all') {
                    this.editMemoryImportance = importance;
                  }
                })
                .width('100%')
                .height(40)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 16 })

            // 标签输入
            Column() {
              Text('标签')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              TextInput({ text: this.editMemoryTags, placeholder: '输入标签，用逗号分隔...' })
                .width('100%')
                .height(44)
                .backgroundColor($r('app.color.input_background'))
                .borderRadius(8)
                .placeholderColor($r('app.color.text_secondary'))
                .fontColor($r('app.color.text_primary'))
                .onChange((value: string) => {
                  this.editMemoryTags = value;
                })
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }
        .height(400)

        // 按钮行
        Row() {
          Button('取消')
            .fontSize(16)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.text_secondary'))
            .borderWidth(1)
            .borderColor($r('app.color.text_secondary'))
            .borderRadius(8)
            .layoutWeight(1)
            .height(44)
            .onClick(() => {
              this.showEditDialog = false;
              this.resetEditMemoryForm();
            })

          Button('保存')
            .fontSize(16)
            .backgroundColor($r('app.color.primary_color'))
            .fontColor(Color.White)
            .borderRadius(8)
            .layoutWeight(1)
            .height(44)
            .margin({ left: 12 })
            .onClick(() => this.editMemory())
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('90%')
      .height('80%')
      .padding(20)
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius(16)
      .position({ x: '50%', y: '50%' })
      .translate({ x: '-50%', y: '-50%' })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 辅助方法
  private getCategoryIndex(category: MemoryCategory | 'all'): number {
    const categories: (MemoryCategory | 'all')[] = ['all', MemoryCategory.PERSONAL, MemoryCategory.PREFERENCE, MemoryCategory.WORK, MemoryCategory.STUDY, MemoryCategory.HOBBY, MemoryCategory.FAMILY, MemoryCategory.HEALTH, MemoryCategory.CUSTOM];
    return categories.indexOf(category);
  }

  private getCategoryByIndex(index: number): MemoryCategory | 'all' {
    const categories: (MemoryCategory | 'all')[] = ['all', MemoryCategory.PERSONAL, MemoryCategory.PREFERENCE, MemoryCategory.WORK, MemoryCategory.STUDY, MemoryCategory.HOBBY, MemoryCategory.FAMILY, MemoryCategory.HEALTH, MemoryCategory.CUSTOM];
    return categories[index] || 'all';
  }

  private getImportanceIndex(importance: MemoryImportance | 'all'): number {
    const importances: (MemoryImportance | 'all')[] = ['all', MemoryImportance.LOW, MemoryImportance.MEDIUM, MemoryImportance.HIGH, MemoryImportance.CRITICAL];
    return importances.indexOf(importance);
  }

  private getImportanceByIndex(index: number): MemoryImportance | 'all' {
    const importances: (MemoryImportance | 'all')[] = ['all', MemoryImportance.LOW, MemoryImportance.MEDIUM, MemoryImportance.HIGH, MemoryImportance.CRITICAL];
    return importances[index] || 'all';
  }
}