# 日程管理MCP工具使用示例

## 工具概述

日程管理MCP工具 (`calendar_manager`) 提供了完整的日程管理功能，包括：

- 创建、更新、删除日程事件
- 查询日程事件
- 创建、删除日历
- 获取日历列表

## 权限要求

使用此工具需要以下权限：
- `ohos.permission.READ_CALENDAR` - 读取日程权限
- `ohos.permission.WRITE_CALENDAR` - 写入日程权限

## 使用示例

### 1. 创建日程事件

```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "create_event",
    "title": "团队会议",
    "startTime": 1703664000000,
    "endTime": 1703667600000,
    "description": "讨论项目进展和下阶段计划",
    "location": "会议室A",
    "isAllDay": false,
    "remindTime": [-15, -60],
    "recurrenceRule": "FREQ=WEEKLY;BYDAY=MO"
  }
}
```

### 2. 查询日程事件

```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "query_events",
    "startTime": 1703664000000,
    "endTime": 1703750400000,
    "title": "团队会议"
  }
}
```

### 3. 更新日程事件

```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "update_event",
    "eventId": 123,
    "title": "团队会议（已推迟）",
    "startTime": 1703670600000,
    "endTime": 1703674200000,
    "location": "会议室B"
  }
}
```

### 4. 删除日程事件

```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "delete_event",
    "eventId": 123
  }
}
```

### 5. 创建新日历

```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "create_calendar",
    "displayName": "工作日历",
    "color": "#FF5722"
  }
}
```

### 6. 获取所有日历

```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "get_calendars"
  }
}
```

### 7. 删除日历

```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "delete_calendar",
    "calendarId": 456
  }
}
```

## 参数说明

### 通用参数

- `operation` (必填): 操作类型
  - `create_event`: 创建事件
  - `update_event`: 更新事件
  - `delete_event`: 删除事件
  - `query_events`: 查询事件
  - `create_calendar`: 创建日历
  - `delete_calendar`: 删除日历
  - `get_calendars`: 获取日历列表

### 事件相关参数

- `title` (string): 事件标题
- `startTime` (number): 开始时间（时间戳，毫秒）
- `endTime` (number): 结束时间（时间戳，毫秒）
- `description` (string, 可选): 事件描述
- `location` (string, 可选): 事件地点
- `isAllDay` (boolean, 可选): 是否全天事件，默认false
- `calendarId` (number, 可选): 日历ID
- `eventId` (number): 事件ID（更新和删除时需要）
- `remindTime` (array, 可选): 提醒时间列表，单位分钟，负数表示提前
- `recurrenceRule` (string, 可选): 重复规则，遵循RFC 5545格式

### 日历相关参数

- `displayName` (string): 日历显示名称
- `color` (string, 可选): 日历颜色，默认蓝色 #1E90FF
- `calendarId` (number): 日历ID（删除时需要）

## 时间格式说明

所有时间参数使用JavaScript时间戳格式（毫秒）：

```javascript
// 2024年12月27日 10:00:00
const startTime = new Date('2024-12-27 10:00:00').getTime(); // 1703664000000

// 2024年12月27日 11:00:00
const endTime = new Date('2024-12-27 11:00:00').getTime(); // 1703667600000
```

## 重复规则示例

重复规则遵循RFC 5545标准：

- 每周重复：`FREQ=WEEKLY`
- 每月重复：`FREQ=MONTHLY`
- 工作日重复：`FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR`
- 每周一重复：`FREQ=WEEKLY;BYDAY=MO`
- 每月最后一个工作日：`FREQ=MONTHLY;BYDAY=-1MO`

## 提醒时间示例

提醒时间数组示例：
- `[-15]`: 提前15分钟提醒
- `[-60, -15]`: 提前1小时和15分钟各提醒一次
- `[0]`: 准时提醒
- `[15]`: 延后15分钟提醒

## 实际使用场景

### 场景1：创建工作会议

用户：请帮我创建一个明天上午10点的团队例会，时长1小时，地点在会议室A，提前15分钟提醒。

AI助手调用：
```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "create_event",
    "title": "团队例会",
    "startTime": 1703664000000,
    "endTime": 1703667600000,
    "location": "会议室A",
    "remindTime": [-15]
  }
}
```

### 场景2：查询本周日程

用户：查看我本周的所有工作安排。

AI助手调用：
```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "query_events",
    "startTime": 1703462400000,
    "endTime": 1704067200000
  }
}
```

### 场景3：修改会议时间

用户：把明天的团队例会推迟半小时。

AI助手先查询事件，然后调用：
```json
{
  "name": "calendar_manager",
  "arguments": {
    "operation": "update_event",
    "eventId": 123,
    "startTime": 1703665800000,
    "endTime": 1703669400000
  }
}
```

## 错误处理

工具会处理以下错误情况：

1. **权限错误**: 当缺少日历权限时，会提示用户授权
2. **参数错误**: 当必需参数缺失时，会返回错误提示
3. **事件不存在**: 当尝试更新或删除不存在的事件时，会返回错误
4. **日历不存在**: 当尝试删除不存在的日历时，会返回错误
5. **时间格式错误**: 当时间参数格式不正确时，会返回错误

## 注意事项

1. 时间参数必须使用毫秒级时间戳
2. 结束时间必须大于开始时间
3. 删除日历会同时删除该日历下的所有事件
4. 重复规则需要遵循RFC 5545标准
5. 颜色值建议使用标准的十六进制格式（如 #FF5722）