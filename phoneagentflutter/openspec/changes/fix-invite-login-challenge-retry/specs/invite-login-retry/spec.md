## ADDED Requirements

### Requirement: 核销前校验失败可安全重试
系统 MUST 仅在旧码只读校验阶段失败时恢复原未到期手机号凭证，MUST NOT 延长有效期或在核销启动后恢复；相同凭证 MUST 保留原子占用，成功核销一次。

#### Scenario: 错误旧码后替换正确码
- **WHEN** 同一手机号用未过期 challenge 提交旧码校验失败并改填有效码
- **THEN** 系统允许重试，失败阶段不核销，最终成功只核销一次

#### Scenario: 核销结果不明
- **WHEN** redeem 超时、返回异常或核销后账号初始化失败
- **THEN** 系统不通过恢复 challenge 重新核销，保留真实失败

### Requirement: App 明确处理凭证失效
App MUST 识别 SDK 的登录验证过期错误，在邀请码阶段清除旧 challenge 与短信码并返回现有登录表单；MUST 保留发送冷却且不自动发送短信。

#### Scenario: 返回登录重新验证
- **WHEN** 邀请码提交返回“登录验证已过期，请重新获取验证码”
- **THEN** App 显示明确原因，禁止继续用旧凭证提交，重新验证后才获得新凭证
