import { SystemPrompt } from '../models/ChatModels';
import { router } from '@kit.ArkUI';

/**
 * 系统提示词选择组件
 */
@ComponentV2
export struct SystemPromptComponent {
  @Param prompts: SystemPrompt[] = [];
  @Param selectedPrompt: SystemPrompt | null = null;
  @Param onPromptSelected: (prompt: SystemPrompt | null) => void = () => {};
  @Param onClose: () => void = () => {};
  
  @Local searchText: string = '';
  @Local filteredPrompts: SystemPrompt[] = [];

  aboutToAppear() {
    // 确保filteredPrompts初始化
    this.filteredPrompts = this.prompts || [];
  }
  
  aboutToRender(): void {
    // 每次渲染时更新filteredPrompts，确保数据同步
    if (!this.searchText.trim()) {
      this.filteredPrompts = this.prompts || [];
    } else {
      this.filterPrompts();
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('选择系统提示词')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        
        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      // 搜索框
      TextInput({ placeholder: '搜索提示词...', text: this.searchText })
        .width('100%')
        .height(40)
        .backgroundColor($r('app.color.input_background'))
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .fontSize(14)
        .onChange((value: string) => {
          this.searchText = value;
          this.filterPrompts();
        })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Divider()
        .color($r('app.color.border_color'))
        .height(1)

      // 提示词列表
      if (this.filteredPrompts.length > 0) {
        List({ space: 8 }) {
          // 无提示词选项
          ListItem() {
            this.buildPromptItem(null)
          }
          
          // 提示词列表
          ForEach(this.filteredPrompts, (prompt: SystemPrompt) => {
            ListItem() {
              this.buildPromptItem(prompt)
            }
          }, (prompt: SystemPrompt) => prompt.id)
        }
        .width('100%')
        .layoutWeight(1)
        .listDirection(Axis.Vertical)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 8, right: 8, top: 8, bottom: 8 })
      } else {
        Column() {
          Text('没有找到匹配的提示词')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      
      // 底部管理按钮
      Button('管理提示词')
        .fontSize(14)
        .fontColor($r('app.color.primary_color'))
        .backgroundColor(Color.Transparent)
        .borderRadius(8)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .margin({ left: 16, right: 16, bottom: 16 })
        .onClick(() => {
          this.onClose();
          // 跳转到管理页面
          setTimeout(() => {
            router.pushUrl({ 
              url: 'pages/SystemPromptManagerPage',
              params: { fromSystemPromptComponent: true }
            });
          }, 100);
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_color'))
  }

  @Builder
  buildPromptItem(prompt: SystemPrompt | null) {
    Row() {
      // 选中状态指示器
      Circle({ width: 16, height: 16 })
        .fill(this.isPromptSelected(prompt) ? $r('app.color.primary_color') : $r('app.color.border_color'))
        .margin({ right: 12 })

      Column() {
        // 名称行
        Text(prompt ? prompt.name : '无提示词')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (prompt) {
          Text(prompt.content)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Start)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 6 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 4, bottom: 4 })
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.isPromptSelected(prompt) ? 'rgba(66, 133, 244, 0.05)' : Color.Transparent)
    .borderRadius(8)
    .border({
      width: this.isPromptSelected(prompt) ? 2 : 1,
      color: this.isPromptSelected(prompt) ? $r('app.color.primary_color') : $r('app.color.border_color')
    })
    .onClick(() => {
      this.onPromptSelected(prompt);
      this.onClose();
    })
  }

  private isPromptSelected(prompt: SystemPrompt | null): boolean {
    if (!this.selectedPrompt && !prompt) {
      return true;
    }
    if (this.selectedPrompt && prompt) {
      return this.selectedPrompt.id === prompt.id;
    }
    return false;
  }

  private filterPrompts(): void {
    if (!this.searchText.trim()) {
      this.filteredPrompts = this.prompts;
      return;
    }

    const searchLower = this.searchText.toLowerCase();
    this.filteredPrompts = this.prompts.filter(prompt => 
      prompt.name.toLowerCase().includes(searchLower) ||
      prompt.content.toLowerCase().includes(searchLower)
    );
  }
}