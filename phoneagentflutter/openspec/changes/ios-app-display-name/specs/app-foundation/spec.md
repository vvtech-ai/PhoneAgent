## ADDED Requirements

### Requirement: iOS 显示名称与包身份对应
iOS Runner MUST 在Bundle ID为com.chaken.phoneagent时显示PhoneAgent，在Bundle ID为com.chaken.phoneagent.test时显示PhoneAgent test。

#### Scenario: 正式包名称
- **WHEN** 构建Release正式包com.chaken.phoneagent
- **THEN** CFBundleDisplayName为PhoneAgent

#### Scenario: 测试包名称
- **WHEN** 构建Debug或Profile测试包com.chaken.phoneagent.test
- **THEN** CFBundleDisplayName为PhoneAgent test
