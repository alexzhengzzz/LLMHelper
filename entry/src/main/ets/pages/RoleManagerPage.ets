import { router, promptAction } from '@kit.ArkUI';
import { AppStorage } from '../utils/AppStorage';
import { SystemPrompt } from '../models/ChatModels';
import { common } from '@kit.AbilityKit';
import { ThemeManager } from '../utils/ThemeManager';
import { Logger } from '../utils/Logger';
import { ChatViewModel } from '../viewmodels/ChatViewModel';
import { Constants } from '../utils/Constants';
import { BusinessError } from '@kit.BasicServicesKit';
import { SessionManager } from '../utils/SessionManager';
import { RoleManager, RoleCategory, RoleSortOption } from '../utils/RoleManager';

// 扩展RoleCategory枚举添加“全部”选项
enum ExtendedRoleCategory {
  ALL = 'all',
  PROFESSIONAL = 'professional',
  CREATIVE = 'creative',
  LIFE = 'life',
  PSYCHOLOGY = 'psychology',
  CUSTOM = 'custom'
}

interface RouteParams {
  fromChatPage?: boolean;
  currentSessionId?: string;
}

/**
 * 角色管理页面 - 管理AI助手角色
 */
@Entry
@ComponentV2
struct RoleManagerPage {
  @Local roles: SystemPrompt[] = [];
  @Local filteredRoles: SystemPrompt[] = [];
  @Local showAddDialog: boolean = false;
  @Local showEditDialog: boolean = false;
  @Local editingRole: SystemPrompt | null = null;
  @Local newRoleName: string = '';
  @Local newRoleContent: string = '';
  @Local newRoleCategory: RoleCategory = RoleCategory.CUSTOM;
  @Local newRoleIcon: string = '';
  @Local newRoleDescription: string = '';
  @Local editRoleName: string = '';
  @Local editRoleContent: string = '';
  @Local editRoleCategory: RoleCategory = RoleCategory.CUSTOM;
  @Local editRoleIcon: string = '';
  @Local editRoleDescription: string = '';
  @Local isDarkMode: boolean = false;
  @Local statusBarHeight: number = 44;
  @Local usingRoleId: string = '';
  @Local isFromChatPage: boolean = false;
  @Local currentSessionId: string | null = null;
  @Local selectedCategory: ExtendedRoleCategory = ExtendedRoleCategory.ALL;
  @Local searchQuery: string = '';
  @Local isLoading: boolean = true;
  @Local showSortOptions: boolean = false;
  @Local currentSortOption: RoleSortOption = { field: 'usageCount', order: 'desc' };
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private chatViewModel: ChatViewModel = new ChatViewModel();
  private sessionManager: SessionManager = SessionManager.getInstance();
  private roleManager: RoleManager = RoleManager.getInstance();

  async aboutToAppear(): Promise<void> {
    // 接收路由参数
    const params = router.getParams() as RouteParams;
    if (params) {
      this.isFromChatPage = !!(params.fromChatPage);
      this.currentSessionId = params.currentSessionId || null;
    }
    Logger.info('RoleManagerPage', `页面来源检测: fromChatPage=${this.isFromChatPage}, currentSessionId=${this.currentSessionId}`);
    
    // 初始化主题管理器
    await this.themeManager.initialize();
    this.isDarkMode = this.themeManager.getDarkMode();
    
    // 添加主题变更监听器
    this.themeManager.addThemeListener((isDark: boolean) => {
      this.isDarkMode = isDark;
    });
    
    // 暂时使用固定状态栏高度，后续动态获取
    Logger.info('RoleManagerPage', '使用固定状态栏高度44vp');

    // 加载角色
    await this.loadRoles();
  }

  async onPageShow(): Promise<void> {
    // 页面显示时刷新数据
    await this.loadRoles();
  }

  aboutToDisappear(): void {
    // 移除主题监听器
    this.themeManager.removeThemeListener((isDark: boolean) => {
      this.isDarkMode = isDark;
    });
  }

  onBackPress(): boolean | void {
    // 如果有对话框打开，先关闭对话框
    if (this.showAddDialog) {
      this.showAddDialog = false;
      return true;
    }
    
    if (this.showEditDialog) {
      this.showEditDialog = false;
      return true;
    }
    
    // 没有对话框时返回上一页
    router.back();
    return true;
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏 - 添加状态栏高度避让
        Column() {
          this.buildNavigationBar()
        }
        .margin({ top: this.statusBarHeight })

        // 角色列表
        if (this.roles.length > 0) {
          this.buildRoleList()
        } else {
          this.buildEmptyState()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_color'))

      // 蒙版层
      if (this.showAddDialog || this.showEditDialog) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.isDarkMode ? 'rgba(0, 0, 0, 0.7)' : 'rgba(0, 0, 0, 0.5)')
          .onClick(() => {
            if (this.showAddDialog) {
              this.showAddDialog = false;
            }
            if (this.showEditDialog) {
              this.showEditDialog = false;
            }
          })
      }

      // 添加角色对话框
      if (this.showAddDialog) {
        this.buildAddRoleDialog()
      }

      // 编辑角色对话框
      if (this.showEditDialog && this.editingRole) {
        this.buildEditRoleDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildNavigationBar() {
    Row() {
      // 现代化返回按钮
      Button() {
        Row() {
          Text('←')
            .fontSize(18)
            .fontColor($r('app.color.text_primary'))
            .margin({ right: 4 })
          Text('返回')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
        }
        .alignItems(VerticalAlign.Center)
      }
      .height(40)
      .padding({ left: 8, right: 12 })
      .backgroundColor(Color.Transparent)
      .borderRadius(20)
      .onClick(() => {
        router.back();
      })

      Blank()

      Text('角色管理')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))

      Blank()

      // 现代化添加按钮 - 圆形图标按钮
      Button() {
        Text('+')
          .fontSize(20)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
      }
      .width(44)
      .height(44)
      .backgroundColor($r('app.color.primary_color'))
      .borderRadius(22)
      .shadow({
        radius: 8,
        color: $r('app.color.primary_color_20'),
        offsetY: 2
      })
      .onClick(() => {
        this.showAddDialog = true;
        this.newRoleName = '';
        this.newRoleContent = '';
      })
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.surface_color'))
    .border({
      width: { bottom: 0.5 },
      color: $r('app.color.border_color')
    })
  }

  @Builder
  buildCurrentSessionInfo() {
    Column() {
      Row() {
        Column() {
          Text(this.chatViewModel.currentSession?.name || '无会话')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
          
          if (this.chatViewModel.getCurrentSessionSystemPrompt()) {
            Text(`当前角色: ${this.chatViewModel.getCurrentSessionSystemPrompt()!.name}`)
              .fontSize(12)
              .fontColor($r('app.color.primary_color'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 2 })
          } else {
            Text('当前角色: 通用助手')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        
        Text('💬')
          .fontSize(20)
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(8)
      .border({
        width: 1,
        color: $r('app.color.border_color')
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    .backgroundColor($r('app.color.background_color'))
  }

  @Builder
  buildRoleList() {
    List({ space: 16 }) {
      ForEach(this.filteredRoles, (role: SystemPrompt) => {
        ListItem() {
          this.buildRoleItem(role)
        }
        .transition({
          type: TransitionType.All,
          scale: { x: 0.95, y: 0.95 },
          opacity: 0
        })
      }, (role: SystemPrompt) => `${role.id}_${role.timestamp}`)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 16, bottom: 20 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .divider({
      strokeWidth: 0,
      color: Color.Transparent
    })
  }

  @Builder
  buildRoleItem(role: SystemPrompt) {
    Column() {
      // 内容区域
      Column() {
        // 标题行
        Row() {
          Text(role.name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 当前会话使用指示器
          if (this.chatViewModel.getCurrentSessionSystemPrompt()?.id === role.id) {
            Row() {
              Text('✓')
                .fontSize(10)
                .fontColor(Color.White)
                .margin({ right: 2 })
              Text('当前使用')
                .fontSize(11)
                .fontColor(Color.White)
                .fontWeight(FontWeight.Medium)
            }
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.primary_color'))
            .borderRadius(12)
            .alignItems(VerticalAlign.Center)
            .margin({ left: 8 })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 12 })

        // 内容预览
        Text(role.content)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Start)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(20)
          .width('100%')
          .margin({ bottom: 12 })

        // 操作按钮：使用、编辑、删除一行布局 - 三个按钮相等大小
        Row({ space: 8 }) {
          // 使用按钮 - 占1/3宽度
          Button() {
            Row() {
              if (this.usingRoleId === role.id) {
                // Loading状态
                LoadingProgress()
                  .width(14)
                  .height(14)
                  .color(Color.White)
                  .margin({ right: 4 })
                Text(this.isFromChatPage ? '应用中...' : '创建中...')
                  .fontSize(12)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Medium)
              } else {
                Text(this.isFromChatPage ? '🎯' : '🚀')
                  .fontSize(14)
                  .margin({ right: 3 })
                Text(this.isFromChatPage ? '应用' : '使用')
                  .fontSize(12)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Medium)
              }
            }
            .alignItems(VerticalAlign.Center)
          }
          .height(40)
          .layoutWeight(1)
          .backgroundColor(this.usingRoleId === role.id ? '#999999' : $r('app.color.primary_color'))
          .borderRadius(8)
          .shadow({
            radius: 4,
            color: this.usingRoleId === role.id ? '#40999999' : $r('app.color.primary_color_20'),
            offsetY: 1
          })
          .enabled(this.usingRoleId === '')
          .onClick(() => {
            if (this.isFromChatPage) {
              this.applyToCurrentSession(role);
            } else {
              this.useRole(role);
            }
          })

          // 编辑按钮 - 占1/3宽度
          Button() {
            Row() {
              Text('✏️')
                .fontSize(14)
                .margin({ right: 3 })
              Text('编辑')
                .fontSize(12)
                .fontColor($r('app.color.text_primary'))
                .fontWeight(FontWeight.Medium)
            }
            .alignItems(VerticalAlign.Center)
          }
          .height(40)
          .layoutWeight(1)
          .backgroundColor($r('app.color.input_background'))
          .borderRadius(8)
          .border({
            width: 0.5,
            color: $r('app.color.border_color')
          })
          .stateEffect(true)
          .onClick(() => {
            this.editingRole = role;
            this.editRoleName = role.name;
            this.editRoleContent = role.content;
            this.showEditDialog = true;
          })

          // 删除按钮 - 占1/3宽度
          Button() {
            Row() {
              Text('🗑️')
                .fontSize(14)
                .margin({ right: 3 })
              Text('删除')
                .fontSize(12)
                .fontColor($r('app.color.error_color'))
                .fontWeight(FontWeight.Medium)
            }
            .alignItems(VerticalAlign.Center)
          }
          .height(40)
          .layoutWeight(1)
          .backgroundColor($r('app.color.input_background'))
          .borderRadius(8)
          .border({
            width: 0.5,
            color: $r('app.color.border_color')
          })
          .stateEffect(true)
          .onClick(() => {
            this.deleteRole(role);
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .shadow({
      radius: 8,
      color: this.isDarkMode ? '#30000000' : '#08000000',
      offsetY: 2,
      offsetX: 0
    })
    .border({
      width: 0.5,
      color: $r('app.color.border_color')
    })
  }

  @Builder
  buildEmptyState() {
    Column() {
      // 插图区域
      Column() {
        Text('📝')
          .fontSize(64)
          .margin({ bottom: 16 })
        
        Text('暂无角色')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })

        Text('角色可以定制AI助手的行为和风格\n让对话更符合您的需求')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .lineHeight(20)
          .margin({ bottom: 24 })
      }
      .alignItems(HorizontalAlign.Center)
      
      // 引导按钮
      Button() {
        Row() {
          Text('+')
            .fontSize(16)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .margin({ right: 4 })
          Text('创建第一个角色')
            .fontSize(15)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        }
        .alignItems(VerticalAlign.Center)
      }
      .height(44)
      .padding({ left: 24, right: 24 })
      .backgroundColor($r('app.color.primary_color'))
      .borderRadius(12)
      .shadow({
        radius: 8,
        color: $r('app.color.primary_color_20'),
        offsetY: 2
      })
      .onClick(() => {
        this.showAddDialog = true;
        this.newRoleName = '';
        this.newRoleContent = '';
      })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(32)
  }

  @Builder
  buildAddRoleDialog() {
    Column() {
      // 标题栏
      Row() {
        Text('✨')
          .fontSize(20)
          .margin({ right: 8 })

        Text('添加角色')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        
        Button() {
          Text('×')
            .fontSize(20)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .borderRadius(16)
        .onClick(() => {
          this.showAddDialog = false;
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 24 })

      // 表单区域
      Column({ space: 20 }) {
        // 名称输入
        Column({ space: 8 }) {
          Row() {
            Text('角色名称')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            
            Text('*')
              .fontSize(15)
              .fontColor($r('app.color.error_color'))
              .margin({ left: 2 })
          }
          .alignItems(VerticalAlign.Center)
          
          TextInput({ placeholder: '例如：编程助手、创意写作...' })
            .width('100%')
            .height(48)
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(12)
            .padding({ left: 16, right: 16 })
            .border({
              width: 1,
              color: this.newRoleName.trim().length > 0 ? $r('app.color.primary_color') : $r('app.color.border_color')
            })
            .onChange((value: string) => {
              this.newRoleName = value;
            })
        }
        .alignItems(HorizontalAlign.Start)

        // 内容输入
        Column({ space: 8 }) {
          Row() {
            Text('角色内容')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            
            Text('*')
              .fontSize(15)
              .fontColor($r('app.color.error_color'))
              .margin({ left: 2 })
          }
          .alignItems(VerticalAlign.Center)
          
          TextArea({ placeholder: '请详细描述您希望AI助手扮演的角色和行为方式...' })
            .width('100%')
            .height(140)
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(12)
            .padding(16)
            .border({
              width: 1,
              color: this.newRoleContent.trim().length > 0 ? $r('app.color.primary_color') : $r('app.color.border_color')
            })
            .onChange((value: string) => {
              this.newRoleContent = value;
            })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ bottom: 24 })

      // 按钮组
      Row({ space: 12 }) {
        Button('取消')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.border_color'))
          .borderRadius(12)
          .height(44)
          .layoutWeight(1)
          .onClick(() => {
            this.showAddDialog = false;
          })

        Button('创建角色')
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor(this.newRoleName.trim().length > 0 && this.newRoleContent.trim().length > 0 ? 
            $r('app.color.primary_color') : $r('app.color.border_color'))
          .borderRadius(12)
          .height(44)
          .layoutWeight(1)
          .enabled(this.newRoleName.trim().length > 0 && this.newRoleContent.trim().length > 0)
          .onClick(() => {
            this.addRole();
          })
      }
      .width('100%')
    }
    .width('90%')
    .padding(24)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .shadow({
      radius: 16,
      color: this.isDarkMode ? '#50000000' : '#12000000',
      offsetX: 0,
      offsetY: 6
    })
    .border({
      width: 0.5,
      color: $r('app.color.border_color')
    })
  }

  @Builder
  buildEditRoleDialog() {
    Column() {
      // 标题栏
      Row() {
        Text('✏️')
          .fontSize(20)
          .margin({ right: 8 })
        
        Text('编辑角色')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        
        Button() {
          Text('×')
            .fontSize(20)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .borderRadius(16)
        .onClick(() => {
          this.showEditDialog = false;
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 24 })

      // 表单区域
      Column({ space: 20 }) {
        // 名称输入
        Column({ space: 8 }) {
          Row() {
            Text('角色名称')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            
            Text('*')
              .fontSize(15)
              .fontColor($r('app.color.error_color'))
              .margin({ left: 2 })
          }
          .alignItems(VerticalAlign.Center)
          
          TextInput({ placeholder: '请输入角色名称', text: this.editRoleName })
            .width('100%')
            .height(48)
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(12)
            .padding({ left: 16, right: 16 })
            .border({
              width: 1,
              color: this.editRoleName.trim().length > 0 ? $r('app.color.primary_color') : $r('app.color.border_color')
            })
            .onChange((value: string) => {
              this.editRoleName = value;
            })
        }
        .alignItems(HorizontalAlign.Start)

        // 内容输入
        Column({ space: 8 }) {
          Row() {
            Text('角色内容')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            
            Text('*')
              .fontSize(15)
              .fontColor($r('app.color.error_color'))
              .margin({ left: 2 })
          }
          .alignItems(VerticalAlign.Center)
          
          TextArea({ placeholder: '请输入角色内容', text: this.editRoleContent })
            .width('100%')
            .height(140)
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(12)
            .padding(16)
            .border({
              width: 1,
              color: this.editRoleContent.trim().length > 0 ? $r('app.color.primary_color') : $r('app.color.border_color')
            })
            .onChange((value: string) => {
              this.editRoleContent = value;
            })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .margin({ bottom: 24 })

      // 按钮组
      Row({ space: 12 }) {
        Button('取消')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor($r('app.color.border_color'))
          .borderRadius(12)
          .height(44)
          .layoutWeight(1)
          .onClick(() => {
            this.showEditDialog = false;
          })

        Button('保存更改')
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor(this.editRoleName.trim().length > 0 && this.editRoleContent.trim().length > 0 ? 
            $r('app.color.primary_color') : $r('app.color.border_color'))
          .borderRadius(12)
          .height(44)
          .layoutWeight(1)
          .enabled(this.editRoleName.trim().length > 0 && this.editRoleContent.trim().length > 0)
          .onClick(() => {
            this.updateRole();
          })
      }
      .width('100%')
    }
    .width('90%')
    .padding(24)
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .shadow({
      radius: 16,
      color: this.isDarkMode ? '#50000000' : '#12000000',
      offsetX: 0,
      offsetY: 6
    })
    .border({
      width: 0.5,
      color: $r('app.color.border_color')
    })
  }

  private async useRole(role: SystemPrompt): Promise<void> {
    try {
      // 设置loading状态
      this.usingRoleId = role.id;

      Logger.info('RoleManagerPage', `开始使用角色创建新会话: ${role.name}`);

      // 显示toast提示
      promptAction.showToast({
        message: `正在使用"${role.name}"创建新会话...`,
        duration: 2000
      });

      // 使用SessionManager创建角色会话
      const newSession = await this.sessionManager.createRoleSession(role);

      Logger.info('RoleManagerPage', `新会话创建成功: ${newSession.id}，准备跳转...`);

      // 清除loading状态
      this.usingRoleId = '';

      // 显示成功提示
      promptAction.showToast({
        message: '新会话创建成功！',
        duration: 1500
      });

      // 延迟跳转以确保用户能看到成功提示
      setTimeout(() => {
        router.pushUrl({
          url: 'pages/ChatPage',
          params: { sessionId: newSession.id }
        }).then(() => {
          Logger.info('RoleManagerPage', '成功跳转到聊天页面');
        }).catch((error: Error) => {
          Logger.error('RoleManagerPage', `跳转失败: ${error.message}`);
        });
      }, 300);

    } catch (error) {
      // 清除loading状态
      this.usingRoleId = '';

      Logger.error('RoleManagerPage', `使用角色创建会话失败: ${error}`);
      promptAction.showToast({
        message: `创建失败: ${(error as Error).message}`,
        duration: 3000
      });
    }
  }

  /**
   * 应用提示词到当前会话
   */
  private async applyToCurrentSession(role: SystemPrompt): Promise<void> {
    try {
      // 设置loading状态
      this.usingRoleId = role.id;

      Logger.info('RoleManagerPage', `开始应用角色到当前会话: ${role.name}`);

      // 显示toast提示
      promptAction.showToast({
        message: `正在应用"${role.name}"到当前会话...`,
        duration: 2000
      });

      // 检查是否有当前会话ID
      if (!this.currentSessionId) {
        throw new Error('当前没有活动会话');
      }

      // 使用 SessionManager 更新会话的系统提示词
      await this.sessionManager.updateSessionPrompt(this.currentSessionId, role.id);

      Logger.info('RoleManagerPage', `角色已应用到会话: ${this.currentSessionId}`);

      // 清除loading状态
      this.usingRoleId = '';

      // 显示成功提示
      promptAction.showToast({
        message: '角色应用成功！',
        duration: 1500
      });

      // 延迟返回到聊天页面
      setTimeout(() => {
        router.back();
      }, 800);

    } catch (error) {
      // 清除loading状态
      this.usingRoleId = '';

      Logger.error('RoleManagerPage', `应用角色到当前会话失败: ${error}`);
      promptAction.showToast({
        message: `应用失败: ${(error as Error).message}`,
        duration: 3000
      });
    }
  }


  private async loadRoles(): Promise<void> {
    try {
      Logger.info('RoleManagerPage', '开始加载角色');

      // 使用RoleManager加载所有角色
      const loadedRoles = await this.roleManager.getAllRoles();
      Logger.info('RoleManagerPage', `从RoleManager加载了 ${loadedRoles.length} 个角色`);

      // 强制触发UI更新 - 使用扩展运算符创建新数组
      this.roles = [...loadedRoles];

      // 应用筛选和排序
      await this.applyFiltersAndSort();

      Logger.info('RoleManagerPage', '角色加载完成');
    } catch (error) {
      Logger.error('RoleManagerPage', `加载角色失败: ${(error as Error).message}`);
    }
  }

  private async applyFiltersAndSort(): Promise<void> {
    try {
      let filtered = this.roles;

      // 按分类筛选
      if (this.selectedCategory !== ExtendedRoleCategory.ALL) {
        filtered = filtered.filter(role => role.roleCategory === this.selectedCategory);
      }

      // 按搜索查询筛选
      if (this.searchQuery.trim()) {
        const query = this.searchQuery.toLowerCase().trim();
        filtered = filtered.filter(role =>
          role.name.toLowerCase().includes(query) ||
          role.content.toLowerCase().includes(query) ||
          (role.roleDescription && role.roleDescription.toLowerCase().includes(query))
        );
      }

      // 应用排序
      this.filteredRoles = this.roleManager.sortRoles(filtered, this.currentSortOption);

      Logger.debug('RoleManagerPage', `筛选排序后: ${this.filteredRoles.length} 个角色`);
    } catch (error) {
      Logger.error('RoleManagerPage', `筛选排序失败: ${error}`);
      this.filteredRoles = [...this.roles];
    }
  }



  
  private async addRole(): Promise<void> {
    try {
      Logger.info('RoleManagerPage', `开始添加角色: ${this.newRoleName.trim()}`);

      // 使用RoleManager创建角色
      const newRole = await this.roleManager.createRole(
        this.newRoleName.trim(),
        this.newRoleContent.trim(),
        RoleCategory.CUSTOM,
        '', // 使用默认图标
        this.newRoleName.trim() // 使用名称作为描述
      );

      Logger.info('RoleManagerPage', `角色已创建: ${newRole.id}`);

      // 关闭对话框并清空输入
      this.showAddDialog = false;
      this.newRoleName = '';
      this.newRoleContent = '';

      // 重新加载数据
      await this.loadRoles();

      Logger.debug('RoleManagerPage', '对话框状态已重置');

      promptAction.showToast({
        message: '添加成功',
        duration: 1500
      });

      Logger.info('RoleManagerPage', '角色添加完成');
    } catch (error) {
      Logger.error('RoleManagerPage', `添加角色失败: ${(error as Error).message}`);
      promptAction.showToast({
        message: '添加失败',
        duration: 1500
      });
    }
  }

  private async updateRole(): Promise<void> {
    try {
      if (this.editingRole) {
        Logger.info('RoleManagerPage', `开始更新角色: ${this.editingRole.id}`);
        Logger.info('RoleManagerPage', `新名称: ${this.editRoleName.trim()}`);
        Logger.info('RoleManagerPage', `新内容长度: ${this.editRoleContent.trim().length}`);

        // 更新角色信息
        this.editingRole.name = this.editRoleName.trim();
        this.editingRole.content = this.editRoleContent.trim();
        this.editingRole.timestamp = Date.now();

        Logger.debug('RoleManagerPage', `更新后的角色对象: ${JSON.stringify(this.editingRole)}`);

        // 使用RoleManager更新角色
        await this.roleManager.updateRole(this.editingRole);
        Logger.info('RoleManagerPage', '角色已更新到存储，准备重新加载');

        // 关闭编辑对话框
        this.showEditDialog = false;
        this.editingRole = null;

        // 重新加载数据
        await this.loadRoles();

        promptAction.showToast({
          message: '更新成功',
          duration: 1500
        });

        Logger.info('RoleManagerPage', '角色更新完成');
      }
    } catch (error) {
      Logger.error('RoleManagerPage', `更新角色失败: ${(error as Error).message}`);
      promptAction.showToast({
        message: '更新失败',
        duration: 1500
      });
    }
  }


  private async deleteRole(role: SystemPrompt): Promise<void> {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除角色"${role.name}"吗？此操作不可撤销。`,
      primaryButton: {
        value: '确定',
        action: async () => {
          try {
            Logger.info('RoleManagerPage', `开始删除角色: ${role.name}`);

            // 使用RoleManager删除角色
            await this.roleManager.deleteRole(role.id);
            Logger.info('RoleManagerPage', '角色已从存储删除，准备重新加载');

            // 重新加载数据
            await this.loadRoles();

            promptAction.showToast({
              message: '删除成功',
              duration: 1500
            });

            Logger.info('RoleManagerPage', '角色删除完成');
          } catch (error) {
            Logger.error('RoleManagerPage', `删除角色失败: ${(error as Error).message}`);
            promptAction.showToast({
              message: '删除失败',
              duration: 1500
            });
          }
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }
}