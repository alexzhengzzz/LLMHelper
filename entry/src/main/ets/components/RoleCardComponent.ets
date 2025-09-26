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
}

/**
 * 角色卡片组件 - 显示单个角色信息
 */
@ComponentV2
export struct RoleCardComponent {
  @Param @Require role: SystemPrompt = new SystemPrompt();
  @Param onRoleSelect: (role: SystemPrompt) => void = () => {};
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
    Column() {
      // 角色头部信息
      Row() {
        // 角色图标容器
        Stack() {
          Circle({ width: 48, height: 48 })
            .fill(this.getCategoryLightBg(this.role.roleCategory))
            .stroke(this.getCategoryColor(this.role.roleCategory))
            .strokeWidth(1);

          Text(this.role.roleIcon || '🎭')
            .fontSize(24)
            .textAlign(TextAlign.Center);
        }
        .width(48)
        .height(48)
        .margin({ right: 16 });

        // 角色名称和分类
        Column() {
          Row() {
            Text(this.role.name)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
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

            // 内置角色标识
            if (this.role.isBuiltIn) {
              Text('🔒')
                .fontSize(12)
                .fontColor('#9CA3AF')
                .margin({ left: 4 });
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          // 分类标签
          if (this.role.roleCategory) {
            Row() {
              Text(this.getCategoryDisplayName(this.role.roleCategory))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getCategoryColor(this.role.roleCategory))
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(this.getCategoryLightBg(this.role.roleCategory))
                .borderRadius(12);
            }
            .width('100%')
            .margin({ top: 4 });
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ bottom: 12 });

      // 角色描述
      if (this.role.roleDescription) {
        Text(this.role.roleDescription)
          .fontSize(14)
          .fontWeight(FontWeight.Regular)
          .fontColor(this.isDarkMode ? '#D1D5DB' : '#6B7280')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(20)
          .width('100%')
          .margin({ bottom: 16 });
      }

  
      // 操作按钮区域
      Row() {
        // 基于角色创建会话按钮
        Button() {
          Row() {
            Text('💬')
              .fontSize(14)
              .margin({ right: 6 });
            Text('开始对话')
              .fontSize(14)
              .fontWeight(FontWeight.Medium);
          }
        }
        .backgroundColor(COMMON_CONSTANTS.THEME_COLORS.primary)
        .fontColor(Color.White)
        .borderRadius(20)
        .padding({ left: 20, right: 20, top: 10, bottom: 10 })
        .onClick(() => {
          this.onCreateSessionWithRole();
        })
        .layoutWeight(1)
        .shadow({
          radius: 4,
          color: COMMON_CONSTANTS.THEME_COLORS.primary,
          offsetX: 0,
          offsetY: 2
        });
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);
    }
    .padding(20)
    .backgroundColor(this.isPressed ?
      (this.isDarkMode ? '#2A2A2A' : '#F0F0F0') :
      (this.isDarkMode ? '#1E1E1E' : '#FFFFFF'))
    .borderRadius(16)
    .shadow({
      radius: this.isPressed ? 2 : 8,
      color: '#000000',
      offsetX: 0,
      offsetY: this.isPressed ? 1 : 4
    })
    .border({
      width: 1,
      color: this.isDarkMode ? '#333333' : '#E5E7EB'
    })
    .onClick(() => {
      if (this.onRoleSelect) {
        this.onRoleSelect(this.role);
      }
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
    });
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
}