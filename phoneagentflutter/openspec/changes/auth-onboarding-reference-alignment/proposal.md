## Why
用户于2026-10-09批准登录、邀请码、欢迎页及两步初始化修改计划。覆盖旧Android无协议、提交可返回、模型成功后推进的规则。
## What Changes
- 两端协议门禁、手机号变更清凭证、共用Toast和原生键盘。
- 邀请草稿持久化、返回消费入口保留码、欢迎页原生布局和iOS业务错误继续。
- 两步初始化采用Android模型异步切换，不阻塞身份保存和进入首页。
## Capabilities
### New Capabilities
- auth-onboarding-reference-alignment: 登录邀请与初始化一致性。
## Impact
仅相关Flutter共享UI、控制器和装配；无依赖或平台构建修改。真实短信/认证/外呼无授权。保留他方pubspec.lock，未验收不归档。
