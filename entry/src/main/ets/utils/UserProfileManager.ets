import { UserProfile, UserProfileData, AppStorage as StorageManager } from './AppStorage';
import { Logger } from './Logger';

/**
 * 头像信息类
 */
export class AvatarInfo {
  type: 'default' | 'emoji' | 'image';
  value: string;

  constructor(type: 'default' | 'emoji' | 'image', value: string) {
    this.type = type;
    this.value = value;
  }
}

/**
 * 验证结果类
 */
export class ValidationResult {
  valid: boolean;
  errors: string[];

  constructor(valid: boolean, errors: string[]) {
    this.valid = valid;
    this.errors = errors;
  }
}

/**
 * 用户资料管理器
 * 统一管理用户基本资料的读取、更新、验证和同步
 */
export class UserProfileManager {
  private static instance: UserProfileManager | null = null;
  private currentProfile: UserProfile | null = null;
  private initialized: boolean = false;
  private profileListeners: ((profile: UserProfile) => void)[] = [];

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): UserProfileManager {
    if (!UserProfileManager.instance) {
      UserProfileManager.instance = new UserProfileManager();
    }
    return UserProfileManager.instance;
  }

  /**
   * 初始化用户资料管理器
   */
  async initialize(): Promise<void> {
    if (this.initialized) {
      Logger.info('UserProfileManager', '用户资料管理器已初始化');
      return;
    }

    try {
      // 加载用户资料
      this.currentProfile = await StorageManager.getUserProfile();
      Logger.info('UserProfileManager', `用户资料加载成功: ${this.currentProfile.userName}`);

      // 添加存储监听器
      StorageManager.addUserProfileListener((profile: UserProfile) => {
        this.currentProfile = profile;
        this.notifyListeners(profile);
      });

      this.initialized = true;
      Logger.info('UserProfileManager', '用户资料管理器初始化完成');
    } catch (error) {
      Logger.error('UserProfileManager', `初始化失败: ${error}`);
      // 使用默认资料
      this.currentProfile = StorageManager.getDefaultUserProfile();
    }
  }

  /**
   * 获取当前用户资料
   */
  getCurrentProfile(): UserProfile | null {
    return this.currentProfile;
  }

  /**
   * 更新用户名字
   */
  async updateUserName(name: string): Promise<boolean> {
    try {
      // 验证用户名
      if (!UserProfile.validateUserName(name)) {
        Logger.warn('UserProfileManager', `用户名格式不正确: ${name}`);
        return false;
      }

      // 更新用户资料
      await StorageManager.updateUserProfile({ userName: name.trim() });
      Logger.info('UserProfileManager', `用户名更新成功: ${name}`);
      return true;
    } catch (error) {
      Logger.error('UserProfileManager', `更新用户名失败: ${error}`);
      return false;
    }
  }

  /**
   * 更新个性签名
   */
  async updateUserSignature(signature: string): Promise<boolean> {
    try {
      // 验证个性签名
      if (!UserProfile.validateUserSignature(signature)) {
        Logger.warn('UserProfileManager', `个性签名格式不正确: ${signature}`);
        return false;
      }

      // 更新用户资料
      await StorageManager.updateUserProfile({ userSignature: signature });
      Logger.info('UserProfileManager', `个性签名更新成功: ${signature}`);
      return true;
    } catch (error) {
      Logger.error('UserProfileManager', `更新个性签名失败: ${error}`);
      return false;
    }
  }

  /**
   * 更新用户头像
   */
  async updateUserAvatar(avatarType: 'default' | 'emoji' | 'image', avatarValue: string): Promise<boolean> {
    try {
      // 更新用户资料中的头像信息
      await StorageManager.updateUserProfile({ 
        userAvatarType: avatarType, 
        userAvatarValue: avatarValue 
      });
      Logger.info('UserProfileManager', `用户头像更新成功: ${avatarType} - ${avatarValue}`);
      return true;
    } catch (error) {
      Logger.error('UserProfileManager', `更新用户头像失败: ${error}`);
      return false;
    }
  }

  /**
   * 批量更新用户资料
   */
  async updateProfile(updates: Partial<UserProfileData>): Promise<boolean> {
    try {
      // 验证各个字段
      if (updates.userName !== undefined && !UserProfile.validateUserName(updates.userName)) {
        Logger.warn('UserProfileManager', `用户名格式不正确: ${updates.userName}`);
        return false;
      }

      if (updates.userSignature !== undefined && !UserProfile.validateUserSignature(updates.userSignature)) {
        Logger.warn('UserProfileManager', `个性签名格式不正确: ${updates.userSignature}`);
        return false;
      }

      // 处理用户名的去除空格
      if (updates.userName !== undefined) {
        updates.userName = updates.userName.trim();
      }

      // 更新用户资料
      await StorageManager.updateUserProfile(updates);
      Logger.info('UserProfileManager', '用户资料批量更新成功');
      return true;
    } catch (error) {
      Logger.error('UserProfileManager', `批量更新用户资料失败: ${error}`);
      return false;
    }
  }

  /**
   * 重置用户资料为默认值
   */
  async resetProfile(): Promise<void> {
    try {
      await StorageManager.resetUserProfile();
      Logger.info('UserProfileManager', '用户资料已重置为默认值');
    } catch (error) {
      Logger.error('UserProfileManager', `重置用户资料失败: ${error}`);
    }
  }

  /**
   * 获取用户显示名称（用于UI显示）
   */
  getDisplayName(): string {
    if (!this.currentProfile || !this.currentProfile.userName.trim()) {
      return 'Javis用户';
    }
    return this.currentProfile.userName;
  }

  /**
   * 获取用户显示签名（用于UI显示）
   */
  getDisplaySignature(): string {
    if (!this.currentProfile || !this.currentProfile.userSignature.trim()) {
      return '让AI成为你的编程伙伴';
    }
    return this.currentProfile.userSignature;
  }

  /**
   * 获取用户头像信息
   */
  getUserAvatar(): AvatarInfo {
    if (!this.currentProfile) {
      return new AvatarInfo('default', '#4285F4');
    }
    return new AvatarInfo(this.currentProfile.userAvatarType, this.currentProfile.userAvatarValue);
  }

  /**
   * 验证用户输入的完整性
   */
  validateProfileInput(name: string, signature: string): ValidationResult {
    const errors: string[] = [];

    if (!UserProfile.validateUserName(name)) {
      if (name.trim().length === 0) {
        errors.push('用户名不能为空');
      } else if (name.length > 20) {
        errors.push('用户名不能超过20个字符');
      }
    }

    if (!UserProfile.validateUserSignature(signature)) {
      if (signature.length > 50) {
        errors.push('个性签名不能超过50个字符');
      }
    }

    return new ValidationResult(errors.length === 0, errors);
  }

  /**
   * 添加资料变更监听器
   */
  addProfileListener(listener: (profile: UserProfile) => void): void {
    this.profileListeners.push(listener);
    Logger.info('UserProfileManager', `添加资料监听器，当前监听器数量: ${this.profileListeners.length}`);
  }

  /**
   * 移除资料变更监听器
   */
  removeProfileListener(listener: (profile: UserProfile) => void): void {
    const index = this.profileListeners.indexOf(listener);
    if (index > -1) {
      this.profileListeners.splice(index, 1);
      Logger.info('UserProfileManager', `移除资料监听器，当前监听器数量: ${this.profileListeners.length}`);
    }
  }

  /**
   * 通知所有监听器
   */
  private notifyListeners(profile: UserProfile): void {
    this.profileListeners.forEach((listener, index) => {
      try {
        listener(profile);
        Logger.debug('UserProfileManager', `监听器 ${index} 通知成功`);
      } catch (error) {
        Logger.error('UserProfileManager', `监听器 ${index} 通知失败: ${error}`);
      }
    });
  }

  /**
   * 强制刷新用户资料（从存储重新加载）
   */
  async refreshProfile(): Promise<void> {
    try {
      this.currentProfile = await StorageManager.getUserProfile();
      if (this.currentProfile) {
        this.notifyListeners(this.currentProfile);
      }
      Logger.info('UserProfileManager', '用户资料刷新成功');
    } catch (error) {
      Logger.error('UserProfileManager', `刷新用户资料失败: ${error}`);
    }
  }

  /**
   * 销毁管理器
   */
  destroy(): void {
    this.profileListeners = [];
    this.currentProfile = null;
    this.initialized = false;
    Logger.info('UserProfileManager', '用户资料管理器已销毁');
  }
}