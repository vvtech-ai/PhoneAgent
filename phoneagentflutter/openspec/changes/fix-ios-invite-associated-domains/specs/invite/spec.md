## ADDED Requirements

### Requirement: iOS邀请域名必须按环境显式配置
客户端 MUST 在Debug/Profile使用com.chaken.phoneagent.test并关联agent.vvtech.tech、phoneagent-ioslink.vvtech.tech；Release使用com.chaken.phoneagent并关联www.chaken.ai、ioslink.chaken.ai。

#### Scenario: 正式分享地址与API host不同
- **WHEN** 正式API使用chaken.ai或www.chaken.ai
- **THEN** 两种可信分享host均可解析，主分享host为www.chaken.ai，保持原路径与邀请码校验

#### Scenario: 测试与正式邀请隔离
- **WHEN** 收到其他环境的分享或专用邀请链接
- **THEN** 拒绝解析，不自动切换环境
