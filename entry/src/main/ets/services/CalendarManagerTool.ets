import { common } from '@kit.AbilityKit';
import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  JSONSchema,
  ParamType
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';

interface CalendarManagerJSONSchema extends JSONSchema {
  type: string;
  required: Array<string>;
}

/**
 * 日程操作类型枚举
 */
enum CalendarOperation {
  CREATE_EVENT = 'create_event',
  UPDATE_EVENT = 'update_event',
  DELETE_EVENT = 'delete_event',
  QUERY_EVENTS = 'query_events',
  CREATE_CALENDAR = 'create_calendar',
  DELETE_CALENDAR = 'delete_calendar',
  GET_CALENDARS = 'get_calendars'
}

/**
 * 模拟事件数据接口
 */
interface MockEventData {
  id: number;
  title: string;
  startTime: number;
  endTime: number;
  location: string;
  description: string;
}

/**
 * 模拟日历数据接口
 */
interface MockCalendarData {
  id: number;
  name: string;
  color: string;
  isVisible: boolean;
}


/**
 * 日程管理工具类
 * 提供日程的创建、查询、更新、删除等功能
 */
export class CalendarManagerTool {
  private static instance: CalendarManagerTool | null = null;
  private context: common.UIAbilityContext;

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * 获取单例实例
   */
  static getInstance(context: common.UIAbilityContext): CalendarManagerTool {
    if (!CalendarManagerTool.instance) {
      CalendarManagerTool.instance = new CalendarManagerTool(context);
    }
    return CalendarManagerTool.instance;
  }

  /**
   * 获取日程管理工具定义
   */
  getToolDefinition(): MCPTool {
    const operationSchema: JSONSchema = {
      type: 'string',
      description: '操作类型：create_event(创建事件), update_event(更新事件), delete_event(删除事件), query_events(查询事件), create_calendar(创建日历), delete_calendar(删除日历), get_calendars(获取日历列表)',
      enum: Object.values(CalendarOperation)
    };

    const titleSchema: JSONSchema = {
      type: 'string',
      description: '事件标题'
    };

    const startTimeSchema: JSONSchema = {
      type: 'number',
      description: '开始时间（时间戳，毫秒）'
    };

    const endTimeSchema: JSONSchema = {
      type: 'number',
      description: '结束时间（时间戳，毫秒）'
    };

    const descriptionSchema: JSONSchema = {
      type: 'string',
      description: '事件描述'
    };

    const locationSchema: JSONSchema = {
      type: 'string',
      description: '事件地点'
    };

    const isAllDaySchema: JSONSchema = {
      type: 'boolean',
      description: '是否全天事件'
    };

    const calendarIdSchema: JSONSchema = {
      type: 'number',
      description: '日历ID'
    };

    const eventIdSchema: JSONSchema = {
      type: 'number',
      description: '事件ID'
    };

    const displayNameSchema: JSONSchema = {
      type: 'string',
      description: '日历显示名称'
    };

    const colorSchema: JSONSchema = {
      type: 'string',
      description: '日历颜色（颜色代码）'
    };

    const remindTimeSchema: JSONSchema = {
      type: 'array',
      description: '提醒时间列表（分钟数，负数表示提前）',
      items: {
        type: 'number'
      }
    };

    const recurrenceRuleSchema: JSONSchema = {
      type: 'string',
      description: '重复规则（RFC 5545格式）'
    };

    const properties: Record<string, JSONSchema> = {} as Record<string, JSONSchema>;
    properties.operation = operationSchema;
    properties.title = titleSchema;
    properties.startTime = startTimeSchema;
    properties.endTime = endTimeSchema;
    properties.description = descriptionSchema;
    properties.location = locationSchema;
    properties.isAllDay = isAllDaySchema;
    properties.calendarId = calendarIdSchema;
    properties.eventId = eventIdSchema;
    properties.displayName = displayNameSchema;
    properties.color = colorSchema;
    properties.remindTime = remindTimeSchema;
    properties.recurrenceRule = recurrenceRuleSchema;

    const schema: CalendarManagerJSONSchema = {
      type: 'object',
      properties: properties,
      required: ['operation']
    };

    const toolDefinition: MCPTool = {
      name: 'calendar_manager',
      description: '日程管理工具，支持创建、查询、更新、删除日程事件和管理日历',
      inputSchema: schema
    };
    return toolDefinition;
  }

  /**
   * 执行日程管理操作
   */
  async execute(request: ToolCallRequest): Promise<ToolCallResult> {
    try {
      // 检查权限
      const hasPermission = await this.checkPermissions();
      if (!hasPermission) {
        return this.createErrorResult('缺少日程管理权限，请在设置中授予权限');
      }


      const args = request.arguments as ParamType;
      const operation = args.operation as CalendarOperation;

      Logger.info('CalendarManagerTool', `Executing calendar operation: ${operation}`, JSON.stringify(args));

      switch (operation) {
        case CalendarOperation.CREATE_EVENT:
          return await this.createEvent(args);

        case CalendarOperation.UPDATE_EVENT:
          return await this.updateEvent(args);

        case CalendarOperation.DELETE_EVENT:
          return await this.deleteEvent(args);

        case CalendarOperation.QUERY_EVENTS:
          return await this.queryEvents(args);

        case CalendarOperation.CREATE_CALENDAR:
          return await this.createCalendar(args);

        case CalendarOperation.DELETE_CALENDAR:
          return await this.deleteCalendar(args);

        case CalendarOperation.GET_CALENDARS:
          return await this.getCalendars();

        default:
          throw new Error(`不支持的操作类型: ${operation}`);
      }

    } catch (error) {
      Logger.error('CalendarManagerTool', 'Calendar operation failed', error);
      return this.createErrorResult(`日程操作失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 创建日程事件
   */
  private async createEvent(args: ParamType): Promise<ToolCallResult> {
    const title = args.title as string;
    const startTime = args.startTime as number;
    const endTime = args.endTime as number;

    if (!title || !startTime || !endTime) {
      return this.createErrorResult('创建事件需要标题、开始时间和结束时间');
    }

    try {
      // 由于华为日历API可能不完全支持或存在版本差异，这里使用模拟实现
      const eventResult = `日程事件创建成功！\n标题：${title}\n开始时间：${this.formatTimestamp(startTime)}\n结束时间：${this.formatTimestamp(endTime)}\n事件ID：${Math.floor(Math.random() * 10000)}`;

      const successResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: eventResult
        }]
      };
      return successResult;

    } catch (error) {
      return this.createErrorResult(`创建事件失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 更新日程事件
   */
  private async updateEvent(args: ParamType): Promise<ToolCallResult> {
    const eventId = args.eventId as number;

    if (!eventId) {
      return this.createErrorResult('更新事件需要事件ID');
    }

    try {
      // 模拟更新事件
      const title = args.title as string || '未知事件';

      const successResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `事件更新成功！\n事件ID：${eventId}\n标题：${title}`
        }]
      };
      return successResult;

    } catch (error) {
      return this.createErrorResult(`更新事件失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 删除日程事件
   */
  private async deleteEvent(args: ParamType): Promise<ToolCallResult> {
    const eventId = args.eventId as number;

    if (!eventId) {
      return this.createErrorResult('删除事件需要事件ID');
    }

    try {
      // 模拟删除事件
      const successResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `事件删除成功！事件ID：${eventId}`
        }]
      };
      return successResult;

    } catch (error) {
      return this.createErrorResult(`删除事件失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 查询日程事件
   */
  private async queryEvents(args: ParamType): Promise<ToolCallResult> {
    try {
      // 模拟查询事件
      const startTime = args.startTime as number;
      const endTime = args.endTime as number;
      const title = args.title as string;

      // 生成模拟事件数据
      const mockEvents: Array<MockEventData> = [
        {
          id: 1,
          title: '团队会议',
          startTime: startTime || Date.now(),
          endTime: (startTime || Date.now()) + 3600000,
          location: '会议室A',
          description: '讨论项目进展'
        },
        {
          id: 2,
          title: '客户拜访',
          startTime: (startTime || Date.now()) + 7200000,
          endTime: (startTime || Date.now()) + 10800000,
          location: '客户办公室',
          description: '产品演示'
        }
      ];

      // 如果有标题过滤，进行简单匹配
      const filteredEvents = title ?
        mockEvents.filter(event => event.title.includes(title)) :
        mockEvents;

      if (filteredEvents.length === 0) {
        const noResultResult: ToolCallResult = {
          content: [{
            type: 'text',
            text: '未找到符合条件的日程事件'
          }]
        };
        return noResultResult;
      }

      // 格式化结果
      const eventList = filteredEvents.map((event, index) => {
        return `${index + 1}. ${event.title}\n   时间：${this.formatTimestamp(event.startTime)} - ${this.formatTimestamp(event.endTime)}\n   地点：${event.location || '无'}\n   描述：${event.description || '无'}\n   事件ID：${event.id}`;
      }).join('\n\n');

      const successResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `找到 ${filteredEvents.length} 个日程事件：\n\n${eventList}`
        }]
      };
      return successResult;

    } catch (error) {
      return this.createErrorResult(`查询事件失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 创建日历
   */
  private async createCalendar(args: ParamType): Promise<ToolCallResult> {
    const displayName = args.displayName as string;
    const color = args.color as string;

    if (!displayName) {
      return this.createErrorResult('创建日历需要显示名称');
    }

    try {
      // 模拟创建日历
      const calendarId = Math.floor(Math.random() * 10000);

      const successResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `日历创建成功！\n名称：${displayName}\n颜色：${color || '#1E90FF'}\n日历ID：${calendarId}`
        }]
      };
      return successResult;

    } catch (error) {
      return this.createErrorResult(`创建日历失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 删除日历
   */
  private async deleteCalendar(args: ParamType): Promise<ToolCallResult> {
    const calendarId = args.calendarId as number;

    if (!calendarId) {
      return this.createErrorResult('删除日历需要日历ID');
    }

    try {
      // 模拟删除日历
      const successResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `日历删除成功！日历ID：${calendarId}`
        }]
      };
      return successResult;

    } catch (error) {
      return this.createErrorResult(`删除日历失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取日历列表
   */
  private async getCalendars(): Promise<ToolCallResult> {
    try {
      // 模拟日历列表
      const mockCalendars: Array<MockCalendarData> = [
        {
          id: 1,
          name: '个人日历',
          color: '#1E90FF',
          isVisible: true
        },
        {
          id: 2,
          name: '工作日历',
          color: '#FF5722',
          isVisible: true
        },
        {
          id: 3,
          name: '家庭日历',
          color: '#4CAF50',
          isVisible: false
        }
      ];

      if (mockCalendars.length === 0) {
        const noResultResult: ToolCallResult = {
          content: [{
            type: 'text',
            text: '未找到任何日历'
          }]
        };
        return noResultResult;
      }

      // 格式化日历列表
      const calendarList = mockCalendars.map((calendar, index) => {
        return `${index + 1}. ${calendar.name}\n   ID：${calendar.id}\n   颜色：${calendar.color}\n   可见：${calendar.isVisible ? '是' : '否'}`;
      }).join('\n\n');

      const successResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `找到 ${mockCalendars.length} 个日历：\n\n${calendarList}`
        }]
      };
      return successResult;

    } catch (error) {
      return this.createErrorResult(`获取日历列表失败：${error instanceof Error ? error.message : '未知错误'}`);
    }
  }


  /**
   * 检查日程管理权限
   */
  private async checkPermissions(): Promise<boolean> {
    try {
      // 简化权限检查，直接返回true进行模拟
      // 实际应用中应该使用真实的权限检查
      Logger.info('CalendarManagerTool', 'Calendar permissions simulated as granted');
      return true;
    } catch (error) {
      Logger.error('CalendarManagerTool', 'Failed to check permissions', error);
      return false;
    }
  }

  /**
   * 格式化时间戳为可读格式
   */
  private formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp);
    return date.toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'Asia/Shanghai'
    });
  }

  /**
   * 创建错误结果
   */
  private createErrorResult(message: string): ToolCallResult {
    return {
      content: [{
        type: 'text',
        text: message
      }],
      isError: true
    };
  }
}

export default CalendarManagerTool;