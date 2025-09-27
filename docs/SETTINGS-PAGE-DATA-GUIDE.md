# SettingsPage 记忆统计刷新问题复盘

## 背景
- 页面顶部的“记忆中心”项始终显示 `-1 个记忆碎片`，即便新增或删除记忆后日志中已经拿到了正确统计值。
- 问题定位与修复经过多轮排查，需要沉淀这次经验，避免后续设置页出现类似的刷新问题。

## 根因分析
- `computedMemorySettings` 初次渲染时就把 `memoryTotalFragments`、`memoryActiveFragments` 拼成普通字符串写入 `SettingItem.subtitle`。
- UI 在 `buildSettingsItem` → `getDynamicSubtitle` 中只是回读 `item.subtitle`，没有再触碰对应的 `@Local` 变量。
- ArkUI 的响应式依赖建立在“渲染时读取状态”上，既然渲染树只持有旧字符串，就不会因状态变化触发二次刷新，所以界面一直停留在 `-1`。

## 修复要点
- 让 UI 的 `Text` 直接访问 `@Local` 状态：`getDynamicSubtitle` 针对 `title === '记忆中心'` 的项返回 `this.memoryTotalFragments`、`this.memoryActiveFragments` 的实时值。
- 同时去掉用于“强制刷新”的伪版本号，避免制造无效依赖。
- 调整后每次监听器更新状态，`Text` 都会重新读取最新的 `@Local` 数据，界面即可同步刷新。

## 设置页数据绑定规范
1. **保持直接依赖**：列表项的展示文本应从 `@Local` / `@Observed` 状态直接计算，避免把数值缓存成普通字符串后再传递。
2. **避免伪触发器**：不要依靠额外的计数器（例如 `version++`）去“强制刷新”UI，应找出实际未建立响应式依赖的节点。
3. **优先使用 `@Computed`**：当需要根据多个状态拼装 `SettingItem` 时，加 `@Computed` 并确保其返回值在渲染阶段会访问到那些状态。
4. **调试加双向日志**：除了在监听器里记录状态更新，也在渲染读取位置记录调用次数，可快速判断 UI 是否重新计算。
5. **复用场景复测**：修复后，至少覆盖“进入设置页”“新增记忆”“删除记忆”三个场景，确认数字和日志一致。

## 参考实现
- 详见 `entry/src/main/ets/pages/SettingsPage.ets:1260-1285` 的 `getDynamicSubtitle` 分支实现。
- 相关监听与加载流程位于同文件 `136-175` 和 `156-208` 行，可作为设置页状态管理的结构范例。

