## Why

首页默认可点击普通卡片缺 opening，且配置加载等待网络、标语读写。网络失败还丢弃有效缓存，与已批准 task-orchestration-v1.1 ENTRY-01/02 的完整入口快照及后台更新下次进入生效要求不符。

## What Changes

- 从 v66 同 SHA Skill frontmatter 逐字补全随包普通开场。
- 有效缓存先返回，无缓存使用完整随包入口；HTTP 单飞后台更新仅写缓存，下次读取生效，关闭后旧响应失效。
- 有效快照先发布，不等待 slogan 持久化；拒绝缺普通开场的可点击配置。

## Capabilities
### New Capabilities
- `home-entry-snapshot-readiness`：完整入口快照与非阻塞后台刷新。
### Modified Capabilities
- 无；落实已批准规则。

## Impact

仅 home defaults、DTO mapper、repository、controller 及聚焦测试；复用既有 HomeRepository 接口和导航冻结行为。真实模型、权益、权限与版本门禁不变；无 API、数据库、SIP、ASR/TTS 协议或真实外呼变化。
