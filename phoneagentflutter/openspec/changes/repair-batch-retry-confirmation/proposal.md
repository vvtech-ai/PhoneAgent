## Why
批量任务重拨一人时可误走 makeCall；语义识别异常与真实不明确混淆。用户已于2026-10-29批准本方案及实施、独立回归、推送 test_v1.8.0_fix，客户端修改时打测试签名包，不安装。
## What Changes
- 公共 batch_plus 流程阻止普通单呼逃逸，要求重新生成保留目标身份的批量确认卡。
- 拨打确认提供明确问题上下文，异常有界重试，成功判断不重试；失败与不明确分开。
- 同一次确认请求复用结果并核对当前卡片；原单/多路自然语义、记忆确认及执行门禁保持。
## Capabilities
### Modified Capabilities
- task-orchestration: 批量重拨和语义确认连续性。
## Impact
Java Agent编排、Flutter确认反馈；无数据库变更，无部署和实际外呼。
