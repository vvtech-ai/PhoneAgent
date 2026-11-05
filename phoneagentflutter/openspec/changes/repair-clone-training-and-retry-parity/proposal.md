## Why
2026-10-19 用户批准对齐 aiassistant-app 1.6.0 的认证失败恢复，修复 iOS 试听 561017449，以及 Seeduplex 旧槽位结果被当作本次成功的问题。

## What Changes
- 明确失败返回填写身份页，同一流程保留输入和授权，脱敏显示；未知结果只同步。
- 在拥有媒体租约时显式准备 iOS playback/default/mixWithOthers 会话，保留取消和资源释放。
- 持久化 Seeduplex 提交前训练版本，核对本次版本变化才确认成功、扣费；旧 READY 不作为成功证据。保护候选、确认及当前音色试听入口。

## Capabilities
### New Capabilities
- clone-training-and-retry-parity：认证重试及训练结果归属。

## Impact
Flutter codex/dev 与 Java feature/test_v1.7.0（common、SDK、SSE）；原生1.6.0只读。新增训练证据表，保护设置、激活、试听及实际通话，不自动执行业务迁移、退款或部署。音质门槛、每日次数、成功冷却和价格不变；真实认证、供应商训练及iOS设备验收独立待验。
