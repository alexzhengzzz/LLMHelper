# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with the HarmonyOS client code in this repository.

## Quick Start Commands

**Build:**
```bash
# Build HarmonyOS app
./build.sh

# Deploy to device
./deploy.sh
```

**Key Architecture:**
- **Technology**: HarmonyOS app using ArkTS V2 with MVVM architecture
- **Backend API**: Connects to Go server at YOUR_SERVER_IP:8080 (production)
- **Core Services**: 17 service classes handling API, WebSocket, voice, AI logic, MCP tools

# Javis - HarmonyOS AI编程助手客户端

## 项目概述
Javis 是一款基于鸿蒙系统的智能AI编程助手应用，通过集成多个大语言模型API，为开发者提供智能编程辅助、代码生成、问题解答等全方位服务。应用支持语音交互、实时对话、代码执行、联网搜索等现代化功能，旨在提升开发效率和编程体验。

## 技术架构

### HarmonyOS 客户端架构
采用ArkTS V2状态管理和MVVM架构模式，连接到后端API服务。

**核心功能:**
- **智能对话**: 多厂商AI模型支持，实时聊天界面
- **语音交互**: 华为ASR语音识别 + TTS语音合成
- **代码执行**: 通过API调用后端代码执行服务
- **联网搜索**: 集成搜索功能，获取最新信息
- **深度思考**: 自适应推理链路（规划/分析/（预留）检索/推演/验证/整合/复盘），离线执行，分步可视化+质量复盘

**后端API连接:**
- **生产环境**: `YOUR_SERVER_IP:8080`
- **主要接口**: `/api/chat`, `/api/execute`, `/api/search`
- **实时通信**: WebSocket支持流式响应
- **MCP工具**: 支持Calculator、AppLauncher、WeatherService等本地工具

## 🛠️ 开发工作流

### 构建和部署命令

#### 鸿蒙应用构建
```bash
# 编译.hap文件
./build.sh

# 部署到鸿蒙设备
./deploy.sh
```

## 📁 项目结构

### 鸿蒙应用目录结构
```
entry/src/main/ets/
├── pages/                    # 页面
│   ├── ChatPage.ets                 # 主聊天页面
│   ├── SettingsPage.ets             # 设置页面
│   ├── MCPSettingsPage.ets          # MCP工具设置页面
│   ├── ServerSettingsPage.ets       # 服务器设置页面
│   ├── UserProfileEditPage.ets      # 用户配置编辑页面
│   ├── APIKeyManagerPage.ets        # API密钥管理页面
│   ├── RoleManagerPage.ets          # 角色管理页面
│   └── SystemPromptManagerPage.ets  # 系统提示词管理
├── components/              # UI组件
│   ├── ModelSelectorComponent.ets    # 模型选择器
│   ├── VoiceInputComponent.ets       # 语音输入
│   ├── SideDrawerComponent.ets       # 侧边栏导航
│   ├── SmartTextRenderer.ets         # 智能文本渲染
│   ├── DeepThinkingDialog.ets        # 深度思考对话框
│   ├── QuickCommandsComponent.ets    # 快速命令面板
│   ├── ToolboxComponent.ets          # 工具箱组件
│   ├── SwipeableSessionItemComponent.ets # 滑动会话项
│   ├── SystemPromptComponent.ets     # 系统提示词
│   ├── NewSessionDialogComponent.ets # 新建会话对话框
│   ├── HybridActionComponent.ets     # 混合操作组件
│   ├── MCPToolsComponent.ets         # MCP工具组件
│   ├── RoleCardComponent.ets         # 角色卡片组件
│   ├── RoleViewComponent.ets         # 角色视图组件
│   ├── DeepThinkingIndicator.ets    # 深度思考指示器
│   ├── DeepThinkingStatusCard.ets   # 深度思考状态卡片
│   ├── ThinkingProcessComponent.ets  # 思考过程组件
│   ├── ThinkingProgressComponent.ets # 思考进度组件
│   ├── SearchDetailsDialog.ets       # 搜索详情对话框
│   ├── ToolCallStatusComponent.ets  # 工具调用状态组件
│   └── MCPToolTestDialog.ets        # MCP工具测试对话框
├── services/                # 服务层
│   ├── APIManager.ets               # API管理器 (双API模式支持)
│   ├── WebSocketService.ets         # WebSocket服务
│   ├── SpeechRecognitionService.ets # 语音识别服务
│   ├── TTSService.ets               # TTS语音合成
│   ├── AutoTTSService.ets           # 自动TTS服务
│   ├── DeepThinkingService.ets      # 深度思考服务
│   ├── HybridChatService.ets        # 混合聊天服务
│   ├── MessageEnhancer.ets          # 消息增强服务
│   ├── SearchDecisionEngine.ets     # 搜索决策引擎
│   ├── DirectAPIService.ets         # 直连API服务
│   ├── ApiService.ets               # 基础API服务
│   ├── MCPClientManager.ets         # MCP客户端管理器
│   ├── LocalToolManager.ets         # 本地工具管理器
│   ├── CalculatorTool.ets            # 计算器工具
│   ├── AppLauncherTool.ets          # 应用启动工具
│   ├── AudioCapturer.ets             # 音频捕获
│   └── ContentCompressor.ets        # 内容压缩器
├── clients/                 # API客户端
│   ├── BaseAPIClient.ets            # 基础客户端
│   ├── SiliconFlowClient.ets        # 硅基流动客户端
│   ├── GLMClient.ets                # GLM客户端
│   └── SearchAPIClient.ets          # 搜索API客户端
├── utils/                   # 工具类
│   ├── ThemeManager.ets             # 主题管理器
│   ├── SystemPromptManager.ets      # 系统提示词管理
│   ├── SessionManager.ets           # 会话管理器
│   ├── AppStorage.ets               # 应用存储
│   ├── UserProfileManager.ets       # 用户配置管理
│   ├── Constants.ets                # 常量定义
│   ├── Logger.ets                   # 日志系统
│   ├── AIServiceStateManager.ets    # AI服务状态管理器
│   ├── ErrorManager.ets              # 错误管理器
│   ├── FontManager.ets               # 字体管理器
│   ├── AdaptiveTimeoutManager.ets    # 自适应超时管理器
│   ├── NetworkRequestOptimizer.ets  # 网络请求优化器
│   ├── HTTPConnectionPool.ets       # HTTP连接池
│   ├── RequestDeduplicator.ets      # 请求去重器
│   ├── APIKeyManager.ets            # API密钥管理器
│   ├── ServerConfigManager.ets      # 服务器配置管理器
│   ├── AppConfigManager.ets         # 应用配置管理器
│   ├── PromptRecommendationManager.ets # 提示词推荐管理器
│   └── RoleManager.ets              # 角色管理器
├── animations/              # 动画系统
│   ├── index.ets                    # 动画系统入口
│   └── BasicAnimations.ets          # 基础动画
├── viewmodels/              # 视图模型
│   └── ChatViewModel.ets            # 聊天视图模型
├── models/                  # 数据模型
│   └── ChatModels.ets               # 聊天模型定义
├── types/                   # 类型定义
│   ├── APITypes.ets                 # API类型定义
│   ├── ToolboxTypes.ets             # 工具箱类型定义
│   ├── MCPTypes.ets                 # MCP类型定义
│   ├── APIKeyTypes.ets              # API密钥类型定义
│   ├── ErrorTypes.ets               # 错误类型定义
│   └── AIServiceStateTypes.ets      # AI服务状态类型定义
└── entryability/            # 应用入口
    └── EntryAbility.ets             # 主入口
```


## 🔧 开发规范

### ArkTS开发规范
- **ArkTS V2**: 使用V2状态变量 `@Local` `@Param` 等
- **类型安全**: 禁用any、unknown，禁止ESObject，要定义明确类型
- **MVVM架构**: 分离UI、ViewModel、Model
- **组件化**: 可复用组件开发、统一图标系统
- **日志系统**: 禁止用console，使用统一Logger
- **主题管理**: 统一主题管理器，支持明暗模式

### 工具和服务
- **语音服务**: 华为语音识别API、TTS文本朗读
- **状态管理**: 语音状态、TTS状态、UI状态统一管理
- **网络服务**: 双API模式支持（直连API + 服务端API）
- **数据持久化**: AppStorage系统，支持配置、会话、用户数据管理

## 🚀 核心功能特性

### 智能对话系统
- **多厂商AI模型**: 硅基流动(Qwen、DeepSeek)、Google Gemini、智谱GLM
- **深度思考**: 自适应多轮推理引擎（当前默认离线执行），分步展示+质量复盘
- **联网搜索**: 获取最新信息和技术文档
- **代码执行**: 支持Python、JavaScript、Go、Bash等语言

### 语音交互
- **语音识别**: 华为ASR引擎，实时语音转文字
- **语音合成**: TTS引擎，支持自动播放和手动播放
- **语音动画**: 可视化语音状态反馈

### 用户界面
- **现代化设计**: 侧边栏导航、主题切换、动画系统
- **智能文本渲染**: 支持Markdown、代码高亮、富文本处理
- **交互优化**: 滑动操作、快速命令、工具箱集成

### 系统管理
- **会话管理**: 多会话支持，历史记录持久化
- **系统提示词**: 可自定义AI行为，智能提示词推荐
- **API密钥管理**: 统一密钥管理，支持多厂商配置
- **使用量监控**: API调用统计，每日限制设置

## 🎯 项目特色

### 技术亮点
- **双API模式**: 支持直连API和服务端API两种调用方式
- **完整测试覆盖**: 14个测试文件，151个测试用例，95%功能覆盖
- **动画系统**: 统一动画管理器，60fps性能优化
- **类型安全**: 100%符合ArkTS严格模式，无any类型使用
- **模块化架构**: 高度组件化，便于维护和扩展

### 用户体验
- **语音优先**: 完整的语音交互链路
- **智能提示**: 场景化提示词推荐
- **流畅交互**: 优化的UI性能和响应速度
- **个性化**: 主题切换、头像管理、自定义配置

## 🔮 开发环境配置

### 开发环境要求
- **DevEco Studio**: /Applications/DevEco-Studio.app
- **HarmonyOS SDK**: 5.0.5(17)
- **编译目标**: phone@default
- **签名配置**: debug模式自动签名

### 后端API配置
- **生产环境**: YOUR_SERVER_IP:8080
- **API基础URL**: http://YOUR_SERVER_IP:8080/api
- **WebSocket**: ws://YOUR_SERVER_IP:8080/ws

### 依赖和工具
- **测试框架**: @ohos/hypium (单元测试), @ohos/hamock (模拟框架)
- **构建工具**: hvigor (鸿蒙构建系统)
- **开发语言**: ArkTS V2, TypeScript

## 💡 开发提示

### 常用操作
1 **构建应用**: 使用 `./build.sh` 编译.hap文件
2 **部署到设备**: 使用 `./deploy.sh` 部署到鸿蒙设备
3 **查看日志**: Logger.debug/info/warn/error，禁止使用console

### 关键开发规则
- **路径规范**: 所有文件路径必须是绝对路径，不使用相对路径
- **状态管理**: 严格遵循ArkTS V2状态管理规范，使用@Local、@Param等
- **日志系统**: 禁止使用console，必须使用统一的Logger系统
- **架构模式**: 组件开发遵循MVVM架构模式
- **类型安全**: 100%类型安全，禁用any、unknown、ESObject
- **MCP工具开发**: ArkTS对MCP接入要求极高，所有类型都需要写得非常详细，禁止类型推断依赖
- **测试要求**: 测试文件必须包含完整的边界条件和异常处理测试

### 代码质量要求
- **无注释代码**: 除非明确要求，否则不添加代码注释
- **性能优化**: 硬件加速动画，60fps目标性能
- **内存管理**: 合理的资源释放和内存优化
- **错误处理**: 统一的错误处理机制和用户反馈

### 扩展开发
- 新增AI模型: 在 `clients/` 目录添加新的API客户端
- 新增UI组件: 在 `components/` 目录创建，并添加对应测试
- 新增服务: 在 `services/` 目录实现，遵循现有服务接口规范
- 新增工具类: 在 `utils/` 目录添加，提供通用功能支持

### MCP工具开发指导

**ArkTS严格类型要求**:
项目已实现CalculatorTool和AppLauncherTool作为MCP工具开发范式，ArkTS对MCP接入要求极其严格：

- 禁用any、unknown、ESObject类型
- 所有接口必须明确类型定义（如`CalculatorJSONSchema extends JSONSchema`）
- 参数转换必须使用严格的类型断言（如`args.operation as string`）
- JSON Schema构建需要详细的类型声明（如`Record<string, JSONSchema>`）
- 工具执行器必须严格实现LocalToolExecutor接口
- 错误处理必须遵循ToolCallResult类型规范
- 100%类型安全，无类型推断依赖

**开发模式**:
- **简单工具**: 参考CalculatorTool，无外部依赖，纯计算逻辑
- **复杂工具**: 参考AppLauncherTool，需要系统权限和上下文依赖
- **注册机制**: 在LocalToolManager中注册新工具
- **UI自动生成**: MCPToolsComponent根据JSON Schema自动生成参数表单

详细开发范式请参考：`MCP.md`

## 📊 HarmonyOS客户端统计
- **源代码**: 82个ArkTS文件，约45,589行代码
- **UI组件**: 25个主要组件，支持复杂交互和动画
- **服务层**: 17个服务类，处理API、语音、AI逻辑、MCP工具
- **工具类**: 18个工具管理器，支持存储、主题、配置、网络优化
- **客户端**: 4个API客户端，支持多厂商AI模型调用
- **类型定义**: 6个类型文件，提供完整的类型安全保障
- **代码质量**: 100%类型安全，ArkTS严格模式
