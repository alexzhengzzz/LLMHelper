# Javis - 智能AI编程助手 (HarmonyOS客户端)

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-5.0+-blue.svg)](https://developer.harmonyos.com/)
[![ArkTS](https://img.shields.io/badge/ArkTS-V2-green.svg)](https://developer.harmonyos.com/arkts/)

Javis 是一款基于鸿蒙系统的智能AI编程助手应用，集成多个大语言模型API，为开发者提供智能编程辅助、语音交互、代码执行等功能。

## ✨ 主要功能

- **🤖 多厂商AI模型**: 硅基流动(Qwen、DeepSeek)、Google Gemini、智谱GLM
- **🎤 语音交互**: 华为语音识别 + TTS语音合成
- **💻 代码执行**: Python、JavaScript、Go、Bash等多语言支持  
- **🔍 联网搜索**: 获取最新技术信息
- **🧠 深度思考**: 自适应多轮推理引擎，按需规划“规划→分析→（预留）检索→推演→验证→整合→复盘”链路，现阶段默认离线执行并提供分步可视化与质量复盘
- **🎨 现代化UI**: 侧边栏导航、主题切换、60fps动画

## 🚀 快速开始

### 环境要求
- DevEco Studio 5.0+
- HarmonyOS SDK 5.0.5(17) 
- 支持设备: HarmonyOS 手机/平板

### 构建部署
```bash
# 构建应用
./build.sh

# 部署到设备
./deploy.sh
```

### 配置设置
1. 复制配置模板:
```bash
cp entry/src/main/resources/rawfile/config.json.template entry/src/main/resources/rawfile/config.json
```

2. 编辑 `config.json` 设置服务器地址:
```json
{
  "server": {
    "baseUrl": "http://YOUR_SERVER_IP:8080/api",
    "wsUrl": "ws://YOUR_SERVER_IP:8080/api/ws"
  }
}
```

## 📱 应用特色

### 智能编程助手
- **代码生成**: 根据需求描述快速生成代码
- **调试助手**: 分析错误信息，提供修复建议
- **代码优化**: 重构和优化现有代码
- **技术问答**: 编程概念解释和最佳实践

### 语音优先体验  
- **语音识别**: 华为ASR引擎，高准确率
- **语音合成**: TTS自动朗读，支持多种音色
- **语音动画**: 可视化语音状态反馈
- **免手操作**: 适合移动场景使用

### 现代化界面
- **Material Design**: 符合HarmonyOS设计规范
- **主题切换**: 深色/浅色模式自适应
- **流畅动画**: 60fps硬件加速动画
- **响应式布局**: 适配不同屏幕尺寸

## 🏗️ 技术架构

### 核心技术栈
- **开发语言**: ArkTS V2 + TypeScript
- **架构模式**: MVVM + 组件化
- **状态管理**: @Local、@Param响应式状态
- **UI框架**: ArkUI声明式开发

### 项目结构
```
entry/src/main/ets/
├── pages/                 # 页面组件
│   ├── ChatPage.ets      # 主聊天页面
│   └── SettingsPage.ets  # 设置页面
├── components/           # UI组件 (17个)
│   ├── SideDrawerComponent.ets      # 侧边栏导航
│   ├── VoiceInputComponent.ets      # 语音输入
│   ├── SmartTextRenderer.ets        # 智能文本渲染
│   └── DeepThinkingDialog.ets       # 深度思考对话框
├── services/             # 业务服务 (13个)
│   ├── APIManager.ets               # API管理器
│   ├── WebSocketService.ets         # WebSocket服务
│   ├── SpeechRecognitionService.ets # 语音识别
│   └── DeepThinkingService.ets      # 深度思考服务
├── utils/                # 工具类 (10个)
│   ├── ThemeManager.ets            # 主题管理
│   ├── SessionManager.ets          # 会话管理
│   └── AppStorage.ets              # 数据持久化
└── animations/           # 动画系统 (6个)
    ├── AnimationManager.ets        # 动画管理器
    └── VoiceAnimations.ets         # 语音动画
```

## 🧪 测试和质量

### 测试覆盖
- **测试文件**: 14个完整测试文件
- **测试用例**: 151个测试用例  
- **功能覆盖**: 95%核心功能覆盖
- **代码行数**: ~4,200行测试代码

### 主要测试模块
- **核心服务测试** (6个): API管理、WebSocket、语音服务等
- **UI组件测试** (4个): 模型选择器、语音输入、文本渲染等  
- **数据管理测试** (2个): 应用存储、会话管理
- **工具类测试** (2个): 主题管理、系统提示词

## 📊 性能指标

- **启动时间**: < 3秒冷启动
- **UI响应**: 60fps流畅动画
- **内存占用**: < 200MB运行内存
- **电池优化**: 支持后台节能模式
- **网络优化**: WebSocket长连接，断线重连

## 🔒 安全隐私

- **API密钥**: 本地加密存储，不上传版本控制
- **数据隐私**: 对话记录仅本地存储
- **配置保护**: 敏感配置使用模板系统
- **权限最小化**: 仅申请必要的系统权限

## 🎯 开发规范

### 代码规范
- **类型安全**: 100%符合ArkTS严格模式，禁用any类型
- **组件化**: 高度模块化设计，单一职责原则
- **状态管理**: 遵循ArkTS V2状态管理最佳实践
- **性能优化**: 硬件加速动画，智能缓存机制

### 开发工具
```bash
# 代码格式化
npx prettier --write "**/*.ets"

# 类型检查  
npx tsc --noEmit

# 构建分析
./build.sh --analyze
```

## 📈 项目统计

- **源代码**: 65个ArkTS文件，约28,852行代码
- **UI组件**: 17个主要组件，支持复杂交互
- **业务服务**: 13个服务类，处理API、语音、AI逻辑  
- **工具类**: 10个管理器，支持存储、主题、配置
- **动画系统**: 6个动画模块，60fps性能
- **测试代码**: 14个测试文件，4,200行测试代码

## 🎯 路线图

### 已完成 ✅
- [x] 核心聊天功能和多模型集成
- [x] 语音识别和TTS语音合成
- [x] 深度思考系统和推理展示
- [x] 现代化UI和动画系统  
- [x] 完整测试套件和质量保证
- [x] API密钥管理和配置系统

### 开发中 🚧
- [ ] 插件系统和扩展机制
- [ ] 云端同步和多设备协同
- [ ] 更多AI模型集成
- [ ] 性能优化和内存管理

### 计划中 📋
- [ ] 多语言国际化支持
- [ ] 企业级功能和权限管理
- [ ] 开放API和第三方集成
- [ ] 跨平台支持(Android/iOS)

## 🤝 参与贡献

### 开发环境设置
1. 安装 DevEco Studio 5.0+
2. 配置 HarmonyOS SDK
3. 克隆项目并安装依赖
4. 参考 `CLAUDE.md` 了解详细开发规范

### 贡献流程
1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`) 
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [HarmonyOS](https://developer.harmonyos.com/) - 优秀的开发平台
- [华为语音服务](https://developer.huawei.com/consumer/cn/hms/huawei-speech/) - 语音识别和合成支持
- [ArkTS](https://developer.harmonyos.com/arkts/) - 强大的开发语言
- 所有为项目做出贡献的开发者们

---

**体验智能AI编程的未来！** 🚀

> 如需了解服务端部署和完整系统架构，请参考主项目文档。
