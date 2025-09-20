import { AutoTTSSettings, StorageManager } from '../utils/AppStorage';
import { AutoTTSService } from '../services/AutoTTSService';
import { Logger } from '../utils/Logger';

export interface AudioSettingsItem {
  title: string;
  subtitle: string;
  type: 'switch' | 'slider';
  value?: boolean;
  numValue?: number;
  minValue?: number;
  maxValue?: number;
  step?: number;
}

export interface AudioSettings {
  muted: boolean;
  autoPlayOnReceive: boolean;
  speed: number;
  volume: number;
  pitch: number;
  language: string;
}

/**
 * 语音播报设置管理器
 */
export class AudioSettingsSection {
  private autoTTSService: AutoTTSService = AutoTTSService.getInstance();
  private settings: AudioSettings = {
    muted: false,
    autoPlayOnReceive: true,
    speed: 1.0,
    volume: 0.8,
    pitch: 1.0,
    language: 'zh-CN'
  };

  constructor() {
    // 加载默认设置
    this.settings = {
      muted: StorageManager.getDefaultAutoTTSSettings().muted,
      autoPlayOnReceive: StorageManager.getDefaultAutoTTSSettings().autoPlayOnReceive,
      speed: StorageManager.getDefaultAutoTTSSettings().speed,
      volume: StorageManager.getDefaultAutoTTSSettings().volume,
      pitch: StorageManager.getDefaultAutoTTSSettings().pitch,
      language: StorageManager.getDefaultAutoTTSSettings().language
    };
  }

  /**
   * 初始化音频设置
   */
  async initialize(): Promise<void> {
    Logger.info('AudioSettingsSection', '初始化音频设置');

    try {
      // 加载自动播报设置
      const loadedSettings = await StorageManager.getAutoTTSSettings();
      this.settings = {
        muted: loadedSettings.muted,
        autoPlayOnReceive: loadedSettings.autoPlayOnReceive,
        speed: loadedSettings.speed,
        volume: loadedSettings.volume,
        pitch: loadedSettings.pitch,
        language: loadedSettings.language
      };

      Logger.info('AudioSettingsSection', `音频设置加载成功: ${JSON.stringify(this.settings)}`);
    } catch (error) {
      Logger.error('AudioSettingsSection', `加载音频设置失败: ${error}`);
      throw error;
    }
  }

  /**
   * 获取设置项列表
   */
  getSettingsItems(): AudioSettingsItem[] {
    return [
      {
        title: '立刻静音',
        subtitle: this.settings.muted ? '已静音，不会自动播放' : '正常播放模式',
        type: 'switch',
        value: this.settings.muted
      },
      {
        title: '收到回复时播放',
        subtitle: this.settings.autoPlayOnReceive ? '收到AI回复时自动播放' : '需要手动点击播放',
        type: 'switch',
        value: this.settings.autoPlayOnReceive
      },
      {
        title: '语音速度',
        subtitle: this.getSpeedSubtitle(),
        type: 'slider',
        numValue: this.settings.speed,
        minValue: 0.5,
        maxValue: 2.0,
        step: 0.1
      },
      {
        title: '音量大小',
        subtitle: this.getVolumeSubtitle(),
        type: 'slider',
        numValue: this.settings.volume,
        minValue: 0.1,
        maxValue: 1.0,
        step: 0.1
      },
      {
        title: '音调高低',
        subtitle: this.getPitchSubtitle(),
        type: 'slider',
        numValue: this.settings.pitch,
        minValue: 0.5,
        maxValue: 2.0,
        step: 0.1
      }
    ];
  }

  /**
   * 获取速度显示文本
   */
  private getSpeedSubtitle(): string {
    return `当前: ${this.settings.speed.toFixed(1)}x`;
  }

  /**
   * 获取音量显示文本
   */
  private getVolumeSubtitle(): string {
    return `当前: ${Math.round(this.settings.volume * 100)}%`;
  }

  /**
   * 获取音调显示文本
   */
  private getPitchSubtitle(): string {
    return `当前: ${this.settings.pitch.toFixed(1)}`;
  }

  /**
   * 更新自动播报设置
   */
  async updateSetting(key: keyof AudioSettings, value: boolean | number): Promise<void> {
    try {
      const updates: Partial<AutoTTSSettings> = {};

      switch (key) {
        case 'muted':
          if (typeof value === 'boolean') {
            updates.muted = value;
            this.settings.muted = value;
          }
          break;
        case 'autoPlayOnReceive':
          if (typeof value === 'boolean') {
            updates.autoPlayOnReceive = value;
            this.settings.autoPlayOnReceive = value;
          }
          break;
        case 'speed':
          if (typeof value === 'number') {
            updates.speed = value;
            this.settings.speed = value;
          }
          break;
        case 'volume':
          if (typeof value === 'number') {
            updates.volume = value;
            this.settings.volume = value;
          }
          break;
        case 'pitch':
          if (typeof value === 'number') {
            updates.pitch = value;
            this.settings.pitch = value;
          }
          break;
        case 'language':
          if (typeof value === 'string') {
            updates.language = value;
            this.settings.language = value;
          }
          break;
      }

      // 同时更新AppStorage和AutoTTSService
      await StorageManager.updateAutoTTSSettings(updates);
      const serviceSettings = await this.autoTTSService.updateSettings(updates);
      this.settings = { ...serviceSettings };

      Logger.info('AudioSettingsSection', `音频设置已更新: ${key} = ${value}`);
    } catch (error) {
      Logger.error('AudioSettingsSection', `更新音频设置失败: ${error}`);
      throw error;
    }
  }

  /**
   * 切换静音状态
   */
  async toggleMute(): Promise<void> {
    await this.updateSetting('muted', !this.settings.muted);
  }

  /**
   * 切换自动播放状态
   */
  async toggleAutoPlay(): Promise<void> {
    await this.updateSetting('autoPlayOnReceive', !this.settings.autoPlayOnReceive);
  }

  /**
   * 更新语音速度
   */
  async updateSpeed(speed: number): Promise<void> {
    await this.updateSetting('speed', speed);
  }

  /**
   * 更新音量
   */
  async updateVolume(volume: number): Promise<void> {
    await this.updateSetting('volume', volume);
  }

  /**
   * 更新音调
   */
  async updatePitch(pitch: number): Promise<void> {
    await this.updateSetting('pitch', pitch);
  }

  /**
   * 获取当前设置
   */
  getCurrentSettings(): AudioSettings {
    return { ...this.settings };
  }

  /**
   * 获取静音状态
   */
  isMuted(): boolean {
    return this.settings.muted;
  }

  /**
   * 获取自动播放状态
   */
  isAutoPlayEnabled(): boolean {
    return this.settings.autoPlayOnReceive;
  }

  /**
   * 获取语音速度
   */
  getSpeed(): number {
    return this.settings.speed;
  }

  /**
   * 获取音量
   */
  getVolume(): number {
    return this.settings.volume;
  }

  /**
   * 获取音调
   */
  getPitch(): number {
    return this.settings.pitch;
  }

  /**
   * 获取语言
   */
  getLanguage(): string {
    return this.settings.language;
  }

  /**
   * 重置为默认设置
   */
  async resetToDefaults(): Promise<void> {
    const defaults = StorageManager.getDefaultAutoTTSSettings();
    const updates: Partial<AutoTTSSettings> = {
      muted: defaults.muted,
      autoPlayOnReceive: defaults.autoPlayOnReceive,
      speed: defaults.speed,
      volume: defaults.volume,
      pitch: defaults.pitch,
      language: defaults.language
    };

    await this.updateAllSettings(updates);
  }

  /**
   * 更新所有设置
   */
  private async updateAllSettings(updates: Partial<AutoTTSSettings>): Promise<void> {
    try {
      // 更新本地状态
      if (updates.muted !== undefined) this.settings.muted = updates.muted;
      if (updates.autoPlayOnReceive !== undefined) this.settings.autoPlayOnReceive = updates.autoPlayOnReceive;
      if (updates.speed !== undefined) this.settings.speed = updates.speed;
      if (updates.volume !== undefined) this.settings.volume = updates.volume;
      if (updates.pitch !== undefined) this.settings.pitch = updates.pitch;
      if (updates.language !== undefined) this.settings.language = updates.language;

      // 同时更新AppStorage和AutoTTSService
      await StorageManager.updateAutoTTSSettings(updates);
      const serviceSettings = await this.autoTTSService.updateSettings(updates);
      this.settings = { ...serviceSettings };

      Logger.info('AudioSettingsSection', `音频设置已重置为默认值`);
    } catch (error) {
      Logger.error('AudioSettingsSection', `重置音频设置失败: ${error}`);
      throw error;
    }
  }
}