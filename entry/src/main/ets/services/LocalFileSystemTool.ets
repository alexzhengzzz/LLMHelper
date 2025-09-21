import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import {
  MCPTool,
  ToolCallRequest,
  ToolCallResult,
  TextContent,
  JSONSchema
} from '../types/MCPTypes';
import { Logger } from '../utils/Logger';

/**
 * 本地文件系统工具
 * 提供安全的文件系统操作，仅限应用沙箱内
 */
export class LocalFileSystemTool {
  private static readonly TOOLS: Array<MCPTool> = [
    {
      name: 'read_file',
      description: '读取应用沙箱内的文本文件',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: '文件路径（相对于应用沙箱）'
          },
          encoding: {
            type: 'string',
            enum: ['utf8', 'utf-8'],
            default: 'utf8',
            description: '文件编码'
          }
        },
        required: ['path']
      }
    },
    {
      name: 'write_file',
      description: '写入文本内容到应用沙箱内的文件',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: '文件路径（相对于应用沙箱）'
          },
          content: {
            type: 'string',
            description: '要写入的文本内容'
          },
          encoding: {
            type: 'string',
            enum: ['utf8', 'utf-8'],
            default: 'utf8',
            description: '文件编码'
          },
          mode: {
            type: 'string',
            enum: ['write', 'append'],
            default: 'write',
            description: '写入模式：覆盖或追加'
          }
        },
        required: ['path', 'content']
      }
    },
    {
      name: 'list_directory',
      description: '列出应用沙箱内目录的内容',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: '目录路径（相对于应用沙箱），默认为根目录',
            default: '.'
          },
          recursive: {
            type: 'boolean',
            description: '是否递归列出子目录',
            default: false
          }
        }
      }
    },
    {
      name: 'create_directory',
      description: '在应用沙箱内创建目录',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: '目录路径（相对于应用沙箱）'
          },
          recursive: {
            type: 'boolean',
            description: '是否递归创建父目录',
            default: true
          }
        },
        required: ['path']
      }
    },
    {
      name: 'delete_file',
      description: '删除应用沙箱内的文件或目录',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: '文件或目录路径（相对于应用沙箱）'
          },
          recursive: {
            type: 'boolean',
            description: '如果是目录，是否递归删除',
            default: false
          }
        },
        required: ['path']
      }
    },
    {
      name: 'get_file_info',
      description: '获取文件或目录的详细信息',
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: '文件或目录路径（相对于应用沙箱）'
          }
        },
        required: ['path']
      }
    }
  ];

  private context: common.UIAbilityContext;
  private filesDir: string;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.filesDir = context.filesDir;
    Logger.info('LocalFileSystemTool', `Initialized with files directory: ${this.filesDir}`);
  }

  /**
   * 获取所有工具定义
   */
  getTools(): Array<MCPTool> {
    return LocalFileSystemTool.TOOLS;
  }

  /**
   * 执行工具调用
   */
  async executeCall(request: ToolCallRequest): Promise<ToolCallResult> {
    try {
      Logger.info('LocalFileSystemTool', `Executing tool: ${request.name}`, request.arguments);

      switch (request.name) {
        case 'read_file':
          return await this.readFile(request.arguments);
        case 'write_file':
          return await this.writeFile(request.arguments);
        case 'list_directory':
          return await this.listDirectory(request.arguments);
        case 'create_directory':
          return await this.createDirectory(request.arguments);
        case 'delete_file':
          return await this.deleteFile(request.arguments);
        case 'get_file_info':
          return await this.getFileInfo(request.arguments);
        default:
          throw new Error(`Unknown tool: ${request.name}`);
      }
    } catch (error) {
      Logger.error('LocalFileSystemTool', `Tool execution failed: ${request.name}`, error);
      return {
        content: [{
          type: 'text',
          text: `工具执行失败: ${error instanceof Error ? error.message : '未知错误'}`
        }],
        isError: true
      };
    }
  }

  /**
   * 读取文件内容
   */
  private async readFile(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const path = this.validateAndGetPath(args.path as string);
    const encoding = (args.encoding as string) || 'utf8';

    try {
      const fullPath = this.getFullPath(path);
      const exists = await this.fileExists(fullPath);

      if (!exists) {
        throw new Error(`文件不存在: ${path}`);
      }

      const stat = await fileIo.stat(fullPath);
      if (stat.isDirectory()) {
        throw new Error(`指定路径是目录，不是文件: ${path}`);
      }

      const content = await fileIo.readText(fullPath, { encoding: encoding });

      return {
        content: [{
          type: 'text',
          text: `文件内容 (${path}):\n\n${content}`
        }]
      };
    } catch (error) {
      throw new Error(`读取文件失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 写入文件内容
   */
  private async writeFile(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const path = this.validateAndGetPath(args.path as string);
    const content = args.content as string;
    const encoding = (args.encoding as string) || 'utf8';
    const mode = (args.mode as string) || 'write';

    if (typeof content !== 'string') {
      throw new Error('content 参数必须是字符串');
    }

    try {
      const fullPath = this.getFullPath(path);
      const parentDir = this.getParentDirectory(fullPath);

      // 确保父目录存在
      if (parentDir && !(await this.fileExists(parentDir))) {
        await fileIo.mkdir(parentDir, true);
      }

      if (mode === 'append') {
        // 追加模式
        const file = await fileIo.open(fullPath, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND);
        await fileIo.write(file.fd, content, { encoding: encoding });
        await fileIo.close(file.fd);
      } else {
        // 覆盖模式
        await fileIo.writeText(fullPath, content, { encoding: encoding });
      }

      const bytesWritten = Buffer.from(content, encoding).length;

      return {
        content: [{
          type: 'text',
          text: `文件写入成功: ${path} (${bytesWritten} 字节)`
        }]
      };
    } catch (error) {
      throw new Error(`写入文件失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 列出目录内容
   */
  private async listDirectory(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const path = (args.path as string) || '.';
    const recursive = (args.recursive as boolean) || false;

    try {
      const fullPath = this.getFullPath(path);
      const exists = await this.fileExists(fullPath);

      if (!exists) {
        throw new Error(`目录不存在: ${path}`);
      }

      const stat = await fileIo.stat(fullPath);
      if (!stat.isDirectory()) {
        throw new Error(`指定路径不是目录: ${path}`);
      }

      const items = await this.listDirectoryRecursive(fullPath, recursive);
      const itemList = items.map(item => {
        const relativePath = item.path.replace(this.filesDir + '/', '');
        return `${item.type === 'directory' ? '[DIR]' : '[FILE]'} ${relativePath} (${item.size} 字节)`;
      }).join('\n');

      return {
        content: [{
          type: 'text',
          text: `目录内容 (${path}):\n\n${itemList}\n\n总计: ${items.length} 项`
        }]
      };
    } catch (error) {
      throw new Error(`列出目录失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 创建目录
   */
  private async createDirectory(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const path = this.validateAndGetPath(args.path as string);
    const recursive = (args.recursive as boolean) !== false; // 默认为true

    try {
      const fullPath = this.getFullPath(path);

      if (await this.fileExists(fullPath)) {
        const stat = await fileIo.stat(fullPath);
        if (stat.isDirectory()) {
          return {
            content: [{
              type: 'text',
              text: `目录已存在: ${path}`
            }]
          };
        } else {
          throw new Error(`路径已存在且不是目录: ${path}`);
        }
      }

      await fileIo.mkdir(fullPath, recursive);

      return {
        content: [{
          type: 'text',
          text: `目录创建成功: ${path}`
        }]
      };
    } catch (error) {
      throw new Error(`创建目录失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 删除文件或目录
   */
  private async deleteFile(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const path = this.validateAndGetPath(args.path as string);
    const recursive = (args.recursive as boolean) || false;

    try {
      const fullPath = this.getFullPath(path);
      const exists = await this.fileExists(fullPath);

      if (!exists) {
        throw new Error(`文件或目录不存在: ${path}`);
      }

      const stat = await fileIo.stat(fullPath);

      if (stat.isDirectory()) {
        if (recursive) {
          await fileIo.rmdir(fullPath);
        } else {
          // 检查目录是否为空
          const files = await fileIo.listFile(fullPath);
          if (files.length > 0) {
            throw new Error(`目录不为空，请使用 recursive: true 参数: ${path}`);
          }
          await fileIo.rmdir(fullPath);
        }
      } else {
        await fileIo.unlink(fullPath);
      }

      return {
        content: [{
          type: 'text',
          text: `删除成功: ${path}`
        }]
      };
    } catch (error) {
      throw new Error(`删除失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 获取文件信息
   */
  private async getFileInfo(args: Record<string, ESObject>): Promise<ToolCallResult> {
    const path = this.validateAndGetPath(args.path as string);

    try {
      const fullPath = this.getFullPath(path);
      const exists = await this.fileExists(fullPath);

      if (!exists) {
        throw new Error(`文件或目录不存在: ${path}`);
      }

      const stat = await fileIo.stat(fullPath);

      const info = {
        path: path,
        type: stat.isDirectory() ? 'directory' : 'file',
        size: stat.size,
        accessTime: new Date(stat.atime * 1000).toISOString(),
        modifyTime: new Date(stat.mtime * 1000).toISOString(),
        createTime: new Date(stat.ctime * 1000).toISOString(),
        mode: stat.mode.toString(8),
        isReadable: true, // 在应用沙箱内，默认可读
        isWritable: true  // 在应用沙箱内，默认可写
      };

      return {
        content: [{
          type: 'text',
          text: `文件信息:\n${JSON.stringify(info, null, 2)}`
        }]
      };
    } catch (error) {
      throw new Error(`获取文件信息失败: ${error instanceof Error ? error.message : '未知错误'}`);
    }
  }

  /**
   * 验证和清理路径
   */
  private validateAndGetPath(path: string): string {
    if (!path || typeof path !== 'string') {
      throw new Error('路径不能为空');
    }

    // 移除开头的斜杠和相对路径符号
    let cleanPath = path.replace(/^\/+/, '').replace(/^\.\//, '');

    // 检查是否包含危险的路径遍历
    if (cleanPath.includes('..') || cleanPath.includes('~')) {
      throw new Error('路径不能包含 .. 或 ~ 字符');
    }

    // 确保路径不以斜杠结尾（除非是根目录）
    if (cleanPath.endsWith('/') && cleanPath !== '/') {
      cleanPath = cleanPath.slice(0, -1);
    }

    return cleanPath || '.';
  }

  /**
   * 获取完整路径
   */
  private getFullPath(relativePath: string): string {
    if (relativePath === '.') {
      return this.filesDir;
    }
    return `${this.filesDir}/${relativePath}`;
  }

  /**
   * 获取父目录路径
   */
  private getParentDirectory(fullPath: string): string | null {
    const pathParts = fullPath.split('/');
    if (pathParts.length <= 1) {
      return null;
    }
    pathParts.pop();
    return pathParts.join('/');
  }

  /**
   * 检查文件是否存在
   */
  private async fileExists(path: string): Promise<boolean> {
    try {
      await fileIo.access(path);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * 递归列出目录内容
   */
  private async listDirectoryRecursive(dirPath: string, recursive: boolean): Promise<Array<FileItem>> {
    const items: Array<FileItem> = [];

    try {
      const files = await fileIo.listFile(dirPath);

      for (const fileName of files) {
        const filePath = `${dirPath}/${fileName}`;
        const stat = await fileIo.stat(filePath);

        items.push({
          path: filePath,
          name: fileName,
          type: stat.isDirectory() ? 'directory' : 'file',
          size: stat.size,
          modifyTime: stat.mtime * 1000
        });

        // 如果是目录且需要递归
        if (recursive && stat.isDirectory()) {
          const subItems = await this.listDirectoryRecursive(filePath, true);
          items.push(...subItems);
        }
      }
    } catch (error) {
      Logger.warn('LocalFileSystemTool', `Failed to list directory: ${dirPath}`, error);
    }

    return items;
  }
}

/**
 * 文件项信息
 */
interface FileItem {
  path: string;
  name: string;
  type: 'file' | 'directory';
  size: number;
  modifyTime: number;
}

export default LocalFileSystemTool;