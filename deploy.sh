#!/bin/bash

# 遇到任何错误立即退出
set -e

# --- 配置变量 ---
# DevEco Studio 的安装路径
DEVECO_STUDIO_PATH="/Applications/DevEco-Studio.app"
# hdc 工具的路径
HDC_CLI="${DEVECO_STUDIO_PATH}/Contents/sdk/default/openharmony/toolchains/hdc"
# 你的项目根目录
PROJECT_ROOT="/Users/alex/zmh/ohos/llmhap/ohosllm"
# 编译生成的 .hap 文件相对于项目根目录的路径
HAP_FILE_RELATIVE_PATH="entry/build/default/outputs/default/phone-default-signed.hap"
# 你的应用包名
PACKAGE_NAME="com.zmh.llmapp"
# 应用的入口 Ability 名称
ENTRY_ABILITY="EntryAbility"

# 生成一个设备上唯一的临时目录名，用于存放 .hap 文件
# 使用 uuidgen 来确保目录名的唯一性，避免冲突
DEVICE_TMP_DIR_NAME=$(uuidgen)
DEVICE_INSTALL_PATH="/data/local/tmp/${DEVICE_TMP_DIR_NAME}"

# --- 推包到设备并启动 ---
echo "--- 停止设备上的旧应用实例 ---"
"${HDC_CLI}" shell aa force-stop "${PACKAGE_NAME}"

echo "--- 在设备上创建临时目录: ${DEVICE_INSTALL_PATH} ---"
"${HDC_CLI}" shell mkdir "${DEVICE_INSTALL_PATH}"

echo "--- 发送 .hap 文件到设备 ---"
# 拼接完整的 .hap 文件路径
FULL_HAP_PATH="${PROJECT_ROOT}/${HAP_FILE_RELATIVE_PATH}"
"${HDC_CLI}" file send "${FULL_HAP_PATH}" "${DEVICE_INSTALL_PATH}"

echo "--- 在设备上安装 .hap 文件 ---"
"${HDC_CLI}" shell bm install -p "${DEVICE_INSTALL_PATH}"

echo "--- 清理设备上的临时目录 ---"
"${HDC_CLI}" shell rm -rf "${DEVICE_INSTALL_PATH}"

echo "--- 在设备上启动应用 ---"
"${HDC_CLI}" shell aa start -a "${ENTRY_ABILITY}" -b "${PACKAGE_NAME}"

echo "--- 编译和推包流程全部完成！ ---"