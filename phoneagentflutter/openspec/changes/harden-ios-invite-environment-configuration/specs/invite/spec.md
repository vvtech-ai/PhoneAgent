## ADDED Requirements

### Requirement: iOS 邀请配置按运行环境核对
客户端 MUST 对 prod/test/dev 显式选择邀请配置，构建前检查 Dart APP_ENV 与 Xcode 邀请域名、Scheme、Bundle ID 和实际权限模板一致；未知或串用环境 MUST 拒绝签名构建。

#### Scenario: 测试 API 不得沿用正式邀请权限
- **WHEN** APP_ENV 为 test
- **THEN** 必须选择 test 邀请配置、测试 Bundle ID 和 phoneagent-test Scheme
- **AND** 必须关联 phoneagent-ioslink.vvtech.tech 与 chakenai-test.vvtech.tech

#### Scenario: 开发和正式分别配置
- **WHEN** 选择 dev 或 prod 环境
- **THEN** dev 关联 phoneagent-ioslink.vvtech.tech 与 chakenai-dev.vvtech.tech，兼容 agent.vvtech.tech
- **AND** prod 关联 ioslink.chaken.ai 与 www.chaken.ai，保持 chaken.ai 分享解析兼容
- **AND** 不改变现有 dev/test 共用身份，不宣称可以同时独立安装

### Requirement: iOS 邀请交付必须检查最终签名权限
交付验证 MUST 检查最终 App/IPA 的 Associated Domains、邀请 Scheme、环境标记、Bundle ID、签名 application-identifier 及描述文件授权；仅源码设置正确 MUST NOT 视为验收通过。

#### Scenario: 网页域名重复覆盖专用唤起域名
- **WHEN** 签名包缺少目标环境专用唤起域名，或邀请域名包含其他环境域名
- **THEN** 验证返回非零并阻止作为通过门禁的产物交付

#### Scenario: 描述文件不授权关联权限
- **WHEN** 描述文件缺少或不允许最终签名的关联域名、应用身份或团队
- **THEN** 成包检查失败，不重签、不改变身份、不通过卸载或清数据绕过
