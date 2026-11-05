## ADDED Requirements

### Requirement: 海外创建兼容原生IOException重试
客户端 MUST 在默认媒体能力创建遭HTTP拒绝或网络I/O失败时，仅移除capabilities重试一次；第二次失败 MUST 上抛，不循环。成功响应的解析或会话校验失败 MUST 不重建；已知会话仍清理。UI及提示 MUST 保持不变。
#### Scenario: 普通400或网络失败
- **WHEN** 首次创建HTTP400、其他HTTP拒绝或网络I/O失败
- **THEN** 第二次请求仅移除capabilities，其余body和账号header不变
#### Scenario: 第二次仍失败
- **WHEN** 兼容请求失败
- **THEN** 不产生第三次创建，不自动发起对端电话
#### Scenario: 已知会话解析失败
- **WHEN** 成功响应包含会话ID但录音或媒体字段无效
- **THEN** 清理已有会话并报错，不兼容重建
