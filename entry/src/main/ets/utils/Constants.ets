interface LanguageNames {
  python: string;
  javascript: string;
  go: string;
  bash: string;
}

export interface PromptTemplate {
  id: string;
  title: string;
  description: string;
  prompt: string;
  category: PromptCategory;
  icon: string;
  color: string;
  backgroundColor: string;
  isParameterized?: boolean;
  parameters?: string[];
  voiceTriggers?: string[];
}

export interface PromptCategory {
  id: string;
  name: string;
  description: string;
  icon: string;
  color: string;
}

/**
 * 常量定义
 */
export class Constants {
  // 服务器配置 - 现在从配置管理器获取
  // 静态配置已移除，请使用 AppConfigManager.getInstance().getServerConfig()
  
  // API端点 - 现在从配置管理器获取
  // 静态配置已移除，请使用 AppConfigManager.getInstance().getApiConfig()
  
  // 默认配置
  static readonly DEFAULT_PROVIDER = 'siliconflow'; // 已从 google 更改 (Gemini已禁用)
  static readonly DEFAULT_MODEL = 'Qwen/Qwen2.5-7B-Instruct'; // 已从 gemini-2.5-flash 更改 (Gemini已禁用)
  static readonly DEFAULT_LANGUAGE = 'python';
  
  // UI常量
  static readonly MAX_MESSAGE_WIDTH = '70%';
  static readonly ANIMATION_DURATION = 300;
  static readonly DEBOUNCE_TIME = 500;
  static readonly STATUS_BAR_HEIGHT = 44; // 状态栏高度，用于沉浸式布局避让
  
  // 支持的编程语言
  static readonly SUPPORTED_LANGUAGES = ['python', 'javascript', 'go', 'bash'];
  
  // 语言显示名称映射
  static readonly LANGUAGE_DISPLAY_NAMES: LanguageNames = {
    python: 'Python',
    javascript: 'JavaScript', 
    go: 'Go',
    bash: 'Bash'
  };

  // Prompt 模板分类
  static readonly PROMPT_CATEGORIES: PromptCategory[] = [
    {
      id: 'thinking',
      name: '思考引导',
      description: '引导AI更深入地思考和分析',
      icon: '🧠',
      color: '#4A90E2'
    },
    {
      id: 'format',
      name: '格式输出',
      description: '控制AI输出的格式和结构',
      icon: '📝',
      color: '#7B68EE'
    },
    {
      id: 'role',
      name: '角色扮演',
      description: '让AI扮演特定的专业角色',
      icon: '🎭',
      color: '#FF6B6B'
    },
    {
      id: 'creative',
      name: '创意激发',
      description: '激发AI的创造性思维',
      icon: '💡',
      color: '#FFA500'
    },
    {
      id: 'quality',
      name: '质量控制',
      description: '确保输出质量和准确性',
      icon: '✅',
      color: '#32CD32'
    }
  ];

  // 预定义的 Prompt 模板
  static readonly PROMPT_TEMPLATES: PromptTemplate[] = [
    // 思考引导类
    {
      id: 'ask_questions',
      title: '提出深度问题',
      description: '让AI在听完想法后提出三个深度问题',
      prompt: '请提出听完我想法后的三个问题？',
      category: this.PROMPT_CATEGORIES[0],
      icon: '🤔',
      color: '#4A90E2',
      backgroundColor: '#E3F2FD',
      voiceTriggers: ['提问', '问题', '深度思考']
    },
    {
      id: 'step_analysis',
      title: '逐步分析',
      description: '用思维链方法分析复杂问题',
      prompt: '用思维链方法逐步分析这个问题，先分解要点，再逐一展开分析',
      category: this.PROMPT_CATEGORIES[0],
      icon: '📊',
      color: '#4A90E2',
      backgroundColor: '#E3F2FD',
      voiceTriggers: ['逐步分析', '分析问题', '思维链']
    },
    {
      id: 'multi_perspective',
      title: '多角度分析',
      description: '从多个角度分析问题',
      prompt: '从多个角度分析这个问题，然后给出综合结论',
      category: this.PROMPT_CATEGORIES[0],
      icon: '🔍',
      color: '#4A90E2',
      backgroundColor: '#E3F2FD',
      voiceTriggers: ['多角度', '全面分析']
    },

    // 格式输出类
    {
      id: 'bullet_summary',
      title: '要点总结',
      description: '用3个要点总结，每点不超过50字',
      prompt: '用3个要点总结，每点不超过50字',
      category: this.PROMPT_CATEGORIES[1],
      icon: '📋',
      color: '#7B68EE',
      backgroundColor: '#F3E5F5',
      voiceTriggers: ['总结', '要点', '概括']
    },
    {
      id: 'markdown_format',
      title: 'Markdown格式',
      description: '以markdown格式输出，包含标题和列表',
      prompt: '以markdown格式输出，包含标题、子标题和列表',
      category: this.PROMPT_CATEGORIES[1],
      icon: '📄',
      color: '#7B68EE',
      backgroundColor: '#F3E5F5',
      voiceTriggers: ['格式化', 'markdown']
    },
    {
      id: 'action_steps',
      title: '行动清单',
      description: '给出具体的行动步骤清单',
      prompt: '给出具体的行动步骤清单，按优先级排序',
      category: this.PROMPT_CATEGORIES[1],
      icon: '✔️',
      color: '#7B68EE',
      backgroundColor: '#F3E5F5',
      voiceTriggers: ['行动', '步骤', '清单']
    },

    // 角色扮演类
    {
      id: 'programmer_review',
      title: '程序员审查',
      description: '作为资深程序员审查代码',
      prompt: '作为资深程序员，请审查这段代码，指出潜在问题和改进建议',
      category: this.PROMPT_CATEGORIES[2],
      icon: '👨‍💻',
      color: '#FF6B6B',
      backgroundColor: '#FFEBEE',
      voiceTriggers: ['代码审查', '程序员', '审查代码']
    },
    {
      id: 'product_manager',
      title: '产品经理视角',
      description: '以产品经理的视角分析需求',
      prompt: '以产品经理的视角分析这个需求，考虑用户体验、商业价值和技术可行性',
      category: this.PROMPT_CATEGORIES[2],
      icon: '👔',
      color: '#FF6B6B',
      backgroundColor: '#FFEBEE',
      voiceTriggers: ['产品经理', '需求分析', '产品视角']
    },
    {
      id: 'teacher_explain',
      title: '老师讲解',
      description: '用老师的方式解释概念',
      prompt: '用老师的方式详细解释这个概念，使用通俗易懂的语言和例子',
      category: this.PROMPT_CATEGORIES[2],
      icon: '👩‍🏫',
      color: '#FF6B6B',
      backgroundColor: '#FFEBEE',
      voiceTriggers: ['解释', '讲解', '教学']
    },

    // 创意激发类
    {
      id: 'five_solutions',
      title: '五种方案',
      description: '提供5种不同的解决方案',
      prompt: '提供5种不同的解决方案，每种方案说明优缺点',
      category: this.PROMPT_CATEGORIES[3],
      icon: '💫',
      color: '#FFA500',
      backgroundColor: '#FFF3E0',
      voiceTriggers: ['方案', '解决方案', '创意']
    },
    {
      id: 'different_angle',
      title: '换个角度',
      description: '换个完全不同的角度思考',
      prompt: '换个完全不同的角度思考这个问题，打破常规思维',
      category: this.PROMPT_CATEGORIES[3],
      icon: '🔄',
      color: '#FFA500',
      backgroundColor: '#FFF3E0',
      voiceTriggers: ['换角度', '不同角度', '创新思维']
    },
    {
      id: 'no_limits',
      title: '无限制思考',
      description: '如果没有任何限制，你会怎么做？',
      prompt: '如果没有任何限制（时间、资源、技术），你会怎么解决这个问题？',
      category: this.PROMPT_CATEGORIES[3],
      icon: '🚀',
      color: '#FFA500',
      backgroundColor: '#FFF3E0',
      voiceTriggers: ['无限制', '理想情况', '大胆想象']
    },

    // 质量控制类
    {
      id: 'logic_check',
      title: '逻辑检查',
      description: '检查逻辑漏洞并指出',
      prompt: '检查以上内容的逻辑漏洞并指出，提供改进建议',
      category: this.PROMPT_CATEGORIES[4],
      icon: '🔍',
      color: '#32CD32',
      backgroundColor: '#E8F5E8',
      voiceTriggers: ['检查逻辑', '逻辑漏洞', '验证']
    },
    {
      id: 'risk_analysis',
      title: '风险评估',
      description: '找出可能的风险点',
      prompt: '找出这个方案可能存在的风险点，按严重程度排序，以及你打算怎么应对',
      category: this.PROMPT_CATEGORIES[4],
      icon: '⚠️',
      color: '#32CD32',
      backgroundColor: '#E8F5E8',
      voiceTriggers: ['风险', '风险评估', '潜在问题']
    },
    {
      id: 'fact_verify',
      title: '事实验证',
      description: '验证信息的准确性',
      prompt: '验证以上信息的准确性，指出可能不准确的地方',
      category: this.PROMPT_CATEGORIES[4],
      icon: '✅',
      color: '#32CD32',
      backgroundColor: '#E8F5E8',
      voiceTriggers: ['验证', '事实检查', '准确性']
    }
  ];

  // 常用快捷命令映射表
  static readonly SLASH_COMMANDS = new Map([
    ['summary', '/总结'],
    ['analyze', '/分析'],
    ['explain', '/解释'],
    ['review', '/审查'],
    ['improve', '/改进'],
    ['creative', '/创意'],
    ['question', '/提问']
  ]);
}