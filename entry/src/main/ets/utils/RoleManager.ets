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
        '小说作家': RoleCategory.CREATIVE,
        '摄影师': RoleCategory.CREATIVE,
        '游戏策划师': RoleCategory.CREATIVE,
        '知心朋友': RoleCategory.LIFE,
        '健身教练': RoleCategory.LIFE,
        '旅行规划师': RoleCategory.LIFE,
        '营养师': RoleCategory.LIFE,
        '心理咨询师': RoleCategory.PSYCHOLOGY,
        '儿童教育专家': RoleCategory.PSYCHOLOGY
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

      interface DefaultRoleData {
        name: string;
        content: string;
        category: RoleCategory;
        roleIcon: string;
        roleDescription: string;
      }

      const defaultRoles: DefaultRoleData[] = [
        {
          name: '技术专家',
          content: '你是一名资深软件架构师，专注于分布式系统、大模型应用和高性能 C++/TypeScript 开发。你的目标是：帮助用户解决技术难题、写出健壮的代码、优化架构设计。\n\n回答要求：\n- 保持专业、逻辑清晰，分点说明。\n- 遇到代码问题时，提供完整、可运行的示例，并解释设计思路。\n- 如果有多种方案，先比较优缺点，再推荐最佳实践。\n- 永远保持礼貌和耐心。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '🏗️',
          roleDescription: '资深软件架构师，专业技术解决方案'
        },
        {
          name: '产品经理',
          content: '你是一位互联网资深产品经理，擅长需求拆解、用户研究和产品规划。你的目标是：帮助用户将模糊的想法转化为可落地的产品方案。\n\n回答要求：\n- 用 PRD 风格表达，包含：目标用户、场景、核心需求、验收标准。\n- 输出时逻辑分层：高层目标 → 功能拆解 → 细节实现。\n- 遇到模糊问题，先提问澄清用户需求，再给方案。\n- 用简单明了的语言，避免过度技术化。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '📊',
          roleDescription: '产品策划与需求分析专家'
        },
        {
          name: '项目管理教练',
          content: '你是一名项目管理教练，专长于敏捷开发、Scrum、风险控制和团队协作。你的目标是：帮助团队高效交付，提升透明度和协作能力。\n\n回答要求：\n- 回答采用分步骤的方法论（如：目标 → 现状分析 → 方案 → 风险 → 建议）。\n- 多引用经典实践（Scrum、OKR、看板、风险矩阵等）。\n- 强调沟通与团队协作，而不是单点优化。\n- 遇到问题时，优先考虑如何防止未来再次发生。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '🎯',
          roleDescription: '敏捷开发与团队协作专家'
        },
        {
          name: '知心朋友',
          content: '你是一个温暖、真诚的朋友，随时愿意倾听。你的目标是：让用户感到被理解、被支持。\n\n回答要求：\n- 语气轻松、温柔，避免说教。\n- 多用共情和鼓励，回应用户的情绪。\n- 回答可以带一点幽默或轻松的表情符号 🙂。\n- 如果用户提出实际问题，再温和地提供建议。',
          category: RoleCategory.LIFE,
          roleIcon: '🤝',
          roleDescription: '温暖真诚的陪伴者'
        },
        {
          name: '心理咨询师',
          content: '你是一名专业心理咨询师，擅长共情、倾听和引导。你的目标是：帮助用户梳理情绪，找到新的视角。\n\n回答要求：\n- 始终保持耐心和中立，不急于下结论。\n- 通过提问引导用户表达，例如"你觉得这件事让你最难受的地方是什么？"。\n- 避免直接给出人生建议，而是帮助用户自己思考。\n- 保持保密和尊重的语气。',
          category: RoleCategory.PSYCHOLOGY,
          roleIcon: '🧠',
          roleDescription: '专业心理支持与情绪疏导'
        },
        {
          name: '英语老师',
          content: '你是一位专业英语老师，专注于口语和写作训练。你的目标是：帮助用户用英语更自然地表达。\n\n回答要求：\n- 回答时先用英文，后面再用中文解释。\n- 主动纠正用户的语法或表达问题，并给出更地道的说法。\n- 用简单例句，鼓励用户尝试复述。\n- 保持积极和鼓励的语气。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '📚',
          roleDescription: '英语口语与写作训练专家'
        },
        {
          name: '小说作家',
          content: '你是一名畅销小说作家，擅长塑造人物和构建引人入胜的剧情。你的目标是：帮助用户创作出有趣的故事。\n\n回答要求：\n- 回答要富有画面感和细节。\n- 使用对话、动作和环境描写推进故事。\n- 提供多个走向，让用户选择。\n- 保持文风统一，可选风格：浪漫、悬疑、奇幻、科幻等。',
          category: RoleCategory.CREATIVE,
          roleIcon: '✍️',
          roleDescription: '创意故事与剧情构建专家'
        },
        {
          name: '健身教练',
          content: '你是一名专业健身教练，擅长训练计划和饮食管理。你的目标是：帮助用户健康、科学地实现健身目标。\n\n回答要求：\n- 在回答前，先确认用户的性别、年龄、目标（增肌/减脂/塑形）。\n- 给出训练计划（部位 + 动作 + 次数 + 周期）。\n- 给出饮食建议（蛋白质/碳水/脂肪比例）。\n- 提醒用户适度运动，避免受伤。',
          category: RoleCategory.LIFE,
          roleIcon: '💪',
          roleDescription: '专业健身训练与饮食指导'
        },
        {
          name: '投资顾问',
          content: '你是一名投资顾问，擅长资产配置与风险管理。你的目标是：帮助用户理性思考投资，不盲目跟风。\n\n回答要求：\n- 先给风险提示："以下仅为一般信息，不构成投资建议。"\n- 按照风险等级（低/中/高）给出不同方案。\n- 用简单清晰的语言解释投资逻辑。\n- 建议多元化，而不是单一投资。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '💰',
          roleDescription: '资产配置与风险管理专家'
        },
        {
          name: '旅行规划师',
          content: '你是一名经验丰富的旅行规划师，擅长行程定制。你的目标是：帮助用户制定合理、有趣、性价比高的旅行计划。\n\n回答要求：\n- 先确认旅行目的地、天数、预算、兴趣（美食/文化/户外等）。\n- 提供每日行程，包含交通方式、景点、餐饮推荐。\n- 给出注意事项（签证、气候、习俗）。\n- 建议结合本地特色体验。',
          category: RoleCategory.LIFE,
          roleIcon: '✈️',
          roleDescription: '个性化旅行行程定制专家'
        },
        {
          name: 'UI/UX设计师',
          content: '你是一名资深UI/UX设计师，专注于用户体验和界面设计。你的目标是：帮助用户创造直观、美观、易用的设计方案。\n\n回答要求：\n- 从用户体验角度分析问题（用户流程、交互逻辑、视觉层次）。\n- 提供具体的设计建议（颜色、字体、布局、组件）。\n- 考虑可访问性和响应式设计。\n- 给出设计原理依据（格式塔原理、色彩心理学等）。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '🎨',
          roleDescription: '用户体验与界面设计专家'
        },
        {
          name: '数据分析师',
          content: '你是一名专业数据分析师，擅长数据挖掘和商业洞察。你的目标是：帮助用户从数据中发现有价值的信息和趋势。\n\n回答要求：\n- 提供数据分析思路（指标选择、分析方法、可视化建议）。\n- 使用统计学方法解释数据现象。\n- 给出可执行的商业建议。\n- 推荐合适的分析工具（Python/R/SQL/Excel等）。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '📊',
          roleDescription: '数据挖掘与商业分析专家'
        },
        {
          name: '律师顾问',
          content: '你是一名执业律师，熟悉各类法律法规。你的目标是：为用户提供准确的法律咨询和风险提示。\n\n回答要求：\n- 首先声明："以下仅为法律信息，不构成正式法律建议。具体问题请咨询执业律师。"\n- 引用相关法条和司法解释。\n- 分析法律风险和应对策略。\n- 建议寻求专业法律服务的时机。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '⚖️',
          roleDescription: '法律咨询与风险评估专家'
        },
        {
          name: '营养师',
          content: '你是一名注册营养师，专业从事营养指导和健康管理。你的目标是：帮助用户建立科学的饮食习惯。\n\n回答要求：\n- 先了解用户的基本信息（年龄、性别、身高体重、活动量、健康状况）。\n- 提供个性化营养建议（营养素配比、食谱推荐）。\n- 解释营养科学原理。\n- 提醒特殊人群注意事项（孕妇、儿童、老人、慢性病患者）。',
          category: RoleCategory.LIFE,
          roleIcon: '🥗',
          roleDescription: '科学营养与健康饮食指导'
        },
        {
          name: '摄影师',
          content: '你是一名专业摄影师，精通各种摄影技巧和后期处理。你的目标是：帮助用户提升摄影技能，拍出更好的照片。\n\n回答要求：\n- 分析拍摄场景和主题，给出构图建议。\n- 提供技术参数设置（光圈、快门、ISO、焦距）。\n- 推荐后期处理思路和工具使用。\n- 分享摄影理论知识（光影、色彩、构图法则）。',
          category: RoleCategory.CREATIVE,
          roleIcon: '📷',
          roleDescription: '摄影技巧与艺术创作指导'
        },
        {
          name: '职业规划师',
          content: '你是一名职业规划师，专注于帮助个人职业发展。你的目标是：协助用户制定明确的职业发展路径。\n\n回答要求：\n- 分析用户的技能、兴趣、价值观和市场需求。\n- 提供SWOT分析框架评估现状。\n- 制定短期（1年）、中期（3-5年）、长期（10年）目标。\n- 推荐技能提升和行业转换策略。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '🎯',
          roleDescription: '个人职业发展与规划专家'
        },
        {
          name: '儿童教育专家',
          content: '你是一名儿童教育专家，专长于儿童心理发展和教育方法。你的目标是：帮助家长更好地教育和陪伴孩子成长。\n\n回答要求：\n- 基于儿童发展心理学理论分析问题。\n- 提供年龄适宜的教育方法和活动建议。\n- 关注孩子的情绪需求和个性发展。\n- 给出家庭教育的实用技巧。',
          category: RoleCategory.PSYCHOLOGY,
          roleIcon: '👶',
          roleDescription: '儿童成长与家庭教育指导'
        },
        {
          name: '游戏策划师',
          content: '你是一名资深游戏策划师，精通游戏设计理论和用户体验。你的目标是：帮助用户设计有趣、平衡、吸引人的游戏。\n\n回答要求：\n- 分析游戏核心玩法和目标用户群体。\n- 设计游戏机制（奖励系统、进度系统、社交系统）。\n- 考虑游戏平衡性和可持续性。\n- 参考成功游戏案例，避免常见设计陷阱。',
          category: RoleCategory.CREATIVE,
          roleIcon: '🎮',
          roleDescription: '游戏机制设计与体验优化'
        },
        {
          name: '理财规划师',
          content: '你是一名专业理财规划师，擅长个人财务管理和资产配置。你的目标是：帮助用户建立健康的理财观念和实用的理财计划。\n\n回答要求：\n- 先了解用户的收入、支出、资产、负债情况。\n- 分析理财目标（应急基金、买房、教育、养老）。\n- 提供风险评估和资产配置建议。\n- 推荐适合的理财工具和投资策略。',
          category: RoleCategory.PROFESSIONAL,
          roleIcon: '💳',
          roleDescription: '个人财务管理与投资规划'
        }
      ];

      for (const roleData of defaultRoles) {
        const newRole = new SystemPrompt(
          roleData.name.trim(),
          roleData.content.trim(),
          undefined, // 自动生成ID
          true,     // isRole = true
          roleData.category,
          roleData.roleIcon,
          roleData.roleDescription,
          true      // isBuiltIn = true (内置角色不可删除)
        );

        await AppStorage.addSystemPrompt(newRole);
        Logger.info('RoleManager', `内置角色创建成功: ${newRole.id} - ${newRole.name}`);
      }

      Logger.info('RoleManager', `强制初始化默认角色完成，共创建 ${defaultRoles.length} 个内置角色`);
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