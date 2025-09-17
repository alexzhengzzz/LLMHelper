#!/bin/bash

# 遇到任何错误立即退出
set -e

# --- 配置变量 ---
# DevEco Studio 的安装路径
DEVECO_STUDIO_PATH="/Applications/DevEco-Studio.app"
# 设置 DEVECO_SDK_HOME 环境变量，hvigor 工具需要此变量
export DEVECO_SDK_HOME="${DEVECO_STUDIO_PATH}/Contents"
# hvigor 命令使用的 Node.js 路径
HVIGOR_NODE="${DEVECO_STUDIO_PATH}/Contents/tools/node/bin/node"
# hvigor 命令行工具的路径
HVIGOR_CLI="${DEVECO_STUDIO_PATH}/Contents/tools/hvigor/bin/hvigorw.js"

# --- 编译 .hap 文件 ---
echo "--- 开始编译 .hap 文件 ---"
"${HVIGOR_NODE}" "${HVIGOR_CLI}" --mode module -p module=phone@default -p product=default -p requiredDeviceType=phone assembleHap --analyze=normal --parallel --incremental --daemon
echo "--- .hap 文件编译完成 ---"

