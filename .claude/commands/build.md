使用build.sh编译并且修复一下编译错误（只处理相关的编译问题且不处理 warning），遵循 arkts 状态变量v2语法规范
# 注意(以下只是ark 规范，如果没有这些编译报错可以忽略)
1、不能用 esobject / object / any / unknown 要显式声明具体类型
2、UI （build）里面不能写非 UI 的语法
3、delete关键字不存在