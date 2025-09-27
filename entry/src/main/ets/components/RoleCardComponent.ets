import { SystemPrompt } from '../models/ChatModels';
import { AppStorage } from '../utils/AppStorage';
import { SessionManager } from '../utils/SessionManager';
import { Logger } from '../utils/Logger';
import { router } from '@kit.ArkUI';
import { COMMON_CONSTANTS } from '../utils/Constants';

/**
 * 角色卡片组件属性
 */
interface RoleCardProps {
  role: SystemPrompt;
  onRoleSelect?: (role: SystemPrompt) => void;
  onViewHistory?: (role: SystemPrompt) => void;
  onRoleLongPress?: (role: SystemPrompt) => void; // 新增：长按回调
}

/**
 * 角色卡片组件 - 显示单个角色信息
 */
@ComponentV2
export struct RoleCardComponent {
  @Param @Require role: SystemPrompt = new SystemPrompt();
  @Param onRoleSelect: (role: SystemPrompt) => void = () => {};
  @Param onViewHistory: (role: SystemPrompt) => void = () => {};
  @Param onRoleLongPress: (role: SystemPrompt) => void = () => {}; // 新增：长按回调
  @Local isDarkMode: boolean = false;
  @Local isPressed: boolean = false;
  @Local isHovered: boolean = false;

  // 获取角色分类对应的主题色
  private getCategoryColor(category: string): string {
    const colorMap: Record<string, string> = {
      'professional': '#4F46E5', // 深蓝色 - 专业
      'creative': '#EC4899',     // 粉色 - 创意
      'life': '#10B981',        // 绿色 - 生活
      'psychology': '#8B5CF6',  // 紫色 - 心理
      'custom': '#F59E0B'       // 橙色 - 自定义
    };
    return colorMap[category] || '#6B7280';
  }

  // 获取角色分类对应的浅色背景
  private getCategoryLightBg(category: string): string {
    const colorMap: Record<string, string> = {
      'professional': '#EEF2FF', // 淡蓝色
      'creative': '#FDF2F8',     // 淡粉色
      'life': '#F0FDF4',         // 淡绿色
      'psychology': '#F3E8FF',   // 淡紫色
      'custom': '#FEF3C7'        // 淡橙色
    };
    return colorMap[category] || '#F9FAFB';
  }


  aboutToAppear(): void {
    // 这里可以从主题管理器获取主题状态，暂时简化处理
  }

  build() {
    Stack() {
      Column() {
        // 角色头部信息
        Row() {
          // 角色图标
          Text(this.role.roleIcon || '🎭')
            .fontSize(32)
            .textAlign(TextAlign.Center)
            .width(48)
            .height(48)
            .margin({ right: 16 });

          // 角色名称和分类
          Column() {
            Row() {
              Text(this.role.name)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontColor(this.isDarkMode ? '#FFFFFF' : '#1F2937')
                .layoutWeight(1);

              // 置顶标识
              if (this.role.isPinned) {
                Text('📌')
                  .fontSize(14)
                  .margin({ left: 4 });
              }

            }
            .width('100%')
            .alignItems(VerticalAlign.Center);

            // 分类标签和历史按钮行
            if (this.role.roleCategory) {
              Row() {
                Text(this.getCategoryDisplayName(this.role.roleCategory))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getCategoryColor(this.role.roleCategory))
                  .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                  .backgroundColor(this.getCategoryLightBg(this.role.roleCategory))
                  .borderRadius(14);

                Blank();

                // 历史按钮
                Button() {
                  Text('📚')
                    .fontSize(14)
                    .fontColor(this.isDarkMode ? '#FFFFFF' : '#666666');
                }
                .width(28)
                .height(28)
                .backgroundColor(this.isDarkMode ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)')
                .borderRadius(14)
                .onClick(() => {
                  this.onViewRoleHistory();
                })
                .opacity(0.8);
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .margin({ top: 6 });
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ bottom: 12 });

        // 角色描述 - 降低透明度和减少行数
        if (this.role.roleDescription) {
          Text(this.role.roleDescription)
            .fontSize(14)
            .fontWeight(FontWeight.Regular)
            .fontColor(this.isDarkMode ? '#9CA3AF' : '#9CA3AF')
            .opacity(0.8)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(20)
            .width('100%');
        }
      }
      .width('100%');
    }
    .padding(16)
    .backgroundColor(this.isPressed ?
      (this.isDarkMode ? '#2A2A2A' : '#F7F8FC') :
      (this.isDarkMode ? '#1E1E1E' : '#FFFFFF'))
    .borderRadius(20)
    .shadow({
      radius: this.isPressed ? 4 : 12,
      color: this.isDarkMode ? 'rgba(0, 0, 0, 0.3)' : 'rgba(0, 0, 0, 0.08)',
      offsetX: 0,
      offsetY: this.isPressed ? 2 : 6
    })
    .border({
      width: 1,
      color: this.isDarkMode ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.06)'
    })
    .onClick(() => {
      this.onCreateSessionWithRole();
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onHover((isHovered: boolean) => {
      this.isHovered = isHovered;
    })
    .gesture(
      // 长按手势
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => {
          this.onRoleLongPress(this.role);
        })
    );
  }

  /**
   * 获取分类显示名称
   */
  private getCategoryDisplayName(category: string): string {
    const categoryMap: Record<string, string> = {
      'professional': '专业',
      'creative': '创意',
      'life': '生活',
      'psychology': '心理',
      'custom': '自定义'
    };
    return categoryMap[category] || category;
  }

  
  /**
   * 基于角色创建会话
   */
  private async onCreateSessionWithRole(): Promise<void> {
    try {
      Logger.info('RoleCardComponent', `基于角色创建会话: ${this.role.name}`);

      // 创建新会话并绑定角色
      const sessionManager = SessionManager.getInstance();
      const session = await sessionManager.createRoleSession(this.role);

      // 跳转到聊天页面
      router.pushUrl({
        url: 'pages/ChatPage',
        params: {
          sessionId: session.id,
          rolePromptId: this.role.id
        }
      });

      Logger.info('RoleCardComponent', `基于角色 ${this.role.name} 创建会话成功: ${session.id}`);
    } catch (error) {
      Logger.error('RoleCardComponent', `基于角色创建会话失败: ${error}`);
    }
  }

  /**
   * 查看角色历史会话
   */
  private onViewRoleHistory(): void {
    try {
      Logger.info('RoleCardComponent', `查看角色历史: ${this.role.name}`);

      // 调用父组件传入的回调，触发角色筛选
      if (this.onViewHistory) {
        this.onViewHistory(this.role);
      }

      Logger.info('RoleCardComponent', `角色历史查看请求已发送: ${this.role.id}`);
    } catch (error) {
      Logger.error('RoleCardComponent', `查看角色历史失败: ${error}`);
    }
  }
}