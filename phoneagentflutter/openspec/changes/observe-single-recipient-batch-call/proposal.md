## Why

多路 Skill 在实际执行一人时仍留在批次进度，缺少已有单路实时通话体验。用户已于 2026-10-28 批准通用人数规则，并要求保护原通话门禁。

## What Changes

- 冻结执行名单一人时复用实时通话页；不限定 Skill。
- 保留确认、批次执行、权益、计费、重拨、结果及多人展示。
- 用归属校验的只读查询取得同 attempt 的真实启动事实；挂断沿用批次停止。
- Bug 23841：已结束批次后的下一次已确认单人执行必须重新观察，不依赖服务端未发送的 toolStart；同批重试和旧批隔离仍保持。

## Capabilities

### New Capabilities
- `single-recipient-batch-observation`: 一人批次通话的安全只读展示。

### Modified Capabilities
无。

## Impact

Agent SSE 新增只读接口，Flutter 增加观察适配器。无表、依赖、SDK/Phone/Netty 门禁变更。
