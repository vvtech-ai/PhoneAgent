## Why

首页积分和统一页结果评价尚未迁移。先按 v65 建立可自动验证的接口/状态基础，避免后续页面臆造余额、评价字段或奖励。

## What Changes

- 钱包余额/20条分页流水读取、失败保留已知快照、不把未知余额当0。
- 独立赞踩协议与条件评分协议：GOOD/BAD 与1–5分不合并；资格必须匹配CALL/BATCH回执归属。
- 仅合成请求测试，无真实积分/评分写入，无充值入口。计费、激活赠送、页面挂载、草稿持久化后续接入。

## Capabilities

### New Capabilities
- `wallet-feedback-core`: 钱包与评价协议基础。

### Modified Capabilities

无。

## Impact

新增 points/feedback domain/data/controller，复用 AccountApi。无平台/依赖/后端/数据库/提示词/SIP/ASR/TTS变更；不记录账户、评价正文或凭据。测试/analyze/OpenSpec门禁，无新设备安装。
