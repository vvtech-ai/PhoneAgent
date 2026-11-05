## ADDED Requirements
### Requirement: 正式 API 新域名启用邀请策略
客户端 SHALL 在 prod 环境使用 HTTPS/443 的 phoneagent.chaken.net.cn API 时启用原正式邀请策略，保留原有正式 API 域名；不得把该 API 主机自动扩展为邀请链接主机。
#### Scenario: 正式 iOS 邀请入口
- **WHEN** prod API 为 https://phoneagent.chaken.net.cn/aiassistant-api/ 且收到 https://ioslink.chaken.ai/phoneagent/ios/invite/?code=VYFX
- **THEN** 邀请策略解析出 VYFX，后续按原账号与邀请授权流程处理
#### Scenario: 隔离及精确主机校验
- **WHEN** dev/test 配置该正式 API，或 prod 使用相似域名或非标准端口
- **THEN** 不启用邀请策略，原链接域名、路径与邀请码校验不放宽
