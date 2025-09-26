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