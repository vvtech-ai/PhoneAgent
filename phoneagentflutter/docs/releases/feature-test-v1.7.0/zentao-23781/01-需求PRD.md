# 禅道 23781 批量通话积分回执修复

## 需求来源

禅道 Bug 23781：多路批量任务通话期间后台积分流水出现扣费，但当时的会话结果未显示扣除积分信息，并出现通话自动挂断提示。

## 当前证据

- 附件截图显示账户流水有一笔 `-160`，并说明为 QwenOmniPlus 批量外呼第 2 路任务通话扣除；通话页面截图显示自动挂断提示，结果卡未显示积分扣除字段。
- 客户端 diagnostics 在对应时段记录 `finalResponse / batchCallResult` 后有 `committed`，但附件没有保存最终 batchCallResult 或 Timeline 原始 payload 正文。
- 当前客户端 `BatchReceiptItem` 只解析批量项 `billingSummaries`；`BatchReceiptCard` 仅渲染已解析账单。单路 `CallReceiptProjector` 可从 Timeline 通话事件回执解析 `billingSummary`，但批量投影尚未按 attempt 复用。

## 修复目标与边界

批量项没有账单列表时，若 Timeline 有同一 session、同一 callAttemptId 的结构化账单，则在批量回执中显示；现有批量账单优先。没有精确匹配时不推算金额、不借用其他通话账单。该改动修复客户端可恢复的投影缺口，不能单独证明 23781 现场的批量 payload 缺字段，也不代替真实环境复现。
