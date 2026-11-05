## ADDED Requirements

### Requirement: 认证必须使用真实接口契约
配置有效时客户端 MUST 通过现有sms/send-code及sms/login接口处理认证，检查HTTP与业务响应码，保留baseURL前缀且不自动重试或跨域转发凭据。

#### Scenario: 邀请挑战
- **WHEN** 登录返回inviteRequired和loginChallenge
- **THEN** 不建立登录会话，继续邀请码流程，提交邀请码时携带challenge且code为空

#### Scenario: 错误或不完整成功
- **WHEN** 服务端失败或成功结果缺少账号/令牌
- **THEN** 展示失败，不保存伪会话

### Requirement: 会话保存必须安全且隔离环境
会话 MUST 使用设备安全存储，按环境和baseURL隔离；MUST NOT 保存验证码/邀请码/challenge或输出凭据日志。

#### Scenario: 登录后重启
- **WHEN** 成功保存后重新启动相同环境
- **THEN** 恢复同一账号会话，不要求再次发送短信

#### Scenario: 保存失败
- **WHEN** 网络登录成功但本地存储失败
- **THEN** 不宣称已完成会话交接，可重试保存且不重复认证请求

#### Scenario: 恢复失败
- **WHEN** 安全存储无法读取
- **THEN** 显示恢复失败和重试，不默默覆盖原会话

### Requirement: 真实验证必须限定授权范围
真实验证 MUST 只使用本轮授权账号和确认环境，通过弹窗获得验证码；MUST NOT 提交真实值或进行未经授权的外呼。

#### Scenario: 首次真实登录验证
- **WHEN** 自动测试及构建完成
- **THEN** 才发送验证码并请求用户输入，邀请码只在服务要求时提交
