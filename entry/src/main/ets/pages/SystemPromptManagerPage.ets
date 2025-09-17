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

interface RouteParams {
  fromChatPage?: boolean;
  currentSessionId?: string;
}

/**
 * 系统提示词管理页面
 */
@Entry
@ComponentV2
struct SystemPromptManagerPage {
  @Local prompts: SystemPrompt[] = [];
  @Local showAddDialog: boolean = false;
  @Local showEditDialog: boolean = false;
  @Local editingPrompt: SystemPrompt | null = null;
  @Local newPromptName: string = '';
  @Local newPromptContent: string = '';
  @Local editPromptName: string = '';
  @Local editPromptContent: string = '';
  @Local isDarkMode: boolean = false;
  @Local statusBarHeight: number = 44; // 状态栏高度
  @Local usingPromptId: string = ''; // 正在使用中的提示词ID
  @Local isFromChatPage: boolean = false; // 是否从聊天页面跳转而来
  @Local currentSessionId: string | null = null; // 当前会话ID
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private chatViewModel: ChatViewModel = new ChatViewModel();
  private sessionManager: SessionManager = SessionManager.getInstance();

  async aboutToAppear(): Promise<void> {
    // 接收路由参数
    const params = router.getParams() as RouteParams;
    if (params) {
      this.isFromChatPage = !!(params.fromChatPage);
      this.currentSessionId = params.currentSessionId || null;
    }
    Logger.info('SystemPromptManagerPage', `页面来源检测: fromChatPage=${this.isFromChatPage}, currentSessionId=${this.currentSessionId}`);
    
    // 初始化主题管理器
    await this.themeManager.initialize();
    this.isDarkMode = this.themeManager.getDarkMode();
    
    // 添加主题变更监听器
    this.themeManager.addThemeListener((isDark: boolean) => {
      this.isDarkMode = isDark;
    });
    
    // 暂时使用固定状态栏高度，后续动态获取
    Logger.info('SystemPromptManagerPage', '使用固定状态栏高度44vp');
    
    // 加载提示词
    await this.loadPrompts();
  }

  async onPageShow(): Promise<void> {
    // 页面显示时刷新数据
    await this.loadPrompts();
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

        // 提示词列表
        if (this.prompts.length > 0) {
          this.buildPromptList()
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

      // 添加提示词对话框
      if (this.showAddDialog) {
        this.buildAddPromptDialog()
      }

      // 编辑提示词对话框
      if (this.showEditDialog && this.editingPrompt) {
        this.buildEditPromptDialog()
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

      Text('系统提示词管理')
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
        this.newPromptName = '';
        this.newPromptContent = '';
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
  buildPromptList() {
    List({ space: 16 }) {
      ForEach(this.prompts, (prompt: SystemPrompt) => {
        ListItem() {
          this.buildPromptItem(prompt)
        }
        .transition({
          type: TransitionType.All,
          scale: { x: 0.95, y: 0.95 },
          opacity: 0
        })
      }, (prompt: SystemPrompt) => `${prompt.id}_${prompt.timestamp}`)
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
  buildPromptItem(prompt: SystemPrompt) {
    Column() {
      // 内容区域
      Column() {
        // 标题行
        Row() {
          Text(prompt.name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 当前会话使用指示器
          if (this.chatViewModel.getCurrentSessionSystemPrompt()?.id === prompt.id) {
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
        Text(prompt.content)
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
              if (this.usingPromptId === prompt.id) {
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
          .backgroundColor(this.usingPromptId === prompt.id ? '#999999' : $r('app.color.primary_color'))
          .borderRadius(8)
          .shadow({
            radius: 4,
            color: this.usingPromptId === prompt.id ? '#40999999' : $r('app.color.primary_color_20'),
            offsetY: 1
          })
          .enabled(this.usingPromptId === '')
          .onClick(() => {
            if (this.isFromChatPage) {
              this.applyToCurrentSession(prompt);
            } else {
              this.usePrompt(prompt);
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
            this.editingPrompt = prompt;
            this.editPromptName = prompt.name;
            this.editPromptContent = prompt.content;
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
            this.deletePrompt(prompt);
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
        
        Text('暂无系统提示词')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 8 })
        
        Text('系统提示词可以定制AI助手的行为和风格\n让对话更符合您的需求')
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
          Text('创建第一个提示词')
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
        this.newPromptName = '';
        this.newPromptContent = '';
      })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(32)
  }

  @Builder
  buildAddPromptDialog() {
    Column() {
      // 标题栏
      Row() {
        Text('✨')
          .fontSize(20)
          .margin({ right: 8 })
        
        Text('添加系统提示词')
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
            Text('提示词名称')
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
              color: this.newPromptName.trim().length > 0 ? $r('app.color.primary_color') : $r('app.color.border_color')
            })
            .onChange((value: string) => {
              this.newPromptName = value;
            })
        }
        .alignItems(HorizontalAlign.Start)

        // 内容输入
        Column({ space: 8 }) {
          Row() {
            Text('提示词内容')
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
              color: this.newPromptContent.trim().length > 0 ? $r('app.color.primary_color') : $r('app.color.border_color')
            })
            .onChange((value: string) => {
              this.newPromptContent = value;
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

        Button('创建提示词')
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor(this.newPromptName.trim().length > 0 && this.newPromptContent.trim().length > 0 ? 
            $r('app.color.primary_color') : $r('app.color.border_color'))
          .borderRadius(12)
          .height(44)
          .layoutWeight(1)
          .enabled(this.newPromptName.trim().length > 0 && this.newPromptContent.trim().length > 0)
          .onClick(() => {
            this.addPrompt();
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
  buildEditPromptDialog() {
    Column() {
      // 标题栏
      Row() {
        Text('✏️')
          .fontSize(20)
          .margin({ right: 8 })
        
        Text('编辑系统提示词')
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
            Text('提示词名称')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            
            Text('*')
              .fontSize(15)
              .fontColor($r('app.color.error_color'))
              .margin({ left: 2 })
          }
          .alignItems(VerticalAlign.Center)
          
          TextInput({ placeholder: '请输入提示词名称', text: this.editPromptName })
            .width('100%')
            .height(48)
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(12)
            .padding({ left: 16, right: 16 })
            .border({
              width: 1,
              color: this.editPromptName.trim().length > 0 ? $r('app.color.primary_color') : $r('app.color.border_color')
            })
            .onChange((value: string) => {
              this.editPromptName = value;
            })
        }
        .alignItems(HorizontalAlign.Start)

        // 内容输入
        Column({ space: 8 }) {
          Row() {
            Text('提示词内容')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            
            Text('*')
              .fontSize(15)
              .fontColor($r('app.color.error_color'))
              .margin({ left: 2 })
          }
          .alignItems(VerticalAlign.Center)
          
          TextArea({ placeholder: '请输入提示词内容', text: this.editPromptContent })
            .width('100%')
            .height(140)
            .backgroundColor($r('app.color.input_background'))
            .borderRadius(12)
            .padding(16)
            .border({
              width: 1,
              color: this.editPromptContent.trim().length > 0 ? $r('app.color.primary_color') : $r('app.color.border_color')
            })
            .onChange((value: string) => {
              this.editPromptContent = value;
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
          .backgroundColor(this.editPromptName.trim().length > 0 && this.editPromptContent.trim().length > 0 ? 
            $r('app.color.primary_color') : $r('app.color.border_color'))
          .borderRadius(12)
          .height(44)
          .layoutWeight(1)
          .enabled(this.editPromptName.trim().length > 0 && this.editPromptContent.trim().length > 0)
          .onClick(() => {
            this.updatePrompt();
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

  private async usePrompt(prompt: SystemPrompt): Promise<void> {
    try {
      // 设置loading状态
      this.usingPromptId = prompt.id;
      
      Logger.info('SystemPromptManagerPage', `开始使用提示词创建新会话: ${prompt.name}`);

      // 显示toast提示
      promptAction.showToast({
        message: `正在使用"${prompt.name}"创建新会话...`,
        duration: 2000
      });

      const sessionManager = SessionManager.getInstance();
      const newSessionId = await sessionManager.createSessionFromPrompt(prompt);

      Logger.info('SystemPromptManagerPage', `新会话创建成功: ${newSessionId}，准备跳转...`);

      // 清除loading状态
      this.usingPromptId = '';

      // 显示成功提示
      promptAction.showToast({
        message: '新会话创建成功！',
        duration: 1500
      });

      // 延迟跳转以确保用户能看到成功提示
      setTimeout(() => {
        router.pushUrl({
          url: 'pages/ChatPage',
          params: { sessionId: newSessionId }
        }).then(() => {
          Logger.info('SystemPromptManagerPage', '成功跳转到聊天页面');
        }).catch((error: Error) => {
          Logger.error('SystemPromptManagerPage', `跳转失败: ${error.message}`);
        });
      }, 300);

    } catch (error) {
      // 清除loading状态
      this.usingPromptId = '';
      
      Logger.error('SystemPromptManagerPage', `使用提示词创建会话失败: ${error}`);
      promptAction.showToast({
        message: `创建失败: ${(error as Error).message}`,
        duration: 3000
      });
    }
  }

  /**
   * 应用提示词到当前会话
   */
  private async applyToCurrentSession(prompt: SystemPrompt): Promise<void> {
    try {
      // 设置loading状态
      this.usingPromptId = prompt.id;
      
      Logger.info('SystemPromptManagerPage', `开始应用提示词到当前会话: ${prompt.name}`);

      // 显示toast提示
      promptAction.showToast({
        message: `正在应用"${prompt.name}"到当前会话...`,
        duration: 2000
      });

      // 检查是否有当前会话ID
      if (!this.currentSessionId) {
        throw new Error('当前没有活动会话');
      }

      // 使用 SessionManager 更新会话的系统提示词
      await this.sessionManager.updateSessionPrompt(this.currentSessionId, prompt.id);

      Logger.info('SystemPromptManagerPage', `系统提示词已应用到会话: ${this.currentSessionId}`);

      // 清除loading状态
      this.usingPromptId = '';

      // 显示成功提示
      promptAction.showToast({
        message: '系统提示词应用成功！',
        duration: 1500
      });

      // 延迟返回到聊天页面
      setTimeout(() => {
        router.back();
      }, 800);

    } catch (error) {
      // 清除loading状态
      this.usingPromptId = '';
      
      Logger.error('SystemPromptManagerPage', `应用提示词到当前会话失败: ${error}`);
      promptAction.showToast({
        message: `应用失败: ${(error as Error).message}`,
        duration: 3000
      });
    }
  }


  private async loadPrompts(): Promise<void> {
    try {
      Logger.info('SystemPromptManagerPage', '开始加载提示词');
      
      // 加载所有提示词
      const loadedPrompts = await AppStorage.getSystemPrompts();
      Logger.info('SystemPromptManagerPage', `从AppStorage加载了 ${loadedPrompts.length} 条系统提示词`);
      
      // 强制触发UI更新 - 使用扩展运算符创建新数组
      this.prompts = [...loadedPrompts];
      Logger.info('SystemPromptManagerPage', `UI状态已更新，当前显示 ${this.prompts.length} 条提示词`);
      
      Logger.info('SystemPromptManagerPage', '提示词加载完成');
    } catch (error) {
      Logger.error('SystemPromptManagerPage', `加载提示词失败: ${(error as Error).message}`);
      Logger.error('SystemPromptManagerPage', `错误堆栈: ${(error as Error).stack}`);
    }
  }



  
  private async addPrompt(): Promise<void> {
    try {
      Logger.info('SystemPromptManagerPage', `开始添加提示词: ${this.newPromptName.trim()}`);
      
      const newPrompt: SystemPrompt = new SystemPrompt(
        this.newPromptName.trim(),
        this.newPromptContent.trim(),
        ''
      );
      
      Logger.debug('SystemPromptManagerPage', `新提示词对象: ${JSON.stringify(newPrompt)}`);
      
      await AppStorage.addSystemPrompt(newPrompt);
      Logger.info('SystemPromptManagerPage', '提示词已保存到存储，准备重新加载');
      
      // 关闭对话框并清空输入
      this.showAddDialog = false;
      this.newPromptName = '';
      this.newPromptContent = '';
      
      // 强制清空并重新加载数据，确保UI更新
      this.prompts = []; // 先清空
      await this.loadPrompts(); // 再重新加载
      
      Logger.debug('SystemPromptManagerPage', '对话框状态已重置');
      
      promptAction.showToast({
        message: '添加成功',
        duration: 1500
      });
      
      Logger.info('SystemPromptManagerPage', '提示词添加完成');
    } catch (error) {
      Logger.error('SystemPromptManagerPage', `添加提示词失败: ${(error as Error).message}`);
      Logger.error('SystemPromptManagerPage', `错误堆栈: ${(error as Error).stack}`);
      promptAction.showToast({
        message: '添加失败',
        duration: 1500
      });
    }
  }

  private async updatePrompt(): Promise<void> {
    try {
      if (this.editingPrompt) {
        console.info('=== 开始更新提示词 ===');
        console.info(`更新提示词 ID: ${this.editingPrompt.id}`);
        console.info(`新名称: ${this.editPromptName.trim()}`);
        console.info(`新内容长度: ${this.editPromptContent.trim().length}`);
        
        // 创建更新后的提示词对象
        const updatedPrompt: SystemPrompt = new SystemPrompt(
          this.editPromptName.trim(),
          this.editPromptContent.trim(),
          ''
        );
        updatedPrompt.id = this.editingPrompt.id;
        updatedPrompt.timestamp = Date.now();
        
        Logger.debug('SystemPromptManagerPage', `更新后的提示词对象: ${JSON.stringify(updatedPrompt)}`);
        
        await AppStorage.updateSystemPrompt(updatedPrompt);
        Logger.info('SystemPromptManagerPage', '提示词已更新到存储，准备重新加载');
        
        // 关闭编辑对话框
        this.showEditDialog = false;
        this.editingPrompt = null;
        
        // 强制清空并重新加载数据，确保UI更新
        this.prompts = []; // 先清空
        await this.loadPrompts(); // 再重新加载
        
        promptAction.showToast({
          message: '更新成功',
          duration: 1500
        });
        
        Logger.info('SystemPromptManagerPage', '提示词更新完成');
      }
    } catch (error) {
      Logger.error('SystemPromptManagerPage', `更新提示词失败: ${(error as Error).message}`);
      Logger.error('SystemPromptManagerPage', `错误堆栈: ${(error as Error).stack}`);
      promptAction.showToast({
        message: '更新失败',
        duration: 1500
      });
    }
  }


  private async deletePrompt(prompt: SystemPrompt): Promise<void> {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除提示词"${prompt.name}"吗？此操作不可撤销。`,
      primaryButton: {
        value: '确定',
        action: async () => {
          try {
            Logger.info('SystemPromptManagerPage', `开始删除提示词: ${prompt.name}`);
            
            await AppStorage.deleteSystemPrompt(prompt.id);
            Logger.info('SystemPromptManagerPage', '提示词已从存储删除，准备重新加载');
            
            // 强制清空并重新加载数据，确保UI更新
            this.prompts = []; // 先清空
            await this.loadPrompts(); // 再重新加载
            
            promptAction.showToast({
              message: '删除成功',
              duration: 1500
            });
            
            Logger.info('SystemPromptManagerPage', '提示词删除完成');
          } catch (error) {
            Logger.error('SystemPromptManagerPage', `删除提示词失败: ${(error as Error).message}`);
            Logger.error('SystemPromptManagerPage', `错误堆栈: ${(error as Error).stack}`);
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