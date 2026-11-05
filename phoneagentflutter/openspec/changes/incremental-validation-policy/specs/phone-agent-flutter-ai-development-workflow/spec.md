## MODIFIED Requirements

### Requirement: 验证命令必须按影响范围执行
AI贡献者 MUST 按风险选择最小有效验证集合，日常小批不得无理由重复全量回归。

#### Scenario: 日常Flutter业务变更
- **WHEN** 修改lib、tool演练或test且影响范围明确
- **THEN** 执行analyze及受影响模块/直接调用方的定向测试
- **AND** 跨页接线追加关键连续流程冒烟，记录实际范围

#### Scenario: 扩大验证
- **WHEN** 跨模块里程碑、交付前或公共改动影响无法可靠界定
- **THEN** 执行全量并说明触发理由，不在后续未改相关代码时重复

#### Scenario: 使用通用验证脚本
- **WHEN** 运行scripts/verify.ps1
- **THEN** MUST 显式指定定向测试路径，或提供全量开关及原因；缺少范围、冲突或无效路径先失败，不默默执行全量
- **AND** Android构建和依赖刷新均显式开启，PlanOnly只输出命令计划不运行验证工具

#### Scenario: 平台与文档
- **WHEN** 修改平台、插件、依赖或构建链
- **THEN** 执行相关平台构建并保留阶段性设备验收
- **AND** 纯文档只需OpenSpec及diff/链接校验

#### Scenario: 验证失败或无法执行
- **WHEN** 验证失败或环境阻塞
- **THEN** 收窄复现与修复，明确未验证项，不用定向通过冒充全量或真机通过
