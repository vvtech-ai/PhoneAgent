## MODIFIED Requirements

### Requirement: 启动与配置隔离
基础应用 MUST 仅竖屏，校验 local/dev/test/prod 环境，缺少 API 配置不得发起业务请求，启动验证页不得宣称业务已完成。test MUST 使用显式服务地址和非生产 SDK 规则，不自动选择域名。

#### Scenario: 测试环境
- **WHEN** APP_ENV=test 且三个服务地址有效
- **THEN** Debug/Profile 配置可用，保留独立服务路由及非生产 SDK 选择

#### Scenario: 未配置 API
- **WHEN** 无 API_BASE_URL 启动开发包
- **THEN** 展示明确未配置状态，不发真实短信、认证或外呼

#### Scenario: 非法环境或发布配置
- **WHEN** 环境未知、地址含凭据或 release 未显式使用 prod/HTTPS
- **THEN** 校验返回明确问题，不建立可用业务网络配置，test 不豁免 Release 限制
