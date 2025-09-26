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

  aboutToAppear(): void {
    // 这里可以从主题管理器获取主题状态，暂时简化处理
  }

  build() {
    Column() {
      // 角色头部信息
      Row() {
        // 角色图标
        if (this.role.roleIcon) {
          Text(this.role.roleIcon)
            .fontSize(24)
            .margin({ right: 12 });
        } else {
          Text('🎭')
            .fontSize(24)
            .margin({ right: 12 });
        }

        // 角色名称和分类
        Column() {
          Text(this.role.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          if (this.role.roleCategory) {
            Text(this.getCategoryDisplayName(this.role.roleCategory))
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 2 });
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        // 置顶标识
        if (this.role.isPinned) {
          Text('📌')
            .fontSize(14)
            .margin({ right: 8 });
        }

        // 内置角色标识
        if (this.role.isBuiltIn) {
          Text('🔒')
            .fontSize(12)
            .fontColor('#999999');
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 8 });

      // 角色描述
      if (this.role.roleDescription) {
        Text(this.role.roleDescription)
          .fontSize(14)
          .fontColor('#666666')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(18)
          .width('100%')
          .margin({ bottom: 8 });
      }

      // 角色统计信息
      Row() {
        // 使用次数
        Row() {
          Text('📊')
            .fontSize(12);
          Text(`使用 ${this.role.usageCount} 次`)
            .fontSize(12)
            .fontColor('#999999');
        }
        .margin({ right: 16 });

        // 最后使用时间
        Row() {
          Text('⏰')
            .fontSize(12);
          Text(this.formatLastUsedTime(this.role.timestamp))
            .fontSize(12)
            .fontColor('#999999');
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween);

      // 操作按钮区域
      Row() {
        // 基于角色创建会话按钮
        Button('开始对话')
          .fontSize(14)
          .backgroundColor(COMMON_CONSTANTS.THEME_COLORS.primary)
          .fontColor(Color.White)
          .borderRadius(16)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.onCreateSessionWithRole();
          })
          .layoutWeight(1);
      }
      .width('100%')
      .margin({ top: 8 })
      .justifyContent(FlexAlign.Center);
    }
    .padding(16)
    .backgroundColor(this.isPressed ? '#F5F5F5' : Color.White)
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: '#000000',
      offsetX: 0,
      offsetY: 2
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
    });
  }

  /**
   * 获取分类显示名称
   */
  private getCategoryDisplayName(category: string): string {
    const categoryMap: Record<string, string> = {
      'professional': '专业角色',
      'creative': '创意角色',
      'life': '生活角色',
      'psychology': '心理角色',
      'custom': '自定义角色'
    };
    return categoryMap[category] || category;
  }

  /**
   * 格式化最后使用时间
   */
  private formatLastUsedTime(timestamp: number): string {
    const now = Date.now();
    const diff = now - timestamp;
    const minutes = Math.floor(diff / (1000 * 60));
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (minutes < 1) {
      return '刚刚';
    } else if (minutes < 60) {
      return `${minutes}分钟前`;
    } else if (hours < 24) {
      return `${hours}小时前`;
    } else if (days < 7) {
      return `${days}天前`;
    } else {
      return new Date(timestamp).toLocaleDateString();
    }
  }

  /**
   * 基于角色创建会话
   */
  private async onCreateSessionWithRole(): Promise<void> {
    try {
      Logger.info('RoleCardComponent', `基于角色创建会话: ${this.role.name}`);

      // 创建新会话并绑定角色
      const sessionManager = SessionManager.getInstance();
      const session = await sessionManager.createNewSessionWithPrompt(this.role.id);

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