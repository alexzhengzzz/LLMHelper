import { Provider } from '../models/ChatModels';

interface ModelInfo {
  provider: string;
  model: string;
  displayName: string;
  description: string;
}

interface ProviderGroup {
  provider: Provider;
  models: ModelInfo[];
}

@ComponentV2
export struct ModelSelectorComponent {
  @Param providers: Provider[] = [];
  @Param currentProvider: string = '';
  @Param currentModel: string = '';
  @Param onModelSelected: (provider: string, model: string) => void = () => {};
  @Param onClose: () => void = () => {};
  @Param onConfigureAPIKeys: () => void = () => {};
  @Param onReloadProviders?: () => void = undefined; // 重新加载模型列表的回调
  
  @Local searchText: string = '';
  @Local providerGroups: ProviderGroup[] = [];
  @Local expandedStates: Map<string, boolean> = new Map();

  aboutToAppear(): void {
    this.initializeProviderGroups();
  }

  private initializeProviderGroups(): void {
    this.providerGroups = this.providers.map(provider => {
      // 初始化展开状态：当前选中的厂商或只有2个以下厂商时展开
      const shouldExpand = provider.name === this.currentProvider || this.providers.length <= 2;
      this.expandedStates.set(provider.name, shouldExpand);
      
      const group: ProviderGroup = {
        provider,
        models: this.getModelsForProvider(provider)
      };
      return group;
    });
  }

  private getModelsForProvider(provider: Provider): ModelInfo[] {
    return provider.models.map(model => {
      const modelInfo: ModelInfo = {
        provider: provider.name,
        model,
        displayName: this.getDisplayName(model),
        description: this.getModelDescription(provider.name, model)
      };
      return modelInfo;
    });
  }

  private getDisplayName(model: string): string {
    if (model.includes('/')) {
      return model.split('/').pop() || model;
    }
    return model;
  }

  private getModelDescription(provider: string, model: string): string {
    if (model.includes('Qwen')) {
      return '通义千问 - 阿里巴巴大语言模型';
    } else if (model.includes('Claude')) {
      return 'Claude - Anthropic AI助手';
    } else if (model.includes('DeepSeek')) {
      return 'DeepSeek - 深度求索AI模型';
    } else if (model.includes('GPT')) {
      return 'GPT - OpenAI语言模型';
    // } else if (model.includes('gemma')) {
    //   return 'Gemma - Google开源模型';
    } else if (model.includes('ChatGLM')) {
      return 'ChatGLM - 智谱AI对话模型';
    }
    return '多功能AI语言模型';
  }


  private getFilteredGroups(): ProviderGroup[] {
    if (!this.searchText.trim()) {
      return this.providerGroups;
    }
    
    const searchLower = this.searchText.toLowerCase();
    return this.providerGroups.map(group => {
      const filteredGroup: ProviderGroup = {
        provider: group.provider,
        models: group.models.filter(model =>
          model.displayName.toLowerCase().includes(searchLower) ||
          model.description.toLowerCase().includes(searchLower)
        )
      };
      return filteredGroup;
    }).filter(group => group.models.length > 0);
  }

  private toggleGroup(providerName: string): void {
    const currentState = this.expandedStates.get(providerName) || false;
    this.expandedStates.set(providerName, !currentState);
    // 触发UI更新
    this.expandedStates = new Map(this.expandedStates);
  }

  private isGroupExpanded(providerName: string): boolean {
    return this.expandedStates.get(providerName) || false;
  }

  private selectModel(provider: string, model: string): void {
    this.onModelSelected(provider, model);
    this.onClose();
  }

  private isCurrentModel(provider: string, model: string): boolean {
    return this.currentProvider === provider && this.currentModel === model;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('选择AI模型')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        
        Blank()
        
        // API密钥配置按钮
        Button() {
          Text('🔑')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .margin({ right: 8 })
        .onClick(() => {
          this.onConfigureAPIKeys();
        })
        
        Button() {
          Text('×')
            .fontSize(20)
            .fontColor($r('app.color.text_secondary'))
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.onClose())
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.surface_color'))
      .borderRadius({ topLeft: 16, topRight: 16 })

      // 搜索框
      Row() {
        TextInput({ placeholder: '搜索模型...', text: this.searchText })
          .layoutWeight(1)
          .height(40)
          .backgroundColor($r('app.color.input_background'))
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .fontSize(14)
          .onChange((value: string) => {
            this.searchText = value;
          })
        
        if (this.searchText) {
          Button() {
            Text('×')
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
          }
          .width(32)
          .height(32)
          .backgroundColor(Color.Transparent)
          .margin({ left: 8 })
          .onClick(() => {
            this.searchText = '';
          })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.surface_color'))

      Divider()
        .color($r('app.color.border_color'))
        .height(1)

      // 模型列表
      if (this.getFilteredGroups().length === 0) {
        // 空状态显示
        Column() {
          Column() {
            Text('🔑')
              .fontSize(48)
              .margin({ bottom: 16 })
            
            Text('无可用模型')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 8 })
            
            Text('请先在设置中配置API密钥')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .margin({ bottom: 16 })
            
            // 按钮组
            Row({ space: 12 }) {
              Button() {
                Text('配置API密钥')
                  .fontSize(14)
                  .fontColor(Color.White)
              }
              .width(120)
              .height(40)
              .backgroundColor($r('app.color.primary_color'))
              .borderRadius(20)
              .onClick(() => {
                this.onConfigureAPIKeys();
                this.onClose();
              })
              
              // 重新加载按钮（仅在有回调时显示）
              if (this.onReloadProviders) {
                Button() {
                  Text('重新加载')
                    .fontSize(14)
                    .fontColor($r('app.color.primary_color'))
                }
                .width(100)
                .height(40)
                .backgroundColor(Color.Transparent)
                .border({ width: 1, color: $r('app.color.primary_color') })
                .borderRadius(20)
                .onClick(() => {
                  if (this.onReloadProviders) {
                    this.onReloadProviders();
                  }
                })
              }
            }
          }
          .width('100%')
          .padding(20)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('app.color.background_color'))
        .justifyContent(FlexAlign.Center)
      } else {
        // 正常模型列表
        List({ space: 0 }) {
          ForEach(this.getFilteredGroups(), (group: ProviderGroup) => {
            ListItemGroup() {
              // 厂商标题
              ListItem() {
                Row() {
                  // 厂商图标
                  Circle({ width: 28, height: 28 })
                    .fill(this.getProviderColor(group.provider.name))
                    .margin({ right: 12 })
                  
                  Column({ space: 2 }) {
                    Text(this.getProviderDisplayName(group.provider.name))
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                    
                    Text(`${group.models.length} 个模型`)
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  
                  Button() {
                    Text(this.isGroupExpanded(group.provider.name) ? '−' : '+')
                      .fontSize(16)
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .width(24)
                  .height(24)
                  .backgroundColor(Color.Transparent)
                }
                .width('100%')
                .height(48)
                .padding({ left: 16, right: 16 })
                .backgroundColor($r('app.color.surface_color'))
                .onClick(() => this.toggleGroup(group.provider.name))
              }

              // 模型列表
              if (this.isGroupExpanded(group.provider.name)) {
                ForEach(group.models, (modelInfo: ModelInfo) => {
                  ListItem() {
                    this.buildModelItem(modelInfo)
                  }
                  .backgroundColor($r('app.color.surface_color'))
                }, (modelInfo: ModelInfo) => `${modelInfo.provider}-${modelInfo.model}`)
              }
            }
          }, (group: ProviderGroup) => group.provider.name)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('app.color.background_color'))
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('75%')
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 32, topRight: 32 })
    .clip(true)
    .shadow({
      radius: 8,
      color: '#40000000',
      offsetY: -2
    })
  }

  @Builder
  buildModelItem(modelInfo: ModelInfo) {
    Row() {
      Column({ space: 4 }) {
        Row() {
          Text(modelInfo.displayName)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          
          if (this.isCurrentModel(modelInfo.provider, modelInfo.model)) {
            Text('当前')
              .fontSize(10)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.primary_color'))
              .borderRadius(8)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .margin({ left: 8 })
          }
        }
        .width('100%')
        
        Text(modelInfo.description)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 44, right: 16, top: 12, bottom: 12 })
    .onClick(() => this.selectModel(modelInfo.provider, modelInfo.model))
  }

  private getProviderColor(provider: string): string {
    switch (provider) {
      case 'siliconflow': return '#4285F4';
      case 'anthropic': return '#FF6B35';
      case 'openai': return '#00A67E';
      // case 'google': return '#EA4335';
      case 'zhipu': return '#5856D6';
      default: return '#666666';
    }
  }

  private getProviderDisplayName(provider: string): string {
    switch (provider) {
      case 'siliconflow': return '硅基流动';
      case 'anthropic': return 'Anthropic';
      case 'openai': return 'OpenAI';
      // case 'google': return 'Google';
      case 'zhipu': return '智谱AI';
      default: return provider;
    }
  }
}