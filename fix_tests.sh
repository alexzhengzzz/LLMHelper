#!/bin/bash

# 批量修复测试文件中的常见编译错误

echo "开始批量修复测试文件..."

# 1. 修复 protected setTestTag 访问问题 - 改为 public
find /Users/alex/zmh/ohos/llmhap/ohosllm/entry/src/test/ -name "*.ets" -exec sed -i '' 's/protected setTestTag/public setTestTag/g' {} \;

echo "修复完成：setTestTag 方法访问权限"

# 2. 修复 notBeNull 为 notBeNull（如果存在）或使用其他断言
find /Users/alex/zmh/ohos/llmhap/ohosllm/entry/src/test/ -name "*.ets" -exec sed -i '' 's/\.notBeNull()/\.assertEqual(false)/g' {} \;

echo "修复完成：notBeNull 断言方法"

# 3. 修复 toEqual 为 assertEqual（如果存在）
find /Users/alex/zmh/ohos/llmhap/ohosllm/entry/src/test/ -name "*.ets" -exec sed -i '' 's/\.toEqual(/\.assertEqual(/g' {} \;

echo "修复完成：toEqual 断言方法"

echo "批量修复完成！"