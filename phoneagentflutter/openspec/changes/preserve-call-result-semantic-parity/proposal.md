## Why

旧版 OnlineAndRestoredReceiptIsomorphismTest 逐项保护五种语义结果在实时和恢复入口一致；Flutter 分散的结果测试缺少同 fixture 等价回放。源码将 reported 原 outcome 用归一 transport status 反推，会丢失 NEEDS_RECALL / USER_CANCELLED 语义。

## What Changes

- 迁移五种结果的真实 controller、恢复与只读详情等价回归。
- 保留 reported 原始语义；传输状态继续按既有映射归一。
- 检查字段、原因、展示状态、顺序，以及恢复无命令 / 无 TTS。

## Capabilities

### New Capabilities

- `call-result-semantic-parity`: 实时与历史保持完整语义结果。

### Modified Capabilities

无。

## Impact

局部回执投影与测试，不改变 API、数据库、评分政策或媒体行为。对应 ENTRY-05 / 06、HISTORY-01、VOICE-01。
