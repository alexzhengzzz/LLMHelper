import { describe, beforeAll, afterAll, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import UserProfileManager, { UserAvatarType, UserProfile } from '../../main/ets/utils/UserProfileManager';

export default function UserProfileManagerTest() {
  describe('UserProfileManagerTest', () => {
    let manager: UserProfileManager;

    beforeAll(() => {
      // 初始化测试环境
      manager = UserProfileManager.getInstance();
    });

    afterAll(() => {
      // 清理测试环境
      manager.clear();
    });

    beforeEach(() => {
      // 重置管理器状态
      manager.clear();
    });

    afterEach(() => {
      // 清理测试数据
    });

    it('should initialize with default profile', () => {
      const profile = manager.getProfile();
      expect(profile).notEqual(null);
      expect(profile.name).assertEqual('User');
      expect(profile.avatarType).assertEqual(UserAvatarType.EMOJI);
      expect(profile.avatar).assertEqual('👤');
    });

    it('should update profile name', () => {
      const newName = 'Test User';
      manager.updateName(newName);
      const profile = manager.getProfile();

      expect(profile.name).assertEqual(newName);
    });

    it('should update avatar with emoji', () => {
      const emoji = '😊';
      manager.updateAvatar(emoji, UserAvatarType.EMOJI);
      const profile = manager.getProfile();

      expect(profile.avatar).assertEqual(emoji);
      expect(profile.avatarType).assertEqual(UserAvatarType.EMOJI);
    });

    it('should update avatar with URL', () => {
      const url = 'https://example.com/avatar.jpg';
      manager.updateAvatar(url, UserAvatarType.URL);
      const profile = manager.getProfile();

      expect(profile.avatar).assertEqual(url);
      expect(profile.avatarType).assertEqual(UserAvatarType.URL);
    });

    it('should update avatar with file path', () => {
      const filePath = '/path/to/avatar.png';
      manager.updateAvatar(filePath, UserAvatarType.FILE);
      const profile = manager.getProfile();

      expect(profile.avatar).assertEqual(filePath);
      expect(profile.avatarType).assertEqual(UserAvatarType.FILE);
    });

    it('should validate avatar URL format', () => {
      expect(manager.isValidAvatarURL('https://example.com/avatar.jpg')).assertTrue();
      expect(manager.isValidAvatarURL('http://test.org/image.png')).assertTrue();
      expect(manager.isValidAvatarURL('ftp://invalid.url/image.jpg')).assertFalse();
      expect(manager.isValidAvatarURL('not-a-url')).assertFalse();
      expect(manager.isValidAvatarURL('')).assertFalse();
    });

    it('should validate file path format', () => {
      expect(manager.isValidFilePath('/path/to/file.png')).assertTrue();
      expect(manager.isValidFilePath('/path/to/avatar.jpg')).assertTrue();
      expect(manager.isValidFilePath('relative/path.jpg')).assertFalse();
      expect(manager.isValidFilePath('')).assertFalse();
    });

    it('should validate emoji format', () => {
      expect(manager.isValidEmoji('😊')).assertTrue();
      expect(manager.isValidEmoji('👍')).assertTrue();
      expect(manager.isValidEmoji('❤️')).assertTrue();
      expect(manager.isValidEmoji('abc')).assertFalse();
      expect(manager.isValidEmoji('123')).assertFalse();
      expect(manager.isValidEmoji('')).assertFalse();
    });

    it('should get default avatars', () => {
      const defaultAvatars = manager.getDefaultAvatars();
      expect(defaultAvatars.length).assertGreaterThan(0);
      expect(defaultAvatars.some(a => a === '👤')).assertTrue();
      expect(defaultAvatars.some(a => a === '😊')).assertTrue();
    });

    it('should get recent avatars', () => {
      manager.updateAvatar('😊', UserAvatarType.EMOJI);
      manager.updateAvatar('👍', UserAvatarType.EMOJI);
      manager.updateAvatar('❤️', UserAvatarType.EMOJI);

      const recentAvatars = manager.getRecentAvatars();
      expect(recentAvatars.length).assertLessEqual(5); // 最多5个最近头像
      expect(recentAvatars).toContain('❤️');
      expect(recentAvatars).toContain('👍');
      expect(recentAvatars).toContain('😊');
    });

    it('should get avatar suggestions', () => {
      const suggestions = manager.getAvatarSuggestions();
      expect(suggestions.length).assertGreaterThan(0);
      expect(suggestions.every(s => manager.isValidEmoji(s))).assertTrue();
    });

    it('should handle profile persistence', () => {
      const testProfile: UserProfile = {
        name: 'Test User',
        avatar: 'https://example.com/test.jpg',
        avatarType: UserAvatarType.URL
      };

      manager.updateProfile(testProfile);

      // 保存配置
      manager.save();

      // 清空并重新加载
      manager.clear();
      manager.load();

      const loadedProfile = manager.getProfile();
      expect(loadedProfile.name).assertEqual(testProfile.name);
      expect(loadedProfile.avatar).assertEqual(testProfile.avatar);
      expect(loadedProfile.avatarType).assertEqual(testProfile.avatarType);
    });

    it('should handle invalid profile updates', () => {
      const originalProfile = manager.getProfile();

      // 测试空名称
      manager.updateName('');
      expect(manager.getProfile().name).assertEqual(originalProfile.name);

      // 测试无效URL
      manager.updateAvatar('invalid-url', UserAvatarType.URL);
      expect(manager.getProfile().avatar).assertEqual(originalProfile.avatar);

      // 测试无效文件路径
      manager.updateAvatar('invalid-path', UserAvatarType.FILE);
      expect(manager.getProfile().avatar).assertEqual(originalProfile.avatar);
    });

    it('should export profile data', () => {
      const testProfile: UserProfile = {
        name: 'Export Test',
        avatar: '🚀',
        avatarType: UserAvatarType.EMOJI
      };

      manager.updateProfile(testProfile);
      const exported = manager.exportProfile();

      expect(exported.name).assertEqual(testProfile.name);
      expect(exported.avatar).assertEqual(testProfile.avatar);
      expect(exported.avatarType).assertEqual(testProfile.avatarType);
    });

    it('should import profile data', () => {
      const importData: UserProfile = {
        name: 'Import Test',
        avatar: '🎯',
        avatarType: UserAvatarType.EMOJI
      };

      manager.importProfile(importData);
      const profile = manager.getProfile();

      expect(profile.name).assertEqual(importData.name);
      expect(profile.avatar).assertEqual(importData.avatar);
      expect(profile.avatarType).assertEqual(importData.avatarType);
    });

    it('should handle profile change events', () => {
      let profileChanged = false;
      let changedProfile: UserProfile | null = null;

      manager.onProfileChange = (profile: UserProfile) => {
        profileChanged = true;
        changedProfile = profile;
      };

      manager.updateName('Event Test');
      expect(profileChanged).assertTrue();
      expect(changedProfile.name).assertEqual('Event Test');
    });

    it('should reset to default profile', () => {
      manager.updateName('Custom Name');
      manager.updateAvatar('😎', UserAvatarType.EMOJI);

      manager.resetToDefault();
      const profile = manager.getProfile();

      expect(profile.name).assertEqual('User');
      expect(profile.avatar).assertEqual('👤');
      expect(profile.avatarType).assertEqual(UserAvatarType.EMOJI);
    });

    it('should get profile statistics', () => {
      manager.updateAvatar('😊', UserAvatarType.EMOJI);
      manager.updateAvatar('👍', UserAvatarType.EMOJI);

      const stats = manager.getProfileStats();
      expect(stats.nameChanges).assertGreaterEqual(0);
      expect(stats.avatarChanges).assertGreaterEqual(2);
      expect(stats.avatarTypeChanges).assertGreaterEqual(0);
    });

    it('should handle multiple instances', () => {
      const instance1 = UserProfileManager.getInstance();
      const instance2 = UserProfileManager.getInstance();

      expect(instance1).assertEqual(instance2);

      instance1.updateName('Instance Test');
      expect(instance2.getProfile().name).assertEqual('Instance Test');
    });

    it('should validate profile data', () => {
      const validProfile: UserProfile = {
        name: 'Valid User',
        avatar: '😊',
        avatarType: UserAvatarType.EMOJI
      };

      expect(manager.validateProfile(validProfile)).assertTrue();

      const invalidProfile1 = {
        name: '',
        avatar: '😊',
        avatarType: UserAvatarType.EMOJI
      };

      expect(manager.validateProfile(invalidProfile1)).assertFalse();

      const invalidProfile2 = {
        name: 'Valid User',
        avatar: 'invalid',
        avatarType: UserAvatarType.EMOJI
      };

      expect(manager.validateProfile(invalidProfile2)).assertFalse();
    });

    it('should handle avatar caching', () => {
      const url = 'https://example.com/avatar.jpg';
      manager.updateAvatar(url, UserAvatarType.URL);

      expect(manager.isAvatarCached(url)).assertTrue();
      expect(manager.getCachedAvatar(url)).assertEqual(url);

      manager.clearAvatarCache();
      expect(manager.isAvatarCached(url)).assertFalse();
    });

    it('should get avatar by type', () => {
      manager.updateAvatar('😊', UserAvatarType.EMOJI);
      manager.updateAvatar('https://example.com/avatar.jpg', UserAvatarType.URL);

      const emojiAvatars = manager.getAvatarsByType(UserAvatarType.EMOJI);
      const urlAvatars = manager.getAvatarsByType(UserAvatarType.URL);

      expect(emojiAvatars).toContain('😊');
      expect(urlAvatars).toContain('https://example.com/avatar.jpg');
    });

    it('should handle profile backup and restore', () => {
      const testProfile: UserProfile = {
        name: 'Backup Test',
        avatar: '💾',
        avatarType: UserAvatarType.EMOJI
      };

      manager.updateProfile(testProfile);

      // 创建备份
      const backup = manager.createBackup();

      // 修改配置
      manager.updateName('Modified Name');

      // 恢复备份
      manager.restoreBackup(backup);

      const profile = manager.getProfile();
      expect(profile.name).assertEqual(testProfile.name);
      expect(profile.avatar).assertEqual(testProfile.avatar);
    });

    it('should handle edge cases', () => {
      // 测试空导入数据
      expect(() => {
        manager.importProfile({} as UserProfile);
      }).not.throw();

      // 测试null值处理
      expect(() => {
        manager.updateName(null);
      }).not.throw();

      expect(() => {
        manager.updateAvatar(null, UserAvatarType.EMOJI);
      }).not.throw();
    });

    it('should provide profile completion status', () => {
      // 初始状态应该不完整
      expect(manager.isProfileComplete()).assertFalse();

      // 添加必要信息
      manager.updateName('Complete User');
      manager.updateAvatar('✅', UserAvatarType.EMOJI);

      expect(manager.isProfileComplete()).assertTrue();
    });

    it('should get profile completion percentage', () => {
      // 初始完成度
      let completion = manager.getProfileCompletionPercentage();
      expect(completion).assertGreaterThan(0);
      expect(completion).assertLess(100);

      // 添加信息后完成度应该提高
      manager.updateName('Progress User');
      manager.updateAvatar('📊', UserAvatarType.EMOJI);

      completion = manager.getProfileCompletionPercentage();
      expect(completion).assertEqual(100);
    });
  });
}