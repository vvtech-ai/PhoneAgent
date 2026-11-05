## MODIFIED Requirements

### Requirement: 平台身份安全
Android MUST 保留生产身份目标 com.vvtech.aiassistant，debug 使用 .dev；iOS Debug/Profile MUST 使用 com.chaken.phoneagent.test、Release 使用 com.chaken.phoneagent。没有正式签名不得输出伪 release 包。

#### Scenario: 安装基础调试包
- **WHEN** 安装 B0 debug 构建
- **THEN** 不覆盖 Android 正式包，iOS 使用已指定测试身份

#### Scenario: 主工程测试身份一致
- **WHEN** 直接使用主工程构建 iOS Debug 或 Profile
- **THEN** Runner Bundle ID 为 com.chaken.phoneagent.test，两个扩展分别采用该标识加 .KXLiveActivityExtension 和 .KXPushServiceExtension
- **AND** Release 仍使用正式主包及正式扩展身份，不依赖私有 defines 修改 Bundle ID
