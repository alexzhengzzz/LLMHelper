/**
 * 搜索决策引擎
 * 智能判断用户输入是否需要联网搜索
 */

import { Logger } from '../utils/Logger';

/**
 * 搜索决策结果
 */
export interface SearchDecision {
  shouldSearch: boolean;
  confidence: number; // 0-1，建议搜索的置信度
  reason: string; // 决策原因
  keywords: string[]; // 检测到的关键词
  category: SearchCategory; // 搜索类别
}

/**
 * 搜索类别
 */
export enum SearchCategory {
  REAL_TIME = 'real_time', // 实时信息
  TECHNICAL = 'technical', // 技术查询
  NEWS = 'news', // 新闻事件
  CURRENT_AFFAIRS = 'current_affairs', // 时事
  FACTUAL = 'factual', // 事实查询
  NONE = 'none' // 不需要搜索
}

/**
 * 特殊模式检测结果
 */
export interface SpecialPatternResult {
  detected: boolean;
  score: number;
  keywords: string[];
  category: SearchCategory;
}

export class SearchDecisionEngine {
  private static instance: SearchDecisionEngine;

  // 实时信息关键词
  private realTimeKeywords: string[] = [
    '最新', '现在', '今天', '今年', '当前', '目前', '近期', '最近',
    '实时', '正在', '刚刚', '昨天', '明天', '这个月', '本月', '本年',
    '2024', '2025', 'latest', 'current', 'now', 'today', 'recent',
    // 扩展时间关键词
    '此刻', '目前', '现时', '此时', '当前时间', '几点', '什么时候',
    '今天上午', '今天下午', '今天晚上', '今早', '今晚', '今日',
    '现在几点', '实时数据', '即时信息', '动态更新', '实时更新'
  ];

  // 技术查询关键词
  private technicalKeywords: string[] = [
    'API', 'SDK', '文档', '教程', '框架', '库', '版本', '更新', '发布',
    '官方', '源码', 'GitHub', 'npm', 'pip', 'yarn', '安装', '配置',
    '错误', 'bug', '修复', '解决', '问题', 'issue', 'error', 'exception',
    '鸿蒙', 'HarmonyOS', 'ArkTS', 'DevEco', 'OpenHarmony',
    'React', 'Vue', 'Angular', 'Node.js', 'Python', 'Java', 'Go',
    'Docker', 'Kubernetes', 'MySQL', 'PostgreSQL', 'MongoDB'
  ];

  // 新闻事件关键词
  private newsKeywords: string[] = [
    '新闻', '报道', '消息', '发布', '宣布', '公告', '声明', '官宣',
    '事件', '发生', '情况', '状态', '更新', '进展', '结果',
    '公司', '企业', '组织', '政府', '机构', '官方'
  ];

  // 时事关键词
  private currentAffairsKeywords: string[] = [
    '政策', '法律', '规定', '条例', '规则', '标准', '要求',
    '经济', '市场', '股价', '汇率', '价格', '行情', '趋势',
    '天气', '气候', '温度', '降雨', '台风', '地震', '灾害',
    // 扩展天气相关关键词
    '天气预报', '气温', '天气情况', '天气如何', '天气怎么样',
    '阴晴', '风力', '湿度', '空气质量', 'PM2.5', '紫外线',
    '天气状况', '实时天气', '今日天气', '现在天气',
    // 扩展地理位置关键词（常见城市）
    '北京', '上海', '广州', '深圳', '杭州', '南京', '苏州', '吴江',
    '成都', '重庆', '武汉', '西安', '天津', '青岛', '大连', '厦门',
    // 扩展经济信息关键词
    '股票', '基金', '理财', '投资', '收益', '利率', '汇率',
    '财经', '股市', '期货', '黄金', '原油', '数字货币',
    // 扩展时事新闻关键词
    '新闻', '事件', '发布会', '公告', '通知', '动态', '进展',
    '最新消息', '实时新闻', '今日头条', '热点', '要闻'
  ];

  // 不需要搜索的关键词（优先级更高）
  private noSearchKeywords: string[] = [
    '你是', '你好', '谢谢', '感谢', '再见', '拜拜',
    '什么是', '为什么', '解释', '定义',
    '计算', '算一下', '帮我', '写一个', '生成', '创建',
    '代码', '函数', '方法', '类', '变量', '数据结构',
    '故事', '诗歌', '小说', '文章', '作文', '总结'
    // 注意：移除了"如何"、"怎么"因为它们会误判天气查询等需要搜索的问题
  ];

  private constructor() {}

  static getInstance(): SearchDecisionEngine {
    if (!SearchDecisionEngine.instance) {
      SearchDecisionEngine.instance = new SearchDecisionEngine();
    }
    return SearchDecisionEngine.instance;
  }

  /**
   * 判断是否需要搜索
   */
  shouldSearch(message: string, isSearchEnabled: boolean): SearchDecision {
    Logger.info('SearchDecisionEngine', `=== 搜索决策分析 ===`);
    Logger.info('SearchDecisionEngine', `输入消息: "${message}"`);
    Logger.info('SearchDecisionEngine', `搜索开关: ${isSearchEnabled}`);

    // 如果搜索开关关闭，直接返回不搜索
    if (!isSearchEnabled) {
      const decision: SearchDecision = {
        shouldSearch: false,
        confidence: 0,
        reason: '联网搜索开关已关闭',
        keywords: [],
        category: SearchCategory.NONE
      };
      Logger.info('SearchDecisionEngine', `决策结果: ${JSON.stringify(decision)}`);
      return decision;
    }

    const lowerMessage = message.toLowerCase();
    const detectedKeywords: string[] = [];
    let totalScore = 0;
    let category = SearchCategory.NONE;

    // 检查不需要搜索的关键词（优先级最高）
    const noSearchMatches = this.findMatchingKeywords(lowerMessage, this.noSearchKeywords);
    if (noSearchMatches.length > 0) {
      const decision: SearchDecision = {
        shouldSearch: false,
        confidence: 0,
        reason: `检测到不需要搜索的内容类型，匹配关键词: ${noSearchMatches.join(', ')}`,
        keywords: noSearchMatches,
        category: SearchCategory.NONE
      };
      Logger.info('SearchDecisionEngine', `决策结果: ${JSON.stringify(decision)}`);
      return decision;
    }

    // 检查实时信息关键词（权重: 0.5）
    const realTimeMatches = this.findMatchingKeywords(lowerMessage, this.realTimeKeywords);
    if (realTimeMatches.length > 0) {
      const score = Math.min(realTimeMatches.length * 0.5, 1.0);
      totalScore += score;
      detectedKeywords.push(...realTimeMatches);
      category = SearchCategory.REAL_TIME;
      Logger.info('SearchDecisionEngine', `检测到实时信息关键词: ${realTimeMatches.join(', ')}, 得分: ${score}`);
    }

    // 检查技术查询关键词（权重: 0.4）
    const technicalMatches = this.findMatchingKeywords(lowerMessage, this.technicalKeywords);
    if (technicalMatches.length > 0) {
      const score = Math.min(technicalMatches.length * 0.4, 0.8);
      totalScore += score;
      detectedKeywords.push(...technicalMatches);
      if (category === SearchCategory.NONE) {
        category = SearchCategory.TECHNICAL;
      }
      Logger.info('SearchDecisionEngine', `检测到技术查询关键词: ${technicalMatches.join(', ')}, 得分: ${score}`);
    }

    // 检查新闻事件关键词（权重: 0.4）
    const newsMatches = this.findMatchingKeywords(lowerMessage, this.newsKeywords);
    if (newsMatches.length > 0) {
      const score = Math.min(newsMatches.length * 0.4, 0.8);
      totalScore += score;
      detectedKeywords.push(...newsMatches);
      if (category === SearchCategory.NONE) {
        category = SearchCategory.NEWS;
      }
      Logger.info('SearchDecisionEngine', `检测到新闻事件关键词: ${newsMatches.join(', ')}, 得分: ${score}`);
    }

    // 检查时事关键词（权重: 0.6）
    const currentAffairsMatches = this.findMatchingKeywords(lowerMessage, this.currentAffairsKeywords);
    if (currentAffairsMatches.length > 0) {
      const score = Math.min(currentAffairsMatches.length * 0.6, 1.0);
      totalScore += score;
      detectedKeywords.push(...currentAffairsMatches);
      if (category === SearchCategory.NONE) {
        category = SearchCategory.CURRENT_AFFAIRS;
      }
      Logger.info('SearchDecisionEngine', `检测到时事关键词: ${currentAffairsMatches.join(', ')}, 得分: ${score}`);
    }

    // 特殊模式检测
    const specialPatterns = this.checkSpecialPatterns(message);
    if (specialPatterns.detected) {
      totalScore += specialPatterns.score;
      detectedKeywords.push(...specialPatterns.keywords);
      if (category === SearchCategory.NONE) {
        category = specialPatterns.category;
      }
      Logger.info('SearchDecisionEngine', `检测到特殊模式: ${specialPatterns.keywords.join(', ')}, 得分: ${specialPatterns.score}`);
    }

    // 组合词加分机制
    const combinationBonus = this.calculateCombinationBonus(detectedKeywords, category);
    if (combinationBonus > 0) {
      totalScore += combinationBonus;
      Logger.info('SearchDecisionEngine', `组合词加分: ${combinationBonus}`);
    }

    // 动态决策阈值：根据类别调整
    const threshold = this.getDynamicThreshold(category);
    const shouldSearch = totalScore >= threshold;
    const confidence = Math.min(totalScore, 1.0);

    let reason = '';
    if (shouldSearch) {
      reason = `检测到需要实时信息的内容，置信度: ${confidence.toFixed(2)}，类别: ${category}，阈值: ${threshold.toFixed(2)}`;
    } else {
      reason = `内容不需要联网搜索，置信度不足 (${confidence.toFixed(2)} < ${threshold.toFixed(2)})`;
    }

    const decision: SearchDecision = {
      shouldSearch,
      confidence,
      reason,
      keywords: Array.from(new Set(detectedKeywords)), // 去重
      category
    };

    Logger.info('SearchDecisionEngine', `=== 搜索决策完成 ===`);
    Logger.info('SearchDecisionEngine', `最终决策: ${shouldSearch ? '需要搜索' : '不需要搜索'}`);
    Logger.info('SearchDecisionEngine', `置信度: ${confidence.toFixed(2)}`);
    Logger.info('SearchDecisionEngine', `决策原因: ${reason}`);
    Logger.info('SearchDecisionEngine', `检测关键词: ${detectedKeywords.join(', ')}`);
    Logger.info('SearchDecisionEngine', `搜索类别: ${category}`);

    return decision;
  }

  /**
   * 查找匹配的关键词
   */
  private findMatchingKeywords(message: string, keywords: string[]): string[] {
    const matches: string[] = [];
    for (const keyword of keywords) {
      if (message.includes(keyword.toLowerCase())) {
        matches.push(keyword);
      }
    }
    return matches;
  }

  /**
   * 检查特殊模式
   */
  private checkSpecialPatterns(message: string): SpecialPatternResult {
    const lowerMessage = message.toLowerCase();
    let detected = false;
    let score = 0;
    const keywords: string[] = [];
    let category = SearchCategory.FACTUAL;

    // 天气查询特殊模式
    const weatherPatterns = [
      /(.+)天气.+[今天|现在|实时|当前|此刻]/i,
      /[今天|现在|实时|当前|此刻].+(.+)天气/i,
      /(.+)气温.+[今天|现在]/i,
      /(.+)天气怎么样/i,
      /(.+)天气如何/i,
      /实时(.+)天气/i,
      /(.+)天气预报/i
    ];
    
    for (const pattern of weatherPatterns) {
      if (pattern.test(message)) {
        detected = true;
        score += 0.5; // 天气查询特殊模式高分
        keywords.push('天气查询模式');
        category = SearchCategory.CURRENT_AFFAIRS;
        Logger.info('SearchDecisionEngine', '检测到天气查询特殊模式');
        break;
      }
    }

    // 问号结尾的事实性问题
    if (message.includes('?') || message.includes('？')) {
      // 检查是否是事实性查询
      const factualPatterns = [
        /谁是/i, /什么时候/i, /在哪里/i, /多少/i, /哪个公司/i, /哪家公司/i,
        /who is/i, /when did/i, /where is/i, /how much/i, /which company/i
      ];
      
      for (const pattern of factualPatterns) {
        if (pattern.test(message)) {
          detected = true;
          score += 0.2;
          keywords.push('事实性查询');
          break;
        }
      }
    }

    // 版本相关查询
    const versionPatterns = [
      /版本.*是什么/i, /最新版本/i, /当前版本/i, /version.*latest/i, /current.*version/i
    ];
    
    for (const pattern of versionPatterns) {
      if (pattern.test(message)) {
        detected = true;
        score += 0.3;
        keywords.push('版本查询');
        category = SearchCategory.TECHNICAL;
        break;
      }
    }

    // 价格和市场信息查询
    const pricePatterns = [
      /价格.*多少/i, /多少钱/i, /费用/i, /cost.*how much/i, /price.*of/i
    ];
    
    for (const pattern of pricePatterns) {
      if (pattern.test(message)) {
        detected = true;
        score += 0.3;
        keywords.push('价格查询');
        category = SearchCategory.CURRENT_AFFAIRS;
        break;
      }
    }

    // 实时信息查询模式
    const realTimePatterns = [
      /现在(.+)怎么样/i,
      /(.+)现在的情况/i,
      /最新(.+)消息/i,
      /(.+)最新进展/i,
      /实时(.+)/i,
      /(.+)动态更新/i
    ];
    
    for (const pattern of realTimePatterns) {
      if (pattern.test(message)) {
        detected = true;
        score += 0.4;
        keywords.push('实时信息查询模式');
        category = SearchCategory.REAL_TIME;
        break;
      }
    }

    return { detected, score, keywords, category };
  }

  /**
   * 生成搜索查询词
   * 基于原始消息和检测到的关键词优化搜索查询
   */
  generateSearchQuery(originalMessage: string, decision: SearchDecision): string {
    Logger.info('SearchDecisionEngine', `生成搜索查询词`);
    Logger.info('SearchDecisionEngine', `原始消息: "${originalMessage}"`);
    Logger.info('SearchDecisionEngine', `搜索类别: ${decision.category}`);

    let searchQuery = originalMessage.trim();

    // 根据搜索类别优化查询
    switch (decision.category) {
      case SearchCategory.REAL_TIME:
        // 添加时间限定词
        if (!searchQuery.includes('最新') && !searchQuery.includes('2024') && !searchQuery.includes('2025')) {
          searchQuery = `最新 ${searchQuery}`;
        }
        break;

      case SearchCategory.TECHNICAL:
        // 技术查询通常已经很明确，保持原样
        break;

      case SearchCategory.NEWS:
        // 新闻查询添加新闻限定词
        if (!searchQuery.includes('新闻') && !searchQuery.includes('报道')) {
          searchQuery = `${searchQuery} 新闻`;
        }
        break;

      case SearchCategory.CURRENT_AFFAIRS:
        // 时事查询保持原样，通常比较明确
        break;

      case SearchCategory.FACTUAL:
        // 事实查询保持原样
        break;

      default:
        break;
    }

    // 限制查询长度
    if (searchQuery.length > 100) {
      searchQuery = searchQuery.substring(0, 100);
    }

    Logger.info('SearchDecisionEngine', `优化后的搜索查询: "${searchQuery}"`);
    return searchQuery;
  }

  /**
   * 计算组合词加分
   */
  private calculateCombinationBonus(detectedKeywords: string[], category: SearchCategory): number {
    let bonus = 0;
    
    // 天气查询组合加分：时间 + 天气 + 地理位置
    const hasTimeKeyword = detectedKeywords.some(k => ['今天', '现在', '今天', '实时', '最新'].includes(k));
    const hasWeatherKeyword = detectedKeywords.some(k => ['天气', '气温', '温度', '天气情况'].includes(k));
    const hasLocationKeyword = detectedKeywords.some(k => ['吴江', '苏州', '上海', '北京', '广州'].includes(k));
    
    if (hasTimeKeyword && hasWeatherKeyword && hasLocationKeyword) {
      bonus += 0.4; // 天气查询组合最高加分
      Logger.info('SearchDecisionEngine', '检测到完整的天气查询组合，加0.4分');
    } else if (hasTimeKeyword && hasWeatherKeyword) {
      bonus += 0.2; // 时间+天气组合
      Logger.info('SearchDecisionEngine', '检测到时间+天气组合，加0.2分');
    } else if (hasWeatherKeyword && hasLocationKeyword) {
      bonus += 0.15; // 天气+地理位置组合
      Logger.info('SearchDecisionEngine', '检测到天气+地理位置组合，加0.15分');
    }
    
    // 技术查询组合加分：技术词 + 问题词
    const hasTechKeyword = detectedKeywords.some(k => ['API', 'SDK', '版本', '文档', '教程'].includes(k));
    const hasQuestionKeyword = detectedKeywords.some(k => ['如何', '怎么', '什么是', '为什么'].includes(k));
    
    if (hasTechKeyword && hasQuestionKeyword) {
      bonus += 0.2; // 技术+问题组合
      Logger.info('SearchDecisionEngine', '检测到技术+问题组合，加0.2分');
    }
    
    // 新闻查询组合加分：时间 + 事件词
    const hasNewsKeyword = detectedKeywords.some(k => ['新闻', '事件', '消息', '动态'].includes(k));
    
    if (hasTimeKeyword && hasNewsKeyword) {
      bonus += 0.25; // 时间+新闻组合
      Logger.info('SearchDecisionEngine', '检测到时间+新闻组合，加0.25分');
    }
    
    return Math.min(bonus, 0.5); // 最大加分不超过0.5
  }

  /**
   * 获取动态决策阈值
   */
  private getDynamicThreshold(category: SearchCategory): number {
    switch (category) {
      case SearchCategory.REAL_TIME:
        return 0.2; // 实时信息阈值较低
      case SearchCategory.CURRENT_AFFAIRS:
        return 0.15; // 时事信息阈值最低
      case SearchCategory.NEWS:
        return 0.25; // 新闻事件阈值中等
      case SearchCategory.TECHNICAL:
        return 0.3; // 技术查询阈值较高
      case SearchCategory.FACTUAL:
        return 0.2; // 事实查询阈值较低
      default:
        return 0.25; // 默认阈值
    }
  }
}