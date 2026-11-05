## Why

用户于2026-10-05确认执行“先建立差异台账和 OpenSpec”。Flutter 原迁移目标固定在旧 v65，而指定的 Android/iOS 当前源码已经演进。已有页面、正式装配、真实业务验收及新增功能必须分别取证，避免把旧结论当新版全量对齐，或重复开发已有能力。

## What Changes

- 固定 Android `0f8879e4baf1d56fe6d7f8f356101fdf61d602ed`、iOS `bb9ff34966f40a3c2794a9a8b8e935669a9faa12`、Flutter `75e0e256b3b193129126f7d8df8ef28a78f36c63` 为本轮只读比较来源。
- 建立按正式入口和调用链组织的功能差异台账，分别记录实现状态、验证证据、正常/失败/取消/离线/恢复/跨账号六类场景。
- 把邀请活动、产物下载、平台专属能力及历史排除项纳入核对；证据不足项保留待核实，不自动恢复旧页面。
- 将原页面编号、后续优先级、依赖及现有 change 关联起来；新增能力仅列后续 change 建议。
- 更新需求文档的本轮来源说明及工程索引；正式规格待验收归档时合并。

## Capabilities

### Modified Capabilities
- migration-governance: 增加新版原生功能对照、证据分级和范围冲突处理要求。

## Impact

仅修改文档和 OpenSpec；本次确认授权执行步骤一，不包含功能开发、真实短信/认证/外呼、设备安装或生产发布。原生参考仓库只读。Flutter 3.32.0/Dart 3.8.0、包身份和发布保护仍由现有规则管理。

交付入口：[功能差异台账](../../../docs/engineering/NATIVE_FEATURE_PARITY_MATRIX.md)。
