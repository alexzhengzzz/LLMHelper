/**
 * 工具箱类型定义
 * Javis 聊天应用工具箱功能
 */

/**
 * 工具类型枚举
 */
export enum ToolType {
  CLEAR_SESSION = 'clear_session',     // 清空会话
  WEB_SEARCH = 'web_search',           // 联网搜索
  COMPACT_CONTEXT = 'compact_context',  // 压缩上下文
  TOGGLE_STYLE = 'toggle_style'        // 切换样式
}

/**
 * 工具项接口
 */
export interface ToolItem {
  id: ToolType;              // 工具唯一标识
  title: string;             // 工具标题
  description: string;       // 工具描述
  icon: string;              // 工具图标
  color: string;             // 图标颜色
  backgroundColor: string;    // 背景颜色
  enabled: boolean;          // 是否启用
  action: () => void | Promise<void>; // 工具执行动作
}

/**
 * 工具箱组件属性
 */
export interface ToolboxComponentProps {
  onToolSelected?: (tool: ToolType) => void;  // 工具选择回调
  onPanelShow?: () => void;                   // 面板显示回调
  onPanelHide?: () => void;                   // 面板隐藏回调
  enableWebSearch: boolean;                   // 联网搜索状态
  onWebSearchToggle?: (enabled: boolean) => void; // 联网搜索状态切换回调
}

/**
 * 工具箱配置
 */
export interface ToolboxConfig {
  showPanel: boolean;          // 是否显示工具面板
  animationDuration: number;   // 动画持续时间
  toolItemHeight: number;     // 工具项高度
  panelMaxHeight: number;     // 面板最大高度
  panelCornerRadius: number;  // 面板圆角
}