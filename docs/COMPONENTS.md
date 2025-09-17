# Javis UI Component Architecture Documentation

## Overview

The Javis UI component system implements a comprehensive, modular architecture for building responsive and interactive user interfaces. This document provides detailed documentation of all UI components, their architecture, usage patterns, and integration guidelines.

## Component Architecture Overview

### Component Hierarchy

```
UI Component System
├── Page Components (Entry Points)
│   ├── ChatPage.ets
│   ├── SettingsPage.ets
│   └── SystemPromptManagerPage.ets
├── Core Components (Reusable UI Elements)
│   ├── Navigation Components
│   │   ├── SideDrawerComponent.ets
│   │   └── ModelSelectorComponent.ets
│   ├── Interaction Components
│   │   ├── VoiceInputComponent.ets
│   │   ├── QuickCommandsComponent.ets
│   │   └── ToolboxComponent.ets
│   ├── Content Components
│   │   ├── SmartTextRenderer.ets
│   │   ├── DeepThinkingDialog.ets
│   │   └── ThinkingProcessComponent.ets
│   ├── Session Components
│   │   ├── SwipeableSessionItemComponent.ets
│   │   └── NewSessionDialogComponent.ets
│   └── Utility Components
│       ├── LoadingComponent.ets
│       ├── SystemPromptComponent.ets
│       └── HybridActionComponent.ets
└── Animation Components (Visual Effects)
    ├── AnimationManager.ets
    ├── BasicAnimations.ets
    └── VoiceAnimations.ets
```

### Component Design Principles

1. **Single Responsibility**: Each component has a single, well-defined purpose
2. **Reusability**: Components are designed to be reusable across different contexts
3. **Composability**: Components can be combined to create complex interfaces
4. **State Management**: Components use ArkTS V2 state management patterns
5. **Event-Driven**: Components communicate through events and callbacks
6. **Performance**: Optimized for 60fps rendering and smooth interactions

## Page Components

### ChatPage

#### Overview

`ChatPage` is the main conversational interface, combining multiple components to provide a complete chat experience with message history, input controls, and navigation.

#### Architecture

```typescript
/**
 * Main chat interface page providing complete conversational experience
 * Integrates message display, input controls, and navigation components
 */
@Entry
@Component
struct ChatPage {
  @Local private chatViewModel: ChatViewModel = new ChatViewModel()
  @Local private isSideDrawerOpen: boolean = false
  @Local private isThinkingDialogOpen: boolean = false
  @Local private isNewSessionDialogOpen: boolean = false

  build() {
    Column() {
      // Header with model selector and theme toggle
      this.Header()

      // Message display area
      this.MessageList()

      // Input area with voice and toolbox
      this.InputArea()

      // Side drawer for navigation
      this.SideDrawer()

      // Deep thinking dialog
      this.DeepThinkingDialog()

      // New session dialog
      this.NewSessionDialog()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder Header() {
    Row() {
      // Menu button for side drawer
      Button({ type: ButtonType.Circle })
        .width(40)
        .height(40)
        .onClick(() => {
          this.isSideDrawerOpen = true
        })

      // Model selector component
      ModelSelectorComponent({
        currentModel: this.chatViewModel.currentModel,
        onModelChange: (model) => {
          this.chatViewModel.setCurrentModel(model)
        }
      })

      Blank()

      // Theme toggle button
      ThemeToggleComponent({
        isDarkMode: this.chatViewModel.isDarkMode,
        onThemeChange: (isDark) => {
          this.chatViewModel.setTheme(isDark)
        }
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.header_background'))
  }

  @Builder MessageList() {
    List({ space: 8 }) {
      ForEach(this.chatViewModel.messages, (message: ChatMessage) => {
        ListItem() {
          MessageItemComponent({
            message: message,
            onAction: (action) => {
              this.handleMessageAction(action, message)
            }
          })
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16 })
  }

  @Builder InputArea() {
    Column() {
      // Quick commands component
      QuickCommandsComponent({
        commands: this.chatViewModel.quickCommands,
        onCommandSelect: (command) => {
          this.handleQuickCommand(command)
        }
      })

      // Voice input and text input
      Row() {
        VoiceInputComponent({
          onSpeechResult: (text) => {
            this.chatViewModel.setInputText(text)
          },
          onStateChanged: (state) => {
            this.chatViewModel.setVoiceState(state)
          }
        })

        TextInput({ placeholder: 'Type your message...' })
          .width('100%')
          .height(40)
          .fontSize(16)
          .backgroundColor($r('app.color.input_background'))
          .onChange((value: string) => {
            this.chatViewModel.setInputText(value)
          })

        ToolboxComponent({
          onToolSelect: (tool) => {
            this.handleToolSelection(tool)
          }
        })
      }
      .width('100%')
      .padding(8)
    }
    .width('100%')
    .backgroundColor($r('app.color.input_area_background'))
  }

  @Builder SideDrawer() {
    SideDrawerComponent({
      isOpen: this.isSideDrawerOpen,
      sessions: this.chatViewModel.sessions,
      activeSessionId: this.chatViewModel.activeSessionId,
      onSessionSelect: (sessionId) => {
        this.chatViewModel.switchSession(sessionId)
        this.isSideDrawerOpen = false
      },
      onNewSession: () => {
        this.isNewSessionDialogOpen = true
        this.isSideDrawerOpen = false
      },
      onSettings: () => {
        this.chatViewModel.navigateToSettings()
        this.isSideDrawerOpen = false
      },
      onClose: () => {
        this.isSideDrawerOpen = false
      }
    })
  }

  @Builder DeepThinkingDialog() {
    DeepThinkingDialog({
      isOpen: this.isThinkingDialogOpen,
      thinkingData: this.chatViewModel.thinkingData,
      onClose: () => {
        this.isThinkingDialogOpen = false
      }
    })
  }

  @Builder NewSessionDialog() {
    NewSessionDialogComponent({
      isOpen: this.isNewSessionDialogOpen,
      onCreateSession: (options) => {
        this.chatViewModel.createSession(options)
        this.isNewSessionDialogOpen = false
      },
      onCancel: () => {
        this.isNewSessionDialogOpen = false
      }
    })
  }

  private handleMessageAction(action: string, message: ChatMessage): void {
    // Handle message actions like copy, edit, delete
  }

  private handleQuickCommand(command: QuickCommand): void {
    this.chatViewModel.setInputText(command.text)
  }

  private handleToolSelection(tool: ToolboxTool): void {
    this.chatViewModel.handleToolSelection(tool)
  }
}
```

#### Key Features

- **Modular Design**: Composed of multiple specialized components
- **State Management**: Uses ChatViewModel for centralized state
- **Responsive Layout**: Adapts to different screen sizes
- **Event Handling**: Comprehensive event management for user interactions
- **Component Integration**: Seamless integration with all sub-components

#### State Management

```typescript
// ChatViewModel manages all page state
@Observed
class ChatViewModel {
  @Local messages: ChatMessage[] = []
  @Local currentModel: string = 'siliconflow.Qwen/Qwen2.5-7B-Instruct'
  @Local isDarkMode: boolean = false
  @Local inputText: string = ''
  @Local voiceState: VoiceState = VoiceState.IDLE
  @Local sessions: ChatSession[] = []
  @Local activeSessionId: string = ''
  @Local quickCommands: QuickCommand[] = []
  @Local thinkingData: ThinkingData | null = null

  // State management methods
  setCurrentModel(model: string): void {
    this.currentModel = model
  }

  setTheme(isDark: boolean): void {
    this.isDarkMode = isDark
    // Update theme manager
  }

  setInputText(text: string): void {
    this.inputText = text
  }

  setVoiceState(state: VoiceState): void {
    this.voiceState = state
  }

  switchSession(sessionId: string): void {
    this.activeSessionId = sessionId
    // Load session messages
  }

  createSession(options: SessionOptions): void {
    // Create new session logic
  }

  handleToolSelection(tool: ToolboxTool): void {
    // Handle tool selection logic
  }
}
```

### SettingsPage

#### Overview

`SettingsPage` provides comprehensive configuration management for the application, including model settings, theme preferences, voice settings, and API key management.

#### Architecture

```typescript
/**
 * Settings page providing comprehensive configuration management
 * Handles model settings, themes, voice configuration, and API management
 */
@Entry
@Component
struct SettingsPage {
  @Local private settingsViewModel: SettingsViewModel = new SettingsViewModel()
  @Local private currentTab: SettingsTab = SettingsTab.GENERAL

  build() {
    Column() {
      // Header with back button
      this.Header()

      // Tab navigation
      this.TabNavigation()

      // Tab content
      this.TabContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder Header() {
    Row() {
      Button({ type: ButtonType.Circle })
        .width(40)
        .height(40)
        .onClick(() => {
          this.settingsViewModel.navigateBack()
        })

      Text('Settings')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ left: 16 })

      Blank()
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.header_background'))
  }

  @Builder TabNavigation() {
    Row() {
      ForEach(this.settingsViewModel.tabs, (tab: SettingsTabInfo) => {
        Button(tab.label)
          .type(ButtonType.Normal)
          .backgroundColor(
            this.currentTab === tab.id ? $r('app.color.primary') : Color.Transparent
          )
          .fontColor(
            this.currentTab === tab.id ? Color.White : $r('app.color.text_primary')
          )
          .onClick(() => {
            this.currentTab = tab.id
          })
      })
    }
    .width('100%')
    .padding(8)
    .backgroundColor($r('app.color.tab_background'))
  }

  @Builder TabContent() {
    Scroll() {
      Column() {
        switch (this.currentTab) {
          case SettingsTab.GENERAL:
            this.GeneralSettings()
            break
          case SettingsTab.MODELS:
            this.ModelSettings()
            break
          case SettingsTab.VOICE:
            this.VoiceSettings()
            break
          case SettingsTab.APPEARANCE:
            this.AppearanceSettings()
            break
          case SettingsTab.API:
            this.APISettings()
            break
          case SettingsTab.ADVANCED:
            this.AdvancedSettings()
            break
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding(16)
  }

  @Builder GeneralSettings() {
    Column() {
      // Language selection
      SettingsItem({
        title: 'Language',
        subtitle: this.settingsViewModel.currentLanguage,
        onClick: () => {
          this.settingsViewModel.showLanguageSelector()
        }
      })

      // Auto-start voice input
      SettingsToggleItem({
        title: 'Auto-start Voice Input',
        isOn: this.settingsViewModel.autoStartVoice,
        onChange: (isOn) => {
          this.settingsViewModel.setAutoStartVoice(isOn)
        }
      })

      // Save conversation history
      SettingsToggleItem({
        title: 'Save Conversation History',
        isOn: this.settingsViewModel.saveHistory,
        onChange: (isOn) => {
          this.settingsViewModel.setSaveHistory(isOn)
        }
      })
    }
    .width('100%')
    .spacing(16)
  }

  @Builder ModelSettings() {
    Column() {
      // Default model selection
      SettingsItem({
        title: 'Default Model',
        subtitle: this.settingsViewModel.defaultModel,
        onClick: () => {
          this.settingsViewModel.showModelSelector()
        }
      })

      // Model parameters
      this.ModelParameterSettings()

      // Model priority
      SettingsItem({
        title: 'Model Priority',
        subtitle: 'Configure model selection priority',
        onClick: () => {
          this.settingsViewModel.showModelPriorityDialog()
        }
      })
    }
    .width('100%')
    .spacing(16)
  }

  @Builder VoiceSettings() {
    Column() {
      // Speech recognition settings
      VoiceRecognitionSettings({
        settings: this.settingsViewModel.voiceRecognitionSettings,
        onSettingsChange: (settings) => {
          this.settingsViewModel.updateVoiceRecognitionSettings(settings)
        }
      })

      // TTS settings
      TTSSettings({
        settings: this.settingsViewModel.ttsSettings,
        onSettingsChange: (settings) => {
          this.settingsViewModel.updateTTSSettings(settings)
        }
      })

      // Auto TTS settings
      SettingsToggleItem({
        title: 'Auto TTS',
        subtitle: 'Automatically read responses',
        isOn: this.settingsViewModel.autoTTS,
        onChange: (isOn) => {
          this.settingsViewModel.setAutoTTS(isOn)
        }
      })
    }
    .width('100%')
    .spacing(16)
  }

  // Additional builders for other tabs...
}
```

#### Key Features

- **Tabbed Interface**: Organized settings with tab navigation
- **Comprehensive Configuration**: Covers all app settings
- **Real-time Updates**: Settings apply immediately
- **Validation**: Input validation and error handling
- **Persistence**: Automatic saving of settings

## Core Components

### ModelSelectorComponent

#### Overview

`ModelSelectorComponent` provides a dropdown interface for selecting AI models, with support for multiple providers and real-time availability checking.

#### Architecture

```typescript
/**
 * AI model selector component with provider grouping and availability indicators
 * Supports model switching, provider selection, and real-time status checking
 */
@Component
export struct ModelSelectorComponent {
  @Prop currentModel: string
  @Prop onModelChange: (model: string) => void
  @Local private isOpen: boolean = false
  @Local private availableModels: ModelInfo[] = []
  @Local private isLoading: boolean = false
  @Local private searchTerm: string = ''

  aboutToAppear() {
    this.loadAvailableModels()
  }

  build() {
    Column() {
      // Current model display
      this.CurrentModelDisplay()

      // Model dropdown
      if (this.isOpen) {
        this.ModelDropdown()
      }
    }
    .width('100%')
  }

  @Builder CurrentModelDisplay() {
    Row() {
      // Model icon and name
      Row() {
        Image(this.getModelIcon(this.currentModel))
          .width(24)
          .height(24)
          .margin({ right: 8 })

        Text(this.getModelDisplayName(this.currentModel))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
      }

      Blank()

      // Status indicator
      if (this.isLoading) {
        LoadingComponent({ size: 16 })
      } else {
        Image($r('app.media.dropdown_arrow'))
          .width(16)
          .height(16)
          .rotate({ angle: this.isOpen ? 180 : 0 })
      }
    }
    .width('100%')
    .height(40)
    .padding(12)
    .backgroundColor($r('app.color.model_selector_background'))
    .borderRadius(8)
    .onClick(() => {
      this.isOpen = !this.isOpen
      if (this.isOpen) {
        this.loadAvailableModels()
      }
    })
  }

  @Builder ModelDropdown() {
    Column() {
      // Search bar
      this.SearchBar()

      // Provider tabs
      this.ProviderTabs()

      // Model list
      this.ModelList()
    }
    .width('100%')
    .maxHeight(400)
    .backgroundColor($r('app.color.dropdown_background'))
    .borderRadius(8)
    .shadow({
      radius: 4,
      color: Color.Gray,
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder SearchBar() {
    Row() {
      Image($r('app.media.search_icon'))
        .width(16)
        .height(16)
        .margin({ right: 8 })

      TextInput({ placeholder: 'Search models...' })
        .width('100%')
        .height(32)
        .fontSize(14)
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => {
          this.searchTerm = value
        })
    }
    .width('100%')
    .padding(8)
    .backgroundColor($r('app.color.search_background'))
    .borderRadius(4)
    .margin(8)
  }

  @Builder ProviderTabs() {
    Scroll() {
      Row() {
        ForEach(this.getProviders(), (provider: string) => {
          Button(provider)
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.selectProvider(provider)
            })
        })
      }
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .padding({ left: 8, right: 8 })
  }

  @Builder ModelList() {
    List({ space: 4 }) {
      ForEach(this.getFilteredModels(), (model: ModelInfo) => {
        ListItem() {
          this.ModelItem(model)
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
    .padding(8)
  }

  @Builder ModelItem(model: ModelInfo) {
    Row() {
      // Model icon and info
      Row() {
        Image(this.getModelIcon(model.id))
          .width(20)
          .height(20)
          .margin({ right: 8 })

        Column() {
          Text(model.name)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)

          Text(model.description)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
      }

      Blank()

      // Status indicator
      if (model.isAvailable) {
        Image($r('app.media.available_icon'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.success'))
      } else {
        Image($r('app.media.unavailable_icon'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.error'))
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(
      this.currentModel === model.id ? $r('app.color.selected_background') : Color.Transparent
    )
    .borderRadius(4)
    .onClick(() => {
      this.selectModel(model)
    })
  }

  private async loadAvailableModels(): Promise<void> {
    this.isLoading = true
    try {
      const apiManager = APIManager.getInstance()
      this.availableModels = await apiManager.getAvailableModels()
    } catch (error) {
      Logger.error('Failed to load models:', error)
    } finally {
      this.isLoading = false
    }
  }

  private selectModel(model: ModelInfo): void {
    this.currentModel = model.id
    this.onModelChange(model.id)
    this.isOpen = false
  }

  private getFilteredModels(): ModelInfo[] {
    if (!this.searchTerm) {
      return this.availableModels
    }

    const searchTerm = this.searchTerm.toLowerCase()
    return this.availableModels.filter(model =>
      model.name.toLowerCase().includes(searchTerm) ||
      model.description.toLowerCase().includes(searchTerm)
    )
  }

  private getProviders(): string[] {
    const providers = new Set<string>()
    this.availableModels.forEach(model => {
      providers.add(model.provider)
    })
    return Array.from(providers)
  }

  private selectProvider(provider: string): void {
    // Filter models by provider
  }

  private getModelIcon(modelId: string): Resource {
    // Return appropriate icon based on model
    return $r('app.media.default_model_icon')
  }

  private getModelDisplayName(modelId: string): string {
    const model = this.availableModels.find(m => m.id === modelId)
    return model?.name || modelId
  }
}
```

#### Key Features

- **Model Grouping**: Organized by provider
- **Real-time Status**: Live availability checking
- **Search Functionality**: Quick model search
- **Provider Filtering**: Filter models by provider
- **Visual Feedback**: Clear status indicators

### VoiceInputComponent

#### Overview

`VoiceInputComponent` provides a comprehensive voice input interface with visual feedback, state management, and integration with speech recognition services.

#### Architecture

```typescript
/**
 * Voice input component with visual feedback and state management
 * Integrates with speech recognition services and provides real-time audio visualization
 */
@Component
export struct VoiceInputComponent {
  @Prop onSpeechResult: (text: string) => void
  @Prop onStateChanged: (state: VoiceState) => void
  @Local private isRecording: boolean = false
  @Local private voiceState: VoiceState = VoiceState.IDLE
  @Local private audioLevel: number = 0
  @Local private interimText: string = ''
  @Local private animationPhase: number = 0

  private speechService: SpeechRecognitionService = SpeechRecognitionService.getInstance()
  private animationTimer: number = 0

  aboutToAppear() {
    this.setupSpeechService()
  }

  aboutToDisappear() {
    this.cleanupSpeechService()
  }

  build() {
    Column() {
      // Voice input button with animations
      this.VoiceButton()

      // Visual feedback overlay
      if (this.isRecording) {
        this.VisualFeedbackOverlay()
      }
    }
    .width(48)
    .height(48)
  }

  @Builder VoiceButton() {
    Button() {
      Image(this.getVoiceButtonIcon())
        .width(24)
        .height(24)
        .fillColor(this.getVoiceButtonColor())
    }
    .width(48)
    .height(48)
    .backgroundColor(
      this.isRecording ? $r('app.color.voice_recording') : $r('app.color.voice_idle')
    )
    .borderRadius(24)
    .onClick(() => {
      this.toggleRecording()
    })
  }

  @Builder VisualFeedbackOverlay() {
    Column() {
      // Audio waveform visualization
      this.AudioWaveform()

      // State indicator
      this.StateIndicator()

      // Interim text display
      if (this.interimText) {
        Text(this.interimText)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 16 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width(200)
    .padding(16)
    .backgroundColor($r('app.color.overlay_background'))
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: Color.Gray,
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder AudioWaveform() {
    Row() {
      ForEach(Array.from({ length: 20 }), (_, index) => {
        Rectangle()
          .width(4)
          .height(this.getWaveformHeight(index))
          .backgroundColor($r('app.color.waveform'))
          .borderRadius(2)
          .animation({
            duration: 100,
            curve: Curve.EaseInOut
          })
      })
    }
    .width('100%')
    .height(40)
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Center)
  }

  @Builder StateIndicator() {
    Row() {
      // State icon
      Image(this.getStateIcon())
        .width(16)
        .height(16)
        .margin({ right: 8 })

      // State text
      Text(this.getStateText())
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))

      // Recording timer
      if (this.isRecording) {
        Text(this.formatRecordingTime())
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .margin({ top: 8 })
  }

  private setupSpeechService(): void {
    this.speechService.on('recognition_started', () => {
      this.onRecordingStarted()
    })

    this.speechService.on('interim_result', (text: string) => {
      this.interimText = text
    })

    this.speechService.on('final_result', (text: string) => {
      this.onSpeechResultReceived(text)
    })

    this.speechService.on('recognition_completed', () => {
      this.onRecordingCompleted()
    })

    this.speechService.on('recognition_error', (error) => {
      this.onRecordingError(error)
    })

    this.speechService.on('volume_changed', (volume: number) => {
      this.audioLevel = volume
    })

    this.speechService.on('state_changed', (state: { oldState: VoiceState, newState: VoiceState }) => {
      this.voiceState = state.newState
      this.onStateChanged(state.newState)
    })
  }

  private cleanupSpeechService(): void {
    if (this.animationTimer) {
      clearInterval(this.animationTimer)
    }
  }

  private async toggleRecording(): Promise<void> {
    if (this.isRecording) {
      await this.stopRecording()
    } else {
      await this.startRecording()
    }
  }

  private async startRecording(): Promise<void> {
    try {
      await this.speechService.startRecognition({
        language: 'zh-CN',
        enablePunctuation: true,
        enablePartialResults: true
      })
      this.isRecording = true
      this.startAnimation()
    } catch (error) {
      Logger.error('Failed to start recording:', error)
      this.onRecordingError(error)
    }
  }

  private async stopRecording(): Promise<void> {
    try {
      await this.speechService.stopRecognition()
      this.isRecording = false
      this.stopAnimation()
    } catch (error) {
      Logger.error('Failed to stop recording:', error)
      this.onRecordingError(error)
    }
  }

  private onRecordingStarted(): void {
    this.isRecording = true
    this.interimText = ''
    this.startAnimation()
  }

  private onSpeechResultReceived(text: string): void {
    this.interimText = ''
    this.onSpeechResult(text)
    this.stopRecording()
  }

  private onRecordingCompleted(): void {
    this.isRecording = false
    this.stopAnimation()
  }

  private onRecordingError(error: any): void {
    this.isRecording = false
    this.stopAnimation()
    Logger.error('Recording error:', error)
  }

  private startAnimation(): void {
    this.animationTimer = setInterval(() => {
      this.animationPhase = (this.animationPhase + 1) % 60
    }, 50)
  }

  private stopAnimation(): void {
    if (this.animationTimer) {
      clearInterval(this.animationTimer)
      this.animationTimer = 0
    }
  }

  private getVoiceButtonIcon(): Resource {
    if (this.isRecording) {
      return $r('app.media.stop_icon')
    } else {
      return $r('app.media.microphone_icon')
    }
  }

  private getVoiceButtonColor(): Color {
    if (this.isRecording) {
      return Color.White
    } else {
      return $r('app.color.icon_primary')
    }
  }

  private getStateIcon(): Resource {
    switch (this.voiceState) {
      case VoiceState.LISTENING:
        return $r('app.media.listening_icon')
      case VoiceState.PROCESSING:
        return $r('app.media.processing_icon')
      case VoiceState.ERROR:
        return $r('app.media.error_icon')
      default:
        return $r('app.media.idle_icon')
    }
  }

  private getStateText(): string {
    switch (this.voiceState) {
      case VoiceState.LISTENING:
        return 'Listening...'
      case VoiceState.PROCESSING:
        return 'Processing...'
      case VoiceState.ERROR:
        return 'Error occurred'
      default:
        return 'Ready'
    }
  }

  private getWaveformHeight(index: number): number {
    const baseHeight = 8
    const amplitude = this.audioLevel * 32
    const phase = this.animationPhase / 60 * Math.PI * 2
    const waveOffset = Math.sin(phase + index * 0.3) * amplitude
    return Math.max(4, baseHeight + waveOffset)
  }

  private formatRecordingTime(): string {
    const elapsed = Math.floor(Date.now() / 1000)
    const minutes = Math.floor(elapsed / 60)
    const seconds = elapsed % 60
    return `${minutes}:${seconds.toString().padStart(2, '0')}`
  }
}
```

#### Key Features

- **Visual Feedback**: Real-time audio waveform and state indicators
- **State Management**: Comprehensive state tracking and transitions
- **Animation Support**: Smooth animations for all interactions
- **Error Handling**: Robust error recovery and user feedback
- **Service Integration**: Seamless integration with speech recognition services

### SmartTextRenderer

#### Overview

`SmartTextRenderer` provides intelligent text rendering with support for Markdown, code syntax highlighting, mathematical expressions, and rich text formatting.

#### Architecture

```typescript
/**
 * Intelligent text renderer with Markdown support and syntax highlighting
 * Handles code blocks, mathematical expressions, and rich text formatting
 */
@Component
export struct SmartTextRenderer {
  @Prop text: string
  @Prop style: TextStyle = {}
  @Local private parsedContent: ParsedContent[] = []
  @Local private isLoading: boolean = false

  aboutToAppear() {
    this.parseContent()
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingComponent({ size: 20 })
      } else {
        ForEach(this.parsedContent, (content: ParsedContent) => {
          this.renderContent(content)
        })
      }
    }
    .width('100%')
  }

  @Builder renderContent(content: ParsedContent) {
    switch (content.type) {
      case 'text':
        this.renderText(content as TextContent)
        break
      case 'code':
        this.renderCode(content as CodeContent)
        break
      case 'markdown':
        this.renderMarkdown(content as MarkdownContent)
        break
      case 'math':
        this.renderMath(content as MathContent)
        break
      case 'link':
        this.renderLink(content as LinkContent)
        break
      default:
        this.renderText(content as TextContent)
    }
  }

  @Builder renderText(content: TextContent) {
    Text(content.text)
      .fontSize(content.style?.fontSize || 14)
      .fontColor(content.style?.fontColor || $r('app.color.text_primary'))
      .fontWeight(content.style?.fontWeight || FontWeight.Normal)
      .fontStyle(content.style?.fontStyle || FontStyle.Normal)
      .textAlign(content.style?.textAlign || TextAlign.Start)
      .lineHeight(content.style?.lineHeight || 1.4)
      .margin(content.style?.margin || { top: 0, bottom: 0 })
  }

  @Builder renderCode(content: CodeContent) {
    Column() {
      // Code header with language and copy button
      this.CodeHeader(content)

      // Code content with syntax highlighting
      this.CodeContent(content)
    }
    .width('100%')
    .backgroundColor($r('app.color.code_background'))
    .borderRadius(8)
    .margin({ top: 8, bottom: 8 })
  }

  @Builder CodeHeader(content: CodeContent) {
    Row() {
      // Language indicator
      Text(content.language || 'code')
        .fontSize(12)
        .fontColor($r('app.color.code_language'))
        .textCase(TextCase.Uppercase)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor($r('app.color.code_language_background'))
        .borderRadius(4)

      Blank()

      // Copy button
      Button({ type: ButtonType.Normal }) {
        Image($r('app.media.copy_icon'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.icon_secondary'))
      }
      .width(32)
      .height(32)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.copyToClipboard(content.code)
      })
    }
    .width('100%')
    .padding(8)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder CodeContent(content: CodeContent) {
    Scroll() {
      Text(this.highlightSyntax(content.code, content.language))
        .fontSize(13)
        .fontFamily('monospace')
        .fontColor($r('app.color.code_text'))
        .lineHeight(1.5)
        .padding(12)
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .backgroundColor($r('app.color.code_content_background'))
    .borderRadius({
      topLeft: 0,
      topRight: 0,
      bottomLeft: 8,
      bottomRight: 8
    })
  }

  @Builder renderMarkdown(content: MarkdownContent) {
    Column() {
      ForEach(content.blocks, (block: MarkdownBlock) => {
        this.renderMarkdownBlock(block)
      })
    }
    .width('100%')
  }

  @Builder renderMarkdownBlock(block: MarkdownBlock) {
    switch (block.type) {
      case 'heading':
        Text(block.text)
          .fontSize(this.getHeadingFontSize(block.level))
          .fontWeight(FontWeight.Bold)
          .margin({ top: 16, bottom: 8 })
        break
      case 'paragraph':
        this.renderText({ text: block.text, style: content.style })
        break
      case 'list':
        this.renderListItem(block)
        break
      case 'blockquote':
        this.renderBlockquote(block)
        break
      case 'table':
        this.renderTable(block)
        break
    }
  }

  @Builder renderMath(content: MathContent) {
    Text(content.latex)
      .fontSize(content.style?.fontSize || 16)
      .fontColor(content.style?.fontColor || $r('app.color.text_primary'))
      .fontFamily('math')
      .margin({ top: 8, bottom: 8 })
  }

  @Builder renderLink(content: LinkContent) {
    Button() {
      Text(content.text)
        .fontSize(content.style?.fontSize || 14)
        .fontColor($r('app.color.link'))
        .textDecoration({ type: TextDecorationType.Underline })
    }
    .type(ButtonType.Normal)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.openLink(content.url)
    })
  }

  private async parseContent(): Promise<void> {
    this.isLoading = true
    try {
      // Parse text and identify different content types
      this.parsedContent = await this.textParser.parse(this.text)
    } catch (error) {
      Logger.error('Failed to parse content:', error)
      // Fallback to plain text
      this.parsedContent = [{
        type: 'text',
        text: this.text,
        style: this.style
      }]
    } finally {
      this.isLoading = false
    }
  }

  private highlightSyntax(code: string, language?: string): string {
    // Implement syntax highlighting based on language
    if (!language) {
      return code
    }

    const syntaxHighlighter = new SyntaxHighlighter()
    return syntaxHighlighter.highlight(code, language)
  }

  private getHeadingFontSize(level: number): number {
    const sizes = [24, 20, 18, 16, 14, 12]
    return sizes[level - 1] || 14
  }

  private async copyToClipboard(text: string): Promise<void> {
    try {
      await this.clipboardService.copy(text)
      // Show toast notification
      this.showToast('Code copied to clipboard')
    } catch (error) {
      Logger.error('Failed to copy to clipboard:', error)
    }
  }

  private openLink(url: string): void {
    // Open link in browser
    this.linkService.open(url)
  }

  private showToast(message: string): void {
    // Show toast notification
    this.toastService.show(message)
  }
}
```

#### Key Features

- **Markdown Support**: Full Markdown parsing and rendering
- **Syntax Highlighting**: Code highlighting for multiple languages
- **Mathematical Expressions**: LaTeX formula rendering
- **Rich Text Formatting**: Bold, italic, links, and more
- **Responsive Layout**: Adapts to different content types and screen sizes

## Session Components

### SwipeableSessionItemComponent

#### Overview

`SwipeableSessionItemComponent` provides a swipeable interface for session management, supporting actions like delete, archive, and share with smooth animations and gesture recognition.

#### Architecture

```typescript
/**
 * Swipeable session item component with gesture recognition and action buttons
 * Supports swipe actions for session management with smooth animations
 */
@Component
export struct SwipeableSessionItemComponent {
  @Prop session: ChatSession
  @Prop isActive: boolean
  @Prop onSessionSelect: (sessionId: string) => void
  @Prop onDelete: (sessionId: string) => void
  @Prop onArchive: (sessionId: string) => void
  @Prop onShare: (sessionId: string) => void
  @Local private offsetX: number = 0
  @Local private isSwiping: boolean = false
  @Local private actionButtons: ActionButton[] = []
  @Local private isDeleting: boolean = false

  aboutToAppear() {
    this.setupActionButtons()
  }

  build() {
    Stack() {
      // Background action buttons
      this.ActionButtons()

      // Main session item
      this.SessionItem()
        .translate({ x: this.offsetX })
        .gesture(
          PanGesture({})
            .onActionStart(() => {
              this.onSwipeStart()
            })
            .onActionUpdate((event: GestureEvent) => {
              this.onSwipeUpdate(event)
            })
            .onActionEnd(() => {
              this.onSwipeEnd()
            })
        )
    }
    .width('100%')
    .height(64)
    .backgroundColor(Color.Transparent)
  }

  @Builder ActionButtons() {
    Row() {
      ForEach(this.actionButtons, (button: ActionButton) => {
        Button() {
          Column() {
            Image(button.icon)
              .width(24)
              .height(24)
              .fillColor(button.color)

            Text(button.label)
              .fontSize(10)
              .fontColor(button.color)
          }
          .alignItems(HorizontalAlign.Center)
        }
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .width(80)
        .height('100%')
        .onClick(() => {
          this.onActionClick(button.action)
        })
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
  }

  @Builder SessionItem() {
    Row() {
      // Session icon
      Image(this.getSessionIcon())
        .width(40)
        .height(40)
        .borderRadius(20)
        .margin({ right: 12 })

      // Session info
      Column() {
        Text(this.session.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text(this.formatDate(this.session.updatedAt))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))

          if (this.session.messageCount > 0) {
            Text(`${this.session.messageCount} messages`)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 8 })
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // Active indicator
      if (this.isActive) {
        Image($r('app.media.active_indicator'))
          .width(8)
          .height(8)
          .backgroundColor($r('app.color.primary'))
          .borderRadius(4)
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor(
      this.isActive ? $r('app.color.session_active_background') : $r('app.color.session_background')
    )
    .borderRadius(8)
    .onClick(() => {
      this.onSessionSelect(this.session.id)
    })
  }

  private setupActionButtons(): void {
    this.actionButtons = [
      {
        action: 'delete',
        label: 'Delete',
        icon: $r('app.media.delete_icon'),
        color: $r('app.color.error')
      },
      {
        action: 'archive',
        label: 'Archive',
        icon: $r('app.media.archive_icon'),
        color: $r('app.color.warning')
      },
      {
        action: 'share',
        label: 'Share',
        icon: $r('app.media.share_icon'),
        color: $r('app.color.success')
      }
    ]
  }

  private onSwipeStart(): void {
    this.isSwiping = true
  }

  private onSwipeUpdate(event: GestureEvent): void {
    if (this.isSwiping) {
      // Limit swipe distance
      this.offsetX = Math.max(-240, Math.min(0, event.offsetX))
    }
  }

  private onSwipeEnd(): void {
    this.isSwiping = false

    // Determine which action to trigger based on swipe distance
    const buttonWidth = 80
    const actionIndex = Math.floor(Math.abs(this.offsetX) / buttonWidth) - 1

    if (actionIndex >= 0 && actionIndex < this.actionButtons.length) {
      const action = this.actionButtons[actionIndex].action
      this.onActionClick(action)
    } else {
      // Animate back to center
      this.animateToCenter()
    }
  }

  private onActionClick(action: string): void {
    switch (action) {
      case 'delete':
        this.deleteSession()
        break
      case 'archive':
        this.onArchive(this.session.id)
        break
      case 'share':
        this.onShare(this.session.id)
        break
    }

    // Reset position
    this.animateToCenter()
  }

  private async deleteSession(): Promise<void> {
    if (this.isDeleting) {
      return
    }

    this.isDeleting = true

    try {
      // Show confirmation dialog
      const confirmed = await this.showDeleteConfirmation()

      if (confirmed) {
        this.onDelete(this.session.id)
      }
    } catch (error) {
      Logger.error('Failed to delete session:', error)
    } finally {
      this.isDeleting = false
    }
  }

  private animateToCenter(): void {
    // Animate back to center position
    animateTo({
      duration: 300,
      curve: Curve.EaseInOut,
      delay: 0,
      iterations: 1,
      playMode: PlayMode.Normal,
      onFinish: () => {
        this.offsetX = 0
      }
    }, () => {
      this.offsetX = 0
    })
  }

  private getSessionIcon(): Resource {
    // Return appropriate icon based on session content
    return $r('app.media.default_session_icon')
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp)
    const now = new Date()
    const diff = now.getTime() - date.getTime()

    if (diff < 60000) { // Less than 1 minute
      return 'Just now'
    } else if (diff < 3600000) { // Less than 1 hour
      return `${Math.floor(diff / 60000)}m ago`
    } else if (diff < 86400000) { // Less than 1 day
      return `${Math.floor(diff / 3600000)}h ago`
    } else {
      return date.toLocaleDateString()
    }
  }

  private async showDeleteConfirmation(): Promise<boolean> {
    // Show confirmation dialog
    return new Promise((resolve) => {
      // Implement dialog logic
      resolve(true)
    })
  }
}
```

#### Key Features

- **Gesture Recognition**: Smooth swipe gesture handling
- **Action Buttons**: Contextual action buttons for session management
- **Animation Support**: Smooth animations for all interactions
- **Visual Feedback**: Clear visual indicators for different states
- **Performance Optimized**: Efficient rendering and gesture handling

## Animation Components

### AnimationManager

#### Overview

`AnimationManager` provides centralized animation management, coordination, and performance optimization for all UI animations in the application.

#### Architecture

```typescript
/**
 * Centralized animation management system for coordinating all UI animations
 * Provides performance optimization, coordination, and animation lifecycle management
 */
export class AnimationManager {
  private static instance: AnimationManager
  private activeAnimations: Map<string, Animation> = new Map()
  private animationQueue: AnimationRequest[] = []
  private isProcessingQueue: boolean = false
  private performanceMonitor: PerformanceMonitor
  private animationConfigs: AnimationConfigs

  private constructor() {
    this.performanceMonitor = new PerformanceMonitor()
    this.animationConfigs = new AnimationConfigs()
    this.initializeAnimationSystem()
  }

  /**
   * Get singleton instance
   */
  static getInstance(): AnimationManager {
    if (!AnimationManager.instance) {
      AnimationManager.instance = new AnimationManager()
    }
    return AnimationManager.instance
  }

  /**
   * Execute animation with performance monitoring
   */
  async executeAnimation(
    animationId: string,
    config: AnimationConfig
  ): Promise<AnimationResult> {
    return new Promise((resolve, reject) => {
      const animationRequest: AnimationRequest = {
        id: animationId,
        config: config,
        resolve: resolve,
        reject: reject,
        timestamp: Date.now()
      }

      this.queueAnimation(animationRequest)
    })
  }

  /**
   * Queue animation for execution
   */
  private queueAnimation(request: AnimationRequest): void {
    this.animationQueue.push(request)

    if (!this.isProcessingQueue) {
      this.processAnimationQueue()
    }
  }

  /**
   * Process animation queue with performance consideration
   */
  private async processAnimationQueue(): Promise<void> {
    if (this.isProcessingQueue || this.animationQueue.length === 0) {
      return
    }

    this.isProcessingQueue = true

    try {
      while (this.animationQueue.length > 0) {
        const request = this.animationQueue.shift()!

        // Check performance before executing
        if (this.performanceMonitor.canExecuteAnimation()) {
          await this.executeSingleAnimation(request)
        } else {
          // Re-queue for later
          this.animationQueue.unshift(request)
          break
        }
      }
    } finally {
      this.isProcessingQueue = false
    }
  }

  /**
   * Execute single animation with error handling
   */
  private async executeSingleAnimation(request: AnimationRequest): Promise<void> {
    try {
      const startTime = this.performanceMonitor.startAnimation(request.id)

      // Create animation instance
      const animation = this.createAnimation(request.config)

      // Store active animation
      this.activeAnimations.set(request.id, animation)

      // Execute animation
      const result = await this.runAnimation(animation, request.config)

      // Performance tracking
      const endTime = this.performanceMonitor.endAnimation(request.id, startTime)

      // Clean up
      this.activeAnimations.delete(request.id)

      // Resolve with result
      request.resolve({
        success: true,
        animationId: request.id,
        duration: endTime - startTime,
        result: result
      })

    } catch (error) {
      Logger.error(`Animation ${request.id} failed:`, error)

      // Clean up on error
      this.activeAnimations.delete(request.id)

      // Reject with error
      request.reject({
        success: false,
        animationId: request.id,
        error: error
      })
    }
  }

  /**
   * Create animation instance based on configuration
   */
  private createAnimation(config: AnimationConfig): Animation {
    switch (config.type) {
      case 'fade':
        return new FadeAnimation(config)
      case 'slide':
        return new SlideAnimation(config)
      case 'scale':
        return new ScaleAnimation(config)
      case 'rotate':
        return new RotateAnimation(config)
      case 'sequence':
        return new SequenceAnimation(config)
      case 'parallel':
        return new ParallelAnimation(config)
      default:
        return new BasicAnimation(config)
    }
  }

  /**
   * Run animation with proper lifecycle management
   */
  private async runAnimation(
    animation: Animation,
    config: AnimationConfig
  ): Promise<AnimationResult> {
    return new Promise((resolve, reject) => {
      try {
        // Pre-animation setup
        animation.setup()

        // Execute animation
        animation.execute()

        // Set up completion handler
        animation.onComplete = () => {
          animation.cleanup()
          resolve({ success: true })
        }

        animation.onError = (error) => {
          animation.cleanup()
          reject(error)
        }

        // Set timeout for animation
        if (config.timeout) {
          setTimeout(() => {
            animation.cancel()
            reject(new Error('Animation timeout'))
          }, config.timeout)
        }

      } catch (error) {
        reject(error)
      }
    })
  }

  /**
   * Cancel animation by ID
   */
  cancelAnimation(animationId: string): void {
    const animation = this.activeAnimations.get(animationId)
    if (animation) {
      animation.cancel()
      this.activeAnimations.delete(animationId)
    }
  }

  /**
   * Cancel all animations
   */
  cancelAllAnimations(): void {
    this.activeAnimations.forEach((animation) => {
      animation.cancel()
    })
    this.activeAnimations.clear()
    this.animationQueue = []
  }

  /**
   * Get active animation count
   */
  getActiveAnimationCount(): number {
    return this.activeAnimations.size
  }

  /**
   * Get animation queue status
   */
  getQueueStatus(): QueueStatus {
    return {
      queueLength: this.animationQueue.length,
      isProcessing: this.isProcessingQueue,
      activeCount: this.activeAnimations.size
    }
  }

  /**
   * Initialize animation system
   */
  private initializeAnimationSystem(): void {
    // Set up performance monitoring
    this.performanceMonitor.startMonitoring()

    // Set up event listeners
    this.setupEventListeners()

    // Initialize animation configurations
    this.animationConfigs.loadDefaultConfigs()
  }

  /**
   * Set up event listeners for system events
   */
  private setupEventListeners(): void {
    // Listen for system events that might affect animations
    this.setupSystemEventListeners()

    // Listen for performance events
    this.setupPerformanceEventListeners()
  }

  /**
   * Clean up animation manager
   */
  destroy(): void {
    this.cancelAllAnimations()
    this.performanceMonitor.stopMonitoring()
  }
}
```

#### Key Features

- **Centralized Management**: Single point of control for all animations
- **Performance Monitoring**: Real-time performance tracking and optimization
- **Animation Queue**: Intelligent queueing system for optimal performance
- **Error Handling**: Comprehensive error handling and recovery
- **Lifecycle Management**: Proper setup, execution, and cleanup of animations

## Component Integration Patterns

### Component Communication

```
Component Communication Patterns:
├── Props and Events (Parent-Child)
│   ├── Data flow down via @Prop
│   ├── Events up via callbacks
│   └── State synchronization
├── Service Integration (Component-Service)
│   ├── Service injection
│   ├── Event subscriptions
│   └── State management
├── Global State (Shared State)
│   ├── AppStorage integration
│   ├── Global events
│   └── State synchronization
└── Component Composition (Complex UI)
    ├── Component nesting
    ├── Layout coordination
    └── Event bubbling
```

### State Management Patterns

```
State Management in Components:
├── Local State (@Local)
│   ├── Component-specific state
│   ├── Temporary UI state
│   └── User input state
├── Prop State (@Prop)
│   ├── Parent-controlled state
│   ├── Configuration data
│   └── Callback functions
├── Global State (AppStorage)
│   ├── Application-wide state
│   ├── Persistent data
│   └── Shared configuration
└── Computed State
    ├── Derived values
    ├── Filtered data
    └── Formatted display
```

### Performance Optimization

```
Component Performance Strategies:
├── Lazy Loading
│   ├── On-demand component creation
│   ├── Lazy data loading
│   └── Resource optimization
├── Memory Management
│   ├── Component lifecycle
│   ├── Resource cleanup
│   └── Memory pressure handling
├── Rendering Optimization
│   ├── Minimal re-renders
│   ├── Virtual scrolling
│   └── Hardware acceleration
└── Animation Performance
    ├── 60fps targeting
    ├── Animation pooling
    └── GPU acceleration
```

## Testing Components

### Component Testing Structure

```typescript
// ModelSelectorComponent.test.ets
import { ModelSelectorComponent } from './ModelSelectorComponent'
import { describe, it, expect } from '@ohos/hypium'

describe('ModelSelectorComponent', () => {
  let component: ModelSelectorComponent

  beforeEach(() => {
    component = new ModelSelectorComponent()
  })

  describe('Model Selection', () => {
    it('should emit model change event when model is selected', async () => {
      const mockCallback = jest.fn()
      component.onModelChange = mockCallback

      await component.selectModel({
        id: 'test-model',
        name: 'Test Model',
        isAvailable: true
      })

      expect(mockCallback).toHaveBeenCalledWith('test-model')
    })

    it('should filter models based on search term', () => {
      component.availableModels = [
        { id: 'model1', name: 'Test Model 1' },
        { id: 'model2', name: 'Example Model 2' }
      ]
      component.searchTerm = 'Test'

      const filtered = component.getFilteredModels()

      expect(filtered).toHaveLength(1)
      expect(filtered[0].id).toBe('model1')
    })
  })

  describe('State Management', () => {
    it('should toggle dropdown state correctly', () => {
      expect(component.isOpen).toBe(false)

      component.toggleDropdown()

      expect(component.isOpen).toBe(true)
    })

    it('should close dropdown when model is selected', async () => {
      component.isOpen = true

      await component.selectModel({
        id: 'test-model',
        name: 'Test Model',
        isAvailable: true
      })

      expect(component.isOpen).toBe(false)
    })
  })
})
```

This comprehensive UI component architecture documentation provides developers with the knowledge needed to understand, use, and extend the Javis component system effectively.