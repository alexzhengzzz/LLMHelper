import { UserProfileManager } from '../utils/UserProfileManager';
import { StorageManager, AvatarSettings } from '../utils/AppStorage';
import { Logger } from '../utils/Logger';

export interface ProfileSettings {
  userName: string;
  userSignature: string;
  userAvatarType: 'default' | 'emoji' | 'image';
  userAvatarValue: string;
  aiAvatarType: 'default' | 'emoji' | 'image';
  aiAvatarValue: string;
}

export interface ProfileSettingsItem {
  title: string;
  subtitle: string;
  type: 'button' | 'avatar';
  avatarType?: 'default' | 'emoji' | 'image';
  avatarValue?: string;
}

/**
 * 个人资料设置管理器
 */
export class ProfileSettingsSection {
  private userProfileManager: UserProfileManager = UserProfileManager.getInstance();
  private settings: ProfileSettings = {
    userName: 'Javis用户',
    userSignature: '让AI成为你的编程伙伴',
    userAvatarType: 'default',
    userAvatarValue: '#4285F4',
    aiAvatarType: 'default',
    aiAvatarValue: '#34A853'
  };

  private avatarListener: (settings: AvatarSettings) => void;
  private userProfileListener: (profile: ProfileSettings) => void;

  constructor() {
    this.avatarListener = (settings: AvatarSettings) => {
      this.updateSettingsFromAvatar(settings);
    };
    this.userProfileListener = (profile: ProfileSettings) => {
      this.updateSettingsFromProfile(profile);
    };
  }

  /**
   * 初始化个人资料设置
   */
  async initialize(): Promise<void> {
    Logger.info('ProfileSettingsSection', '初始化个人资料设置');

    try {
      // 初始化用户资料管理器
      await this.userProfileManager.initialize();
      const currentProfile = this.userProfileManager.getCurrentProfile();
      if (currentProfile) {
        this.settings.userName = currentProfile.userName;
        this.settings.userSignature = currentProfile.userSignature;
        this.settings.userAvatarType = currentProfile.userAvatarType;
        this.settings.userAvatarValue = currentProfile.userAvatarValue;
      }

      // 加载AI头像设置
      const avatarSettings = await StorageManager.getAvatarSettings();
      this.settings.aiAvatarType = avatarSettings.aiAvatarType;
      this.settings.aiAvatarValue = avatarSettings.aiAvatarValue;

      // 添加监听器
      this.userProfileManager.addProfileListener(this.userProfileListener);
      StorageManager.addAvatarListener(this.avatarListener);

      Logger.info('ProfileSettingsSection', '个人资料设置初始化完成');
    } catch (error) {
      Logger.error('ProfileSettingsSection', `初始化失败: ${error}`);
      throw error;
    }
  }

  /**
   * 获取设置项列表
   */
  getSettingsItems(): ProfileSettingsItem[] {
    return [
      {
        title: '个人资料',
        subtitle: `${this.settings.userName} • ${this.settings.userSignature}`,
        type: 'button'
      },
      {
        title: 'AI头像',
        subtitle: this.getAvatarDisplayText(this.settings.aiAvatarType, this.settings.aiAvatarValue),
        type: 'avatar',
        avatarType: this.settings.aiAvatarType,
        avatarValue: this.settings.aiAvatarValue
      }
    ];
  }

  /**
   * 获取头像显示文本
   */
  private getAvatarDisplayText(avatarType: string, avatarValue: string): string {
    switch (avatarType) {
      case 'emoji':
        return `表情符号: ${avatarValue}`;
      case 'image':
        return '自定义图片';
      case 'default':
      default:
        return `默认颜色: ${avatarValue}`;
    }
  }

  /**
   * 更新设置从头像配置
   */
  private updateSettingsFromAvatar(settings: AvatarSettings): void {
    this.settings.aiAvatarType = settings.aiAvatarType;
    this.settings.aiAvatarValue = settings.aiAvatarValue;
  }

  /**
   * 更新设置从用户资料
   */
  private updateSettingsFromProfile(profile: ProfileSettings): void {
    this.settings.userName = profile.userName;
    this.settings.userSignature = profile.userSignature;
    this.settings.userAvatarType = profile.userAvatarType;
    this.settings.userAvatarValue = profile.userAvatarValue;
  }

  /**
   * 更新头像设置
   */
  async updateAvatarSetting(
    isUserAvatar: boolean,
    type: 'default' | 'emoji' | 'image',
    value: string
  ): Promise<void> {
    try {
      // 更新本地状态
      if (isUserAvatar) {
        this.settings.userAvatarType = type;
        this.settings.userAvatarValue = value;
      } else {
        this.settings.aiAvatarType = type;
        this.settings.aiAvatarValue = value;
      }

      // 保存到存储并通知其他组件
      const avatarSettings = new AvatarSettings(
        this.settings.userAvatarType,
        this.settings.userAvatarValue,
        this.settings.aiAvatarType,
        this.settings.aiAvatarValue
      );

      await StorageManager.updateAvatarSettings(avatarSettings.toObject());
      Logger.info('ProfileSettingsSection', `头像设置已更新: ${isUserAvatar ? '用户' : 'AI'} -> ${type}:${value}`);
    } catch (error) {
      Logger.error('ProfileSettingsSection', `更新头像设置失败: ${error}`);
      throw error;
    }
  }

  /**
   * 构建头像预览
   */
  buildAvatarPreview(isUserAvatar: boolean) {
    const avatarType = isUserAvatar ? this.settings.userAvatarType : this.settings.aiAvatarType;
    const avatarValue = isUserAvatar ? this.settings.userAvatarValue : this.settings.aiAvatarValue;

    if (avatarType === 'emoji') {
      return avatarValue;
    } else if (avatarType === 'image') {
      return avatarValue;
    } else {
      return avatarValue;
    }
  }

  /**
   * 重置头像为默认
   */
  async resetAvatar(isUserAvatar: boolean): Promise<void> {
    const defaultColor = isUserAvatar ? '#4285F4' : '#34A853';
    await this.updateAvatarSetting(isUserAvatar, 'default', defaultColor);
  }

  /**
   * 获取当前设置
   */
  getCurrentSettings(): ProfileSettings {
    return { ...this.settings };
  }

  /**
   * 销毁资源
   */
  destroy(): void {
    this.userProfileManager.removeProfileListener(this.userProfileListener);
    StorageManager.removeAvatarListener(this.avatarListener);
  }
}