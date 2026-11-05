## Why

按 2026-09-16 用户调整，先交付无需人工验证的页面和业务策略，不再扩展音频。当前 App 只有工程启动页，需要以固定设计稿与 v65 规则实现首个可自动验收的登录模块。

## What Changes

- 2026-10-23 用户确认修正当前六位输入/校验与本规格的偏差：接受 4–8 位数字、输入最多八位；保持当前 Flutter UI、短信发送与邀请码流程，使用离线认证模块回归验证。

- 从固定 HTML 提取登录/邀请码视觉契约，落地真实 Logo 和语义表单。
- 登录表单、冷却、邀请码 challenge 与返回状态由独立 Controller 编排，纯 Dart 契约隔离数据层。
- 默认数据适配明确报未接入；测试替身仅存在 test/integration_test，不伪造真实认证。
- Android 模拟器、离线单元/Widget/集成测试优先；真实短信、账户持久化、首页和 iOS 本批页面验证属于后续批次。

## Capabilities

### New Capabilities
- `auth-presentation`: 基于 v65 的登录/邀请码展示与可测试状态流程。

### Modified Capabilities
- `app-foundation`：工程启动页迁移为登录入口；未就绪服务通过明确操作提示暴露，不改变缺少配置时禁止真实请求的门禁。

## Impact

影响 lib/features/auth、共享设计 token、应用路由、pubspec 资源和自动化测试。无后端、数据库、提示词、SIP/ASR/TTS 或真实网络请求；不接入可信来电。每个手写微批不超过三个文件，生成设计元数据为机械批次。
