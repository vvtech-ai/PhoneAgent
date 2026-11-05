# 展示 SSE 业务与系统失败提示

## Why

SSE 将通用业务拒绝和积分不足按稳定错误码区分。App 需要给用户明确反馈，并保持系统异常的安全统一提示。

## What Changes

- 对 `BUSINESS_REJECTED` 与 `POINTS_INSUFFICIENT_BALANCE` 展示固定中文提示。
- 对系统异常继续使用统一安全提示，不展示上游异常原文。

## Impact

只修改对话失败提示映射及定向测试；不改请求、任务状态、拨号或购买流程。
