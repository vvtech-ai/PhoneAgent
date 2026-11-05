## MODIFIED Requirements

### Requirement: 有效范围与设计依据
项目 MUST 保留 v65 4c781e3cc 及用户答复作为既有实现基线，以设计提交 0cd58de9bb 的 memory/index.html 呈现现有功能；新版对齐目标 MUST 另以 Android 0f8879e4baf1d56fe6d7f8f356101fdf61d602ed、iOS bb9ff34966f40a3c2794a9a8b8e935669a9faa12 的有效入口与调用链核对 Flutter 75e0e256b3b193129126f7d8df8ef28a78f36c63。历史排除的国内 App SIP、可信来电 SDK MUST 纳入差异台账及后续设计，不把本次文档确认当成业务实现验收。MUST NOT 凭设计稿、类名或失效入口增加记忆、支付或旧独立对话模式。

#### Scenario: 新版原生具有原先排除的有效能力
- **WHEN** 正式导航和实际调用链证明新版原生存在有效能力
- **THEN** 记录历史范围变化、Flutter 差距与后续 change 依赖
- **AND** 实现细节由后续能力规格定义，本次不修改运行行为

#### Scenario: 仅存在组件或占位处理
- **WHEN** 找不到正式入口，或入口仅执行本地占位动作
- **THEN** 标记待核实或明确占位边界，不声明完整业务已经实现

## ADDED Requirements

### Requirement: 原生差异台账必须可追溯
台账 MUST 按业务入口分配稳定 NF 编号，记录原生调用链、Flutter 接线、固定源码版本、实现状态、验证证据、缺口、优先级及后续任务依赖，并关联原 P01–P29/P08a。MUST 区分源码接线、自动化、真实接口、真机与生产升级证据；历史报告 MUST 保留日期和范围。

#### Scenario: 已有页面但缺少真实媒体证据
- **WHEN** 页面、控制器和平台端口已接线，仅有模拟场景通过
- **THEN** 记录已接线及真实能力待验，不标缺失，也不标端到端通过

### Requirement: 每项能力必须定义六类验收场景
每项 NF MUST 覆盖正常、失败、取消、离线、恢复和跨账号六类预期；不适用项 MUST 说明原因。平台差异 MUST 独立记录权限、后台、中断、外部链接及升级等场景。验收预期 MUST NOT 被当作本轮测试结果。

#### Scenario: 平台实现方式不同
- **WHEN** Android 系统记录、APK 更新与 iOS App 记录、外部更新或扩展能力不同
- **THEN** 记录平台等价目标与限制，分别安排验收，不复制另一平台不可用实现
