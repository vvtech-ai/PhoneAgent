# phone-agent-flutter-ai-development-workflow 规范

## Purpose

定义 phone-agent-flutter 仓库的 AI 研发工作流，确保每次任务都从正确上下文开始，按 OpenSpec 约束推进，并在完成前执行与影响范围匹配的验证命令。
## Requirements
### Requirement: AI 任务必须从仓库上下文开始
AI 贡献者在修改代码、需求、设计稿或 OpenSpec artifact 前 MUST 先阅读仓库级规则、当前需求基线和相关 capability spec。

#### Scenario: 新任务开始
- **WHEN** AI 贡献者接到本仓库任务
- **THEN** 必须先阅读 `AGENTS.md`
- **AND** 必须按任务范围阅读相关需求文档和 `openspec/specs/<capability>/spec.md`

#### Scenario: 执行 active change
- **WHEN** 任务对应 `openspec/changes/<change-id>/`
- **THEN** 必须阅读该 change 下的 `proposal.md`、`design.md`、`tasks.md` 和 delta spec

### Requirement: 修改前必须说明方案和验证计划
AI 贡献者在进行有行为影响的修改前 MUST 说明问题理解、修改范围、状态流影响和验证计划。

#### Scenario: 需要修改代码
- **WHEN** 任务需要修改代码
- **THEN** 必须先说明将修改的模块、状态或数据影响、边界影响和验证命令

#### Scenario: 纯文档或规格变更
- **WHEN** 任务只修改文档、OpenSpec spec 或 AGENTS 规则
- **THEN** 可以不等待额外确认直接执行
- **AND** 仍必须运行 OpenSpec 校验

### Requirement: 行为变化必须通过 OpenSpec change 管理
新增或修改产品行为、交互规则、平台能力、数据模型、构建基线或 AI 工作流时 MUST 先创建或更新 OpenSpec change，除非用户明确要求直接修订 baseline。

#### Scenario: 新增行为
- **WHEN** 任务会改变用户可见行为、接口契约、数据模型、权限、构建或验收标准
- **THEN** 必须创建或更新 `openspec/changes/<change-id>/`
- **AND** 必须包含 `proposal.md`、`design.md`、`tasks.md` 和对应 delta spec

#### Scenario: 执行 change 任务
- **WHEN** AI 贡献者实现 active change 中的任务
- **THEN** 必须按 `tasks.md` 小批次推进
- **AND** 完成任务后必须更新对应 checkbox

### Requirement: 实现必须按职责拆分并保持可回滚
AI 贡献者修改工程代码时 MUST 按职责拆分，保持小批次、可验证、可回滚。

#### Scenario: 文件出现多职责
- **WHEN** 一个文件同时承载展示、状态编排、业务规则、平台能力、本地存储、接口或 mock 数据中的多个职责
- **THEN** 必须评估并执行职责拆分

#### Scenario: 文件超过 500 行
- **WHEN** 单个文件超过 500 行且计划继续新增逻辑
- **THEN** 必须评估是否拆分
- **AND** 如果不拆分，必须说明理由

### Requirement: 验证命令必须按影响范围执行
AI 贡献者完成每个有意义批次后 MUST 按风险运行最小有效验证集合，日常小批不得无理由重复全量回归，并在最终汇报中报告实际范围。

#### Scenario: OpenSpec 或流程文档变更
- **WHEN** 修改 `openspec/`、`AGENTS.md` 或工程流程文档
- **THEN** 必须运行 `openspec validate --all`

#### Scenario: Flutter 业务代码变更
- **WHEN** 修改 Flutter `lib`、`tool` 或 `test` 且影响范围明确
- **THEN** 必须运行 `flutter analyze`
- **AND** 必须运行受影响模块和直接调用方的定向 `flutter test <paths>`，跨页接线追加关键连续流程冒烟

#### Scenario: 扩大验证
- **WHEN** 跨模块里程碑、交付前或公共改动影响无法可靠界定
- **THEN** 执行全量并说明触发理由，不在后续未改相关代码时重复

#### Scenario: 使用通用验证脚本
- **WHEN** 运行scripts/verify.ps1
- **THEN** 必须显式指定定向测试路径，或提供全量开关及原因；缺少范围、冲突或无效路径先失败，不默默执行全量
- **AND** Android构建和依赖刷新均显式开启，PlanOnly只输出命令计划不运行验证工具

#### Scenario: Android APK 或平台能力变更
- **WHEN** 修改 Android 配置、Flutter 插件、平台能力、依赖或 APK 产物链路
- **THEN** 必须运行 `flutter build apk --debug`

#### Scenario: 推荐验证命令
- **WHEN** 需要验证本项目
- **THEN** 推荐命令为：

```powershell
openspec validate --all
Set-Location .
flutter analyze
flutter test
flutter build apk --debug
```

#### Scenario: 无法运行验证
- **WHEN** 因环境、网络、设备或工具链问题无法运行验证命令
- **THEN** 最终汇报必须明确说明未验证项、失败命令和原因

### Requirement: 完成汇报必须包含验证证据
AI 贡献者在声明任务完成前 MUST 已经读取验证命令输出，并在最终回复中报告关键结果。

#### Scenario: 验证通过
- **WHEN** 所有应运行验证命令均返回成功
- **THEN** 最终汇报必须列出命令和通过结果

#### Scenario: 验证失败
- **WHEN** 任一验证命令失败
- **THEN** 不得声称任务完成
- **AND** 必须报告失败命令、失败摘要和下一步处理建议

### Requirement: OpenSpec artifact 必须保持中文和可校验格式
本仓库 OpenSpec artifact MUST 默认使用简体中文表达，并保留 OpenSpec 解析依赖的英文结构标记。

#### Scenario: 编写 baseline spec
- **WHEN** 新增或修改 `openspec/specs/<capability>/spec.md`
- **THEN** 必须使用 `## Purpose`、`## Requirements`、`### Requirement:` 和 `#### Scenario:`
- **AND** 每个 requirement 正文必须包含 `MUST` 或 `SHALL`

#### Scenario: 编写 change delta spec
- **WHEN** 新增或修改 `openspec/changes/<change-id>/specs/<capability>/spec.md`
- **THEN** 必须使用 `## ADDED Requirements`、`## MODIFIED Requirements`、`## REMOVED Requirements` 或 `## RENAMED Requirements`

### Requirement: OpenSpec 归档必须在验收后执行
active change 完成实现和验证后 MUST 归档，并把最终能力合并回 baseline specs。

#### Scenario: change 实现完成
- **WHEN** 一个 active change 的任务全部完成且验证通过
- **THEN** 必须将最终需求合并进 `openspec/specs/`
- **AND** 将 change 移入 `openspec/changes/archive/`

#### Scenario: change 尚未验收
- **WHEN** change 尚未实现、尚未验证或尚未被用户验收
- **THEN** 不得归档
- **AND** 必须保留在 `openspec/changes/` 作为后续任务来源

### Requirement: 工具故障须有限恢复并继续独立工作
AI贡献者遇到工具调用错误 MUST 先重新读取当前状态、核对参数及执行结果，再有限重试；仍失败时记录未验证项，继续不依赖该工具的已授权工作，不因单项模拟器故障停止整体开发。

#### Scenario: 模拟器或电脑操作状态失效
- **WHEN** 工具提示Bad Request、会话失效或状态不可用
- **THEN** 重新获取App或页面的当前状态并按新的控件信息调用，不复用旧编号或坐标
- **AND** 默认重试一次，仅在新证据出现时再重试一次，不无限重复相同失败操作

#### Scenario: 恢复后仍失败
- **WHEN** 有限恢复仍未成功
- **THEN** 记录时间、工具和动作、错误摘要、已发生的执行结果及未验证项
- **AND** 继续独立代码、定向测试、文档或其他可用平台工作，保留设备验证待验状态

#### Scenario: 有副作用动作的执行结果不明确
- **WHEN** 失败的操作可能已触发上传、短信、身份采集、外呼、收费或数据修改
- **THEN** 先核实执行结果和既有授权，不盲目重复，不通过卸载、清数据或扩大权限绕过故障

#### Scenario: 对话请求被平台终止
- **WHEN** 平台拒绝请求并终止agent轮次
- **THEN** 不把后台命令仍运行表述为agent持续推进，也不承诺当前轮次自行恢复
- **AND** 后续恢复从磁盘记录、Git状态及实际进程输出接续，避免重复已完成操作
