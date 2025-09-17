import apiManagerTest from './APIManagerTest';
import webSocketServiceTest from './WebSocketServiceTest';
import speechServiceTest from './SpeechServiceTest';
import apiServiceTest from './ApiServiceTest';
import deepThinkingServiceTest from './DeepThinkingServiceTest';
import hybridChatServiceTest from './HybridChatServiceTest';
import themeManagerTest from './ThemeManagerTest';
import systemPromptManagerTest from './SystemPromptManagerTest';
import appStorageTest from './AppStorageTest';
import sessionManagerTest from './SessionManagerTest';
import modelSelectorComponentTest from './ModelSelectorComponentTest';
import voiceInputComponentTest from './VoiceInputComponentTest';
import smartTextRendererTest from './SmartTextRendererTest';
import deepThinkingDialogTest from './DeepThinkingDialogTest';
import appConfigManagerTest from './AppConfigManagerTest';
import serverConfigChangeTest from './ServerConfigChangeTest';

export default function() {
  // 执行所有测试套件
  apiManagerTest();
  webSocketServiceTest();
  speechServiceTest();
  apiServiceTest();
  deepThinkingServiceTest();
  hybridChatServiceTest();
  themeManagerTest();
  systemPromptManagerTest();
  appStorageTest();
  sessionManagerTest();
  modelSelectorComponentTest();
  voiceInputComponentTest();
  smartTextRendererTest();
  deepThinkingDialogTest();
  appConfigManagerTest();
  serverConfigChangeTest();
}