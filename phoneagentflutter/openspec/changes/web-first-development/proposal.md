## Why

2026-09-16 用户要求同一 Flutter 工程优先在移动视口 Web 中迭代 UI 与文字闭环，自动化验证替代日常逐步 ADB 截图；Android/iOS 保留里程碑和平台能力验收。

## What Changes

- 增加 Web 宿主、移动宽度预览和可重复启动命令。
- 核验并适配 POST SSE 增量响应、取消、跨域及安全存储。
- 建立浏览器自动回归与设计状态检查，区分 synthetic 与真实接口证据。
- 统一页 UI 与真实文字闭环继续推进，不以 Web 可打开代替业务完成。

## Capabilities

### New Capabilities
- `web-development`: 同源本地开发入口、共享 UI/业务、浏览器验证和真机分工。

### Modified Capabilities

无；移动端产品行为、身份和正式发布配置不变。

## Impact

新增 web 宿主、开发脚本、薄网络适配和测试；不复制业务页面，不修改后端 API/数据库/提示词/SIP/ASR/TTS。测试环境登录和文字请求沿用用户授权；禁止真实外呼。日志不输出凭据。
