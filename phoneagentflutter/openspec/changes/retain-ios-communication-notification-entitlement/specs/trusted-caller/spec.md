## ADDED Requirements

### Requirement: 主包通讯通知权限完整保留
Debug/Profile/Release 主包模板 MUST 声明 com.apple.developer.usernotifications.communication=true；签名 MUST 仅在主包 profile 已授权时保留该项，最终 IPA 主包签名与 profile MUST 均为 true。两个 extension MUST 沿用各自合法授权，不将主包能力任意复制。

#### Scenario: 模板有权限但签名丢失
- **WHEN** 最终主包签名缺少该项或为 false
- **THEN** 拒绝交付，即使 APNs、邀请配置和扩展存在均正确

#### Scenario: 描述文件未授权
- **WHEN** 主包 profile 未授予通讯通知能力
- **THEN** 在签名前失败，不伪造权限、不改用其他身份
