/**
 * 搜索API客户端
 * 封装对服务端搜索接口的调用
 */

import { http } from '@kit.NetworkKit';
import { Logger } from '../utils/Logger';
import { AppConfigManager } from '../utils/AppConfigManager';

/**
 * 搜索请求参数
 */
export interface SearchRequest {
  query: string;
  provider?: string;
}

/**
 * 搜索结果
 */
export interface SearchResult {
  title: string;
  url: string;
  snippet: string;
}

/**
 * 搜索响应
 */
export interface SearchResponse {
  success: boolean;
  query: string;
  provider?: string;
  results: SearchResult[];
  total_results?: number;
  search_time?: number;
  error?: string;
}

/**
 * 搜索客户端配置
 */
export interface SearchClientConfig {
  baseUrl: string;
  timeout: number;
}

/**
 * 搜索结果摘要
 */
export interface SearchResultSummary {
  title: string;
  url: string;
}

/**
 * 搜索提供商响应
 */
export interface ProvidersResponse {
  providers: string[];
}

export class SearchAPIClient {
  private baseUrl: string;
  private configManager: AppConfigManager;
  private timeout: number = 10000; // 10秒超时

  constructor(baseUrl?: string) {
    this.configManager = AppConfigManager.getInstance();
    this.baseUrl = baseUrl || this.configManager.getServerConfig().searchUrl;
  }

  /**
   * 执行搜索请求
   */
  async search(query: string, provider?: string): Promise<SearchResponse> {
    Logger.info('SearchAPIClient', `=== 开始搜索请求 ===`);
    Logger.info('SearchAPIClient', `搜索查询: "${query}"`);
    Logger.info('SearchAPIClient', `搜索引擎: ${provider || 'default'}`);
    
    const startTime = Date.now();
    
    try {
      const requestData: SearchRequest = {
        query: query.trim()
      };
      
      if (provider) {
        requestData.provider = provider;
      }

      const httpRequest = http.createHttp();
      
      Logger.info('SearchAPIClient', `请求URL: ${this.baseUrl}/api/search`);
      Logger.info('SearchAPIClient', `请求数据: ${JSON.stringify(requestData)}`);
      
      const response = await httpRequest.request(
        `${this.baseUrl}/api/search`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          extraData: JSON.stringify(requestData),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: this.timeout,
          readTimeout: this.timeout
        }
      );

      httpRequest.destroy();
      
      const responseTime = Date.now() - startTime;
      Logger.info('SearchAPIClient', `响应状态码: ${response.responseCode}`);
      Logger.info('SearchAPIClient', `响应时间: ${responseTime}ms`);
      
      if (response.responseCode === 200) {
        try {
          const responseData = JSON.parse(response.result as string) as SearchResponse;
          Logger.info('SearchAPIClient', `=== 搜索请求成功 ===`);
          Logger.info('SearchAPIClient', `搜索结果数量: ${responseData.results?.length || 0}`);
          Logger.info('SearchAPIClient', `总结果数: ${responseData.total_results || 'unknown'}`);
          
          // 简化结果数据用于日志
          const resultSummary = responseData.results?.slice(0, 3).map(r => {
            const summaryItem: SearchResultSummary = {
              title: r.title?.substring(0, 50) + '...',
              url: r.url
            };
            return summaryItem;
          });
          Logger.info('SearchAPIClient', `结果预览: ${JSON.stringify(resultSummary)}`);
          
          return {
            success: true,
            query: query,
            provider: responseData.provider,
            results: responseData.results || [],
            total_results: responseData.total_results,
            search_time: responseTime
          };
          
        } catch (parseError) {
          Logger.error('SearchAPIClient', `解析响应数据失败: ${parseError}`);
          return {
            success: false,
            query: query,
            results: [],
            error: `响应数据解析失败: ${parseError}`
          };
        }
      } else {
        Logger.error('SearchAPIClient', `搜索请求失败，状态码: ${response.responseCode}`);
        Logger.error('SearchAPIClient', `响应内容: ${response.result}`);
        
        return {
          success: false,
          query: query,
          results: [],
          error: `服务器错误 (${response.responseCode}): ${response.result}`
        };
      }
      
    } catch (error) {
      const responseTime = Date.now() - startTime;
      Logger.error('SearchAPIClient', `=== 搜索请求异常 ===`);
      Logger.error('SearchAPIClient', `查询: "${query}"`);
      Logger.error('SearchAPIClient', `耗时: ${responseTime}ms`);
      Logger.error('SearchAPIClient', `错误信息: ${(error as Error).message}`);
      Logger.error('SearchAPIClient', `错误堆栈: ${(error as Error).stack}`);
      
      return {
        success: false,
        query: query,
        results: [],
        error: `网络请求失败: ${(error as Error).message}`
      };
    }
  }

  /**
   * 测试搜索服务连接
   */
  async testConnection(): Promise<boolean> {
    try {
      Logger.info('SearchAPIClient', '测试搜索服务连接');
      const response = await this.search('test', 'google');
      return response.success;
    } catch (error) {
      Logger.error('SearchAPIClient', `搜索服务连接测试失败: ${error}`);
      return false;
    }
  }

  /**
   * 获取可用的搜索引擎列表
   */
  async getAvailableProviders(): Promise<string[]> {
    try {
      Logger.info('SearchAPIClient', '获取可用搜索引擎列表');
      
      const httpRequest = http.createHttp();
      
      const response = await httpRequest.request(
        `${this.baseUrl}/api/search/providers`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/json'
          },
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: this.timeout,
          readTimeout: this.timeout
        }
      );

      httpRequest.destroy();
      
      if (response.responseCode === 200) {
        const responseData: ProvidersResponse = JSON.parse(response.result as string);
        const providers: string[] = responseData.providers || [];
        Logger.info('SearchAPIClient', `可用搜索引擎: ${providers.join(', ')}`);
        return providers;
      } else {
        Logger.error('SearchAPIClient', `获取搜索引擎列表失败: ${response.responseCode}`);
        return [];
      }
      
    } catch (error) {
      Logger.error('SearchAPIClient', `获取搜索引擎列表异常: ${error}`);
      return [];
    }
  }

  /**
   * 设置基础URL
   */
  setBaseUrl(url: string): void {
    this.baseUrl = url;
    Logger.info('SearchAPIClient', `搜索API基础URL已更新: ${url}`);
  }

  /**
   * 设置请求超时时间
   */
  setTimeout(timeout: number): void {
    this.timeout = timeout;
    Logger.info('SearchAPIClient', `搜索API超时时间已更新: ${timeout}ms`);
  }

  /**
   * 获取当前配置
   */
  getConfig(): SearchClientConfig {
    return {
      baseUrl: this.baseUrl,
      timeout: this.timeout
    };
  }
}