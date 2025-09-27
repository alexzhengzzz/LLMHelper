import { SystemPrompt } from '../models/ChatModels';
import { AppStorage } from './AppStorage';
import { Logger } from './Logger';
import { DefaultPrompts } from '../data/DefaultPrompts';
import { PromptsConfigManager } from './PromptsConfigManager';

/**
 * 角色分类枚举
 */
export enum RoleCategory {
  PROFESSIONAL = 'professional',  // 专业角色
  CHARACTER = 'character',      // 人物角色
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
      const allPrompts = await AppStorage.getSystemPrompts();
      Logger.info('RoleManager', `从存储获取到 ${allPrompts.length} 个系统提示词`);

      const rolePrompts = allPrompts.filter(role => role.isRole);
      Logger.info('RoleManager', `其中标记为角色的有 ${rolePrompts.length} 个`);

      // 如果发现有系统提示词没有标记为角色，记录日志
      const nonRolePrompts = allPrompts.filter(prompt => !prompt.isRole);
      if (nonRolePrompts.length > 0) {
        Logger.warn('RoleManager', `发现 ${nonRolePrompts.length} 个系统提示词未标记为角色:`);
        nonRolePrompts.forEach((prompt, index) => {
          Logger.warn('RoleManager', `  [${index + 1}] ${prompt.name} (ID: ${prompt.id})`);
        });
      }

      return rolePrompts; // 只返回角色类型的提示词
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
   * 检查角色名称是否已存在（不区分大小写）
   */
  async isRoleNameExists(name: string, excludeRoleId?: string): Promise<boolean> {
    try {
      Logger.debug('RoleManager', `检查角色名称是否存在: ${name}`);

      const allRoles = await this.getAllRoles();
      const trimmedName = name.trim();

      // 检查是否有重复名称（排除指定的角色ID，用于更新场景）
      const existingRole = allRoles.find(role =>
        role.name.toLowerCase() === trimmedName.toLowerCase() &&
        role.id !== excludeRoleId
      );

      const exists = !!existingRole;
      Logger.debug('RoleManager', `角色名称 "${trimmedName}" ${exists ? '已存在' : '不存在'}`);
      return exists;
    } catch (error) {
      Logger.error('RoleManager', `检查角色名称存在性失败: ${error}`);
      return false;
    }
  }

  /**
   * 创建新角色
   */
  async createRole(name: string, content: string, category: RoleCategory = RoleCategory.CUSTOM,
                   roleIcon: string = '', roleDescription: string = ''): Promise<SystemPrompt> {
    try {
      Logger.info('RoleManager', `创建新角色: ${name}`);

      // 检查角色名称是否已存在
      if (await this.isRoleNameExists(name)) {
        throw new Error(`角色名称 "${name.trim()}" 已存在，请使用其他名称`);
      }

      // 注意：此方法没有角色数量限制，用户可以创建任意数量的角色

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

      // 检查角色名称是否已存在（排除当前角色ID）
      if (await this.isRoleNameExists(role.name, role.id)) {
        throw new Error(`角色名称 "${role.name.trim()}" 已存在，请使用其他名称`);
      }

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

      // 删除角色
      await AppStorage.deleteSystemPrompt(roleId);

      // 同时从已应用角色列表中移除
      await this.removeRoleFromSidebar(roleId);

      Logger.info('RoleManager', `角色删除成功: ${roleId}`);
    } catch (error) {
      Logger.error('RoleManager', `删除角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 内部方法：强制删除角色（包括内置角色，仅供内部重置使用）
   */
  private async forceDeleteRole(roleId: string): Promise<void> {
    try {
      await AppStorage.deleteSystemPrompt(roleId);
      Logger.info('RoleManager', `强制删除角色成功: ${roleId}`);
    } catch (error) {
      Logger.error('RoleManager', `强制删除角色失败: ${error}`);
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
      const builtInRoles = existingRoles.filter(role => role.isBuiltIn);
      Logger.info('RoleManager', `当前存在 ${existingRoles.length} 个角色，其中 ${builtInRoles.length} 个内置角色`);

      // 检查是否已存在任何内置角色，如果存在则跳过初始化
      if (builtInRoles.length > 0) {
        Logger.info('RoleManager', '已存在内置角色，跳过初始化');
        return;
      }

      await this.forceInitializeDefaultRoles();
    } catch (error) {
      Logger.error('RoleManager', `初始化默认角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 修复角色分类：重新分类错误标记的内置角色
   */
  async fixRoleCategories(): Promise<number> {
    try {
      Logger.info('RoleManager', '开始修复角色分类');

      const allRoles = await this.getAllRoles();
      let fixedCount = 0;

      // 定义内置角色名称和其正确分类的映射
      const builtInRoleCategories: Record<string, RoleCategory> = {
        '技术专家': RoleCategory.PROFESSIONAL,
        '产品经理': RoleCategory.PROFESSIONAL,
        '项目管理教练': RoleCategory.PROFESSIONAL,
        '英语老师': RoleCategory.PROFESSIONAL,
        '投资顾问': RoleCategory.PROFESSIONAL,
        'UI/UX设计师': RoleCategory.PROFESSIONAL,
        '数据分析师': RoleCategory.PROFESSIONAL,
        '律师顾问': RoleCategory.PROFESSIONAL,
        '职业规划师': RoleCategory.PROFESSIONAL,
        '理财规划师': RoleCategory.PROFESSIONAL,
        '小说作家': RoleCategory.PROFESSIONAL,
        '摄影师': RoleCategory.PROFESSIONAL,
        '游戏策划师': RoleCategory.PROFESSIONAL,
        '知心朋友': RoleCategory.PROFESSIONAL,
        '健身教练': RoleCategory.PROFESSIONAL,
        '旅行规划师': RoleCategory.PROFESSIONAL,
        '营养师': RoleCategory.PROFESSIONAL,
        '心理咨询师': RoleCategory.PROFESSIONAL,
        '儿童教育专家': RoleCategory.PROFESSIONAL
      };

      for (const role of allRoles) {
        const correctCategory = builtInRoleCategories[role.name];
        if (correctCategory && role.roleCategory !== correctCategory) {
          Logger.info('RoleManager', `修复角色 ${role.name} 的分类: ${role.roleCategory} -> ${correctCategory}`);

          role.roleCategory = correctCategory;
          role.isBuiltIn = true; // 确保标记为内置角色
          role.roleIcon = role.roleIcon || this.getDefaultIconForCategory(correctCategory);

          await AppStorage.updateSystemPrompt(role);
          fixedCount++;
        }
      }

      Logger.info('RoleManager', `角色分类修复完成，共修复 ${fixedCount} 个角色`);
      return fixedCount;
    } catch (error) {
      Logger.error('RoleManager', `修复角色分类失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 修复现有系统提示词：将未标记为角色的系统提示词转换为角色
   */
  async convertSystemPromptsToRoles(): Promise<number> {
    try {
      Logger.info('RoleManager', '开始修复现有系统提示词');

      const allPrompts = await AppStorage.getSystemPrompts();
      const nonRolePrompts = allPrompts.filter(prompt => !prompt.isRole);

      if (nonRolePrompts.length === 0) {
        Logger.info('RoleManager', '所有系统提示词都已正确标记为角色');
        return 0;
      }

      Logger.info('RoleManager', `发现 ${nonRolePrompts.length} 个需要转换的系统提示词`);

      // 转换每个系统提示词为角色
      let convertedCount = 0;
      for (const prompt of nonRolePrompts) {
        try {
          Logger.info('RoleManager', `转换系统提示词: ${prompt.name}`);

          // 设置为角色
          prompt.isRole = true;
          prompt.roleCategory = RoleCategory.CUSTOM; // 默认设为自定义角色
          prompt.roleIcon = this.getDefaultIconForCategory(RoleCategory.CUSTOM);
          prompt.roleDescription = prompt.roleDescription || prompt.name;

          // 更新到存储
          await AppStorage.updateSystemPrompt(prompt);
          convertedCount++;

          Logger.info('RoleManager', `成功转换: ${prompt.name}`);
        } catch (error) {
          Logger.error('RoleManager', `转换失败 ${prompt.name}: ${error}`);
        }
      }

      Logger.info('RoleManager', `系统提示词修复完成，成功转换 ${convertedCount} 个`);
      return convertedCount;
    } catch (error) {
      Logger.error('RoleManager', `修复系统提示词失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 强制重新初始化默认角色（清除现有内置角色后重新创建）
   */
  async forceInitializeDefaultRoles(): Promise<void> {
    try {
      Logger.info('RoleManager', '强制重新初始化默认角色');

      // 首先删除所有现有的内置角色
      const existingRoles = await this.getAllRoles();
      const builtInRoles = existingRoles.filter(role => role.isBuiltIn);

      Logger.info('RoleManager', `删除现有的 ${builtInRoles.length} 个内置角色`);
      for (const role of builtInRoles) {
        await this.forceDeleteRole(role.id);
        Logger.info('RoleManager', `已删除内置角色: ${role.name}`);
      }

      // 使用异步方式获取 DefaultPrompts 中的所有角色作为默认角色
      Logger.info('RoleManager', '开始添加 DefaultPrompts 中的角色');
      const manager = PromptsConfigManager.getInstance();

      // 确保提示词已异步加载完成
      const defaultPromptsRoles = await manager.getAllPrompts();
      Logger.info('RoleManager', `从 DefaultPrompts 获取到 ${defaultPromptsRoles.length} 个角色`);

      for (const promptRole of defaultPromptsRoles) {
        try {
          // 确保角色标记和分类正确
          promptRole.isRole = true;
          promptRole.isBuiltIn = true;

          // 修正分类映射
          if (promptRole.roleCategory === 'professional') {
            promptRole.roleCategory = RoleCategory.PROFESSIONAL;
          } else if (promptRole.roleCategory === 'character') {
            promptRole.roleCategory = RoleCategory.CHARACTER;
          } else {
            // 默认设置分类：创意、生活、心理等都归类为专业角色
            promptRole.roleCategory = RoleCategory.PROFESSIONAL;
          }

          // 确保有正确的图标
          if (!promptRole.roleIcon) {
            promptRole.roleIcon = this.getDefaultIconForCategory(promptRole.roleCategory as RoleCategory);
          }

          await AppStorage.addSystemPrompt(promptRole);
          Logger.info('RoleManager', `DefaultPrompts 角色创建成功: ${promptRole.id} - ${promptRole.name} (分类: ${promptRole.roleCategory})`);
        } catch (error) {
          Logger.error('RoleManager', `创建 DefaultPrompts 角色失败 ${promptRole.name}: ${error}`);
        }
      }

      Logger.info('RoleManager', `强制初始化默认角色完成，共创建 ${defaultPromptsRoles.length} 个内置角色`);
    } catch (error) {
      Logger.error('RoleManager', `强制初始化默认角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 获取分类默认图标
   */
  private getDefaultIconForCategory(category: RoleCategory): string {
    const iconMap: Record<RoleCategory, string> = {
      [RoleCategory.PROFESSIONAL]: '💼',
      [RoleCategory.CHARACTER]: '🎭',
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
      [RoleCategory.CHARACTER]: '人物角色',
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
      RoleCategory.CHARACTER,
      RoleCategory.CUSTOM
    ];
  }

  //=================== 已应用角色管理相关方法 ===================

  /**
   * 获取已应用到侧边栏的角色列表
   */
  async getAppliedRoles(): Promise<SystemPrompt[]> {
    try {
      Logger.info('RoleManager', '获取已应用到侧边栏的角色列表');

      // 获取已应用角色的ID列表
      const appliedRoleIds = await AppStorage.getAppliedRoleIds();
      if (appliedRoleIds.length === 0) {
        Logger.debug('RoleManager', '没有已应用的角色');
        return [];
      }

      // 获取所有角色
      const allRoles = await this.getAllRoles();

      // 筛选出已应用的角色，保持ID列表的顺序
      const appliedRoles: SystemPrompt[] = [];
      const invalidRoleIds: string[] = []; // 记录无效的角色ID

      for (const roleId of appliedRoleIds) {
        const role = allRoles.find(r => r.id === roleId);
        if (role) {
          appliedRoles.push(role);
        } else {
          Logger.warn('RoleManager', `已应用角色ID ${roleId} 对应的角色不存在，可能已被删除`);
          invalidRoleIds.push(roleId);
        }
      }

      // 清理无效的角色ID（从已应用列表中移除）
      if (invalidRoleIds.length > 0) {
        Logger.info('RoleManager', `清理 ${invalidRoleIds.length} 个无效的角色ID`);
        for (const invalidRoleId of invalidRoleIds) {
          try {
            await this.removeRoleFromSidebar(invalidRoleId);
          } catch (error) {
            Logger.error('RoleManager', `清理无效角色ID失败 ${invalidRoleId}: ${error}`);
          }
        }
      }

      Logger.info('RoleManager', `获取到 ${appliedRoles.length} 个已应用角色`);
      return appliedRoles;
    } catch (error) {
      Logger.error('RoleManager', `获取已应用角色列表失败: ${error}`);
      return [];
    }
  }

  /**
   * 将角色应用到侧边栏
   */
  async applyRoleToSidebar(roleId: string): Promise<void> {
    try {
      Logger.info('RoleManager', `将角色应用到侧边栏: ${roleId}`);

      // 检查角色是否存在
      const role = await this.getRoleById(roleId);
      if (!role) {
        throw new Error(`角色不存在: ${roleId}`);
      }

      // 添加到已应用列表
      await AppStorage.addAppliedRole(roleId);
      Logger.info('RoleManager', `角色 ${role.name} 已应用到侧边栏`);
    } catch (error) {
      Logger.error('RoleManager', `应用角色到侧边栏失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 从侧边栏移除已应用的角色
   */
  async removeRoleFromSidebar(roleId: string): Promise<void> {
    try {
      Logger.info('RoleManager', `从侧边栏移除角色: ${roleId}`);

      // 从已应用列表中移除
      await AppStorage.removeAppliedRole(roleId);

      // 获取角色名称用于日志
      const role = await this.getRoleById(roleId);
      const roleName = role ? role.name : roleId;

      Logger.info('RoleManager', `角色 ${roleName} 已从侧边栏移除`);
    } catch (error) {
      Logger.error('RoleManager', `从侧边栏移除角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 检查角色是否已应用到侧边栏
   */
  async isRoleAppliedToSidebar(roleId: string): Promise<boolean> {
    try {
      Logger.debug('RoleManager', `检查角色是否已应用到侧边栏: ${roleId}`);
      const isApplied = await AppStorage.isRoleApplied(roleId);
      Logger.debug('RoleManager', `角色 ${roleId} 侧边栏应用状态: ${isApplied}`);
      return isApplied;
    } catch (error) {
      Logger.error('RoleManager', `检查角色侧边栏应用状态失败: ${error}`);
      return false;
    }
  }

  /**
   * 清空侧边栏所有已应用角色
   */
  async clearAllAppliedRoles(): Promise<void> {
    try {
      Logger.info('RoleManager', '清空侧边栏所有已应用角色');
      await AppStorage.clearAppliedRoles();
      Logger.info('RoleManager', '侧边栏已应用角色已全部清空');
    } catch (error) {
      Logger.error('RoleManager', `清空侧边栏已应用角色失败: ${error}`);
      throw error as Error;
    }
  }

  /**
   * 获取已应用角色的数量
   */
  async getAppliedRolesCount(): Promise<number> {
    try {
      const appliedRoleIds = await AppStorage.getAppliedRoleIds();
      return appliedRoleIds.length;
    } catch (error) {
      Logger.error('RoleManager', `获取已应用角色数量失败: ${error}`);
      return 0;
    }
  }
}