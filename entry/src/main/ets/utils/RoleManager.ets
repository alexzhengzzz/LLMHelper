import { SystemPrompt } from '../models/ChatModels';
import { AppStorage } from './AppStorage';
import { Logger } from './Logger';

/**
 * 角色分类枚举
 */
export enum RoleCategory {
  PROFESSIONAL = 'professional',  // 专业角色
  CREATIVE = 'creative',        // 创意角色
  LIFE = 'life',                // 生活角色
  PSYCHOLOGY = 'psychology',    // 心理角色
  CUSTOM = 'custom'             // 自定义角色
}

/**
 * 角色排序选项
 */
export interface RoleSortOption {
  field: 'usageCount' | 'timestamp' | 'name' | 'pinned';
  order: 'asc' | 'desc';
}

/**
 * 角色统计信息
 */
export interface RoleStats {
  totalRoles: number;
  totalUsage: number;
  categoryStats: Record<string, number>;
  mostUsedRole: SystemPrompt | null;
}

/**
 * 角色筛选选项
 */
export interface RoleFilterOptions {
  category?: RoleCategory;
  searchQuery?: string;
  isPinned?: boolean;
  isBuiltIn?: boolean;
}

/**
 * 角色管理器 - 统一管理AI角色（系统提示词）
 */
export class RoleManager {
  private static instance: RoleManager | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): RoleManager {
    if (!RoleManager.instance) {
      RoleManager.instance = new RoleManager();
    }
    return RoleManager.instance;
  }

  /**
   * 获取所有角色
   */
  async getAllRoles(): Promise<SystemPrompt[]> {
    try {
      Logger.info('RoleManager', '获取所有角色');
      const roles = await AppStorage.getSystemPrompts();
      Logger.info('RoleManager', `获取到 ${roles.length} 个角色`);
      return roles.filter(role => role.isRole); // 只返回角色类型的提示词
    } catch (error) {
      Logger.error('RoleManager', `获取角色列表失败: ${error}`);
      return [];
    }
  }

  /**
   * 按分类获取角色
   */
  async getRolesByCategory(category: RoleCategory): Promise<SystemPrompt[]> {
    try {
      Logger.info('RoleManager', `获取分类角色: ${category}`);
      const allRoles = await this.getAllRoles();
      const filteredRoles = allRoles.filter(role => role.roleCategory === category);
      Logger.info('RoleManager', `分类 ${category} 有 ${filteredRoles.length} 个角色`);
      return filteredRoles;
    } catch (error) {
      Logger.error('RoleManager', `获取分类角色失败: ${error}`);
      return [];
    }
  }

  /**
   * 筛选角色
   */
  async filterRoles(options: RoleFilterOptions): Promise<SystemPrompt[]> {
    try {
      Logger.info('RoleManager', `筛选角色，选项: ${JSON.stringify(options)}`);
      let roles = await this.getAllRoles();

      // 按分类筛选
      if (options.category) {
        roles = roles.filter(role => role.roleCategory === options.category);
      }

      // 按置顶状态筛选
      if (options.isPinned !== undefined) {
        roles = roles.filter(role => role.isPinned === options.isPinned);
      }

      // 按内置状态筛选
      if (options.isBuiltIn !== undefined) {
        roles = roles.filter(role => role.isBuiltIn === options.isBuiltIn);
      }

      // 按搜索查询筛选
      if (options.searchQuery && options.searchQuery.trim()) {
        const query = options.searchQuery.toLowerCase().trim();
        roles = roles.filter(role =>
          role.name.toLowerCase().includes(query) ||
          role.content.toLowerCase().includes(query) ||
          role.roleDescription.toLowerCase().includes(query)
        );
      }

      Logger.info('RoleManager', `筛选后得到 ${roles.length} 个角色`);
      return roles;
    } catch (error) {
      Logger.error('RoleManager', `筛选角色失败: ${error}`);
      return [];
    }
  }

  /**
   * 排序角色
   */
  sortRoles(roles: SystemPrompt[], sortOption: RoleSortOption): SystemPrompt[] {
    try {
      Logger.info('RoleManager', `排序角色，选项: ${JSON.stringify(sortOption)}`);

      const sortedRoles = [...roles].sort((a, b) => {
        let valueA: number | string, valueB: number | string;

        switch (sortOption.field) {
          case 'usageCount':
            valueA = a.usageCount;
            valueB = b.usageCount;
            break;
          case 'timestamp':
            valueA = a.timestamp;
            valueB = b.timestamp;
            break;
          case 'name':
            valueA = a.name.toLowerCase();
            valueB = b.name.toLowerCase();
            break;
          case 'pinned':
            valueA = a.isPinned ? 1 : 0;
            valueB = b.isPinned ? 1 : 0;
            break;
          default:
            valueA = a.timestamp;
            valueB = b.timestamp;
        }

        if (sortOption.order === 'asc') {
          return valueA > valueB ? 1 : -1;
        } else {
          return valueA < valueB ? 1 : -1;
        }
      });

      Logger.info('RoleManager', '角色排序完成');
      return sortedRoles;
    } catch (error) {
      Logger.error('RoleManager', `排序角色失败: ${error}`);
      return roles;
    }
  }

  /**
   * 创建新角色
   */
  async createRole(name: string, content: string, category: RoleCategory = RoleCategory.CUSTOM,
                   roleIcon: string = '', roleDescription: string = ''): Promise<SystemPrompt> {
    try {
      Logger.info('RoleManager', `创建新角色: ${name}`);

      const newRole = new SystemPrompt(
        name.trim(),
        content.trim(),
        undefined, // 自动生成ID
        true,     // isRole = true
        category,
        roleIcon || this.getDefaultIconForCategory(category),
        roleDescription || name,
        false    // isBuiltIn = false
      );

      await AppStorage.addSystemPrompt(newRole);
      Logger.info('RoleManager', `角色创建成功: ${newRole.id}`);
      return newRole;
    } catch (error) {
      Logger.error('RoleManager', `创建角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 更新角色
   */
  async updateRole(role: SystemPrompt): Promise<void> {
    try {
      Logger.info('RoleManager', `更新角色: ${role.name}`);

      // 确保是角色类型
      role.isRole = true;
      role.timestamp = Date.now(); // 更新时间戳

      await AppStorage.updateSystemPrompt(role);
      Logger.info('RoleManager', `角色更新成功: ${role.id}`);
    } catch (error) {
      Logger.error('RoleManager', `更新角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 删除角色
   */
  async deleteRole(roleId: string): Promise<void> {
    try {
      Logger.info('RoleManager', `删除角色: ${roleId}`);

      // 检查是否为内置角色
      const roles = await this.getAllRoles();
      const role = roles.find(r => r.id === roleId);

      if (role && role.isBuiltIn) {
        throw new Error('不能删除内置角色');
      }

      await AppStorage.deleteSystemPrompt(roleId);
      Logger.info('RoleManager', `角色删除成功: ${roleId}`);
    } catch (error) {
      Logger.error('RoleManager', `删除角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 增加角色使用统计
   */
  async incrementRoleUsage(roleId: string): Promise<void> {
    try {
      Logger.debug('RoleManager', `增加角色使用统计: ${roleId}`);

      const roles = await this.getAllRoles();
      const role = roles.find(r => r.id === roleId);

      if (role) {
        role.usageCount++;
        role.timestamp = Date.now();
        await AppStorage.updateSystemPrompt(role);
        Logger.debug('RoleManager', `角色 ${roleId} 使用次数: ${role.usageCount}`);
      }
    } catch (error) {
      Logger.error('RoleManager', `增加角色使用统计失败: ${error}`);
    }
  }

  /**
   * 设置角色置顶状态
   */
  async pinRole(roleId: string, pinned: boolean): Promise<void> {
    try {
      Logger.info('RoleManager', `设置角色置顶状态: ${roleId} -> ${pinned}`);

      const roles = await this.getAllRoles();
      const role = roles.find(r => r.id === roleId);

      if (role) {
        role.isPinned = pinned;
        role.timestamp = Date.now();
        await AppStorage.updateSystemPrompt(role);
        Logger.info('RoleManager', `角色置顶状态设置成功: ${roleId}`);
      }
    } catch (error) {
      Logger.error('RoleManager', `设置角色置顶状态失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 获取角色详情
   */
  async getRoleById(roleId: string): Promise<SystemPrompt | null> {
    try {
      Logger.debug('RoleManager', `获取角色详情: ${roleId}`);

      const roles = await this.getAllRoles();
      const role = roles.find(r => r.id === roleId);

      if (role) {
        Logger.debug('RoleManager', `找到角色: ${role.name}`);
        return role;
      }

      Logger.warn('RoleManager', `未找到角色: ${roleId}`);
      return null;
    } catch (error) {
      Logger.error('RoleManager', `获取角色详情失败: ${error}`);
      return null;
    }
  }

  /**
   * 搜索角色
   */
  async searchRoles(query: string): Promise<SystemPrompt[]> {
    try {
      Logger.info('RoleManager', `搜索角色: ${query}`);

      if (!query || !query.trim()) {
        return await this.getAllRoles();
      }

      const options: RoleFilterOptions = {
        searchQuery: query.trim()
      };

      const results = await this.filterRoles(options);
      Logger.info('RoleManager', `搜索到 ${results.length} 个角色`);
      return results;
    } catch (error) {
      Logger.error('RoleManager', `搜索角色失败: ${error}`);
      return [];
    }
  }

  /**
   * 获取最常用的角色
   */
  async getMostUsedRoles(limit: number = 5): Promise<SystemPrompt[]> {
    try {
      Logger.info('RoleManager', `获取最常用的 ${limit} 个角色`);

      const roles = await this.getAllRoles();
      const sortedRoles = this.sortRoles(roles, {
        field: 'usageCount',
        order: 'desc'
      });

      return sortedRoles.slice(0, limit);
    } catch (error) {
      Logger.error('RoleManager', `获取最常用角色失败: ${error}`);
      return [];
    }
  }

  /**
   * 获取最近使用的角色
   */
  async getRecentRoles(limit: number = 5): Promise<SystemPrompt[]> {
    try {
      Logger.info('RoleManager', `获取最近使用的 ${limit} 个角色`);

      const roles = await this.getAllRoles();
      const sortedRoles = this.sortRoles(roles, {
        field: 'timestamp',
        order: 'desc'
      });

      return sortedRoles.slice(0, limit);
    } catch (error) {
      Logger.error('RoleManager', `获取最近使用角色失败: ${error}`);
      return [];
    }
  }

  /**
   * 获取置顶角色
   */
  async getPinnedRoles(): Promise<SystemPrompt[]> {
    try {
      Logger.info('RoleManager', '获取置顶角色');

      const options: RoleFilterOptions = {
        isPinned: true
      };

      const pinnedRoles = await this.filterRoles(options);
      const sortedRoles = this.sortRoles(pinnedRoles, {
        field: 'timestamp',
        order: 'desc'
      });

      Logger.info('RoleManager', `找到 ${sortedRoles.length} 个置顶角色`);
      return sortedRoles;
    } catch (error) {
      Logger.error('RoleManager', `获取置顶角色失败: ${error}`);
      return [];
    }
  }

  /**
   * 获取角色统计信息
   */
  async getRoleStats(): Promise<RoleStats> {
    try {
      Logger.info('RoleManager', '获取角色统计信息');

      const roles = await this.getAllRoles();
      const totalRoles = roles.length;
      const totalUsage = roles.reduce((sum, role) => sum + role.usageCount, 0);

      // 分类统计
      const categoryStats: Record<string, number> = {};
      roles.forEach(role => {
        categoryStats[role.roleCategory] = (categoryStats[role.roleCategory] || 0) + 1;
      });

      // 最常用角色
      const mostUsedRole = roles.length > 0
        ? roles.reduce((prev, current) => prev.usageCount > current.usageCount ? prev : current)
        : null;

      const stats: RoleStats = {
        totalRoles,
        totalUsage,
        categoryStats,
        mostUsedRole
      };

      Logger.info('RoleManager', `角色统计: ${JSON.stringify(stats)}`);
      return stats;
    } catch (error) {
      Logger.error('RoleManager', `获取角色统计失败: ${error}`);
      return {
        totalRoles: 0,
        totalUsage: 0,
        categoryStats: {},
        mostUsedRole: null
      } as RoleStats;
    }
  }

  /**
   * 初始化默认角色
   */
  async initializeDefaultRoles(): Promise<void> {
    try {
      Logger.info('RoleManager', '初始化默认角色');

      const existingRoles = await this.getAllRoles();
      if (existingRoles.length > 0) {
        Logger.info('RoleManager', '已存在角色，跳过初始化');
        return;
      }

      interface DefaultRoleData {
        name: string;
        content: string;
        category: RoleCategory;
        roleIcon: string;
        roleDescription: string;
      }

      const defaultRoles: DefaultRoleData[] = [
        {
          name: '编程助手',
          content: '你是一位经验丰富的编程助手，擅长多种编程语言，能够帮助用户解决编程问题、调试代码、优化算法。请用专业且易懂的语言回答技术问题。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '💻',
          roleDescription: '专业的编程技术支持'
        },
        {
          name: '创意写作助手',
          content: '你是一位富有创意的写作助手，能够帮助用户进行创意写作、故事创作、文案策划等。请用富有想象力和启发性的方式协助用户创作。',
          category: RoleCategory.CREATIVE,
          roleIcon: '✍️',
          roleDescription: '激发创意灵感的写作伙伴'
        },
        {
          name: '生活顾问',
          content: '你是一位亲切的生活顾问，能够为用户提供生活建议、情感支持、日常规划等帮助。请用温暖、体贴的语言与用户交流。',
          category: RoleCategory.LIFE,
          roleIcon: '🏠',
          roleDescription: '温暖贴心的生活指导'
        },
        {
          name: '心理咨询师',
          content: '你是一位专业的心理咨询师，能够为用户提供心理支持、情绪疏导、压力管理等专业帮助。请用专业、温和、保密的态度为用户提供服务。',
          category: RoleCategory.PSYCHOLOGY,
          roleIcon: '🧠',
          roleDescription: '专业心理支持与倾听'
        }
      ];

      for (const roleData of defaultRoles) {
        await this.createRole(
          roleData.name,
          roleData.content,
          roleData.category,
          roleData.roleIcon,
          roleData.roleDescription
        );
      }

      Logger.info('RoleManager', '默认角色初始化完成');
    } catch (error) {
      Logger.error('RoleManager', `初始化默认角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 获取分类默认图标
   */
  private getDefaultIconForCategory(category: RoleCategory): string {
    const iconMap: Record<RoleCategory, string> = {
      [RoleCategory.PROFESSIONAL]: '💼',
      [RoleCategory.CREATIVE]: '🎨',
      [RoleCategory.LIFE]: '🏠',
      [RoleCategory.PSYCHOLOGY]: '🧠',
      [RoleCategory.CUSTOM]: '⚙️'
    };
    return iconMap[category] || '🎭';
  }

  /**
   * 获取分类显示名称
   */
  static getCategoryDisplayName(category: RoleCategory): string {
    const nameMap: Record<RoleCategory, string> = {
      [RoleCategory.PROFESSIONAL]: '专业角色',
      [RoleCategory.CREATIVE]: '创意角色',
      [RoleCategory.LIFE]: '生活角色',
      [RoleCategory.PSYCHOLOGY]: '心理角色',
      [RoleCategory.CUSTOM]: '自定义角色'
    };
    return nameMap[category] || category;
  }

  /**
   * 获取所有分类
   */
  static getAllCategories(): RoleCategory[] {
    return [
      RoleCategory.PROFESSIONAL,
      RoleCategory.CREATIVE,
      RoleCategory.LIFE,
      RoleCategory.PSYCHOLOGY,
      RoleCategory.CUSTOM
    ];
  }
}