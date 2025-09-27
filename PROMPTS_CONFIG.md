# 提示词JSON配置系统

## 概述

本项目已将原本硬编码在代码中的系统提示词提取到JSON配置文件中，便于管理和修改。

## 文件结构

```
entry/src/main/resources/rawfile/
└── prompts_config.json          # 提示词配置文件

entry/src/main/ets/
├── data/
│   └── DefaultPrompts.ets       # 支持JSON加载的提示词数据类
└── utils/
    └── PromptsConfigManager.ets # 提示词配置管理器
```

## JSON配置文件格式

### 基本结构

```json
{
  "version": "1.0.0",
  "lastUpdated": "2025-09-28",
  "prompts": {
    "professional": [...],  // 专业类提示词
    "character": [...]      // 人物角色类提示词
  },
  "categories": [...],      // 分类信息
  "metadata": {             // 元数据
    "totalPrompts": 26,
    "professionalCount": 16,
    "characterCount": 10,
    "formatVersion": "1.0.0",
    "compatibilityLevel": "harmonyos-5.0"
  }
}
```

### 提示词格式

每个提示词包含以下字段：

```json
{
  "id": "unique_id",              // 唯一标识符
  "name": "提示词名称",           // 显示名称
  "content": "提示词内容...",      // 详细内容
  "shortDescription": "简短描述", // 简短描述
  "category": "professional",     // 分类(professional/character)
  "icon": "🤖",                  // 图标
  "isRole": true,                // 是否为角色类型
  "tags": ["标签1", "标签2"]      // 标签数组
}
```

## 使用方法

### 1. 获取提示词实例

```typescript
// 方法1: 使用配置管理器（推荐）
import { PromptsConfigManager } from '../utils/PromptsConfigManager';

const manager = PromptsConfigManager.getInstance();

// 异步获取所有提示词
const prompts = await manager.getAllPrompts();

// 同步获取所有提示词（用于向后兼容）
const promptsSync = manager.getAllPromptsSync();

// 按分类获取
const professionalPrompts = manager.getPromptsByCategory('professional');
const characterPrompts = manager.getPromptsByCategory('character');

// 搜索提示词
const searchResults = manager.searchPrompts('编程');
```

### 2. 直接使用DefaultPrompts（传统方式）

```typescript
import { DefaultPrompts } from '../data/DefaultPrompts';

// 异步方式（推荐）
const prompts = await DefaultPrompts.getAllPrompts();

// 同步方式（向后兼容）
const promptsSync = DefaultPrompts.getAllPromptsSync();

// 重新加载配置
const reloadedPrompts = await DefaultPrompts.reloadPrompts();
```

## 配置管理特性

### 1. 智能缓存
- 首次加载后会缓存结果
- 支持强制重新加载
- 异步加载失败时自动降级到硬编码版本

### 2. 错误处理
- JSON解析失败时使用硬编码后备
- 详细的错误日志记录
- 优雅降级机制

### 3. 性能优化
- 预加载机制
- 单例模式避免重复加载
- 同步/异步双重接口

## 修改提示词

### 1. 编辑JSON文件

直接编辑 `entry/src/main/resources/rawfile/prompts_config.json` 文件：

1. **新增提示词**: 在对应分类下添加新的提示词对象
2. **修改提示词**: 编辑已有提示词的字段
3. **删除提示词**: 从数组中移除对应对象
4. **更新元数据**: 修改后记得更新metadata中的计数

### 2. 验证配置

使用内置验证检查配置文件格式：

```bash
# 可以自己编写简单的Node.js验证脚本
node -e "
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('entry/src/main/resources/rawfile/prompts_config.json', 'utf8'));
console.log('配置验证通过, 总计:', config.metadata.totalPrompts, '个提示词');
"
```

### 3. 应用重启

修改JSON文件后，重启应用即可生效。或者调用重新加载方法：

```typescript
const manager = PromptsConfigManager.getInstance();
await manager.reloadConfig();
```

## 最佳实践

### 1. 提示词设计
- **名称**: 简洁明了，体现角色特色
- **内容**: 结构化，包含角色定位、专长、风格等
- **标签**: 便于搜索和分类
- **图标**: 选择代表性的emoji

### 2. ID命名规范
- 使用蛇形命名法：`snake_case`
- 体现分类：`professional_`, `character_`
- 描述性：体现功能或角色特征

### 3. 分类管理
- **professional**: 专业技能类，如架构师、翻译专家
- **character**: 虚拟角色类，如船长、隐士

### 4. 版本控制
- 修改后更新 `lastUpdated` 字段
- 重大格式变更时更新 `version` 和 `formatVersion`
- 保持 `metadata` 计数准确

## 迁移说明

本次改动完全移除了硬编码提示词，实现了纯JSON配置系统：

1. **硬编码移除**: 所有硬编码提示词已从代码中移除，仅保留1个应急后备提示词
2. **API接口**: 保持向后兼容，内部实现完全改为JSON加载
3. **后备机制**: JSON加载失败时使用最小的应急提示词（基础功能）
4. **配置优先**: 系统现在完全依赖JSON配置文件，无任何硬编码内容

## 故障排除

### 1. JSON解析失败
- 检查JSON格式是否正确
- 验证必要字段是否缺失
- 查看控制台错误日志

### 2. 提示词加载失败
- 检查资源文件是否正确放置
- 验证应用权限设置
- 确认文件路径正确

### 3. 缓存问题
- 调用 `clearCache()` 清除缓存
- 重启应用重新加载
- 检查单例实例状态

## 技术细节

### 1. 加载机制
- 使用 `resourceManager` 读取rawfile资源
- 异步加载主流程，同步加载作为后备
- 智能缓存避免重复加载

### 2. 类型安全
- 完整的TypeScript接口定义
- 严格的类型检查
- 运行时验证机制

### 3. 错误恢复
- 多层级错误处理
- 优雅降级策略
- 详细日志记录

## 未来扩展

1. **在线配置**: 支持从服务器动态加载配置
2. **用户自定义**: 允许用户添加自定义提示词
3. **A/B测试**: 支持多套配置方案切换
4. **本地化**: 支持多语言配置文件