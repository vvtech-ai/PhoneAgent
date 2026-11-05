# 设计

## 状态边界

`BatchProgressTracker` 接收的路由进度是物理层临时快照。`UNCLEAR`、`PENDING` 和未知值不是成功，也不代表批次最终结束；只有最终 `BATCH_CALL_RESULT` 才能覆盖临时快照并决定业务结果。

## 实现

在 `BatchProgressTracker.headline` 中显式处理待裁决状态，并把未知值安全降级为“结果待确认”。成功、失败、取消、振铃、通话中和核对中的既有文案保持不变。

续批将线路繁忙排队与等待呼叫统一显示为“等待呼叫中”。进度卡按规范化状态映射，逐路回执只覆盖这三个等待状态的 headline；status、detail、运行中判断、顺序与终态裁决保持原值。此规则只调整展示，不能据此推断该路已经发起呼叫。

## 验证

运行批量进度 tracker 定向测试、Flutter analyze 和 OpenSpec 校验。真实 dev 批次日志作为问题证据保留在交付说明中，不在客户端伪造或重放真实外呼。
