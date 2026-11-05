## ADDED Requirements

### Requirement: APNs 签名权利与失败证据
客户端 MUST 为 Debug/Profile 声明 development APNs 权利，为 Release 保留 production；MUST 分别记录通知授权、token 收到、SDK 绑定结果。注册失败仅允许固定错误域分类和有符号32位错误码，不输出 token、凭据或系统错误正文。

#### Scenario: 测试身份注册
- **WHEN** 构建 Debug/Profile 的 com.chaken.phoneagent.test
- **THEN** 使用既有 APNs 环境变量声明 aps-environment，保留关联域名，并核对 profile 与实际签名权利

#### Scenario: 系统注册失败
- **WHEN** iOS 返回注册失败 NSError
- **THEN** 仍记录失败，保留白名单错误域与合法整数码，过滤描述和自定义字段，不触发伪造 token 或绕过账号门禁

#### Scenario: 设备验收尚未执行
- **WHEN** 仅源码与自动回归通过
- **THEN** 不报告 token 获取或 SDK 绑定成功，签名成包与真机分别待验
