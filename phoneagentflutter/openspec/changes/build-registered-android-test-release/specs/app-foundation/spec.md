## MODIFIED Requirements

### Requirement: 启动与配置隔离
基础应用 MUST 仅竖屏，校验 local/dev/test/prod 环境，缺少 API 配置不得发起业务请求，启动验证页不得宣称业务已完成。Release MUST 显式使用 test 或 prod，且所有配置的服务地址均为有效 HTTPS；dev/local Release 保持拒绝。

#### Scenario: 未配置 API
- **WHEN** 无 API_BASE_URL 启动开发包
- **THEN** 展示明确未配置状态，不发真实短信、认证或外呼

#### Scenario: 测试 Release
- **WHEN** APP_ENV=test 且 API、SDK API 和 Runtime 配置均为有效 HTTPS
- **THEN** 配置可用，沿用独立服务路由和测试环境 SDK 规则

#### Scenario: 非法环境或发布配置
- **WHEN** 环境未知、地址含凭据或 Release 使用 dev/local/HTTP
- **THEN** 校验返回明确问题，不建立可用业务网络配置
