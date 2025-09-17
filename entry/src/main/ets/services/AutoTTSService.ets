import { TTSService, TTSCallbacks } from './TTSService';
import { AppStorage, AutoTTSSettings } from '../utils/AppStorage';
import { Logger } from '../utils/Logger';

/**
 * 播报任务状态枚举
 */
export enum PlaybackState {
  IDLE = 'idle',
  PLAYING = 'playing',
  PAUSED = 'paused',
  STOPPED = 'stopped'
}

/**
 * 播报任务接口
 */
export interface PlaybackTask {
  id: string;
  content: string;
  messageId?: string;
  priority: number;
  timestamp: number;
  retryCount: number;
}

/**
 * 播报事件回调接口
 */
export interface AutoTTSCallbacks {
  onTaskStart?: (task: PlaybackTask) => void;
  onTaskComplete?: (task: PlaybackTask) => void;
  onTaskError?: (task: PlaybackTask, error: Error) => void;
  onQueueEmpty?: () => void;
  onSettingsChanged?: (settings: AutoTTSSettings) => void;
}

/**
 * 自动语音播报服务
 * 管理播报队列，支持自动和手动播报
 */
export class AutoTTSService {
  private static instance: AutoTTSService | null = null;
  private ttsService: TTSService;
  private settings: AutoTTSSettings;
  private playbackQueue: PlaybackTask[] = [];
  private currentTask: PlaybackTask | null = null;
  private currentState: PlaybackState = PlaybackState.IDLE;
  private callbacks: AutoTTSCallbacks = {};
  private isInitialized: boolean = false;
  private processingQueue: boolean = false;
  private maxRetries: number = 2;

  private constructor() {
    this.ttsService = TTSService.getInstance();
    this.settings = AppStorage.getDefaultAutoTTSSettings();
    Logger.info('AutoTTSService', '创建自动语音播报服务实例');
  }

  /**
   * 获取自动播报服务单例
   */
  static getInstance(): AutoTTSService {
    if (AutoTTSService.instance === null) {
      AutoTTSService.instance = new AutoTTSService();
    }
    return AutoTTSService.instance;
  }

  /**
   * 初始化自动播报服务
   */
  async initialize(): Promise<boolean> {
    try {
      Logger.info('AutoTTSService', '开始初始化自动播报服务');
      
      // 初始化TTS引擎
      const ttsInitialized = await this.ttsService.initialize();
      if (!ttsInitialized) {
        Logger.error('AutoTTSService', 'TTS引擎初始化失败');
        return false;
      }

      // 总是重新加载设置，确保状态同步
      await this.loadSettings();

      // 配置TTS引擎
      this.updateTTSConfig();

      
      this.isInitialized = true;
      Logger.info('AutoTTSService', '自动播报服务初始化成功');
      return true;

    } catch (error) {
      Logger.error('AutoTTSService', `初始化失败: ${(error as Error).message}`);
      return false;
    }
  }

  /**
   * 加载播报设置
   */
  private async loadSettings(): Promise<void> {
    try {
      this.settings = await AppStorage.getAutoTTSSettings();
      Logger.info('AutoTTSService', `加载播报设置: ${JSON.stringify(this.settings)}`);
    } catch (error) {
      Logger.error('AutoTTSService', `加载设置失败: ${(error as Error).message}`);
      this.settings = AppStorage.getDefaultAutoTTSSettings();
    }
  }

  /**
   * 更新TTS引擎配置
   */
  private updateTTSConfig(): void {
    this.ttsService.updateConfig({
      language: this.settings.language,
      rate: this.settings.speed,
      volume: this.settings.volume,
      pitch: this.settings.pitch
    });
  }

  
  /**
   * 强制停止TTS播放
   */
  private async forceStopPlayback(): Promise<boolean> {
    Logger.info('AutoTTSService', '强制停止TTS播放');
    
    try {
      // 强制停止TTS引擎
      await this.ttsService.forceStop();
      
      // 重置当前状态
      this.currentState = PlaybackState.STOPPED;
      this.currentTask = null;
      this.processingQueue = false;
      
      Logger.info('AutoTTSService', 'TTS播放强制停止完成');
      return true;
    } catch (error) {
      Logger.error('AutoTTSService', `强制停止TTS播放失败: ${(error as Error).message}`);
      
      // 即使失败也要重置状态
      this.currentState = PlaybackState.STOPPED;
      this.currentTask = null;
      this.processingQueue = false;
      return false;
    }
  }

  /**
   * 强制停止AutoTTS（包括清空队列）
   */
  private async forceStopAutoTTS(): Promise<boolean> {
    Logger.info('AutoTTSService', '强制停止AutoTTS服务');
    
    try {
      // 强制停止当前播放
      await this.forceStopPlayback();
      
      // 清空队列
      this.clearQueue();
      
      Logger.info('AutoTTSService', 'AutoTTS服务强制停止完成');
      return true;
    } catch (error) {
      Logger.error('AutoTTSService', `强制停止AutoTTS服务失败: ${(error as Error).message}`);
      
      // 即使失败也要清理状态
      this.currentState = PlaybackState.IDLE;
      this.currentTask = null;
      this.processingQueue = false;
      this.playbackQueue = [];
      return false;
    }
  }

  /**
   * 设置回调函数
   */
  setCallbacks(callbacks: AutoTTSCallbacks): void {
    this.callbacks = callbacks;
  }

  /**
   * 添加播报任务到队列
   */
  async addPlaybackTask(content: string, messageId?: string, priority: number = 1): Promise<string> {
    if (!this.isInitialized) {
      Logger.warn('AutoTTSService', '服务未初始化，尝试初始化');
      const initialized = await this.initialize();
      if (!initialized) {
        throw new Error('自动播报服务初始化失败');
      }
    }

    // 过滤和处理文本内容
    const processedContent = this.preprocessText(content);
    if (!processedContent || processedContent.trim().length === 0) {
      Logger.warn('AutoTTSService', '文本内容为空或无效，跳过播报');
      return '';
    }

    const task: PlaybackTask = {
      id: Date.now().toString() + Math.random().toString(36).substr(2, 9),
      content: processedContent,
      messageId,
      priority,
      timestamp: Date.now(),
      retryCount: 0
    };

    // 根据优先级插入队列
    this.insertTaskByPriority(task);
    
    Logger.info('AutoTTSService', `添加播报任务: ${task.id} (优先级: ${priority})`);
    Logger.debug('AutoTTSService', `任务内容: ${task.content.substring(0, 50)}...`);
    
    // 自动开始处理队列（如果非静音且启用自动播放）
    if (!this.settings.muted && this.settings.autoPlayOnReceive) {
      await this.processQueue();
    }

    return task.id;
  }

  /**
   * 手动播报消息
   */
  async playMessage(content: string, messageId?: string): Promise<string> {
    Logger.info('AutoTTSService', `手动播报请求: ${messageId || '未知消息'}`);
    
    try {
      // 立即清空所有队列
      this.playbackQueue = [];
      this.currentTask = null;
      this.currentState = PlaybackState.IDLE;
      this.processingQueue = false;

      // 添加高优先级手动播报任务
      const taskId = await this.addPlaybackTask(content, messageId, 10);
      
      // 手动播放无条件处理队列，不受自动播放设置限制
      if (taskId) {
        Logger.info('AutoTTSService', `手动播放任务已添加，立即处理队列: ${taskId}`);
        await this.processQueue();
      }
      
      return taskId;
    } catch (error) {
      Logger.error('AutoTTSService', `手动播报启动失败: ${(error as Error).message}`);
      return '';
    }
  }

  /**
   * 停止播报
   */
  async stopPlayback(): Promise<void> {
    try {
      Logger.info('AutoTTSService', '停止播报');
      
      if (this.currentTask && this.currentState === PlaybackState.PLAYING) {
        await this.ttsService.stop();
      }

      this.currentState = PlaybackState.STOPPED;
      this.currentTask = null;
      this.processingQueue = false;
      
    } catch (error) {
      Logger.error('AutoTTSService', `停止播报失败: ${(error as Error).message}`);
    }
  }

  /**
   * 暂停播报
   */
  async pausePlayback(): Promise<void> {
    try {
      if (this.currentState === PlaybackState.PLAYING) {
        await this.ttsService.pause();
        this.currentState = PlaybackState.PAUSED;
        Logger.info('AutoTTSService', '播报已暂停');
      }
    } catch (error) {
      Logger.error('AutoTTSService', `暂停播报失败: ${(error as Error).message}`);
    }
  }

  /**
   * 恢复播报
   */
  async resumePlayback(): Promise<void> {
    try {
      if (this.currentState === PlaybackState.PAUSED) {
        await this.ttsService.resume();
        this.currentState = PlaybackState.PLAYING;
        Logger.info('AutoTTSService', '播报已恢复');
      }
    } catch (error) {
      Logger.error('AutoTTSService', `恢复播报失败: ${(error as Error).message}`);
    }
  }

  /**
   * 清空播报队列
   */
  clearQueue(): void {
    Logger.info('AutoTTSService', `清空播报队列，清除 ${this.playbackQueue.length} 个任务`);
    this.playbackQueue = [];
  }

  /**
   * 移除特定消息的播报任务
   */
  removeTaskByMessageId(messageId: string): boolean {
    const beforeLength = this.playbackQueue.length;
    this.playbackQueue = this.playbackQueue.filter(task => task.messageId !== messageId);
    const removed = beforeLength > this.playbackQueue.length;
    
    if (removed) {
      Logger.info('AutoTTSService', `移除消息 ${messageId} 的播报任务`);
    }
    
    // 如果当前播放的任务也是这个消息，停止播放
    if (this.currentTask?.messageId === messageId) {
      this.stopPlayback();
    }
    
    return removed;
  }

  /**
   * 更新播报设置
   */
  async updateSettings(updates: Partial<AutoTTSSettings>): Promise<void> {
    try {
      const oldSettings: AutoTTSSettings = {
        muted: this.settings.muted,
        speed: this.settings.speed,
        volume: this.settings.volume,
        pitch: this.settings.pitch,
        language: this.settings.language,
        autoPlayOnReceive: this.settings.autoPlayOnReceive
      };
      
      this.settings = {
        muted: updates.muted !== undefined ? updates.muted : this.settings.muted,
        speed: updates.speed !== undefined ? updates.speed : this.settings.speed,
        volume: updates.volume !== undefined ? updates.volume : this.settings.volume,
        pitch: updates.pitch !== undefined ? updates.pitch : this.settings.pitch,
        language: updates.language !== undefined ? updates.language : this.settings.language,
        autoPlayOnReceive: updates.autoPlayOnReceive !== undefined ? updates.autoPlayOnReceive : this.settings.autoPlayOnReceive
      };
      
      // 保存到存储
      await AppStorage.saveAutoTTSSettings(this.settings);
      
      // 更新TTS配置
      this.updateTTSConfig();
      
      Logger.info('AutoTTSService', `播报设置已更新: ${JSON.stringify(updates)}`);
      
      // 触发设置变更回调
      this.callbacks.onSettingsChanged?.(this.settings);
      
      // 如果开启了静音，立即停止当前播放并清空队列
      if (this.settings.muted && !oldSettings.muted) {
        await this.stopPlayback();
        this.clearQueue();
      }
      
    } catch (error) {
      Logger.error('AutoTTSService', `更新设置失败: ${(error as Error).message}`);
    }
  }

  /**
   * 获取当前设置
   */
  getSettings(): AutoTTSSettings {
    return {
      muted: this.settings.muted,
      speed: this.settings.speed,
      volume: this.settings.volume,
      pitch: this.settings.pitch,
      language: this.settings.language,
      autoPlayOnReceive: this.settings.autoPlayOnReceive
    };
  }

  /**
   * 重新加载设置（用于手动刷新状态）
   */
  async reloadSettings(): Promise<void> {
    await this.loadSettings();
    this.updateTTSConfig();
    Logger.info('AutoTTSService', '设置已重新加载');
  }

  /**
   * 获取当前状态
   */
  getCurrentState(): PlaybackState {
    return this.currentState;
  }

  /**
   * 获取当前任务
   */
  getCurrentTask(): PlaybackTask | null {
    if (this.currentTask) {
      return {
        id: this.currentTask.id,
        content: this.currentTask.content,
        messageId: this.currentTask.messageId,
        priority: this.currentTask.priority,
        timestamp: this.currentTask.timestamp,
        retryCount: this.currentTask.retryCount
      };
    }
    return null;
  }

  /**
   * 获取队列长度
   */
  getQueueLength(): number {
    return this.playbackQueue.length;
  }

  /**
   * 检查是否正在播放
   */
  isPlaying(): boolean {
    return this.currentState === PlaybackState.PLAYING;
  }

  /**
   * 检查是否启用自动播报
   */
  isAutoPlayEnabled(): boolean {
    return !this.settings.muted && this.settings.autoPlayOnReceive;
  }

  /**
   * 预处理文本内容
   */
  private preprocessText(content: string): string {
    if (!content) return '';
    
    let processedText = content.trim();
    
    // 移除代码块（使用```包围的内容）
    processedText = processedText.replace(/```[\s\S]*?```/g, '[代码块]');
    
    // 移除行内代码（使用`包围的内容）
    processedText = processedText.replace(/`[^`]*`/g, '[代码]');
    
    // 移除Markdown链接，保留链接文字
    processedText = processedText.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1');
    
    // 移除HTML标签
    processedText = processedText.replace(/<[^>]*>/g, '');
    
    // 移除多余的空白字符
    processedText = processedText.replace(/\s+/g, ' ');
    
    // 限制文本长度（避免过长的文本）
    const maxLength = 500;
    if (processedText.length > maxLength) {
      processedText = processedText.substring(0, maxLength) + '...';
    }
    
    return processedText.trim();
  }

  /**
   * 根据优先级插入任务
   */
  private insertTaskByPriority(task: PlaybackTask): void {
    // 找到插入位置（按优先级降序）
    let insertIndex = 0;
    for (let i = 0; i < this.playbackQueue.length; i++) {
      if (this.playbackQueue[i].priority < task.priority) {
        insertIndex = i;
        break;
      }
      insertIndex = i + 1;
    }
    
    this.playbackQueue.splice(insertIndex, 0, task);
  }

  /**
   * 处理播报队列
   */
  private async processQueue(): Promise<void> {
    if (this.processingQueue || this.playbackQueue.length === 0) {
      return;
    }

    this.processingQueue = true;
    
    try {
      while (this.playbackQueue.length > 0) {
        const task = this.playbackQueue.shift();
        if (!task) continue;

        // 如果静音，只处理高优先级任务（手动播放任务）
        if (this.settings.muted && task.priority < 10) {
          Logger.info('AutoTTSService', `当前静音，跳过低优先级任务: ${task.id} (优先级: ${task.priority})`);
          break;
        }

        this.currentTask = task;
        this.currentState = PlaybackState.PLAYING;

        Logger.info('AutoTTSService', `开始播报任务: ${task.id}`);
        this.callbacks.onTaskStart?.(task);

        // 设置TTS回调
        const ttsCallbacks: TTSCallbacks = {
          onStart: () => {
            Logger.debug('AutoTTSService', `TTS开始播放: ${task.id}`);
          },
          onComplete: () => {
            Logger.info('AutoTTSService', `任务播报完成: ${task.id}`);
            this.callbacks.onTaskComplete?.(task);
            this.currentTask = null;
            this.currentState = PlaybackState.IDLE;
          },
          onError: (error: Error) => {
            Logger.error('AutoTTSService', `任务播报失败: ${task.id}, 错误: ${error.message}`);
            
            // 重试逻辑
            if (task.retryCount < this.maxRetries) {
              task.retryCount++;
              Logger.info('AutoTTSService', `重试播报任务: ${task.id}, 第 ${task.retryCount} 次重试`);
              this.insertTaskByPriority(task);
            } else {
              Logger.error('AutoTTSService', `任务播报最终失败: ${task.id}`);
              this.callbacks.onTaskError?.(task, error);
            }
            
            this.currentTask = null;
            this.currentState = PlaybackState.IDLE;
          },
          onStop: () => {
            Logger.info('AutoTTSService', `任务播报被停止: ${task.id}`);
            this.currentTask = null;
            this.currentState = PlaybackState.STOPPED;
          }
        };

        // 执行播报
        const success = await this.ttsService.speak(task.content, ttsCallbacks);
        if (!success) {
          // 如果立即失败，触发错误处理
          ttsCallbacks.onError?.(new Error('TTS播放启动失败'));
        } else {
          // 等待播放完成
          await this.waitForTaskCompletion();
        }

        // 检查是否需要停止处理队列（静音时停止）
        if (this.settings.muted) {
          break;
        }
      }

      // 队列处理完成
      if (this.playbackQueue.length === 0) {
        Logger.info('AutoTTSService', '播报队列已空');
        this.callbacks.onQueueEmpty?.();
      }

    } finally {
      this.processingQueue = false;
    }
  }

  /**
   * 等待任务完成
   */
  private async waitForTaskCompletion(): Promise<void> {
    return new Promise((resolve) => {
      const checkInterval = setInterval(() => {
        if (this.currentState === PlaybackState.IDLE || 
            this.currentState === PlaybackState.STOPPED ||
            this.currentTask === null) {
          clearInterval(checkInterval);
          resolve();
        }
      }, 100);
      
      // 设置超时，避免永久等待
      setTimeout(() => {
        clearInterval(checkInterval);
        resolve();
      }, 30000); // 30秒超时
    });
  }

  /**
   * 销毁服务
   */
  async destroy(): Promise<void> {
    try {
      Logger.info('AutoTTSService', '销毁自动播报服务');
      
      // 停止播放和清空队列
      await this.stopPlayback();
      this.clearQueue();
      
      // 清理状态
      this.currentTask = null;
      this.currentState = PlaybackState.IDLE;
      this.callbacks = {};
      this.isInitialized = false;
      
    } catch (error) {
      Logger.error('AutoTTSService', `销毁服务失败: ${(error as Error).message}`);
    }
  }
}