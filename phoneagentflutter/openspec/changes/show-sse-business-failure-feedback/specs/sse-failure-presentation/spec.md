## ADDED Requirements

### Requirement: 业务、积分与系统失败有稳定可见反馈

App SHALL 对 `task_failed` 中的 `BUSINESS_REJECTED`、`POINTS_INSUFFICIENT_BALANCE` 与 `INTERNAL_ERROR` 展示各自固定安全中文提示，不能把业务拒绝说成系统不可用，亦不得展示上游异常原文。既有会员专用回复与通话积分结果卡 SHALL 保持原行为。

#### Scenario: 通用业务拒绝

- **WHEN** SSE 发送 `BUSINESS_REJECTED`
- **THEN** 对话显示“本次操作未完成，请检查后重试”类提示，而非通用服务异常

#### Scenario: 积分不足或系统异常

- **WHEN** SSE 发送 `POINTS_INSUFFICIENT_BALANCE` 或 `INTERNAL_ERROR`
- **THEN** 分别提示补充积分或统一系统异常文案，忽略上游原始异常文本
