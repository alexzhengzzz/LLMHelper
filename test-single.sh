#!/bin/bash

# 简化的测试运行脚本 - 用于运行单个测试文件
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

# --- 检查参数 ---
if [ $# -eq 0 ]; then
    echo "使用方法: $0 <测试文件名>"
    echo "例如: $0 APIManagerTest"
    echo "可用的测试文件:"
    ls -la entry/src/test/*.ets | grep -v TestUtils | sed 's/.*\///g' | sed 's/\.ets$//g'
    exit 1
fi

TEST_NAME=$1
TEST_FILE="entry/src/test/${TEST_NAME}.ets"

if [ ! -f "$TEST_FILE" ]; then
    echo "错误: 测试文件 $TEST_FILE 不存在"
    exit 1
fi

echo "=== 运行单个测试文件: $TEST_NAME ==="

# 创建临时的测试入口文件
TEMP_TEST_FILE="entry/src/test/TempSingleTest.ets"

cat > "$TEMP_TEST_FILE" << EOF
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { TestUtils } from './TestUtils';
import ${TEST_NAME} from './${TEST_NAME}';

export default function testsuite() {
  describe('${TEST_NAME}', () => {
    beforeAll(() => {
      TestUtils.log('🚀 开始执行 ${TEST_NAME}');
    });
    
    afterAll(() => {
      TestUtils.log('✅ ${TEST_NAME} 执行完成');
    });
    
    // 执行测试
    ${TEST_NAME}();
  });
}
EOF

# 运行单元测试
echo "--- 开始运行单元测试 ---"
"${HVIGOR_NODE}" "${HVIGOR_CLI}" --mode module -p module=phone@default -p unit.test.replace.page=../../../.test/testability/pages/Index -p product=default -p pageType=page -p isLocalTest=true -p unitTestMode=true -p buildRoot=.test UnitTestBuild --analyze=normal --parallel --incremental --daemon

# 清理临时文件
rm -f "$TEMP_TEST_FILE"

echo "--- 单个测试执行完成 ---"