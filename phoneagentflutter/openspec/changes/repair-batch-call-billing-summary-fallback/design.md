## Context

`CallReceiptProjector` 已按 `(sessionId, callAttemptId)` 聚合 Timeline 通话事实，并从 `CALL_OUTCOME_REPORTED.callReceipt.billingSummary` 读取结构化结算。`BatchReceiptProjector` 当前只解析最终批量结果 payload，未复用这些已落入同一 Timeline 的单路结算事实。

## Goals / Non-Goals

**Goals:**

- 批量结果 payload 缺少某一路的账单时，若 Timeline 存在相同会话和通话尝试的有效结算回执，则展示该结算。
- 保持投影确定性、按身份隔离及幂等。

**Non-Goals:**

- 不把钱包余额差、积分流水、通话时长或失败提示转换成账单。
- 不覆盖批量 payload 已提供的结算，不改变扣费或余额刷新策略。
- 不声称解决了原始 payload 未取得的 23781 服务端根因。

## Decisions

1. `BatchReceiptProjector` 在已有 Timeline 事实集合内调用单路回执投影，按 `(sessionId, callAttemptId)` 建立账单候选。
2. 仅当批量项 `billingSummaries` 为空且 `attemptId` 非空时补入该精确匹配项的结构化 `ReceiptBilling`；绝不跨 session 或 attempt 匹配。
3. 原批量列表非空时完全保留原列表；无候选账单时保留空列表，UI 不展示虚构金额。
4. 验证覆盖缺失批量账单时精确 attempt 补齐、跨 session/attempt 不匹配、批量原账单优先及缺少账单不造数。

## Risks / Trade-offs

- 若后端最终批量结果和 Timeline 单路事实在“重试”语义上不是同一 attempt，精确 ID 门禁会选择不补，而不会误显示另一通账单。
- 真实问题也可能是 Timeline 与批量结果都缺账单；本客户端修复不能修复这种服务端缺失，需通过原始 test 回包判定。

## Verification

- 先运行批量回执投影定向测试，确认新增反例在实现前失败。
- 实现后运行 `flutter test test/features/conversation/batch_receipt_test.dart`、`flutter analyze` 及 OpenSpec 全量校验。
- 不执行外呼、打包、安装或远程环境操作。
