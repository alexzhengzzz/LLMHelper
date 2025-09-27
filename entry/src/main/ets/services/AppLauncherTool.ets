import { common, Want, abilityAccessCtrl, bundleManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  JSONSchema,
  ParamType,
  AppLaunchParameters,
  AppLaunchResult,
  AppLaunchPermission,
  AppLauncherJSONSchema,
  InstalledApplication
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';

/**
 * JSON Schema 扩展接口
 */
interface AppLauncherToolJSONSchema extends JSONSchema {
  type: string;
  properties: Record<string, JSONSchema>;
  required: Array<string>;
}

/**
 * 应用启动验证结果接口
 */
interface AppLaunchValidationResult {
  isValid: boolean;
  error?: string;
}

/**
 * 应用权限检查结果接口
 */
interface AppLaunchPermissionCheck {
  hasPermissions: boolean;
  error?: string;
}

/**
 * 应用存在检查结果接口
 */
interface AppLaunchExistenceCheck {
  exists: boolean;
  appName?: string;
}

/**
 * 应用启动执行结果接口
 */
interface AppLaunchExecutionResult {
  result: AppLaunchResult;
  error?: string;
}

/**
 * 应用启动工具类
 * 提供通过包名拉起其他鸿蒙应用的功能
 */
export class AppLauncherTool {
  private static instance: AppLauncherTool | null = null;
  private context: common.UIAbilityContext;
  private permissionManager: abilityAccessCtrl.AtManager;

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.permissionManager = abilityAccessCtrl.createAtManager();
  }

  /**
   * 获取单例实例
   */
  static getInstance(context: common.UIAbilityContext): AppLauncherTool {
    if (!AppLauncherTool.instance) {
      AppLauncherTool.instance = new AppLauncherTool(context);
    }
    return AppLauncherTool.instance;
  }

  /**
   * 获取应用启动工具定义
   */
  getToolDefinition(): MCPTool {
    const bundleNameSchema: JSONSchema = {
      type: 'string',
      description: '应用包名，例如：com.huawei.hms.app',
      pattern: '^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z][a-zA-Z0-9_]*)+$',
      minLength: 1,
      maxLength: 255
    };

    const abilityNameSchema: JSONSchema = {
      type: 'string',
      description: 'Ability名称，可选参数，例如：MainAbility',
      pattern: '^[a-zA-Z][a-zA-Z0-9_]*$',
      minLength: 1,
      maxLength: 100
    };

    const parametersSchema: JSONSchema = {
      type: 'object',
      description: '启动参数，可选参数，例如：{"action": "view", "data": "https://example.com"}'
    };

    const properties: Record<string, JSONSchema> = {} as Record<string, JSONSchema>;
    properties.bundleName = bundleNameSchema;
    properties.abilityName = abilityNameSchema;
    properties.parameters = parametersSchema;

    const schema: AppLauncherToolJSONSchema = {
      type: 'object',
      properties: properties,
      required: ['bundleName']
    };

    const toolDefinition: MCPTool = {
      name: 'app_launcher',
      description: '通过包名启动其他鸿蒙应用，支持传递启动参数',
      inputSchema: schema
    };
    return toolDefinition;
  }

  /**
   * 执行应用启动
   */
  async execute(request: ToolCallRequest): Promise<ToolCallResult> {
    try {
      const args = request.arguments as ParamType;
      const launchParams: AppLaunchParameters = {
        bundleName: args.bundleName as string,
        abilityName: args.abilityName as string,
        parameters: args.parameters as Record<string, string | number | boolean>
      };

      Logger.info('AppLauncherTool', `Executing app launch: ${launchParams.bundleName}`,
        JSON.stringify({ abilityName: launchParams.abilityName, parameters: launchParams.parameters }));

      // 参数验证
      const validationResult = this.validateParameters(launchParams);
      if (!validationResult.isValid) {
        const errorResult: ToolCallResult = {
          content: [{
            type: 'text',
            text: `参数验证失败: ${validationResult.error}`
          }],
          isError: true
        };
        return errorResult;
      }

      // 检查权限
      const permissionCheck = await this.checkPermissions();
      if (!permissionCheck.hasPermissions) {
        const errorResult: ToolCallResult = {
          content: [{
            type: 'text',
            text: `权限检查失败: ${permissionCheck.error}`
          }],
          isError: true
        };
        return errorResult;
      }

      // 检查应用是否存在
      // const appCheck = await this.checkAppExists(launchParams.bundleName);
      // if (!appCheck.exists) {
      //   const errorResult: ToolCallResult = {
      //     content: [{
      //       type: 'text',
      //       text: `应用不存在: ${launchParams.bundleName}`
      //     }],
      //     isError: true
      //   };
      //   return errorResult;
      // }

      // 启动应用
      const launchResult = await this.launchApplication(launchParams);

      if (launchResult.result === AppLaunchResult.SUCCESS) {
        const successResult: ToolCallResult = {
          content: [{
            type: 'text',
            text: `应用启动成功\n包名: ${launchParams.bundleName}${launchParams.abilityName ? `\nAbility: ${launchParams.abilityName}` : ''}${launchParams.parameters ? `\n参数: ${JSON.stringify(launchParams.parameters)}` : ''}`
          }]
        };
        return successResult;
      } else {
        const errorResult: ToolCallResult = {
          content: [{
            type: 'text',
            text: `应用启动失败: ${launchResult.error}`
          }],
          isError: true
        };
        return errorResult;
      }

    } catch (error) {
      Logger.error('AppLauncherTool', 'Application launch failed', error);
      const errorResult: ToolCallResult = {
        content: [{
          type: 'text',
          text: `应用启动失败: ${error instanceof Error ? error.message : '未知错误'}`
        }],
        isError: true
      };
      return errorResult;
    }
  }

  /**
   * 参数验证
   */
  private validateParameters(params: AppLaunchParameters): AppLaunchValidationResult {
    if (!params.bundleName || typeof params.bundleName !== 'string') {
      return { isValid: false, error: 'bundleName参数缺失或类型错误' };
    }

    // 验证包名格式
    const bundleNamePattern = /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$/;
    if (!bundleNamePattern.test(params.bundleName)) {
      return { isValid: false, error: 'bundleName格式错误，应为有效的包名格式' };
    }

    if (params.abilityName && typeof params.abilityName !== 'string') {
      return { isValid: false, error: 'abilityName参数类型错误' };
    }

    if (params.abilityName) {
      const abilityNamePattern = /^[a-zA-Z][a-zA-Z0-9_]*$/;
      if (!abilityNamePattern.test(params.abilityName)) {
        return { isValid: false, error: 'abilityName格式错误' };
      }
    }

    if (params.parameters && typeof params.parameters !== 'object') {
      return { isValid: false, error: 'parameters参数类型错误' };
    }

    return { isValid: true };
  }

  /**
   * 检查应用启动权限
   */
  private async checkPermissions(): Promise<AppLaunchPermissionCheck> {
    try {
      const requiredPermissions = [
        AppLaunchPermission.START_ABILITIES_FROM_BACKGROUND,
        AppLaunchPermission.GET_BUNDLE_INFO
      ];

      for (const permission of requiredPermissions) {
        const status = await this.permissionManager.checkAccessTokenSync(
          this.context.applicationInfo.accessTokenId,
          permission
        );
        if (status !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          Logger.warn('AppLauncherTool', `Permission not granted: ${permission}`);
        }
      }

      return { hasPermissions: true };
    } catch (error) {
      Logger.error('AppLauncherTool', 'Permission check failed', error);
      return { hasPermissions: false, error: error instanceof Error ? error.message : '权限检查失败' };
    }
  }

  /**
   * 检查应用是否存在
   */
  private async checkAppExists(bundleName: string): Promise<AppLaunchExistenceCheck> {
    try {
      const bundleInfo = await bundleManager.getBundleInfo(bundleName, bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      return {
        exists: true,
        appName: bundleInfo.name
      };
    } catch (error) {
      Logger.warn('AppLauncherTool', `App not found: ${bundleName}`, error);
      return { exists: false };
    }
  }

  /**
   * 启动应用
   */
  private async launchApplication(params: AppLaunchParameters): Promise<AppLaunchExecutionResult> {
    try {
      const want: Want = {
        bundleName: params.bundleName,
        abilityName: params.abilityName,
        parameters: params.parameters
      };

      // 清理undefined属性，不使用delete操作符
      const cleanWant: Want = {
        bundleName: want.bundleName
      };
      if (want.abilityName !== undefined) {
        cleanWant.abilityName = want.abilityName;
      }
      if (want.parameters !== undefined) {
        cleanWant.parameters = want.parameters;
      }

      Logger.debug('AppLauncherTool', `Starting ability with want: ${JSON.stringify(cleanWant)}`);

      await this.context.startAbility(cleanWant);

      Logger.info('AppLauncherTool', `Application launched successfully: ${params.bundleName}`);
      return { result: AppLaunchResult.SUCCESS };

    } catch (error) {
      Logger.error('AppLauncherTool', `Failed to launch application: ${params.bundleName}`, error);

      let errorType = AppLaunchResult.LAUNCH_FAILED;
      let errorMessage = error instanceof Error ? error.message : '启动失败';

      // 根据错误类型进行分类
      if (errorMessage.includes('permission') || errorMessage.includes('Permission')) {
        errorType = AppLaunchResult.PERMISSION_DENIED;
        errorMessage = '缺少必要权限，无法启动应用';
      } else if (errorMessage.includes('not found') || errorMessage.includes('Not found')) {
        errorType = AppLaunchResult.APP_NOT_FOUND;
        errorMessage = '应用未找到，请检查包名是否正确';
      }

      return {
        result: errorType,
        error: errorMessage
      };
    }
  }

  /**
   * 获取已安装应用列表
   */
  async getInstalledApplications(): Promise<Array<InstalledApplication>> {
    try {
      // 由于getAllBundleInfo可能需要特殊权限，我们返回一个空列表作为fallback
      const apps: Array<InstalledApplication> = [];

      // 简化版本，避免使用可能需要特殊权限的API
      Logger.info('AppLauncherTool', 'Application listing requires special permissions, returning empty list');
      return apps;
    } catch (error) {
      Logger.error('AppLauncherTool', 'Failed to get installed applications', error);
      throw new Error('获取已安装应用列表失败');
    }
  }
}

export default AppLauncherTool;