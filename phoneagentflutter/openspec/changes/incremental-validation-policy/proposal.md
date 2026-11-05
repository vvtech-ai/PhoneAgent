## Why

用户2026-09-20要求加速交互迁移，停止每个小批次重复执行两千余项全量测试。

## What Changes

- 日常按影响范围选择模块测试及关键连续流程冒烟。
- 全量仅在跨模块里程碑、交付前或无法界定公共改动影响时执行。
- 未修改平台/依赖/构建链不重复打双端包，阶段安装仍保留。

## Capabilities

### Modified Capabilities
- phone-agent-flutter-ai-development-workflow: 分级验证节奏。

## Impact

仅工程规则，不变更产品、接口或数据。记录执行范围，不冒充全量通过。
