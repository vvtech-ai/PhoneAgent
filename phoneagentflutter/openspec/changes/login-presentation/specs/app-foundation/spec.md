## MODIFIED Requirements

### Requirement: 启动与配置隔离
应用 MUST 仅竖屏，校验 local/dev/prod 环境，缺少 API 配置不得发起业务请求。工程启动验证页迁移为登录页后，尚未接入的认证服务 MUST 明确返回不可用提示，不得模拟登录成功。

#### Scenario: 未配置或服务尚未接入
- **WHEN** 无 API_BASE_URL 启动开发包，或者认证适配尚未实现
- **THEN** 可展示登录表单，但提交/获取验证码显示不可用状态，不发真实短信、认证或外呼

#### Scenario: 非法环境或发布配置
- **WHEN** 环境未知、地址含凭据或 release 未显式使用 prod/HTTPS
- **THEN** 校验返回明确问题，不建立可用业务网络配置
