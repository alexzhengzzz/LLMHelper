import { SystemPrompt } from '../models/ChatModels';
import { RoleCardComponent } from './RoleCardComponent';
import { RoleManager, RoleCategory } from '../utils/RoleManager';
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
  appliedRoles?: SystemPrompt[]; // 新增：已应用角色数据
  onRoleSelect?: (role: SystemPrompt) => void;
  onRoleFilterRequest?: (role: SystemPrompt) => void;
  onRoleLongPress?: (role: SystemPrompt) => void; // 新增：长按回调
}

/**
 * 角色视图组件 - 显示角色列表和分类
 */
@ComponentV2
export struct RoleViewComponent {
  @Param appliedRoles: SystemPrompt[] = []; // 新增：已应用角色数据
  @Param onRoleSelect: (role: SystemPrompt) => void = () => {};
  @Param onRoleFilterRequest: (role: SystemPrompt) => void = () => {};
  @Param onRoleLongPress: (role: SystemPrompt) => void = () => {}; // 新增：长按回调
  @Local selectedCategory: string = 'all';
  @Local isLoading: boolean = true;
  @Local isDarkMode: boolean = false;

  // 直接使用appliedRoles，不需要中间变量
  private getDisplayRoles(): SystemPrompt[] {
    return this.appliedRoles;
  }
  private roleManager: RoleManager = RoleManager.getInstance();

  // 分类选项 - 与角色管理页面保持一致
  private readonly categories: CategoryItem[] = [
    { id: 'all', name: '全部角色', icon: '🎭' },
    { id: 'professional', name: '专业角色', icon: '💼' },
    { id: 'character', name: '人物角色', icon: '🎭' },
    { id: 'custom', name: '自定义角色', icon: '⚙️' }
  ];

  aboutToAppear(): void {
    // 初始化状态
    this.isLoading = false;
  }

  aboutToDisappear(): void {
    // 清理资源
  }

  
  /**
   * 获取当前分类的角色
   */
  private getFilteredRoles(): SystemPrompt[] {
    const displayRoles = this.getDisplayRoles();
    if (this.selectedCategory === 'all') {
      return displayRoles;
    }
    return displayRoles.filter(role => role.roleCategory === this.selectedCategory);
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

  /**
   * 处理角色筛选请求（查看历史）
   */
  private onRoleFilterRequested(role: SystemPrompt): void {
    Logger.info('RoleViewComponent', `请求查看角色历史: ${role.name}`);
    if (this.onRoleFilterRequest) {
      this.onRoleFilterRequest(role);
    }
  }

  
  build() {
    Column() {
      // 分类选择器 - 仅在显示所有角色时显示，已应用角色时不显示
      if (this.appliedRoles.length === 0) {
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
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .margin({ bottom: 16 });
      }

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
            // 侧边栏模式：显示已应用角色为空
            Text('暂无应用的角色')
              .fontSize(16)
              .fontColor('#999999')
              .margin({ bottom: 8 });
            Text('在角色管理页面将角色应用到侧边栏')
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
                  },
                  onViewHistory: (selectedRole: SystemPrompt) => {
                    this.onRoleFilterRequested(selectedRole);
                  },
                  onRoleLongPress: (selectedRole: SystemPrompt) => {
                    this.onRoleLongPress(selectedRole);
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