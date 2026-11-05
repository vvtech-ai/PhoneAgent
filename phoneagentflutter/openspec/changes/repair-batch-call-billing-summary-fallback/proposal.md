## Why

批量通话结果卡目前从 `batchCallResult.items[*].billingSummaries` 读取积分结算。Timeline 若已保存同一 `callAttemptId` 的结构化单路 `callReceipt.billingSummary`，但批量快照缺失账单，批量卡仍会漏显扣费信息。

禅道 23781 的客户端诊断证明最终 `batchCallResult` 事件已到达，但附件没有保存结果正文，无法确认该次原始批量 payload 是否包含账单字段。因此本变更只修复可由当前 Timeline 事实安全恢复的客户端投影缺口，不推断该现场的最终根因。

## What Changes

- 批量结果项自身账单列表为空时，允许从同一会话、同一 `callAttemptId` 的结构化单路通话回执补齐账单展示。
- 批量结果项已有账单时保持其权威性，不追加或覆盖。
- 缺少精确身份匹配或结构化账单时不推算金额、不从钱包流水反查，也不跨会话/线路借用账单。

## Capabilities

### New Capabilities

- `batch-call-billing-receipt`: 批量回执基于同一通话尝试的 Timeline 账单事实恢复积分结算展示。

## Impact

影响 Flutter 会话领域 `BatchReceiptProjector` / `BatchReceiptItem` 及对应 Dart 定向测试；不修改后端、钱包余额口径、扣费规则或通话状态机。真实 23781 payload 是否缺 `billingSummaries` 仍待服务端原始回包核验。
