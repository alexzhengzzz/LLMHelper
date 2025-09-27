import { SystemPrompt } from '../models/ChatModels';
import { Logger } from '../utils/Logger';

export type SessionMode = 'single' | 'multi';

export interface NewSessionSelection {
  mode: SessionMode;
  systemPrompt: SystemPrompt | null;
  participants: SystemPrompt[];
}

interface ModeOption {
  value: SessionMode;
  label: string;
}

/**
 * 新会话创建对话框组件
 * 用于在创建新会话时选择系统提示词
 */
@ComponentV2
export struct NewSessionDialogComponent {
  @Param systemPrompts: SystemPrompt[] = [];
  @Param onConfirm: (selection: NewSessionSelection) => void = () => {};
  @Param onCancel: () => void = () => {};
  @Local selectedPrompt: SystemPrompt | null = null;
  @Local searchText: string = '';
  @Local sessionMode: SessionMode = 'single';
  @Local selectedParticipantIds: string[] = [];
  @Local refreshCounter: number = 0; // 用于强制刷新UI
  private readonly modeOptions: ModeOption[] = [
    { value: 'single', label: '单人模式' },
    { value: 'multi', label: '多人模式' }
  ];

  aboutToAppear(): void {
    this.initializeDefaultSelection();
  }

  private initializeDefaultSelection(): void {
    this.sessionMode = 'single';
    this.searchText = '';
    this.selectedParticipantIds = [];
    Logger.debug('NewSessionDialogComponent', `initializeDefaultSelection: ${this.systemPrompts.length} prompts available`);

    // 默认选中第一个系统提示词（如果有的话）
    if (this.systemPrompts.length > 0) {
      this.selectedPrompt = this.systemPrompts[0];
      Logger.debug('NewSessionDialogComponent', `Default selected prompt: ${this.selectedPrompt.name}`);
    } else {
      this.selectedPrompt = null;
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

      // 模式说明
      Text(this.sessionMode === 'single' ? '请选择AI助手角色（系统提示词）' : '请选择要加入的会话参与者')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: 20, right: 20, bottom: 12 })

      // 模式选择切换
      this.buildModeToggle()

      if (this.sessionMode === 'multi') {
        Text('提示：至少选择一个角色参与多人会话，可随时在会话内调整。')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding({ left: 20, right: 20, bottom: 8 })
      }

      // 搜索输入框
      TextInput({ placeholder: this.sessionMode === 'single' ? '搜索提示词或角色' : '搜索角色参与者' })
                .onChange((value: string) => {
          this.searchText = value;
        })
        .width('100%')
        .height(40)
        .backgroundColor($r('app.color.input_background'))
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .margin({ left: 20, right: 20, bottom: 12 })

      // 分隔线
      Divider()
        .color($r('app.color.border_color'))
        .height(1)
        .margin({ left: 20, right: 20, bottom: 12 })

      if (this.sessionMode === 'single') {
        this.buildSingleModeList();
      } else {
        this.buildMultiModeList();
      }

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
          .enabled(this.canConfirm())
          .onClick(() => this.handleConfirm())
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
  buildModeToggle() {
    Row({ space: 12 }) {
      ForEach(this.modeOptions, (option: ModeOption) => {
        Button(option.label)
          .fontSize(14)
          .fontColor(this.sessionMode === option.value ? Color.White : $r('app.color.text_primary'))
          .backgroundColor(this.sessionMode === option.value ? $r('app.color.primary_color') : Color.Transparent)
          .borderRadius(20)
          .padding({ left: 18, right: 18, top: 8, bottom: 8 })
          .borderWidth(1)
          .borderColor(this.sessionMode === option.value ? $r('app.color.primary_color') : $r('app.color.border_color'))
          .onClick(() => this.switchSessionMode(option.value))
      }, (option: ModeOption) => option.value)
    }
    .padding({ left: 20, right: 20, bottom: 12 })
    .width('100%')
  }

  @Builder
  buildSingleModeList() {
    List({ space: 8 }) {
      ListItem() {
        this.buildPromptItem(null, '通用助手', '没有特定角色设定，通用AI助手');
      }

      ForEach(this.getFilteredPrompts(), (prompt: SystemPrompt) => {
        ListItem() {
          this.buildPromptItem(prompt, prompt.name, this.getPromptSummary(prompt));
        }
      }, (prompt: SystemPrompt) => prompt.id)
    }
    .width('100%')
    .height(300)
    .listDirection(Axis.Vertical)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 12, right: 12 })
  }

  @Builder
  buildMultiModeList() {
    if (this.getFilteredParticipants().length === 0) {
      Column() {
        Text('暂无可选角色。您可以先在角色管理中创建角色后再尝试。')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
      }
      .width('100%')
      .height(120)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 8 }) {
        ForEach(this.getFilteredParticipants(), (prompt: SystemPrompt) => {
          ListItem() {
            this.buildParticipantItem(prompt);
          }
        }, (prompt: SystemPrompt) => `${prompt.id}_${this.refreshCounter}`) // 添加refreshCounter强制重新渲染
      }
      .width('100%')
      .height(300)
      .listDirection(Axis.Vertical)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 12, right: 12 })
    }
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

  @Builder
  buildParticipantItem(prompt: SystemPrompt) {
    this.buildParticipantItemInternal(prompt, this.selectedParticipantIds.includes(prompt.id));
  }

  @Builder
  private buildParticipantItemInternal(prompt: SystemPrompt, isSelected: boolean) {

    Row() {
      Stack() {
        Circle({ width: 18, height: 18 })
          .fill(isSelected ? $r('app.color.primary_color') : Color.Transparent)
          .stroke(isSelected ? $r('app.color.primary_color') : $r('app.color.border_color'))
          .strokeWidth(2)

        if (isSelected) {
          Text('✓')
            .fontSize(12)
            .fontColor(Color.White)
        }
      }
      .margin({ right: 12 })

      Column() {
        Text(prompt.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.getPromptSummary(prompt))
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
    .backgroundColor(isSelected ? 'rgba(66, 133, 244, 0.08)' : Color.Transparent)
    .borderRadius(12)
    .border({
      width: isSelected ? 2 : 1,
      color: isSelected ? $r('app.color.primary_color') : $r('app.color.border_color')
    })
    .onClick(() => this.toggleParticipant(prompt))
    .gesture(
      TapGesture()
        .onAction(() => {
          this.toggleParticipant(prompt);
        })
    )
  }

  /**
   * 判断是否为选中状态
   */
  private switchSessionMode(mode: SessionMode): void {
    if (this.sessionMode === mode) {
      return;
    }

    Logger.debug('NewSessionDialogComponent', `switchSessionMode: ${this.sessionMode} -> ${mode}`);
    this.sessionMode = mode;

    if (mode === 'single') {
      if (!this.selectedPrompt && this.systemPrompts.length > 0) {
        this.selectedPrompt = this.systemPrompts[0];
      }
    } else {
      // 切换到多人模式时清除单人选择
      this.selectedPrompt = null;
      this.selectedParticipantIds = [...this.selectedParticipantIds];
      Logger.debug('NewSessionDialogComponent', `Switched to multi mode, cleared single selection`);
    }
  }

  private handleConfirm(): void {
    if (!this.canConfirm()) {
      return;
    }
    this.onConfirm(this.buildSelectionResult());
  }

  private canConfirm(): boolean {
    if (this.sessionMode === 'single') {
      return this.selectedPrompt !== null;
    }
    Logger.debug('NewSessionDialogComponent', `canConfirm: ${this.selectedParticipantIds.length} selected participants`);
    return this.selectedParticipantIds.length > 0;
  }

  private buildSelectionResult(): NewSessionSelection {
    return {
      mode: this.sessionMode,
      systemPrompt: this.sessionMode === 'single' ? this.selectedPrompt : null,
      participants: this.sessionMode === 'multi' ? this.getSelectedParticipants() : []
    };
  }

  private getSelectedParticipants(): SystemPrompt[] {
    if (this.selectedParticipantIds.length === 0) {
      return [];
    }

    const promptMap = new Map<string, SystemPrompt>(this.systemPrompts.map(prompt => [prompt.id, prompt]));
    const result: SystemPrompt[] = [];
    for (const id of this.selectedParticipantIds) {
      const prompt = promptMap.get(id);
      if (prompt) {
        result.push(prompt);
      }
    }
    return result;
  }

  private getPromptSummary(prompt: SystemPrompt): string {
    const descriptionSource = prompt.roleDescription && prompt.roleDescription.trim().length > 0
      ? prompt.roleDescription
      : prompt.content;

    if (!descriptionSource || !descriptionSource.trim()) {
      return '暂无描述';
    }

    const normalized = descriptionSource.trim().replace(/\s+/g, ' ');
    return normalized.length <= 80 ? normalized : normalized.substring(0, 80) + '...';
  }

  private toggleParticipant(prompt: SystemPrompt): void {
    const index = this.selectedParticipantIds.indexOf(prompt.id);
    if (index >= 0) {
      // 移除参与者
      this.selectedParticipantIds.splice(index, 1);
    } else {
      // 添加参与者
      this.selectedParticipantIds.push(prompt.id);
    }
    // 强制更新状态
    this.selectedParticipantIds = [...this.selectedParticipantIds];
    this.refreshCounter++; // 增加刷新计数器强制UI更新
    Logger.debug('NewSessionDialogComponent', `toggleParticipant: ${prompt.name}, selected: ${this.selectedParticipantIds.join(', ')}, refreshCounter: ${this.refreshCounter}`);
  }

  private isParticipantSelected(prompt: SystemPrompt): boolean {
    const selected = this.selectedParticipantIds.includes(prompt.id);
    Logger.debug('NewSessionDialogComponent', `isParticipantSelected: ${prompt.name}, result: ${selected}, allIds: [${this.selectedParticipantIds.join(', ')}]`);
    return selected;
  }

  private getFilteredParticipants(): SystemPrompt[] {
    const roles = this.systemPrompts.filter(prompt => prompt.isRole);
    Logger.debug('NewSessionDialogComponent', `getFilteredParticipants: found ${roles.length} roles`);

    if (!this.searchText.trim()) {
      return roles;
    }

    const searchLower = this.searchText.toLowerCase();
    return roles.filter(prompt =>
      prompt.name.toLowerCase().includes(searchLower) ||
      prompt.content.toLowerCase().includes(searchLower) ||
      (prompt.roleDescription && prompt.roleDescription.toLowerCase().includes(searchLower))
    );
  }

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
      prompt.content.toLowerCase().includes(searchLower) ||
      (prompt.roleDescription && prompt.roleDescription.toLowerCase().includes(searchLower))
    );
  }
}
