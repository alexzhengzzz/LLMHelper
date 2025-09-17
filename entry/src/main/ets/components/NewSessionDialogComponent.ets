import { SystemPrompt } from '../models/ChatModels';

/**
 * 新会话创建对话框组件
 * 用于在创建新会话时选择系统提示词
 */
@ComponentV2
export struct NewSessionDialogComponent {
  @Param systemPrompts: SystemPrompt[] = [];
  @Param onConfirm: (selectedPrompt: SystemPrompt | null) => void = () => {};
  @Param onCancel: () => void = () => {};
  @Local selectedPrompt: SystemPrompt | null = null;
  @Local searchText: string = '';

  aboutToAppear(): void {
    // 默认选中第一个系统提示词（如果有的话）
    if (this.systemPrompts.length > 0) {
      this.selectedPrompt = this.systemPrompts[0];
    }
  }

  build() {
    Column() {
      // 对话框标题
      Row() {
        Text('创建新会话')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        
        Blank()
        
        // 关闭按钮
        Button() {
          Text('✕')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.onCancel())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 16 })

      // 提示文本
      Text('请选择AI助手角色（系统提示词）')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: 20, right: 20, bottom: 16 })

      // 搜索框
      TextInput({ placeholder: '搜索角色...', text: this.searchText })
        .width('100%')
        .height(40)
        .backgroundColor($r('app.color.input_background'))
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .fontSize(14)
        .margin({ left: 20, right: 20, bottom: 16 })
        .onChange((value: string) => {
          this.searchText = value;
        })

      // 分隔线
      Divider()
        .color($r('app.color.border_color'))
        .height(1)
        .margin({ left: 20, right: 20, bottom: 12 })

      // 系统提示词选择列表
      List({ space: 8 }) {
        // 通用助手选项（无特定角色）
        ListItem() {
          this.buildPromptItem(null, '通用助手', '没有特定角色设定，通用AI助手')
        }

        // 系统提示词列表
        ForEach(this.getFilteredPrompts(), (prompt: SystemPrompt) => {
          ListItem() {
            this.buildPromptItem(prompt, prompt.name, prompt.content.substring(0, 80) + '...')
          }
        }, (prompt: SystemPrompt) => prompt.id)
      }
      .width('100%')
      .height(300)
      .listDirection(Axis.Vertical)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 12, right: 12 })

      Blank()

      // 底部按钮区域
      Row() {
        Button('取消')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .borderWidth(1)
          .borderColor($r('app.color.border_color'))
          .borderRadius(8)
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .onClick(() => this.onCancel())

        Blank()

        Button('确认创建')
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary_color'))
          .borderRadius(8)
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .onClick(() => this.onConfirm(this.selectedPrompt))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 20 })
    }
    .width('90%')
    .constraintSize({ maxWidth: 480 })
    .backgroundColor($r('app.color.surface_color'))
    .borderRadius(16)
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.2)',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  buildPromptItem(prompt: SystemPrompt | null, title: string, description: string) {
    Row() {
      // 选中状态指示器
      Circle({ width: 18, height: 18 })
        .fill(this.isSelected(prompt) ? $r('app.color.primary_color') : Color.Transparent)
        .stroke(this.isSelected(prompt) ? $r('app.color.primary_color') : $r('app.color.border_color'))
        .strokeWidth(2)
        .margin({ right: 12 })

      // 内容区域
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(description)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 4, bottom: 4 })
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.isSelected(prompt) ? 'rgba(66, 133, 244, 0.08)' : Color.Transparent)
    .borderRadius(12)
    .border({
      width: this.isSelected(prompt) ? 2 : 1,
      color: this.isSelected(prompt) ? $r('app.color.primary_color') : $r('app.color.border_color')
    })
    .onClick(() => {
      this.selectedPrompt = prompt;
    })
    .gesture(
      TapGesture()
        .onAction(() => {
          this.selectedPrompt = prompt;
        })
    )
  }

  /**
   * 判断是否为选中状态
   */
  private isSelected(prompt: SystemPrompt | null): boolean {
    if (!this.selectedPrompt && !prompt) {
      return true;
    }
    if (this.selectedPrompt && prompt) {
      return this.selectedPrompt.id === prompt.id;
    }
    return false;
  }

  /**
   * 获取过滤后的系统提示词列表
   */
  private getFilteredPrompts(): SystemPrompt[] {
    if (!this.searchText.trim()) {
      return this.systemPrompts;
    }
    
    const searchLower = this.searchText.toLowerCase();
    return this.systemPrompts.filter(prompt =>
      prompt.name.toLowerCase().includes(searchLower) ||
      prompt.content.toLowerCase().includes(searchLower)
    );
  }
}