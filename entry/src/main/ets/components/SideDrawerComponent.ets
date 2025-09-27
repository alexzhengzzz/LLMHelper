import { router } from '@kit.ArkUI';
import { curves } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { ThemeManager } from '../utils/ThemeManager';
import { AvatarSettings, UserProfile, AppStorage as StorageManager } from '../utils/AppStorage';
import { UserProfileManager } from '../utils/UserProfileManager';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';
import { Session, SystemPrompt } from '../models/ChatModels';
import { ChatViewModel } from '../viewmodels/ChatViewModel';
import { SwipeableSessionItemComponent } from './SwipeableSessionItemComponent';
import { NewSessionDialogComponent } from './NewSessionDialogComponent';
import { RoleViewComponent } from './RoleViewComponent';
import { AppConfigManager } from '../utils/AppConfigManager';

interface AvatarOption {
  text: string;
  value: string;
}

interface MenuItem {
  id: string;
  title: string;
  subtitle: string;
  icon: string;
  iconColor: string;
  action: () => void;
}

interface MenuSection {
  title: string;
  items: MenuItem[];
}

@ComponentV2
export struct SideDrawerComponent {
  @Param @Require onClose: () => void;
  @Param @Require onSessionSwitched?: () => void; // 会话切换成功后的回调
  @Param chatViewModel: ChatViewModel | null = null;
  @Param sessions: Session[] = []; // 会话列表，单独传递以确保响应式更新
  @Param systemPrompts: SystemPrompt[] = []; // 系统提示词列表，用于显示会话绑定的提示词
  @Param swipeProgress: number = 0; // 外部滑动进度 (0-1)
  @Param isSwipeActive: boolean = false; // 是否正在滑动
  @Param onSessionSwipeStateChange?: (isSwiping: boolean) => void = undefined; // 会话项滑动状态变化回调
  @Local isDarkMode: boolean = false;
  @Local userAvatarType: 'default' | 'emoji' | 'image' = 'default';
  @Local userAvatarValue: string = '#4285F4';
  @Local aiAvatarType: 'default' | 'emoji' | 'image' = 'default';
  @Local aiAvatarValue: string = '#34A853';
  @Local userName: string = 'Javis用户';
  @Local userSignature: string = '让AI成为你的编程伙伴';
  @Local showRenameDialog: boolean = false;
  @Local renameSessionId: string = '';
  @Local renameText: string = '';
  @Local drawerVisible: boolean = false; // 抽屉可见状态
  @Local animationProgress: number = 0; // 菜单滑动动画进度 (0-1)
  @Local maskOpacity: number = 0; // 遮罩层透明度 (0-1)，独立控制
  @Local showNewSessionDialog: boolean = false; // 新增：新建会话对话框状态
  @Local isSessionItemSwiping: boolean = false; // 会话项正在滑动状态
  @Local isExiting: boolean = false; // 是否正在执行退出动画
  @Local activeTab: 'sessions' | 'roles' = 'sessions'; // 活跃标签页：会话或角色
  @Local globalSearchQuery: string = ''; // 全局搜索关键词
  @Local filteredSessions: Session[] = []; // 搜索过滤后的会话列表
  @Local selectedRoleFilter: SystemPrompt | null = null; // 选中的角色筛选器
  @Local showRoleFilter: boolean = false; // 是否显示角色筛选器
  
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private userProfileManager: UserProfileManager = UserProfileManager.getInstance();
  private swipeableItemRefs: Map<string, SwipeableSessionItemComponent> = new Map(); // 侧滑组件引用
  private debounceTimer: number = 0; // 防抖定时器
  private readonly DEBOUNCE_DELAY = 300; // 防抖延迟时间（毫秒）
  private avatarListener: (settings: AvatarSettings) => void = (settings: AvatarSettings) => {
    this.userAvatarType = settings.userAvatarType;
    this.userAvatarValue = settings.userAvatarValue;
    this.aiAvatarType = settings.aiAvatarType;
    this.aiAvatarValue = settings.aiAvatarValue;
    Logger.info('SideDrawerComponent', '头像设置已更新');
  };
  private userProfileListener: (profile: UserProfile) => void = (profile: UserProfile) => {
    this.userName = profile.userName;
    this.userSignature = profile.userSignature;
    this.userAvatarType = profile.userAvatarType;
    this.userAvatarValue = profile.userAvatarValue;
    Logger.info('SideDrawerComponent', '用户资料已更新');
  };

  async aboutToAppear(): Promise<void> {
    this.isDarkMode = this.themeManager.getDarkMode();
    
    // 初始化用户资料管理器
    try {
      await this.userProfileManager.initialize();
      const currentProfile = this.userProfileManager.getCurrentProfile();
      if (currentProfile) {
        this.userName = currentProfile.userName;
        this.userSignature = currentProfile.userSignature;
        this.userAvatarType = currentProfile.userAvatarType;
        this.userAvatarValue = currentProfile.userAvatarValue;
        Logger.info('SideDrawerComponent', `用户资料加载成功: ${this.userName}`);
      }
    } catch (error) {
      Logger.error('SideDrawerComponent', `初始化用户资料管理器失败: ${error}`);
    }
    
    // 加载AI头像设置
    try {
      const avatarSettings = await StorageManager.getAvatarSettings();
      this.aiAvatarType = avatarSettings.aiAvatarType;
      this.aiAvatarValue = avatarSettings.aiAvatarValue;
      Logger.info('SideDrawerComponent', `AI头像设置加载成功: ${JSON.stringify(avatarSettings)}`);
    } catch (error) {
      Logger.error('SideDrawerComponent', `加载AI头像设置失败: ${error}`);
    }
    
    // 添加用户资料监听器
    this.userProfileManager.addProfileListener(this.userProfileListener);
    
    // 添加头像设置监听器（仅用于AI头像）
    StorageManager.addAvatarListener(this.avatarListener);
    
    // 添加会话数据清除监听器
    StorageManager.addSessionDataClearedListener(() => this.onSessionDataCleared());
    
    // 启动进入动画
    this.startEnterAnimation();

    // 初始化过滤后的会话列表
    this.filteredSessions = [...this.sessions];
  }

  /**
   * 启动进入动画
   */
  private startEnterAnimation(): void {
    // 先显示抽屉
    this.drawerVisible = true;
    
    // 如果正在外部滑动，不执行动画，直接设置状态
    if (this.isSwipeActive) {
      this.maskOpacity = Math.max(0.3, this.swipeProgress * 0.5);
      this.animationProgress = this.swipeProgress;
      Logger.debug('SideDrawerComponent', '滑动激活状态，跳过进入动画');
      return;
    }
    
    // 延迟一帧后开始动画
    setTimeout(() => {
      // 遮罩层动画
      animateTo(
        {
          duration: 300,
          curve: curves.springMotion(0.8, 0.9),
          iterations: 1,
          playMode: PlayMode.Normal
        },
        () => {
          this.maskOpacity = 1;
        }
      );
      
      // 菜单滑入动画（稍微延迟）
      setTimeout(() => {
        animateTo(
          {
            duration: 300,
            curve: curves.springMotion(0.8, 0.9), // 弹性退出曲线
            iterations: 1,
            playMode: PlayMode.Normal
          },
          () => {
            this.animationProgress = 1;
          }
        );
      }, 50);
    }, 16);
  }

  /**
   * 启动退出动画
   */
  private startExitAnimation(callback?: () => void): void {
    // 始终执行平滑的常规退出动画
    // 不再区分滑动状态，确保所有关闭操作都有流畅的动画
    Logger.debug('SideDrawerComponent', '执行退出动画');

    // 标记进入退出动画状态
    this.isExiting = true;
    
    // 菜单滑出动画
    this.animationProgress = 1;
    animateTo(
      {
        duration: 300,
        curve: curves.springMotion(0.75, 0.85),
        iterations: 1,
        playMode: PlayMode.Normal,
        onFinish: () => {
          this.drawerVisible = false;
          this.isExiting = false; // 退出动画完成
          callback?.();
        }
      },
      () => {
        this.animationProgress = 0;
      }
    );
  }

  /**
   * 关闭抽屉（带动画）
   */
  private closeDrawer(): void {
    // 如果正在滑动，立即停止滑动状态
    if (this.isSwipeActive) {
      Logger.debug('SideDrawerComponent', '强制结束滑动状态，执行关闭动画');
    }
    
    this.startExitAnimation(() => {
      this.onClose();
    });
  }

  aboutToDisappear(): void {
    // 清理防抖定时器
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = 0;
    }

    // 移除用户资料监听器
    this.userProfileManager.removeProfileListener(this.userProfileListener);

    // 移除头像设置监听器
    StorageManager.removeAvatarListener(this.avatarListener);

    // 移除会话数据清除监听器
    // 注意：由于使用了箭头函数，这里移除监听器需要保存引用
    // 在当前实现中，监听器会在页面销毁时自动清理
  }

  /**
   * 处理会话数据清除事件
   */
  private onSessionDataCleared(): void {
    Logger.info('SideDrawerComponent', '收到会话数据清除通知，关闭侧边菜单');
    
    // 关闭侧边菜单
    this.startExitAnimation(() => {
      this.onClose();
    });
  }

  private get menuSections(): MenuSection[] {
    return [
      {
        title: '功能',
        items: [
          {
            id: 'memory',
            title: '记忆中心',
            subtitle: '管理AI记忆和知识',
            icon: '🧠',
            iconColor: '#E74C3C',
            action: () => {
              this.navigateToMemoryManager();
            }
          }
        ]
      },
      {
        title: '设置',
        items: [
          {
            id: 'settings',
            title: '设置',
            subtitle: '应用设置和偏好',
            icon: '⚙️',
            iconColor: '#8E44AD',
            action: () => {
              this.navigateToSettings();
            }
          }
        ]
      }
    ];
  }

  build() {
    Stack() {
      // 侧边抽屉主内容
      Row() {
        // 抽屉内容
        Column() {
          // 头部
          this.buildHeader()

          // 主内容区域 - 会话列表或角色列表
          this.buildMainContentSection()
        }
        .width(280)
        .height('100%')
        .backgroundColor($r('app.color.surface_color'))
        .borderRadius({ topRight: 16, bottomRight: 16 })
        .shadow({
          radius: 32,
          color: 'rgba(0, 0, 0, 0.2)',
          offsetX: 8,
          offsetY: 0
        })
        
        // 右侧背景遮罩区域（可点击关闭）
        Column()
          .layoutWeight(1)
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0)')
          .opacity(Math.max(this.maskOpacity, this.swipeProgress * 0.5))
          .onClick(() => {
            this.closeDrawer();
          })
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Top)
      .justifyContent(FlexAlign.Start)
      .translate({ 
        x: -280 * (1 - (this.isExiting ? this.animationProgress : Math.max(this.animationProgress, this.swipeProgress))) 
      }) // 退出动画期间优先使用内部animationProgress，避免外部状态干扰
      .visibility(this.drawerVisible ? Visibility.Visible : Visibility.Hidden)

      // 重命名对话框（居中显示）
      if (this.showRenameDialog) {
        Column() {
          this.buildRenameDialog()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(0, 0, 0, 0.3)')
        .onClick(() => {
          // 点击背景关闭对话框
          this.cancelRename();
        })
      }
      
      // 新建会话对话框（居中显示）
      if (this.showNewSessionDialog) {
        Stack() {
          // 背景遮罩
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.cancelNewSession();
            })

          // 对话框
          NewSessionDialogComponent({
            systemPrompts: this.chatViewModel?.systemPrompts || [],
            onConfirm: (prompt) => this.confirmNewSession(prompt),
            onCancel: () => this.cancelNewSession()
          })
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
        .zIndex(2000) // 提高z-index确保在最上层
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildHeader() {
    Column() {
      // 用户资料区域
      Column() {
        // 用户头像
        Column() {
          this.buildUserAvatar()
        }
        .margin({ bottom: 12 })

        // 用户信息区域（可点击编辑）
        Column() {
          // 用户名字
          Text(this.userName)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 个性签名
          Text(this.userSignature)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 16 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.navigateToProfileEdit();
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

    }
    .width('100%')
    .padding({ top: 48, left: 24, right: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildUserAvatar() {
    if (this.userAvatarType === 'emoji') {
      Text(this.userAvatarValue)
        .fontSize(32)
        .width(64)
        .height(64)
        .textAlign(TextAlign.Center)
        .border({ width: 2, color: $r('app.color.border_color'), radius: 32 })
        .backgroundColor($r('app.color.surface_color'))
        .onClick(() => {
          this.navigateToProfileEdit();
        })
    } else if (this.userAvatarType === 'image') {
      Image(this.userAvatarValue)
        .width(64)
        .height(64)
        .borderRadius(32)
        .border({ width: 2, color: $r('app.color.border_color') })
        .objectFit(ImageFit.Cover)
        .onError(() => {
          // 图片加载失败时显示默认头像
          Logger.warn('SideDrawerComponent', '用户头像图片加载失败，显示默认头像');
        })
        .onClick(() => {
          this.navigateToProfileEdit();
        })
    } else {
      Circle({ width: 64, height: 64 })
        .fill(this.userAvatarValue)
        .border({ width: 2, color: $r('app.color.border_color') })
        .onClick(() => {
          this.navigateToProfileEdit();
        })
    }
  }

  @Builder
  buildMenuSection(section: MenuSection) {
    Column() {
      Text(section.title)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ left: 24, top: 24, bottom: 8 })

      Column() {
        ForEach(section.items, (item: MenuItem, index: number) => {
          this.buildMenuItem(item, index === section.items.length - 1)
        })
      }
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(12)
      .margin({ left: 16, right: 16 })
    }
    .width('100%')
  }

  @Builder
  buildMenuItem(item: MenuItem, isLast: boolean) {
    Column() {
      Row() {
        // 图标
        Text(item.icon)
          .fontSize(20)
          .fontColor(item.iconColor)
          .margin({ right: 16 })

        // 文字内容
        Column() {
          Text(item.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)

          Text(item.subtitle)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ top: 2 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 箭头
        Text('›')
          .fontSize(20)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .height(64)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        item.action();
      })

      if (!isLast) {
        Divider()
          .color($r('app.color.border_color'))
          .height(0.5)
          .margin({ left: 56, right: 16 })
      }
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  //=================== 会话和角色管理相关Builder ===================

  @Builder
  buildMainContentSection() {
    Column() {
      // 标签页切换
      Row() {
        // 会话标签
        Button() {
          Text('会话')
            .fontSize(14)
            .fontWeight(this.activeTab === 'sessions' ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.activeTab === 'sessions' ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.activeTab = 'sessions';
        })
        .layoutWeight(1)
        .height(40)
        .borderRadius(0)
        .border({ width: { bottom: 2 }, color: this.activeTab === 'sessions' ? $r('app.color.text_primary') : Color.Transparent })

        // 角色标签
        Button() {
          Text('角色')
            .fontSize(14)
            .fontWeight(this.activeTab === 'roles' ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.activeTab === 'roles' ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.activeTab = 'roles';
        })
        .layoutWeight(1)
        .height(40)
        .borderRadius(0)
        .border({ width: { bottom: 2 }, color: this.activeTab === 'roles' ? $r('app.color.text_primary') : Color.Transparent })
      }
      .width('100%')
      .margin({ top: 16, left: 16, right: 16 })

      // 全局搜索区域
      this.buildGlobalSearchSection()

      // 内容区域
      if (this.activeTab === 'sessions') {
        this.buildSessionSection()
      } else {
        this.buildRoleSection()
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildGlobalSearchSection() {
    Column() {
      // 全局搜索框
      if (this.activeTab === 'sessions') {
        Search({ placeholder: this.activeTab === 'sessions' ? '搜索会话历史...' : '搜索角色...' })
          .width('90%')
          .height(36)
          .margin({ top: 8, bottom: 8 })
          .onChange((value: string) => {
            this.globalSearchQuery = value;
            if (this.activeTab === 'sessions') {
              this.performGlobalSearch();
            }
          })
      }

      // 角色筛选器（条件显示，仅在会话页面显示）
      if (this.activeTab === 'sessions' && this.showRoleFilter && this.selectedRoleFilter) {
        Row() {
          // 角色图标
          Text(this.selectedRoleFilter.roleIcon || '🎭')
            .fontSize(14)
            .margin({ right: 6 })

          // 角色名称
          Text(`${this.selectedRoleFilter.name}`)
            .fontSize(12)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 清除筛选按钮
          Button() {
            Text('✕')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .type(ButtonType.Circle)
          .width(20)
          .height(20)
          .backgroundColor('transparent')
          .stateEffect(true)
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            this.clearRoleFilter();
          })
        }
        .width('auto')
        .height(32)
        .padding({ left: 8, right: 6, top: 4, bottom: 4 })
        .backgroundColor('#E3F2FD')
        .borderRadius(16)
        .margin({ top: 4, bottom: 8, left: 16, right: 16 })
        .border({ width: 1, color: '#2196F3' })
        .alignSelf(ItemAlign.Start)
        .stateStyles({
          pressed: {
            .backgroundColor('#BBDEFB')
            .scale({ x: 0.95, y: 0.95 })
          },
          normal: {
            .backgroundColor('#E3F2FD')
            .scale({ x: 1.0, y: 1.0 })
          }
        })
        .animation({
          duration: 120,
          curve: Curve.EaseInOut
        })
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          this.clearRoleFilter();
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildSessionSection() {
    Scroll() {
      Column() {
        // 会话列表头部
        Row() {
          Text('会话列表')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 24 })

          Blank()

          // 新建会话按钮
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Text('+')
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
          }
          .width(28)
          .height(28)
          .backgroundColor('transparent')
          .border({ width: 1, color: $r('app.color.border_color'), radius: 14 })
          .margin({ right: 24 })
          .onClick(() => {
            this.handleNewSession();
          })
        }
        .width('100%')
        .height(40)
        .alignItems(VerticalAlign.Center)
        .margin({ top: 8 })


        // 会话列表
        Column() {
          if (this.filteredSessions.length > 0) {
            ForEach(this.filteredSessions, (session: Session, index: number) => {
              SwipeableSessionItemComponent({
                session: session,
                systemPromptName: this.getSystemPromptName(session.systemPromptId), // 传递系统提示词名称
                isCurrentSession: this.isCurrentSession(session),
                isLast: index === this.filteredSessions.length - 1,
                onSessionClick: (sessionId: string) => {
                  this.switchToSession(sessionId);
                },
                onDelete: (sessionId: string) => {
                  this.confirmDeleteSession(sessionId);
                },
                onSwipeStart: () => {
                  this.handleSessionSwipeStart();
                },
                onSwipeEnd: () => {
                  this.handleSessionSwipeEnd();
                }
              })
            }, (session: Session) => session.id)
          } else {
            // 空状态
            Column() {
              Text(this.globalSearchQuery.trim() || this.showRoleFilter ? '没有找到匹配的会话' : '暂无会话')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 20, bottom: 20 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
        }
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(12)
        .margin({ left: 16, right: 16, top: 8, bottom: 8 })
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  buildRoleSection() {
    RoleViewComponent({
      onRoleSelect: (role: SystemPrompt) => {
        this.handleRoleSelect(role);
      },
      onRoleFilterRequest: (role: SystemPrompt) => {
        this.setRoleFilter(role);
      }
    })
  }


  @Builder
  buildRenameDialog() {
    Column() {
      // 标题
      Text('重命名会话')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 16 })

      // 输入框
      TextInput({ text: this.renameText, placeholder: '请输入会话名称' })
        .width('100%')
        .height(40)
        .fontSize(16)
        .backgroundColor($r('app.color.input_background'))
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 24 })
        .onChange((value: string) => {
          this.renameText = value;
        })

      // 按钮
      Row() {
        Button('取消')
          .type(ButtonType.Normal)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor('transparent')
          .width(80)
          .height(36)
          .onClick(() => {
            this.cancelRename();
          })

        Button('确定')
          .type(ButtonType.Normal)
          .fontColor('#FFFFFF')
          .backgroundColor('#4285F4')
          .width(80)
          .height(36)
          .margin({ left: 12 })
          .onClick(() => {
            this.confirmRename();
          })
      }
      .justifyContent(FlexAlign.End)
      .width('100%')
    }
    .width(280)
    .padding({ top: 24, bottom: 24, left: 24, right: 24 })
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(12)
    .shadow({ 
      radius: 16, 
      color: 'rgba(0,0,0,0.1)', 
      offsetX: 0, 
      offsetY: 4 
    })
    .onClick(() => {
      // 阻止事件冒泡，避免点击对话框时关闭 
    })
  }

  //=================== 会话和角色管理相关方法 ===================

  /**
   * 判断是否为当前会话
   */
  private isCurrentSession(session: Session): boolean {
    return this.chatViewModel?.currentSession?.id === session.id;
  }

  /**
   * 处理会话项滑动开始
   */
  private handleSessionSwipeStart(): void {
    this.isSessionItemSwiping = true;
    Logger.debug('SideDrawerComponent', '会话项开始滑动，禁用侧边栏滑动');
    
    // 通知父组件
    this.onSessionSwipeStateChange?.(true);
  }

  /**
   * 处理会话项滑动结束
   */
  private handleSessionSwipeEnd(): void {
    this.isSessionItemSwiping = false;
    Logger.debug('SideDrawerComponent', '会话项滑动结束，恢复侧边栏滑动');
    
    // 通知父组件
    this.onSessionSwipeStateChange?.(false);
  }

  /**
   * 获取会话项滑动状态
   */
  public isSessionItemSwipingActive(): boolean {
    return this.isSessionItemSwiping;
  }

  /**
   * 显示新建会话对话框
   */
  private handleNewSession(): void {
    Logger.info('SideDrawerComponent', '显示新建会话对话框');
    Logger.info('SideDrawerComponent', `ChatViewModel存在: ${!!this.chatViewModel}`);
    Logger.info('SideDrawerComponent', `系统提示词数量: ${this.chatViewModel?.systemPrompts?.length || 0}`);
    Logger.info('SideDrawerComponent', `当前showNewSessionDialog状态: ${this.showNewSessionDialog}`);
    
    this.showNewSessionDialog = true;
    
    Logger.info('SideDrawerComponent', `设置后showNewSessionDialog状态: ${this.showNewSessionDialog}`);
  }

  /**
   * 确认创建新会话
   */
  private async confirmNewSession(selectedPrompt: SystemPrompt | null): Promise<void> {
    try {
      Logger.info('SideDrawerComponent', `确认创建新会话，系统提示词: ${selectedPrompt?.name || '无'}`);
      
      this.showNewSessionDialog = false;
      
      if (!this.chatViewModel) {
        Logger.warn('SideDrawerComponent', '没有ChatViewModel，无法创建会话');
        return;
      }

      // 使用新的带系统提示词的创建方法
      const newSession = await this.chatViewModel.createNewSessionWithPrompt(selectedPrompt);
      if (newSession) {
        Logger.info('SideDrawerComponent', `新会话创建成功: ${newSession.name}`);
        
        // 通知父组件会话已切换
        this.onSessionSwitched?.();
      }
    } catch (error) {
      Logger.error('SideDrawerComponent', `创建新会话失败: ${error}`);
    }
    
    // 关闭侧边栏
    this.closeDrawer();
  }

  /**
   * 取消新建会话
   */
  private cancelNewSession(): void {
    Logger.info('SideDrawerComponent', '取消新建会话');
    this.showNewSessionDialog = false;
  }

  /**
   * 根据系统提示词ID获取提示词名称
   */
  private getSystemPromptName(systemPromptId: string | null): string | null {
    if (!systemPromptId || this.systemPrompts.length === 0) {
      return null;
    }
    const prompt = this.systemPrompts.find(p => p.id === systemPromptId);
    return prompt ? prompt.name : null;
  }

  /**
   * 切换到指定会话
   */
  private async switchToSession(sessionId: string): Promise<void> {
    try {
      if (!this.chatViewModel) {
        Logger.warn('SideDrawerComponent', '没有ChatViewModel，无法切换会话');
        return;
      }

      const success = await this.chatViewModel.switchToSession(sessionId);
      if (success) {
        Logger.info('SideDrawerComponent', `会话切换成功: ${sessionId}`);
        this.closeDrawer(); // 带动画关闭侧边栏
        
        // 通知会话切换成功，触发滚动到最新消息
        if (this.onSessionSwitched) {
          this.onSessionSwitched();
        }
      }
    } catch (error) {
      Logger.error('SideDrawerComponent', `切换会话失败: ${error}`);
    }
  }


  /**
   * 开始重命名会话
   */
  private startRename(session: Session): void {
    this.renameSessionId = session.id;
    this.renameText = session.name;
    this.showRenameDialog = true;
  }

  /**
   * 取消重命名
   */
  private cancelRename(): void {
    this.showRenameDialog = false;
    this.renameSessionId = '';
    this.renameText = '';
  }

  /**
   * 确认重命名
   */
  private async confirmRename(): Promise<void> {
    try {
      if (!this.chatViewModel || !this.renameSessionId || !this.renameText.trim()) {
        return;
      }

      const success = await this.chatViewModel.renameSession(this.renameSessionId, this.renameText.trim());
      if (success) {
        Logger.info('SideDrawerComponent', '会话重命名成功');
      }

      this.cancelRename();
    } catch (error) {
      Logger.error('SideDrawerComponent', `重命名会话失败: ${error}`);
    }
  }

  /**
   * 确认删除会话 (侧滑删除，无需确认)
   */
  private confirmDeleteSession(sessionId: string): void {
    this.deleteSession(sessionId);
  }

  /**
   * 删除会话
   */
  private async deleteSession(sessionId: string): Promise<void> {
    try {
      if (!this.chatViewModel) {
        Logger.warn('SideDrawerComponent', '没有ChatViewModel，无法删除会话');
        return;
      }

      const success = await this.chatViewModel.deleteSession(sessionId);
      if (success) {
        Logger.info('SideDrawerComponent', `会话删除成功: ${sessionId}`);

        // 立即更新过滤会话列表，从当前列表中移除已删除的会话
        this.filteredSessions = this.filteredSessions.filter(session => session.id !== sessionId);

        // 同时更新搜索结果，确保界面立即反映删除操作
        this.updateFilteredSessions();
      }
    } catch (error) {
      Logger.error('SideDrawerComponent', `删除会话失败: ${error}`);
    }
  }

  /**
   * 执行全局搜索过滤（带防抖功能，支持角色筛选）
   */
  private performGlobalSearch(): void {
    // 清除之前的定时器
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    // 设置新的定时器
    this.debounceTimer = setTimeout(async () => {
      try {
        let searchResults: Session[] = [];

        // 1. 首先根据角色筛选获取基础会话列表
        if (this.selectedRoleFilter) {
          Logger.debug('SideDrawerComponent', `使用角色筛选: ${this.selectedRoleFilter.name}`);
          const sessionManager = this.chatViewModel?.getSessionManager();
          if (sessionManager) {
            searchResults = await sessionManager.getSessionsByRole(this.selectedRoleFilter.id);
            Logger.debug('SideDrawerComponent', `角色筛选找到 ${searchResults.length} 个相关会话`);
          } else {
            searchResults = [...this.sessions];
          }
        } else {
          // 没有角色筛选，使用所有会话
          searchResults = [...this.sessions];
        }

        // 2. 在筛选结果基础上执行关键词搜索
        if (!this.globalSearchQuery.trim()) {
          // 如果搜索词为空，直接使用筛选结果
          this.filteredSessions = searchResults;
          Logger.debug('SideDrawerComponent', `无搜索关键词，显示${this.selectedRoleFilter ? '角色筛选' : '所有'}会话: ${searchResults.length} 个`);
        } else {
          Logger.debug('SideDrawerComponent', `在${searchResults.length}个会话中搜索关键词: "${this.globalSearchQuery}"`);

          // 使用 SessionManager 的搜索方法，但先筛选会话范围
          const sessionManager = this.chatViewModel?.getSessionManager();
          if (sessionManager) {
            // 如果有角色筛选，需要在筛选结果中进一步搜索
            if (this.selectedRoleFilter) {
              const query = this.globalSearchQuery.toLowerCase().trim();
              const matchedSessions: Session[] = [];

              for (const session of searchResults) {
                // 检查会话标题
                if (session.name.toLowerCase().includes(query)) {
                  matchedSessions.push(session);
                  continue;
                }

                // 检查会话消息内容
                try {
                  const messages = await sessionManager.getSessionMessages(session.id);
                  const hasContentMatch = messages.some(msg =>
                    msg.content && typeof msg.content === 'string' &&
                    msg.content.toLowerCase().includes(query)
                  );
                  if (hasContentMatch) {
                    matchedSessions.push(session);
                  }
                } catch (error) {
                  Logger.warn('SideDrawerComponent', `搜索会话 ${session.id} 内容时出错: ${error}`);
                }
              }

              this.filteredSessions = matchedSessions;
              Logger.info('SideDrawerComponent', `角色筛选+关键词搜索完成，找到 ${matchedSessions.length} 个匹配会话`);
            } else {
              // 没有角色筛选，直接使用全局搜索
              this.filteredSessions = await sessionManager.searchSessions(this.globalSearchQuery);
              Logger.info('SideDrawerComponent', `全局搜索完成，找到 ${this.filteredSessions.length} 个匹配会话`);
            }
          } else {
            Logger.warn('SideDrawerComponent', '未找到SessionManager，使用本地搜索（仅搜索会话名称）');
            // 如果没有 SessionManager，使用本地搜索作为后备方案
            const query = this.globalSearchQuery.toLowerCase().trim();
            this.filteredSessions = searchResults.filter(session =>
              session.name.toLowerCase().includes(query)
            );
            Logger.info('SideDrawerComponent', `本地搜索完成，找到 ${this.filteredSessions.length} 个匹配会话`);
          }
        }
      } catch (error) {
        Logger.error('SideDrawerComponent', `搜索会话失败: ${error}`);
        // 搜索失败时显示所有会话
        this.filteredSessions = [...this.sessions];
      }
    }, this.DEBOUNCE_DELAY);
  }

  /**
   * 更新过滤后的会话列表
   */
  private updateFilteredSessions(): void {
    this.performGlobalSearch();
  }

  /**
   * 当sessions参数变化时自动调用
   */
  protected onSessionsChanged(): void {
    this.updateFilteredSessions();
  }

  /**
   * 处理角色选择
   */
  private async handleRoleSelect(role: SystemPrompt): Promise<void> {
    try {
      Logger.info('SideDrawerComponent', `选择角色: ${role.name}`);

      if (!this.chatViewModel) {
        Logger.warn('SideDrawerComponent', '没有ChatViewModel，无法处理角色选择');
        return;
      }

      // 使用SessionManager创建基于角色的会话
      const sessionManager = this.chatViewModel.getSessionManager();
      const newSession = await sessionManager.createRoleSession(role);

      if (newSession) {
        Logger.info('SideDrawerComponent', `基于角色创建会话成功: ${newSession.name}`);

        // 关闭侧边栏
        this.closeDrawer();

        // 通知父组件会话已切换
        this.onSessionSwitched?.();
      }
    } catch (error) {
      Logger.error('SideDrawerComponent', `处理角色选择失败: ${error}`);
    }
  }

  /**
   * 设置角色筛选器（供外部调用，用于快捷筛选）
   */
  public setRoleFilter(role: SystemPrompt): void {
    try {
      Logger.info('SideDrawerComponent', `设置角色筛选器: ${role.name}`);

      this.selectedRoleFilter = role;
      this.showRoleFilter = true;

      // 切换到会话标签页
      this.activeTab = 'sessions';

      // 触发搜索更新
      this.performGlobalSearch();

      Logger.info('SideDrawerComponent', `角色筛选器设置完成，切换到会话标签页`);
    } catch (error) {
      Logger.error('SideDrawerComponent', `设置角色筛选器失败: ${error}`);
    }
  }

  /**
   * 清除角色筛选器
   */
  private clearRoleFilter(): void {
    try {
      Logger.info('SideDrawerComponent', '清除角色筛选器');

      this.selectedRoleFilter = null;
      this.showRoleFilter = false;

      // 重新执行搜索，显示所有会话
      this.performGlobalSearch();

      Logger.info('SideDrawerComponent', '角色筛选器已清除');
    } catch (error) {
      Logger.error('SideDrawerComponent', `清除角色筛选器失败: ${error}`);
    }
  }

  
  private navigateToSettings(): void {
    this.closeDrawer();
    setTimeout(() => {
      router.pushUrl({ url: 'pages/SettingsPage' });
    }, 300);
  }

  private navigateToMemoryManager(): void {
    this.closeDrawer();
    setTimeout(() => {
      router.pushUrl({ url: 'pages/MemoryManagerPage' });
    }, 300);
  }

  private navigateToProfileEdit(): void {
    this.closeDrawer();
    setTimeout(() => {
      router.pushUrl({ url: 'pages/UserProfileEditPage' });
    }, 300);
  }

  //=================== 头像选择相关方法 ===================

  /**
   * 显示头像选择对话框
   */
  private showAvatarSelectionDialog(): void {
    const avatarOptions: AvatarOption[] = [
      { text: '默认蓝色', value: 'default:#4285F4' },
      { text: '默认绿色', value: 'default:#34A853' },
      { text: '默认红色', value: 'default:#EA4335' },
      { text: '默认橙色', value: 'default:#FBBC05' },
      { text: '默认紫色', value: 'default:#9C27B0' },
      { text: '😀', value: 'emoji:😀' },
      { text: '🙂', value: 'emoji:🙂' },
      { text: '😊', value: 'emoji:😊' },
      { text: '🤔', value: 'emoji:🤔' },
      { text: '🤖', value: 'emoji:🤖' },
      { text: '👨‍💻', value: 'emoji:👨‍💻' },
      { text: '👩‍💻', value: 'emoji:👩‍💻' },
      { text: '选择图片', value: 'image:select' }
    ];

    this.showAvatarGridDialog(true, avatarOptions);
  }

  /**
   * 显示头像网格选择对话框
   */
  private showAvatarGridDialog(isUserAvatar: boolean, options: AvatarOption[]): void {
    const optionTexts = options.map((opt: AvatarOption) => opt.text);
    
    TextPickerDialog.show({
      range: optionTexts,
      selected: 0,
      onAccept: async (value: TextPickerResult) => {
        const selectedIndex: number = value.index as number;
        const selectedOption = options[selectedIndex];
        
        if (selectedOption.value === 'image:select') {
          await this.selectImageFromGallery(isUserAvatar);
        } else {
          const parts = selectedOption.value.split(':');
          const type = parts[0] as 'default' | 'emoji';
          const val = parts[1];
          await this.updateAvatarSetting(isUserAvatar, type, val);
        }
      },
      onCancel: () => {
        // 取消头像选择
      }
    });
  }

  /**
   * 从相册选择图片
   */
  private async selectImageFromGallery(isUserAvatar: boolean): Promise<void> {
    try {
      const photoSelectOptions: picker.PhotoSelectOptions = {
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };

      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const photoSelectResult: picker.PhotoSelectResult = await photoPicker.select(photoSelectOptions);

      if (photoSelectResult.photoUris.length > 0) {
        const imageUri: string = photoSelectResult.photoUris[0];
        await this.updateAvatarSetting(isUserAvatar, 'image', imageUri);
        Logger.info('SideDrawerComponent', '头像图片选择成功');
      }
    } catch (error) {
      Logger.error('SideDrawerComponent', `选择头像图片失败: ${error}`);
      AlertDialog.show({
        title: '选择失败',
        message: '无法选择图片，请重试',
        confirm: {
          value: '确定',
          action: () => {}
        }
      });
    }
  }

  /**
   * 更新头像设置
   */
  private async updateAvatarSetting(isUserAvatar: boolean, type: 'default' | 'emoji' | 'image', value: string): Promise<void> {
    try {
      // 更新本地状态
      if (isUserAvatar) {
        this.userAvatarType = type;
        this.userAvatarValue = value;
      } else {
        this.aiAvatarType = type;
        this.aiAvatarValue = value;
      }
      
      // 创建新的头像设置对象用于保存
      const newAvatarSettings = new AvatarSettings(
        this.userAvatarType,
        this.userAvatarValue,
        this.aiAvatarType,
        this.aiAvatarValue
      );
      
      // 保存到存储并通知其他组件
      await StorageManager.updateAvatarSettings(newAvatarSettings.toObject());
      
      Logger.info('SideDrawerComponent', `头像设置已更新: ${type} = ${value}`);
    } catch (error) {
      Logger.error('SideDrawerComponent', `更新头像设置失败: ${error}`);
    }
  }
}