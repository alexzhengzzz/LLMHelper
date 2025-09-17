import { AppStorage } from '../utils/AppStorage';
import { Logger } from './Logger';
import { DefaultPrompts } from '../data/DefaultPrompts';

interface SimplePromptData {
  id: string;
  name: string;
  content: string;
  timestamp: number;
}

/**
 * 系统提示词管理工具类
 * 提供简化的数据管理，避免复杂的序列化问题
 */
export class SystemPromptManager {
  
  /**
   * 获取所有默认提示词
   */
  static getDefaultPrompts(): SimplePromptData[] {
    try {
      Logger.info('SystemPromptManager', '获取默认系统提示词');
      const defaultPrompts = DefaultPrompts.getAllPrompts();
      
      // 转换为简单数据结构
      const simplePrompts = defaultPrompts.map(prompt => ({
        id: prompt.id,
        name: prompt.name,
        content: prompt.content,
        timestamp: prompt.timestamp
      }));
      
      Logger.info('SystemPromptManager', `获取到 ${simplePrompts.length} 个默认提示词`);
      return simplePrompts;
    } catch (error) {
      Logger.error('SystemPromptManager', `获取默认提示词失败: ${error}`);
      return [];
    }
  }
  
  /**
   * 根据分类获取默认提示词
   */
  static getDefaultPromptsByCategory(category: string): SimplePromptData[] {
    try {
      Logger.info('SystemPromptManager', `获取分类默认提示词: ${category}`);
      const categoryPrompts = DefaultPrompts.getPromptsByCategory(category);
      
      // 转换为简单数据结构
      const simplePrompts = categoryPrompts.map(prompt => ({
        id: prompt.id,
        name: prompt.name,
        content: prompt.content,
        timestamp: prompt.timestamp
      }));
      
      Logger.info('SystemPromptManager', `分类 ${category} 包含 ${simplePrompts.length} 个提示词`);
      return simplePrompts;
    } catch (error) {
      Logger.error('SystemPromptManager', `获取分类默认提示词失败: ${error}`);
      return [];
    }
  }
  
  /**
   * 搜索默认提示词
   */
  static searchDefaultPrompts(keyword: string): SimplePromptData[] {
    try {
      Logger.info('SystemPromptManager', `搜索默认提示词: ${keyword}`);
      const searchResults = DefaultPrompts.searchPrompts(keyword);
      
      // 转换为简单数据结构
      const simplePrompts = searchResults.map(prompt => ({
        id: prompt.id,
        name: prompt.name,
        content: prompt.content,
        timestamp: prompt.timestamp
      }));
      
      Logger.info('SystemPromptManager', `搜索到 ${simplePrompts.length} 个相关提示词`);
      return simplePrompts;
    } catch (error) {
      Logger.error('SystemPromptManager', `搜索默认提示词失败: ${error}`);
      return [];
    }
  }
  
  /**
   * 获取提示词分类列表
   */
  static getPromptCategories(): string[] {
    try {
      const categories = DefaultPrompts.getCategories();
      Logger.info('SystemPromptManager', `获取到 ${categories.length} 个提示词分类`);
      return categories;
    } catch (error) {
      Logger.error('SystemPromptManager', `获取提示词分类失败: ${error}`);
      return [];
    }
  }
  
  /**
   * 获取所有提示词（包括用户自定义和默认）
   */
  static async getAllPrompts(includeDefaults: boolean = true): Promise<SimplePromptData[]> {
    try {
      Logger.info('SystemPromptManager', '=== getAllPrompts 开始 ===');
      Logger.debug('SystemPromptManager', `当前时间: ${new Date().toISOString()}`);
      
      // 获取用户自定义提示词
      const userPrompts = await this.getPrompts();
      Logger.info('SystemPromptManager', `用户自定义提示词: ${userPrompts.length} 条`);
      
      let allPrompts = [...userPrompts];
      
      // 如果需要包含默认提示词
      if (includeDefaults) {
        const defaultPrompts = this.getDefaultPrompts();
        Logger.info('SystemPromptManager', `默认提示词: ${defaultPrompts.length} 条`);
        
        // 合并并去重（基于名称）
        const existingNames = new Set(userPrompts.map(p => p.name));
        const uniqueDefaults = defaultPrompts.filter(p => !existingNames.has(p.name));
        
        allPrompts = [...allPrompts, ...uniqueDefaults];
      }
      
      Logger.info('SystemPromptManager', `总计 ${allPrompts.length} 条提示词`);
      Logger.info('SystemPromptManager', '=== getAllPrompts 完成 ===');
      
      return allPrompts;
    } catch (error) {
      Logger.error('SystemPromptManager', `获取所有提示词失败: ${error}`);
      Logger.error('SystemPromptManager', `错误堆栈: ${(error as Error).stack}`);
      return [];
    }
  }
  
  /**
   * 获取用户自定义提示词（不包含默认）
   */
  static async getUserPrompts(): Promise<SimplePromptData[]> {
    try {
      Logger.info('SystemPromptManager', '=== getUserPrompts 开始 ===');
      
      const prompts = await this.getPrompts();
      Logger.info('SystemPromptManager', `获取到 ${prompts.length} 条用户自定义提示词`);
      
      Logger.info('SystemPromptManager', '=== getUserPrompts 完成 ===');
      return prompts;
    } catch (error) {
      Logger.error('SystemPromptManager', `获取用户提示词失败: ${error}`);
      return [];
    }
  }
  
  /**
   * 初始化默认提示词（仅在首次使用时）
   */
  static async initializeDefaultPrompts(): Promise<boolean> {
    try {
      Logger.info('SystemPromptManager', '=== initializeDefaultPrompts 开始 ===');
      
      const existingPrompts = await this.getPrompts();
      
      if (existingPrompts.length === 0) {
        Logger.info('SystemPromptManager', '首次使用，初始化默认提示词');
        
        const defaultPrompts = this.getDefaultPrompts();
        
        for (const prompt of defaultPrompts) {
          const success = await this.addPrompt(prompt.name, prompt.content);
          if (!success) {
            Logger.error('SystemPromptManager', `初始化提示词失败: ${prompt.name}`);
            return false;
          }
        }
        
        Logger.info('SystemPromptManager', `成功初始化 ${defaultPrompts.length} 个默认提示词`);
      } else {
        Logger.info('SystemPromptManager', `已存在 ${existingPrompts.length} 条提示词，跳过初始化`);
      }
      
      Logger.info('SystemPromptManager', '=== initializeDefaultPrompts 完成 ===');
      return true;
    } catch (error) {
      Logger.error('SystemPromptManager', `初始化默认提示词失败: ${error}`);
      return false;
    }
  }
  
  /**
   * 获取所有提示词（保持向后兼容）
   */
  static async getPrompts(): Promise<SimplePromptData[]> {
    try {
      Logger.info('SystemPromptManager', '=== getPrompts 开始 ===');
      Logger.debug('SystemPromptManager', `当前时间: ${new Date().toISOString()}`);
      
      const prompts = await AppStorage.getSystemPrompts();
      Logger.info('SystemPromptManager', `从AppStorage获取到 ${prompts.length} 条提示词`);
      
      // 转换为简单数据结构
      const simplePrompts = prompts.map(prompt => ({
        id: prompt.id,
        name: prompt.name,
        content: prompt.content,
        timestamp: prompt.timestamp
      }));
      
      Logger.info('SystemPromptManager', `转换为简单数据结构，返回 ${simplePrompts.length} 条提示词`);
      Logger.info('SystemPromptManager', '=== getPrompts 完成 ===');
      
      return simplePrompts;
    } catch (error) {
      Logger.error('SystemPromptManager', `获取提示词失败: ${error}`);
      Logger.error('SystemPromptManager', `错误堆栈: ${(error as Error).stack}`);
      return [];
    }
  }
  
  /**
   * 添加提示词
   */
  static async addPrompt(name: string, content: string): Promise<boolean> {
    try {
      console.info('=== SystemPromptManager.addPrompt 开始 ===');
      console.info('当前时间:', new Date().toISOString());
      console.info(`添加提示词 - 名称: "${name}", 内容长度: ${content.length}`);
      
      const prompts = await this.getPrompts();
      console.info(`当前存储的提示词数量: ${prompts.length}`);
      
      const newPrompt: SimplePromptData = {
        id: this.generateId(),
        name: name.trim(),
        content: content.trim(),
        timestamp: Date.now()
      };
      
      Logger.info('SystemPromptManager', `新提示词对象: ${JSON.stringify(newPrompt)}`);
      
      prompts.push(newPrompt);
      Logger.info('SystemPromptManager', `添加后提示词数量: ${prompts.length}`);
      
      await this.savePrompts(prompts);
      Logger.info('SystemPromptManager', '✅ addPrompt 成功');
      Logger.info('SystemPromptManager', '=== addPrompt 完成 ===');
      return true;
    } catch (error) {
      Logger.error('SystemPromptManager', `添加提示词失败: ${error}`);
      Logger.error('SystemPromptManager', `错误堆栈: ${(error as Error).stack}`);
      return false;
    }
  }
  
  /**
   * 更新提示词
   */
  static async updatePrompt(id: string, name: string, content: string): Promise<boolean> {
    try {
      const prompts = await this.getPrompts();
      const index = prompts.findIndex(p => p.id === id);
      if (index === -1) return false;
      
      prompts[index].name = name.trim();
      prompts[index].content = content.trim();
      prompts[index].timestamp = Date.now();
      
      await this.savePrompts(prompts);
      return true;
    } catch (error) {
      Logger.error('SystemPromptManager', `更新提示词失败: ${error}`);
      return false;
    }
  }
  
  /**
   * 删除提示词
   */
  static async deletePrompt(id: string): Promise<boolean> {
    try {
      const prompts = await this.getPrompts();
      const filteredPrompts = prompts.filter(p => p.id !== id);
      await this.savePrompts(filteredPrompts);
      return true;
    } catch (error) {
      Logger.error('SystemPromptManager', `删除提示词失败: ${error}`);
      return false;
    }
  }
  
  /**
   * 保存提示词到存储
   */
  private static async savePrompts(prompts: SimplePromptData[]): Promise<void> {
    try {
      Logger.info('SystemPromptManager', `保存 ${prompts.length} 条提示词到存储`);
      // 转换为SystemPrompt对象数组
      const systemPrompts = prompts.map(data => ({
        id: data.id,
        name: data.name,
        content: data.content,
        timestamp: data.timestamp
      }));
      
      await AppStorage.saveSystemPrompts(systemPrompts);
      Logger.info('SystemPromptManager', '提示词保存成功');
    } catch (error) {
      Logger.error('SystemPromptManager', `保存提示词失败: ${error}`);
      throw error;
    }
  }
  
  /**
   * 生成ID
   */
  private static generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  }
}