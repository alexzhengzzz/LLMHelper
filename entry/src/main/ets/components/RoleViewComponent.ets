import { SystemPrompt } from '../models/ChatModels';
import { RoleCardComponent } from './RoleCardComponent';
import { AppStorage } from '../utils/AppStorage';
import { Logger } from '../utils/Logger';
import { COMMON_CONSTANTS } from '../utils/Constants';

/**
 * 角色分类接口
 */
interface CategoryItem {
  id: string;
  name: string;
  icon: string;
}

/**
 * 角色视图组件属性
 */
interface RoleViewProps {
  onRoleSelect?: (role: SystemPrompt) => void;
}

/**
 * 角色视图组件 - 显示角色列表和分类
 */
@ComponentV2
export struct RoleViewComponent {
  @Param onRoleSelect: (role: SystemPrompt) => void = () => {};
  @Local roles: SystemPrompt[] = [];
  @Local selectedCategory: string = 'all';
  @Local isLoading: boolean = true;
  @Local isDarkMode: boolean = false;

  // 分类选项
  private readonly categories: CategoryItem[] = [
    { id: 'all', name: '全部角色', icon: '🎭' },
    { id: 'professional', name: '专业角色', icon: '💼' },
    { id: 'creative', name: '创意角色', icon: '🎨' },
    { id: 'life', name: '生活角色', icon: '🏠' },
    { id: 'psychology', name: '心理角色', icon: '🧠' },
    { id: 'custom', name: '自定义角色', icon: '⚙️' }
  ];

  aboutToAppear(): void {
    this.loadRoles();
  }

  aboutToDisappear(): void {
    // 清理资源
  }

  /**
   * 加载角色数据
   */
  private async loadRoles(): Promise<void> {
    try {
      this.isLoading = true;
      Logger.info('RoleViewComponent', '开始加载角色数据');

      Logger.info('RoleViewComponent', '角色数据加载完成');
    } catch (error) {
      Logger.error('RoleViewComponent', `加载角色数据失败: ${error}`);
      this.roles = [];
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 获取当前分类的角色
   */
  private getFilteredRoles(): SystemPrompt[] {
    if (this.selectedCategory === 'all') {
      return this.roles;
    }
    return this.roles.filter(role => role.roleCategory === this.selectedCategory);
  }

  /**
   * 获取分类显示名称
   */
  private getCategoryDisplayName(category: string): string {
    const categoryInfo = this.categories.find(c => c.id === category);
    return categoryInfo ? categoryInfo.name : category;
  }

  /**
   * 选择分类
   */
  private onSelectCategory(categoryId: string): void {
    this.selectedCategory = categoryId;
    Logger.info('RoleViewComponent', `切换到分类: ${categoryId}`);
  }

  /**
   * 处理角色选择
   */
  private onRoleSelected(role: SystemPrompt): void {
    Logger.info('RoleViewComponent', `选择角色: ${role.name}`);
    if (this.onRoleSelect) {
      this.onRoleSelect(role);
    }
  }

  
  build() {
    Column() {
      // 标题
      Row() {
        Text('AI 角色助手')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isDarkMode ? '#FFFFFF' : '#333333')
          .layoutWeight(1);

        // 刷新按钮
        Button('🔄')
          .fontSize(16)
          .backgroundColor(Color.Transparent)
          .fontColor(this.isDarkMode ? '#CCCCCC' : '#666666')
          .borderRadius(16)
          .width(32)
          .height(32)
          .onClick(() => {
            this.loadRoles();
          });
      }
      .width('100%')
      .margin({ bottom: 16 });

      // 分类选择器
      Row() {
        Scroll() {
          Row() {
            ForEach(this.categories, (category: CategoryItem) => {
              Button() {
                Row() {
                  Text(category.icon)
                    .fontSize(14)
                    .margin({ right: 4 });
                  Text(category.name)
                    .fontSize(14)
                    .fontWeight(this.selectedCategory === category.id ? FontWeight.Medium : FontWeight.Normal);
                }
                .padding({ left: 12, right: 12, top: 6, bottom: 6 });
              }
              .backgroundColor(this.selectedCategory === category.id ? COMMON_CONSTANTS.THEME_COLORS.primary : Color.Transparent)
              .fontColor(this.selectedCategory === category.id ? Color.White : (this.isDarkMode ? '#CCCCCC' : '#666666'))
              .borderRadius(16)
              .onClick(() => {
                this.onSelectCategory(category.id);
              });
            });
          }
        }
        .scrollable(ScrollDirection.Horizontal)
      }
      .width('100%')
      .margin({ bottom: 16 });

      // 角色列表
      if (this.isLoading) {
        // 加载状态
        Column() {
          LoadingProgress()
            .width(24)
            .height(24);
          Text('加载角色中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 8 });
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        // 角色网格
        if (this.getFilteredRoles().length === 0) {
          // 空状态
          Column() {
            Text('🎭')
              .fontSize(48)
              .margin({ bottom: 16 });
            Text(this.selectedCategory === 'all' ? '暂无角色' : `暂无${this.getCategoryDisplayName(this.selectedCategory)}`)
              .fontSize(16)
              .fontColor('#999999')
              .margin({ bottom: 8 });
            Text('快去创建你的第一个AI角色吧！')
              .fontSize(14)
              .fontColor('#CCCCCC');
          }
          .width('100%')
          .height(200)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center);
        } else {
          // 角色列表
          List() {
            ForEach(this.getFilteredRoles(), (role: SystemPrompt) => {
              ListItem() {
                RoleCardComponent({
                  role: role,
                  onRoleSelect: (selectedRole: SystemPrompt) => {
                    this.onRoleSelected(selectedRole);
                  }
                });
              }
              .padding({ bottom: 12 });
            });
          }
          .width('100%')
          .layoutWeight(1);
        }
      }
    }
    .padding(16)
    .backgroundColor(this.isDarkMode ? '#1E1E1E' : '#F8F9FA')
    .height('100%');
  }
}