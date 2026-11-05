# 设计
aiassistant_app AssistantCallsDialSheet使用translateEnabled && promptBeforeTranslationDial。Flutter当前只判断prompt，故关闭翻译时仍自动弹出。本轮按确认计划给现有_call条件增加enabled，不修改弹层/控件/文案/样式，也不清除prompt偏好。手动入口仍可打开，预设确认调用presetsConfirmed保持单次流程。

业务微批1个源码文件，测试独立1文件；固定Flutter3.32/Dart3.8，验证双平台样式分支及enabled/prompt四组合、手动确认、取消、既有页面与跨境边界、主流程冒烟。无需全仓或双端构建。当前其他准备链路/跨境及iOS SDK修改不混入提交，不归档。
