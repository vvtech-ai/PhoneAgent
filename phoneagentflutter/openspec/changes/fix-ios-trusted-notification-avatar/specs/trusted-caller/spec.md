## ADDED Requirements
### Requirement: iOS 主应用必须登记通讯通知 intent
iOS 主应用 MUST 在 NSUserActivityTypes 声明通知扩展用于通讯通知转换的 INSendMessageIntent，并保留主应用 communication entitlement 和通知服务扩展入口。

#### Scenario: 通知扩展使用发送消息 intent
- **WHEN** 可信来电扩展通过 INSendMessageIntent 捐赠和转换通知
- **THEN** Runner 与通知扩展均声明支持该 intent
- **AND** 配置回归能够发现仅扩展声明、主应用遗漏的情况

#### Scenario: 实机头像验收证据不足
- **WHEN** 只有点击后的应用内头像成功诊断或本地编译通过
- **THEN** 不得将其表述为系统通知头像已验收
- **AND** 缺失头像和超时仍沿用既有回退策略，不改 Flutter UI
