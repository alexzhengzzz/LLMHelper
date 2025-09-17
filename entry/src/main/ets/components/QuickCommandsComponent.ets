import { router } from '@kit.ArkUI';
import { Constants, PromptTemplate, PromptCategory } from '../utils/Constants';
import { PromptRecommendationManager } from '../utils/PromptRecommendationManager';

export interface QuickCommand {
  id: string;
  title: string;
  subtitle: string;
  icon: string;
  color: string;
  backgroundColor: string;
  action: () => void;
}

@ComponentV2
export struct QuickCommandsComponent {
  @Param commands: QuickCommand[] = [];
  @Param phrases: [] = [];
  @Param onClose: () => void = () => {};
  @Param onPromptSelected?: (prompt: string) => void = () => {};
  @Local showAnimation: boolean = false;
  @Local searchText: string = '';
  @Local selectedCategory: string = 'all';
  @Local showPrompts: boolean = true;
  @Local showRecommendations: boolean = false;
  
  private promptTemplates: PromptTemplate[] = Constants.PROMPT_TEMPLATES;
  private categories: PromptCategory[] = Constants.PROMPT_CATEGORIES;
  private recommendationManager: PromptRecommendationManager = PromptRecommendationManager.getInstance();
  private scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    // 初始化推荐管理器
    await this.recommendationManager.initialize();
    
    // 延迟显示动画效果
    setTimeout(() => {
      this.showAnimation = true;
    }, 50);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 背景蒙层
      Column() {}
        .width('100%')
        .height('100%')
        .backgroundColor(this.showAnimation ? 'rgba(0, 0, 0, 0.5)' : 'rgba(0, 0, 0, 0.01)')
        .animation({
          duration: 300,
          curve: Curve.FastOutSlowIn
        })
        .onClick(() => {
          this.closePanel();
        })

      // 主面板
      Column({ space: 0 }) {
        // 顶部标题区域
        this.buildHeader()
        
        // 搜索框
        this.buildSearchBox()
        
        // 模式切换
        this.buildModeToggle()
        
        // 分类标签页 (只在Prompt模式显示)
        if (this.showPrompts) {
          this.buildCategoryTabs()
        }
        
        // 内容列表
        this.buildContentList()
      }
      .width('90%')
      .constraintSize({ maxWidth: 450, maxHeight: '80%' })
      .backgroundColor(Color.White)
      .borderRadius(20)
      .clip(true)
      .shadow({
        radius: 20,
        color: 'rgba(0, 0, 0, 0.15)',
        offsetY: 10
      })
      .scale({ x: this.showAnimation ? 1 : 0.8, y: this.showAnimation ? 1 : 0.8 })
      .opacity(this.showAnimation ? 1 : 0)
      .animation({
        duration: 350,
        curve: Curve.FastOutSlowIn
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildHeader() {
    Row() {
      // 标题
      Text(this.showPrompts ? '智能助手' : '快捷指令')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      
      Blank()
      
      // 关闭按钮
      Button() {
        Text('✕')
          .fontSize(16)
          .fontColor('#666666')
      }
      .width(32)
      .height(32)
      .backgroundColor('#F5F5F5')
      .borderRadius(16)
      .onClick(() => {
        this.closePanel();
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 12 })
  }

  @Builder
  buildSearchBox() {
    Row() {
      // 搜索图标
      Text('🔍')
        .fontSize(16)
        .margin({ right: 8 })
      
      // 搜索输入框
      TextInput({ placeholder: '搜索指令...', text: $$this.searchText })
        .layoutWeight(1)
        .height(36)
        .backgroundColor('#F8F9FA')
        .borderRadius(18)
        .padding({ left: 12, right: 12 })
        .border({ width: 0 })
        .placeholderColor('#999999')
        .fontColor('#333333')
        .onChange((value: string) => {
          this.searchText = value;
        })
      
      // 清除按钮
      if (this.searchText.length > 0) {
        Button() {
          Text('✕')
            .fontSize(14)
            .fontColor('#999999')
        }
        .width(28)
        .height(28)
        .backgroundColor('#F0F0F0')
        .borderRadius(14)
        .margin({ left: 8 })
        .onClick(() => {
          this.searchText = '';
        })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 12 })
  }

  @Builder
  buildModeToggle() {
    Row() {
      // 智能推荐
      Button() {
        Row({ space: 4 }) {
          Text('🔥')
            .fontSize(12)
          Text('推荐')
            .fontSize(14)
            .fontColor(this.showRecommendations ? '#FFFFFF' : '#666666')
        }
      }
      .layoutWeight(1)
      .height(36)
      .backgroundColor(this.showRecommendations ? '#FF6B35' : '#F8F9FA')
      .borderRadius(18)
      .margin({ left: 3 })
      .onClick(() => {
        this.showPrompts = true;
        this.showRecommendations = true;
        this.selectedCategory = 'recommendations';
      })

      // AI模板
      Button() {
        Text('AI模板')
          .fontSize(14)
          .fontColor(this.showPrompts && !this.showRecommendations ? '#FFFFFF' : '#666666')
      }
      .layoutWeight(1)
      .height(36)
      .backgroundColor(this.showPrompts && !this.showRecommendations ? '#007AFF' : '#F8F9FA')
      .borderRadius(18)
      .onClick(() => {
        this.showPrompts = true;
        this.showRecommendations = false;
        this.selectedCategory = 'all';
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 12 })
  }

  @Builder
  buildCategoryTabs() {
    Scroll(this.scroller) {
      Row({ space: 8 }) {
        if (this.showRecommendations) {
          // 推荐模式的选项
          Button() {
            Row({ space: 4 }) {
              Text('⭐')
                .fontSize(12)
              Text('智能推荐')
                .fontSize(13)
                .fontColor(this.selectedCategory === 'recommendations' ? '#FFFFFF' : '#666666')
            }
          }
          .height(32)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.selectedCategory === 'recommendations' ? '#FF6B35' : '#F0F0F0')
          .borderRadius(16)
          .onClick(() => {
            this.selectedCategory = 'recommendations';
          })

          Button() {
            Row({ space: 4 }) {
              Text('🕒')
                .fontSize(12)
              Text('最近使用')
                .fontSize(13)
                .fontColor(this.selectedCategory === 'recent' ? '#FFFFFF' : '#666666')
            }
          }
          .height(32)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.selectedCategory === 'recent' ? '#34C759' : '#F0F0F0')
          .borderRadius(16)
          .onClick(() => {
            this.selectedCategory = 'recent';
          })

          Button() {
            Row({ space: 4 }) {
              Text('🎤')
                .fontSize(12)
              Text('语音常用')
                .fontSize(13)
                .fontColor(this.selectedCategory === 'voice' ? '#FFFFFF' : '#666666')
            }
          }
          .height(32)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.selectedCategory === 'voice' ? '#5856D6' : '#F0F0F0')
          .borderRadius(16)
          .onClick(() => {
            this.selectedCategory = 'voice';
          })
        } else {
          // 全部分类
          Button() {
            Text('全部')
              .fontSize(13)
              .fontColor(this.selectedCategory === 'all' ? '#FFFFFF' : '#666666')
          }
          .height(32)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.selectedCategory === 'all' ? '#007AFF' : '#F0F0F0')
          .borderRadius(16)
          .onClick(() => {
            this.selectedCategory = 'all';
          })
          
          // 各个分类
          ForEach(this.categories, (category: PromptCategory) => {
            Button() {
              Row({ space: 4 }) {
                Text(category.icon)
                  .fontSize(12)
                Text(category.name)
                  .fontSize(13)
                  .fontColor(this.selectedCategory === category.id ? '#FFFFFF' : '#666666')
              }
            }
            .height(32)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.selectedCategory === category.id ? category.color : '#F0F0F0')
            .borderRadius(16)
            .onClick(() => {
              this.selectedCategory = category.id;
            })
          }, (category: PromptCategory) => category.id)
        }
      }
      .padding({ left: 20, right: 20 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  buildContentList() {
    Scroll() {
      Column({ space: 8 }) {
        if (this.showPrompts) {
          // 显示Prompt模板
          ForEach(this.getFilteredPrompts(), (prompt: PromptTemplate, index: number) => {
            this.buildPromptItem(prompt, index)
          }, (prompt: PromptTemplate) => prompt.id)
        } else {
          // 显示快捷命令
          ForEach(this.getFilteredCommands(), (command: QuickCommand, index: number) => {
            this.buildCommandItem(command, index)
          }, (command: QuickCommand) => command.id)
        }
      }
      .align(Alignment.TopStart)
      .justifyContent(FlexAlign.Start)
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .align(Alignment.TopStart)
    .layoutWeight(1)
  }

  @Builder
  buildPromptItem(prompt: PromptTemplate, index: number) {
    Row({ space: 12 }) {
      // 左侧图标区域
      Stack() {
        Circle()
          .width(44)
          .height(44)
          .fill(prompt.backgroundColor)
        
        Text(prompt.icon)
          .fontSize(18)
      }
      
      // 右侧内容区域
      Column({ space: 4 }) {
        Row() {
          // 跑马灯效果显示长标题
          Text(prompt.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
            .textAlign(TextAlign.Start)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
          
          // 分类标签
          Text(prompt.category.name)
            .fontSize(11)
            .fontColor(prompt.category.color)
            .backgroundColor(`${prompt.category.color}20`)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(8)
            .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        
        Text(prompt.description)
          .fontSize(12)
          .fontColor('#666666')
          .textAlign(TextAlign.Start)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      
      // 右侧箭头
      Text('›')
        .fontSize(18)
        .fontColor('#CCCCCC')
    }
    .width('100%')
    .height(68)
    .padding({ left: 12, right: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .border({
      width: 1,
      color: '#F0F0F0'
    })
    .stateStyles({
      normal: {
        .backgroundColor(Color.White)
        .scale({ x: 1, y: 1 })
      },
      pressed: {
        .backgroundColor('#F8F9FA')
        .scale({ x: 0.98, y: 0.98 })
      }
    })
    .animation({
      duration: 150,
      curve: Curve.FastOutSlowIn
    })
    .onClick(() => {
      this.executePrompt(prompt);
    })
  }

  @Builder
  buildCommandItem(command: QuickCommand, index: number) {
    Row({ space: 16 }) {
      // 左侧图标区域
      Stack() {
        Circle()
          .width(48)
          .height(48)
          .fill(command.backgroundColor)
        
        Text(command.icon)
          .fontSize(20)
          .fontColor(command.color)
      }
      
      // 右侧内容区域
      Column({ space: 4 }) {
        Text(command.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .textAlign(TextAlign.Start)
          .width('100%')
        
        Text(command.subtitle)
          .fontSize(13)
          .fontColor('#666666')
          .textAlign(TextAlign.Start)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      
      // 右侧箭头
      Text('›')
        .fontSize(20)
        .fontColor('#CCCCCC')
    }
    .width('100%')
    .height(72)
    .padding({ left: 12, right: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .border({
      width: 1,
      color: '#F0F0F0'
    })
    .margin({ top: index > 0 ? 8 : 0 })
    .stateStyles({
      normal: {
        .backgroundColor(Color.White)
        .scale({ x: 1, y: 1 })
      },
      pressed: {
        .backgroundColor('#F8F9FA')
        .scale({ x: 0.98, y: 0.98 })
      }
    })
    .animation({
      duration: 150,
      curve: Curve.FastOutSlowIn
    })
    .onClick(() => {
      this.executeCommand(command);
    })
  }


  private executeCommand(command: QuickCommand): void {
    // 先关闭面板
    this.closePanel();
    
    // 延迟执行命令，确保关闭动画完成
    setTimeout(() => {
      command.action();
    }, 200);
  }

  private async executePrompt(prompt: PromptTemplate): Promise<void> {
    // 记录使用统计
    await this.recommendationManager.recordPromptUsage(prompt.id, false);
    
    // 先关闭面板
    this.closePanel();
    
    // 延迟执行Prompt选择，确保关闭动画完成
    setTimeout(() => {
      if (this.onPromptSelected) {
        this.onPromptSelected(prompt.prompt);
      }
    }, 200);
  }

  private getFilteredPrompts(): PromptTemplate[] {
    if (this.showRecommendations) {
      return this.getRecommendationPrompts();
    }

    let filtered = this.promptTemplates;
    
    // 按分类过滤
    if (this.selectedCategory !== 'all') {
      filtered = filtered.filter(prompt => prompt.category.id === this.selectedCategory);
    }
    
    // 按搜索文本过滤
    if (this.searchText.length > 0) {
      const searchLower = this.searchText.toLowerCase();
      filtered = filtered.filter(prompt => 
        prompt.title.toLowerCase().includes(searchLower) ||
        prompt.description.toLowerCase().includes(searchLower) ||
        prompt.prompt.toLowerCase().includes(searchLower) ||
        (prompt.voiceTriggers && prompt.voiceTriggers.some(trigger => 
          trigger.toLowerCase().includes(searchLower)
        ))
      );
    }
    
    // 使用频率排序
    return this.recommendationManager.getFrequencyBasedSorting(filtered);
  }

  private getRecommendationPrompts(): PromptTemplate[] {
    switch (this.selectedCategory) {
      case 'recommendations':
        return this.recommendationManager.getPersonalizedRecommendations(8);
      case 'recent':
        return this.recommendationManager.getRecentlyUsedPrompts(6);
      case 'voice':
        return this.recommendationManager.getVoiceBasedRecommendations();
      default:
        return this.recommendationManager.getPersonalizedRecommendations(8);
    }
  }

  private getFilteredCommands(): QuickCommand[] {
    let filtered = this.commands;
    
    // 按搜索文本过滤
    if (this.searchText.length > 0) {
      const searchLower = this.searchText.toLowerCase();
      filtered = filtered.filter(command => 
        command.title.toLowerCase().includes(searchLower) ||
        command.subtitle.toLowerCase().includes(searchLower)
      );
    }
    
    return filtered;
  }


  private closePanel(): void {
    this.showAnimation = false;
    
    // 延迟调用onClose，确保动画完成
    setTimeout(() => {
      this.onClose();
    }, 300);
  }
}