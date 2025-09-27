/**
 * 记忆系统类型定义
 * 定义用户记忆管理相关的数据结构
 */

// 记忆碎片接口
export interface MemoryFragment {
  id: string;
  content: string; // 记忆内容，如"我喜欢喝拿铁咖啡"
  tags: string[]; // 标签，用于分类和搜索
  category: MemoryCategory; // 记忆分类
  importance: MemoryImportance; // 重要程度
  isActive: boolean; // 是否激活（会在对话中注入）
  createdAt: number; // 创建时间戳
  updatedAt: number; // 更新时间戳
  usageCount: number; // 使用次数统计
  lastUsedAt: number; // 最后使用时间
  vector?: number[]; // 向量表示，用于语义搜索
}

// 记忆项接口（带标题）
export interface MemoryItem {
  id: string;
  title: string; // 记忆标题
  content: string; // 记忆内容，如"我喜欢喝拿铁咖啡"
  tags: string[]; // 标签，用于分类和搜索
  category: MemoryCategory; // 记忆分类
  importance: MemoryImportance; // 重要程度
  isActive: boolean; // 是否激活（会在对话中注入）
  createdAt: number; // 创建时间戳
  updatedAt: number; // 更新时间戳
  usageCount: number; // 使用次数统计
  lastUsedAt: number; // 最后使用时间
}

// 记忆分类枚举
export enum MemoryCategory {
  PERSONAL = 'personal', // 个人信息
  PREFERENCE = 'preference', // 个人偏好
  WORK = 'work', // 工作相关
  STUDY = 'study', // 学习相关
  HOBBY = 'hobby', // 兴趣爱好
  FAMILY = 'family', // 家庭信息
  HEALTH = 'health', // 健康信息
  CUSTOM = 'custom' // 自定义分类
}

// 记忆分类类型（字符串联合类型）
export type MemoryCategoryType = 'personal' | 'preference' | 'work' | 'study' | 'hobby' | 'family' | 'health' | 'custom' | 'all';

// 记忆重要程度枚举
export enum MemoryImportance {
  LOW = 'low', // 低重要性
  MEDIUM = 'medium', // 中等重要性
  HIGH = 'high', // 高重要性
  CRITICAL = 'critical' // 关键重要性
}

// 记忆重要性类型（字符串联合类型）
export type MemoryImportanceType = 'low' | 'medium' | 'high' | 'critical' | 'all';

// 记忆搜索结果接口
export interface MemorySearchResult {
  fragment: MemoryFragment;
  matchScore: number; // 匹配分数(0-1)
  matchReason: string; // 匹配原因
}

// 记忆分类统计接口
export interface MemoryCategoryCounts {
  personal: number;
  preference: number;
  work: number;
  study: number;
  hobby: number;
  family: number;
  health: number;
  custom: number;
}

// 记忆重要性统计接口
export interface MemoryImportanceCounts {
  low: number;
  medium: number;
  high: number;
  critical: number;
}

// 记忆统计接口
export interface MemoryStats {
  totalFragments: number; // 总记忆数量
  activeFragments: number; // 激活的记忆数量
  categoryCounts: MemoryCategoryCounts; // 各分类数量
  importanceCounts: MemoryImportanceCounts; // 各重要性级别数量
  lastUpdated: number; // 最后更新时间
  totalUsageCount: number; // 总使用次数
}

// 可观察的记忆分类统计类
@ObservedV2
export class ObservableMemoryCategoryCounts {
  @Trace personal: number = 0;
  @Trace preference: number = 0;
  @Trace work: number = 0;
  @Trace study: number = 0;
  @Trace hobby: number = 0;
  @Trace family: number = 0;
  @Trace health: number = 0;
  @Trace custom: number = 0;

  updateFromCounts(counts: MemoryCategoryCounts): void {
    this.personal = counts.personal;
    this.preference = counts.preference;
    this.work = counts.work;
    this.study = counts.study;
    this.hobby = counts.hobby;
    this.family = counts.family;
    this.health = counts.health;
    this.custom = counts.custom;
  }

  toCategoryCounts(): MemoryCategoryCounts {
    return {
      personal: this.personal,
      preference: this.preference,
      work: this.work,
      study: this.study,
      hobby: this.hobby,
      family: this.family,
      health: this.health,
      custom: this.custom
    };
  }
}

// 可观察的记忆重要性统计类
@ObservedV2
export class ObservableMemoryImportanceCounts {
  @Trace low: number = 0;
  @Trace medium: number = 0;
  @Trace high: number = 0;
  @Trace critical: number = 0;

  updateFromCounts(counts: MemoryImportanceCounts): void {
    this.low = counts.low;
    this.medium = counts.medium;
    this.high = counts.high;
    this.critical = counts.critical;
  }

  toImportanceCounts(): MemoryImportanceCounts {
    return {
      low: this.low,
      medium: this.medium,
      high: this.high,
      critical: this.critical
    };
  }
}

// 可观察的记忆统计类
@ObservedV2
export class ObservableMemoryStats {
  @Trace totalFragments: number = 0;
  @Trace activeFragments: number = 0;
  @Trace totalUsageCount: number = 0;
  @Trace lastUpdated: number = 0;
  @Trace categoryCounts: ObservableMemoryCategoryCounts = new ObservableMemoryCategoryCounts();
  @Trace importanceCounts: ObservableMemoryImportanceCounts = new ObservableMemoryImportanceCounts();

  constructor(stats?: MemoryStats) {
    if (stats) {
      this.updateFromStats(stats);
    }
  }

  updateFromStats(stats: MemoryStats): void {
    this.totalFragments = stats.totalFragments;
    this.activeFragments = stats.activeFragments;
    this.totalUsageCount = stats.totalUsageCount;
    this.lastUpdated = stats.lastUpdated;

    // 使用嵌套可观察对象的更新方法
    this.categoryCounts.updateFromCounts(stats.categoryCounts);
    this.importanceCounts.updateFromCounts(stats.importanceCounts);
  }

  toMemoryStats(): MemoryStats {
    return {
      totalFragments: this.totalFragments,
      activeFragments: this.activeFragments,
      totalUsageCount: this.totalUsageCount,
      lastUpdated: this.lastUpdated,
      categoryCounts: this.categoryCounts.toCategoryCounts(),
      importanceCounts: this.importanceCounts.toImportanceCounts()
    };
  }
}

// 记忆导出元数据接口
export interface MemoryExportMetadata {
  totalCount: number;
  activeCount: number;
}

// 记忆导入导出接口
export interface MemoryExportData {
  version: string; // 导出版本
  exportTime: number; // 导出时间
  fragments: MemoryFragment[]; // 记忆碎片列表
  metadata: MemoryExportMetadata;
}

// 记忆创建请求接口
export interface CreateMemoryRequest {
  content: string;
  tags?: string[];
  category?: MemoryCategory;
  importance?: MemoryImportance;
  isActive?: boolean;
}

// 记忆更新请求接口
export interface UpdateMemoryRequest {
  content?: string;
  tags?: string[];
  category?: MemoryCategory;
  importance?: MemoryImportance;
  isActive?: boolean;
}

// 记忆日期范围接口
export interface MemoryDateRange {
  start: number;
  end: number;
}

// 记忆过滤选项接口
export interface MemoryFilterOptions {
  categories?: MemoryCategory[];
  importances?: MemoryImportance[];
  isActive?: boolean;
  tags?: string[];
  keywords?: string[];
  dateRange?: MemoryDateRange;
}

// 记忆排序选项枚举
export enum MemorySortBy {
  CREATED_TIME = 'created_time',
  UPDATED_TIME = 'updated_time',
  USAGE_COUNT = 'usage_count',
  LAST_USED = 'last_used',
  IMPORTANCE = 'importance',
  CONTENT = 'content'
}

// 记忆排序方向枚举
export enum MemorySortDirection {
  ASC = 'asc',
  DESC = 'desc'
}

// 记忆排序选项接口
export interface MemorySortOptions {
  sortBy: MemorySortBy;
  direction: MemorySortDirection;
}

// 记忆分页选项接口
export interface MemoryPaginationOptions {
  page: number; // 页码，从1开始
  pageSize: number; // 每页大小
}

// 分页结果接口
export interface MemoryPageResult {
  fragments: MemoryFragment[];
  total: number; // 总数量
  page: number; // 当前页码
  pageSize: number; // 每页大小
  totalPages: number; // 总页数
}

// 记忆注入配置接口
export interface MemoryInjectionConfig {
  enabled: boolean; // 是否启用记忆注入
  maxFragments: number; // 最大注入数量
  includeCategories: MemoryCategory[]; // 包含的分类
  excludeCategories: MemoryCategory[]; // 排除的分类
  minImportance: MemoryImportance; // 最小重要性级别
  sortByUsage: boolean; // 是否按使用频率排序
  template: string; // 注入模板
}

// 记忆管理器操作结果接口
export interface MemoryOperationResult {
  success: boolean;
  message: string;
  data?: MemoryFragment | MemoryFragment[];
}

// 记忆备份信息接口
export interface MemoryBackupInfo {
  id: string;
  name: string;
  createTime: number;
  fragmentCount: number;
  size: number; // 备份大小（字节）
}

// 记忆同步状态枚举
export enum MemorySyncStatus {
  IDLE = 'idle',
  SYNCING = 'syncing',
  SUCCESS = 'success',
  FAILED = 'failed'
}

// 记忆同步结果接口
export interface MemorySyncResult {
  status: MemorySyncStatus;
  message: string;
  syncTime: number;
  addedCount: number;
  updatedCount: number;
  deletedCount: number;
}

// 向量搜索配置接口
export interface VectorSearchConfig {
  enabled: boolean;
  hybridSearch: boolean;
  vectorWeight: number;
  keywordWeight: number;
  minSimilarity: number;
  maxResults: number;
}

// 向量服务状态接口
export interface VectorServiceStatus {
  modelLoaded: boolean;
  modelName: string;
  embeddingDimension: number;
  totalEmbeddings: number;
  averageGenerationTime: number;
}

// 混合搜索结果接口
export interface HybridSearchResult {
  memory: MemoryFragment;
  finalScore: number;
  vectorScore: number;
  keywordScore: number;
}

// 向量搜索结果接口
export interface VectorSearchResult {
  memory: MemoryFragment;
  similarity: number;
}

// 向量迁移状态接口
export interface VectorMigrationStatus {
  totalMemories: number;
  memoriesWithVectors: number;
  memoriesWithoutVectors: number;
  migrationNeeded: boolean;
}

// ====== 用户主动触发记忆功能扩展 ======

// 记忆触发源类型
export enum MemoryTriggerSource {
  USER_COMMAND = 'user_command',    // 用户通过指令触发（如"记住："）
  USER_CLICK = 'user_click',        // 用户点击按钮触发
  SYSTEM_AUTO = 'system_auto'       // 系统自动保存（预留）
}

// 记忆内容类型
export enum MemoryContentType {
  TEXT = 'text',                    // 纯文本记忆
  CODE = 'code',                    // 代码片段
  CONVERSATION = 'conversation',    // 完整对话
  MESSAGE = 'message'               // 单条消息
}

// 用户记忆项（扩展了基础MemoryFragment）
export interface UserMemoryItem extends MemoryFragment {
  title: string;                    // 记忆标题（自动生成或用户指定）
  contentType: MemoryContentType;   // 内容类型
  triggerSource: MemoryTriggerSource; // 触发来源
  sessionId?: string;               // 所属会话ID
  messageId?: string;               // 相关消息ID
  originalContext?: string;         // 原始上下文
}

// 记忆指令解析结果
export interface MemoryCommandParseResult {
  isMemoryCommand: boolean;         // 是否为记忆指令
  command: string;                  // 识别的指令类型
  content: string;                  // 提取的内容
  title?: string;                   // 自定义标题（如果有）
  tags?: string[];                  // 提取的标签（如果有）
  category?: MemoryCategory;        // 推断的分类
}

// 支持的记忆指令
export interface MemoryCommand {
  trigger: string;                  // 触发词（如"记住"、"记下"）
  pattern: RegExp;                  // 匹配正则表达式
  description: string;              // 指令描述
  example: string;                  // 使用示例
}

// 记忆保存请求（用户触发）
export interface SaveUserMemoryRequest {
  content: string;                  // 必填：记忆内容
  title?: string;                   // 可选：自定义标题
  contentType?: MemoryContentType;  // 可选：内容类型，默认为TEXT
  triggerSource: MemoryTriggerSource; // 必填：触发来源
  sessionId?: string;               // 可选：会话ID
  messageId?: string;               // 可选：消息ID
  tags?: string[];                  // 可选：标签
  category?: MemoryCategory;        // 可选：分类
  importance?: MemoryImportance;    // 可选：重要程度
  originalContext?: string;         // 可选：原始上下文
}

// 记忆操作反馈
export interface MemoryOperationFeedback {
  success: boolean;                 // 操作是否成功
  message: string;                  // 反馈消息
  memoryId?: string;                // 创建的记忆ID
  title?: string;                   // 记忆标题
  action: 'save' | 'update' | 'delete'; // 操作类型
}

// 记忆快速操作
export interface MemoryQuickAction {
  id: string;                       // 操作ID
  title: string;                    // 操作标题
  icon: string;                     // 操作图标
  description: string;              // 操作描述
  handler: (memoryId: string) => Promise<void>; // 操作处理器
}

// 记忆管理器配置
export interface UserMemoryManagerConfig {
  autoGenerateTitle: boolean;       // 是否自动生成标题
  maxTitleLength: number;           // 标题最大长度
  defaultCategory: MemoryCategory;  // 默认分类
  defaultImportance: MemoryImportance; // 默认重要程度
  enableTagSuggestion: boolean;     // 是否启用标签建议
  maxRecentMemories: number;        // 最近记忆显示数量
  enableExportImport: boolean;      // 是否启用导入导出
}