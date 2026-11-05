# migration-governance

## Purpose

记录已批准的目标契约；实现进度以 active change/tasks 为准，不代表已完成验收。

## Requirements

### Requirement: 有效范围与设计依据
项目 MUST 以 v65 4c781e3cc 及用户答复决定行为，以设计提交 0cd58de9bb 的 memory/index.html 呈现现有功能；MUST NOT 引入设计独有记忆、旧对话模式、国内 App SIP 或可信来电 SDK。

#### Scenario: 设计稿包含新版本功能
- **WHEN** 页面或入口仅在设计稿存在而 v65 无有效实现
- **THEN** 标记排除，不自动生成可访问入口

### Requirement: 文件按职责管理
手写源码 MUST 默认不超过 500 行；超过时可保留极少数单职责例外，但 MUST 在工程记录说明理由、验证与复核条件；300 行不得成为机械拆分触发条件。

#### Scenario: 单职责文件超过 500 行
- **WHEN** 保留该文件比拆分更有利于维护
- **THEN** 显式记录例外；多职责文件仍必须拆分

### Requirement: 里程碑 Git 和规格同步
关键改动 MUST 在验证后提交并推送用户指定远端；不得 force push、提交密钥/构建缓存或把未验证部分标完成。OpenSpec tasks MUST 随实现更新，用户验收前不得归档。

#### Scenario: 远端不可用
- **WHEN** 尚无可用远端或认证失败
- **THEN** 明确报告未同步，不伪称 push 成功，不换推送目的地
